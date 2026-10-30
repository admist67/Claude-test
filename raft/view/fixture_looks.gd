class_name FixtureLooks
## Lanterns (on a post, a tall post, on a wall), the hammock and the rain barrel. A lantern
## head is centered where its light is (Part puts the glow there): an iron frame with
## amber glass, a brass base, a stepped roof and a ring to hang it by.

const IDS := ["lantern", "lantern_tall", "lantern_wall", "hammock", "collector"]
const TALL := Looks.TALL_LAMP
const WOOD := Color(1, 0.93, 0.84)
const DARK := Color(1, 0.95, 0.9)
const IRON := Color(0.3, 0.31, 0.34)
const BRASS := Color("#c9a24a")
const ROPE := Color(1, 0.96, 0.9)
const GLASS := 0.064              # how far the panes stand from the center (the glow covers them)


## Builds `id` into `st`. Returns true when it needs the leaf (cut-out) material.
static func build(st: SurfaceTool, id: String) -> bool:
	match id:
		"lantern", "lantern_tall":
			_post(st, 1.35 if id == "lantern" else TALL, 0.09 if id == "lantern" else 0.11)
		"lantern_wall":
			_wall_bracket(st)
		"hammock":
			_hammock(st)
		"collector":
			_rain_barrel(st)
	return false


## A rod of radius `r` from `a` to `b`.
static func _bar(st: SurfaceTool, a: Vector3, b: Vector3, r: float, c: Color, cell: String, seg := 6) -> void:
	var d := b - a
	var up := d.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	Mk.st_cyl(st, r, d.length(), (a + b) / 2.0, c, cell, Basis(side, up, side.cross(up)).get_euler(), seg, 0.8)


## The lantern itself, centered at `at`.
static func lamp_head(st: SurfaceTool, at: Vector3) -> void:
	# Base: an iron plate and a brass rim, four little feet.
	Mk.st_box(st, Vector3(0.17, 0.022, 0.17), at + Vector3(0, -0.118, 0), IRON, "metal")
	Mk.st_box(st, Vector3(0.15, 0.02, 0.15), at + Vector3(0, -0.098, 0), BRASS, "metal")
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		Mk.st_box(st, Vector3(0.025, 0.02, 0.025), at + Vector3(c.x * 0.072, -0.135, c.y * 0.072), IRON, "metal")
	# Amber glass on four sides with an iron cross on each pane.
	for k in 4:
		var yaw := k * PI / 2.0
		var b := Basis(Vector3.UP, yaw)
		Mk.st_box(st, Vector3(0.118, 0.17, 0.006), at + b * Vector3(0, -0.005, GLASS - 0.003), Color("#f2dca2"), "plastic", Vector3(0, yaw, 0))
		Mk.st_box(st, Vector3(0.008, 0.17, 0.01), at + b * Vector3(0, -0.005, GLASS), IRON, "metal", Vector3(0, yaw, 0))
		Mk.st_box(st, Vector3(0.118, 0.008, 0.01), at + b * Vector3(0, 0.0, GLASS), IRON, "metal", Vector3(0, yaw, 0))
	# Corner posts.
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		Mk.st_box(st, Vector3(0.02, 0.21, 0.02), at + Vector3(c.x * 0.066, -0.005, c.y * 0.066), IRON, "metal")
	# A stepped roof, a little chimney, a brass ring on top.
	Mk.st_box(st, Vector3(0.18, 0.02, 0.18), at + Vector3(0, 0.1, 0), IRON, "metal")
	Mk.st_box(st, Vector3(0.14, 0.03, 0.14), at + Vector3(0, 0.125, 0), IRON.lightened(0.05), "metal")
	Mk.st_box(st, Vector3(0.09, 0.03, 0.09), at + Vector3(0, 0.15, 0), IRON, "metal")
	Mk.st_cyl(st, 0.025, 0.04, at + Vector3(0, 0.18, 0), IRON.darkened(0.1), "metal", Vector3.ZERO, 8)
	Mk.st_cyl(st, 0.032, 0.008, at + Vector3(0, 0.2, 0), BRASS, "metal", Vector3.ZERO, 8)
	for i in 14:
		var a := TAU * i / 14.0
		Mk.st_box(st, Vector3(0.019, 0.011, 0.011), at + Vector3(cos(a) * 0.03, 0.24 + sin(a) * 0.03, 0), IRON, "metal", Vector3(0, 0, a + PI / 2.0))


## A lantern on a wooden post: crossed feet with braces, rope wraps, a capped top, an arm
## with a diagonal brace and an iron hook.
static func _post(st: SurfaceTool, ph: float, w: float) -> void:
	for yaw: float in [0.0, PI / 2.0]:
		Mk.st_box(st, Vector3(0.4, 0.06, 0.08), Vector3(0, 0.03, 0), DARK, "wood_dark", Vector3(0, yaw, 0))
	for k in 4:
		var d := Basis(Vector3.UP, k * PI / 2.0) * Vector3(1, 0, 0)
		_bar(st, d * 0.17 + Vector3(0, 0.05, 0), d * (w * 0.5) + Vector3(0, 0.24, 0), 0.016, DARK, "wood_dark")
	Mk.st_box(st, Vector3(w, ph, w), Vector3(0, ph / 2.0, 0), DARK, "wood_dark")
	for y: float in [0.3, ph * 0.55]:
		Mk.st_cyl(st, w * 0.62 + 0.012, 0.07, Vector3(0, y, 0), ROPE, "rope", Vector3.ZERO, 10, 0.6)
	Mk.st_box(st, Vector3(w + 0.05, 0.04, w + 0.05), Vector3(0, ph + 0.02, 0), DARK.darkened(0.1), "wood_dark")
	Mk.st_box(st, Vector3(w * 0.6, 0.05, w * 0.6), Vector3(0, ph + 0.06, 0), DARK.darkened(0.1), "wood_dark")
	Mk.st_box(st, Vector3(0.34, 0.05, 0.055), Vector3(0.13, ph - 0.04, 0), DARK, "wood_dark")
	_bar(st, Vector3(w * 0.5, ph - 0.24, 0), Vector3(0.17, ph - 0.06, 0), 0.016, DARK, "wood_dark")
	Mk.st_box(st, Vector3(0.012, 0.05, 0.012), Vector3(0.22, ph - 0.085, 0), IRON, "metal")
	lamp_head(st, Vector3(0.22, ph - 0.33, 0))


## A wall lantern: a backing board with bolts and a scrolled iron bracket.
static func _wall_bracket(st: SurfaceTool) -> void:
	Mk.st_box(st, Vector3(0.16, 0.34, 0.035), Vector3(0, 1.86, 0.018), DARK, "wood_dark")
	for y: float in [1.74, 1.98]:
		Mk.st_cyl(st, 0.012, 0.012, Vector3(0, y, 0.04), IRON, "metal", Vector3(PI / 2.0, 0, 0), 6)
	Mk.st_box(st, Vector3(0.022, 0.022, 0.3), Vector3(0, 1.98, 0.17), IRON, "metal")
	_bar(st, Vector3(0, 1.8, 0.04), Vector3(0, 1.97, 0.22), 0.01, IRON, "metal")
	for i in 6:
		var a := PI * 0.3 + i * 0.35
		Mk.st_box(st, Vector3(0.012, 0.012, 0.03), Vector3(0, 1.93 + sin(a) * 0.035, 0.1 + cos(a) * 0.035), IRON, "metal", Vector3(-a, 0, 0))
	Mk.st_box(st, Vector3(0.012, 0.04, 0.012), Vector3(0, 1.955, 0.26), IRON, "metal")
	Mk.st_cyl(st, 0.016, 0.02, Vector3(0, 1.98, 0.325), BRASS, "metal", Vector3(PI / 2.0, 0, 0), 6)
	lamp_head(st, Vector3(0, 1.69, 0.26))


## Two posts on feet with outward braces, rope fans to wooden spreader bars, a striped
## sling with a fringe and a pillow.
static func _hammock(st: SurfaceTool) -> void:
	for s: float in [-1.0, 1.0]:
		var x := s * 0.66
		Mk.st_box(st, Vector3(0.11, 1.18, 0.11), Vector3(x, 0.59, 0), DARK, "wood_dark")
		Mk.st_box(st, Vector3(0.16, 0.05, 0.5), Vector3(x, 0.025, 0), DARK, "wood_dark")
		Mk.st_box(st, Vector3(0.14, 0.04, 0.14), Vector3(x, 1.2, 0), DARK.darkened(0.1), "wood_dark")
		for z: float in [-0.2, 0.2]:
			_bar(st, Vector3(x, 0.05, z), Vector3(x, 0.4, z * 0.2), 0.02, DARK, "wood_dark")
		Mk.st_cyl(st, 0.075, 0.09, Vector3(x, 1.02, 0), ROPE, "rope", Vector3.ZERO, 10, 0.6)
		Mk.st_cyl(st, 0.07, 0.07, Vector3(x, 0.3, 0), ROPE, "rope", Vector3.ZERO, 10, 0.6)
		# Spreader bar and a fan of ropes up to the post.
		var sx := s * 0.52
		Mk.st_cyl(st, 0.02, 0.7, Vector3(sx, 0.86, 0), WOOD, "wood_warm", Vector3(PI / 2.0, 0, 0), 8)
		for z: float in [-0.32, -0.16, 0.0, 0.16, 0.32]:
			_bar(st, Vector3(sx, 0.86, z), Vector3(x - s * 0.06, 1.02, 0), 0.006, ROPE, "rope", 4)
	var stripes := [Color("#efe2c2"), Color("#c8432f"), Color("#efe2c2"), Color("#2f6fb0"), Color("#efe2c2"), Color("#c8432f"), Color("#efe2c2")]
	var segs := 10
	var width := 0.66
	for i in segs:
		var u0 := float(i) / segs
		var u1 := float(i + 1) / segs
		var x0 := lerpf(-0.52, 0.52, u0)
		var x1 := lerpf(-0.52, 0.52, u1)
		var y0 := 0.86 - sin(PI * u0) * 0.42
		var y1 := 0.86 - sin(PI * u1) * 0.42
		var mid := Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, 0)
		var ang := atan2(y1 - y0, x1 - x0)
		var sag := sin(PI * (u0 + u1) / 2.0)
		for k in stripes.size():
			var z := -width / 2.0 + width * (k + 0.5) / stripes.size()
			# The sling curls up a little at its edges.
			var curl := absf(z) / (width / 2.0)
			Mk.st_box(st, Vector3(Vector2(x1 - x0, y1 - y0).length() + 0.012, 0.02, width / stripes.size() + 0.004),
					mid + Vector3(0, curl * curl * 0.06 * sag, z), stripes[k], "canvas", Vector3(0, 0, ang), 1.0)
		for z: float in [-width / 2.0 - 0.01, width / 2.0 + 0.01]:
			Mk.st_box(st, Vector3(0.012, 0.07, 0.008), mid + Vector3(0, 0.03 * sag - 0.03, z), Color("#efe2c2"), "rope", Vector3(0, 0, ang), 0.5)
	Mk.st_cyl(st, 0.07, 0.36, Vector3(-0.36, 0.62, 0), Color("#f4f1ea"), "canvas", Vector3(PI / 2.0, 0, 0.35), 12, 0.6, 0.25)


## A barrel of staves with three iron hoops and a tap with a cup on a nail, under a canvas
## funnel on a wooden ring held by four poles with rope lashings.
static func _rain_barrel(st: SurfaceTool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var staves := 18
	var h := 0.76
	for i in staves:
		var a := TAU * (i + 0.5) / staves
		var tint := Color(1, 0.9, 0.78).darkened(rng.randf_range(-0.04, 0.14))
		for j in 3:
			var u := (j + 0.5) / 3.0
			var r := 0.315 * (1.0 + 0.07 * sin(PI * u))
			var lean := -atan(0.07 * 0.315 * PI * cos(PI * u) / h)
			var p := Vector3(cos(a) * r, h * u, sin(a) * r)
			Mk.st_box(st, Vector3(0.028, h / 3.0 + 0.004, TAU * r / staves - 0.006), p, tint, "wood_warm", Vector3(0, -a, lean), 1.2)
	Mk.st_cyl(st, 0.3, 0.02, Vector3(0, 0.03, 0), Color(0.55, 0.42, 0.3), "wood_dark", Vector3.ZERO, 16)
	for y: float in [0.1, 0.4, 0.69]:
		var r := 0.315 * (1.0 + 0.07 * sin(PI * y / h)) + 0.018
		Mk.st_cyl(st, r, 0.04, Vector3(0, y, 0), IRON.lightened(0.15), "metal", Vector3.ZERO, 18)
	# The tap and a tin cup on a nail.
	Mk.st_cyl(st, 0.025, 0.09, Vector3(0, 0.16, 0.35), Color(0.75, 0.6, 0.35), "metal", Vector3(PI / 2.0, 0, 0), 8)
	Mk.st_box(st, Vector3(0.08, 0.016, 0.016), Vector3(0, 0.2, 0.38), Color(0.75, 0.6, 0.35), "metal")
	Mk.st_box(st, Vector3(0.016, 0.04, 0.016), Vector3(0, 0.12, 0.39), Color(0.75, 0.6, 0.35), "metal")
	Mk.st_cyl(st, 0.045, 0.08, Vector3(0.17, 0.38, 0.31), Color(0.7, 0.71, 0.75), "metal", Vector3(0, 0, 0), 10, 1.0, 0.05)
	Mk.st_box(st, Vector3(0.012, 0.05, 0.02), Vector3(0.22, 0.39, 0.29), Color(0.7, 0.71, 0.75), "metal")
	# The funnel on its ring and poles.
	Looks._funnel(st, 0.3, 0.8, 0.66, 1.18, Color("#e8d8b0"))
	for i in 16:
		var a := TAU * (i + 0.5) / 16.0
		Mk.st_box(st, Vector3(0.05, 0.05, TAU * 0.67 / 16.0 + 0.02), Vector3(cos(a) * 0.67, 1.19, sin(a) * 0.67), DARK, "wood_dark", Vector3(0, -a, 0))
	Mk.st_cyl(st, 0.33, 0.06, Vector3(0, 0.78, 0), DARK, "wood_dark", Vector3.ZERO, 16)
	for k in 4:
		var yaw := k * PI / 2.0 + PI / 4.0
		var d := Vector3(sin(yaw), 0, cos(yaw))
		_bar(st, d * 0.36 + Vector3(0, 0.02, 0), d * 0.68 + Vector3(0, 1.22, 0), 0.025, DARK, "wood_dark", 6)
		Mk.st_cyl(st, 0.035, 0.06, d * 0.66 + Vector3(0, 1.16, 0), ROPE, "rope", Vector3.ZERO, 8, 0.6)
		Mk.st_cyl(st, 0.03, 0.05, d * 0.4 + Vector3(0, 0.16, 0), ROPE, "rope", Vector3.ZERO, 8, 0.6)
