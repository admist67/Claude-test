extends "res://scripts3d/main3d.gd"
## Capture bot for the 3D game: plays a shift through the station APIs and saves screenshots
## from fixed camera views. Run with a window (xvfb):
##   godot --path . res://tools/bot3d.tscn -- --out <dir> [--speed 3]

const VIEWS := {
	"terrace": [Vector3(0.6, 0, -5.0), PI + 0.35, -0.15],
	"hall": [Vector3(2.2, 0, -1.4), 0.5, -0.22],
	"tables": [Vector3(-0.6, 0, -2.4), PI / 2.0 + 0.2, -0.22],
	"window": [Vector3(0, 0, 0.0), 0.0, -0.06],
	"back": [Vector3(-0.6, 0, 1.0), PI, -0.55],
	"spit": [Vector3(-1.75, 0, 1.0), PI / 2.0, -0.38],
	"grill": [Vector3(1.7, 0, 0.75), -PI / 2.0, -0.5],
	"overview": [Vector3(-2.0, 0, 1.5), -PI / 4.0 + 0.1, -0.2],
	"storage": [Vector3(0.9, 0, 0.7), PI - 0.45, -0.35],
	"storage2": [Vector3(0.9, 0, 0.7), PI + 0.45, -0.35],
}
const SHOTS := [[6.0, "spit"], [11.5, "window"], [14.0, "back"], [19.0, "grill"], [24.0, "overview"], [26.0, "storage"], [28.0, "storage2"],
	[34.0, "terrace"], [44.0, "hall"], [60.0, "tables"], [90.0, "terrace"], [121.0, "window"], [150.0, "hall"]]

var out_dir := ".studioigor/captures/bot3d"
var shot_i := 0
var act_t := 0.0
var real_t := 0.0
var phase := 0
var days_to_play := 1
var day_i := 1
var fire_demo := false
var _shots_fire := 0
var _seen_restock := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var speed := 3.0
	for i in args.size():
		if args[i] == "--out":
			out_dir = args[i + 1]
		if args[i] == "--speed":
			speed = float(args[i + 1])
		if args[i] == "--days":
			days_to_play = int(args[i + 1])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out_dir))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	var start_day := 1
	for i in args.size():
		if args[i] == "--start-day":
			start_day = int(args[i + 1])
	if start_day > 1:
		var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		var hist: Array = []
		for k in start_day - 1:
			hist.append(2 + k % 2)
		f.store_string(JSON.stringify({"day": start_day, "bank": 16000, "sound": true, "stars": hist}))
		f.close()
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
				phase = 10
				await _shot("00_menu")
				phase = 1
		1:
			if real_t > 1.4:
				phase = 10
				if day > 1:
					_show_shop()
					await _shot("01a_shop")
					for id in ["cafe", "tables", "helper", "waiter", "cleaner", "garland", "grill3", "neon", "tipjar", "spit"]:
						_buy(id)
					shop_tab = "cafe"
					_show_shop()
					await _shot("01b_shop_bought")
					_buy("recipe")
					_show_recipe()
					await _shot("01c_recipe")
					hud.recipe_saved.emit({"name": RECIPE_NAMES[1], "meat": 2, "items": ["tomato", "cabbage", "onion"]})
					await _shot("01d_shop_recipe_saved")
				_show_note()
				real_t = 1.4
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
				if not fire_demo and shift_t >= 17.0 and grill.slots[0] != null:
					grill._ignite(0)
					fire_demo = true
				if not staff.restocking.is_empty() and not _seen_restock:
					_seen_restock = true
					print("BOT3D helper restocking ", staff.restocking.keys(), " at ", int(shift_t))
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
			if real_t > 1.5 and day_i < days_to_play:
				await _shot("99_summary_day%d" % day_i)
				day_i += 1
				shot_i = 0
				_show_note()
				_start_shift()
				phase = 4
				out_dir = out_dir + "_d%d" % day_i
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out_dir))
			elif real_t > 1.5:
				phase = 6
				print("BOT3D stats: ", stats, " money: ", money_today, " rating: ", _rating())
				await _shot("99_summary")
				_after_summary()
				await get_tree().create_timer(0.6 * Engine.time_scale).timeout
				await _shot("99z_after_summary")
				get_tree().quit()


func _act() -> void:
	if grill.any_fire() and shift_t > 21.0:
		if not player.held.has("ext"):
			player.drop()
			player.hold({"ext": true})
			return
		for i in grill.unlocked:
			if grill.on_fire(i):
				grill.extinguish(i)
				player.drop()
				_shots_fire += 1
				return
	if player.held.has("ext") or player.held.has("crate"):
		player.drop()
		return
	if not staff.workers.has("helper"):
		for id in ["lavash"] + unlocked:
			if bins.nodes.has(id) and not bins.has(id):
				bins.refill(id)
				return
	if not player.held.is_empty():
		var target = null
		if player.held.has("drink"):
			for c in _waiting():
				if c.order.drink and not c.got_drink:
					target = c
					break
		else:
			target = customer_for(player.held)
		if target != null:
			give(target, player.drop())
		else:
			player.drop()
		return
	var has_waiter: bool = staff.workers.has("waiter")
	if cafe.enabled and not has_waiter:
		for c in _waiting():
			if c.order.drink and not c.got_drink:
				player.hold({"drink": true})
				return
	for i in grill.unlocked:
		var s = grill.slots[i]
		if s == null:
			continue
		if s["t"] >= Bal.f("grill_burnt_at"):
			grill.take(i)
			return
		if not has_waiter and s["t"] >= Bal.f("grill_perfect_from") + 0.3 and customer_for(s["made"]) != null:
			player.hold(grill.take(i))
			return
	if cafe.enabled and not staff.workers.has("cleaner"):
		for t in cafe.dirty_tables():
			cafe.set_state(t, "free")
			return
	match board.state:
		BoardS.S.EMPTY:
			if grill.free_slot() >= 0 and next_uncovered() != null and bins.has("lavash"):
				if board.put_lavash():
					bins.take("lavash")
		BoardS.S.OPEN:
			var c = _board_target()
			if c == null:
				board.clear()
				return
			if board.meat < c.order.meat:
				if spit.can_cut():
					spit.cut()
					board.add_meat()
					_fly(spit.cut_point(), board.center_global(), M3.mat(DU.MEAT), Vector3(0.05, 0.012, 0.02), 6)
				return
			for id in c.order.items:
				if not board.items.has(id):
					if bins.has(id) and board.add_item(id):
						bins.take(id)
					return
			board.roll()
		BoardS.S.ROLLED:
			var i: int = grill.free_slot()
			if i >= 0:
				grill.put_in(i, board.take_roll(), board.center_global())


## The waiting customer whose order fits what is already on the board.
func _board_target():
	var taken: Array = []
	for i in grill.unlocked:
		if grill.slots[i] != null:
			taken.append(customer_for(grill.slots[i]["made"]))
	for c in _waiting():
		if not c.needs_roll() or c.has_meta("waiter_roll") or taken.has(c):
			continue
		var ok: bool = board.meat <= c.order.meat
		for id in board.items:
			ok = ok and c.order.items.has(id)
		if ok:
			return c
	return null


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
