class_name IslandLooks
## Island visuals: the sand-and-grass ground (its own tiling shader), palms with coconuts,
## banana and pineapple plants, rocks, a driftwood log and a sea chest (atlas meshes).

## Radial profile of the ground: [fraction of the radius, height above the sea].
const PROFILE := [[0.0, 0.95], [0.2, 0.92], [0.4, 0.84], [0.55, 0.7], [0.68, 0.5], [0.8, 0.27], [0.9, 0.09], [1.0, -0.14], [1.12, -0.55], [1.3, -1.4], [1.6, -3.2]]
const SEG := 40
const TRUNK := Color("#9a7a58")
const LEAF := Color(0.95, 1.05, 0.85)

static var _ground_mat: ShaderMaterial


static func ground_material() -> ShaderMaterial:
	if _ground_mat == null:
		_ground_mat = ShaderMaterial.new()
		_ground_mat.shader = load("res://systems/islands/island.gdshader")
		_ground_mat.set_shader_parameter("sand_tex", load("res://assets/textures/sand.jpg"))
		_ground_mat.set_shader_parameter("grass_tex", load("res://assets/textures/grass.jpg"))
	return _ground_mat


## How far the shore reaches in direction `a` (radians), as a multiple of the radius.
static func shore(a: float, wob: Array) -> float:
	return 1.0 + wob[0] * sin(2.0 * a + wob[1]) + wob[2] * sin(3.0 * a + wob[3]) + wob[4] * sin(5.0 * a + wob[5])


## Ground height above the sea at island-local (x, z).
static func height(p: Vector2, radius: float, wob: Array) -> float:
	var f := p.length() / (radius * shore(atan2(p.y, p.x), wob))
	for i in PROFILE.size() - 1:
		var a: Array = PROFILE[i]
		var b: Array = PROFILE[i + 1]
		if f <= float(b[0]):
			return lerpf(a[1], b[1], (f - float(a[0])) / (float(b[0]) - float(a[0])))
	return PROFILE[-1][1]


## The ground: rings of the profile around the center, wobbly shore; grass on top, wet
## sand at the waterline (vertex colors for the shader).
static func ground(radius: float, wob: Array, rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	var cols: Array = []
	for pr: Array in PROFILE:
		var ring: Array[Vector3] = []
		var col: Array[Color] = []
		for j in SEG:
			var a := TAU * j / SEG
			var r := radius * float(pr[0]) * shore(a, wob)
			var h := float(pr[1]) + (rng.randf_range(-0.04, 0.04) if float(pr[0]) < 0.9 else 0.0)
			ring.append(Vector3(cos(a) * r, h, sin(a) * r))
			var grass := 1.0 - smoothstep(0.42, 0.62, float(pr[0]) + rng.randf_range(-0.06, 0.06))
			col.append(Color(grass, clampf((0.14 - h) / 0.45, 0.0, 1.0), 0.0))
		rings.append(ring)
		cols.append(col)
	for i in rings.size() - 1:
		for j in SEG:
			var j2 := (j + 1) % SEG
			var q: Array[Vector3] = [rings[i][j], rings[i][j2], rings[i + 1][j2], rings[i + 1][j]]
			var qc: Array[Color] = [cols[i][j], cols[i][j2], cols[i + 1][j2], cols[i + 1][j]]
			for k: int in [0, 2, 1, 0, 3, 2]:
				st.set_color(qc[k])
				st.add_vertex(q[k])
	st.generate_normals()
	var m := st.commit()
	m.surface_set_material(0, ground_material())
	return m


## A curved palm trunk; returns [trunk mesh, crown (leaves) mesh, coconuts mesh, top point].
static func palm(rng: RandomNumberGenerator) -> Array:
	var h := rng.randf_range(4.2, 5.6)
	var lean := rng.randf_range(0.5, 1.5)
	var yaw := rng.randf() * TAU
	var dir := Vector3(cos(yaw), 0, sin(yaw))
	var pts: Array[Vector3] = []
	for i in 10:
		var u := i / 9.0
		pts.append(dir * lean * u * u + Vector3(0, h * u, 0))
	var st := Mk.st_begin()
	for i in 9:
		var a := pts[i]
		var b := pts[i + 1]
		var r := lerpf(0.2, 0.13, i / 8.0)
		_cyl_between(st, a, b, r, TRUNK.darkened(0.12 if i % 2 == 0 else 0.0), "wood_dark")
	var trunk := Mk.st_commit(st)
	var top := pts[9]
	var lst := Mk.st_begin()
	var n := rng.randi_range(8, 10)
	for k in n:
		var a := k * TAU / n + rng.randf_range(-0.2, 0.2)
		_frond(lst, top, Vector3(cos(a), 0, sin(a)), rng.randf_range(2.0, 2.7), rng.randf_range(0.15, 0.4))
	var crown := Mk.st_commit(lst, true)
	var nst := Mk.st_begin()
	for k in 4:
		var a := k * TAU / 4.0 + 0.4
		Mk.st_cyl(nst, 0.13, 0.22, top + Vector3(cos(a) * 0.17, -0.28, sin(a) * 0.17), Color("#7a5532"), "clay", Vector3(0.3, a, 0), 10, 1.0, 0.6)
	return [trunk, crown, Mk.st_commit(nst), top]


## A drooping frond from `at` along the flat direction `d`, `lift` of upward curve.
static func _frond(st: SurfaceTool, at: Vector3, d: Vector3, length: float, lift: float, tint := LEAF) -> void:
	var r := Mk.cell("palm")
	var side := Vector3(-d.z, 0, d.x)
	var segs := 4
	for i in segs:
		var u0 := float(i) / segs
		var u1 := float(i + 1) / segs
		var p0 := at + d * length * u0 + Vector3(0, lift * u0 - 1.1 * u0 * u0, 0)
		var p1 := at + d * length * u1 + Vector3(0, lift * u1 - 1.1 * u1 * u1, 0)
		var w0 := 0.5 * sin(PI * (0.12 + 0.8 * u0)) + 0.06
		var w1 := 0.5 * sin(PI * (0.12 + 0.8 * u1)) + 0.06
		var sub := Rect2(r.position + Vector2(0, r.size.y * (1.0 - u1)), Vector2(r.size.x, r.size.y / segs))
		Mk.st_quad(st, [p0 + side * w0, p0 - side * w0, p1 - side * w1, p1 + side * w1], sub, tint)


## A cylinder from a to b (Y axis of st_cyl turned onto the segment).
static func _cyl_between(st: SurfaceTool, a: Vector3, b: Vector3, r: float, c: Color, cell: String) -> void:
	var d := b - a
	var up := Vector3.UP
	var axis := up.cross(d.normalized())
	var rot := Vector3.ZERO
	if axis.length() > 0.0001:
		rot = Basis(axis.normalized(), up.angle_to(d.normalized())).get_euler()
	Mk.st_cyl(st, r, d.length() + 0.02, (a + b) / 2.0, c, cell, rot, 10, 1.2)


## A banana plant: [leaves mesh, bunch mesh].
static func banana(rng: RandomNumberGenerator) -> Array:
	var st := Mk.st_begin()
	for k in 3:
		var a := k * TAU / 3.0 + rng.randf()
		var base := Vector3(cos(a) * 0.12, 0, sin(a) * 0.12)
		_cyl_between(st, base, base + Vector3(0, 1.3 + k * 0.15, 0), 0.07, Color("#7c9a4a"), "white")
	var stem := Mk.st_commit(st)
	var lst := Mk.st_begin()
	for k in 7:
		var a := k * TAU / 7.0 + rng.randf_range(-0.2, 0.2)
		_frond(lst, Vector3(0, 1.35 + (k % 3) * 0.12, 0), Vector3(cos(a), 0, sin(a)), rng.randf_range(1.1, 1.5), 0.9, Color(1.1, 1.25, 0.8))
	var leaves := Mk.st_commit(lst, true)
	var bst := Mk.st_begin()
	_cyl_between(bst, Vector3(0.18, 1.35, 0), Vector3(0.24, 0.95, 0), 0.025, Color("#6a7a3a"), "white")
	for k in 9:
		var a := k * TAU / 4.5
		var y := 1.25 - k * 0.035
		Mk.st_box(bst, Vector3(0.06, 0.2, 0.06), Vector3(0.22 + cos(a) * 0.08, y, sin(a) * 0.08), Color("#f2d24a"), "white", Vector3(0.0, -a, 0.5))
	return [stem, leaves, Mk.st_commit(bst)]


## A pineapple plant: spiky leaves (the fruit is the food model).
static func pineapple_leaves(rng: RandomNumberGenerator) -> ArrayMesh:
	var st := Mk.st_begin()
	var r := Mk.cell("palm")
	for k in 11:
		var a := k * TAU / 11.0 + rng.randf_range(-0.15, 0.15)
		var b := Basis(Vector3.UP, a)
		var l := rng.randf_range(0.5, 0.75)
		Mk.st_quad(st, [b * Vector3(-0.05, 0.02, 0.0), b * Vector3(0.05, 0.02, 0.0), b * Vector3(0.03, l * 0.75, l), b * Vector3(-0.03, l * 0.75, l)], r, Color(0.75, 0.95, 0.65))
	return Mk.st_commit(st, true)


## A rock of a few chunky lumps; returns [mesh, rough size].
static func rock(rng: RandomNumberGenerator) -> Array:
	var st := Mk.st_begin()
	var s := rng.randf_range(0.7, 1.05)
	for k in 4:
		var size := Vector3(rng.randf_range(0.5, 0.9), rng.randf_range(0.35, 0.7), rng.randf_range(0.5, 0.9)) * s
		var at := Vector3(rng.randf_range(-0.3, 0.3), size.y * 0.35, rng.randf_range(-0.3, 0.3)) * s
		var g := rng.randf_range(0.82, 1.0)
		Mk.st_box(st, size, at, Color(g, g, g * 0.97), "rock", Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4)), 1.2)
	return [Mk.st_commit(st), Vector3(1.3, 0.8, 1.3) * s]


## A bleached driftwood log lying along X.
static func log_mesh() -> ArrayMesh:
	var st := Mk.st_begin()
	var c := Color("#c9b9a0")
	Mk.st_cyl(st, 0.22, 2.3, Vector3(0, 0.18, 0), c, "wood", Vector3(0, 0, PI / 2.0), 10, 1.5)
	Mk.st_cyl(st, 0.07, 0.6, Vector3(0.4, 0.38, 0.12), c.darkened(0.1), "wood", Vector3(0.5, 0, 0.6), 6, 1.5)
	Mk.st_cyl(st, 0.06, 0.45, Vector3(-0.6, 0.35, -0.1), c.darkened(0.1), "wood", Vector3(-0.6, 0, -0.5), 6, 1.5)
	return Mk.st_commit(st)


## A sea chest: [body mesh, lid mesh (hinged at its back edge, local origin on the hinge)].
static func chest() -> Array:
	var st := Mk.st_begin()
	var wood := Color(0.95, 0.85, 0.75)
	var iron := Color(0.55, 0.52, 0.5)
	Mk.st_box(st, Vector3(0.9, 0.45, 0.58), Vector3(0, 0.225, 0), wood, "wood_warm")
	for x: float in [-0.3, 0.3]:
		Mk.st_box(st, Vector3(0.06, 0.47, 0.6), Vector3(x, 0.235, 0), iron, "metal")
	var body := Mk.st_commit(st)
	var lst := Mk.st_begin()
	Mk.st_box(lst, Vector3(0.92, 0.16, 0.6), Vector3(0, 0.08, 0.3), wood.darkened(0.1), "wood_warm")
	for x: float in [-0.3, 0.3]:
		Mk.st_box(lst, Vector3(0.06, 0.18, 0.62), Vector3(x, 0.08, 0.3), iron, "metal")
	Mk.st_box(lst, Vector3(0.12, 0.12, 0.04), Vector3(0, 0.0, 0.61), Color(0.8, 0.7, 0.4), "metal")
	return [body, Mk.st_commit(lst)]
