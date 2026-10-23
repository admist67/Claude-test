extends Node3D
## Back-counter ingredient station: lavash stack, two sauce bottles and a row of bins.
## Faces -Z (the room). Tappable kinds: "lavash", "bin:<id>".

const VEG := ["tomato", "cucumber", "cabbage", "onion", "fries", "cheese", "jalapeno"]
const K := "res://assets/models/food/"

var nodes := {}       # id -> Node3D (for bounce and hint targets)
var locks := {}       # id -> Node3D overlay
var unlocked: Array = []


func _ready() -> void:
	# Lavash stack.
	var lav := Node3D.new()
	lav.position = Vector3(-1.5, 0, 0)
	add_child(lav)
	for k in 5:
		M3.cyl(lav, 0.15, 0.15, 0.008, Vector3(0, 0.006 + k * 0.009, 0), M3.mat(DU.LAVASH.darkened(0.03 * (k % 2)), 0.95), 24)
	_name(lav, "Лаваш", 0.16)
	M3.solid(lav, Vector3(0.34, 0.12, 0.34), Vector3(0, 0.05, 0), M3.LAYER_USE, "lavash")
	nodes["lavash"] = lav
	# Sauce bottles.
	for spec in [["garlic", -0.42], ["hot", -0.17]]:
		var id: String = spec[0]
		var b := Node3D.new()
		b.position = Vector3(spec[1], 0, -0.02)
		add_child(b)
		var bottle := M3.model(b, K + "bottle-ketchup.glb", Vector3.ZERO, 0.62)
		M3.paint(bottle, M3.mat(Bal.color(id), 0.35))
		M3.cyl(b, 0.025, 0.025, 0.04, Vector3(0, 0.26, 0), M3.mat(DU.INK if id == "hot" else Color("#3ccf7a")), 10)
		_name(b, Bal.ing_name(id), 0.09)
		M3.solid(b, Vector3(0.16, 0.3, 0.16), Vector3(0, 0.14, 0), M3.LAYER_USE, "bin:" + id)
		nodes[id] = b
	# Veggie bins.
	for i in VEG.size():
		var id: String = VEG[i]
		var n := Node3D.new()
		n.position = Vector3(0.05 + i * 0.26, 0, 0)
		add_child(n)
		M3.box(n, Vector3(0.24, 0.07, 0.3), Vector3(0, 0.035, 0), M3.mat(Color("#d8d3e6"), 0.3, 0.7))
		M3.box(n, Vector3(0.21, 0.02, 0.27), Vector3(0, 0.065, 0), M3.mat(Bal.color(id).darkened(0.15), 0.9))
		_pile(n, id)
		_name(n, Bal.ing_name(id), 0.17)
		M3.solid(n, Vector3(0.25, 0.16, 0.31), Vector3(0, 0.07, 0), M3.LAYER_USE, "bin:" + id)
		nodes[id] = n
		var lock := Node3D.new()
		n.add_child(lock)
		M3.box(lock, Vector3(0.25, 0.02, 0.31), Vector3(0, 0.15, 0), M3.mat(Color("#3a3048"), 0.6))
		var ll := M3.label(lock, "закрыто", Vector3(0, 0.165, 0), 34, Color("#c9bde6"), 8, 0.0022)
		ll.rotation = Vector3(-PI / 2.0, PI, 0)
		locks[id] = lock


func set_unlocked(ids: Array) -> void:
	unlocked = ids
	for id in locks:
		locks[id].visible = not ids.has(id)


func target(id: String) -> Vector3:
	return nodes[id].to_global(Vector3(0, 0.12, 0))


func poke(id: String) -> void:
	var n: Node3D = nodes[id]
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector3(1.12, 1.25, 1.12), 0.07)
	tw.tween_property(n, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _name(n: Node3D, text: String, front: float) -> void:
	var l := M3.label(n, text, Vector3(0, 0.035, -front), 26, DU.CREAM, 8, 0.0017)
	l.rotation.y = PI
	l.position.z = -front


func _pile(n: Node3D, id: String) -> void:
	var spots := [Vector3(-0.05, 0.075, -0.06), Vector3(0.05, 0.075, -0.05), Vector3(0.0, 0.08, 0.05), Vector3(-0.06, 0.075, 0.07), Vector3(0.06, 0.075, 0.07)]
	match id:
		"tomato":
			for p in spots:
				M3.model(n, K + "tomato-slice.glb", p, 0.42, p.x * 20.0)
		"onion":
			for p in spots.slice(0, 3):
				M3.model(n, K + "onion-half.glb", p, 0.32, p.x * 30.0).rotation.z = PI / 2.0
		"cabbage":
			M3.model(n, K + "cabbage.glb", Vector3(0, 0.07, 0), 0.38)
		"cheese":
			for k in 3:
				M3.model(n, K + "cheese-cut.glb", Vector3(-0.07, 0.078 + k * 0.006, -0.08 + k * 0.03), 0.38, 0.2 * k)
		"fries":
			M3.model(n, K + "fries.glb", Vector3(-0.02, 0.07, 0.01), 0.45)
		_:
			for p in spots:
				var mi := M3.cyl(n, 0.03, 0.03, 0.01, p, M3.mat(Bal.color(id)), 12)
				M3.cyl(mi, 0.022, 0.022, 0.011, Vector3.ZERO, M3.mat(Bal.color(id).lightened(0.4)), 12)
