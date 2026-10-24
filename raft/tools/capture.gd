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
	print("CAPTURE DONE")
	get_tree().quit()
