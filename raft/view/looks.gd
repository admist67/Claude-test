class_name Looks
## Visuals for items: floating debris, tools in hand, food and stations. Merged textured
## meshes on the CC0 atlas; Kenney CC0 models for some food.

const MODELS := {
	"coconut": ["res://assets/models/food/coconut.glb", 0.9],
	"banana": ["res://assets/models/food/banana.glb", 0.9],
	"pineapple": ["res://assets/models/food/pineapple.glb", 0.6],
}
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
			"hook":
				mi.scale = Vector3.ONE * 0.45
				mi.rotation = Vector3(0.5, 0.4, -0.2)
				mi.position = Vector3(0.06, -0.08, -0.05)
			"hammer":
				mi.scale = Vector3.ONE * 0.7
				mi.rotation = Vector3(0.3, -0.4, 0.2)
				mi.position = Vector3(0.06, -0.12, 0.0)
			"rod":
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
	var st := Mk.st_begin()
	var leaf := false
	match id:
		"plank":
			Mk.st_box(st, Vector3(1.05, 0.065, 0.24), Vector3.ZERO, Color(1, 0.93, 0.82), "wood")
			for x: float in [-0.38, 0.38]:
				Mk.st_box(st, Vector3(0.02, 0.012, 0.02), Vector3(x, 0.036, 0.05), Color(0.5, 0.5, 0.52), "metal")
		"plastic", "water":
			var tint := PLASTIC if id == "plastic" else Color("#9fd2f5")
			Mk.st_cyl(st, 0.1, 0.3, Vector3(0, 0.1, 0), tint, "plastic", Vector3(0, 0, PI / 2.0), 12, 1.0, 0.06)
			Mk.st_cyl(st, 0.045, 0.08, Vector3(0.18, 0.1, 0), tint, "plastic", Vector3(0, 0, PI / 2.0), 10)
			Mk.st_cyl(st, 0.05, 0.04, Vector3(0.24, 0.1, 0), CAP, "plastic", Vector3(0, 0, PI / 2.0), 10)
			if id == "water":
				Mk.st_cyl(st, 0.102, 0.16, Vector3(-0.04, 0.1, 0), Color("#3d8fd6"), "plastic", Vector3(0, 0, PI / 2.0), 12)
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
			Mk.st_cyl(st, 0.018, 0.9, Vector3(0, 0.4, 0), Color(1, 0.93, 0.8), "wood_warm", Vector3.ZERO, 8)
			Mk.st_cyl(st, 0.026, 0.22, Vector3(0, -0.12, 0), Color(1, 0.95, 0.88), "rope", Vector3.ZERO, 8, 0.6)
			Mk.st_cyl(st, 0.045, 0.04, Vector3(0.04, -0.02, 0), Color(0.6, 0.62, 0.66), "metal", Vector3(0, 0, PI / 2.0), 12)
		"rod_icon":
			Mk.st_cyl(st, 0.035, 0.7, Vector3(0, 0.3, 0), Color(1, 0.93, 0.8), "wood_warm", Vector3.ZERO, 8)
			Mk.st_cyl(st, 0.05, 0.22, Vector3(0, -0.12, 0), Color(1, 0.95, 0.88), "rope", Vector3.ZERO, 8, 0.6)
			Mk.st_cyl(st, 0.09, 0.07, Vector3(0.08, 0.0, 0), Color(0.75, 0.77, 0.8), "metal", Vector3(0, 0, PI / 2.0), 12)
			Mk.st_cyl(st, 0.045, 0.06, Vector3(0, 0.68, 0), Color("#e8452c"), "plastic", Vector3.ZERO, 10)
		"bobber":
			Mk.st_cyl(st, 0.05, 0.05, Vector3(0, 0.025, 0), Color("#f4f1ea"), "plastic", Vector3.ZERO, 10)
			Mk.st_cyl(st, 0.05, 0.05, Vector3(0, -0.025, 0), Color("#e8452c"), "plastic", Vector3.ZERO, 10)
			Mk.st_cyl(st, 0.008, 0.08, Vector3(0, 0.08, 0), Color("#e8452c"), "plastic", Vector3.ZERO, 6)
		"fish", "big_fish", "fish_cooked", "big_fish_cooked":
			var big := id.begins_with("big")
			var cooked := id.ends_with("cooked")
			_fish(st, 0.36 if big else 0.24, Color("#a9784a") if cooked else (Color("#7fa0b8") if big else Color("#b9c8d2")))
		"cup_water":
			Mk.st_cyl(st, 0.07, 0.12, Vector3(0, 0.06, 0), Color(1, 0.95, 0.9), "clay", Vector3.ZERO, 12, 0.5)
			Mk.st_cyl(st, 0.062, 0.005, Vector3(0, 0.11, 0), Color("#5fb4e8"), "white", Vector3.ZERO, 12)
		"tile":
			return Raft.tile_preview_mesh()
		"purifier", "grill":
			_station(st, id)
		_:
			Mk.st_box(st, Vector3(0.25, 0.25, 0.25), Vector3.ZERO, Color("#ff00ff"))
	var m := Mk.st_commit(st, leaf)
	_cache[id] = m
	return m


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


## A low-poly fish along +X: tapered body boxes, tail and fins.
static func _fish(st: SurfaceTool, length: float, c: Color) -> void:
	var l := length
	Mk.st_box(st, Vector3(l * 0.5, l * 0.32, l * 0.16), Vector3(0, 0, 0), c, "scales", Vector3.ZERO, 0.3)
	Mk.st_box(st, Vector3(l * 0.28, l * 0.24, l * 0.13), Vector3(l * 0.34, -l * 0.01, 0), c.lightened(0.05), "scales", Vector3.ZERO, 0.3)
	Mk.st_box(st, Vector3(l * 0.22, l * 0.2, l * 0.11), Vector3(-l * 0.33, 0, 0), c.darkened(0.05), "scales", Vector3.ZERO, 0.3)
	Mk.st_box(st, Vector3(l * 0.06, l * 0.36, l * 0.03), Vector3(-l * 0.48, 0, 0), c.darkened(0.15), "scales", Vector3(0, 0, 0.0), 0.3)
	Mk.st_box(st, Vector3(l * 0.22, l * 0.08, l * 0.02), Vector3(0, l * 0.19, 0), c.darkened(0.12), "scales", Vector3(0, 0, -0.2), 0.3)
	for s: float in [-1.0, 1.0]:
		Mk.st_box(st, Vector3(l * 0.03, l * 0.03, l * 0.01), Vector3(l * 0.4, l * 0.04, s * l * 0.065), Color(0.08, 0.08, 0.1), "white")


## Station bodies (fire, steam and food are separate nodes in Station).
static func _station(st: SurfaceTool, kind: String) -> void:
	var brick := Color(1, 0.92, 0.85)
	if kind == "purifier":
		Mk.st_box(st, Vector3(0.62, 0.36, 0.62), Vector3(0, 0.18, 0), brick, "bricks", Vector3.ZERO, 1.0)
		Mk.st_box(st, Vector3(0.3, 0.16, 0.05), Vector3(0, 0.1, 0.3), Color(0.15, 0.13, 0.12), "ash")
		Mk.st_cyl(st, 0.24, 0.3, Vector3(0, 0.51, 0), Color(1, 0.95, 0.9), "clay", Vector3.ZERO, 14, 0.8, 0.12)
		Mk.st_cyl(st, 0.2, 0.03, Vector3(0, 0.67, 0), Color(0.75, 0.77, 0.8), "metal", Vector3.ZERO, 14)
		Mk.st_cyl(st, 0.025, 0.05, Vector3(0, 0.7, 0), Color(0.75, 0.77, 0.8), "metal", Vector3.ZERO, 8)
		Mk.st_cyl(st, 0.02, 0.3, Vector3(0.28, 0.6, 0), Color(0.75, 0.77, 0.8), "metal", Vector3(0, 0, 1.2), 8)
	else:
		Mk.st_box(st, Vector3(0.8, 0.4, 0.55), Vector3(0, 0.2, 0), brick, "bricks", Vector3.ZERO, 1.0)
		Mk.st_box(st, Vector3(0.66, 0.06, 0.42), Vector3(0, 0.38, 0), Color(0.18, 0.15, 0.14), "ash")
		for i in 7:
			Mk.st_box(st, Vector3(0.012, 0.012, 0.46), Vector3(-0.3 + i * 0.1, 0.44, 0), Color(0.45, 0.46, 0.5), "metal")
		for z: float in [-0.2, 0.2]:
			Mk.st_box(st, Vector3(0.7, 0.012, 0.012), Vector3(0, 0.44, z), Color(0.45, 0.46, 0.5), "metal")
		Mk.st_box(st, Vector3(0.3, 0.14, 0.05), Vector3(0, 0.12, 0.28), Color(0.15, 0.13, 0.12), "ash")
