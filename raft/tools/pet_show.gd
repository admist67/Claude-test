extends "res://scenes/main.gd"
## The parrot's day on a small clean raft, frame by frame: on its perch, fed by hand,
## eating from the bowl, back from the sea with a find, screaming over the shark, asleep.
## Run with a window (xvfb):  godot --path . res://tools/pet_show.tscn -- --out <dir>

var out_dir := ".studioigor/captures/pet_show"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		if args[i] == "--out":
			out_dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out_dir))
	SaveGame.dir = "user://pet_show/"
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


func _look(p: Vector3) -> void:
	var d := raft.to_global(p) - player.cam.global_position
	player.yaw = atan2(-d.x, -d.z)
	player.pitch = atan2(d.y, Vector2(d.x, d.z).length())


func _run() -> void:
	await _wait(1.0)
	menus.new_game.emit("Попугай")
	await _wait(1.0)
	shark.enabled = false
	daynight.phase = 0.3
	for x in range(-1, 3):
		for z in range(-1, 2):
			raft.add_tile(Vector2i(x, z))
	var cc := func(x: int, z: int) -> Vector3: return raft.cell_center(Vector2i(x, z))
	for e: Array in [["railing", Vector4i(2, -1, 0, 0)], ["railing", Vector4i(2, 0, 0, 0)], ["wall", Vector4i(-1, -2, 1, 0)], ["wall", Vector4i(0, -2, 1, 0)]]:
		if raft.parts.can_edge(e[1], false, e[0]):
			raft.parts.add(e[0], e[1])
	var perch := raft.parts.put_free("perch", Vector2(cc.call(0, -1).x, cc.call(0, -1).z), 0.0, 0)
	raft.parts.put_free("table", Vector2(cc.call(2, 1).x, cc.call(2, 1).z), 0.0, 0)
	raft.parts.put_free("lantern", Vector2(cc.call(1, -1).x + 0.4, cc.call(1, -1).z - 0.4), 0.0, 0)
	pets.from_dict({"tamed": true, "name": "Кеша", "satiety": 80.0})
	var pet := pets.pet
	pets._move_t = 999.0
	pets._fetch_t = 999.0
	pets._talk_t = 999.0
	hand = ""
	_refresh_hotbar()
	# On its perch.
	pet.position = pets._perch_spot(perch)
	player.place(cc.call(1, 1) + Vector3(0.2, 0, 0.3), 0.0)
	_look(pet.position + Vector3(0, 0.1, 0))
	pet.face_to(raft.to_local(player.global_position))
	await _wait(0.8)
	pets.say("Кеша хороший!")
	await _wait(0.5)
	await _shot("1_perch")
	# Fed by hand on the deck.
	pet.position = cc.call(1, 0) + Vector3(0.0, 0, 0.0)
	player.place(cc.call(1, 1) + Vector3(0.0, 0, 0.4), 0.0)
	_look(pet.position + Vector3(0, 0.3, 0))
	pet.face_to(raft.to_local(player.global_position))
	inv.add("banana", 2)
	pets.satiety = 40.0
	await _wait(0.6)
	print("prompt ", use_view()["label"])
	_on_pressed("use")
	await _wait(0.5)
	await _shot("2_feed")
	# The bowl.
	inv.add("pineapple", 2)
	pets.fill_bowl(perch)
	pets.fill_bowl(perch)
	pets.satiety = 40.0
	player.place(cc.call(1, 0) + Vector3(0.2, 0, 0.6), 0.0)
	_look(perch.position + Vector3(-0.2, 1.0, 0))
	await _wait(2.6)
	await _shot("3_bowl")
	# Back from the sea with a find in its beak.
	pets.satiety = 90.0
	pets._fetch_t = 0.0
	var t := 0.0
	while not (pets._task == "back" and pet.position.distance_to(raft.to_local(player.global_position)) < 5.0) and t < 30.0:
		await _wait(0.1)
		t += 0.1
		if pets._task == "back":
			_look(pet.position)
	await _shot("4_find")
	while pets._task == "back" and t < 40.0:
		await _wait(0.1)
		t += 0.1
	await _wait(0.6)
	await _shot("5_gift")
	# The shark.
	shark.enabled = true
	shark.visible = true
	shark.state = Shark.State.CIRCLE
	shark._timer = 30.0
	shark.global_position = raft.to_global(cc.call(2, 1) + Vector3(3.5, 0, 0))
	pets._on_shark(Vector2i(2, 1))
	player.place(cc.call(0, 0), 0.0)
	await _wait(1.6)
	_look(pet.position + Vector3(0, -0.6, 0))
	await _wait(0.3)
	await _shot("6_shark")
	shark.reset(600.0)
	pets._task = ""
	# Night on the perch.
	daynight.phase = 0.74
	await _wait(4.0)
	player.place(cc.call(1, 0) + Vector3(0.2, 0, 0.3), 0.0)
	_look(pets._perch_spot(perch) + Vector3(0, 0.15, 0))
	await _wait(0.6)
	print("asleep ", pet.mode == Parrot.Mode.SLEEP)
	await _shot("7_sleep")
	get_tree().quit()
