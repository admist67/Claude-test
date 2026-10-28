extends Node
## Renders a 192 px icon of every item and buildable into assets/icons/<id>.png.
## Run with a window (xvfb):  godot --path . res://tools/render_icons.tscn

const SIZE := 192
const VIEW_DIR := Vector3(1.0, 0.95, 1.35)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/icons"))
	var ids: Array = Data.items.keys()
	for d: Dictionary in Data.build:
		ids.append(d["id"])
	for id: String in ids:
		await _render(id)
	print("icons: ", ids.size())
	get_tree().quit()


func _render(id: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
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
	if Looks.MODELS.has(id):
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
	cam.look_at_from_position(center + VIEW_DIR.normalized() * dist, center, Vector3.UP)
	cam.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://assets/icons/%s.png" % id))
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
