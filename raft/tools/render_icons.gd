extends Node
## Renders a 192 px icon of every item and buildable into assets/icons/<id>.png.
## Run with a window (xvfb):  godot --path . res://tools/render_icons.tscn
## A close look at a few:  ... -- --only lantern,crossbow --size 512 --out <dir under res://>

const VIEW_DIR := Vector3(1.0, 0.95, 1.35)
const STAIRS_VIEW := Vector3(1.25, 0.7, -1.3)

var size := 192
var out_dir := "assets/icons"


func _ready() -> void:
	var ids: Array = Data.items.keys()
	for d: Dictionary in Data.build:
		ids.append(d["id"])
	ids.append("parrot")
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		match args[i]:
			"--only":
				ids = Array(args[i + 1].split(","))
			"--size":
				size = int(args[i + 1])
			"--out":
				out_dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out_dir))
	for id: String in ids:
		await _render(id)
	print("icons: ", ids.size())
	get_tree().quit()


func _render(id: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(size, size)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c8d8e0")
	env.ambient_light_energy = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(30), 0)
	sun.light_energy = 1.35
	vp.add_child(sun)
	var root := Node3D.new()
	vp.add_child(root)
	var model: Node3D
	if id == "parrot":
		var bird := Parrot.new()
		bird.rotation.y = -0.5
		root.add_child(bird)
		model = bird
		await get_tree().create_timer(0.1).timeout
	elif Looks.MODELS.has(id):
		model = Mk.model(root, Looks.MODELS[id][0])
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = Looks.mesh(id + "_icon" if id in ["rod", "spear", "metal_spear", "metal_rod", "sail", "crossbow"] else id)
		root.add_child(mi)
		model = mi
	if id in ["rod", "spear", "metal_spear", "metal_rod"]:
		model.rotation = Vector3(0, 0, -0.7)
	elif id == "leaf":
		model.rotation = Vector3(0.9, 0.6, 0)
	elif id in ["hook", "hammer", "metal_hook"]:
		model.rotation = Vector3(0, 0, -0.5)
	var box := _aabb(root)
	var center := box.get_center()
	var radius := box.size.length() * 0.5
	var cam := Camera3D.new()
	cam.fov = 28.0
	vp.add_child(cam)
	var dist := radius / sin(deg_to_rad(cam.fov * 0.5)) * 1.02
	# Stairs climb toward +Z: look at them from the foot, where the steps show.
	var view := STAIRS_VIEW if id in RaftParts.STAIRS else VIEW_DIR
	cam.look_at_from_position(center + view.normalized() * dist, center, Vector3.UP)
	cam.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://%s/%s.png" % [out_dir, id]))
	vp.queue_free()


func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var b := mi.global_transform * mi.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out
