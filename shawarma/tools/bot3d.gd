extends "res://scripts3d/main3d.gd"
## Capture bot for the 3D game: plays a shift through the station APIs and saves screenshots
## from fixed camera views. Run with a window (xvfb):
##   godot --path . res://tools/bot3d.tscn -- --out <dir> [--speed 3]

const VIEWS := {
	"window": [Vector3(0, 0, 0.1), 0.0, -0.06],
	"back": [Vector3(-0.3, 0, 0.75), PI, -0.6],
	"spit": [Vector3(-0.85, 0, 0.8), PI / 2.0, -0.38],
	"grill": [Vector3(0.85, 0, 0.3), -PI / 2.0, -0.5],
	"overview": [Vector3(-1.15, 0, 1.15), -PI / 4.0, -0.2],
}
const SHOTS := [[6.0, "spit"], [11.0, "window"], [14.0, "back"], [19.0, "grill"], [24.0, "overview"],
	[40.0, "window"], [60.0, "back"], [121.0, "window"], [150.0, "grill"]]

var out_dir := ".studioigor/captures/bot3d"
var shot_i := 0
var act_t := 0.0
var real_t := 0.0
var phase := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var speed := 3.0
	for i in args.size():
		if args[i] == "--out":
			out_dir = args[i + 1]
		if args[i] == "--speed":
			speed = float(args[i + 1])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out_dir))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	super()
	Engine.time_scale = speed


func _view(name: String) -> void:
	var v: Array = VIEWS[name]
	player.position = v[0]
	player.yaw = v[1]
	player.pitch = v[2]


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://%s/%s.png" % [out_dir, name]))


func _process(delta: float) -> void:
	super(delta)
	real_t += delta / Engine.time_scale
	match phase:
		0:
			if real_t > 1.0:
				_shot("00_menu")
				phase = 1
		1:
			if real_t > 1.4:
				_show_note()
				phase = 2
		2:
			if real_t > 2.0:
				_shot("01_note")
				phase = 3
		3:
			if real_t > 2.4:
				_start_shift()
				phase = 4
		4:
			if g == G.PLAYING:
				if shot_i < SHOTS.size() and shift_t >= SHOTS[shot_i][0]:
					_view(SHOTS[shot_i][1])
					_shot("%02d_%s_%03d" % [shot_i + 2, SHOTS[shot_i][1], int(SHOTS[shot_i][0])])
					shot_i += 1
				act_t -= delta
				if act_t <= 0.0:
					act_t = 0.9
					_act()
			elif g == G.SUMMARY:
				phase = 5
				real_t = 0.0
		5:
			if real_t > 1.5:
				phase = 6
				print("BOT3D stats: ", stats, " money: ", money_today, " rating: ", _rating())
				await _shot("99_summary")
				get_tree().quit()


func _act() -> void:
	if not player.held.is_empty():
		var target = _match_customer(player.held)
		if target != null:
			_serve(target, player.drop())
		else:
			player.drop()
		return
	for i in grill.unlocked:
		var s = grill.slots[i]
		if s != null and s["t"] >= Bal.f("grill_perfect_from") + 0.3:
			if _match_customer(s["made"]) != null:
				player.hold(grill.take(i))
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
				board.put_lavash()
		BoardS.S.OPEN:
			if board.meat < c.order.meat:
				if spit.can_cut():
					spit.cut()
					board.add_meat()
					_fly(spit.cut_point(), board.center_global(), M3.mat(DU.MEAT), Vector3(0.05, 0.012, 0.02), 6)
				return
			for id in c.order.items:
				if not board.items.has(id):
					board.add_item(id)
					return
			board.roll()
		BoardS.S.ROLLED:
			var i: int = grill.free_slot()
			if i >= 0:
				grill.put_in(i, board.take_roll(), board.center_global())


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
	if not player.held.is_empty() and _match_customer(player.held) == c:
		return true
	return false
