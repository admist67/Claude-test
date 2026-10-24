class_name Raft
extends Node3D
## Grid of floor tiles riding the waves. The player and anything built on the raft are its
## children, so they bob with it. Tiles are cells (Vector2i) of size tile_size in raft-local space.

signal changed

static var _mesh_cache: Dictionary = {}

var tiles: Dictionary = {}          # Vector2i -> StaticBody3D
var stations: Dictionary = {}       # Vector3i(x, z, level) -> Station
var hp: Dictionary = {}             # Vector2i -> bites left; missing = whole tile
var tile_size := 1.5
var parts: RaftParts
var cfg: Dictionary
var _y := 0.0
var _pitch := 0.0
var _roll := 0.0
var _c := Vector3.ZERO              # centroid, raft-local
var _ext := 1.5


func _ready() -> void:
	cfg = Data.b["raft"]
	tile_size = float(cfg["tile"])
	parts = RaftParts.new()
	parts.raft = self
	add_child(parts)


func cell_center(c: Vector2i) -> Vector3:
	return Vector3(c.x * tile_size, 0.0, c.y * tile_size)


func cell_at(local: Vector3) -> Vector2i:
	return Vector2i(roundi(local.x / tile_size), roundi(local.z / tile_size))


func has_tile(c: Vector2i) -> bool:
	return tiles.has(c)


func on_raft(local: Vector3) -> bool:
	return tiles.has(cell_at(local))


func can_place(c: Vector2i) -> bool:
	if c.x < -40 or c.x > 40 or c.y < -40 or c.y > 40:
		return false
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
	mi.mesh = _mesh_for(c)
	mi.rotation.y = PI if (c.x + c.y) % 2 == 0 else 0.0
	body.add_child(mi)
	add_child(body)
	tiles[c] = body
	_recalc()
	changed.emit()


func remove_tile(c: Vector2i) -> void:
	if not tiles.has(c) or tiles.size() <= 1:
		return
	hp.erase(c)
	tiles[c].queue_free()
	tiles.erase(c)
	parts.on_tile_removed(c)
	_recalc()
	changed.emit()


func clear() -> void:
	for c: Vector2i in tiles:
		tiles[c].free()
	tiles.clear()
	for c: Vector3i in stations:
		stations[c].free()
	stations.clear()
	hp.clear()
	parts.clear()
	_recalc()


## Builds a station (purifier, grill…) on a floor: key = Vector3i(x, z, level).
func add_station(kind: String, k: Vector3i, def: Dictionary) -> Station:
	var st := Station.new()
	st.setup(kind, k, def)
	st.position = cell_center(Vector2i(k.x, k.y)) + Vector3(0, k.z * RaftParts.H, 0)
	st.rotation.y = PI
	add_child(st)
	stations[k] = st
	changed.emit()
	return st


## Can the player be at this raft-local point? Anywhere above the raft's footprint:
## off an upper floor you fall onto the deck, never into the sea.
func walkable(local: Vector3) -> bool:
	return tiles.has(cell_at(local))


func count_kind(kind: String) -> int:
	return count_stations(kind) + parts.count(kind)


func count_stations(kind: String) -> int:
	var n := 0
	for c: Vector3i in stations:
		if stations[c].kind == kind:
			n += 1
	return n


func max_hp() -> int:
	return int(cfg["tile_hp"])


func tile_hp(c: Vector2i) -> int:
	return hp.get(c, max_hp())


func damaged(c: Vector2i) -> bool:
	return tiles.has(c) and tile_hp(c) < max_hp()


## A shark bite. Returns true when the tile broke off and sank (the last tile never does).
func damage_tile(c: Vector2i) -> bool:
	if not tiles.has(c):
		return false
	var left := tile_hp(c) - 1
	if left <= 0 and tiles.size() > 1:
		remove_tile(c)
		return true
	hp[c] = maxi(1, left)
	refresh_tile(c)
	var mi: Node3D = tiles[c].get_node("Mesh")
	var tw := create_tween()
	tw.tween_property(mi, "rotation:z", 0.08, 0.06)
	tw.tween_property(mi, "rotation:z", -0.05, 0.08)
	tw.tween_property(mi, "rotation:z", 0.0, 0.1)
	return false


func repair_tile(c: Vector2i) -> void:
	hp.erase(c)
	if tiles.has(c):
		refresh_tile(c)


## Tiles with a free side: what a shark can reach.
func edge_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in tiles:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not tiles.has(c + d):
				out.append(c)
				break
	return out


func refresh_tile(c: Vector2i) -> void:
	var mi: MeshInstance3D = tiles[c].get_node("Mesh")
	mi.mesh = _mesh_for(c)


func _mesh_for(c: Vector2i) -> ArrayMesh:
	var variant := absi(c.x * 7 + c.y * 13) % 3
	var missing := max_hp() - tile_hp(c)
	var key := "%d/%d" % [variant, missing]
	if not _mesh_cache.has(key):
		_mesh_cache[key] = build_tile_mesh(tile_size, variant, missing)
	return _mesh_cache[key]


## The center of the tile nearest to a raft-local point (safe spot for the player).
func nearest_tile(local: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var bd := INF
	for c: Vector2i in tiles:
		var p := cell_center(c)
		var d := Vector2(p.x - local.x, p.z - local.z).length()
		if d < bd:
			bd = d
			best = p
	return best


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


## The tile as an item/ghost preview.
static func tile_preview_mesh() -> ArrayMesh:
	return build_tile_mesh(1.5, 0)


## A foundation tile: five nailed planks on two dark beams, rope lashings at the corners
## and two plastic barrels underneath as floats. One mesh, one atlas material.
static func build_tile_mesh(ts: float, seed_i: int, missing := 0) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 + seed_i * 31
	var st := Mk.st_begin()
	var n := 5
	var w := (ts - 0.02) / float(n)
	var beam_x := ts * 0.33
	# Bitten tiles lose planks from the edge inwards.
	var gone := [0, 4, 1, 3].slice(0, missing)
	for i in n:
		var z := -ts / 2.0 + 0.01 + w * (i + 0.5)
		var pl := ts - rng.randf_range(0.0, 0.07)
		var tint := Color(1.0, 0.93, 0.82).darkened(rng.randf_range(-0.06, 0.16))
		var px := rng.randf_range(-0.025, 0.025)
		var y := -0.04 + rng.randf_range(-0.008, 0.008)
		if i in gone:
			continue
		Mk.st_box(st, Vector3(pl, 0.07, w - 0.028), Vector3(px, y, z), tint, "wood", Vector3(rng.randf_range(-0.01, 0.01), rng.randf_range(-0.015, 0.015), 0.0))
		for bx: float in [-beam_x, beam_x]:
			for dz: float in [-w * 0.24, w * 0.24]:
				Mk.st_box(st, Vector3(0.022, 0.012, 0.022), Vector3(bx + px * 0.5, y + 0.039, z + dz), Color(0.55, 0.55, 0.58), "metal")
	for bx: float in [-beam_x, beam_x]:
		Mk.st_box(st, Vector3(0.13, 0.11, ts - 0.04), Vector3(bx, -0.13, 0.0), Color(1, 0.95, 0.9), "wood_dark")
		for bz: float in [-ts / 2.0 + 0.09, ts / 2.0 - 0.09]:
			for k in 3:
				Mk.st_box(st, Vector3(0.17, 0.03, 0.028), Vector3(bx, -0.04 + 0.002 * k, bz + (k - 1) * 0.034), Color(1, 0.97, 0.9), "rope", Vector3(0, 0, rng.randf_range(-0.12, 0.12)), 0.6)
	var float_tint := Color("#4a86c8") if seed_i != 1 else Color("#e6e1d2")
	for fz: float in [-ts * 0.24, ts * 0.24]:
		Mk.st_cyl(st, 0.17, ts * 0.72, Vector3(0.0, -0.32, fz), float_tint, "plastic", Vector3(0, 0, PI / 2.0), 10, 1.5, 0.1)
	return Mk.st_commit(st)
