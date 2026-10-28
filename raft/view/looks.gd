class_name Looks
## Visuals for items: floating debris, tools in hand, food and stations. Merged textured
## meshes on the CC0 atlas; Kenney CC0 models for some food.

const MODELS := {
	"coconut": ["res://assets/models/food/coconut.glb", 0.9],
	"banana": ["res://assets/models/food/banana.glb", 0.9],
	"pineapple": ["res://assets/models/food/pineapple.glb", 0.6],
}
const T := 1.5     # tile size, as in data/balance.json raft.tile
const H := 2.4     # wall height = upper floor level
const TALL_LAMP := 2.3   # tall lantern post, a little under the wall top
const STRUCTURES := ["wall", "window", "door", "door_ajar", "door_frame", "door_leaf", "pillar", "lantern", "lantern_tall", "lantern_wall",
		"roof", "stairs", "net", "net_strong", "trap", "hammock", "collector"]
const PLASTIC := Color("#bfe0f2")
const CAP := Color("#2a6fb0")

static var _cache: Dictionary = {}


static func debris(id: String) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(id)
	root.add_child(mi)
	return root


## What the right hand shows for a hotbar item.
static func held(id: String) -> Node3D:
	var root := Node3D.new()
	if MODELS.has(id):
		var m := Mk.model(root, MODELS[id][0], Vector3(0, -0.06, 0), MODELS[id][1] * 0.5)
		m.rotation.y = 0.6
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh(id)
		root.add_child(mi)
		match id:
			"hook", "metal_hook":
				mi.scale = Vector3.ONE * 0.45
				mi.rotation = Vector3(0.5, 0.4, -0.2)
				mi.position = Vector3(0.06, -0.08, -0.05)
			"hammer":
				mi.scale = Vector3.ONE * 0.7
				mi.rotation = Vector3(0.3, -0.4, 0.2)
				mi.position = Vector3(0.06, -0.12, 0.0)
			"spear", "metal_spear":
				mi.scale = Vector3.ONE * 0.8
				mi.rotation = Vector3(-1.35, 0.05, -0.15)
				mi.position = Vector3(0.0, -0.05, 0.25)
			"rod", "metal_rod":
				mi.scale = Vector3.ONE * 0.75
				mi.rotation = Vector3(-0.55, 0.0, -0.5)
				mi.position = Vector3(0.08, -0.12, 0.05)
			_:
				mi.scale = Vector3.ONE * 0.55
				mi.rotation = Vector3(0.3, 0.6, 0.0)
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


## A model for an item or debris id; cached.
static func mesh(id: String) -> ArrayMesh:
	if _cache.has(id):
		return _cache[id]
	if id in FoodLooks.IDS:
		_cache[id] = FoodLooks.mesh(id)
		return _cache[id]
	var st := Mk.st_begin()
	var leaf := false
	match id:
		"plank":
			Mk.st_box(st, Vector3(1.05, 0.065, 0.24), Vector3.ZERO, Color(1, 0.93, 0.82), "wood")
			for x: float in [-0.38, 0.38]:
				Mk.st_box(st, Vector3(0.02, 0.012, 0.02), Vector3(x, 0.036, 0.05), Color(0.5, 0.5, 0.52), "metal")
		"water":
			# A full bottle of drinking water: blue water, a label, a red cap.
			var rz := Vector3(0, 0, PI / 2.0)
			var blue := Color("#6fb8ec")
			Mk.st_cyl(st, 0.085, 0.27, Vector3(-0.02, 0.09, 0), blue, "plastic", rz, 14, 1.0, 0.03)
			for x: float in [-0.14, -0.12]:
				Mk.st_cyl(st, 0.087, 0.008, Vector3(x, 0.09, 0), blue.lightened(0.2), "plastic", rz, 14)
			Mk.st_cyl(st, 0.088, 0.1, Vector3(0.0, 0.09, 0), Color("#2a6fc4"), "canvas", rz, 14, 0.6)
			Mk.st_cyl(st, 0.089, 0.022, Vector3(0.0, 0.09, 0), Color("#f4f4f0"), "white", rz, 14)
			Mk.st_cyl(st, 0.06, 0.05, Vector3(0.135, 0.09, 0), blue.lightened(0.1), "plastic", rz, 12, 1.0, 0.25)
			Mk.st_cyl(st, 0.03, 0.04, Vector3(0.175, 0.09, 0), blue.lightened(0.2), "plastic", rz, 10)
			Mk.st_cyl(st, 0.035, 0.035, Vector3(0.205, 0.09, 0), Color("#d8352a"), "plastic", rz, 12)
		"leaf":
			leaf = true
			_frond(st, Vector3.ZERO, 0.0, 1.15)
			_frond(st, Vector3(0.05, 0.02, 0.05), 0.5, 0.95)
		"rope":
			for i in 4:
				Mk.st_cyl(st, 0.13 - i * 0.004, 0.045, Vector3(0, i * 0.042, 0), Color(1, 0.96, 0.9), "rope", Vector3.ZERO, 14, 0.6)
		"barrel":
			Mk.st_cyl(st, 0.3, 0.8, Vector3(0, 0.05, 0), Color(1, 0.9, 0.8), "wood_warm", Vector3(0, 0, PI / 2.0), 14, 1.2, 0.12)
			for x: float in [-0.26, 0.26]:
				Mk.st_cyl(st, 0.325, 0.05, Vector3(x, 0.05, 0), Color(0.6, 0.62, 0.66), "metal", Vector3(0, 0, PI / 2.0), 14)
		"metal_hook":
			Mk.st_cyl(st, 0.026, 0.34, Vector3(0, 0.12, 0), Color(1, 1, 1), "metal", Vector3.ZERO, 8)
			for a in 4:
				var yaw := a * TAU / 4.0
				var out := Vector3(sin(yaw), 0, cos(yaw))
				Mk.st_box(st, Vector3(0.035, 0.035, 0.18), out * 0.08 + Vector3(0, -0.03, 0), Color(1, 1, 1), "metal", Vector3(0.0, yaw, 0.0))
				Mk.st_box(st, Vector3(0.035, 0.13, 0.035), out * 0.16 + Vector3(0, 0.03, 0), Color(1, 1, 1), "metal", Vector3(0.0, yaw, 0.0))
			for k in 3:
				Mk.st_cyl(st, 0.038, 0.03, Vector3(0, 0.22 + k * 0.03, 0), Color(1, 0.95, 0.88), "rope", Vector3.ZERO, 8, 0.6)
			Mk.st_cyl(st, 0.055, 0.06, Vector3(0, 0.31, 0), Color("#2f6fb0"), "plastic", Vector3.ZERO, 10)
		"hook", "hook_head":
			Mk.st_cyl(st, 0.022, 0.32, Vector3(0, 0.12, 0), Color(0.8, 0.82, 0.86), "metal", Vector3.ZERO, 8)
			for a in 3:
				var yaw := a * TAU / 3.0
				var out := Vector3(sin(yaw), 0, cos(yaw))
				Mk.st_box(st, Vector3(0.03, 0.03, 0.15), out * 0.07 + Vector3(0, -0.03, 0), Color(0.8, 0.82, 0.86), "metal", Vector3(0.0, yaw, 0.0))
				Mk.st_box(st, Vector3(0.03, 0.11, 0.03), out * 0.14 + Vector3(0, 0.02, 0), Color(0.8, 0.82, 0.86), "metal", Vector3(0.0, yaw, 0.0))
			for k in 3:
				Mk.st_cyl(st, 0.035, 0.03, Vector3(0, 0.22 + k * 0.03, 0), Color(1, 0.95, 0.88), "rope", Vector3.ZERO, 8, 0.6)
			Mk.st_cyl(st, 0.05, 0.06, Vector3(0, 0.31, 0), Color("#ff6a3d"), "plastic", Vector3.ZERO, 10)
		"hammer":
			Mk.st_box(st, Vector3(0.045, 0.34, 0.045), Vector3(0, 0.0, 0), Color(1, 0.92, 0.82), "wood_warm")
			Mk.st_box(st, Vector3(0.17, 0.06, 0.06), Vector3(0.02, 0.17, 0), Color(0.7, 0.72, 0.76), "metal")
			for k in 3:
				Mk.st_cyl(st, 0.03, 0.025, Vector3(0, -0.08 + k * 0.03, 0), Color(1, 0.95, 0.88), "rope", Vector3.ZERO, 8, 0.6)
		"rod":
			_rod(st)
		"metal_rod":
			_rod(st, 1.0, true)
		"spear":
			Mk.st_cyl(st, 0.022, 1.3, Vector3(0, 0.2, 0), Color(1, 0.93, 0.8), "wood_warm", Vector3.ZERO, 8)
			Mk.st_cyl(st, 0.03, 0.14, Vector3(0, 0.82, 0), Color(1, 0.95, 0.88), "rope", Vector3.ZERO, 8, 0.6)
			Mk.st_box(st, Vector3(0.06, 0.2, 0.015), Vector3(0, 0.97, 0), Color(0.8, 0.82, 0.86), "metal")
			Mk.st_box(st, Vector3(0.035, 0.07, 0.016), Vector3(0, 1.1, 0), Color(0.85, 0.87, 0.9), "metal")
		"metal_spear", "metal_spear_icon":
			var r := 0.045 if id.ends_with("icon") else 0.022
			Mk.st_cyl(st, r, 1.3 if r < 0.03 else 1.0, Vector3(0, 0.2 if r < 0.03 else 0.1, 0), Color(1, 0.93, 0.8), "wood_warm", Vector3.ZERO, 8)
			var tip := 0.82 if r < 0.03 else 0.6
			var k := 1.0 if r < 0.03 else 1.6
			Mk.st_cyl(st, r * 1.5, 0.12 * k, Vector3(0, tip, 0), Color(0.75, 0.77, 0.8), "metal", Vector3.ZERO, 8)
			Mk.st_box(st, Vector3(0.09 * k, 0.26 * k, 0.02 * k), Vector3(0, tip + 0.18 * k, 0), Color(1, 1, 1), "metal")
			Mk.st_box(st, Vector3(0.05 * k, 0.1 * k, 0.022 * k), Vector3(0, tip + 0.35 * k, 0), Color(1, 1, 1), "metal")
		"spear_icon":
			Mk.st_cyl(st, 0.045, 1.0, Vector3(0, 0.1, 0), Color(1, 0.93, 0.8), "wood_warm", Vector3.ZERO, 8)
			Mk.st_cyl(st, 0.055, 0.16, Vector3(0, 0.58, 0), Color(1, 0.95, 0.88), "rope", Vector3.ZERO, 8, 0.6)
			Mk.st_box(st, Vector3(0.14, 0.3, 0.03), Vector3(0, 0.78, 0), Color(0.8, 0.82, 0.86), "metal")
			Mk.st_box(st, Vector3(0.07, 0.1, 0.032), Vector3(0, 0.96, 0), Color(0.85, 0.87, 0.9), "metal")
		"rod_icon", "metal_rod_icon":
			_rod(st, 2.6, id.begins_with("metal"))
		"bobber":
			Mk.st_cyl(st, 0.05, 0.05, Vector3(0, 0.025, 0), Color("#f4f1ea"), "plastic", Vector3.ZERO, 10)
			Mk.st_cyl(st, 0.05, 0.05, Vector3(0, -0.025, 0), Color("#e8452c"), "plastic", Vector3.ZERO, 10)
			Mk.st_cyl(st, 0.008, 0.08, Vector3(0, 0.08, 0), Color("#e8452c"), "plastic", Vector3.ZERO, 6)
		"bait":
			Mk.st_cyl(st, 0.09, 0.06, Vector3(0, 0.03, 0), Color(1, 0.95, 0.9), "clay", Vector3.ZERO, 12, 0.5)
			for i in 4:
				var a := i * 1.7
				Mk.st_box(st, Vector3(0.05, 0.03, 0.035), Vector3(cos(a) * 0.04, 0.07, sin(a) * 0.04), Color("#d98b84"), "white", Vector3(0, a, 0.3))
		"scrap":
			Mk.st_box(st, Vector3(0.36, 0.03, 0.24), Vector3(0, 0.02, 0), Color(0.85, 0.8, 0.75), "metal", Vector3(0, 0.3, 0.1))
			Mk.st_cyl(st, 0.05, 0.3, Vector3(0.05, 0.07, 0.04), Color(0.7, 0.62, 0.55), "metal", Vector3(0, 0.8, PI / 2.0), 8)
			Mk.st_box(st, Vector3(0.14, 0.12, 0.1), Vector3(-0.1, 0.07, -0.05), Color(0.6, 0.55, 0.5), "metal", Vector3(0.2, 0.5, 0))
		"pickaxe":
			Mk.st_cyl(st, 0.026, 0.8, Vector3(0, 0.2, 0), Color(1, 0.93, 0.8), "wood_warm", Vector3.ZERO, 8)
			Mk.st_cyl(st, 0.032, 0.12, Vector3(0, 0.56, 0), Color(1, 0.95, 0.88), "rope", Vector3.ZERO, 8, 0.6)
			var ir := Color(0.62, 0.63, 0.67)
			Mk.st_box(st, Vector3(0.12, 0.07, 0.06), Vector3(0, 0.6, 0), ir, "metal")
			for sx: float in [-1.0, 1.0]:
				Mk.st_box(st, Vector3(0.2, 0.05, 0.045), Vector3(sx * 0.15, 0.58, 0), ir, "metal", Vector3(0, 0, sx * -0.2))
				Mk.st_box(st, Vector3(0.08, 0.035, 0.03), Vector3(sx * 0.27, 0.54, 0), ir.lightened(0.15), "metal", Vector3(0, 0, sx * -0.45))
		"bucket", "bucket_water":
			var wd := Color(1, 0.9, 0.78)
			Mk.st_cyl(st, 0.15, 0.3, Vector3(0, 0.15, 0), wd, "wood_warm", Vector3.ZERO, 14, 1.0, 0.06)
			for y: float in [0.06, 0.25]:
				Mk.st_cyl(st, 0.158, 0.025, Vector3(0, y, 0), Color(0.55, 0.56, 0.6), "metal", Vector3.ZERO, 14)
			for k in 7:
				var a := PI * k / 6.0
				Mk.st_box(st, Vector3(0.05, 0.012, 0.012), Vector3(cos(a) * 0.15, 0.3 + sin(a) * 0.12, 0), Color(0.5, 0.5, 0.55), "metal", Vector3(0, 0, a + PI / 2.0))
			if id == "bucket_water":
				Mk.st_cyl(st, 0.14, 0.01, Vector3(0, 0.27, 0), Color("#2f86c8"), "white", Vector3.ZERO, 14)
			else:
				Mk.st_cyl(st, 0.14, 0.01, Vector3(0, 0.03, 0), Color(0.55, 0.4, 0.3), "wood_dark", Vector3.ZERO, 14)
		"chest":
			IslandLooks.chest_into(st, true)
		"stone":
			for k in 3:
				var g := 0.8 + k * 0.07
				Mk.st_box(st, Vector3(0.2, 0.13, 0.17) * (1.0 - k * 0.18), Vector3(-0.07 + k * 0.08, 0.06, -0.04 + k * 0.05), Color(g, g, g), "rock", Vector3(0.3 * k, k * 1.3, 0.2), 0.6)
		"anchor":
			for x: float in [-0.34, 0.34]:
				Mk.st_box(st, Vector3(0.1, 0.75, 0.14), Vector3(x, 0.375, 0), Color(1, 0.93, 0.84), "wood_dark")
			Mk.st_box(st, Vector3(0.84, 0.08, 0.5), Vector3(0, 0.04, 0), Color(1, 0.93, 0.84), "wood_dark")
			Mk.st_cyl(st, 0.14, 0.58, Vector3(0, 0.55, 0), Color(1, 0.95, 0.88), "rope", Vector3(0, 0, PI / 2.0), 12, 0.6)
			Mk.st_cyl(st, 0.03, 0.82, Vector3(0, 0.55, 0), Color(0.6, 0.6, 0.62), "metal", Vector3(0, 0, PI / 2.0), 8)
			Mk.st_box(st, Vector3(0.04, 0.24, 0.04), Vector3(0.42, 0.45, 0), Color(0.6, 0.6, 0.62), "metal")
			Mk.st_cyl(st, 0.035, 0.16, Vector3(0.48, 0.34, 0), Color(0.75, 0.55, 0.35), "wood", Vector3(0, 0, PI / 2.0), 8)
			var iron := Color(0.42, 0.42, 0.45)
			Mk.st_box(st, Vector3(0.06, 0.5, 0.06), Vector3(0, 0.3, 0.38), iron, "metal", Vector3(0.35, 0, 0))
			Mk.st_box(st, Vector3(0.42, 0.06, 0.06), Vector3(0, 0.08, 0.3), iron, "metal", Vector3(0.35, 0, 0))
			for x: float in [-0.21, 0.21]:
				Mk.st_box(st, Vector3(0.06, 0.16, 0.06), Vector3(x, 0.13, 0.31), iron, "metal", Vector3(0.35, 0, 0.5 * signf(x)))
			Mk.st_cyl(st, 0.07, 0.03, Vector3(0, 0.56, 0.48), iron, "metal", Vector3(PI / 2.0, 0, 0), 10)
		"anchor_rope":
			Mk.st_cyl(st, 0.025, 4.0, Vector3(0, -2.0, 0), Color(1, 0.95, 0.88), "rope", Vector3.ZERO, 6, 0.4)
		"crab_meat", "crab_cooked":
			# A crab claw: a rounded palm, two pincer fingers in a V and a jointed arm.
			var cooked := id == "crab_cooked"
			var shell := Color("#e0482a") if cooked else Color("#c47a55")
			var tip := Color("#3a2a24")
			var rz := Vector3(0, 0, PI / 2.0)
			Mk.st_cyl(st, 0.07, 0.17, Vector3(0, 0.07, 0), shell, "clay", rz, 12, 0.5, 0.45)
			# Upper finger tilts up, lower one down: an open pincer.
			Mk.st_box(st, Vector3(0.2, 0.045, 0.055), Vector3(0.17, 0.13, 0), shell.lightened(0.08), "clay", Vector3(0, 0, 0.45), 0.5)
			Mk.st_box(st, Vector3(0.17, 0.04, 0.05), Vector3(0.16, 0.025, 0), shell.lightened(0.12), "clay", Vector3(0, 0, -0.35), 0.5)
			Mk.st_box(st, Vector3(0.05, 0.035, 0.04), Vector3(0.265, 0.18, 0), tip, "white", Vector3(0, 0, 0.45))
			Mk.st_box(st, Vector3(0.045, 0.03, 0.035), Vector3(0.24, -0.005, 0), tip, "white", Vector3(0, 0, -0.35))
			Mk.st_cyl(st, 0.035, 0.12, Vector3(-0.13, 0.06, 0), shell.darkened(0.08), "clay", rz, 8, 0.5)
			Mk.st_cyl(st, 0.04, 0.03, Vector3(-0.2, 0.06, 0), Color("#f6d8c4") if not cooked else Color("#f8e6d4"), "clay", rz, 8, 0.5)
		"fruit_salad":
			# A coconut shell bowl heaped with banana and pineapple pieces.
			Mk.st_cyl(st, 0.16, 0.1, Vector3(0, 0.05, 0), Color("#7a5532"), "clay", Vector3.ZERO, 14, 1.0, 0.3)
			Mk.st_cyl(st, 0.145, 0.02, Vector3(0, 0.1, 0), Color("#f4ecd8"), "white", Vector3.ZERO, 14)
			var bits := [[Color("#f2d24a"), Vector3(0.05, 0.12, 0.03)], [Color("#f4b23c"), Vector3(-0.05, 0.12, 0.04)], [Color("#fff2c0"), Vector3(0.0, 0.13, -0.05)],
					[Color("#e9d07a"), Vector3(0.07, 0.12, -0.05)], [Color("#f6a830"), Vector3(-0.06, 0.12, -0.04)]]
			for b: Array in bits:
				Mk.st_box(st, Vector3(0.05, 0.04, 0.05), b[1], b[0], "white", Vector3(0.3, b[1].x * 20.0, 0.2))
		"bandage":
			Mk.st_cyl(st, 0.09, 0.1, Vector3(0, 0.09, 0), Color("#f2efe6"), "canvas", Vector3(PI / 2.0, 0, 0), 14, 0.5)
			Mk.st_cyl(st, 0.035, 0.102, Vector3(0, 0.09, 0), Color("#d9d2c0"), "canvas", Vector3(PI / 2.0, 0, 0), 10, 0.5)
			Mk.st_box(st, Vector3(0.12, 0.004, 0.08), Vector3(0.07, 0.003, 0.0), Color("#f2efe6"), "canvas", Vector3(0, 0, 0.1), 0.5)
			Mk.st_box(st, Vector3(0.02, 0.06, 0.004), Vector3(0, 0.09, 0.052), Color("#d8352a"), "white")
			Mk.st_box(st, Vector3(0.06, 0.02, 0.004), Vector3(0, 0.09, 0.052), Color("#d8352a"), "white")
		"banana_shoot":
			leaf = true
			var r := Mk.cell("palm")
			for a in 3:
				var b := Basis(Vector3.UP, a * TAU / 3.0 + 0.4)
				Mk.st_quad(st, [b * Vector3(-0.03, 0.08, 0.0), b * Vector3(0.03, 0.08, 0.0), b * Vector3(0.1, 0.36, 0.2), b * Vector3(-0.1, 0.36, 0.2)], r, Color(1.05, 1.2, 0.8))
			Mk.st_cyl(st, 0.02, 0.12, Vector3(0, 0.07, 0), Color("#8fb05a"), "white", Vector3.ZERO, 8)
			Mk.st_cyl(st, 0.07, 0.07, Vector3(0, 0.03, 0), Color("#6a4a30"), "clay", Vector3.ZERO, 10, 0.5, 0.4)
		"seeds":
			Mk.st_cyl(st, 0.08, 0.12, Vector3(0, 0.06, 0), Color("#e2cd98"), "canvas", Vector3.ZERO, 10, 0.5, 0.25)
			Mk.st_cyl(st, 0.03, 0.04, Vector3(0, 0.14, 0), Color(1, 0.95, 0.88), "rope", Vector3.ZERO, 8, 0.5)
			Mk.st_box(st, Vector3(0.05, 0.05, 0.05), Vector3(0.0, 0.18, 0), Color("#6a8a3a"), "white", Vector3(0, 0.6, 0.3))
		"sprout":
			leaf = true
			for a in 5:
				var yaw := a * TAU / 5.0
				var b := Basis(Vector3.UP, yaw)
				var r := Mk.cell("palm")
				Mk.st_quad(st, [b * Vector3(-0.05, 0.0, 0.0), b * Vector3(0.05, 0.0, 0.0), b * Vector3(0.09, 0.42, 0.18), b * Vector3(-0.09, 0.42, 0.18)], r, Color(0.8, 1, 0.75))
		"cup_water":
			Mk.st_cyl(st, 0.07, 0.12, Vector3(0, 0.06, 0), Color(1, 0.95, 0.9), "clay", Vector3.ZERO, 12, 0.5)
			Mk.st_cyl(st, 0.062, 0.005, Vector3(0, 0.11, 0), Color("#5fb4e8"), "white", Vector3.ZERO, 12)
		"tile":
			return Raft.tile_preview_mesh()
		"purifier", "grill", "planter":
			_station(st, id)
		_:
			if id in STRUCTURES:
				_structure(st, id)
			elif id in DecorLooks.IDS:
				leaf = DecorLooks.build(st, id)
			elif id in GearLooks.IDS:
				leaf = GearLooks.build(st, id)
			else:
				Mk.st_box(st, Vector3(0.25, 0.25, 0.25), Vector3.ZERO, Color("#ff00ff"))
	var m := Mk.st_commit(st, leaf)
	_cache[id] = m
	return m


## A fishing rod along +Y, tip at y 0.86: cork grip, a reel with line on its spool,
## a dark tapered blank with red thread wraps and line guides. The strong rod: a steel
## blank, gold wraps and reel.
static func _rod(st: SurfaceTool, k := 1.0, strong := false) -> void:
	var metal := Color("#e0b44a") if strong else Color(0.72, 0.74, 0.78)
	var rz := Vector3(0, 0, PI / 2.0)
	Mk.st_cyl(st, 0.029 * k, 0.03, Vector3(0, -0.245, 0), Color(0.18, 0.18, 0.2), "plastic", Vector3.ZERO, 10)
	Mk.st_cyl(st, 0.027 * k, 0.24, Vector3(0, -0.11, 0), Color("#d9b083"), "clay", Vector3.ZERO, 12, 0.35, 0.08)
	Mk.st_cyl(st, 0.022 * k, 0.08, Vector3(0, 0.05, 0), metal, "metal", Vector3.ZERO, 10)
	var rx := 0.02 * k + 0.01
	Mk.st_box(st, Vector3(rx + 0.02, 0.012, 0.022), Vector3(rx * 0.5 + 0.01, 0.05, 0), metal, "metal")
	Mk.st_cyl(st, 0.048 * k, 0.016 * k, Vector3(rx + 0.04, 0.05, 0), metal, "metal", rz, 16)
	Mk.st_cyl(st, 0.036 * k, 0.034 * k, Vector3(rx + 0.04 + 0.025 * k, 0.05, 0), Color(0.96, 0.95, 0.88), "rope", rz, 14, 0.3)
	Mk.st_cyl(st, 0.044 * k, 0.01 * k, Vector3(rx + 0.04 + 0.047 * k, 0.05, 0), Color(0.2, 0.2, 0.22), "plastic", rz, 16)
	var hx := rx + 0.04 + 0.055 * k
	Mk.st_box(st, Vector3(0.008 * k, 0.06 * k, 0.008 * k), Vector3(hx, 0.05 + 0.025 * k, 0), metal, "metal")
	Mk.st_cyl(st, 0.009 * k, 0.024 * k, Vector3(hx + 0.01 * k, 0.05 + 0.05 * k, 0), Color(0.15, 0.15, 0.16), "plastic", rz, 8)
	var blank := Color(0.42, 0.48, 0.56) if strong else Color(0.16, 0.2, 0.17)
	for sec: Array in [[0.09, 0.42, 0.016, 0.012], [0.42, 0.68, 0.012, 0.0085], [0.68, 0.86, 0.0085, 0.005]]:
		var r0 := (float(sec[2]) + float(sec[3])) / 2.0 * k * (1.2 if strong else 1.0)
		Mk.st_cyl(st, r0, float(sec[1]) - float(sec[0]), Vector3(0, (float(sec[0]) + float(sec[1])) / 2.0, 0), blank, "metal" if strong else "plastic", Vector3.ZERO, 10, 1.5)
	for g: Array in [[0.24, 0.015, 0.016], [0.45, 0.012, 0.012], [0.62, 0.01, 0.01], [0.76, 0.008, 0.008], [0.855, 0.006, 0.006]]:
		var y := float(g[0])
		var r := float(g[1]) * k
		var gr := float(g[2]) * k
		Mk.st_cyl(st, r * (1.2 if strong else 1.0) + 0.0035 * k, 0.03, Vector3(0, y, 0), Color("#1f3f8a") if strong else Color("#b8322a"), "white", Vector3.ZERO, 8)
		Mk.st_box(st, Vector3(gr + 0.006 * k, 0.006 * k, 0.004 * k), Vector3(r + gr * 0.5, y, 0), metal, "metal")
		Mk.st_cyl(st, gr, 0.005 * k, Vector3(r + gr + 0.004 * k, y, 0), metal, "metal", Vector3.ZERO, 10)


## A palm frond: three bent quads along +X with the palm atlas cell.
static func _frond(st: SurfaceTool, at: Vector3, yaw: float, length: float) -> void:
	var r := Mk.cell("palm")
	var b := Basis(Vector3.UP, yaw)
	var segs := 3
	var half_w := length * 0.3
	for i in segs:
		var u0 := float(i) / segs
		var u1 := float(i + 1) / segs
		var x0 := (u0 - 0.5) * length
		var x1 := (u1 - 0.5) * length
		var y0 := -sin(u0 * PI) * 0.0 + u0 * u0 * -0.08
		var y1 := u1 * u1 * -0.08
		var c := [at + b * Vector3(x0, y0, -half_w), at + b * Vector3(x1, y1, -half_w), at + b * Vector3(x1, y1, half_w), at + b * Vector3(x0, y0, half_w)]
		# The texture's stem runs bottom→top, so map texture V along the frond.
		var sub := Rect2(r.position + Vector2(0, r.size.y * (1.0 - u1)), Vector2(r.size.x, r.size.y / segs))
		Mk.st_quad(st, [c[3], c[0], c[1], c[2]], sub, Color(1, 1, 1))


## Station bodies (fire, steam and food are separate nodes in Station).
static func _station(st: SurfaceTool, kind: String) -> void:
	var brick := Color(1, 0.92, 0.85)
	if kind == "planter":
		for x: float in [-0.55, 0.55]:
			Mk.st_box(st, Vector3(0.08, 0.36, 1.2), Vector3(x, 0.18, 0), Color(1, 0.93, 0.84), "wood")
		for z: float in [-0.56, 0.56]:
			Mk.st_box(st, Vector3(1.18, 0.36, 0.08), Vector3(0, 0.18, z), Color(1, 0.93, 0.84), "wood")
		Mk.st_box(st, Vector3(1.04, 0.3, 1.04), Vector3(0, 0.15, 0), Color(0.45, 0.32, 0.22), "clay", Vector3.ZERO, 1.0)
		return
	var dark := Color(0.98, 0.9, 0.82)
	var iron := Color(0.42, 0.43, 0.47)
	var ash := Color(0.15, 0.13, 0.12)
	if kind == "purifier":
		# A brick stove, a big clay boiler with a lid, a pipe through a cooling coil into a
		# cup on its own little shelf.
		Mk.st_box(st, Vector3(0.66, 0.42, 0.66), Vector3(0, 0.21, 0), brick, "bricks", Vector3.ZERO, 1.0)
		Mk.st_box(st, Vector3(0.7, 0.04, 0.7), Vector3(0, 0.43, 0), brick.darkened(0.15), "bricks", Vector3.ZERO, 1.0)
		Mk.st_box(st, Vector3(0.3, 0.18, 0.04), Vector3(0, 0.13, 0.32), ash, "ash")
		Mk.st_cyl(st, 0.3, 0.04, Vector3(0, 0.47, 0), iron, "metal", Vector3.ZERO, 16)
		Mk.st_cyl(st, 0.27, 0.36, Vector3(0, 0.67, 0), Color(1, 0.93, 0.86), "clay", Vector3.ZERO, 16, 0.8, 0.15)
		Mk.st_cyl(st, 0.255, 0.05, Vector3(0, 0.86, 0), Color(1, 0.97, 0.92), "clay", Vector3.ZERO, 16, 0.8)
		Mk.st_cyl(st, 0.23, 0.06, Vector3(0, 0.9, 0), Color(0.78, 0.8, 0.84), "metal", Vector3.ZERO, 16, 1.0, 0.4)
		Mk.st_cyl(st, 0.03, 0.05, Vector3(-0.08, 0.95, 0), iron, "metal", Vector3.ZERO, 8)
		var copper := Color(0.95, 0.62, 0.42)
		Mk.st_cyl(st, 0.022, 0.16, Vector3(0.06, 0.99, 0), copper, "metal", Vector3.ZERO, 8)
		Mk.st_cyl(st, 0.022, 0.36, Vector3(0.24, 1.07, 0), copper, "metal", Vector3(0, 0, PI / 2.0), 8)
		Mk.st_cyl(st, 0.022, 0.3, Vector3(0.42, 0.92, 0), copper, "metal", Vector3.ZERO, 8)
		for k in 3:
			Mk.st_cyl(st, 0.075, 0.02, Vector3(0.42, 0.8 + k * 0.08, 0), copper.darkened(0.1), "metal", Vector3(0.25, 0, 0), 12)
		Mk.st_box(st, Vector3(0.26, 0.04, 0.3), Vector3(0.44, 0.44, 0.06), Color(1, 0.93, 0.84), "wood")
		Mk.st_box(st, Vector3(0.05, 0.42, 0.05), Vector3(0.52, 0.21, 0.16), Color(1, 0.93, 0.84), "wood_dark")
	else:
		# The grill: a brick firebox on a wooden stand with firewood below, an iron grate,
		# a back plate with a little chimney and a side board.
		for x: float in [-0.36, 0.36]:
			for z: float in [-0.22, 0.22]:
				Mk.st_box(st, Vector3(0.07, 0.5, 0.07), Vector3(x, 0.25, z), dark, "wood_dark")
		Mk.st_box(st, Vector3(0.8, 0.04, 0.52), Vector3(0, 0.16, 0), Color(1, 0.93, 0.84), "wood")
		for k in 3:
			Mk.st_cyl(st, 0.045, 0.46, Vector3(-0.16 + k * 0.15, 0.23, 0), Color(0.85, 0.7, 0.55), "wood", Vector3(PI / 2.0, 0, 0), 8)
		Mk.st_box(st, Vector3(0.88, 0.34, 0.6), Vector3(0, 0.67, 0), brick, "bricks", Vector3.ZERO, 1.0)
		Mk.st_box(st, Vector3(0.48, 0.17, 0.04), Vector3(0, 0.62, 0.3), ash, "ash")
		Mk.st_box(st, Vector3(0.74, 0.04, 0.46), Vector3(0, 0.85, 0), Color(0.2, 0.17, 0.15), "ash")
		for k in 9:
			Mk.st_box(st, Vector3(0.014, 0.014, 0.5), Vector3(-0.34 + k * 0.085, 0.9, 0), iron, "metal")
		for z: float in [-0.24, 0.0, 0.24]:
			Mk.st_box(st, Vector3(0.78, 0.016, 0.016), Vector3(0, 0.9, z), iron, "metal")
		Mk.st_box(st, Vector3(0.88, 0.32, 0.03), Vector3(0, 1.0, -0.29), iron, "metal")
		Mk.st_cyl(st, 0.05, 0.42, Vector3(0.32, 1.25, -0.27), iron.darkened(0.1), "metal", Vector3.ZERO, 10)
		Mk.st_cyl(st, 0.07, 0.04, Vector3(0.32, 1.47, -0.27), iron.darkened(0.2), "metal", Vector3.ZERO, 10)
		Mk.st_box(st, Vector3(0.26, 0.04, 0.5), Vector3(0.58, 0.8, 0), Color(1, 0.93, 0.84), "wood")
		Mk.st_box(st, Vector3(0.03, 0.2, 0.03), Vector3(0.6, 0.68, 0.22), iron, "metal")
		Mk.st_box(st, Vector3(0.08, 0.012, 0.1), Vector3(0.6, 0.57, 0.22), iron, "metal")


## The shark as two meshes, [body, tail]: a lofted body (nose at -Z) with dorsal and
## pectoral fins; the tail starts at the joint so it can swing. Gray back, white belly.
static func shark_parts(length := 2.6) -> Array[ArrayMesh]:
	var rings := 14
	var seg := 12
	var joint := 9
	var back := Color("#3e4e5c")
	var belly := Color("#d8dcdf")
	var pts: Array = []
	for i in rings + 1:
		var u := float(i) / rings
		var z := (u - 0.5) * length
		var r := 0.42 * pow(sin(PI * (0.06 + 0.9 * u)), 0.75) * (1.0 - 0.55 * u * u)
		var ring: Array = []
		for j in seg:
			var a := TAU * j / seg
			ring.append(Vector3(cos(a) * r * 0.78, sin(a) * r, z))
		pts.append(ring)
	var parts: Array[ArrayMesh] = []
	var r_white := Mk.cell("white")
	var uv := r_white.get_center()
	var joint_z: float = pts[joint][0].z
	for part in 2:
		var st := Mk.st_begin()
		st.set_uv(uv)
		var i0 := 0 if part == 0 else joint
		var i1 := joint if part == 0 else rings
		var off := Vector3.ZERO if part == 0 else Vector3(0, 0, -joint_z)
		for i in range(i0, i1):
			for j in seg:
				var a: Vector3 = pts[i][j]
				var b: Vector3 = pts[i][(j + 1) % seg]
				var c: Vector3 = pts[i + 1][(j + 1) % seg]
				var d: Vector3 = pts[i + 1][j]
				for v: Vector3 in [a, c, b, a, d, c]:
					var n := Vector3(v.x, v.y, 0).normalized()
					st.set_color(back.lerp(belly, smoothstep(0.2, -0.45, n.y)))
					st.set_normal(n)
					st.set_uv(uv)
					st.add_vertex(v + off)
		if part == 0:
			var tip := Vector3(0, 0.02, -length * 0.52)
			for j in seg:
				var a: Vector3 = pts[0][j]
				var b: Vector3 = pts[0][(j + 1) % seg]
				for v: Vector3 in [tip, a, b]:
					st.set_color(back)
					st.set_normal((v - Vector3(0, 0, -length * 0.4)).normalized())
					st.set_uv(uv)
					st.add_vertex(v)
			var zf := -length * 0.08
			_fin(st, [Vector3(0, 0.3, zf - 0.32), Vector3(0, 1.15, zf + 0.16), Vector3(0, 0.3, zf + 0.34)], back.darkened(0.15), uv)
			for sx: float in [-1.0, 1.0]:
				_fin(st, [Vector3(sx * 0.25, -0.15, -length * 0.2), Vector3(sx * 0.75, -0.42, -length * 0.02), Vector3(sx * 0.25, -0.15, -length * 0.05)], back, uv)
			for sx: float in [-1.0, 1.0]:
				Mk.st_box(st, Vector3(0.03, 0.04, 0.04), Vector3(sx * 0.2, 0.08, -length * 0.38), Color(0.05, 0.05, 0.06), "white")
			Mk.st_box(st, Vector3(0.22, 0.02, 0.12), Vector3(0, -0.16, -length * 0.4), Color(0.25, 0.12, 0.12), "white")
		else:
			var tz := length / 2.0 - joint_z
			_fin(st, [Vector3(0, 0.0, tz - 0.15), Vector3(0, 0.7, tz + 0.35), Vector3(0, 0.05, tz + 0.05)], back.darkened(0.1), uv)
			_fin(st, [Vector3(0, 0.0, tz - 0.12), Vector3(0, -0.42, tz + 0.25), Vector3(0, -0.02, tz + 0.04)], back.darkened(0.1), uv)
		parts.append(Mk.st_commit(st))
	return parts


## A double-sided fin triangle.
static func _fin(st: SurfaceTool, p: Array, c: Color, uv: Vector2) -> void:
	var n: Vector3 = (p[1] - p[0]).cross(p[2] - p[0]).normalized()
	for side: float in [1.0, -1.0]:
		var order := [p[0], p[1], p[2]] if side > 0.0 else [p[0], p[2], p[1]]
		for v: Vector3 in order:
			st.set_color(c)
			st.set_normal(n * side * -1.0)
			st.set_uv(uv)
			st.add_vertex(v)




## Raft structures. Walls span X (centered), stand on y = 0, are 0.1 thick in Z.
## Stairs rise toward +Z. The door leaf hinges at its local x = 0.
static func _structure(st: SurfaceTool, id: String) -> void:
	var wood := Color(1, 0.93, 0.84)
	var dark := Color(1, 0.95, 0.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	match id:
		"wall", "window":
			var n := 5
			var w := T / n
			for i in n:
				var x := -T / 2.0 + w * (i + 0.5)
				var tint := wood.darkened(rng.randf_range(-0.05, 0.15))
				var hh := H - rng.randf_range(0.0, 0.06)
				if id == "window" and i >= 1 and i <= 3:
					Mk.st_box(st, Vector3(w - 0.02, 0.95, 0.06), Vector3(x, 0.475, 0), tint, "wood", Vector3.ZERO)
					Mk.st_box(st, Vector3(w - 0.02, hh - 1.75, 0.06), Vector3(x, 1.75 + (hh - 1.75) / 2.0, 0), tint, "wood", Vector3.ZERO)
				else:
					Mk.st_box(st, Vector3(w - 0.02, hh, 0.06), Vector3(x, hh / 2.0, 0), tint, "wood", Vector3(0, 0, rng.randf_range(-0.01, 0.01)))
			for y: float in [0.45, 2.0]:
				Mk.st_box(st, Vector3(T - 0.04, 0.12, 0.05), Vector3(0, y, -0.055), dark, "wood_dark")
			if id == "window":
				for y: float in [0.95, 1.75]:
					Mk.st_box(st, Vector3(0.9, 0.06, 0.1), Vector3(0, y, 0), dark, "wood_dark")
				for x: float in [-0.45, 0.45]:
					Mk.st_box(st, Vector3(0.06, 0.86, 0.1), Vector3(x, 1.35, 0), dark, "wood_dark")
				Mk.st_box(st, Vector3(0.84, 0.04, 0.04), Vector3(0, 1.35, 0), dark, "wood_dark")
		"door", "door_frame", "door_ajar":
			for x: float in [-0.66, 0.66]:
				Mk.st_box(st, Vector3(0.18, H, 0.14), Vector3(x, H / 2.0, 0), dark, "wood_dark")
			Mk.st_box(st, Vector3(T, 0.3, 0.14), Vector3(0, H - 0.15, 0), dark, "wood_dark")
			if id != "door_frame":
				# The building ghost shows the leaf ajar, so you see which way it opens.
				_door_leaf(st, Vector3(-0.56, 0, 0), -0.75 if id == "door_ajar" else 0.0)
		"door_leaf":
			_door_leaf(st, Vector3.ZERO)
		"pillar":
			Mk.st_box(st, Vector3(0.17, H, 0.17), Vector3(0, H / 2.0, 0), dark, "wood_dark")
			for y: float in [0.25, H - 0.3]:
				Mk.st_cyl(st, 0.11, 0.12, Vector3(0, y, 0), Color(1, 0.96, 0.9), "rope", Vector3.ZERO, 10, 0.6)
		"lantern", "lantern_tall":
			var ph := 1.35 if id == "lantern" else TALL_LAMP
			Mk.st_box(st, Vector3(0.08 if id == "lantern" else 0.11, ph, 0.08 if id == "lantern" else 0.11), Vector3(0, ph / 2.0, 0), dark, "wood_dark")
			Mk.st_box(st, Vector3(0.3, 0.04, 0.06), Vector3(0.1, ph - 0.02, 0), dark, "wood_dark")
			_lamp_head(st, Vector3(0.22, ph - 0.23, 0))
		"lantern_wall":
			Mk.st_box(st, Vector3(0.12, 0.2, 0.03), Vector3(0, 1.85, 0.015), dark, "wood_dark")
			Mk.st_box(st, Vector3(0.04, 0.04, 0.3), Vector3(0, 1.92, 0.15), dark, "wood_dark")
			_lamp_head(st, Vector3(0, 1.69, 0.26))
		"roof":
			for i in 5:
				var z := -T / 2.0 + T / 5.0 * (i + 0.5)
				Mk.st_box(st, Vector3(T, 0.07, T / 5.0 - 0.02), Vector3(0, H - 0.11, z), dark.darkened(rng.randf_range(0.0, 0.12)), "wood_dark")
			Mk.st_box(st, Vector3(T + 0.08, 0.06, T + 0.08), Vector3(0, H - 0.04, 0), Color("#e2cd98"), "canvas", Vector3.ZERO, 1.0)
			for k in 4:
				var a := k * PI / 2.0
				var d := Vector3(sin(a), 0, cos(a))
				Mk.st_box(st, Vector3(T + 0.12, 0.05, 0.1), d * (T / 2.0 + 0.04) + Vector3(0, H - 0.09, 0), Color("#c9b27a"), "canvas", Vector3(0, a, 0), 1.0)
		"stairs":
			var steps := 7
			for i in steps:
				var u := (i + 0.5) / steps
				Mk.st_box(st, Vector3(T - 0.24, 0.06, T / steps + 0.03), Vector3(0, u * H - 0.03, -T / 2.0 + u * T), wood.darkened(rng.randf_range(0.0, 0.12)), "wood")
			var slope := atan2(H, T)
			var slen := sqrt(H * H + T * T)
			for x: float in [-T / 2.0 + 0.08, T / 2.0 - 0.08]:
				Mk.st_box(st, Vector3(0.08, 0.16, slen), Vector3(x, H / 2.0 - 0.05, 0), dark, "wood_dark", Vector3(-slope, 0, 0))
				Mk.st_box(st, Vector3(0.05, 0.05, slen), Vector3(x, H / 2.0 + 0.85, 0), dark, "wood_dark", Vector3(-slope, 0, 0))
				Mk.st_box(st, Vector3(0.05, 0.9, 0.05), Vector3(x, 0.45, -T / 2.0 + 0.05), dark, "wood_dark")
		"collector":
			Mk.st_cyl(st, 0.32, 0.75, Vector3(0, 0.375, 0), Color(1, 0.9, 0.8), "wood_warm", Vector3.ZERO, 14, 1.2, 0.08)
			_funnel(st, 0.3, 0.8, 0.66, 1.18, Color("#e8d8b0"))
			for y: float in [0.12, 0.62]:
				Mk.st_cyl(st, 0.345, 0.05, Vector3(0, y, 0), Color(0.6, 0.62, 0.66), "metal", Vector3.ZERO, 14)
			for a in 4:
				var yaw := a * PI / 2.0 + PI / 4.0
				var dv := Vector3(sin(yaw), 0, cos(yaw))
				Mk.st_box(st, Vector3(0.05, 0.6, 0.05), dv * 0.52 + Vector3(0, 0.95, 0), dark, "wood_dark", Vector3(0, yaw, 0))
		"hammock":
			for x: float in [-0.66, 0.66]:
				Mk.st_box(st, Vector3(0.1, 1.15, 0.1), Vector3(x, 0.575, 0), dark, "wood_dark")
				Mk.st_cyl(st, 0.07, 0.08, Vector3(x, 1.0, 0), Color(1, 0.96, 0.9), "rope", Vector3.ZERO, 8, 0.6)
			var segs := 8
			for i in segs:
				var u0 := float(i) / segs
				var u1 := float(i + 1) / segs
				var x0 := lerpf(-0.6, 0.6, u0)
				var x1 := lerpf(-0.6, 0.6, u1)
				var y0 := 0.95 - sin(PI * u0) * 0.45
				var y1 := 0.95 - sin(PI * u1) * 0.45
				var mid := Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, 0)
				var ang := atan2(y1 - y0, x1 - x0)
				Mk.st_box(st, Vector3(Vector2(x1 - x0, y1 - y0).length() + 0.01, 0.025, 0.62), mid, Color("#e8d8b0"), "canvas", Vector3(0, 0, ang), 1.0)
			for z: float in [-0.31, 0.31]:
				Mk.st_box(st, Vector3(0.02, 0.02, 0.02), Vector3(0, 0.5, z), Color("#b03a2a"), "white")
		"net", "net_strong":
			# The strong net: thicker posts with iron caps, a tarred denser mesh.
			var strong := id == "net_strong"
			var post := 0.1 if strong else 0.07
			var cord := Color(0.55, 0.45, 0.32) if strong else Color(1, 0.97, 0.9)
			var th := 0.026 if strong else 0.018
			for x: float in [-0.7, 0.7]:
				Mk.st_box(st, Vector3(post, 1.15, post), Vector3(x, 0.05, 0), dark, "wood_dark")
				if strong:
					Mk.st_box(st, Vector3(post + 0.02, 0.08, post + 0.02), Vector3(x, 0.62, 0), Color(0.55, 0.55, 0.58), "metal")
			var rows := 7 if strong else 5
			for i in rows:
				var y := -0.45 + i * 0.88 / (rows - 1)
				Mk.st_box(st, Vector3(1.36, th, th), Vector3(0, y, 0), cord, "rope", Vector3.ZERO, 0.6)
			var cols := 12 if strong else 9
			for i in cols:
				var x := -0.64 + i * 1.28 / (cols - 1)
				Mk.st_box(st, Vector3(th, 0.92, th), Vector3(x, 0.0, 0), cord, "rope", Vector3.ZERO, 0.6)
			Mk.st_box(st, Vector3(1.45, 0.05 if strong else 0.04, 0.05 if strong else 0.04), Vector3(0, 0.5, 0), cord.lightened(0.1), "rope", Vector3.ZERO, 0.6)
		"trap":
			# Two beams out over the water and a rope cage hanging half under it.
			for x: float in [-0.45, 0.45]:
				Mk.st_box(st, Vector3(0.08, 0.08, 1.1), Vector3(x, 0.04, 0.45), dark, "wood_dark")
			var cage := Vector3(0.9, 0.62, 0.66)
			var cc := Vector3(0, -0.3, 0.78)
			for x: float in [-0.43, 0.43]:
				for z: float in [-0.31, 0.31]:
					Mk.st_box(st, Vector3(0.05, cage.y, 0.05), cc + Vector3(x, 0, z), dark, "wood_dark")
			for y: float in [-0.3, 0.3]:
				for z: float in [-0.31, 0.31]:
					Mk.st_box(st, Vector3(cage.x, 0.05, 0.05), cc + Vector3(0, y, z), dark, "wood_dark")
				for x: float in [-0.43, 0.43]:
					Mk.st_box(st, Vector3(0.05, 0.05, cage.z), cc + Vector3(x, y, 0), dark, "wood_dark")
			for i in 6:
				var x := -0.36 + i * 0.145
				for z: float in [-0.31, 0.31]:
					Mk.st_box(st, Vector3(0.015, cage.y - 0.06, 0.015), cc + Vector3(x, 0, z), Color(1, 0.97, 0.9), "rope", Vector3.ZERO, 0.6)
			for i in 4:
				var z := -0.22 + i * 0.145
				for x: float in [-0.43, 0.43]:
					Mk.st_box(st, Vector3(0.015, cage.y - 0.06, 0.015), cc + Vector3(x, 0, z), Color(1, 0.97, 0.9), "rope", Vector3.ZERO, 0.6)
			Mk.st_cyl(st, 0.13, 0.5, cc + Vector3(0, 0.38, 0), Color(1, 0.9, 0.8), "plastic", Vector3(0, 0, PI / 2.0), 10, 0.6, 0.2)


## A double-sided canvas funnel (cone frustum) from radius r0 at y0 up to r1 at y1.
static func _funnel(st: SurfaceTool, r0: float, y0: float, r1: float, y1: float, c: Color) -> void:
	var seg := 14
	var cell := Mk.cell("canvas")
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var p := [Vector3(cos(a0) * r0, y0, sin(a0) * r0), Vector3(cos(a1) * r0, y0, sin(a1) * r0),
			Vector3(cos(a1) * r1, y1, sin(a1) * r1), Vector3(cos(a0) * r1, y1, sin(a0) * r1)]
		var uv := Rect2(cell.position + Vector2(cell.size.x * i / seg, 0), Vector2(cell.size.x / seg, cell.size.y))
		Mk.st_quad(st, p, uv, c)
		Mk.st_quad(st, [p[0], p[3], p[2], p[1]], uv, c.darkened(0.15))


## A small metal-framed lamp whose center is at `at`.
static func _lamp_head(st: SurfaceTool, at: Vector3) -> void:
	var iron := Color(0.55, 0.56, 0.6)
	Mk.st_box(st, Vector3(0.16, 0.03, 0.16), at + Vector3(0, 0.12, 0), iron, "metal")
	Mk.st_box(st, Vector3(0.16, 0.03, 0.16), at + Vector3(0, -0.12, 0), iron, "metal")
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		Mk.st_box(st, Vector3(0.015, 0.24, 0.015), at + Vector3(c.x * 0.07, 0, c.y * 0.07), Color(0.5, 0.5, 0.55), "metal")


## A plank door 1.12 wide, hinged at its left edge (local x = 0 → at `at`).
static func _door_leaf(st: SurfaceTool, at: Vector3, yaw := 0.0) -> void:
	var wood := Color(1, 0.9, 0.78)
	var b := Basis(Vector3.UP, yaw)
	for i in 4:
		Mk.st_box(st, Vector3(0.26, 2.05, 0.05), at + b * Vector3(0.14 + i * 0.28, 1.04, 0), wood, "wood_warm", Vector3(0, yaw, 0))
	for y: float in [0.35, 1.7]:
		Mk.st_box(st, Vector3(1.08, 0.1, 0.04), at + b * Vector3(0.56, y, -0.045), Color(1, 0.95, 0.9), "wood_dark", Vector3(0, yaw, 0))
	Mk.st_box(st, Vector3(1.4, 0.08, 0.035), at + b * Vector3(0.56, 1.03, -0.045), Color(1, 0.95, 0.9), "wood_dark", Vector3(0, yaw, 0.98))
	Mk.st_cyl(st, 0.03, 0.04, at + b * Vector3(0.98, 1.0, 0.04), Color(0.6, 0.6, 0.62), "metal", Vector3(PI / 2.0, yaw, 0), 8)
