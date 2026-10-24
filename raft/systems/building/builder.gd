class_name Builder
extends Node3D
## Hammer mode: shows a ghost tile on the empty cell the player looks at; place() builds it.

var raft: Raft
var player: Player
var inv: Inventory
var cell := Vector2i.ZERO
var has_target := false
var valid := false
var active := false
var _ghost: MeshInstance3D
var _ok_mat: StandardMaterial3D
var _bad_mat: StandardMaterial3D
var _t := 0.0


func _ready() -> void:
	_ghost = MeshInstance3D.new()
	var bm := BoxMesh.new()
	var ts := float(Data.b["raft"]["tile"])
	bm.size = Vector3(ts - 0.04, 0.12, ts - 0.04)
	_ghost.mesh = bm
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ok_mat = Mk.mat(Color(0.45, 1.0, 0.55, 0.45)).duplicate()
	_ok_mat.no_depth_test = true
	_bad_mat = Mk.mat(Color(1.0, 0.4, 0.3, 0.4)).duplicate()
	_bad_mat.no_depth_test = true
	_ghost.visible = false
	raft.add_child(_ghost)


func cost() -> Dictionary:
	return Data.b["raft"]["tile_cost"]


func affordable() -> bool:
	return inv.has_all(cost())


func _process(delta: float) -> void:
	_t += delta
	has_target = false
	valid = false
	if active:
		_find_target()
	_ghost.visible = has_target
	if has_target:
		_ghost.position = raft.cell_center(cell) + Vector3(0, 0.0 + sin(_t * 5.0) * 0.015, 0)
		_ghost.material_override = _ok_mat if valid and affordable() else _bad_mat


func _find_target() -> void:
	var o := raft.to_local(player.cam.global_position)
	var d := raft.global_basis.inverse() * -player.cam.global_basis.z
	if d.y > -0.08:
		return
	var t := -o.y / d.y
	var hit := o + d * t
	var c := raft.cell_at(hit)
	var reach := float(Data.b["raft"]["build_reach"])
	if Vector2(hit.x - o.x, hit.z - o.z).length() > reach:
		return
	if raft.has_tile(c):
		# Looking at the floor near the edge: offer the neighbour cell in the look direction.
		var f := Vector3(d.x, 0, d.z).normalized()
		var step := Vector2i(roundi(f.x), roundi(f.z)) if absf(f.x) > 0.38 or absf(f.z) > 0.38 else Vector2i.ZERO
		if step == Vector2i.ZERO:
			return
		if absf(f.x) > absf(f.z):
			step = Vector2i(signi(step.x), 0)
		else:
			step = Vector2i(0, signi(step.y))
		c += step
		if raft.has_tile(c):
			return
	cell = c
	has_target = true
	valid = raft.can_place(c)


## Returns true when a tile was built.
func place() -> bool:
	if not (has_target and valid) or not inv.pay(cost()):
		return false
	raft.add_tile(cell)
	return true
