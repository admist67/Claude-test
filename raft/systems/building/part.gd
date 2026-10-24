class_name Part
extends StaticBody3D
## One raft structure: wall, window, door, net (on a tile edge), pillar, lantern (on a
## corner), roof or stairs (on a cell). Doors swing open when the player comes close,
## nets hold the debris that drifts into them, lanterns light up at night.

const H := 2.4

var kind := ""
var key: Variant                  # Vector3i edge, Vector2i corner or cell
var dir := 0                      # stairs: 0..3 = +Z, +X, -Z, -X; nets: outward side
var caught: Array = []            # nets: Debris held in the mesh
var capacity := 8
var _leaf: Node3D
var _open := 0.0
var _light: OmniLight3D
var _glow: MeshInstance3D



func setup(k: String, at_key: Variant, d: int) -> void:
	kind = k
	key = at_key
	dir = d
	var mi := MeshInstance3D.new()
	mi.mesh = Looks.mesh("door_frame" if kind == "door" else kind)
	add_child(mi)
	match kind:
		"wall", "window":
			_box(Vector3(Looks.T, H, 0.12), Vector3(0, H / 2.0, 0))
		"door":
			for x: float in [-0.66, 0.66]:
				_box(Vector3(0.18, H, 0.14), Vector3(x, H / 2.0, 0))
			_box(Vector3(Looks.T, 0.3, 0.14), Vector3(0, H - 0.15, 0))
			_leaf = Node3D.new()
			_leaf.position = Vector3(-0.56, 0, 0)
			var lm := MeshInstance3D.new()
			lm.mesh = Looks.mesh("door_leaf")
			_leaf.add_child(lm)
			add_child(_leaf)
		"pillar":
			_box(Vector3(0.18, H, 0.18), Vector3(0, H / 2.0, 0))
		"lantern":
			_box(Vector3(0.1, 1.35, 0.1), Vector3(0, 0.675, 0))
			_glow = MeshInstance3D.new()
			var gm := BoxMesh.new()
			gm.size = Vector3(0.12, 0.2, 0.12)
			var m := StandardMaterial3D.new()
			m.albedo_color = Color("#ffd27a")
			m.emission_enabled = true
			m.emission = Color("#ffb347")
			m.emission_energy_multiplier = 1.5
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			gm.material = m
			_glow.mesh = gm
			_glow.position = Vector3(0.22, 1.12, 0)
			add_child(_glow)
			_light = OmniLight3D.new()
			_light.light_color = Color("#ffc070")
			_light.omni_range = 7.0
			_light.light_energy = 1.3
			_light.position = Vector3(0.22, 1.1, 0)
			add_child(_light)
		"roof":
			_box(Vector3(Looks.T, 0.14, Looks.T), Vector3(0, H - 0.07, 0))
		"stairs":
			var cs := CollisionShape3D.new()
			var shape := ConvexPolygonShape3D.new()
			var t := Looks.T / 2.0
			shape.points = PackedVector3Array([
				Vector3(-t, 0, -t), Vector3(t, 0, -t), Vector3(-t, 0, t), Vector3(t, 0, t),
				Vector3(-t, H, t), Vector3(t, H, t),
			])
			cs.shape = shape
			add_child(cs)
		"net":
			_box(Vector3(1.4, 1.0, 0.2), Vector3(0, 0.05, 0))
			collision_layer = 1


func _box(size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	add_child(cs)


## Door swing toward `open` (0..1); lantern light on/off.
func tick(delta: float, player_near: bool, night: bool) -> void:
	if _leaf:
		_open = move_toward(_open, 1.0 if player_near else 0.0, delta * 2.5)
		_leaf.rotation.y = -_open * 1.6
	if _light:
		_light.visible = night
		_glow.visible = night


func to_dict() -> Dictionary:
	var k: Array = [key.x, key.y, key.z] if key is Vector3i else [key.x, key.y]
	return {"kind": kind, "key": k, "dir": dir}


## Nets: the use button.
func prompt(_inv: Inventory) -> Dictionary:
	return {"text": "Собрать (%d)" % caught.size() if not caught.is_empty() else "Пусто", "ok": not caught.is_empty(), "icon": "net"}
