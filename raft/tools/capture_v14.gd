extends RefCounted
## The capture bot, v0.14: the crossbow (reload, shot), decor set down freely (several to a
## cell, overlaps refused), the big grill with three fish, the new walls and wall things,
## and the shark finding its way round an island. Called from tools/capture.gd.


func run(g: Variant) -> void:
	var raft: Raft = g.raft
	var parts: RaftParts = raft.parts
	var cc := func(x: int, z: int) -> Vector3: return raft.cell_center(Vector2i(x, z))
	await _shark_round_island(g)
	# The crossbow: reload, the bolt on it, a shot at the shark.
	g.inv.add("crossbow")
	g.inv.add("bolt", 6)
	g._select("crossbow")
	g.player.place(cc.call(5, 1), PI)
	g._aim(PI * 0.5, -0.05)
	await g._wait(0.3)
	print("crossbow: ", g.action_view()["label"])
	g._on_pressed("action")
	g._on_released("action")
	await g._wait(0.3)
	print("crossbow while loading: ", g.action_view()["label"])
	await g._wait(1.2)
	print("crossbow loaded: ", g.action_view()["label"], " bolts left ", g.inv.count("bolt"))
	await g._shot("95_crossbow_loaded")
	var sh: Shark = g.shark
	sh.enabled = true
	sh.visible = true
	sh.state = Shark.State.CIRCLE
	sh._timer = 30.0
	var eye: Vector3 = g.player.cam.global_position
	var fwd: Vector3 = -g.player.cam.global_basis.z
	var flat := Vector3(fwd.x, 0, fwd.z).normalized()
	sh.global_position = Vector3(eye.x, 0, eye.z) + flat * 11.0
	var hits := sh.hits_left()
	await g._wait(0.1)
	g._aim_local(raft.to_local(sh.global_position) + Vector3(0, 0.3, 0))
	g._on_pressed("action")
	g._on_released("action")
	await g._wait(0.12)
	await g._shot("96_crossbow_shot")
	await g._wait(0.4)
	print("shark hit by a bolt from 11 m: ", sh.hits_left() < hits, " button now: ", g.action_view()["label"])
	await g._shot("97_crossbow_reload")
	sh.reset(600.0)
	# The spear reaches less far now.
	g.inv.add("spear")
	g._select("spear")
	sh.visible = true
	sh.state = Shark.State.CIRCLE
	sh._timer = 30.0
	sh.global_position = Vector3(eye.x, 0, eye.z) + flat * 4.0
	g.combat.spear_cd = 0.0
	hits = sh.hits_left()
	g.combat.stab()
	print("spear at 4 m hits: ", sh.hits_left() < hits)
	sh.reset(600.0)
	# Decor anywhere: three things in one cell, a fourth refused where one already stands.
	for c: Vector2i in [Vector2i(7, 1), Vector2i(7, 2), Vector2i(8, 1), Vector2i(8, 2)]:
		raft.add_tile(c)
	var c51: Vector3 = cc.call(5, 1)
	var c52: Vector3 = cc.call(5, 2)
	var placed := []
	for e: Array in [["keg", c51 + Vector3(-0.4, 0, -0.4), 0.0], ["stool", c51 + Vector3(0.35, 0, -0.35), 0.4], ["candle", c51 + Vector3(0.45, 0, 0.45), 0.0],
			["bench", c52 + Vector3(0.0, 0, 0.45), PI], ["deck_chair", cc.call(6, 1) + Vector3(0.1, 0, 0.0), 0.5], ["flower_box", cc.call(6, 2) + Vector3(0, 0, 0.5), 0.0],
			["fire_pit", c52 + Vector3(-0.2, 0, -0.35), 0.0], ["mat", c52 + Vector3(0.2, 0, -0.3), 0.3], ["lantern", c51 + Vector3(-0.55, 0, 0.5), 0.0]]:
		placed.append(e[0] if parts.put_free(e[0], Vector2(e[1].x, e[1].z), e[2], 0) else "-" + e[0])
	print("free placed: ", placed)
	print("stool on the keg refused: ", not parts.can_free("stool", Vector2(c51.x - 0.4, c51.z - 0.4), 0.0, 0))
	print("rug over the mat refused: ", not parts.can_free("rug", Vector2(c52.x + 0.2, c52.z - 0.3), 0.0, 0), " table on the mat ok: ",
			parts.can_free("stool", Vector2(c52.x + 0.55, c52.z - 0.3), 0.0, 0))
	g._select("hammer")
	g.builder.kind = "keg"
	g.player.place(cc.call(6, 2) + Vector3(0.3, 0, 0.3), PI)
	g._aim_local(c51 + Vector3(0.0, 0, 0.1))
	await g._wait(0.4)
	print("ghost between keg and stool valid: ", g.builder.valid)
	await g._shot("98_free_ghost")
	g.builder.kind = ""
	g.hand = ""
	g._refresh_hotbar()
	g.player.place(cc.call(7, 2), PI)
	g._aim_local(c51 + Vector3(0, 0.3, 0.6))
	g.player.pitch = -0.45
	g.daynight.phase = 0.25
	await g._wait(0.5)
	await g._shot("99_free_decor")
	g.daynight.phase = 0.62
	await g._wait(2.6)
	await g._shot("100_free_decor_night")
	g.daynight.phase = 0.25
	# The big grill: three fish at once.
	var bg := raft.add_station("big_grill", Vector3i(8, 1, 0), Data.build_by_id["big_grill"])
	g.inv.add("fish", 3)
	g.inv.add("leaf", 2)
	print("big grill choices ", bg.choices(g.inv))
	print("big grill: ", bg.start(g.inv, "fish"), " amount ", bg.amount)
	g.player.place(cc.call(8, 2) + Vector3(0, 0, 0.3), 0.0)
	g._aim_local(bg.position + Vector3(0, 0.95, 0))
	await g._wait(0.6)
	await g._shot("101_big_grill")
	bg.progress = float(bg.def["time"]) - 0.05
	await g._wait(0.3)
	var before: int = g.inv.count("fish_cooked")
	bg.interact(g.inv)
	print("big grill gave ", g.inv.count("fish_cooked") - before, " fried fish")
	# New walls and things on them, a thatched roof.
	for e: Array in [["wall_stone", Vector4i(7, 2, 1, 0)], ["window_shutters", Vector4i(8, 2, 1, 0)], ["half_wall", Vector4i(8, 1, 0, 0)], ["arch", Vector4i(8, 2, 0, 0)]]:
		if parts.can_edge(e[1], false, e[0]):
			parts.add(e[0], e[1])
	for e: Array in [["trophy", Vector4i(7, 2, 2, 0)], ["map", Vector4i(7, 2, 3, 0)], ["lifebuoy", Vector4i(8, 2, 2, 0)]]:
		if parts.can_lamp(e[1]):
			parts.add(e[0], e[1])
	if parts.can_roof(Vector2i(7, 2), 1):
		parts.add("roof_thatch", Vector3i(7, 2, 1))
	print("new walls ", parts.count("wall_stone"), parts.count("window_shutters"), parts.count("half_wall"), parts.count("arch"),
			" wall things ", parts.count("trophy"), parts.count("map"), parts.count("lifebuoy"), " thatch ", parts.count("roof_thatch"))
	g.player.place(cc.call(7, 1) + Vector3(-0.2, 0, -0.3), 0.0)
	g._aim_local(cc.call(7, 2) + Vector3(0.3, 1.4, 0.75))
	await g._wait(0.5)
	await g._shot("102_new_walls")
	g._open_build()
	g.build_panel._show(0)
	await g._wait(0.4)
	g.build_panel._scroller.scroll_vertical = 380
	await g._wait(0.3)
	await g._shot("103_build_more")
	g._close_build()


## The shark starts on the far side of the island next to the raft and has to reach a tile.
func _shark_round_island(g: Variant) -> void:
	var isl: Island = g.trips.islands.island
	if isl == null:
		print("shark round island: no island")
		return
	var sh: Shark = g.shark
	var c := isl.global_position
	var r := isl.outer_radius()
	var mid: Vector3 = g.raft.global_transform * g.raft.centroid()
	var away := Vector3(c.x - mid.x, 0, c.z - mid.z).normalized()
	sh.enabled = true
	sh.visible = true
	sh.global_position = c + away * (r + 3.0)
	sh.state = Shark.State.CIRCLE
	sh._timer = 0.05
	var closest := INF
	var t := 0.0
	while t < 40.0 and sh.state != Shark.State.BITE:
		await g._wait(0.1)
		t += 0.1
		closest = minf(closest, Vector2(sh.global_position.x - c.x, sh.global_position.z - c.z).length())
	print("shark round island: reached the raft ", sh.state == Shark.State.BITE, " in ", snappedf(t, 0.1), " s; closest to the island center ",
			snappedf(closest, 0.1), " (shore ", snappedf(r, 0.1), ")")
	sh.reset(600.0)
