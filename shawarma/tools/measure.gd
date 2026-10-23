extends SceneTree
## Prints the bounding box size of every imported model: godot --headless -s res://tools/measure.gd


func _aabb(n: Node, xf: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	var t := xf
	if n is Node3D:
		t = xf * n.transform
	if n is MeshInstance3D and n.mesh:
		box = t * n.mesh.get_aabb()
		first = false
	for c in n.get_children():
		var b := _aabb(c, t)
		if b.size != Vector3.ZERO:
			box = b if first else box.merge(b)
			first = false
	return box


func _init() -> void:
	for dir in ["characters", "food", "furniture", "city", "roads", "market"]:
		var d := DirAccess.open("res://assets/models/" + dir)
		for f in d.get_files():
			if f.ends_with(".glb"):
				var ps: PackedScene = load("res://assets/models/%s/%s" % [dir, f])
				var inst := ps.instantiate()
				var b := _aabb(inst, Transform3D.IDENTITY)
				print("%s/%s size=%s pos=%s" % [dir, f, b.size.snappedf(0.01), b.position.snappedf(0.01)])
				inst.free()
	quit()
