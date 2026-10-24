extends Node3D
## The café terrace in front of the kiosk (bought in the shop): deck, planter fence with an
## entrance, string lights, tables with chairs and the drinks cooler by the passage.
## Tables go free → busy → dirty → (cleaned) free. Tappable kinds: "table:<i>", "drinks".

const TABLES := [Vector3(-3.6, 0, -2.5), Vector3(3.6, 0, -2.5), Vector3(-2.0, 0, -4.3),
	Vector3(2.6, 0, -4.3), Vector3(-4.3, 0, -4.3), Vector3(4.4, 0, -4.3)]
const GAP_X := 0.6
const FENCE_Z := -5.6
const LANE_Z := -5.95
const INNER_Z := -5.1
const DOOR_IN := Vector3(1.9, 0, -0.1)
const DOOR := Vector3(2.2, 0, -0.75)
const DOOR_OUT := Vector3(2.2, 0, -1.6)
const COOLER := Vector3(2.72, 1.0, -0.2)
const K := "res://assets/models/"

var enabled := false
var tables: Array = []      # {"pos", "state", "dirt"}
var root: Node3D


func build(on: bool, count: int) -> void:
	if root:
		root.queue_free()
		root = null
	tables.clear()
	enabled = on
	root = Node3D.new()
	add_child(root)
	if not on:
		_teaser()
		return
	_deck()
	_fence()
	_lights()
	_cooler()
	for i in mini(count, TABLES.size()):
		_table(i)


## Before the café is bought: a fenced-off building site on the sidewalk with a sign.
func _teaser() -> void:
	var cone := K + "roads/construction-cone.glb"
	for k in 6:
		M3.model(root, cone, Vector3(-2.4 + k * 0.96, 0, -3.9), 5.0)
	for k in 5:
		var a := Vector3(-2.4 + k * 0.96, 0.32, -3.9)
		M3.box(root, Vector3(0.96, 0.05, 0.02), a + Vector3(0.48, 0, 0), M3.mat(Color("#ffc93c") if k % 2 == 0 else Color("#2b1d33")))
	var board := Node3D.new()
	board.position = Vector3(0.0, 0, -4.6)
	root.add_child(board)
	M3.box(board, Vector3(2.9, 1.45, 0.06), Vector3(0, 1.8, 0), M3.glow(Color("#fff1d6"), 0.35))
	M3.box(board, Vector3(3.0, 1.55, 0.04), Vector3(0, 1.8, -0.02), M3.mat(Color("#a85f2e"), 0.7))
	for x in [-1.3, 1.3]:
		M3.box(board, Vector3(0.07, 1.1, 0.07), Vector3(x, 0.55, 0), M3.mat(Color("#a85f2e"), 0.7))
	var l := M3.label(board, "СКОРО ЗДЕСЬ:\nКАФЕ-ВЕРАНДА\nКупи в магазине —\nвкладка «Кафе и персонал»", Vector3(0, 1.8, 0.04), 48, DU.INK, 0, 0.0032)
	l.modulate = Color(1.7, 0.3, 0.22)
	l.double_sided = false


func _deck() -> void:
	var img := Image.create(1, 8, false, Image.FORMAT_RGB8)
	for y in 8:
		img.set_pixel(0, y, Color("#a0663e") if y % 2 == 0 else Color("#8a5533"))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_scale = Vector3(1, 6, 1)
	m.roughness = 0.8
	M3.box(root, Vector3(11.4, 0.04, 4.55), Vector3(0, -0.018, -3.35), m)


func _fence() -> void:
	var wood := M3.mat(Color("#6b4430"), 0.8)
	var x := -5.4
	while x <= 5.45:
		if absf(x - GAP_X) > 0.75:
			_planter(Vector3(x, 0, FENCE_Z), wood)
		x += 0.9
	for k in 5:
		_planter(Vector3(-5.6, 0, -1.6 - k * 0.9), wood)
		_planter(Vector3(5.6, 0, -1.6 - k * 0.9), wood)
	# Invisible bar in the entrance: customers walk through it, the cook does not.
	M3.solid(root, Vector3(1.5, 2.0, 0.3), Vector3(GAP_X, 1.0, FENCE_Z))
	M3.solid(root, Vector3(0.3, 2.0, 4.6), Vector3(-5.75, 1.0, -3.4))
	M3.solid(root, Vector3(0.3, 2.0, 4.6), Vector3(5.75, 1.0, -3.4))
	M3.solid(root, Vector3(11.6, 2.0, 0.3), Vector3(0, 1.0, FENCE_Z - 0.1))
	for side in [0.0, PI]:
		var sign := M3.label(root, "КАФЕ", Vector3(GAP_X, 2.3, FENCE_Z), 90, Color(2.4, 1.9, 0.6), 0, 0.004)
		sign.rotation.y = side
		sign.double_sided = false
	M3.cyl(root, 0.04, 0.04, 2.3, Vector3(GAP_X - 0.75, 1.15, FENCE_Z), M3.mat(Color("#5b5480"), 0.5, 0.5), 8)
	M3.cyl(root, 0.04, 0.04, 2.3, Vector3(GAP_X + 0.75, 1.15, FENCE_Z), M3.mat(Color("#5b5480"), 0.5, 0.5), 8)
	M3.box(root, Vector3(1.6, 0.06, 0.06), Vector3(GAP_X, 2.3, FENCE_Z), M3.mat(Color("#5b5480"), 0.5, 0.5))


func _planter(p: Vector3, wood: Material) -> void:
	M3.box(root, Vector3(0.72, 0.42, 0.4), p + Vector3(0, 0.21, 0), wood)
	M3.box(root, Vector3(0.66, 0.04, 0.34), p + Vector3(0, 0.43, 0), M3.mat(Color("#3b2a20")))
	for k in 3:
		M3.sphere(root, 0.13, p + Vector3(-0.22 + k * 0.22, 0.55 + (k % 2) * 0.05, 0), M3.mat(Color("#3f9e52") if k % 2 else Color("#2f7d43")))


func _lights() -> void:
	var cols := [Color("#ff4fa3"), Color("#ffc93c"), Color("#4ff0ff"), Color("#7dff6a")]
	for strand in [-3.6, 0.0, 3.6]:
		var a := Vector3(strand * 0.5, 2.75, -1.15)
		var b := Vector3(strand * 1.3 if strand != 0.0 else GAP_X, 2.3, FENCE_Z)
		for i in 16:
			var u := i / 15.0
			var p := a.lerp(b, u) + Vector3(0, -0.25 * sin(u * PI), 0)
			M3.sphere(root, 0.03, p, M3.glow(cols[i % cols.size()], 2.2))
	for x in [-2.8, 2.8]:
		var l := OmniLight3D.new()
		l.position = Vector3(x, 2.3, -3.3)
		l.light_color = Color("#ffd9a0")
		l.light_energy = 1.3
		l.omni_range = 5.0
		root.add_child(l)


func _cooler() -> void:
	var n := Node3D.new()
	n.position = COOLER
	root.add_child(n)
	M3.box(n, Vector3(0.36, 0.55, 0.3), Vector3(0, 0.275, 0), M3.mat(Color("#d8d3e6"), 0.3, 0.6))
	M3.box(n, Vector3(0.02, 0.45, 0.24), Vector3(-0.18, 0.29, 0), M3.glow(Color(0.6, 0.9, 1.0), 0.6))
	for k in 6:
		var can := M3.model(n, K + "food/soda-can.glb", Vector3(-0.1, 0.07 + (k / 3) * 0.2, -0.08 + (k % 3) * 0.08), 0.32)
		can.rotation.y = k
	var l := M3.label(n, "НАПИТКИ", Vector3(-0.2, 0.62, 0), 30, Color(0.6, 2.2, 2.6), 6, 0.002)
	l.rotation.y = -PI / 2.0
	M3.solid(n, Vector3(0.42, 0.62, 0.36), Vector3(0, 0.3, 0), M3.LAYER_USE, "drinks")


func _table(i: int) -> void:
	var p: Vector3 = TABLES[i]
	var n := Node3D.new()
	n.position = p
	root.add_child(n)
	var wood := M3.mat(Color("#c98b55"), 0.6)
	M3.cyl(n, 0.42, 0.42, 0.04, Vector3(0, 0.74, 0), wood, 24)
	M3.cyl(n, 0.035, 0.035, 0.72, Vector3(0, 0.37, 0), M3.mat(Color("#3b3550"), 0.4, 0.6), 8)
	M3.cyl(n, 0.22, 0.22, 0.03, Vector3(0, 0.015, 0), M3.mat(Color("#3b3550"), 0.4, 0.6), 16)
	M3.cyl(n, 0.05, 0.05, 0.12, Vector3(0.18, 0.82, 0.1), M3.mat(Color("#fff1d6")), 8)
	_chair(n, Vector3(0, 0, -0.66))
	M3.solid(n, Vector3(0.9, 0.8, 0.9), Vector3(0, 0.4, 0))
	M3.solid(n, Vector3(1.0, 0.4, 1.0), Vector3(0, 0.85, 0), M3.LAYER_USE, "table:%d" % i)
	var dirt := Node3D.new()
	dirt.visible = false
	n.add_child(dirt)
	M3.cyl(dirt, 0.13, 0.11, 0.015, Vector3(-0.08, 0.77, -0.05), M3.mat(Color.WHITE, 0.3), 16)
	M3.box(dirt, Vector3(0.09, 0.03, 0.06), Vector3(-0.06, 0.79, -0.05), M3.mat(Color("#d9b27a")), Vector3(0, 0.6, 0.3))
	M3.model(dirt, K + "food/soda-can.glb", Vector3(0.12, 0.76, -0.12), 0.3).rotation.z = PI / 2.0
	tables.append({"pos": p, "state": "free", "dirt": dirt})


## A simple wooden chair whose seat matches the guests' sitting pose; back faces away (-Z).
func _chair(n: Node3D, c: Vector3) -> void:
	var wood := M3.mat(Color("#8a5533"), 0.7)
	M3.box(n, Vector3(0.46, 0.05, 0.44), c + Vector3(0, 0.46, 0), wood)
	M3.box(n, Vector3(0.46, 0.5, 0.05), c + Vector3(0, 0.72, -0.22), wood)
	for x in [-0.2, 0.2]:
		for z in [-0.19, 0.19]:
			M3.box(n, Vector3(0.04, 0.46, 0.04), c + Vector3(x, 0.23, z), wood)
	M3.solid(n, Vector3(0.46, 0.9, 0.46), c + Vector3(0, 0.45, 0))


func seat(i: int) -> Vector3:
	return TABLES[i] + Vector3(0, 0, -0.66)


func free_table() -> int:
	var free: Array = []
	for i in tables.size():
		if tables[i]["state"] == "free":
			free.append(i)
	return -1 if free.is_empty() else free[randi() % free.size()]


func set_state(i: int, state: String) -> void:
	tables[i]["state"] = state
	tables[i]["dirt"].visible = state == "dirty"


func dirty_tables() -> Array:
	var list: Array = []
	for i in tables.size():
		if tables[i]["state"] == "dirty":
			list.append(i)
	return list


## Path for a guest from the street lane to a chair (and back reversed).
func path_in(from_side: float, i: int) -> Array:
	var s := seat(i)
	return [Vector3(from_side * 9.0, 0, LANE_Z), Vector3(GAP_X, 0, LANE_Z), Vector3(GAP_X, 0, INNER_Z), Vector3(s.x, 0, INNER_Z), s]


func path_out(from: Vector3, side: float) -> Array:
	return [Vector3(from.x, 0, INNER_Z), Vector3(GAP_X, 0, INNER_Z), Vector3(GAP_X, 0, LANE_Z), Vector3(side * 10.0, 0, LANE_Z)]


## Walking route for staff between the kiosk inside (z > -0.95) and the terrace.
static func route(from: Vector3, to: Vector3) -> Array:
	var a_in := from.z > -0.95
	var b_in := to.z > -0.95
	if a_in and not b_in:
		return [DOOR_IN, DOOR, DOOR_OUT, to]
	if b_in and not a_in:
		return [DOOR_OUT, DOOR, DOOR_IN, to]
	return [to]
