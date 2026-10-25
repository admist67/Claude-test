extends "res://scenes/main.gd"
## Capture bot: plays a scripted minute through the real systems and saves frames.
## Run with a window (xvfb):  godot --path . res://tools/capture.tscn -- --out <dir>

var out_dir := ".studioigor/captures/bot"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out":
			out_dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out_dir))
	SaveGame.dir = "user://capture_saves/"
	SaveGame.clear_all()
	super()
	_run()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://%s/%s.png" % [out_dir, n]))
	print("shot ", n)


func _aim(y: float, p: float) -> void:
	player.yaw = y
	player.pitch = p


## Turns the view toward a raft-local point.
func _aim_local(p: Vector3) -> void:
	var d := raft.to_global(p) - player.cam.global_position
	player.yaw = atan2(-d.x, -d.z)
	player.pitch = atan2(d.y, Vector2(d.x, d.z).length())


func _build_at(kind: String, p: Vector3) -> void:
	builder.kind = kind
	_aim_local(p)
	await _wait(0.25)
	var ok := builder.has_target and builder.valid
	_on_pressed("action")
	_on_released("action")
	print("build ", kind, " target ", builder.has_target, " valid ", ok)


## Turns the view toward a raft cell's center (+ height).
func _look_cell(c: Vector2i, h := 0.0) -> void:
	var target := raft.to_global(raft.cell_center(c) + Vector3(0, h, 0))
	var d := target - player.cam.global_position
	player.yaw = atan2(-d.x, -d.z)
	player.pitch = atan2(d.y, Vector2(d.x, d.z).length())


## A finger press, drag by `dy` and release at a screen point, through the real input path.
func _drag(at: Vector2, dy: float) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = at
	e.global_position = at
	Input.parse_input_event(e)
	await _wait(0.05)
	for i in 6:
		var m := InputEventMouseMotion.new()
		m.position = at + Vector2(0, dy * (i + 1) / 6.0)
		m.global_position = m.position
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(m)
		await _wait(0.03)
	var r := InputEventMouseButton.new()
	r.button_index = MOUSE_BUTTON_LEFT
	r.pressed = false
	r.position = at + Vector2(0, dy)
	r.global_position = r.position
	Input.parse_input_event(r)
	await _wait(0.1)


func _run() -> void:
	await _wait(2.0)
	await _shot("00_menu")
	menus.new_game.emit("Тестовый плот")
	await _wait(1.5)
	_aim(0.0, -0.12)
	print("shark before the first spear: enabled ", shark.enabled)
	await _shot("01_start")
	# Throw the hook at full power and reel it in.
	_on_pressed("action")
	await _wait(1.0)
	await _shot("02_charge")
	_on_released("action")
	await _wait(0.4)
	await _shot("03_flight")
	await _wait(1.0)
	await _shot("04_water")
	# Steer two pieces of debris into the hook to prove catching works.
	for i in 2:
		var d: Debris = field.items[i]
		d.global_position = hook.global_position + Vector3(0.3 * i, 0, -0.2)
	await _wait(0.2)
	print("caught on hook: ", hook.caught.size())
	_on_pressed("action")
	await _wait(1.2)
	await _shot("05_reel")
	var t := 0.0
	while hook.state != Hook.State.IDLE and t < 8.0:
		await _wait(0.2)
		t += 0.2
	_on_released("action")
	await _wait(0.3)
	await _shot("06_delivered")
	print("inventory after reel: ", inv.to_dict())
	# Look around the raft.
	_aim(PI * 0.75, -0.5)
	await _wait(0.4)
	await _shot("07_raft")
	# Craft: rope and a hammer.
	inv.add("leaf", 4)
	inv.add("plank", 10)
	inv.add("plastic", 3)
	_open_bag()
	await _wait(0.4)
	await _shot("08_bag")
	for r: Dictionary in Data.recipes:
		_craft(r)
		_craft(r)
	await _wait(0.3)
	_close_bag()
	_select("hammer")
	builder.kind = "tile"
	player.place(raft.cell_center(Vector2i(0, 0)) + Vector3(0, 0.05, 0), 0.0)
	_aim(0.0, -0.75)
	await _wait(0.5)
	await _shot("09_build_ghost")
	_on_pressed("action")
	_on_released("action")
	await _wait(0.5)
	await _shot("10_built")
	_aim(PI, -0.55)
	await _wait(0.3)
	await _shot("11_back")
	# Stations: purifier and grill on the deck.
	inv.add("plastic", 6)
	inv.add("plank", 14)
	inv.add("leaf", 8)
	inv.add("fish", 2)
	player.place(raft.cell_center(Vector2i(0, 0)) + Vector3(0, 0.05, 0), 0.0)
	_select("hammer")
	builder.kind = "purifier"
	_look_cell(Vector2i(1, 0))
	await _wait(0.4)
	await _shot("18_build_purifier")
	_on_pressed("action")
	_on_released("action")
	builder.kind = "grill"
	_look_cell(Vector2i(0, 1))
	await _wait(0.3)
	_on_pressed("action")
	_on_released("action")
	print("stations: ", raft.stations.size())
	_select("hook")
	_look_cell(Vector2i(1, 0), 0.4)
	await _wait(0.3)
	_on_pressed("use")
	_look_cell(Vector2i(0, 1), 0.4)
	await _wait(0.3)
	_on_pressed("use")
	await _wait(0.4)
	print("grill asks what to cook: ", actions.picker.visible, " mode ", mode)
	await _shot("68_grill_pick")
	actions._on_picked("fish")
	await _wait(1.2)
	await _shot("19_grill_cooking")
	_look_cell(Vector2i(1, 0), 0.4)
	await _wait(0.6)
	await _shot("20_purifier_boiling")
	for st: Station in raft.stations.values():
		st.progress = float(st.def["time"]) - 0.3
	await _wait(0.8)
	_on_pressed("use")
	_look_cell(Vector2i(0, 1), 0.4)
	await _wait(0.3)
	_on_pressed("use")
	print("after stations: ", inv.to_dict())
	# Fishing.
	inv.add("rope", 3)
	for r: Dictionary in Data.recipes:
		if r["id"] == "rod":
			_craft(r)
	_select("rod")
	player.place(raft.cell_center(Vector2i(1, 1)) + Vector3(0, 0.05, 0), 0.0)
	_aim(0.5, -0.15)
	_on_pressed("action")
	await _wait(0.6)
	_on_released("action")
	await _wait(1.4)
	await _shot("21_rod_wait")
	rod._timer = 0.01
	await _wait(0.25)
	await _shot("22_bite")
	_on_pressed("action")
	await _wait(0.7)
	await _shot("23_fight")
	# Play the fish: hold while it is calm and the line is slack enough, let go otherwise.
	var held := true
	var tf := 0.0
	while rod.state == Rod.State.FIGHT and tf < 40.0:
		var want := not rod.jerking and rod.tension < 0.7
		if want != held:
			if want:
				_on_pressed("action")
			else:
				_on_released("action")
			held = want
		await _wait(0.05)
		tf += 0.05
	if held:
		_on_released("action")
	print("fight took ", snappedf(tf, 0.1), " s; fish: ", inv.count("fish"), " big: ", inv.count("big_fish"), " rod wear left ", actions.wear.uses_left("rod", 25))
	await _wait(0.3)
	await _shot("24_caught")
	# Hold all the way through: the line snaps.
	_on_pressed("action")
	await _wait(0.6)
	_on_released("action")
	await _wait(1.0)
	rod._timer = 0.01
	await _wait(0.25)
	_on_pressed("action")
	var ts := 0.0
	while rod.state == Rod.State.FIGHT and ts < 15.0:
		await _wait(0.1)
		ts += 0.1
	_on_released("action")
	print("held through: state ", rod.state, " after ", snappedf(ts, 0.1), " s, rod wear left ", actions.wear.uses_left("rod", 25))
	# Night with a fire on the grill.
	inv.add("fish", 1)
	_look_cell(Vector2i(0, 1), 0.4)
	await _wait(0.2)
	_on_pressed("use")
	if actions.picker.visible:
		actions._on_picked("fish")
	player.place(raft.cell_center(Vector2i(1, 1)) + Vector3(0, 0.05, 0), 0.0)
	_look_cell(Vector2i(0, 1), 0.3)
	daynight.phase = 0.7
	await _wait(0.6)
	await _shot("24_night_fire")
	daynight.phase = 0.2
	# The shark: attack, spear fight, repair.
	inv.add("plank", 6)
	inv.add("rope", 3)
	inv.add("plastic", 3)
	for r: Dictionary in Data.recipes:
		if r["id"] == "spear":
			_craft(r)
	shark.reset(0.0)
	await _wait(0.2)
	shark._timer = 0.0
	var t2 := 0.0
	while shark.state != Shark.State.BITE and t2 < 15.0:
		await _wait(0.2)
		t2 += 0.2
	print("shark state ", shark.state, " target ", shark.target)
	player.place(raft.nearest_tile(raft.centroid()), 0.0)
	var sp := shark.global_position - player.cam.global_position
	player.yaw = atan2(-sp.x, -sp.z) + 0.6
	player.pitch = -0.35
	await _wait(1.6)
	await _shot("25_shark_warning")
	player.place(raft.cell_center(shark.target), 0.0)
	await _wait(0.2)
	sp = shark.global_position - player.cam.global_position
	player.yaw = atan2(-sp.x, -sp.z)
	player.pitch = atan2(sp.y, Vector2(sp.x, sp.z).length())
	await _wait(0.4)
	await _shot("26_shark_bite")
	_select("spear")
	for i in 2:
		_on_pressed("action")
		await _wait(0.75)
	await _shot("27_shark_hit")
	print("hits left ", shark.hits_left(), " state ", shark.state, " tile hp ", raft.tile_hp(shark.target))
	for i in 6:
		shark.global_position = player.cam.global_position + player.flat_forward() * 2.0
		shark.state = Shark.State.BITE
		_on_pressed("action")
		await _wait(0.75)
	await _shot("28_shark_driven")
	print("after drive: meat ", inv.count("shark_meat"), " driven ", stats.get("shark_driven", 0), " state ", shark.state)
	var bitten: Array = raft.hp.keys()
	if not bitten.is_empty():
		_select("hammer")
		_look_cell(bitten[0])
		await _wait(0.4)
		await _shot("29_repair")
		_on_pressed("action")
		print("repaired: ", not raft.damaged(bitten[0]))
	# Building: walls, window, door, pillar, roofs, stairs, net, lantern.
	shark.reset(9999.0)
	inv.add("plank", 80)
	inv.add("rope", 30)
	inv.add("leaf", 30)
	inv.add("plastic", 12)
	var grid: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(2, 0), Vector2i(2, 1), Vector2i(0, 2)]
	grid.append_array([Vector2i(1, 2), Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)])
	for c: Vector2i in grid:
		raft.add_tile(c)
	for c: Variant in raft.stations.keys():
		raft.stations[c].queue_free()
	raft.stations.clear()
	_select("hammer")
	var cc := func(x: int, z: int) -> Vector3: return raft.cell_center(Vector2i(x, z))
	player.place(cc.call(0, 0), 0.0)
	await _build_at("wall", cc.call(-1, 0) + Vector3(-0.6, 0, 0))
	await _build_at("window", cc.call(-1, 1) + Vector3(-0.6, 0, 0))
	player.place(cc.call(1, 1), 0.0)
	await _build_at("door", cc.call(0, 2) + Vector3(0, 0, 0.6))
	await _build_at("pillar", cc.call(1, 2) + Vector3(0.55, 0, 0.55))
	await _build_at("lantern", cc.call(2, 1) + Vector3(0.55, 0, 0.55))
	player.place(cc.call(0, 0), 0.0)
	await _build_at("roof", cc.call(-1, 0))
	await _build_at("roof", cc.call(-1, 1))
	player.place(cc.call(1, 0), 0.0)
	await _build_at("stairs", cc.call(0, 0))
	await _build_at("net", cc.call(2, 0) + Vector3(0, 0, -0.6))
	await _build_at("purifier", cc.call(1, 1))
	print("parts: ", raft.parts.to_list().size())
	_open_build()
	await _wait(0.5)
	await _shot("35_build_panel")
	_close_build()
	_select("hook")
	player.place(cc.call(2, 1), 0.0)
	_aim_local(cc.call(-1, 0) + Vector3(0, 1.4, 0))
	player.pitch = -0.12
	await _wait(0.5)
	await _shot("30_build_overview")
	player.place(cc.call(1, 1), 0.0)
	_aim_local(cc.call(0, 2) + Vector3(0, 1.2, 0.75))
	await _wait(1.0)
	await _shot("31_door_open")
	# Climb the stairs onto the roof.
	player.place(cc.call(1, 0), PI / 2.0)
	player.pitch = 0.0
	player.move_input = Vector2(0, -1)
	var t3 := 0.0
	while t3 < 3.0:
		player.move_input = Vector2(0, -1)
		await _wait(0.1)
		t3 += 0.1
	player.move_input = Vector2.ZERO
	print("on roof y ", player.position.y, " cell ", raft.cell_at(player.position))
	# Second floor: a wall and a tall lantern up on the roof.
	_select("hammer")
	player.move_input = Vector2.ZERO
	await _wait(0.3)
	await _build_at("wall", cc.call(-1, 1) + Vector3(-0.6, RaftParts.H, 0))
	await _build_at("lantern_wall", cc.call(-1, 1) + Vector3(-0.75, RaftParts.H + 1.3, 0))
	print("upper_built ", stats.get("upper_built", 0), " level ", builder.level)
	_select("hook")
	player.pitch = -0.3
	await _wait(0.3)
	await _shot("32_on_roof")
	# A net catches drifting debris.
	var net: Part = raft.parts.nets()[0] if not raft.parts.nets().is_empty() else null
	if net:
		for i in 3:
			var d: Debris = field.items[i]
			d.global_position = raft.to_global(net.position) + Vector3(0.3 * (i - 1), 0, -2.0 - i * 0.6)
		await _wait(3.5)
		print("net caught ", net.caught.size())
		player.place(cc.call(2, 0), 0.0)
		_aim_local(net.position + Vector3(0, 0.1, 0))
		await _wait(0.3)
		await _shot("33_net")
		_on_pressed("use")
		print("after net use: ", net.caught.size())
	daynight.phase = 0.72
	player.place(cc.call(1, 1), 0.0)
	_aim_local(cc.call(-1, 1) + Vector3(0, 1.2, 0))
	await _wait(0.5)
	await _shot("34_lantern_night")
	daynight.phase = 0.2
	# v0.6: lanterns with rotation, demolish, rain collector, bait, bag tabs.
	_select("hammer")
	player.place(cc.call(1, 1), 0.0)
	builder.kind = "lantern_tall"
	builder.turn()
	builder.turn()
	_aim_local(cc.call(1, 1) + Vector3(0.55, 0, -0.55))
	await _wait(0.4)
	await _shot("46_rotate_button")
	await _build_at("lantern_tall", cc.call(1, 1) + Vector3(0.55, 0, -0.55))
	builder.rot = 0
	await _build_at("collector", cc.call(2, 1))
	var pillar_n := raft.parts.count("pillar")
	var plank_n := inv.count("plank")
	_aim_local(raft.parts.corner_center(Vector3i(1, 2, 0)) + Vector3(0, 1.2, 0))
	await _wait(0.3)
	print("demolish target ", demolish_target)
	_on_pressed("use")
	await _wait(0.3)
	print("pillars ", pillar_n, " -> ", raft.parts.count("pillar"), " planks +", inv.count("plank") - plank_n)
	for st: Station in raft.stations.values():
		if st.kind == "collector":
			st.stored = 2
	_select("hook")
	_look_cell(Vector2i(2, 1), 0.5)
	await _wait(0.3)
	await _shot("41_collector")
	_on_pressed("use")
	print("cups ", inv.count("cup_water"))
	daynight.phase = 0.72
	player.place(cc.call(0, 1), 0.0)
	_aim_local(cc.call(1, 1) + Vector3(0.55, 1.8, -0.55))
	await _wait(0.5)
	await _shot("42_lanterns_night")
	daynight.phase = 0.2
	inv.add("fish", 1)
	for r: Dictionary in Data.recipes:
		if r["id"] == "bait":
			_craft(r)
	_select("rod")
	_aim(0.4, -0.1)
	_on_pressed("action")
	await _wait(0.5)
	_on_released("action")
	print("bait left ", inv.count("bait"), " baited ", rod.baited)
	rod.cancel()
	for i in 3:
		_open_bag()
		bag._show(i)
		await _wait(0.4)
		await _shot("4%d_bag_tab%d" % [3 + i, i])
		_close_bag()
	# v0.7: a door opens one way and keeps its sweep clear; an open door is aimed at where
	# its leaf is; wall lanterns go on the wall you look at, on your side.
	_select("hammer")
	player.place(cc.call(0, 1) + Vector3(0, 0, -0.4), 0.0)
	builder.kind = "door"
	builder.rot = 0
	_aim_local(cc.call(0, 1) + Vector3(0, 0, 0.6))
	await _wait(0.4)
	await _shot("47_door_ghost")
	await _build_at("door", cc.call(0, 1) + Vector3(0, 0, 0.6))
	builder.kind = "grill"
	_aim_local(cc.call(0, 2))
	await _wait(0.3)
	print("grill in door sweep: target ", builder.has_target, " valid ", builder.valid)
	await _shot("48_swing_block")
	var door2: Part = raft.parts.edges.get(Vector4i(0, 1, 1, 0))
	if door2:
		door2.toggle()
		await _wait(1.0)
		_select("hook")
		for side: Vector3 in [cc.call(0, 2) + Vector3(0.35, 0, 0.35), cc.call(0, 1) + Vector3(0.3, 0, -0.35)]:
			player.place(side, 0.0)
			_aim_local(raft.to_local(door2.leaf_center()))
			await _wait(0.2)
			print("aim open leaf from ", raft.cell_at(side), ": ", _aimed_body() == door2)
		await _shot("49_door_leaf_aim")
		door2.toggle()
	_select("hammer")
	builder.kind = "lantern_wall"
	player.place(cc.call(-1, 1), 0.0)
	_aim_local(Vector3(-2.25, 1.6, 0))
	await _wait(0.4)
	print("wall lamp key ", builder.key, " target ", builder.has_target, " valid ", builder.valid)
	await _shot("50_wall_lamp_ghost")
	await _build_at("lantern_wall", Vector3(-2.25, 1.6, 0))
	print("wall lamps ", raft.parts.lamps.keys())
	# Hotbar in your own order; bag lists scroll by dragging on the cards.
	_select("hook")
	_open_bag()
	bag._show(0)
	bag._hotbar_tap("hook")
	await _wait(0.3)
	await _shot("51_hotbar_pick")
	bag._hotbar_tap(hotbar[hotbar.size() - 1])
	bag._hotbar_tap("rod")
	layout.hide("rod")
	bag._hotbar_done()
	await _wait(0.3)
	print("hotbar ", hotbar, " hidden ", layout.hidden)
	await _shot("52_hotbar_hidden")
	bag._show(2)
	await _wait(0.3)
	var sc_before := bag._scroller.scroll_vertical
	await _drag(Vector2(640, 520), -260.0)
	await _wait(0.5)
	print("drag on cards scrolls ", sc_before, " -> ", bag._scroller.scroll_vertical)
	bag._show(1)
	await _wait(0.3)
	var made := [false]
	var on_craft := func(_r: Dictionary) -> void: made[0] = true
	bag.craft_requested.connect(on_craft)
	for tgt: Array in bag._scroller._taps:
		if tgt[0] is Button and not tgt[0].disabled:
			var r: Rect2 = tgt[0].get_global_rect()
			await _drag(r.get_center(), 0.0)
			break
	bag.craft_requested.disconnect(on_craft)
	print("tap on Сделать crafts ", made[0])
	_close_bag()
	# v0.5: metal tools, planter, hammock, storm.
	inv.add("scrap", 10)
	inv.add("seeds", 2)
	inv.add("plank", 20)
	inv.add("rope", 10)
	for r: Dictionary in Data.recipes:
		if r["id"] in ["metal_hook", "metal_spear"]:
			_craft(r)
	print("metal: ", inv.count("metal_hook"), inv.count("metal_spear"), " hook left ", inv.count("hook"))
	_select("hammer")
	player.place(cc.call(1, 0), 0.0)
	await _build_at("planter", cc.call(2, 0))
	player.place(cc.call(1, 1), 0.0)
	await _build_at("hammock", cc.call(1, 2))
	_select("metal_hook")
	inv.add("banana_shoot", 1)
	_look_cell(Vector2i(2, 0), 0.3)
	await _wait(0.3)
	_on_pressed("use")
	await _wait(0.4)
	print("planter asks what to plant: ", actions.picker.visible)
	await _shot("69_planter_pick")
	actions._on_picked("banana_shoot")
	for st: Station in raft.stations.values():
		if st.kind == "planter":
			st.progress = float(st.def["time"]) * 0.6
	await _wait(0.4)
	await _shot("36_planter_growing")
	for st: Station in raft.stations.values():
		if st.kind == "planter":
			st.progress = float(st.def["time"]) - 0.2
	await _wait(0.6)
	await _shot("37_planter_ready")
	_on_pressed("use")
	print("bananas ", inv.count("banana"), " planted ", stats.get("planted", 0), " harvest ", stats.get("harvest", 0))
	daynight.phase = 0.7
	player.place(cc.call(1, 1), 0.0)
	_look_cell(Vector2i(1, 2), 0.6)
	await _wait(0.4)
	await _shot("38_hammock_night")
	_on_pressed("use")
	await _wait(3.0)
	print("after sleep day ", daynight.day, " phase ", snappedf(daynight.phase, 0.01), " slept ", stats.get("slept", 0))
	storm.state = Storm.State.WARN
	storm.timer = 0.05
	await _wait(0.5)
	storm._elapsed = 40.0
	player.place(cc.call(2, 0), 0.0)
	_aim(0.3, -0.05)
	await _wait(1.5)
	await _shot("39_storm")
	storm.flash = 1.0
	await _shot("40_lightning")
	storm.timer = 0.05
	await _wait(0.3)
	print("storms ", stats.get("storms", 0), " amp ", Ocean.amp_mult)
	# v0.8: the goal plaque opens and hides; the hand can be empty; a fresh hammer has
	# nothing picked; a tile ghost from the roof floats on the water.
	player.place(cc.call(1, 1) + Vector3(0, 0, 0.3), 0.0)
	_aim(PI * 0.6, -0.1)
	_on_pressed("goal")
	await _wait(0.3)
	await _shot("57_goal_open")
	_on_pressed("goal_hide")
	await _wait(0.3)
	await _shot("58_goal_hidden")
	_on_pressed("goal")
	_select(hotbar[0])
	_on_pressed("slot0")
	print("hand after tapping the held item again: '", hand, "'")
	_on_pressed("slot%d" % hotbar.find("spear"))
	await _wait(0.5)
	await _shot("59_item_name")
	_on_pressed("slot%d" % hotbar.find("hammer"))
	await _wait(0.4)
	print("fresh hammer kind: '", builder.kind, "' action ", action_view()["label"])
	await _shot("60_hammer_fresh")
	player.place(cc.call(-1, 0) + Vector3(0.2, RaftParts.H + 0.05, 0), 0.0)
	builder.kind = "tile"
	await _wait(0.2)
	_aim_local(cc.call(-2, 0) + Vector3(-0.2, 0, 0))
	await _wait(0.4)
	print("tile ghost from the roof: target ", builder.has_target, " y ", snappedf(builder._ghost.position.y, 0.01))
	await _shot("61_tile_from_roof")
	# Islands: an anchor, an island alongside, jump in, swim over, gather, the shark, back.
	inv.add("plank", 12)
	inv.add("rope", 10)
	inv.add("scrap", 4)
	player.place(cc.call(0, 1), 0.0)
	await _wait(0.2)
	await _build_at("anchor", cc.call(1, 0))
	trips.islands._spawn(777)
	var isl: Island = trips.islands.island
	var rc := raft.global_transform * raft.centroid()
	isl.position.z = rc.z
	var side := signf(isl.position.x - rc.x)
	hand = ""
	_refresh_hotbar()
	await _wait(0.3)
	_aim_local(raft.cell_center(Vector2i(1, 0)) + Vector3(0, 0.4, 0))
	await _wait(0.3)
	_on_pressed("use")
	await _wait(0.5)
	print("anchored ", trips.anchored(), " near ", trips.islands.near(), " anchored_island ", stats.get("anchored_island", 0))
	player.place(cc.call(1, 1), 0.0)
	_aim_local(raft.to_local(isl.global_position) + Vector3(0, 2.0, 0))
	player.pitch = -0.05
	await _wait(0.6)
	await _shot("62_island_alongside")
	# To a free edge on the island's side and into the water.
	isl.position.x = rc.x + absf(isl.position.x - rc.x)
	side = 1.0
	raft.add_tile(Vector2i(3, 1))
	var edge_c := Vector2i(3, 1)
	field.clear_all()
	player.place(cc.call(edge_c.x, edge_c.y) + Vector3(0.4, 0, 0), 0.0)
	_aim_local(cc.call(edge_c.x, edge_c.y) + Vector3(3.0, -0.3, 0))
	await _wait(0.3)
	print("jump spot ", trips.jump_at != null, " use label ", use_view()["label"])
	_on_pressed("use")
	await _wait(1.2)
	print("swimming ", player.swimming, " off raft ", player.off_raft)
	_aim_local(raft.to_local(isl.global_position) + Vector3(0, 1.5, 0))
	player.pitch = 0.0
	await _wait(0.3)
	await _shot("63_swimming")
	var t4 := 0.0
	while t4 < 25.0 and (player.swimming or not isl.visited):
		var to := isl.global_position - player.global_position
		player.yaw = atan2(-to.x, -to.z)
		player.move_input = Vector2(0, -1)
		await _wait(0.2)
		t4 += 0.2
	player.move_input = Vector2.ZERO
	print("reached island in ", snappedf(t4, 0.1), " s, visits ", stats.get("island_visits", 0), " swimming ", player.swimming)
	await _wait(0.3)
	await _shot("64_on_island")
	for spot: IslandSpot in isl.spots:
		var at := isl.to_global(spot.position)
		var away := (at - isl.global_position)
		away.y = 0.0
		player._world = at + away.normalized() * 1.6 + Vector3(0, 1.2, 0)
		player.global_position = player._world
		await _wait(0.5)
		_aim_local(raft.to_local(at + Vector3(0, 0.6, 0)))
		await _wait(0.2)
		var label: String = use_view()["label"]
		for k in spot.left:
			_on_pressed("use")
			await _wait(0.1)
		print("gathered ", spot.kind, " ('", label, "') left ", spot.left)
		if spot.kind == "palm":
			await _shot("65_palm")
	print("stone ", inv.count("stone"), " coconut ", inv.count("coconut"), " chests ", stats.get("chests", 0))
	# The shark goes for a swimmer.
	var shore_at := isl.global_position + Vector3(-side, 0, 0) * (isl.radius + 2.5)
	player.jump_in(shore_at)
	shark.reset(0.1)
	await _wait(0.5)
	shark.state = Shark.State.CIRCLE
	var hp0 := vitals.health
	var t5 := 0.0
	while t5 < 12.0 and vitals.health >= hp0:
		await _wait(0.2)
		t5 += 0.2
	_aim_local(raft.to_local(shark.global_position))
	await _wait(0.2)
	print("shark hunting ", shark.hunting(), " health ", snappedf(hp0, 0.1), " -> ", snappedf(vitals.health, 0.1))
	await _shot("66_shark_hunt")
	shark.reset(9999.0)
	vitals.health = 100.0
	# Back next to the raft and climb on.
	player.jump_in(raft.to_global(cc.call(edge_c.x, edge_c.y) + Vector3(1.6 * side, 0, 0)))
	await _wait(0.8)
	print("climb spot ", trips.climb_at != null, " label ", use_view()["label"])
	_on_pressed("use")
	await _wait(0.3)
	print("back on the raft ", not player.off_raft, " at ", raft.cell_at(player.position))
	# A fish trap on the outer edge.
	_select("hammer")
	inv.add("stone", 3)
	player.place(cc.call(1, 0) + Vector3(-0.4, 0, 0.3), 0.0)
	await _build_at("trap", cc.call(1, 0) + Vector3(0.2, 0, -0.6))
	var traps: Array = raft.parts.edges.values().filter(func(pp: Part) -> bool: return pp.kind == "trap")
	if not traps.is_empty():
		traps[0].fish = 2
		hand = ""
		_refresh_hotbar()
		_aim_local(traps[0].position + Basis(Vector3.UP, traps[0].rotation.y) * Vector3(0, -0.1, 0.6))
		await _wait(0.3)
		print("trap prompt ", use_view()["label"])
		await _shot("67_trap")
		_on_pressed("use")
		print("trap fish taken ", stats.get("trap_fish", 0))
	print("goal ", goal_i, ": ", goal_view()["text"])
	print("island still there ", trips.islands.island == isl, " at ", isl.position.round())
	# Survival pressure.
	vitals.thirst = 0.0
	vitals.hunger = 18.0
	_select("hook")
	_aim(0.3, -0.1)
	await _wait(1.0)
	await _shot("12_thirst")
	_pause()
	await _wait(0.4)
	await _shot("13_pause")
	_resume()
	vitals.health = 0.3
	await _wait(3.0)
	await _shot("14_death")
	_respawn()
	await _wait(0.5)
	await _shot("15_respawn")
	# Time of day.
	_aim(0.4, 0.05)
	daynight.phase = 0.47
	await _wait(0.4)
	await _shot("16_sunset")
	daynight.phase = 0.72
	await _wait(0.4)
	await _shot("17_night")
	daynight.phase = 0.2
	# A worn-out hook breaks and is gone; a new one is made in the bag.
	_select("hook")
	actions.use_tool("hook", 44)
	await _wait(0.2)
	await _shot("70_wear")
	actions.use_tool("hook", 5)
	print("hook broke: ", inv.count("hook") == 0, " hand '", hand, "'")
	inv.add("plank", 2)
	inv.add("rope", 2)
	inv.add("plastic", 2)
	for r: Dictionary in Data.recipes:
		if r["id"] == "hook":
			_craft(r)
	print("new hook: ", inv.count("hook"), " wear left ", actions.wear.uses_left("hook", 45))
	# Worlds: save as a second one, the menu, the list, the name box, load the first back.
	var first := world
	var tiles_first := raft.cells().size()
	var parts_first := raft.parts.to_list().size()
	var stations_first := raft.stations.size()
	_pause()
	await _wait(0.3)
	menus.save_as.emit("Второй плот")
	await _wait(0.3)
	await _shot("53_saved_as")
	print("worlds ", SaveGame.worlds().size(), " current ", _world_name())
	menus.to_menu.emit()
	await _wait(0.6)
	await _shot("54_menu")
	menus.show_worlds()
	await _wait(0.3)
	await _shot("55_worlds")
	menus.ask_name("Новый мир", SaveGame.next_name(), "Начать", func(_n: String) -> void: pass, menus.show_main)
	await _wait(0.3)
	await _shot("56_name")
	menus.play_world.emit(first)
	await _wait(0.6)
	print("world back ", _world_name(), " tiles ", raft.cells().size(), " was ", tiles_first)
	print("parts ", raft.parts.to_list().size(), " was ", parts_first, " stations ", raft.stations.size(), " was ", stations_first)
	print("island after load ", trips.islands.island != null)
	print("world names ", SaveGame.worlds().map(func(w: Dictionary) -> String: return w["name"]))
	print("CAPTURE DONE")
	get_tree().quit()
