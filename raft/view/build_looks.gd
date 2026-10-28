class_name BuildLooks
## More things to build (v0.14): a low wall, a stone wall, an arch, a window with
## shutters, a thatched roof; a candle and a fire bowl; a bench, a deck chair, a keg, a
## flower box, a mat; and for walls a lifebuoy, a map and a shelf (the fish trophy is in
## FoodLooks). Walls span X on y = 0; wall things hang in front of a wall (local +Z).

const T := Looks.T
const H := Looks.H
const IDS := ["half_wall", "wall_stone", "arch", "window_shutters", "roof_thatch", "candle", "fire_pit", "bench", "deck_chair",
		"keg", "flower_box", "mat", "lifebuoy", "map", "shelf"]
const WOOD := Color(1, 0.93, 0.84)
const DARK := Color(1, 0.95, 0.9)
const STRAW := Color("#d2b05a")


## Builds `id` into `st`. Returns true when it needs the leaf (cut-out) material.
static func build(st: SurfaceTool, id: String) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	match id:
		"half_wall":
			for i in 5:
				var x := -T / 2.0 + T / 5.0 * (i + 0.5)
				Mk.st_box(st, Vector3(T / 5.0 - 0.02, 1.0, 0.07), Vector3(x, 0.5, 0), WOOD.darkened(rng.randf_range(0.0, 0.14)), "wood")
			Mk.st_box(st, Vector3(T, 0.07, 0.16), Vector3(0, 1.03, 0), DARK, "wood_dark")
			Mk.st_box(st, Vector3(T - 0.04, 0.1, 0.05), Vector3(0, 0.45, -0.055), DARK, "wood_dark")
		"wall_stone":
			_stone_wall(st, rng)
		"arch":
			for x: float in [-0.66, 0.66]:
				Mk.st_box(st, Vector3(0.2, H, 0.18), Vector3(x, H / 2.0, 0), DARK, "wood_dark")
				Mk.st_cyl(st, 0.13, 0.1, Vector3(x, 1.0, 0), Color(1, 0.96, 0.9), "rope", Vector3.ZERO, 10, 0.6)
			Mk.st_box(st, Vector3(T, 0.22, 0.2), Vector3(0, H - 0.11, 0), DARK, "wood_dark")
			for i in 7:
				var a := PI * (i + 0.5) / 7.0
				var p := Vector3(-cos(a) * 0.56, H - 0.6 + sin(a) * 0.35, 0)
				Mk.st_box(st, Vector3(0.2, 0.08, 0.16), p, WOOD, "wood_warm", Vector3(0, 0, a - PI / 2.0))
			Mk.st_box(st, Vector3(0.3, 0.16, 0.04), Vector3(0, H - 0.11, 0.11), Color("#c8432f"), "canvas", Vector3.ZERO, 0.6)
		"window_shutters":
			Looks._structure(st, "window")
			var paint := Color("#4f9a8a")
			for s: float in [-1.0, 1.0]:
				for k in 6:
					Mk.st_box(st, Vector3(0.42, 0.12, 0.025), Vector3(s * 0.68, 1.02 + k * 0.13, 0.07), paint.darkened(0.06 * (k % 2)), "wood", Vector3(0.12, 0, 0))
				for y: float in [1.05, 1.68]:
					Mk.st_box(st, Vector3(0.12, 0.02, 0.03), Vector3(s * 0.5, y, 0.085), Color(0.25, 0.25, 0.27), "metal")
			Mk.st_box(st, Vector3(1.0, 0.06, 0.16), Vector3(0, 0.92, 0.08), DARK, "wood_dark")
		"roof_thatch":
			Mk.st_box(st, Vector3(T, 0.07, T), Vector3(0, H - 0.11, 0), DARK, "wood_dark")
			for i in 6:
				var z := -T / 2.0 + T / 6.0 * (i + 0.5)
				Mk.st_box(st, Vector3(T + 0.14, 0.09, T / 6.0 + 0.06), Vector3(0, H - 0.03 + (i % 2) * 0.012, z), STRAW.darkened(rng.randf_range(0.0, 0.14)), "rope", Vector3(0.05, 0, 0), 0.5)
			for k in 4:
				var a := k * PI / 2.0
				var d := Vector3(sin(a), 0, cos(a))
				for j in 9:
					var off := Vector3(cos(a), 0, -sin(a)) * (-0.7 + j * 0.175)
					Mk.st_box(st, Vector3(0.04, 0.16, 0.03), d * (T / 2.0 + 0.07) + off + Vector3(0, H - 0.1, 0), STRAW.darkened(0.1 + 0.05 * (j % 2)), "rope", Vector3(0, a, 0), 0.5)
		"candle":
			Mk.st_cyl(st, 0.08, 0.025, Vector3(0, 0.0125, 0), Color("#7a5532"), "clay", Vector3.ZERO, 12, 0.5)
			Mk.st_cyl(st, 0.032, 0.18, Vector3(0, 0.115, 0), Color("#f4ecd8"), "white", Vector3.ZERO, 10, 1.0, 0.05)
			Mk.st_cyl(st, 0.004, 0.025, Vector3(0, 0.215, 0), Color(0.1, 0.1, 0.1), "white", Vector3.ZERO, 4)
			Mk.st_box(st, Vector3(0.03, 0.012, 0.012), Vector3(0.09, 0.02, 0), Color("#7a5532"), "clay")
		"fire_pit":
			for i in 9:
				var a := TAU * i / 9.0
				Mk.st_box(st, Vector3(0.2, 0.16, 0.16) * rng.randf_range(0.85, 1.15), Vector3(cos(a) * 0.33, 0.08, sin(a) * 0.33), Color(0.85, 0.84, 0.8).darkened(rng.randf_range(0.0, 0.2)),
						"rock", Vector3(0, -a, rng.randf_range(-0.2, 0.2)), 0.6)
			Mk.st_cyl(st, 0.27, 0.05, Vector3(0, 0.03, 0), Color(0.15, 0.13, 0.12), "ash", Vector3.ZERO, 14)
			for i in 3:
				var a := TAU * i / 3.0
				Mk.st_cyl(st, 0.05, 0.45, Vector3(cos(a) * 0.05, 0.14, sin(a) * 0.05), Color(0.8, 0.62, 0.45), "wood", Vector3(PI / 2.0 - 0.35, a, 0), 8)
		"bench":
			Mk.st_box(st, Vector3(1.2, 0.06, 0.4), Vector3(0, 0.45, 0), WOOD, "wood")
			for x: float in [-0.5, 0.5]:
				Mk.st_box(st, Vector3(0.07, 0.43, 0.34), Vector3(x, 0.215, 0), DARK, "wood_dark")
			Mk.st_box(st, Vector3(1.0, 0.05, 0.05), Vector3(0, 0.15, 0), DARK, "wood_dark")
			for x: float in [-0.5, 0.5]:
				Mk.st_box(st, Vector3(0.06, 0.5, 0.06), Vector3(x, 0.72, -0.18), DARK, "wood_dark", Vector3(-0.15, 0, 0))
			for y: float in [0.72, 0.88]:
				Mk.st_box(st, Vector3(1.16, 0.09, 0.03), Vector3(0, y, -0.2 - (y - 0.7) * 0.15), WOOD.darkened(0.06), "wood", Vector3(-0.15, 0, 0))
		"deck_chair":
			_deck_chair(st)
		"keg":
			Mk.st_cyl(st, 0.25, 0.7, Vector3(0, 0.35, 0), Color(1, 0.9, 0.8), "wood_warm", Vector3.ZERO, 14, 1.2, 0.12)
			for y: float in [0.1, 0.35, 0.6]:
				Mk.st_cyl(st, 0.268 if y == 0.35 else 0.258, 0.04, Vector3(0, y, 0), Color(0.5, 0.5, 0.54), "metal", Vector3.ZERO, 14)
			Mk.st_cyl(st, 0.22, 0.02, Vector3(0, 0.7, 0), Color(0.85, 0.72, 0.55), "wood_dark", Vector3.ZERO, 14)
			Mk.st_cyl(st, 0.03, 0.08, Vector3(0, 0.25, 0.27), Color(0.6, 0.45, 0.3), "wood_dark", Vector3(PI / 2.0, 0, 0), 8)
			Mk.st_box(st, Vector3(0.02, 0.06, 0.02), Vector3(0, 0.29, 0.31), Color(0.75, 0.6, 0.35), "metal")
		"flower_box":
			_flower_box(st, rng)
			return true
		"mat":
			var cols := [Color("#c9a24e"), Color("#8a6a3a"), Color("#c9a24e"), Color("#b0472f"), Color("#c9a24e"), Color("#8a6a3a"), Color("#c9a24e")]
			for i in cols.size():
				Mk.st_box(st, Vector3(1.0, 0.016, 0.1), Vector3(0, 0.008, -0.3 + i * 0.1), cols[i], "canvas", Vector3.ZERO, 0.4)
			for x: float in [-0.5, 0.5]:
				for k in 5:
					Mk.st_box(st, Vector3(0.06, 0.008, 0.012), Vector3(x + signf(x) * 0.03, 0.006, -0.24 + k * 0.12), STRAW, "rope", Vector3.ZERO, 0.5)
		"lifebuoy":
			for i in 16:
				var a := TAU * i / 16.0
				var c := Color("#e8442c") if (i / 2) % 2 == 0 else Color("#f6f2ea")
				Mk.st_box(st, Vector3(0.1, 0.1, 0.1), Vector3(cos(a) * 0.2, 1.5 + sin(a) * 0.2, 0.08), c, "plastic", Vector3(0, 0, a), 0.6)
			for i in 4:
				var a := TAU * i / 4.0 + PI / 4.0
				Mk.st_box(st, Vector3(0.025, 0.12, 0.025), Vector3(cos(a) * 0.2, 1.5 + sin(a) * 0.2, 0.135), Color(1, 0.96, 0.9), "rope", Vector3(0, 0, a), 0.6)
			Mk.st_cyl(st, 0.02, 0.06, Vector3(0, 1.75, 0.03), Color(0.5, 0.5, 0.54), "metal", Vector3(PI / 2.0, 0, 0), 6)
		"map":
			Mk.st_box(st, Vector3(0.78, 0.58, 0.03), Vector3(0, 1.5, 0.02), DARK, "wood_dark")
			Mk.st_box(st, Vector3(0.68, 0.48, 0.01), Vector3(0, 1.5, 0.04), Color("#e8d7a8"), "canvas", Vector3.ZERO, 0.6)
			for b: Array in [[Vector3(-0.18, 1.58, 0.047), Vector2(0.14, 0.1)], [Vector3(0.15, 1.42, 0.047), Vector2(0.18, 0.12)], [Vector3(0.2, 1.62, 0.047), Vector2(0.07, 0.05)]]:
				Mk.st_box(st, Vector3(b[1].x, b[1].y, 0.004), b[0], Color("#7fa35a"), "white")
				Mk.st_box(st, Vector3(b[1].x + 0.03, b[1].y + 0.03, 0.003), b[0] - Vector3(0, 0, 0.001), Color("#d8c48a"), "white")
			for k in 6:
				Mk.st_box(st, Vector3(0.03, 0.008, 0.004), Vector3(-0.12 + k * 0.045, 1.52 - k * 0.012, 0.048), Color("#b03a2a"), "white", Vector3(0, 0, -0.25))
			for r: float in [0.6, -0.6]:
				Mk.st_box(st, Vector3(0.06, 0.012, 0.004), Vector3(0.15, 1.42, 0.052), Color("#b03a2a"), "white", Vector3(0, 0, r))
			for p: Vector2 in [Vector2(-0.3, 1.71), Vector2(0.3, 1.71), Vector2(-0.3, 1.29), Vector2(0.3, 1.29)]:
				Mk.st_cyl(st, 0.012, 0.02, Vector3(p.x, p.y, 0.05), Color(0.7, 0.6, 0.35), "metal", Vector3(PI / 2.0, 0, 0), 6)
		"shelf":
			Mk.st_box(st, Vector3(0.9, 0.04, 0.24), Vector3(0, 1.4, 0.12), WOOD, "wood")
			for x: float in [-0.35, 0.35]:
				Mk.st_box(st, Vector3(0.04, 0.18, 0.04), Vector3(x, 1.31, 0.03), DARK, "wood_dark")
				Mk.st_box(st, Vector3(0.04, 0.04, 0.2), Vector3(x, 1.3, 0.1), DARK, "wood_dark", Vector3(0.6, 0, 0))
			Mk.st_cyl(st, 0.05, 0.1, Vector3(-0.3, 1.47, 0.12), Color(1, 0.95, 0.9), "clay", Vector3.ZERO, 10, 0.5)
			Mk.st_cyl(st, 0.04, 0.22, Vector3(-0.12, 1.53, 0.12), Color("#6fb8ec"), "plastic", Vector3.ZERO, 10, 1.0, 0.05)
			Mk.st_cyl(st, 0.02, 0.04, Vector3(-0.12, 1.66, 0.12), Color("#d8352a"), "plastic", Vector3.ZERO, 8)
			Mk.st_cyl(st, 0.09, 0.06, Vector3(0.1, 1.45, 0.12), Color("#7a5532"), "clay", Vector3.ZERO, 12, 1.0, 0.3)
			Mk.st_cyl(st, 0.05, 0.12, Vector3(0.3, 1.48, 0.12), Color("#c8a85a"), "clay", Vector3.ZERO, 10, 0.5)
			Mk.st_cyl(st, 0.055, 0.02, Vector3(0.3, 1.55, 0.12), Color("#7a5532"), "wood_dark", Vector3.ZERO, 10)
	return false


## Rows of rough stones in grey mortar, a wooden sill at the foot and a beam on top.
static func _stone_wall(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	Mk.st_box(st, Vector3(T - 0.02, H - 0.12, 0.16), Vector3(0, H / 2.0 - 0.02, 0), Color(0.55, 0.53, 0.5), "ash")
	var rows := 8
	for r in rows:
		var y := 0.1 + (H - 0.3) * (r + 0.5) / rows
		var x := -T / 2.0 + 0.02
		var shift := 0.12 if r % 2 == 1 else 0.0
		x += shift
		while x < T / 2.0 - 0.06:
			var w := minf(rng.randf_range(0.22, 0.36), T / 2.0 - 0.02 - x)
			var g := rng.randf_range(0.72, 0.95)
			Mk.st_box(st, Vector3(w - 0.03, (H - 0.3) / rows - 0.03, 0.2), Vector3(x + w / 2.0, y, rng.randf_range(-0.01, 0.01)), Color(g, g * 0.98, g * 0.94), "rock",
					Vector3(0, 0, rng.randf_range(-0.03, 0.03)), 0.7)
			x += w
	Mk.st_box(st, Vector3(T, 0.1, 0.22), Vector3(0, 0.05, 0), DARK, "wood_dark")
	Mk.st_box(st, Vector3(T, 0.12, 0.2), Vector3(0, H - 0.06, 0), DARK, "wood_dark")


## A folding deck chair along +Z: a wooden frame and a striped canvas sling.
static func _deck_chair(st: SurfaceTool) -> void:
	for x: float in [-0.27, 0.27]:
		Mk.st_box(st, Vector3(0.05, 0.05, 1.15), Vector3(x, 0.32, 0.05), DARK, "wood_dark", Vector3(0.28, 0, 0))
		Mk.st_box(st, Vector3(0.05, 0.05, 0.75), Vector3(x, 0.26, 0.05), DARK, "wood_dark", Vector3(-0.42, 0, 0))
		Mk.st_box(st, Vector3(0.05, 0.4, 0.05), Vector3(x, 0.2, 0.45), DARK, "wood_dark")
	var stripes := [Color("#2f6fb0"), Color("#f4f1ea"), Color("#2f6fb0"), Color("#f4f1ea"), Color("#2f6fb0")]
	for i in stripes.size():
		var x := -0.2 + i * 0.1
		Mk.st_box(st, Vector3(0.1, 0.012, 0.6), Vector3(x, 0.55, -0.22), stripes[i], "canvas", Vector3(0.75, 0, 0), 0.6)
		Mk.st_box(st, Vector3(0.1, 0.012, 0.55), Vector3(x, 0.32, 0.28), stripes[i], "canvas", Vector3(-0.12, 0, 0), 0.6)
	Mk.st_box(st, Vector3(0.6, 0.04, 0.05), Vector3(0, 0.78, -0.48), DARK, "wood_dark")


## A planter box of flowers: soil, green stems and leaves, red, yellow and white blooms.
static func _flower_box(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	Mk.st_box(st, Vector3(0.8, 0.26, 0.3), Vector3(0, 0.13, 0), WOOD, "wood")
	Mk.st_box(st, Vector3(0.84, 0.04, 0.34), Vector3(0, 0.27, 0), DARK, "wood_dark")
	Mk.st_box(st, Vector3(0.74, 0.02, 0.24), Vector3(0, 0.27, 0), Color(0.4, 0.28, 0.2), "clay")
	var blooms := [Color("#e8442c"), Color("#f2c230"), Color("#f6f2ea"), Color("#e86aa0")]
	var leaf := Mk.cell("palm")
	for i in 9:
		var x := -0.32 + i * 0.08
		var h := rng.randf_range(0.18, 0.32)
		var z := rng.randf_range(-0.06, 0.06)
		Mk.st_box(st, Vector3(0.012, h, 0.012), Vector3(x, 0.28 + h / 2.0, z), Color("#4e8a32"), "white")
		var c: Color = blooms[i % blooms.size()]
		for a in 4:
			var yaw := a * PI / 2.0 + i
			Mk.st_box(st, Vector3(0.035, 0.012, 0.022), Vector3(x, 0.28 + h, z) + Basis(Vector3.UP, yaw) * Vector3(0.022, 0, 0), c, "white", Vector3(0, yaw, 0.2))
		Mk.st_box(st, Vector3(0.018, 0.016, 0.018), Vector3(x, 0.29 + h, z), Color("#f2c230"), "white")
		var b := Basis(Vector3.UP, i * 1.3)
		var base := Vector3(x, 0.3, z)
		var q := [base + b * Vector3(-0.02, 0, 0), base + b * Vector3(0.02, 0, 0), base + b * Vector3(0.05, 0.1, 0.07), base + b * Vector3(-0.03, 0.1, 0.07)]
		Mk.st_quad(st, q, leaf, Color(0.9, 1.1, 0.8))
