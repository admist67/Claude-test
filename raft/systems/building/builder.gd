class_name Builder
extends Node3D
## Hammer mode: `kind` is what gets built. Floor tiles go on empty water next to the raft,
## stations go on free deck tiles. Shows a ghost on the cell the player looks at.

var raft: Raft
var player: Player
var inv: Inventory
var kind := "tile"
var cell := Vector2i.ZERO
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
	if active and _find_repair():
		pass
	elif active:
		if def()["on"] == "water":
			_find_water_cell()
		else:
			_find_deck_cell()
	var gk := "tile" if repair else kind
	if _ghost_kind != gk:
		_ghost_kind = gk
		_ghost.mesh = Looks.mesh(gk)
	_ghost.visible = has_target
	if has_target:
		var lift := 0.0 if _ghost_kind == "tile" else 0.02
		_ghost.position = raft.cell_center(cell) + Vector3(0, lift + sin(_t * 5.0) * 0.015, 0)
		_ghost.rotation.y = PI
		_ghost.material_override = _ok_mat if valid and affordable() else _bad_mat


## Where the view ray meets the deck plane (raft-local), or null.
func _deck_hit() -> Variant:
	var o := raft.to_local(player.cam.global_position)
	var d := raft.global_basis.inverse() * -player.cam.global_basis.z
	if d.y > -0.08:
		return null
	var hit := o + d * (-o.y / d.y)
	if Vector2(hit.x - o.x, hit.z - o.z).length() > float(Data.b["raft"]["build_reach"]):
		return null
	return hit


## Looking at a bitten tile: offer to fix it first.
func _find_repair() -> bool:
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
		c += Vector2i(signi(roundi(f.x * 2.0)), 0) if absf(f.x) > absf(f.z) else Vector2i(0, signi(roundi(f.z * 2.0)))
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
	valid = not raft.stations.has(c) and raft.cell_at(player.position) != c


## Returns true when something was built.
func place() -> bool:
	if not (has_target and valid) or not inv.pay(cost()):
		return false
	if repair:
		raft.repair_tile(cell)
	elif kind == "tile":
		raft.add_tile(cell)
	else:
		raft.add_station(kind, cell, def())
	return true
