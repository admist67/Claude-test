extends Node3D
## A close look at the parrot: perched (side and front), flying, sleeping, on its stand.
## Run with a window (xvfb):  godot --path . res://tools/pet_look.tscn -- --out <dir>

var out_dir := ".studioigor/captures/pet"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		if args[i] == "--out":
			out_dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out_dir))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#9cc8dc")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c8d8e0")
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-45), deg_to_rad(35), 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	var stand := MeshInstance3D.new()
	stand.mesh = Looks.mesh("perch")
	add_child(stand)
	var p := Parrot.new()
	p.position = Vector3(0.12, 1.245, 0)
	add_child(p)
	var cam := Camera3D.new()
	cam.fov = 40
	add_child(cam)
	cam.current = true
	_run(p, cam)


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://%s/%s.png" % [out_dir, n]))


func _run(p: Parrot, cam: Camera3D) -> void:
	var c := p.position + Vector3(0, 0.25, 0)
	await get_tree().create_timer(0.5).timeout
	cam.look_at_from_position(c + Vector3(0.9, 0.15, 0.25), c)
	await _shot("side")
	cam.look_at_from_position(c + Vector3(0.2, 0.2, -0.95), c)
	await _shot("front")
	p.dance()
	await get_tree().create_timer(0.3).timeout
	cam.look_at_from_position(c + Vector3(0.6, 0.5, 0.6), c)
	await _shot("three_quarter")
	cam.look_at_from_position(Vector3(0, 1.0, 3.2), Vector3(0, 0.75, 0))
	await _shot("stand")
	p.fly_to(p.position + Vector3(-3.0, 0.6, 0), 1.0)
	await get_tree().create_timer(0.35).timeout
	cam.look_at_from_position(p.position + Vector3(0.6, 0.7, 1.1), p.position)
	await _shot("fly")
	await p.arrived
	p.sleep(true)
	await get_tree().create_timer(1.0).timeout
	cam.look_at_from_position(p.position + Vector3(0.7, 0.35, 0.5), p.position + Vector3(0, 0.25, 0))
	await _shot("sleep")
	get_tree().quit()
