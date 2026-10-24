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
	SaveGame.path = "user://capture_save.json"
	SaveGame.clear()
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


func _run() -> void:
	await _wait(2.0)
	await _shot("00_menu")
	menus.new_game.emit()
	await _wait(1.5)
	_aim(0.0, -0.12)
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
	_on_released("action")
	await _wait(0.4)
	await _shot("23_caught")
	print("fish: ", inv.count("fish"), " big: ", inv.count("big_fish"))
	# Night with a fire on the grill.
	inv.add("fish", 1)
	_look_cell(Vector2i(0, 1), 0.4)
	await _wait(0.2)
	_on_pressed("use")
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
	inv.add("plank", 80)
	inv.add("rope", 30)
	inv.add("leaf", 30)
	inv.add("plastic", 12)
	var grid: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(2, 0), Vector2i(2, 1), Vector2i(0, 2)]
	grid.append_array([Vector2i(1, 2), Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)])
	for c: Vector2i in grid:
		raft.add_tile(c)
	for c: Vector2i in raft.stations.keys():
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
	await _build_at("planter", cc.call(2, 1))
	player.place(cc.call(1, 1), 0.0)
	await _build_at("hammock", cc.call(1, 2))
	_select("metal_hook")
	_look_cell(Vector2i(2, 1), 0.3)
	await _wait(0.3)
	_on_pressed("use")
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
	print("pineapples ", inv.count("pineapple"), " planted ", stats.get("planted", 0), " harvest ", stats.get("harvest", 0))
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
	print("CAPTURE DONE")
	get_tree().quit()
