extends "res://scenes/main.gd"
## Load check: the same raft by day, at sunset and at night (lanterns lit), looking along
## the deck and out to sea. Saves a frame of each and prints draw calls, primitives and the
## frame rate (uncapped, so it shows the render cost on this machine).
## Run with a window (xvfb):  godot --path . res://tools/perf.tscn -- --out <dir>

var out_dir := ".studioigor/captures/perf"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out":
			out_dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out_dir))
	SaveGame.dir = "user://perf_saves/"
	SaveGame.clear_all()
	super()
	_run()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _run() -> void:
	await _wait(1.0)
	menus.new_game.emit("Замер")
	await _wait(1.0)
	Engine.max_fps = 0
	var sc := OS.get_cmdline_user_args().find("--scale")
	if sc >= 0:
		get_viewport().scaling_3d_scale = float(OS.get_cmdline_user_args()[sc + 1])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	shark.enabled = false
	for x in range(-1, 4):
		for z in range(-1, 3):
			raft.add_tile(Vector2i(x, z))
	var parts := raft.parts
	for e: Array in [["wall", Vector4i(-2, 0, 0, 0)], ["window", Vector4i(-2, 1, 0, 0)], ["wall", Vector4i(0, 2, 1, 0)], ["railing", Vector4i(3, 0, 0, 0)]]:
		if parts.can_edge(e[1], false, e[0]):
			parts.add(e[0], e[1])
	for c: Vector2i in [Vector2i(-1, 0), Vector2i(-1, 1)]:
		if parts.can_roof(c, 1):
			parts.add("roof", Vector3i(c.x, c.y, 1))
	raft.add_station("grill", Vector3i(1, 1, 0), Data.build_by_id["grill"])
	raft.add_station("purifier", Vector3i(2, 1, 0), Data.build_by_id["purifier"])
	for e: Array in [["lantern", Vector2(0.9, 0.9)], ["lantern_tall", Vector2(4.1, -0.9)], ["torch", Vector2(-1.9, 2.9)], ["lantern", Vector2(2.9, 2.9)],
			["table", Vector2(0.0, 0.0)], ["stool", Vector2(0.9, -0.5)], ["keg", Vector2(3.7, 0.4)]]:
		parts.put_free(e[0], e[1], 0.0, 0)
	player.place(raft.cell_center(Vector2i(0, 1)), 0.0)
	var views := [["deck", PI * 0.75, -0.35], ["sea", 0.2, -0.08], ["sun", 1.02, -0.12]]
	if "--sun" in OS.get_cmdline_user_args():
		views = [["sun", 1.02, -0.12]]
	for view: Array in views:
		for tod: Array in [["day", 0.25], ["sunset", 0.47], ["night", 0.72]]:
			daynight.phase = tod[1]
			player.yaw = view[1]
			player.pitch = view[2]
			await _wait(2.5)
			# Freeze the waves and the sky so frames compare pixel for pixel between runs.
			Ocean.time = 50.0
			ocean._process(0.0)
			get_tree().paused = true
			if "--nosun" in OS.get_cmdline_user_args():
				ocean._mat.set_shader_parameter("sun_light", Vector3.ZERO)
			await _measure("%s_%s" % [view[0], tod[0]])
			get_tree().paused = false
	print("PERF DONE")
	get_tree().quit()


func _measure(n: String) -> void:
	var frames := 0
	var t0 := Time.get_ticks_usec()
	var draws := 0
	var prims := 0
	while Time.get_ticks_usec() - t0 < 2_000_000:
		await RenderingServer.frame_post_draw
		frames += 1
		draws = maxi(draws, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		prims = maxi(prims, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	var fps := frames / ((Time.get_ticks_usec() - t0) / 1e6)
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://%s/%s.png" % [out_dir, n]))
	print("PERF %s fps %.1f draws %d prims %d" % [n, fps, draws, prims])
