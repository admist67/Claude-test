class_name Builder
extends Node3D
## Hammer mode: `kind` is what gets built; where it goes depends on its "on" rule:
## water (floor tiles next to the raft), deck (stations), stairs, edge / edge_out (walls,
## windows, doors / nets on the rim), corner (pillars, lanterns), roof (over a deck cell).
## The view ray picks the spot; a ghost shows it. Looking at a bitten tile offers a repair.

var raft: Raft
var player: Player
var inv: Inventory
var kind := "tile"
var cell := Vector2i.ZERO
var key: Variant = Vector2i.ZERO
var dir := 0
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


func cost() -> Dictionary:
	return Data.b["raft"]["repair_cost"] if repair else def()["cost"]


func affordable() -> bool:
	return inv.has_all(cost())


func _process(delta: float) -> void:
	_t += delta
	has_target = false
	valid = false
	repair = false
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
			"roof":
				_find_roof()
	var gk := "tile" if repair else kind
	if _ghost_kind != gk:
		_ghost_kind = gk
		_ghost.mesh = Looks.mesh(gk)
	_ghost.visible = has_target
	if not has_target:
		return
	match def()["on"] if not repair else "deck":
		"edge":
			pos = raft.parts.edge_center(key)
			yaw = RaftParts.edge_yaw(key)
		"edge_out":
			yaw = raft.parts.outward_yaw(key)
			pos = raft.parts.edge_center(key) + Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.18)
		"corner":
			pos = raft.parts.corner_center(key)
		"stairs":
			pos = raft.cell_center(cell)
			var dv: Vector2i = RaftParts.DIRS[dir]
			yaw = atan2(float(dv.x), float(dv.y)) + (PI / 2.0 if kind == "hammock" else 0.0)
		_:
			pos = raft.cell_center(cell)
			yaw = PI if gk in ["purifier", "grill"] else 0.0
	_ghost.position = pos + Vector3(0, 0.02 + sin(_t * 5.0) * 0.015, 0)
	_ghost.rotation.y = yaw
	_ghost.material_override = _ok_mat if valid and affordable() else _bad_mat


## Where the view ray meets the floor plane of the player's level (raft-local), or null.
func _deck_hit(level_y := 0.0) -> Variant:
	var o := raft.to_local(player.cam.global_position)
	var d := raft.global_basis.inverse() * -player.cam.global_basis.z
	if d.y > -0.08:
		return null
	var hit := o + d * ((level_y - o.y) / d.y)
	if Vector2(hit.x - o.x, hit.z - o.z).length() > float(Data.b["raft"]["build_reach"]):
		return null
	return hit


func _level() -> float:
	return RaftParts.H if player.position.y > 1.2 else 0.0


func _look_dir() -> Vector2i:
	var d := raft.global_basis.inverse() * -player.cam.global_basis.z
	if absf(d.x) > absf(d.z):
		return Vector2i(signi(roundi(d.x * 2.0)), 0)
	return Vector2i(0, signi(roundi(d.z * 2.0)))


## Looking at a bitten tile: offer to fix it first.
func _find_repair() -> bool:
	if _level() > 0.0:
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
	var hit: Variant = _deck_hit(_level())
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
	var hit: Variant = _deck_hit()
	if hit == null:
		return
	var c := raft.cell_at(hit)
	if not raft.has_tile(c):
		return
	cell = c
	has_target = true
	var standing := raft.cell_at(player.position) == c
	if kind == "stairs" or kind == "hammock":
		dir = RaftParts.DIRS.find(_look_dir())
		valid = (raft.parts.can_stairs(c) if kind == "stairs" else raft.parts.can_bed(c)) and not standing
	else:
		valid = not raft.stations.has(c) and not raft.parts.cell_busy(c) and not standing


func _find_edge(outer: bool) -> void:
	var hit: Variant = _deck_hit()
	if hit == null:
		return
	var c := raft.cell_at(hit)
	if not raft.has_tile(c):
		return
	var off: Vector3 = hit - raft.cell_center(c)
	var d := Vector2i(signi(roundi(off.x * 10.0)), 0) if absf(off.x) > absf(off.z) else Vector2i(0, signi(roundi(off.z * 10.0)))
	if d == Vector2i.ZERO:
		d = _look_dir()
	key = RaftParts.edge_of(c, d)
	has_target = true
	valid = raft.parts.can_edge(key, outer)


func _find_corner() -> void:
	var hit: Variant = _deck_hit()
	if hit == null:
		return
	var c := raft.cell_at(hit)
	if not raft.has_tile(c):
		return
	var off: Vector3 = hit - raft.cell_center(c)
	key = Vector2i(c.x if off.x > 0.0 else c.x - 1, c.y if off.z > 0.0 else c.y - 1)
	has_target = true
	valid = raft.parts.can_corner(key)


func _find_roof() -> void:
	var hit: Variant = _deck_hit(_level())
	if hit == null:
		return
	var c := raft.cell_at(hit)
	if not raft.has_tile(c):
		return
	cell = c
	has_target = true
	valid = raft.parts.can_roof(c)


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
			raft.add_station(kind, cell, def())
		"stairs":
			raft.parts.add(kind, cell, dir)
		"roof":
			raft.parts.add(kind, cell)
		_:
			raft.parts.add(kind, key)
	return true
