class_name DecorLooks
## Decorative builds and the variants of walls and stairs: bamboo and woven walls, a wall
## with a porthole, railings, a tiki torch, rope and bamboo stairs, a table, a stool, a
## crate, a potted palm, a rug, a ship's wheel, a flag and a bell. Moving pieces (the
## bell, the wheel, the flag's cloth) are separate meshes: "<id>_base" is the model
## without them, "<id>_<piece>" the piece alone at its hinge.

const T := Looks.T
const H := Looks.H
const IDS := ["wall_bamboo", "wall_woven", "window_round", "railing", "torch", "stairs_rope", "stairs_bamboo",
		"table", "stool", "crate", "plant_pot", "rug", "wheel", "wheel_base", "wheel_wheel", "flag", "flag_base",
		"flag_cloth", "bell", "bell_base", "bell_bell"]
const BAMBOO := Color("#d8c27a")
const WOOD := Color(1, 0.93, 0.84)
const DARK := Color(1, 0.95, 0.9)
const BRASS := Color("#e0ad4a")


## Builds `id` into `st`. Returns true when it needs the leaf (cut-out) material.
static func build(st: SurfaceTool, id: String) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	match id:
		"wall_bamboo":
			var n := 15
			for i in n:
				var x := -T / 2.0 + T / n * (i + 0.5)
				var c := BAMBOO.darkened(rng.randf_range(-0.05, 0.18))
				Mk.st_cyl(st, 0.048, H - rng.randf_range(0.0, 0.08), Vector3(x, H / 2.0, 0), c, "wood_warm", Vector3.ZERO, 8, 1.2)
				for y: float in [0.5, 1.2, 1.9]:
					Mk.st_cyl(st, 0.054, 0.03, Vector3(x, y + rng.randf_range(-0.1, 0.1), 0), c.darkened(0.25), "wood_warm", Vector3.ZERO, 8)
			for y: float in [0.35, 2.05]:
				Mk.st_box(st, Vector3(T - 0.02, 0.05, 0.12), Vector3(0, y, 0), Color(1, 0.96, 0.9), "rope", Vector3.ZERO, 0.6)
		"wall_woven":
			for x: float in [-T / 2.0 + 0.06, T / 2.0 - 0.06]:
				Mk.st_box(st, Vector3(0.12, H, 0.12), Vector3(x, H / 2.0, 0), DARK, "wood_dark")
			var rows := 16
			for r in rows:
				var y := 0.08 + (H - 0.16) * (r + 0.5) / rows
				var c := Color("#c9ad66") if r % 2 == 0 else Color("#a99050")
				Mk.st_box(st, Vector3(T - 0.2, (H - 0.16) / rows - 0.01, 0.05), Vector3(0, y, 0.015 if r % 2 == 0 else -0.015), c, "canvas", Vector3.ZERO, 0.8)
			for i in 6:
				var x := -T / 2.0 + 0.2 + i * (T - 0.4) / 5.0
				Mk.st_box(st, Vector3(0.05, H - 0.2, 0.07), Vector3(x, H / 2.0, 0), Color("#8a7440"), "canvas", Vector3.ZERO, 0.8)
		"window_round":
			Looks._structure(st, "wall")
			for z: float in [0.045, -0.045]:
				Mk.st_cyl(st, 0.3, 0.04, Vector3(0, 1.4, z), BRASS, "metal", Vector3(PI / 2.0, 0, 0), 20)
				Mk.st_cyl(st, 0.24, 0.042, Vector3(0, 1.4, z * 1.1), Color("#9fd2ec"), "plastic", Vector3(PI / 2.0, 0, 0), 20)
			for a in 6:
				var ang := a * TAU / 6.0
				Mk.st_cyl(st, 0.025, 0.02, Vector3(cos(ang) * 0.27, 1.4 + sin(ang) * 0.27, 0.07), BRASS.darkened(0.2), "metal", Vector3(PI / 2.0, 0, 0), 6)
		"railing":
			for x: float in [-0.7, 0.0, 0.7]:
				Mk.st_box(st, Vector3(0.09, 1.0, 0.09), Vector3(x, 0.5, 0), DARK, "wood_dark")
			Mk.st_box(st, Vector3(T, 0.07, 0.11), Vector3(0, 1.0, 0), WOOD, "wood")
			Mk.st_box(st, Vector3(T - 0.05, 0.05, 0.06), Vector3(0, 0.55, 0), WOOD.darkened(0.08), "wood")
			for i in 8:
				var x := -0.62 + i * 0.177
				if absf(x) > 0.06:
					Mk.st_box(st, Vector3(0.035, 0.42, 0.035), Vector3(x, 0.76, 0), WOOD.darkened(0.05), "wood")
		"torch":
			Mk.st_cyl(st, 0.045, 1.5, Vector3(0, 0.75, 0), BAMBOO.darkened(0.15), "wood_warm", Vector3.ZERO, 8, 1.2)
			for y: float in [0.4, 0.9]:
				Mk.st_cyl(st, 0.05, 0.03, Vector3(0, y, 0), BAMBOO.darkened(0.4), "wood_warm", Vector3.ZERO, 8)
			Mk.st_cyl(st, 0.09, 0.18, Vector3(0, 1.55, 0), Color(1, 0.95, 0.85), "rope", Vector3.ZERO, 10, 0.5, 0.25)
			Mk.st_cyl(st, 0.075, 0.02, Vector3(0, 1.64, 0), Color(0.15, 0.12, 0.1), "ash", Vector3.ZERO, 10)
		"stairs_rope", "stairs_bamboo":
			_stairs(st, id == "stairs_bamboo", rng)
		"table":
			Mk.st_box(st, Vector3(1.0, 0.06, 0.7), Vector3(0, 0.74, 0), WOOD, "wood")
			for x: float in [-0.42, 0.42]:
				for z: float in [-0.28, 0.28]:
					Mk.st_box(st, Vector3(0.07, 0.72, 0.07), Vector3(x, 0.36, z), DARK, "wood_dark")
				Mk.st_box(st, Vector3(0.05, 0.05, 0.56), Vector3(x, 0.2, 0), DARK, "wood_dark")
			Mk.st_cyl(st, 0.05, 0.1, Vector3(0.25, 0.82, 0.1), Color(1, 0.95, 0.9), "clay", Vector3.ZERO, 10, 0.5)
			Mk.st_cyl(st, 0.09, 0.08, Vector3(-0.2, 0.81, -0.08), Color("#7a5532"), "clay", Vector3.ZERO, 10, 1.0, 0.5)
		"stool":
			Mk.st_cyl(st, 0.21, 0.05, Vector3(0, 0.45, 0), WOOD, "wood", Vector3.ZERO, 14)
			for a in 3:
				var ang := a * TAU / 3.0
				Mk.st_box(st, Vector3(0.05, 0.46, 0.05), Vector3(cos(ang) * 0.13, 0.22, sin(ang) * 0.13), DARK, "wood_dark", Vector3(sin(ang) * 0.15, 0, -cos(ang) * 0.15))
		"crate":
			Mk.st_box(st, Vector3(0.6, 0.6, 0.6), Vector3(0, 0.3, 0), WOOD, "wood")
			for e: Array in [[Vector3(0.62, 0.06, 0.06), [Vector3(0, 0.03, 0.29), Vector3(0, 0.57, 0.29), Vector3(0, 0.03, -0.29), Vector3(0, 0.57, -0.29)]],
					[Vector3(0.06, 0.06, 0.62), [Vector3(0.29, 0.03, 0), Vector3(-0.29, 0.03, 0), Vector3(0.29, 0.57, 0), Vector3(-0.29, 0.57, 0)]],
					[Vector3(0.06, 0.6, 0.06), [Vector3(0.29, 0.3, 0.29), Vector3(-0.29, 0.3, 0.29), Vector3(0.29, 0.3, -0.29), Vector3(-0.29, 0.3, -0.29)]]]:
				for at: Vector3 in e[1]:
					Mk.st_box(st, e[0], at, DARK, "wood_dark")
			Mk.st_box(st, Vector3(0.7, 0.05, 0.03), Vector3(0, 0.3, 0.305), DARK, "wood_dark", Vector3(0, 0, 0.75))
		"plant_pot":
			Mk.st_cyl(st, 0.2, 0.32, Vector3(0, 0.16, 0), Color("#c4704a"), "clay", Vector3.ZERO, 14, 0.6, 0.12)
			Mk.st_cyl(st, 0.21, 0.04, Vector3(0, 0.33, 0), Color("#d4805a"), "clay", Vector3.ZERO, 14, 0.6)
			Mk.st_cyl(st, 0.18, 0.02, Vector3(0, 0.33, 0), Color("#5a3a26"), "clay", Vector3.ZERO, 14)
			Mk.st_cyl(st, 0.035, 0.55, Vector3(0.02, 0.6, 0), IslandLooks.TRUNK, "wood_dark", Vector3(0, 0, -0.08), 8, 1.2)
			for k in 7:
				var a := k * TAU / 7.0 + 0.3
				IslandLooks._frond(st, Vector3(0.04, 0.88, 0), Vector3(cos(a), 0, sin(a)), 0.55, 0.25)
			return true
		"rug":
			var cols := [Color("#b8452f"), Color("#e8c46a"), Color("#3f6f8f")]
			Mk.st_box(st, Vector3(1.2, 0.02, 0.9), Vector3(0, 0.011, 0), cols[0], "canvas", Vector3.ZERO, 0.8)
			Mk.st_box(st, Vector3(1.0, 0.022, 0.7), Vector3(0, 0.012, 0), cols[1], "canvas", Vector3.ZERO, 0.8)
			Mk.st_box(st, Vector3(0.8, 0.024, 0.5), Vector3(0, 0.013, 0), cols[2], "canvas", Vector3.ZERO, 0.8)
			Mk.st_box(st, Vector3(0.5, 0.026, 0.2), Vector3(0, 0.014, 0), cols[1], "canvas", Vector3.ZERO, 0.8)
			for x: float in [-0.64, 0.64]:
				for i in 9:
					Mk.st_box(st, Vector3(0.07, 0.012, 0.025), Vector3(x, 0.006, -0.4 + i * 0.1), Color(1, 0.95, 0.88), "rope", Vector3.ZERO, 0.5)
		"wheel", "wheel_base":
			Mk.st_box(st, Vector3(0.5, 0.06, 0.4), Vector3(0, 0.03, 0), DARK, "wood_dark")
			Mk.st_box(st, Vector3(0.14, 1.0, 0.14), Vector3(0, 0.5, 0), WOOD, "wood")
			Mk.st_cyl(st, 0.05, 0.12, Vector3(0, 1.05, 0.06), Color(0.6, 0.6, 0.64), "metal", Vector3(PI / 2.0, 0, 0), 10)
			if id == "wheel":
				_wheel(st, Vector3(0, 1.05, 0.13))
		"wheel_wheel":
			_wheel(st, Vector3.ZERO)
		"flag", "flag_base":
			Mk.st_box(st, Vector3(0.4, 0.08, 0.4), Vector3(0, 0.04, 0), DARK, "wood_dark")
			Mk.st_cyl(st, 0.04, 3.0, Vector3(0, 1.5, 0), WOOD, "wood", Vector3.ZERO, 8)
			Mk.st_cyl(st, 0.06, 0.08, Vector3(0, 3.02, 0), BRASS, "metal", Vector3.ZERO, 10, 1.0, 0.5)
			if id == "flag":
				_cloth(st, Vector3(0, 2.92, 0))
		"flag_cloth":
			_cloth(st, Vector3.ZERO)
		"bell", "bell_base":
			Mk.st_box(st, Vector3(0.4, 0.08, 0.4), Vector3(-0.2, 0.04, 0), DARK, "wood_dark")
			Mk.st_box(st, Vector3(0.12, 2.0, 0.12), Vector3(-0.2, 1.0, 0), WOOD, "wood")
			Mk.st_box(st, Vector3(0.62, 0.1, 0.1), Vector3(0.05, 1.96, 0), WOOD, "wood")
			Mk.st_box(st, Vector3(0.05, 0.4, 0.05), Vector3(-0.06, 1.78, 0), DARK, "wood_dark", Vector3(0, 0, -0.7))
			if id == "bell":
				_bell(st, Vector3(0.2, 1.9, 0))
		"bell_bell":
			_bell(st, Vector3.ZERO)
	return false


## Stairs along +Z climbing to H: rope-and-plank steps or bamboo-bundle steps.
static func _stairs(st: SurfaceTool, bamboo: bool, rng: RandomNumberGenerator) -> void:
	var steps := 8 if bamboo else 9
	var slope := atan2(H, T)
	var slen := sqrt(H * H + T * T)
	for i in steps:
		var u := (i + 0.5) / steps
		var at := Vector3(0, u * H - 0.03, -T / 2.0 + u * T)
		if bamboo:
			for k in 3:
				Mk.st_cyl(st, 0.035, T - 0.3, at + Vector3(0, 0, -0.06 + k * 0.06), BAMBOO.darkened(rng.randf_range(0.0, 0.15)), "wood_warm", Vector3(0, 0, PI / 2.0), 8)
		else:
			Mk.st_box(st, Vector3(T - 0.5, 0.05, 0.14), at, WOOD.darkened(rng.randf_range(0.0, 0.12)), "wood")
	for x: float in [-T / 2.0 + 0.12, T / 2.0 - 0.12] if bamboo else [-T / 2.0 + 0.24, T / 2.0 - 0.24]:
		if bamboo:
			Mk.st_cyl(st, 0.05, slen, Vector3(x, H / 2.0 - 0.05, 0), BAMBOO.darkened(0.1), "wood_warm", Vector3(-slope + PI / 2.0, 0, 0), 8)
			Mk.st_cyl(st, 0.035, slen, Vector3(x, H / 2.0 + 0.85, 0), BAMBOO, "wood_warm", Vector3(-slope + PI / 2.0, 0, 0), 8)
			Mk.st_cyl(st, 0.04, 0.9, Vector3(x, 0.45, -T / 2.0 + 0.05), BAMBOO.darkened(0.1), "wood_warm", Vector3.ZERO, 8)
		else:
			Mk.st_cyl(st, 0.028, slen, Vector3(x, H / 2.0, 0), Color(1, 0.96, 0.88), "rope", Vector3(-slope + PI / 2.0, 0, 0), 8, 0.5)
			Mk.st_cyl(st, 0.022, slen, Vector3(x, H / 2.0 + 0.75, 0), Color(1, 0.96, 0.88), "rope", Vector3(-slope + PI / 2.0, 0, 0), 8, 0.5)
			Mk.st_box(st, Vector3(0.08, 0.8, 0.08), Vector3(x, 0.4, -T / 2.0 + 0.05), DARK, "wood_dark")


## A ship's wheel facing +Z: rim, eight spokes with handles, a hub.
static func _wheel(st: SurfaceTool, at: Vector3) -> void:
	var r := 0.38
	for k in 16:
		var a := k * TAU / 16.0
		Mk.st_box(st, Vector3(0.16, 0.05, 0.05), at + Vector3(cos(a) * r, sin(a) * r, 0), WOOD.darkened(0.05), "wood_warm", Vector3(0, 0, a + PI / 2.0))
	for k in 8:
		var a := k * TAU / 8.0
		Mk.st_box(st, Vector3(0.48, 0.035, 0.035), at + Vector3(cos(a) * 0.24, sin(a) * 0.24, 0.0), WOOD, "wood_warm", Vector3(0, 0, a))
		Mk.st_cyl(st, 0.03, 0.1, at + Vector3(cos(a) * 0.52, sin(a) * 0.52, 0), DARK, "wood_dark", Vector3(0, 0, a - PI / 2.0), 8)
	Mk.st_cyl(st, 0.08, 0.08, at, BRASS, "metal", Vector3(PI / 2.0, 0, 0), 12)


## The flag's cloth hanging from the pole top along +X, red with a white band.
static func _cloth(st: SurfaceTool, at: Vector3) -> void:
	Mk.st_box(st, Vector3(0.8, 0.5, 0.015), at + Vector3(0.42, -0.25, 0), Color("#c8352a"), "canvas", Vector3.ZERO, 0.8)
	Mk.st_box(st, Vector3(0.8, 0.1, 0.018), at + Vector3(0.42, -0.25, 0), Color("#f4efe4"), "canvas", Vector3.ZERO, 0.8)
	Mk.st_box(st, Vector3(0.1, 0.12, 0.02), at + Vector3(0.62, -0.25, 0), Color("#f0c040"), "canvas", Vector3.ZERO, 0.8)


## A brass bell hanging under `at` (its hinge), with a clapper and a pull rope.
static func _bell(st: SurfaceTool, at: Vector3) -> void:
	Mk.st_cyl(st, 0.025, 0.06, at + Vector3(0, -0.03, 0), BRASS.darkened(0.2), "metal", Vector3.ZERO, 8)
	Mk.st_cyl(st, 0.12, 0.2, at + Vector3(0, -0.16, 0), BRASS, "metal", Vector3.ZERO, 16, 1.0, 0.2)
	Mk.st_cyl(st, 0.16, 0.05, at + Vector3(0, -0.27, 0), BRASS.lightened(0.1), "metal", Vector3.ZERO, 16)
	Mk.st_cyl(st, 0.03, 0.05, at + Vector3(0, -0.31, 0), Color(0.3, 0.3, 0.32), "metal", Vector3.ZERO, 8)
	Mk.st_cyl(st, 0.012, 0.5, at + Vector3(0, -0.56, 0), Color(1, 0.96, 0.88), "rope", Vector3.ZERO, 6, 0.4)
