class_name FoodLooks
## Fish, shark meat, soup and plastic scraps: smooth lofted bodies with painted textures
## (assets/textures/items.png, made by tools/gen_item_tex.py). A mesh may add a second
## surface on the shared atlas for wood or fruit bits.

const IDS := ["fish", "big_fish", "fish_cooked", "big_fish_cooked", "shark_meat", "shark_steak", "plastic",
		"dried_fish", "fish_soup", "kebab", "trophy"]
const GRID := 4
const CELLS := {
	"fish": Vector2i(0, 0), "fish_cooked": Vector2i(1, 0), "tuna": Vector2i(2, 0), "tuna_cooked": Vector2i(3, 0),
	"fin": Vector2i(0, 1), "fin_cooked": Vector2i(1, 1), "fin_tuna": Vector2i(2, 1), "eyes": Vector2i(3, 1),
	"flesh": Vector2i(0, 2), "meat_side": Vector2i(1, 2), "steak_top": Vector2i(2, 2), "steak_side": Vector2i(3, 2),
	"bottle": Vector2i(0, 3), "crate": Vector2i(1, 3), "dried": Vector2i(2, 3), "soup": Vector2i(3, 3),
}

static var _mat: StandardMaterial3D


## The painted material: a little glossy (wet fish, oily steak), both sides of thin fins.
static func mat() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.albedo_texture = load("res://assets/textures/items.png")
		_mat.vertex_color_use_as_albedo = true
		_mat.vertex_color_is_srgb = true
		_mat.roughness = 0.42
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return _mat


## UV rect of a painted cell, inset a little against bleeding.
static func cell(name: String) -> Rect2:
	var c: Vector2i = CELLS[name]
	var s := 1.0 / GRID
	var inset := 2.0 / 1024.0
	return Rect2(Vector2(c) * s + Vector2(inset, inset), Vector2(s - 2.0 * inset, s - 2.0 * inset))


static func mesh(id: String) -> ArrayMesh:
	var st := Mk.st_begin()
	var at := Mk.st_begin()
	var atlas := false
	match id:
		"fish", "fish_cooked":
			fish(st, 0.27, "fish", id == "fish_cooked")
		"big_fish", "big_fish_cooked":
			fish(st, 0.4, "tuna", id == "big_fish_cooked")
		"dried_fish":
			fish(st, 0.27, "dried", true)
		"shark_meat":
			_slab(st, _outline(0.17, 0.095, 0.3, 0.0, 7), 0.0, 0.1, 0.025, "flesh", "meat_side", Color.WHITE)
		"shark_steak":
			_slab(st, _outline(0.15, 0.115, 0.0, 0.2, 3), 0.0, 0.065, 0.012, "steak_top", "steak_side", Color.WHITE)
		"plastic":
			_plastic(st)
		"fish_soup":
			atlas = true
			_soup(st, at)
		"kebab":
			atlas = true
			_kebab(st, at)
		"trophy":
			# A tuna mounted on a dark wooden plaque with a brass plate, hung on a wall.
			atlas = true
			Mk.st_box(at, Vector3(0.66, 0.4, 0.03), Vector3(0, 1.55, 0.015), Color("#5a3a20"), "wood_dark")
			Mk.st_box(at, Vector3(0.58, 0.32, 0.03), Vector3(0, 1.55, 0.035), Color(1, 0.95, 0.9), "wood_dark")
			Mk.st_box(at, Vector3(0.16, 0.045, 0.008), Vector3(0, 1.425, 0.054), Color("#e0ad4a"), "metal")
			var f := Mk.st_begin()
			fish(f, 0.52, "tuna", false)
			st.append_from(f.commit(), 0, Transform3D(Basis(Vector3.FORWARD, 0.12), Vector3(0.02, 1.58, 0.1)))
	var m := st.commit()
	m.surface_set_material(0, mat())
	if atlas:
		at.generate_tangents()
		at.commit(m)
		m.surface_set_material(1, Mk.atlas())
	return m


## One triangle facing `n` (Godot's front faces wind clockwise seen from outside).
static func _tri(st: SurfaceTool, p: Array, uv: Array, n: Array, c: Color) -> void:
	var face: Vector3 = (p[1] - p[0]).cross(p[2] - p[0])
	var order := [0, 1, 2] if face.dot(n[0] + n[1] + n[2]) < 0.0 else [0, 2, 1]
	for i: int in order:
		st.set_color(c)
		st.set_normal(n[i])
		st.set_uv(uv[i])
		st.add_vertex(p[i])


static func _at(r: Rect2, uv: Vector2) -> Vector2:
	return r.position + uv * r.size


## A smooth body along X. `rings` go from the front: [x, half height, half width, center y,
## texture u]. Texture v runs from the back (0) down to the belly (1) on both sides. The
## front closes in a point at x `tip`, the back with a flat cap.
static func loft(st: SurfaceTool, rings: Array, seg: int, r: Rect2, c: Color, tip: float, belly := 1.0) -> void:
	var pts: Array = []
	var vs: Array = []
	for ring: Array in rings:
		var row: Array = []
		for j in seg:
			var a := PI / 2.0 + TAU * j / seg
			var s := sin(a)
			row.append(Vector3(ring[0], ring[3] + s * ring[1] * (belly if s < 0.0 else 1.0), cos(a) * ring[2]))
		pts.append(row)
	for j in seg:
		vs.append(0.5 - 0.5 * sin(PI / 2.0 + TAU * j / seg))
	var nr := pts.size()
	var nor: Array = []
	for i in nr:
		var row: Array = []
		for j in seg:
			var along: Vector3 = pts[mini(i + 1, nr - 1)][j] - pts[maxi(i - 1, 0)][j]
			var around: Vector3 = pts[i][(j + 1) % seg] - pts[i][(j - 1 + seg) % seg]
			var n := along.cross(around).normalized()
			if n.dot(pts[i][j] - Vector3(rings[i][0], rings[i][3], 0)) < 0.0:
				n = -n
			row.append(n)
		nor.append(row)
	for i in nr - 1:
		var u0: float = rings[i][4]
		var u1: float = rings[i + 1][4]
		for j in seg:
			var k := (j + 1) % seg
			var p := [pts[i][j], pts[i + 1][j], pts[i + 1][k], pts[i][k]]
			var uv := [_at(r, Vector2(u0, vs[j])), _at(r, Vector2(u1, vs[j])), _at(r, Vector2(u1, vs[k])), _at(r, Vector2(u0, vs[k]))]
			var n := [nor[i][j], nor[i + 1][j], nor[i + 1][k], nor[i][k]]
			_tri(st, [p[0], p[1], p[2]], [uv[0], uv[1], uv[2]], [n[0], n[1], n[2]], c)
			_tri(st, [p[0], p[2], p[3]], [uv[0], uv[2], uv[3]], [n[0], n[2], n[3]], c)
	for end in 2:
		var i := 0 if end == 0 else nr - 1
		var ring: Array = rings[i]
		var nb: Array = rings[1] if end == 0 else rings[nr - 2]
		var cx: float = tip if end == 0 else ring[0]
		var cp := Vector3(cx, ring[3], 0)
		var cn := Vector3(signf(float(ring[0]) - float(nb[0])), 0, 0)
		var cuv := _at(r, Vector2(ring[4], 0.5))
		for j in seg:
			var k := (j + 1) % seg
			var en: Vector3 = cn if end == 1 else (nor[i][j] + cn).normalized()
			var kn: Vector3 = cn if end == 1 else (nor[i][k] + cn).normalized()
			_tri(st, [cp, pts[i][j], pts[i][k]], [cuv, _at(r, Vector2(ring[4], vs[j])), _at(r, Vector2(ring[4], vs[k]))], [cn, en, kn], c)


## A flat fin: triangles of points with their texture coordinates (rays fan out from the
## left middle of the fin cell).
static func _fin(st: SurfaceTool, tris: Array, r: Rect2, c := Color.WHITE) -> void:
	for t: Array in tris:
		var p: Array = t[0]
		var n: Vector3 = (p[1] - p[0]).cross(p[2] - p[0]).normalized()
		var uv: Array = []
		for q: Vector2 in t[1]:
			uv.append(_at(r, q))
		_tri(st, p, uv, [n, n, n], c)


static func _girth(u: float, peak: float) -> float:
	if u < peak:
		return pow(sin(u / peak * PI / 2.0), 0.6)
	return lerpf(1.0, 0.13, pow((u - peak) / (1.0 - peak), 1.3))


## A fish along +X (nose) of length `l`: "fish" a slim striped mackerel, "tuna" a deep
## navy tuna with yellow finlets, "dried" a flat salted fish. Cooked: browned, milky eyes.
static func fish(st: SurfaceTool, l: float, kind: String, cooked: bool) -> void:
	var tuna := kind == "tuna"
	var dried := kind == "dried"
	var hh := l * (0.16 if tuna else 0.12)
	var hw := l * (0.105 if tuna else 0.07) * (0.45 if dried else 1.0)
	var peak := 0.4 if tuna else 0.34
	var belly := 1.12 if tuna else 1.05
	var skin := "dried" if dried else kind + ("_cooked" if cooked else "")
	var fr := cell("fin_cooked" if cooked else ("fin_tuna" if tuna else "fin"))
	var x0 := l * 0.5
	var x1 := -l * 0.28
	var rings: Array = []
	for i in 22:
		var u := lerpf(0.02, 1.0, i / 21.0)
		var s := _girth(u, peak)
		rings.append([lerpf(x0, x1, u), hh * s, hw * s, -hh * 0.12 * pow(1.0 - u, 3.0), u])
	loft(st, rings, 18, cell(skin), Color.WHITE, x0 + l * 0.012, belly)
	var top := func(u: float, side: float) -> Vector3:
		var s := _girth(u, peak)
		return Vector3(lerpf(x0, x1, u), -hh * 0.12 * pow(1.0 - u, 3.0) + side * hh * s * (belly if side < 0.0 else 1.0) * 0.96, 0)
	# Forked tail.
	var span := hh * (1.55 if tuna else 1.2)
	var tl := l * 0.21
	var rt := Vector3(x1 + l * 0.015, hh * 0.16, 0)
	var rb := Vector3(x1 + l * 0.015, -hh * 0.16, 0)
	var tt := Vector3(x1 - tl, span, 0.0)
	var tb := Vector3(x1 - tl, -span, 0.0)
	var notch := Vector3(x1 - tl * (0.35 if tuna else 0.5), 0, 0)
	var tuv := func(p: Vector3) -> Vector2: return Vector2(clampf((x1 + l * 0.015 - p.x) / (tl + l * 0.015), 0, 1), clampf(0.5 - p.y / (2.0 * span), 0, 1))
	_fin(st, [[[rt, tt, notch], [tuv.call(rt), tuv.call(tt), tuv.call(notch)]], [[rt, notch, rb], [tuv.call(rt), tuv.call(notch), tuv.call(rb)]],
			[[rb, notch, tb], [tuv.call(rb), tuv.call(notch), tuv.call(tb)]]], fr)
	if not dried:
		# Dorsal fins, the anal fin, side fins.
		var fins := [[0.3, 0.48, 0.52, 0.75 if tuna else 0.6, 1.0], [0.58, 0.67, 0.7, 0.35, 1.0], [0.6, 0.68, 0.72, 0.3, -1.0]]
		for f: Array in fins:
			var a: Vector3 = top.call(f[0], f[4])
			var b: Vector3 = top.call(f[1], f[4])
			var t: Vector3 = top.call(f[2], f[4]) + Vector3(0, f[4] * hh * f[3], 0)
			_fin(st, [[[a, b, t], [Vector2(0, 0.2), Vector2(0, 0.8), Vector2(1, 0.65)]]], fr)
		for side: float in [-1.0, 1.0]:
			var u := 0.24
			var s := _girth(u, peak)
			var x := lerpf(x0, x1, u)
			var a := Vector3(x, -hh * 0.25, side * hw * s * 0.92)
			var b := Vector3(x - l * 0.04, -hh * 0.32, side * hw * s * 0.92)
			var t := Vector3(x - l * 0.15, -hh * 0.6, side * (hw * s + l * 0.05))
			_fin(st, [[[a, b, t], [Vector2(0, 0.25), Vector2(0, 0.75), Vector2(1, 0.5)]]], fr)
		if tuna:
			for k in 6:
				var u := lerpf(0.7, 0.93, k / 5.0)
				for side: float in [1.0, -1.0]:
					var a: Vector3 = top.call(u, side)
					var b: Vector3 = top.call(u + 0.035, side)
					var t: Vector3 = b + Vector3(-l * 0.012, side * hh * 0.22, 0)
					_fin(st, [[[a, b, t], [Vector2(0, 0.3), Vector2(0, 0.7), Vector2(1, 0.5)]]], cell("fin_cooked" if cooked else "fin_tuna"))
	_eyes(st, l, hh, hw, peak, x0, x1, tuna, cooked or dried)


static func _eyes(st: SurfaceTool, l: float, hh: float, hw: float, peak: float, x0: float, x1: float, tuna: bool, cooked: bool) -> void:
	var u := 0.1
	var s := _girth(u, peak)
	var h := hh * s
	var w := hw * s
	var re := l * (0.03 if tuna else 0.034)
	var q := Vector2(1, 0) if cooked else (Vector2(0, 1) if tuna else Vector2(0, 0))
	var er := cell("eyes")
	var center := er.position + (q + Vector2(0.5, 0.5)) * er.size / 2.0
	var rad := er.size.x / 4.0 * 0.96
	for side: float in [-1.0, 1.0]:
		var a := asin(0.3)
		var p := Vector3(lerpf(x0, x1, u), -hh * 0.12 * pow(1.0 - u, 3.0) + 0.3 * h, side * cos(a) * w)
		var n := Vector3(0.45, sin(a) / h * w * 0.6, side * cos(a)).normalized()
		var e1 := n.cross(Vector3.UP).normalized()
		var e2 := n.cross(e1).normalized()
		var c := p + n * re * 0.2
		for k in 12:
			var t0 := TAU * k / 12.0
			var t1 := TAU * (k + 1) / 12.0
			var a0 := p - n * re * 0.1 + (e1 * cos(t0) + e2 * sin(t0)) * re
			var a1 := p - n * re * 0.1 + (e1 * cos(t1) + e2 * sin(t1)) * re
			var n0 := (n + (a0 - p).normalized() * 0.5).normalized()
			var n1 := (n + (a1 - p).normalized() * 0.5).normalized()
			_tri(st, [c, a0, a1], [center, center + Vector2(cos(t0), -sin(t0)) * rad * side, center + Vector2(cos(t1), -sin(t1)) * rad * side], [n, n0, n1], Color.WHITE)


## An irregular oval outline in XZ (`rx` by `rz`): `taper` narrows the +X end, `notch` bites
## into the -Z side (a steak's belly cavity).
static func _outline(rx: float, rz: float, taper: float, notch: float, seed_v: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var out := PackedVector2Array()
	for k in 26:
		var t := TAU * k / 26.0
		var x := cos(t) * rx
		var z := sin(t) * rz * (1.0 - taper * cos(t))
		var d := angle_difference(t, PI * 1.5)
		var k2 := (1.0 - notch * exp(-pow(d / 0.35, 2.0))) * rng.randf_range(0.96, 1.04)
		out.append(Vector2(x, z) * k2)
	return out


## A thick piece of meat on outline `o`: rounded edges, a domed top (`top` cell mapped
## from above), sides (`side` cell around, its top edge at the top).
static func _slab(st: SurfaceTool, o: PackedVector2Array, y0: float, y1: float, dome: float, top: String, side: String, c: Color) -> void:
	var n := o.size()
	var tr := cell(top)
	var sr := cell(side)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in o:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var plan := func(p: Vector2) -> Vector2: return _at(tr, (p - lo) / (hi - lo))
	var hn: Array = []
	for k in n:
		var t := o[(k + 1) % n] - o[(k - 1 + n) % n]
		var nn := Vector3(t.y, 0, -t.x).normalized()
		if nn.dot(Vector3(o[k].x, 0, o[k].y)) < 0.0:
			nn = -nn
		hn.append(nn)
	var layers := [[y0, 0.9, -0.85], [y0 + 0.015, 1.0, 0.0], [y1 - 0.02, 1.0, 0.0], [y1, 0.92, 0.8]]
	var at := func(k: int, l: Array) -> Vector3: return Vector3(o[k % n].x * l[1], l[0], o[k % n].y * l[1])
	var nm := func(k: int, l: Array) -> Vector3: return (hn[k % n] * (1.0 - absf(l[2]) * 0.5) + Vector3(0, l[2], 0)).normalized()
	for li in layers.size() - 1:
		var la: Array = layers[li]
		var lb: Array = layers[li + 1]
		var va := (y1 - float(la[0])) / (y1 - y0)
		var vb := (y1 - float(lb[0])) / (y1 - y0)
		for k in n:
			var u0 := float(k) / n
			var u1 := float(k + 1) / n
			var p := [at.call(k, la), at.call(k, lb), at.call(k + 1, lb), at.call(k + 1, la)]
			var uv := [_at(sr, Vector2(u0, va)), _at(sr, Vector2(u0, vb)), _at(sr, Vector2(u1, vb)), _at(sr, Vector2(u1, va))]
			var nn := [nm.call(k, la), nm.call(k, lb), nm.call(k + 1, lb), nm.call(k + 1, la)]
			_tri(st, [p[0], p[1], p[2]], [uv[0], uv[1], uv[2]], [nn[0], nn[1], nn[2]], c)
			_tri(st, [p[0], p[2], p[3]], [uv[0], uv[2], uv[3]], [nn[0], nn[2], nn[3]], c)
	# The domed top: the edge ring, a raised middle ring, the peak.
	var caps := [[0.92, y1, 0.45], [0.55, y1 + dome * 0.75, 0.2]]
	for ci in 2:
		var ca: Array = caps[ci]
		for k in n:
			var pa := Vector3(o[k].x * ca[0], ca[1], o[k].y * ca[0])
			var pb := Vector3(o[(k + 1) % n].x * ca[0], ca[1], o[(k + 1) % n].y * ca[0])
			var na: Vector3 = (hn[k] * float(ca[2]) + Vector3.UP).normalized()
			var nb: Vector3 = (hn[(k + 1) % n] * float(ca[2]) + Vector3.UP).normalized()
			if ci == 0:
				var cb: Array = caps[1]
				var qa := Vector3(o[k].x * cb[0], cb[1], o[k].y * cb[0])
				var qb := Vector3(o[(k + 1) % n].x * cb[0], cb[1], o[(k + 1) % n].y * cb[0])
				var ma: Vector3 = (hn[k] * float(cb[2]) + Vector3.UP).normalized()
				var mb: Vector3 = (hn[(k + 1) % n] * float(cb[2]) + Vector3.UP).normalized()
				_tri(st, [pa, pb, qb], [plan.call(o[k] * ca[0]), plan.call(o[(k + 1) % n] * ca[0]), plan.call(o[(k + 1) % n] * cb[0])], [na, nb, mb], c)
				_tri(st, [pa, qb, qa], [plan.call(o[k] * ca[0]), plan.call(o[(k + 1) % n] * cb[0]), plan.call(o[k] * cb[0])], [na, mb, ma], c)
			else:
				var pk := Vector3(0, y1 + dome, 0)
				_tri(st, [pk, pa, pb], [plan.call(Vector2.ZERO), plan.call(o[k] * ca[0]), plan.call(o[(k + 1) % n] * ca[0])], [Vector3.UP, na, nb], c)
	for k in n:
		var pa := Vector3(o[k].x * 0.9, y0, o[k].y * 0.9)
		var pb := Vector3(o[(k + 1) % n].x * 0.9, y0, o[(k + 1) % n].y * 0.9)
		var uv := [plan.call(Vector2.ZERO), plan.call(o[k] * 0.9), plan.call(o[(k + 1) % n] * 0.9)]
		_tri(st, [Vector3(0, y0, 0), pa, pb], uv, [Vector3.DOWN, Vector3.DOWN, Vector3.DOWN], c.darkened(0.2))


## A box with every face on one painted cell (`tpm` metres per cell).
static func _box(st: SurfaceTool, size: Vector3, pos: Vector3, rot: Vector3, r: Rect2, c := Color.WHITE, tpm := 0.25) -> void:
	var b := Basis.from_euler(rot)
	var h := size / 2.0
	var faces := [[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD], [Vector3.UP, Vector3.BACK, Vector3.RIGHT],
			[Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT], [Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.LEFT, Vector3.UP]]
	for f: Array in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var su := minf(1.0, (u * size).length() / tpm)
		var sv := minf(1.0, (v * size).length() / tpm)
		var p: Array = []
		var uv: Array = []
		for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			p.append(pos + b * ((n + u * s.x + v * s.y) * h))
			uv.append(_at(r, Vector2((s.x * 0.5 + 0.5) * su, (s.y * 0.5 + 0.5) * sv)))
		var bn := b * n
		_tri(st, [p[0], p[1], p[2]], [uv[0], uv[1], uv[2]], [bn, bn, bn], c)
		_tri(st, [p[0], p[2], p[3]], [uv[0], uv[2], uv[3]], [bn, bn, bn], c)


## Plastic scrap: a crushed bottle with its cap and a broken piece of an orange crate.
static func _plastic(st: SurfaceTool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var rings: Array = []
	for i in 18:
		var u := i / 17.0
		var x := lerpf(0.16, -0.13, u)
		var rad := 0.068
		if u < 0.12:
			rad = 0.026 if u < 0.07 else lerpf(0.026, 0.05, (u - 0.07) / 0.05)
		elif u < 0.26:
			rad = lerpf(0.05, 0.068, (u - 0.12) / 0.14)
		var crush := 1.0 if u < 0.12 else rng.randf_range(0.36, 0.62)
		rings.append([x, rad * crush, rad * rng.randf_range(1.05, 1.28) if u >= 0.12 else rad, rad * crush - 0.005 + rng.randf_range(-0.006, 0.006), 1.0 - u * 0.97])
	loft(st, rings, 16, cell("bottle"), Color.WHITE, 0.163)
	var cr := cell("crate")
	_box(st, Vector3(0.22, 0.014, 0.15), Vector3(0.01, 0.007, 0.12), Vector3(0.0, 0.45, 0.04), cr, Color.WHITE, 0.3)
	_box(st, Vector3(0.2, 0.07, 0.014), Vector3(-0.04, 0.035, 0.2), Vector3(0.0, 0.45, 0.0), cr, Color(0.92, 0.92, 0.92), 0.3)


## Fish soup in a coconut shell: broth, chunks of fish, a fin sticking out.
static func _soup(st: SurfaceTool, at: SurfaceTool) -> void:
	Mk.st_cyl(at, 0.16, 0.11, Vector3(0, 0.055, 0), Color("#7a5532"), "clay", Vector3.ZERO, 16, 1.0, 0.3)
	Mk.st_cyl(at, 0.168, 0.015, Vector3(0, 0.11, 0), Color("#f0e6d0"), "white", Vector3.ZERO, 16)
	var r := cell("soup")
	var seg := 16
	for k in seg:
		var a0 := TAU * k / seg
		var a1 := TAU * (k + 1) / seg
		var p0 := Vector3(cos(a0), 0, sin(a0)) * 0.15 + Vector3(0, 0.118, 0)
		var p1 := Vector3(cos(a1), 0, sin(a1)) * 0.15 + Vector3(0, 0.118, 0)
		_tri(st, [Vector3(0, 0.118, 0), p0, p1], [_at(r, Vector2(0.5, 0.5)), _at(r, Vector2(0.5 + cos(a0) * 0.48, 0.5 + sin(a0) * 0.48)),
				_at(r, Vector2(0.5 + cos(a1) * 0.48, 0.5 + sin(a1) * 0.48))], [Vector3.UP, Vector3.UP, Vector3.UP], Color.WHITE)
	var fr := cell("fin_cooked")
	var a := Vector3(0.05, 0.11, -0.04)
	_fin(st, [[[a, a + Vector3(0.05, 0, 0.03), a + Vector3(0.1, 0.1, 0.06)], [Vector2(0, 0.3), Vector2(0, 0.7), Vector2(1, 0.5)]]], fr)


## A skewer: shark steak pieces between pineapple chunks on a wooden stick.
static func _kebab(st: SurfaceTool, at: SurfaceTool) -> void:
	Mk.st_cyl(at, 0.009, 0.5, Vector3(0, 0, 0), Color(1, 0.93, 0.8), "wood_warm", Vector3(0, 0, PI / 2.0), 8)
	var top := cell("steak_side")
	for i in 5:
		var x := -0.15 + i * 0.075
		var rot := Vector3(0.3 * i, 0.4 * i, 0.2)
		if i % 2 == 0:
			_box(st, Vector3(0.06, 0.055, 0.06), Vector3(x, 0, 0), rot, top, Color.WHITE, 0.12)
		else:
			Mk.st_box(at, Vector3(0.05, 0.05, 0.05), Vector3(x, 0, 0), Color("#f2cf4a"), "white", rot)
	Mk.st_box(at, Vector3(0.03, 0.035, 0.035), Vector3(0.23, 0, 0), Color("#4e8a32"), "palm", Vector3(0.4, 0, 0))
