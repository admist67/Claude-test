class_name RaftParts
extends Node3D
## Everything built on the raft, on floors by level: level 0 is the deck (floor tiles),
## level L ≥ 1 is a floor made of roofs at height L·H. Keys carry the level:
## edges Vector4i(x, z, side, L) — side 0 is the +X edge of cell (x, z), 1 its +Z edge;
## corners Vector3i(x, z, L) — the +X+Z corner of cell (x, z);
## roofs Vector3i(x, z, L) — a floor slab with its top at L·H over cell (x, z), L ≥ 1;
## stairs, beds Vector3i(x, z, L) — standing on level L (stairs climb to L + 1);
## lamps Vector4i(x, z, side * 2 + face, L) — a lantern on one face of a wall.
## A door's dir picks the cell its leaf swings into; nothing may stand in that sweep.

const H := 2.4
const MAX_LEVEL := 3
const DIRS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]

var raft: Raft
var daynight: DayNight
var edges: Dictionary = {}      # Vector4i -> Part
var corners: Dictionary = {}    # Vector3i -> Part
var roofs: Dictionary = {}      # Vector3i -> Part
var stairs: Dictionary = {}     # Vector3i -> Part
var beds: Dictionary = {}       # Vector3i -> Part (hammocks)
var lamps: Dictionary = {}      # Vector4i -> Part (wall lanterns)


# ---------------------------------------------------------------- geometry

static func edge_of(c: Vector2i, d: Vector2i, lvl: int) -> Vector4i:
	if d == Vector2i(1, 0):
		return Vector4i(c.x, c.y, 0, lvl)
	if d == Vector2i(-1, 0):
		return Vector4i(c.x - 1, c.y, 0, lvl)
	if d == Vector2i(0, 1):
		return Vector4i(c.x, c.y, 1, lvl)
	return Vector4i(c.x, c.y - 1, 1, lvl)


static func edge_cells(k: Vector4i) -> Array[Vector2i]:
	if k.z == 0:
		return [Vector2i(k.x, k.y), Vector2i(k.x + 1, k.y)]
	return [Vector2i(k.x, k.y), Vector2i(k.x, k.y + 1)]


static func corner_cells(k: Vector3i) -> Array[Vector2i]:
	var c := Vector2i(k.x, k.y)
	return [c, c + Vector2i(1, 0), c + Vector2i(0, 1), c + Vector2i(1, 1)]


## Wall meshes span X; side 0 edges run along Z.
static func edge_yaw(k: Vector4i) -> float:
	return PI / 2.0 if k.z == 0 else 0.0


func edge_center(k: Vector4i) -> Vector3:
	var t := raft.tile_size
	var y := k.w * H
	return Vector3((k.x + 0.5) * t, y, k.y * t) if k.z == 0 else Vector3(k.x * t, y, (k.y + 0.5) * t)


func corner_center(k: Vector3i) -> Vector3:
	var t := raft.tile_size
	return Vector3((k.x + 0.5) * t, k.z * H, (k.y + 0.5) * t)


func cell_pos(k: Vector3i) -> Vector3:
	return raft.cell_center(Vector2i(k.x, k.y)) + Vector3(0, k.z * H, 0)


## The free side of an outer deck edge, as a yaw that turns local +Z outward.
func outward_yaw(k: Vector4i) -> float:
	var cells := edge_cells(k)
	var out_first := not raft.has_tile(cells[0])
	if k.z == 0:
		return -PI / 2.0 if out_first else PI / 2.0
	return PI if out_first else 0.0


## A wall lantern's edge and the side of the wall it hangs on.
static func lamp_edge(k: Vector4i) -> Vector4i:
	return Vector4i(k.x, k.y, k.z / 2, k.w)


## Where a wall lantern's head is, raft-local.
func lamp_head(k: Vector4i) -> Vector3:
	var e := lamp_edge(k)
	var yaw := edge_yaw(e) + (0.0 if k.z % 2 == 0 else PI)
	return edge_center(e) + Basis(Vector3.UP, yaw) * Vector3(0, 1.69, 0.33)


## Doors turn half a circle to open the other way (dir 1): the leaf swings into the cell
## on local +Z.
static func door_yaw(k: Vector4i, d: int) -> float:
	return edge_yaw(k) + (PI if d % 2 == 1 else 0.0)


static func swing_cell(k: Vector4i, d: int) -> Vector3i:
	var c: Vector2i = edge_cells(k)[1 - d % 2]
	return Vector3i(c.x, c.y, k.w)


## True when raft-local `q` lies in the quarter circle the leaf of door (k, d) sweeps.
func in_swing(k: Vector4i, d: int, q: Vector3) -> bool:
	var rel := Basis(Vector3.UP, door_yaw(k, d)).inverse() * (q - edge_center(k))
	return rel.z > -0.05 and rel.x > -0.65 and Vector2(rel.x + 0.56, rel.z).length() < 1.2


func _door_swings(c: Vector3i) -> bool:
	for p: Part in doors():
		if swing_cell(p.key, p.dir) == c:
			return true
	return false


## The edge a corner lantern's arm points along (dir 0..3 = +X, +Z, -X, -Z).
static func arm_edge(k: Vector3i, d: int) -> Vector4i:
	match d % 4:
		0:
			return Vector4i(k.x + 1, k.y, 1, k.z)
		1:
			return Vector4i(k.x, k.y + 1, 0, k.z)
		2:
			return Vector4i(k.x, k.y, 1, k.z)
	return Vector4i(k.x, k.y, 0, k.z)


# ---------------------------------------------------------------- floors and rules

func has_floor(c: Vector2i, lvl: int) -> bool:
	return raft.has_tile(c) if lvl == 0 else roofs.has(Vector3i(c.x, c.y, lvl))


func _floors_touching(cells: Array[Vector2i], lvl: int) -> int:
	var n := 0
	for c in cells:
		if has_floor(c, lvl):
			n += 1
	return n


func can_edge(k: Vector4i, outer: bool, kind := "", d := 0) -> bool:
	if edges.has(k):
		return false
	var n := _floors_touching(edge_cells(k), k.w)
	if not ((n == 1 and k.w == 0) if outer else n >= 1):
		return false
	if kind in ["net", "trap"]:
		return true
	# A lantern arm pointing along this edge would end up inside the wall.
	var ends: Array[Vector3i] = [Vector3i(k.x, k.y, k.w), Vector3i(k.x, k.y - 1, k.w) if k.z == 0 else Vector3i(k.x - 1, k.y, k.w)]
	for c in ends:
		var lamp: Part = corners.get(c)
		if lamp and lamp.kind != "pillar" and arm_edge(c, lamp.dir) == k:
			return false
	if kind == "door":
		var sc := swing_cell(k, d)
		if stairs.has(sc) or beds.has(sc) or raft.stations.has(sc):
			return false
		for lk: Vector4i in lamps:
			if lk.w == k.w and in_swing(k, d, lamp_head(lk)):
				return false
	return true


func can_corner(k: Vector3i, kind := "", d := 0) -> bool:
	if corners.has(k) or _floors_touching(corner_cells(k), k.z) == 0:
		return false
	var wall: Part = edges.get(arm_edge(k, d))
	return kind == "pillar" or wall == null or wall.kind in ["net", "trap"]


## On a wall or window (a door leaf moves), clear of any door's sweep.
func can_lamp(k: Vector4i) -> bool:
	var wall: Part = edges.get(lamp_edge(k))
	if lamps.has(k) or wall == null or not wall.kind in ["wall", "window"]:
		return false
	for p: Part in doors():
		if p.key.w == k.w and in_swing(p.key, p.dir, lamp_head(k)):
			return false
	return true


## A roof at level `lvl` over `c` rests on walls or pillars of the level below,
## or hangs on to a neighbouring roof of the same level.
func supported(c: Vector2i, lvl: int) -> bool:
	for d in DIRS:
		if roofs.has(Vector3i(c.x + d.x, c.y + d.y, lvl)):
			return true
		var e: Part = edges.get(edge_of(c, d, lvl - 1))
		if e and not e.kind in ["net", "trap"]:
			return true
	for k: Vector2i in [c, c - Vector2i(1, 0), c - Vector2i(0, 1), c - Vector2i(1, 1)]:
		var p: Part = corners.get(Vector3i(k.x, k.y, lvl - 1))
		if p and p.kind == "pillar":
			return true
	return false


func can_roof(c: Vector2i, lvl: int) -> bool:
	if lvl < 1 or lvl > MAX_LEVEL or not raft.has_tile(c) or roofs.has(Vector3i(c.x, c.y, lvl)):
		return false
	if stairs.has(Vector3i(c.x, c.y, lvl - 1)):
		return false
	return supported(c, lvl)


## Something stands in the cell, or a door opens into it.
func cell_busy(k: Vector3i) -> bool:
	return stairs.has(k) or beds.has(k) or raft.stations.has(k) or _door_swings(k)


func can_stairs(k: Vector3i) -> bool:
	return k.z < MAX_LEVEL and has_floor(Vector2i(k.x, k.y), k.z) and not cell_busy(k) and not roofs.has(k + Vector3i(0, 0, 1))


func can_bed(k: Vector3i) -> bool:
	return has_floor(Vector2i(k.x, k.y), k.z) and not cell_busy(k)


func stairs_at(local: Vector3) -> Part:
	var c := raft.cell_at(local)
	return stairs.get(Vector3i(c.x, c.y, floori(local.y / H + 0.05)))


# ---------------------------------------------------------------- building

func add(kind: String, k: Variant, d := 0) -> Part:
	var p := Part.new()
	p.setup(kind, k, d)
	if Data.build_by_id.get(kind, {}).has("capacity"):
		p.capacity = int(Data.build_by_id[kind]["capacity"])
	match kind:
		"wall", "window", "door":
			p.position = edge_center(k)
			p.rotation.y = door_yaw(k, d) if kind == "door" else edge_yaw(k)
			edges[k] = p
		"net", "trap":
			p.rotation.y = outward_yaw(k)
			p.position = edge_center(k) + Basis(Vector3.UP, p.rotation.y) * Vector3(0, 0, 0.18)
			edges[k] = p
		"pillar", "lantern", "lantern_tall":
			p.position = corner_center(k)
			p.rotation.y = -d * PI / 2.0
			corners[k] = p
		"lantern_wall":
			var e := lamp_edge(k)
			var face := 1.0 if k.z % 2 == 0 else -1.0
			p.rotation.y = edge_yaw(e) + (0.0 if face > 0.0 else PI)
			p.position = edge_center(e) + Basis(Vector3.UP, p.rotation.y) * Vector3(0, 0, 0.07)
			lamps[k] = p
		"roof":
			p.position = cell_pos(k) - Vector3(0, H, 0)
			roofs[k] = p
		"stairs", "hammock":
			var dv: Vector2i = DIRS[d]
			p.position = cell_pos(k)
			p.rotation.y = atan2(float(dv.x), float(dv.y)) + (PI / 2.0 if kind == "hammock" else 0.0)
			(stairs if kind == "stairs" else beds)[k] = p
	add_child(p)
	return p


func _dicts() -> Array[Dictionary]:
	return [edges, corners, roofs, stairs, beds, lamps]


func count(kind: String) -> int:
	var n := 0
	for dict in _dicts():
		for k: Variant in dict:
			if dict[k].kind == kind:
				n += 1
	return n


## Takes a part down (the hammer's "Разобрать"); whatever stood on it goes too.
func remove_part(p: Part) -> void:
	for dict in _dicts():
		if dict.has(p.key) and dict[p.key] == p:
			_release(p)
			dict.erase(p.key)
			p.queue_free()
	prune()


## A tile sank: the whole column above it goes, then whatever lost its footing.
func on_tile_removed(c: Vector2i) -> void:
	for dict: Dictionary in [roofs, stairs, beds]:
		for k: Vector3i in dict.keys():
			if k.x == c.x and k.y == c.y:
				dict[k].queue_free()
				dict.erase(k)
	prune()


## Removes everything that no longer stands on a floor or hangs on a wall.
func prune() -> void:
	var changed := true
	while changed:
		changed = false
		for k: Vector4i in edges.keys():
			var n := _floors_touching(edge_cells(k), k.w)
			if n == 0 or (edges[k].kind in ["net", "trap"] and n != 1):
				changed = _drop(edges, k) or changed
		for k: Vector3i in corners.keys():
			if _floors_touching(corner_cells(k), k.z) == 0:
				changed = _drop(corners, k) or changed
		for dict: Dictionary in [stairs, beds]:
			for k: Vector3i in dict.keys():
				if not has_floor(Vector2i(k.x, k.y), k.z):
					changed = _drop(dict, k) or changed
		for k: Vector4i in lamps.keys():
			if not edges.has(lamp_edge(k)):
				changed = _drop(lamps, k) or changed
		for k: Vector3i in raft.stations.keys():
			if not has_floor(Vector2i(k.x, k.y), k.z):
				raft.stations[k].queue_free()
				raft.stations.erase(k)
				changed = true


func _drop(dict: Dictionary, k: Variant) -> bool:
	_release(dict[k])
	dict[k].queue_free()
	dict.erase(k)
	return true


func clear() -> void:
	for dict in _dicts():
		for k: Variant in dict:
			_release(dict[k])
			dict[k].free()
		dict.clear()


func to_list() -> Array:
	var out: Array = []
	for dict in _dicts():
		for k: Variant in dict:
			out.append(dict[k].to_dict())
	return out


## Loads parts; saves from before levels had no level in their keys. Edges saved by v0.6
## lost their side (only x, z were written) and can't be placed again: they are skipped.
func from_list(list: Array) -> void:
	for e: Dictionary in list:
		var a: Array = e["key"]
		var kind: String = e["kind"]
		var k: Variant
		match kind:
			"wall", "window", "door", "net", "trap", "lantern_wall":
				if a.size() < 3:
					continue
				k = Vector4i(int(a[0]), int(a[1]), int(a[2]), int(a[3]) if a.size() > 3 else 0)
			"roof":
				k = Vector3i(int(a[0]), int(a[1]), int(a[2]) if a.size() > 2 else 1)
			_:
				k = Vector3i(int(a[0]), int(a[1]), int(a[2]) if a.size() > 2 else 0)
		var p := add(kind, k, int(e.get("dir", 0)))
		p.fish = int(e.get("fish", 0))
		if e.get("open", false):
			p.toggle()


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


## Lets go of what a net holds (debris the sea already cleared away is skipped).
func _release(p: Part) -> void:
	for d: Variant in p.caught:
		if is_instance_valid(d):
			(d as Debris).net = null
	p.caught.clear()


func doors() -> Array:
	return edges.values().filter(func(p: Part) -> bool: return p.kind == "door")


func _process(delta: float) -> void:
	var night := daynight != null and daynight.is_night()
	for p: Part in edges.values():
		if p.kind in ["door", "trap"]:
			p.tick(delta, night)
	for dict: Dictionary in [corners, lamps]:
		for k: Variant in dict:
			dict[k].tick(delta, night)
