class_name RaftParts
extends Node3D
## Everything built on top of the floor tiles. Keys are raft grid coordinates:
## edges Vector3i(x, z, side) — side 0 is the +X edge of cell (x, z), side 1 its +Z edge;
## corners Vector2i(x, z) — the +X+Z corner of cell (x, z); roofs and stairs by cell.
## Roofs are walkable: with stairs they make a second floor at height H.

const H := 2.4
const DIRS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]

var raft: Raft
var player: Node3D
var daynight: DayNight
var edges: Dictionary = {}      # Vector3i -> Part
var corners: Dictionary = {}    # Vector2i -> Part
var roofs: Dictionary = {}      # Vector2i -> Part
var stairs: Dictionary = {}     # Vector2i -> Part


# ---------------------------------------------------------------- geometry

static func edge_of(c: Vector2i, d: Vector2i) -> Vector3i:
	if d == Vector2i(1, 0):
		return Vector3i(c.x, c.y, 0)
	if d == Vector2i(-1, 0):
		return Vector3i(c.x - 1, c.y, 0)
	if d == Vector2i(0, 1):
		return Vector3i(c.x, c.y, 1)
	return Vector3i(c.x, c.y - 1, 1)


static func edge_cells(k: Vector3i) -> Array[Vector2i]:
	if k.z == 0:
		return [Vector2i(k.x, k.y), Vector2i(k.x + 1, k.y)]
	return [Vector2i(k.x, k.y), Vector2i(k.x, k.y + 1)]


static func corner_cells(k: Vector2i) -> Array[Vector2i]:
	return [k, k + Vector2i(1, 0), k + Vector2i(0, 1), k + Vector2i(1, 1)]


func edge_center(k: Vector3i) -> Vector3:
	var t := raft.tile_size
	return Vector3((k.x + 0.5) * t, 0, k.y * t) if k.z == 0 else Vector3(k.x * t, 0, (k.y + 0.5) * t)


func corner_center(k: Vector2i) -> Vector3:
	var t := raft.tile_size
	return Vector3((k.x + 0.5) * t, 0, (k.y + 0.5) * t)


## Edge rotation: wall meshes span X, side 0 edges run along Z.
static func edge_yaw(k: Vector3i) -> float:
	return PI / 2.0 if k.z == 0 else 0.0


## The free side of an outer edge, as a yaw that turns local +Z outward.
func outward_yaw(k: Vector3i) -> float:
	var cells := edge_cells(k)
	var out_first := not raft.has_tile(cells[0])
	if k.z == 0:
		return -PI / 2.0 if out_first else PI / 2.0
	return PI if out_first else 0.0


# ---------------------------------------------------------------- rules

func _tiles_touching(cells: Array[Vector2i]) -> int:
	var n := 0
	for c in cells:
		if raft.has_tile(c):
			n += 1
	return n


func can_edge(k: Vector3i, outer: bool) -> bool:
	if edges.has(k):
		return false
	var n := _tiles_touching(edge_cells(k))
	return n == 1 if outer else n >= 1


func can_corner(k: Vector2i) -> bool:
	return not corners.has(k) and _tiles_touching(corner_cells(k)) >= 1


func supported(c: Vector2i) -> bool:
	for d in DIRS:
		if roofs.has(c + d):
			return true
		var e: Part = edges.get(edge_of(c, d))
		if e and e.kind != "net":
			return true
	for k: Vector2i in [c, c - Vector2i(1, 0), c - Vector2i(0, 1), c - Vector2i(1, 1)]:
		if corners.has(k) and corners[k].kind == "pillar":
			return true
	return false


func can_roof(c: Vector2i) -> bool:
	return raft.has_tile(c) and not roofs.has(c) and not stairs.has(c) and supported(c)


func can_stairs(c: Vector2i) -> bool:
	return raft.has_tile(c) and not stairs.has(c) and not roofs.has(c) and not raft.stations.has(c)


func cell_busy(c: Vector2i) -> bool:
	return stairs.has(c)


## Can the player be at this raft-local point? Upper floor = roofs and stairs.
func walkable(p: Vector3) -> bool:
	var c := raft.cell_at(p)
	if p.y > 1.2:
		return roofs.has(c) or stairs.has(c) or raft.has_tile(c)
	return raft.has_tile(c)


# ---------------------------------------------------------------- building

func add(kind: String, k: Variant, d := 0) -> Part:
	var p := Part.new()
	p.setup(kind, k, d)
	if Data.build_by_id.get(kind, {}).has("capacity"):
		p.capacity = int(Data.build_by_id[kind]["capacity"])
	match kind:
		"wall", "window", "door":
			p.position = edge_center(k)
			p.rotation.y = edge_yaw(k)
			edges[k] = p
		"net":
			p.rotation.y = outward_yaw(k)
			p.position = edge_center(k) + Basis(Vector3.UP, p.rotation.y) * Vector3(0, 0, 0.18)
			edges[k] = p
		"pillar", "lantern":
			p.position = corner_center(k)
			corners[k] = p
		"roof":
			p.position = raft.cell_center(k)
			roofs[k] = p
		"stairs":
			var dv: Vector2i = DIRS[d]
			p.position = raft.cell_center(k)
			p.rotation.y = atan2(float(dv.x), float(dv.y))
			stairs[k] = p
	add_child(p)
	return p


func count(kind: String) -> int:
	var n := 0
	for dict: Dictionary in [edges, corners, roofs, stairs]:
		for k: Variant in dict:
			if dict[k].kind == kind:
				n += 1
	return n


## A tile sank: drop what stood on it or no longer touches the raft.
func on_tile_removed(c: Vector2i) -> void:
	for dict: Dictionary in [roofs, stairs]:
		if dict.has(c):
			dict[c].queue_free()
			dict.erase(c)
	for k: Vector3i in edges.keys():
		var n := _tiles_touching(edge_cells(k))
		if n == 0 or (edges[k].kind == "net" and n != 1):
			_release(edges[k])
			edges[k].queue_free()
			edges.erase(k)
	for k: Vector2i in corners.keys():
		if _tiles_touching(corner_cells(k)) == 0:
			corners[k].queue_free()
			corners.erase(k)


func clear() -> void:
	for dict: Dictionary in [edges, corners, roofs, stairs]:
		for k: Variant in dict:
			_release(dict[k])
			dict[k].free()
		dict.clear()


func to_list() -> Array:
	var out: Array = []
	for dict: Dictionary in [edges, corners, roofs, stairs]:
		for k: Variant in dict:
			out.append(dict[k].to_dict())
	return out


func from_list(list: Array) -> void:
	for e: Dictionary in list:
		var a: Array = e["key"]
		var k: Variant = Vector3i(int(a[0]), int(a[1]), int(a[2])) if a.size() == 3 else Vector2i(int(a[0]), int(a[1]))
		add(e["kind"], k, int(e.get("dir", 0)))


# ---------------------------------------------------------------- nets

func nets() -> Array:
	return edges.values().filter(func(p: Part) -> bool: return p.kind == "net")


## Debris drifting into a net stays in it. Returns true when `d` got caught.
func try_net(d: Debris) -> bool:
	var local := raft.to_local(d.global_position)
	for net: Part in nets():
		if net.caught.size() >= net.capacity:
			continue
		var b := Basis(Vector3.UP, net.rotation.y)
		var rel := b.inverse() * (local - net.position)
		if absf(rel.x) < 0.75 and rel.z > -0.5 and rel.z < 0.9:
			net.caught.append(d)
			d.net = net
			d.net_offset = Vector3(clampf(rel.x, -0.6, 0.6), 0, 0.35)
			return true
	return false


func _release(p: Part) -> void:
	for d: Debris in p.caught:
		if is_instance_valid(d):
			d.net = null
	p.caught.clear()


func _process(delta: float) -> void:
	var night := daynight != null and daynight.is_night()
	var pp := player.position if player else Vector3(999, 0, 999)
	for k: Variant in edges:
		var p: Part = edges[k]
		if p.kind == "door":
			p.tick(delta, Vector2(p.position.x - pp.x, p.position.z - pp.z).length() < 1.4 and pp.y < 1.5, night)
	for k: Variant in corners:
		corners[k].tick(delta, false, night)
