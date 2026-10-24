extends Node3D
## Back-counter ingredient station: lavash stack, two sauce bottles, a row of bins and the
## crates of prepped food. Every bin has a limited stock (bar in front, "ПУСТО" when empty)
## refilled with a crate. Faces -Z (the room). Tappable kinds: "lavash", "bin:<id>", "storage".

const VEG := ["tomato", "cucumber", "cabbage", "onion", "fries", "cheese", "jalapeno"]
const K := "res://assets/models/food/"

var nodes := {}       # id -> Node3D (for bounce and hint targets)
var locks := {}       # id -> Node3D overlay
var unlocked: Array = []
var stock := {}       # id -> portions left
var cap := {}         # id -> full bin
var piles := {}       # id -> Node3D (contents, hidden when empty)
var bars := {}        # id -> MeshInstance3D stock bar
var empties := {}     # id -> Label3D "ПУСТО"
var lavash_discs: Array = []


func _ready() -> void:
	# Lavash stack.
	var lav := Node3D.new()
	lav.position = Vector3(-1.5, 0, 0)
	add_child(lav)
	for k in 5:
		lavash_discs.append(M3.cyl(lav, 0.15, 0.15, 0.008, Vector3(0, 0.006 + k * 0.009, 0), M3.mat(DU.LAVASH.darkened(0.03 * (k % 2)), 0.95), 24))
	_name(lav, "Лаваш", 0.16)
	_stock_ui("lavash", lav, 0.16)
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
		piles[id] = bottle
		_stock_ui(id, b, 0.09)
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
		var pile := Node3D.new()
		n.add_child(pile)
		piles[id] = pile
		M3.box(pile, Vector3(0.21, 0.02, 0.27), Vector3(0, 0.065, 0), M3.mat(Bal.color(id).darkened(0.15), 0.9))
		_pile(pile, id)
		_name(n, Bal.ing_name(id), 0.17)
		_stock_ui(id, n, 0.17)
		M3.solid(n, Vector3(0.25, 0.16, 0.31), Vector3(0, 0.07, 0), M3.LAYER_USE, "bin:" + id)
		nodes[id] = n
		var lock := Node3D.new()
		n.add_child(lock)
		M3.box(lock, Vector3(0.25, 0.02, 0.31), Vector3(0, 0.15, 0), M3.mat(Color("#3a3048"), 0.6))
		var ll := M3.label(lock, "закрыто", Vector3(0, 0.165, 0), 34, Color("#c9bde6"), 8, 0.0022)
		ll.rotation = Vector3(-PI / 2.0, PI, 0)
		locks[id] = lock
	# Crates of prepped food at the right end of the counter.
	var st := Node3D.new()
	st.position = Vector3(2.4, 0, 0)
	add_child(st)
	for k in 3:
		var crate := M3.box(st, Vector3(0.34, 0.16, 0.28), Vector3(0, 0.08 + k * 0.17, 0), M3.mat(Color("#c98b55"), 0.8))
		crate.rotation.y = (k - 1) * 0.12
		M3.box(st, Vector3(0.3, 0.03, 0.24), Vector3(0, 0.165 + k * 0.17, 0), M3.mat([Color("#e8443a"), Color("#6cc24a"), Color("#ffd84d")][k], 0.8))
	var sl := M3.label(st, "ЗАГОТОВКИ", Vector3(0, 0.6, -0.15), 30, DU.GOLD, 8, 0.0022)
	sl.rotation.y = PI
	M3.solid(st, Vector3(0.4, 0.6, 0.34), Vector3(0, 0.3, 0), M3.LAYER_USE, "storage")
	nodes["storage"] = st


## Stock bar and "ПУСТО" sign in front of a bin.
func _stock_ui(id: String, n: Node3D, front: float) -> void:
	M3.box(n, Vector3(0.2, 0.012, 0.012), Vector3(0, 0.012, -front + 0.02), M3.flat(Color(0.1, 0.07, 0.12)))
	var bar := M3.box(n, Vector3(0.2, 0.016, 0.016), Vector3(0, 0.014, -front + 0.018), M3.flat(DU.GREEN))
	bars[id] = bar
	var e := M3.label(n, "ПУСТО", Vector3(0, 0.2, -0.02), 40, DU.RED, 10, 0.0022)
	e.rotation.y = PI
	e.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	e.visible = false
	empties[id] = e


## Fills every bin; mult scales the capacity (the "big bins" upgrade).
func setup_stock(mult: float) -> void:
	for id in nodes:
		if id == "storage":
			continue
		var base := Bal.f("stock_lavash") if id == "lavash" else (Bal.f("stock_sauce") if id in ["garlic", "hot"] else Bal.f("stock_veg"))
		cap[id] = roundi(base * mult)
		stock[id] = cap[id]
		_refresh(id)


func has(id: String) -> bool:
	return int(stock.get(id, 0)) > 0


func take(id: String) -> void:
	stock[id] = maxi(0, int(stock.get(id, 0)) - 1)
	_refresh(id)


func refill(id: String) -> void:
	stock[id] = cap.get(id, 10)
	_refresh(id)


func frac(id: String) -> float:
	return float(stock.get(id, 0)) / maxf(1.0, float(cap.get(id, 1)))


## Unlocked bins sorted from the emptiest.
func lowest() -> Array:
	var ids: Array = []
	for id in stock:
		if unlocked.has(id):
			ids.append(id)
	ids.sort_custom(func(a, b): return frac(a) < frac(b))
	return ids


func _refresh(id: String) -> void:
	var f := frac(id)
	if bars.has(id):
		bars[id].scale.x = maxf(0.02, f)
		bars[id].material_override = M3.flat(DU.GREEN if f > 0.5 else (DU.GOLD if f > 0.2 else DU.RED))
	if empties.has(id):
		empties[id].visible = f <= 0.0 and unlocked.has(id)
	if id == "lavash":
		for k in lavash_discs.size():
			lavash_discs[k].visible = f > k / float(lavash_discs.size())
	elif piles.has(id):
		piles[id].visible = f > 0.0


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
			var rng := RandomNumberGenerator.new()
			rng.seed = 3
			for k in 26:
				var p := Vector3(rng.randf_range(-0.08, 0.08), 0.078 + rng.randf_range(0, 0.02), rng.randf_range(-0.11, 0.11))
				M3.box(n, Vector3(0.07, 0.008, 0.012), p, M3.mat(Color("#dff2c0") if k % 3 else Color("#b9dc8f")), Vector3(0, rng.randf() * PI, 0))
		"cheese":
			for k in 3:
				M3.model(n, K + "cheese-cut.glb", Vector3(-0.07, 0.078 + k * 0.006, -0.08 + k * 0.03), 0.38, 0.2 * k)
		"fries":
			M3.model(n, K + "fries.glb", Vector3(-0.02, 0.07, 0.01), 0.45)
		"jalapeno":
			for k in spots.size():
				var p: Vector3 = spots[k]
				var pep := Node3D.new()
				pep.position = p + Vector3(0, 0.012, 0)
				pep.rotation = Vector3(0, k * 1.3, 0)
				n.add_child(pep)
				var body := MeshInstance3D.new()
				var cm := CapsuleMesh.new()
				cm.radius = 0.014
				cm.height = 0.08
				body.mesh = cm
				body.rotation.z = PI / 2.0
				body.material_override = M3.mat(Color("#2f9e44"), 0.4)
				pep.add_child(body)
				M3.box(pep, Vector3(0.016, 0.006, 0.006), Vector3(-0.045, 0.004, 0), M3.mat(Color("#6b8e23")))
		_:
			for p in spots:
				var mi := M3.cyl(n, 0.03, 0.03, 0.01, p, M3.mat(Bal.color(id)), 12)
				M3.cyl(mi, 0.022, 0.022, 0.011, Vector3.ZERO, M3.mat(Bal.color(id).lightened(0.4)), 12)
