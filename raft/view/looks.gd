class_name Looks
## Visuals for items: floating debris, the hook head and what the hand holds.
## Kenney CC0 models where they fit, merged procedural boxes otherwise.

const MODELS := {
	"barrel": ["res://assets/models/survival/barrel.glb", 0.9],
	"hammer": ["res://assets/models/survival/tool-hammer.glb", 0.55],
	"coconut": ["res://assets/models/food/coconut.glb", 0.9],
	"banana": ["res://assets/models/food/banana.glb", 0.9],
	"pineapple": ["res://assets/models/food/pineapple.glb", 0.6],
	"water": ["res://assets/models/survival/bottle.glb", 0.8],
}
const LEAF := Color("#4f9e38")
const LEAF2 := Color("#3c842b")

static var _cache: Dictionary = {}


static func debris(id: String) -> Node3D:
	var root := Node3D.new()
	match id:
		"barrel":
			var m := Mk.model(root, MODELS["barrel"][0], Vector3(0, 0.05, 0), MODELS["barrel"][1])
			m.rotation = Vector3(0, 0, PI / 2.0)
		_:
			var mi := MeshInstance3D.new()
			mi.mesh = _mesh(id)
			root.add_child(mi)
	return root


static func held(id: String) -> Node3D:
	var root := Node3D.new()
	if id == "hook":
		var h := hook_head()
		h.scale = Vector3.ONE * 0.55
		h.rotation = Vector3(0.5, 0.4, -0.2)
		h.position = Vector3(0.04, -0.04, -0.05)
		root.add_child(h)
	elif MODELS.has(id):
		var m := Mk.model(root, MODELS[id][0], Vector3(0, -0.06, 0), MODELS[id][1] * 0.5)
		m.rotation.y = 0.6
		if id == "hammer":
			m.rotation = Vector3(-0.2, PI / 2.0, 0.25)
			m.position = Vector3(0, -0.12, 0)
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = _mesh(id)
		mi.scale = Vector3.ONE * 0.4
		root.add_child(mi)
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


## The throwable hook: a three-prong plastic grapple.
static func hook_head() -> Node3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh("hook_head")
	return mi


static func _mesh(id: String) -> ArrayMesh:
	if _cache.has(id):
		return _cache[id]
	var st := Mk.st_begin()
	match id:
		"plank":
			Mk.st_box(st, Vector3(1.05, 0.07, 0.24), Vector3.ZERO, Color("#c08f55"))
			Mk.st_box(st, Vector3(0.12, 0.072, 0.245), Vector3(0.3, 0.001, 0), Color("#9c7140"))
		"plastic":
			Mk.st_box(st, Vector3(0.3, 0.28, 0.22), Vector3(0, 0.02, 0), Color("#8fc9ea"))
			Mk.st_box(st, Vector3(0.1, 0.08, 0.1), Vector3(0.1, 0.2, 0), Color("#2a6fb0"))
			Mk.st_box(st, Vector3(0.05, 0.16, 0.05), Vector3(-0.12, 0.12, 0), Color("#8fc9ea"))
		"leaf":
			Mk.st_box(st, Vector3(1.0, 0.03, 0.04), Vector3(0, 0.02, 0), Color("#7a8a3a"))
			for i in 5:
				var x := -0.35 + i * 0.17
				var l := 0.42 - absf(x) * 0.35
				for s: float in [-1.0, 1.0]:
					Mk.st_box(st, Vector3(0.09, 0.015, l), Vector3(x + 0.08, 0.02, s * l * 0.45), LEAF if i % 2 == 0 else LEAF2, s * 0.55)
		"rope":
			for i in 3:
				Mk.st_box(st, Vector3(0.28, 0.06, 0.06), Vector3(0, i * 0.055, 0), Color("#cfae7a"), i * 1.0)
		"hook_head":
			Mk.st_box(st, Vector3(0.05, 0.3, 0.05), Vector3(0, 0.1, 0), Color("#d9d9d9"))
			for a in 3:
				var yaw := a * TAU / 3.0
				var out := Vector3(sin(yaw), 0, cos(yaw)) * 0.07
				Mk.st_box(st, Vector3(0.035, 0.035, 0.16), out + Vector3(0, -0.04, 0), Color("#bfc4c8"), yaw, 0.0)
				Mk.st_box(st, Vector3(0.035, 0.1, 0.035), out * 2.0 + Vector3(0, 0.0, 0), Color("#bfc4c8"), yaw)
			Mk.st_box(st, Vector3(0.09, 0.07, 0.09), Vector3(0, 0.28, 0), Color("#ff6a3d"))
		_:
			Mk.st_box(st, Vector3(0.25, 0.25, 0.25), Vector3.ZERO, Color("#ff00ff"))
	var m := Mk.st_commit(st)
	_cache[id] = m
	return m
