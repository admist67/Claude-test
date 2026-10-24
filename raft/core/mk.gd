class_name Mk
## Small 3D construction helpers: materials, boxes, models, vertex-colored merged meshes.

static var _mats: Dictionary = {}
static var _vc_mat: StandardMaterial3D


static func mat(c: Color, rough := 0.85) -> StandardMaterial3D:
	var key := "%s/%.2f" % [c.to_html(), rough]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		if c.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mats[key] = m
	return _mats[key]


## One material for all vertex-colored merged meshes (raft tiles, debris).
static func vc_mat() -> StandardMaterial3D:
	if _vc_mat == null:
		_vc_mat = StandardMaterial3D.new()
		_vc_mat.vertex_color_use_as_albedo = true
		_vc_mat.vertex_color_is_srgb = true
		_vc_mat.roughness = 0.9
	return _vc_mat


static func box(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = m
	parent.add_child(mi)
	return mi


static func model(parent: Node3D, path: String, pos := Vector3.ZERO, s := 1.0) -> Node3D:
	var n: Node3D = load(path).instantiate()
	n.position = pos
	n.scale = Vector3.ONE * s
	parent.add_child(n)
	return n


## Appends a box (optionally rotated around Y by `yaw`) to a SurfaceTool with a flat color.
static func st_box(st: SurfaceTool, size: Vector3, pos: Vector3, c: Color, yaw := 0.0, roll := 0.0) -> void:
	var b := Basis.from_euler(Vector3(0, yaw, roll))
	var h := size / 2.0
	var faces := [
		[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
		[Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)],
		[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
		[Vector3(0, -1, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	]
	for f: Array in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var shade := c.darkened(0.12) if n.y < 0.5 and n.y > -0.5 else (c if n.y > 0 else c.darkened(0.3))
		var corners: Array[Vector3] = []
		for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			corners.append(pos + b * ((n + u * s.x + v * s.y) * h))
		st.set_color(shade)
		st.set_normal(b * n)
		for i: int in [0, 2, 1, 0, 3, 2]:
			st.add_vertex(corners[i])


static func st_begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func st_commit(st: SurfaceTool) -> ArrayMesh:
	var m := st.commit()
	m.surface_set_material(0, vc_mat())
	return m
