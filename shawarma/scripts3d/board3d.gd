extends Node3D
## Cutting board on the back counter: lay lavash, add fillings, swipe up to roll.
## Same API as the 2D board. Tappable kind: "board".

enum S { EMPTY, OPEN, ROLLED }

var state := S.EMPTY
var meat := 0
var items: Array[String] = []
var bal: Dictionary
var lavash: MeshInstance3D
var fillings: Node3D
var roll_mesh: MeshInstance3D


func _ready() -> void:
	var board := M3.model(self, "res://assets/models/food/cutting-board.glb", Vector3.ZERO, 0.62, PI / 2.0)
	board.position = Vector3(0, 0, 0)
	lavash = M3.cyl(self, 0.16, 0.16, 0.006, Vector3(0, 0.042, 0), _lavash_mat(), 28)
	lavash.visible = false
	fillings = Node3D.new()
	fillings.position = Vector3(0, 0.046, 0)
	add_child(fillings)
	roll_mesh = M3.make_roll()
	roll_mesh.position = Vector3(0, 0.085, 0)
	roll_mesh.visible = false
	add_child(roll_mesh)
	M3.solid(self, Vector3(0.52, 0.14, 0.4), Vector3(0, 0.06, 0), M3.LAYER_USE, "board")


func _lavash_mat() -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.08
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 64
	tex.height = 64
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	ramp.colors = PackedColorArray([DU.LAVASH, DU.LAVASH, DU.LAVASH_SPOT])
	tex.color_ramp = ramp
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.95
	return m


func center_global() -> Vector3:
	return to_global(Vector3(0, 0.06, 0))


func put_lavash() -> bool:
	if state != S.EMPTY:
		return false
	state = S.OPEN
	meat = 0
	items.clear()
	lavash.visible = true
	lavash.scale = Vector3(0.3, 1, 0.3)
	create_tween().tween_property(lavash, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_rebuild()
	return true


func add_item(id: String) -> bool:
	if state != S.OPEN or items.has(id):
		return false
	items.append(id)
	_rebuild(id)
	return true


func add_meat() -> bool:
	if state != S.OPEN or meat >= 2:
		return false
	meat += 1
	_rebuild("meat")
	return true


func roll() -> bool:
	if state != S.OPEN or (meat == 0 and items.is_empty()):
		return false
	state = S.ROLLED
	var tw := create_tween()
	tw.tween_property(lavash, "scale", Vector3(1, 1, 0.15), 0.18)
	tw.parallel().tween_property(fillings, "scale", Vector3(1, 1, 0.1), 0.18)
	tw.tween_callback(func():
		lavash.visible = false
		fillings.scale = Vector3.ONE
		for c in fillings.get_children():
			c.queue_free()
		roll_mesh.visible = true
		M3.set_toast(roll_mesh, 0.0, bal)
		roll_mesh.scale = Vector3.ONE * 0.4
		create_tween().tween_property(roll_mesh, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	return true


func take_roll() -> Dictionary:
	var made := {"meat": meat, "items": items.duplicate(), "toast": 0.0}
	clear()
	return made


func clear() -> void:
	state = S.EMPTY
	meat = 0
	items.clear()
	lavash.visible = false
	lavash.scale = Vector3.ONE
	roll_mesh.visible = false
	for c in fillings.get_children():
		c.queue_free()


## Rebuilds the filling pieces; `fresh` pops in.
func _rebuild(fresh := "") -> void:
	for c in fillings.get_children():
		c.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for m in meat:
		for k in 8:
			var a := k * 0.8 + m * 0.4
			var p := Vector3(cos(a), 0, sin(a)) * (0.012 + (k % 3) * 0.022)
			var mi := M3.box(fillings, Vector3(0.055, 0.012, 0.02), p + Vector3(0, 0.006 + m * 0.008, 0),
				M3.mat(DU.MEAT if k % 2 == 0 else DU.MEAT_DARK.lightened(0.1)), Vector3(0, a + 0.5, 0))
			_pop(mi, fresh == "meat" and m == meat - 1)
	var vi := 0
	for id in items:
		var kind: String = Bal.ing_by_id[id]["kind"]
		if kind == "sauce":
			for k in 11:
				var p := Vector3(-0.09 + k * 0.018, 0.02, sin(k * 1.4) * 0.04)
				var d := M3.sphere(fillings, 0.009, p, M3.mat(Bal.color(id), 0.3))
				d.scale = Vector3(1.3, 0.5, 1.3)
				_pop(d, fresh == id)
			continue
		for k in 6:
			var a := vi * 0.9 + k * TAU / 6.0
			var r := 0.075 + (k % 2) * 0.03 - vi * 0.008
			var p := Vector3(cos(a), 0.008, sin(a)) * r
			p.y = 0.008
			_pop(_piece(id, p, a + k), fresh == id)
		vi += 1


func _piece(id: String, p: Vector3, rot: float) -> MeshInstance3D:
	var col := Bal.color(id)
	match id:
		"tomato", "cucumber", "jalapeno":
			var mi := M3.cyl(fillings, 0.024, 0.024, 0.008, p, M3.mat(col), 12)
			M3.cyl(mi, 0.017, 0.017, 0.009, Vector3.ZERO, M3.mat(col.lightened(0.35)), 12)
			return mi
		"onion":
			var mi := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.012
			tm.outer_radius = 0.02
			tm.rings = 12
			tm.ring_segments = 6
			mi.mesh = tm
			mi.material_override = M3.mat(col)
			mi.position = p
			fillings.add_child(mi)
			return mi
		"fries":
			return M3.box(fillings, Vector3(0.065, 0.012, 0.012), p, M3.mat(col), Vector3(0, rot, 0))
		"cheese":
			return M3.box(fillings, Vector3(0.03, 0.007, 0.03), p, M3.mat(col), Vector3(0, rot, 0))
		_:
			return M3.box(fillings, Vector3(0.045, 0.007, 0.014), p, M3.mat(col), Vector3(0, rot, 0))


func _pop(n: Node3D, on: bool) -> void:
	if not on:
		return
	var target := n.scale
	n.scale = Vector3.ONE * 0.01
	var tw := n.create_tween()
	tw.tween_interval(0.12)
	tw.tween_property(n, "scale", target, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
