class_name Raft
extends Node3D
## Grid of floor tiles riding the waves. The player and anything built on the raft are its
## children, so they bob with it. Tiles are cells (Vector2i) of size tile_size in raft-local space.

signal changed

const WOOD := [Color("#c89a5b"), Color("#b7864c"), Color("#d4a86a"), Color("#a97a45")]

var tiles: Dictionary = {}          # Vector2i -> StaticBody3D
var tile_size := 1.5
var cfg: Dictionary
var _meshes: Array[ArrayMesh] = []
var _y := 0.0
var _pitch := 0.0
var _roll := 0.0
var _c := Vector3.ZERO              # centroid, raft-local
var _ext := 1.5


func _ready() -> void:
	cfg = Data.b["raft"]
	tile_size = float(cfg["tile"])
	for i in 3:
		_meshes.append(_tile_mesh(i))


func cell_center(c: Vector2i) -> Vector3:
	return Vector3(c.x * tile_size, 0.0, c.y * tile_size)


func cell_at(local: Vector3) -> Vector2i:
	return Vector2i(roundi(local.x / tile_size), roundi(local.z / tile_size))


func has_tile(c: Vector2i) -> bool:
	return tiles.has(c)


func on_raft(local: Vector3) -> bool:
	return tiles.has(cell_at(local))


func can_place(c: Vector2i) -> bool:
	if tiles.has(c):
		return false
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if tiles.has(c + d):
			return true
	return false


func add_tile(c: Vector2i) -> void:
	if tiles.has(c):
		return
	var body := StaticBody3D.new()
	body.position = cell_center(c)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(tile_size, 0.3, tile_size)
	cs.shape = shape
	cs.position.y = -0.15
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _meshes[absi(c.x * 7 + c.y * 13) % _meshes.size()]
	mi.rotation.y = PI if (c.x + c.y) % 2 == 0 else 0.0
	body.add_child(mi)
	add_child(body)
	tiles[c] = body
	_recalc()
	changed.emit()


func remove_tile(c: Vector2i) -> void:
	if not tiles.has(c) or tiles.size() <= 1:
		return
	tiles[c].queue_free()
	tiles.erase(c)
	_recalc()
	changed.emit()


func clear() -> void:
	for c: Vector2i in tiles:
		tiles[c].free()
	tiles.clear()
	_recalc()


func cells() -> Array:
	return tiles.keys()


func centroid() -> Vector3:
	return _c


func _recalc() -> void:
	var s := Vector3.ZERO
	for c: Vector2i in tiles:
		s += cell_center(c)
	_c = s / maxf(1.0, tiles.size())
	_ext = tile_size
	for c: Vector2i in tiles:
		var d := cell_center(c) - _c
		_ext = maxf(_ext, maxf(absf(d.x), absf(d.z)))


func _physics_process(delta: float) -> void:
	var cx := _c.x
	var cz := _c.z
	var e := _ext
	var h0 := Ocean.height_at(cx, cz)
	var hx1 := Ocean.height_at(cx + e, cz)
	var hx0 := Ocean.height_at(cx - e, cz)
	var hz1 := Ocean.height_at(cx, cz + e)
	var hz0 := Ocean.height_at(cx, cz - e)
	# Bigger rafts average over a wider area: they ride calmer.
	var calm := 1.0 / (1.0 + 0.15 * float(tiles.size()))
	var ty := (h0 * 2.0 + hx1 + hx0 + hz1 + hz0) / 6.0 + float(cfg["float"])
	var tilt := float(cfg["tilt"]) * (0.5 + calm)
	var tp := -atan((hz1 - hz0) / (2.0 * e)) * tilt
	var tr := atan((hx1 - hx0) / (2.0 * e)) * tilt
	var k := 1.0 - exp(-float(cfg["follow"]) * delta)
	_y = lerpf(_y, ty, k)
	_pitch = lerpf(_pitch, tp, k)
	_roll = lerpf(_roll, tr, k)
	var b := Basis.from_euler(Vector3(_pitch, 0.0, _roll))
	transform = Transform3D(b, Vector3(cx, _y, cz) - b * _c)


func _process(_delta: float) -> void:
	# Each tile creaks on its own wave a little (visual only).
	var amp := float(cfg["tile_bob"])
	var base := _y - float(cfg["float"])
	for c: Vector2i in tiles:
		var p := cell_center(c)
		var mi: Node3D = tiles[c].get_node("Mesh")
		mi.position.y = clampf((Ocean.height_at(p.x, p.z) - base) * amp, -0.06, 0.06)


## A foundation tile: five planks on two beams with a float underneath.
func _tile_mesh(seed_i: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 + seed_i * 31
	var st := Mk.st_begin()
	var n := 5
	var w := (tile_size - 0.04) / float(n)
	for i in n:
		var c: Color = WOOD[rng.randi() % WOOD.size()].lightened(rng.randf_range(-0.05, 0.08))
		var z := -tile_size / 2.0 + w * (i + 0.5)
		var pl := tile_size - 0.02 - rng.randf_range(0.0, 0.08)
		Mk.st_box(st, Vector3(pl, 0.09, w - 0.035), Vector3(rng.randf_range(-0.03, 0.03), -0.045 + rng.randf_range(-0.012, 0.012), z), c, rng.randf_range(-0.02, 0.02))
	for x: float in [-tile_size * 0.32, tile_size * 0.32]:
		Mk.st_box(st, Vector3(0.16, 0.12, tile_size - 0.06), Vector3(x, -0.15, 0.0), Color("#7a5532"))
	Mk.st_box(st, Vector3(tile_size * 0.7, 0.22, 0.42), Vector3(0.0, -0.3, 0.0), Color("#3e8fc9") if seed_i != 1 else Color("#d8d2c0"))
	return Mk.st_commit(st)
