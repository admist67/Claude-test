class_name ParrotLooks
## A scarlet macaw in pieces that move on their own: body, head (with the upper beak, the
## white face, eyes), lower beak, one wing (the other is its mirror), tail, legs. Built
## facing +X with the feathers on the atlas "scales" cell, tinted. Sizes in meters.
## The wing spreads along +Z from the shoulder, its feathers trailing toward -X.

const RED := Color("#d32a1c")
const RED_DARK := Color("#a81e14")
const YELLOW := Color("#f2c230")
const GREEN := Color("#3f9a48")
const BLUE := Color("#2a5fc0")
const BLUE_DARK := Color("#1d3f8a")
const FACE := Color("#f6efe6")
const IVORY := Color("#d8cbb0")
const BLACK := Color("#24221f")
const FOOT := Color("#6e6863")
const DRIFT := Color(0.86, 0.8, 0.72)
const BRANCH_TOP := 1.32          # the wild parrot's perch on its island branch

static var _cache: Dictionary = {}


static func mesh(part: String) -> ArrayMesh:
	if not _cache.has(part):
		var st := Mk.st_begin()
		match part:
			"body":
				_body(st)
			"head":
				_head(st)
			"jaw":
				Mk.st_box(st, Vector3(0.036, 0.018, 0.028), Vector3(0.017, -0.009, 0), BLACK, "white", Vector3(0, 0, -0.15))
				Mk.st_box(st, Vector3(0.012, 0.008, 0.012), Vector3(0.012, 0.001, 0), Color("#3a2a2a"), "white")
			"wing":
				_wing(st)
			"tail":
				_tail(st)
			"legs":
				_legs(st)
			"branch":
				_branch(st)
		_cache[part] = Mk.st_commit(st)
	return _cache[part]


static func _feathers() -> Rect2:
	return Mk.cell("scales")


## A plump body from the rump (-X) to the neck (+X), a darker back.
static func _body(st: SurfaceTool) -> void:
	var rings: Array = []
	for r: Array in [[-0.13, 0.03, 0.03, 0.0], [-0.08, 0.055, 0.05, 0.0], [-0.02, 0.072, 0.064, -0.004], [0.05, 0.07, 0.062, -0.002],
			[0.11, 0.056, 0.05, 0.004], [0.165, 0.04, 0.038, 0.008]]:
		rings.append([r[0], r[1], r[2], r[3], (float(r[0]) + 0.13) / 0.3])
	FoodLooks.loft(st, rings, 14, _feathers(), RED, 0.18, 1.08)
	# Shoulders tinted darker under the folded wings, a red bib on the chest.
	Mk.st_box(st, Vector3(0.12, 0.012, 0.09), Vector3(-0.01, 0.062, 0), RED_DARK, "scales", Vector3(0, 0, -0.06), 0.4)


## The head: a round crown, white bare face with feather lines, pale eyes, a big hooked beak.
static func _head(st: SurfaceTool) -> void:
	var rings: Array = []
	for r: Array in [[-0.048, 0.028, 0.028, 0.02], [-0.025, 0.048, 0.043, 0.022], [0.008, 0.052, 0.046, 0.022], [0.038, 0.042, 0.038, 0.018]]:
		rings.append([r[0], r[1], r[2], r[3], (float(r[0]) + 0.05) / 0.1])
	FoodLooks.loft(st, rings, 14, _feathers(), RED, 0.056, 1.0)
	for s: float in [-1.0, 1.0]:
		Mk.st_box(st, Vector3(0.05, 0.04, 0.008), Vector3(0.028, 0.012, s * 0.041), FACE, "white", Vector3(0, s * -0.25, 0))
		for k in 3:
			Mk.st_box(st, Vector3(0.036, 0.0025, 0.004), Vector3(0.03, 0.0 + k * 0.009, s * 0.0455), Color("#c9b9a8"), "white", Vector3(0, s * -0.25, 0.1))
		var eye := Vector3(0.012, 0.03, s * 0.044)
		var rx := Vector3(PI / 2.0, 0, 0)
		Mk.st_cyl(st, 0.011, 0.004, eye, Color("#f2e6a0"), "white", rx, 12)
		Mk.st_cyl(st, 0.0065, 0.005, eye + Vector3(0, 0, s * 0.002), BLACK, "white", rx, 10)
		Mk.st_box(st, Vector3(0.003, 0.003, 0.002), eye + Vector3(0.003, 0.003, s * 0.005), Color.WHITE, "white")
	# The upper beak curls down into a dark hook.
	Mk.st_box(st, Vector3(0.036, 0.036, 0.03), Vector3(0.062, 0.022, 0), IVORY, "white", Vector3(0, 0, -0.1))
	Mk.st_box(st, Vector3(0.03, 0.03, 0.026), Vector3(0.082, 0.01, 0), IVORY, "white", Vector3(0, 0, -0.55))
	Mk.st_box(st, Vector3(0.022, 0.024, 0.021), Vector3(0.093, -0.01, 0), IVORY.darkened(0.08), "white", Vector3(0, 0, -1.05))
	Mk.st_box(st, Vector3(0.014, 0.02, 0.015), Vector3(0.094, -0.027, 0), BLACK, "white", Vector3(0, 0, -1.5))
	Mk.st_box(st, Vector3(0.01, 0.012, 0.031), Vector3(0.047, 0.03, 0), BLACK, "white")


## One wing: red coverts on the arm, a yellow band with green tips, long blue flight
## feathers fanning back from the hand.
static func _wing(st: SurfaceTool) -> void:
	Mk.st_box(st, Vector3(0.1, 0.014, 0.075), Vector3(-0.025, 0.004, 0.04), RED, "scales", Vector3(0, 0.15, 0), 0.4)
	Mk.st_box(st, Vector3(0.09, 0.012, 0.07), Vector3(-0.03, 0.0, 0.1), RED_DARK, "scales", Vector3(0, 0.3, 0), 0.4)
	Mk.st_box(st, Vector3(0.07, 0.01, 0.12), Vector3(-0.075, -0.003, 0.07), YELLOW, "scales", Vector3(0, 0.15, 0), 0.4)
	Mk.st_box(st, Vector3(0.05, 0.009, 0.12), Vector3(-0.12, -0.005, 0.07), GREEN, "scales", Vector3(0, 0.15, 0), 0.4)
	# Secondaries along the arm's trailing edge.
	for k in 4:
		var z := 0.02 + k * 0.032
		Mk.st_box(st, Vector3(0.16, 0.006, 0.034), Vector3(-0.1, -0.008, z + 0.01), BLUE.lightened(0.1), "scales", Vector3(0, 0.08 + k * 0.05, 0), 0.4)
	# Primaries fanning from the hand: longer outward, swept further back.
	for k in 6:
		var ln := 0.17 + k * 0.012
		var yaw := 0.25 + k * 0.13
		var root := Vector3(-0.02, -0.006 - k * 0.001, 0.14 + k * 0.032)
		var dir := Basis(Vector3.UP, yaw) * Vector3(-1, 0, 0)
		Mk.st_box(st, Vector3(ln, 0.006, 0.036), root + dir * ln * 0.5, BLUE if k % 2 == 0 else BLUE.darkened(0.08), "scales",
				Vector3(0, yaw, 0), 0.4)
		Mk.st_box(st, Vector3(ln * 0.3, 0.007, 0.03), root + dir * ln * 0.85, BLUE_DARK, "scales", Vector3(0, yaw, 0), 0.4)


## Four long tail feathers trailing back (-X), red with blue tips, a little fanned.
static func _tail(st: SurfaceTool) -> void:
	var feathers := [[0.34, -0.022, 0.09], [0.37, -0.008, 0.03], [0.37, 0.008, -0.03], [0.34, 0.022, -0.09]]
	for f: Array in feathers:
		var ln: float = f[0]
		var yaw: float = f[2]
		var dir := Basis(Vector3.UP, yaw) * Vector3(-1, 0, 0)
		var at := Vector3(0, 0, f[1])
		Mk.st_box(st, Vector3(ln * 0.66, 0.006, 0.03), at + dir * ln * 0.33, RED, "scales", Vector3(0, yaw, 0), 0.4)
		Mk.st_box(st, Vector3(ln * 0.36, 0.006, 0.024), at + dir * ln * 0.82, BLUE, "scales", Vector3(0, yaw, 0), 0.4)
	Mk.st_box(st, Vector3(0.08, 0.02, 0.07), Vector3(-0.03, 0.004, 0), RED_DARK, "scales", Vector3.ZERO, 0.4)


## Short grey legs and four toes each, two forward and two back, gripping the perch.
static func _legs(st: SurfaceTool) -> void:
	for s: float in [-1.0, 1.0]:
		var z := s * 0.024
		Mk.st_cyl(st, 0.008, 0.07, Vector3(0, 0.035, z), FOOT, "white", Vector3.ZERO, 6)
		for k in 2:
			var dz := (k - 0.5) * 0.012
			Mk.st_box(st, Vector3(0.034, 0.008, 0.007), Vector3(0.016, 0.004, z + dz), FOOT, "white", Vector3(0, 0, -0.25))
			Mk.st_box(st, Vector3(0.028, 0.008, 0.007), Vector3(-0.013, 0.004, z + dz), FOOT, "white", Vector3(0, 0, 0.25))


## A bleached driftwood branch stuck in the sand, forked, with a crosswise twig on top and
## a few dry leaves: where a wild parrot sits.
static func _branch(st: SurfaceTool) -> void:
	_stick(st, Vector3(0, -0.1, 0), Vector3(0.05, 0.9, 0.02), 0.07)
	_stick(st, Vector3(0.05, 0.9, 0.02), Vector3(0.0, BRANCH_TOP - 0.03, 0.0), 0.05)
	_stick(st, Vector3(0.05, 0.9, 0.02), Vector3(0.32, 1.2, 0.1), 0.035)
	_stick(st, Vector3(-0.28, BRANCH_TOP - 0.035, 0.05), Vector3(0.3, BRANCH_TOP - 0.025, -0.04), 0.03)
	_stick(st, Vector3(0.0, 0.5, 0.0), Vector3(-0.25, 0.7, 0.12), 0.025)
	for i in 4:
		var a := i * 1.7
		Mk.st_box(st, Vector3(0.1, 0.004, 0.035), Vector3(0.32 + cos(a) * 0.04, 1.2 - i * 0.02, 0.1 + sin(a) * 0.04), Color("#a89058"), "canvas", Vector3(0.3, a, -0.4), 0.5)
	for i in 5:
		var a := TAU * i / 5.0
		Mk.st_box(st, Vector3(0.12, 0.05, 0.08), Vector3(cos(a) * 0.12, 0.0, sin(a) * 0.12), Color(0.8, 0.79, 0.75), "rock", Vector3(0.2, a, 0.1), 0.6)


static func _stick(st: SurfaceTool, a: Vector3, b: Vector3, r: float) -> void:
	var d := b - a
	var up := d.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	Mk.st_cyl(st, r, d.length(), (a + b) / 2.0, DRIFT, "wood", Basis(side, up, side.cross(up)).get_euler(), 8, 0.8)
