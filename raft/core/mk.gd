class_name Mk
## 3D construction helpers: materials, boxes, cylinders and models. Merged meshes use one
## textured atlas material (CC0 textures, see tools/build_atlas.py): a cell per surface
## kind ("wood", "rope", "metal"...), vertex colors tint it.

const GRID := 4
const INSET := 0.012

static var _mats: Dictionary = {}
static var _atlas: StandardMaterial3D
static var _atlas_leaf: StandardMaterial3D
static var _cells: Dictionary = {}


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


## The shared atlas material (one draw call per merged mesh).
static func atlas() -> StandardMaterial3D:
	if _atlas == null:
		_atlas = _make_atlas()
	return _atlas


## Same atlas with alpha cut-out, for leaves.
static func atlas_leaf() -> StandardMaterial3D:
	if _atlas_leaf == null:
		_atlas_leaf = _make_atlas()
		_atlas_leaf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		_atlas_leaf.alpha_scissor_threshold = 0.5
		_atlas_leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _atlas_leaf


static func _make_atlas() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/atlas_albedo.png")
	m.normal_enabled = true
	m.normal_texture = load("res://assets/textures/atlas_normal.jpg")
	m.normal_scale = 0.8
	var rm: Texture2D = load("res://assets/textures/atlas_rm.jpg")
	m.roughness_texture = rm
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.metallic_texture = rm
	m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.metallic = 0.45
	m.roughness = 1.0
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## UV rect of an atlas cell, slightly inset against mipmap bleeding.
static func cell(name: String) -> Rect2:
	if _cells.is_empty():
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/atlas.json"))
		for k: String in d["cells"]:
			var a: Array = d["cells"][k]
			_cells[k] = Vector2(a[0], a[1])
	var c: Vector2 = _cells.get(name, _cells["white"])
	var s := 1.0 / GRID
	return Rect2((c + Vector2(INSET, INSET)) * s, Vector2(1.0 - 2.0 * INSET, 1.0 - 2.0 * INSET) * s)


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


## Maps a face of extent (long, short) metres onto a window of the atlas cell, keeping
## `tpm` metres per cell so the texture density is the same everywhere.
static func _window(r: Rect2, el: float, es: float, tpm: float, seed_v: float) -> Rect2:
	var w := minf(1.0, el / tpm)
	var h := minf(1.0, es / tpm)
	var off := Vector2(fposmod(seed_v * 0.371, 1.0) * (1.0 - w), fposmod(seed_v * 0.613, 1.0) * (1.0 - h))
	return Rect2(r.position + off * r.size, Vector2(w, h) * r.size)


## Appends a textured box. `rot` is an Euler rotation; the texture grain runs along the
## longest side of each face.
static func st_box(st: SurfaceTool, size: Vector3, pos: Vector3, c: Color, cell_name := "white", rot := Vector3.ZERO, tpm := 1.5) -> void:
	var b := Basis.from_euler(rot)
	var h := size / 2.0
	var r := cell(cell_name)
	var faces := [
		[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
		[Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)],
		[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
		[Vector3(0, -1, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	]
	var fi := 0
	for f: Array in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var eu := absf((u * size).length())
		var ev := absf((v * size).length())
		var long_u := eu >= ev
		var win := _window(r, maxf(eu, ev), minf(eu, ev), tpm, pos.x * 3.1 + pos.y * 7.3 + pos.z * 5.7 + fi * 1.7)
		fi += 1
		var corners: Array[Vector3] = []
		var uvs: Array[Vector2] = []
		for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			corners.append(pos + b * ((n + u * s.x + v * s.y) * h))
			var a := (s * 0.5 + Vector2(0.5, 0.5))
			var uv01 := a if long_u else Vector2(a.y, a.x)
			uvs.append(win.position + uv01 * win.size)
		st.set_color(c)
		st.set_normal(b * n)
		for i: int in [0, 2, 1, 0, 3, 2]:
			st.set_uv(uvs[i])
			st.add_vertex(corners[i])


## Appends a textured cylinder along `axis` (local Y rotated by `rot`), with caps.
static func st_cyl(st: SurfaceTool, radius: float, height: float, pos: Vector3, c: Color, cell_name := "white", rot := Vector3.ZERO, seg := 12, tpm := 1.5, bulge := 0.0) -> void:
	var b := Basis.from_euler(rot)
	var r := cell(cell_name)
	var circ := TAU * radius
	var win := _window(r, maxf(circ, height), minf(circ, height), tpm, pos.x * 2.3 + pos.z * 4.1)
	var rings := 4 if bulge > 0.0 else 1
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		for j in rings:
			var y0 := -height / 2.0 + height * j / rings
			var y1 := -height / 2.0 + height * (j + 1) / rings
			var r0 := radius * (1.0 + bulge * sin(PI * float(j) / rings))
			var r1 := radius * (1.0 + bulge * sin(PI * float(j + 1) / rings))
			var p00 := Vector3(cos(a0) * r0, y0, sin(a0) * r0)
			var p10 := Vector3(cos(a1) * r0, y0, sin(a1) * r0)
			var p11 := Vector3(cos(a1) * r1, y1, sin(a1) * r1)
			var p01 := Vector3(cos(a0) * r1, y1, sin(a0) * r1)
			var uv := func(ang: float, y: float) -> Vector2:
				var uu := ang / TAU
				var vv := (y + height / 2.0) / height
				var q := Vector2(uu, vv) if circ >= height else Vector2(vv, uu)
				return win.position + q * win.size
			var quad := [[p00, a0, y0], [p10, a1, y0], [p11, a1, y1], [p00, a0, y0], [p11, a1, y1], [p01, a0, y1]]
			st.set_color(c)
			for q: Array in quad:
				var p: Vector3 = q[0]
				st.set_normal(b * Vector3(p.x, 0, p.z).normalized())
				st.set_uv(uv.call(q[1], q[2]))
				st.add_vertex(pos + b * p)
	# Caps.
	var cap_win := _window(r, radius * 2.0, radius * 2.0, tpm, pos.y)
	for side: float in [-1.0, 1.0]:
		var y := side * height / 2.0
		var rr := radius
		st.set_color(c.darkened(0.08))
		st.set_normal(b * Vector3(0, side, 0))
		for i in seg:
			var a0 := TAU * i / seg
			var a1 := TAU * (i + 1) / seg
			var pts := [Vector3(0, y, 0), Vector3(cos(a0) * rr, y, sin(a0) * rr), Vector3(cos(a1) * rr, y, sin(a1) * rr)]
			if side < 0.0:
				pts = [pts[0], pts[2], pts[1]]
			else:
				pts = [pts[0], pts[1], pts[2]]
			for p: Vector3 in pts:
				st.set_uv(cap_win.position + (Vector2(p.x, p.z) / (2.0 * rr) + Vector2(0.5, 0.5)) * cap_win.size)
				st.add_vertex(pos + b * p)


## A flat quad in the XZ plane (leaves), double-sided via the leaf material.
static func st_quad(st: SurfaceTool, corners: Array, uv_rect: Rect2, c: Color) -> void:
	var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	var n: Vector3 = (corners[1] - corners[0]).cross(corners[3] - corners[0]).normalized()
	st.set_color(c)
	st.set_normal(-n if n.y < 0.0 else n)
	for i: int in [0, 2, 1, 0, 3, 2]:
		st.set_uv(uv_rect.position + uvs[i] * uv_rect.size)
		st.add_vertex(corners[i])


static func st_begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func st_commit(st: SurfaceTool, leaf := false) -> ArrayMesh:
	st.generate_tangents()
	var m := st.commit()
	m.surface_set_material(0, atlas_leaf() if leaf else atlas())
	return m
