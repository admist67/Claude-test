extends "res://scripts/main.gd"
## Capture bot: plays a shift by itself and saves screenshots into .studioigor/captures/<dir>/.
## Run with a window (xvfb), not --headless:  godot --path . res://tools/bot.tscn -- --out <dir> [--speed 4]

var out_dir := ".studioigor/captures/bot"
var shots := [2.0, 5.0, 9.0, 14.0, 22.0, 40.0, 75.0, 118.0, 150.0]
var shot_i := 0
var act_t := 0.0
var real_t := 0.0
var phase := 0
var log_lines: Array = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var speed := 4.0
	for i in args.size():
		if args[i] == "--out":
			out_dir = args[i + 1]
		if args[i] == "--speed":
			speed = float(args[i + 1])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out_dir))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	super()
	Engine.time_scale = speed


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://%s/%s.png" % [out_dir, name]))


func _process(delta: float) -> void:
	super(delta)
	real_t += delta / Engine.time_scale
	match phase:
		0:
			if real_t > 0.6:
				_shot("00_menu")
				phase = 1
		1:
			if real_t > 1.0:
				_show_note()
				phase = 2
		2:
			if real_t > 1.6:
				_shot("01_note")
				phase = 3
		3:
			if real_t > 2.0:
				_start_shift()
				phase = 4
		4:
			if g == G.PLAYING:
				if shot_i < shots.size() and shift_t >= shots[shot_i]:
					_shot("%02d_shift_%03d" % [shot_i + 2, int(shots[shot_i])])
					shot_i += 1
				act_t -= delta
				if act_t <= 0.0:
					act_t = 0.45
					_act()
			elif g == G.SUMMARY:
				phase = 5
				real_t = 0.0
		5:
			if real_t > 1.5:
				_shot("99_summary")
				print("BOT stats: ", stats, " money: ", money_today, " rating: ", _rating())
				get_tree().quit()


func _act() -> void:
	# Serve anything in the green zone first.
	for i in grill.unlocked:
		var s = grill.slots[i]
		if s != null and s["fly"] <= 0.0 and s["t"] >= Bal.f("grill_perfect_from") + 0.3:
			var made: Dictionary = s["made"]
			var target = _match_customer(made)
			if target != null:
				_serve(target, grill.take(i))
				return
			if s["t"] >= Bal.f("grill_burnt_at"):
				grill.take(i)
				return
	var c = null
	for s in slots:
		if s != null and s.st == CustomerS.St.WAIT and not _being_made_for(s) and (c == null or s.patience < c.patience):
			c = s
	if c == null:
		return
	match board.state:
		BoardS.S.EMPTY:
			if grill.free_slot() >= 0:
				_bin("lavash")
		BoardS.S.OPEN:
			if board.meat < c.order.meat:
				if spit.can_cut():
					_cut()
				return
			for id in c.order.items:
				if not board.items.has(id):
					_bin(id)
					return
			_roll()
		BoardS.S.ROLLED:
			_to_grill()


func _match_customer(made: Dictionary):
	for s in slots:
		if s != null and s.st == CustomerS.St.WAIT:
			var ok: bool = s.order.meat == made["meat"] and s.order.items.size() == made["items"].size()
			for id in s.order.items:
				ok = ok and made["items"].has(id)
			if ok:
				return s
	return null


func _being_made_for(c) -> bool:
	for i in grill.unlocked:
		var s = grill.slots[i]
		if s != null and _match_customer(s["made"]) == c:
			return true
	return false
