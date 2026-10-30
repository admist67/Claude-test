extends "res://scenes/main.gd"
## Quick check of the parrot's day on a fresh raft: prints what it is doing every second.


func _ready() -> void:
	SaveGame.dir = "user://pet_debug/"
	SaveGame.clear_all()
	super()
	_run()


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	menus.new_game.emit("Попугай")
	await get_tree().create_timer(1.0).timeout
	shark.enabled = false
	for x in range(-1, 3):
		for z in range(-1, 3):
			raft.add_tile(Vector2i(x, z))
	pets.from_dict({"tamed": true, "name": "Кеша", "satiety": 90.0})
	pets._fetch_t = 2.0
	for i in 40:
		await get_tree().create_timer(1.0).timeout
		var p := pets.pet
		print("t%d task '%s' mode %d pos %s task_t %.1f fetch_t %.1f mode_game %d gifts %d night %s" % [i, pets._task, p.mode, p.position.round(), pets._task_t,
				pets._fetch_t, mode, int(stats.get("parrot_gifts", 0)), daynight.is_night()])
	get_tree().quit()
