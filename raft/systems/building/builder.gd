class_name Builder
extends Node3D
## Hammer mode: `kind` is what gets built; where it goes depends on its "on" rule:
## water (floor tiles next to the raft), deck (stations), stairs (stairs, hammock), edge /
## edge_out (walls, windows, doors / nets on the rim), corner (pillars, lanterns), wall
## (lanterns on the wall you look at, on your side of it), roof (a floor slab above).
## Everything else is built on the floor of the player's level: the deck or a roof. `rot`
## (the rotate button) turns lanterns, stairs and hammocks by 90° clockwise and flips the
## way a door opens. Looking at a bitten tile offers a repair.

const H := RaftParts.H

var raft: Raft
var player: Player
var inv: Inventory
var kind := "tile"
var cell := Vector2i.ZERO
var level := 0
var key: Variant = Vector2i.ZERO
var dir := 0
var rot := 0
var has_target := false
var valid := false
var active := false
var repair := false         # the target is a bitten tile to fix, not something new
var _ghost: MeshInstance3D
var _ok_mat: StandardMaterial3D
var _bad_mat: StandardMaterial3D
var _ghost_kind := ""
var _t := 0.0


func _ready() -> void:
	_ghost = MeshInstance3D.new()
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ok_mat = _ghost_mat(Color(0.45, 1.0, 0.55, 0.42))
	_bad_mat = _ghost_mat(Color(1.0, 0.4, 0.3, 0.4))
	_ghost.visible = false
	raft.add_child(_ghost)


func _ghost_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = true
	m.render_priority = 100     # after the see-through water, or it veils the ghost
	return m


func def() -> Dictionary:
	return Data.build_by_id[kind]


func rotatable() -> bool:
	return def().get("rotate", false)


func cost() -> Dictionary:
	return Data.b["raft"]["repair_cost"] if repair else def()["cost"]


func affordable() -> bool:
	return inv.has_all(cost())


func turn() -> void:
	rot = (rot + 1) % 4


func _process(delta: float) -> void:
	_t += delta
	has_target = false
	valid = false
	repair = false
	level = clampi(roundi(player.position.y / H), 0, RaftParts.MAX_LEVEL)
	var pos := Vector3.ZERO
	var yaw := 0.0
	if active and not _find_repair():
		match def()["on"]:
			"water":
				_find_water_cell()
			"deck", "stairs":
				_find_deck_cell()
			"edge", "edge_out":
				_find_edge(def()["on"] == "edge_out")
			"corner":
				_find_corner()
			"wall":
				_find_wall()
			"roof":
				_find_roof()
	var gk := "tile" if repair else ("door_ajar" if kind == "door" else kind)
	if _ghost_kind != gk:
		_ghost_kind = gk
		_ghost.mesh = Looks.mesh(gk)
	_ghost.visible = has_target
	if not has_target:
		return
	match def()["on"] if not repair else "deck":
		"edge":
			pos = raft.parts.edge_center(key)
			yaw = RaftParts.door_yaw(key, dir) if kind == "door" else RaftParts.edge_yaw(key)
		"edge_out":
			yaw = raft.parts.outward_yaw(key)
			pos = raft.parts.edge_center(key) + Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.18)
		"corner":
			pos = raft.parts.corner_center(key)
			yaw = -rot * PI / 2.0
		"wall":
			var e := RaftParts.lamp_edge(key)
			yaw = RaftParts.edge_yaw(e) + (0.0 if key.z % 2 == 0 else PI)
			pos = raft.parts.edge_center(e) + Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.07)
		"stairs":
			pos = raft.parts.cell_pos(Vector3i(cell.x, cell.y, level))
			var dv: Vector2i = RaftParts.DIRS[dir]
			yaw = atan2(float(dv.x), float(dv.y)) + (PI / 2.0 if kind == "hammock" else 0.0)
		"roof":
			pos = raft.parts.cell_pos(key) - Vector3(0, H, 0)
		_:
			pos = raft.cell_center(cell) + Vector3(0, level * H if not repair else 0.0, 0)
			yaw = PI if gk in ["purifier", "grill", "planter", "collector"] else 0.0
	_ghost.position = pos + Vector3(0, 0.02 + sin(_t * 5.0) * 0.015, 0)
	_ghost.rotation.y = yaw
	_ghost.material_override = _ok_mat if valid and affordable() else _bad_mat


## Where the view ray meets the floor plane at `level_y` (raft-local), or null.
func _deck_hit(level_y := 0.0) -> Variant:
	var o := raft.to_local(player.cam.global_position)
	var d := raft.global_basis.inverse() * -player.cam.global_basis.z
	if d.y > -0.08:
		return null
	var hit := o + d * ((level_y - o.y) / d.y)
	if Vector2(hit.x - o.x, hit.z - o.z).length() > float(Data.b["raft"]["build_reach"]):
		return null
	return hit


func _floor_hit() -> Variant:
	return _deck_hit(level * H)


func _look_dir() -> Vector2i:
	var d := raft.global_basis.inverse() * -player.cam.global_basis.z
	if absf(d.x) > absf(d.z):
		return Vector2i(signi(roundi(d.x * 2.0)), 0)
	return Vector2i(0, signi(roundi(d.z * 2.0)))


## Looking at a bitten tile: offer to fix it first.
func _find_repair() -> bool:
	if level > 0:
		return false
	var hit: Variant = _deck_hit()
	if hit == null:
		return false
	var c := raft.cell_at(hit)
	if not raft.damaged(c):
		return false
	cell = c
	has_target = true
	valid = true
	repair = true
	return true


func _find_water_cell() -> void:
	var hit: Variant = _deck_hit()
	if hit == null:
		return
	var c := raft.cell_at(hit)
	if raft.has_tile(c):
		# Looking at the floor near the edge: offer the neighbour cell in the look direction.
		var d := raft.global_basis.inverse() * -player.cam.global_basis.z
		var f := Vector3(d.x, 0, d.z).normalized()
		if absf(f.x) < 0.38 and absf(f.z) < 0.38:
			return
		c += _look_dir()
		if raft.has_tile(c):
			return
	cell = c
	has_target = true
	valid = raft.can_place(c)


func _find_deck_cell() -> void:
	var hit: Variant = _floor_hit()
	if hit == null:
		return
	var c := raft.cell_at(hit)
	if not raft.parts.has_floor(c, level):
		return
	cell = c
	has_target = true
	var k := Vector3i(c.x, c.y, level)
	var standing := raft.cell_at(player.position) == c
	if kind == "stairs" or kind == "hammock":
		dir = (RaftParts.DIRS.find(_look_dir()) + rot) % 4
		valid = (raft.parts.can_stairs(k) if kind == "stairs" else raft.parts.can_bed(k)) and not standing
	else:
		valid = not raft.parts.cell_busy(k) and not standing


func _edge_dir(hit: Vector3, c: Vector2i) -> Vector2i:
	var off: Vector3 = hit - raft.cell_center(c)
	var d := Vector2i(signi(roundi(off.x * 10.0)), 0) if absf(off.x) > absf(off.z) else Vector2i(0, signi(roundi(off.z * 10.0)))
	return d if d != Vector2i.ZERO else _look_dir()


func _find_edge(outer: bool) -> void:
	var hit: Variant = _floor_hit()
	if hit == null:
		return
	var c := raft.cell_at(hit)
	if not raft.parts.has_floor(c, level):
		return
	key = RaftParts.edge_of(c, _edge_dir(hit, c), level)
	dir = rot % 2
	has_target = true
	valid = raft.parts.can_edge(key, outer, kind, dir)


func _find_corner() -> void:
	var hit: Variant = _floor_hit()
	if hit == null:
		return
	var c := raft.cell_at(hit)
	if not raft.parts.has_floor(c, level):
		return
	var off: Vector3 = hit - raft.cell_center(c)
	key = Vector3i(c.x if off.x > 0.0 else c.x - 1, c.y if off.z > 0.0 else c.y - 1, level)
	dir = rot
	has_target = true
	valid = raft.parts.can_corner(key, kind, dir)


## Wall lanterns: on the wall or window the view ray hits, on the face you look from.
func _find_wall() -> void:
	var from := player.cam.global_position
	var to := from - player.cam.global_basis.z * (float(Data.b["raft"]["build_reach"]) + 1.0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not hit["collider"] is Part:
		return
	var wall: Part = hit["collider"]
	if not wall.kind in ["wall", "window", "door"]:
		return
	var e: Vector4i = wall.key
	var o := raft.to_local(from) - raft.parts.edge_center(e)
	var front := (o.x if e.z == 0 else o.z) > 0.0     # face 0 looks to +X / +Z
	key = Vector4i(e.x, e.y, e.z * 2 + (0 if front else 1), e.w)
	has_target = true
	valid = raft.parts.can_lamp(key)


## A roof one level up over the floor you look at; from an upper floor, looking past its
## edge extends that floor.
func _find_roof() -> void:
	var hit: Variant = _floor_hit()
	if hit == null:
		return
	var c := raft.cell_at(hit)
	if not raft.has_tile(c):
		return
	var lvl := level + 1 if raft.parts.has_floor(c, level) else level
	cell = c
	key = Vector3i(c.x, c.y, lvl)
	has_target = true
	valid = raft.parts.can_roof(c, lvl)


## Returns true when something was built or repaired.
func place() -> bool:
	if not (has_target and valid) or not inv.pay(cost()):
		return false
	if repair:
		raft.repair_tile(cell)
		return true
	match def()["on"]:
		"water":
			raft.add_tile(cell)
		"deck":
			raft.add_station(kind, Vector3i(cell.x, cell.y, level), def())
		"stairs":
			raft.parts.add(kind, Vector3i(cell.x, cell.y, level), dir)
		"corner", "edge":
			raft.parts.add(kind, key, dir)
		_:
			raft.parts.add(kind, key)
	return true
