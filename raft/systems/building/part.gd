class_name Part
extends StaticBody3D
## One raft structure: wall, window, door, net (on a tile edge), pillar, lantern (on a
## corner), roof or stairs (on a cell). Doors open and close with the use button,
## nets hold the debris that drifts into them, fish traps catch a fish now and then,
## lanterns light up at night.

const H := 2.4
const USE_LAYER := 4             # ray-only bodies the player never bumps into

var kind := ""
var key: Variant                  # Vector3i edge, Vector2i corner or cell
var dir := 0                      # stairs: 0..3 = +Z, +X, -Z, -X; nets: outward side
var caught: Array = []            # nets: Debris held in the mesh
var capacity := 8
var fish := 0                     # traps: fish inside
var is_open := false
var _leaf: Node3D
var _leaf_shape: CollisionShape3D
var _open := 0.0
var _light: OmniLight3D
var _glow: MeshInstance3D
var _catch_t := 0.0
var _lit := 0.0                   # lanterns: 0 dark .. 1 burning, fades in and out



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
			_leaf_shape = _box(Vector3(1.12, 2.05, 0.08), Vector3(0, 1.03, 0))
			_use_box(Vector3(1.14, 2.05, 0.3), Vector3(0, 1.03, 0))
			# The leaf carries its own use box, so an open door is aimed at where it stands.
			_use_box(Vector3(1.14, 2.05, 0.3), Vector3(0.56, 1.03, 0), _leaf)
		"pillar":
			_box(Vector3(0.18, H, 0.18), Vector3(0, H / 2.0, 0))
		"lantern", "lantern_tall", "lantern_wall":
			var at: Vector3 = {"lantern": Vector3(0.22, 1.12, 0), "lantern_tall": Vector3(0.22, Looks.TALL_LAMP - 0.23, 0), "lantern_wall": Vector3(0, 1.69, 0.26)}[kind]
			if kind == "lantern_wall":
				_use_box(Vector3(0.3, 0.5, 0.35), Vector3(0, 1.75, 0.15))
			else:
				var ph := 1.35 if kind == "lantern" else Looks.TALL_LAMP
				_box(Vector3(0.12, ph, 0.12), Vector3(0, ph / 2.0, 0))
			_glow = MeshInstance3D.new()
			var gm := BoxMesh.new()
			gm.size = Vector3(0.12, 0.2, 0.12)
			var m := StandardMaterial3D.new()
			m.albedo_color = Color("#ffd27a")
			m.emission_enabled = true
			m.emission = Color("#ffb347")
			m.emission_energy_multiplier = 2.2
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			gm.material = m
			_glow.mesh = gm
			_glow.position = at
			add_child(_glow)
			_light = OmniLight3D.new()
			var lc: Dictionary = Data.b["lamps"]
			_light.light_color = Color("#ffc070")
			_light.light_energy = 0.0
			_light.position = at
			_light.omni_range = float(lc["range_tall"] if kind == "lantern_tall" else lc["range"])
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
		"net", "net_strong":
			_use_box(Vector3(1.4, 1.0, 0.3), Vector3(0, 0.05, 0))
		"trap":
			_use_box(Vector3(1.1, 1.0, 1.4), Vector3(0, -0.1, 0.55))
		"hammock":
			for x: float in [-0.66, 0.66]:
				_box(Vector3(0.12, 1.15, 0.12), Vector3(x, 0.575, 0))
			_use_box(Vector3(1.2, 0.6, 0.7), Vector3(0, 0.65, 0))


func _box(size: Vector3, pos: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	add_child(cs)
	return cs


## A body only the use ray sees (door opening, net), pointing back to this part.
func _use_box(size: Vector3, pos: Vector3, parent: Node = null) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = USE_LAYER
	b.collision_mask = 0
	b.set_meta("part", self)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	b.add_child(cs)
	(parent if parent else self).add_child(b)


## Where the door leaf is now (for aiming at it without a ray hit).
func leaf_center() -> Vector3:
	return _leaf.to_global(Vector3(0.56, 1.0, 0))


func toggle() -> void:
	is_open = not is_open
	_leaf_shape.disabled = is_open
	Sfx.play("door", -4.0)


## Door swing; lantern light fading on/off; a trap's next fish.
func tick(delta: float, lamps_on: bool) -> void:
	if kind == "trap" and fish < capacity:
		var def: Dictionary = Data.build_by_id["trap"]
		if _catch_t <= 0.0:
			_catch_t = randf_range(float(def["catch_time"][0]), float(def["catch_time"][1]))
		_catch_t -= delta
		if _catch_t <= 0.0:
			fish += 1
	if _leaf:
		_open = move_toward(_open, 1.0 if is_open else 0.0, delta * 2.5)
		_leaf.rotation.y = -_open * 1.6
	if _light:
		var lc: Dictionary = Data.b["lamps"]
		_lit = move_toward(_lit, 1.0 if lamps_on else 0.0, delta / float(lc["fade"]))
		_light.visible = _lit > 0.01
		_light.light_energy = float(lc["energy"]) * _lit
		_glow.visible = _lit > 0.25


## Empties a trap: raw fish, now and then a big one.
func take_fish() -> Array[String]:
	var out: Array[String] = []
	var big := float(Data.build_by_id["trap"]["big"])
	for i in fish:
		out.append("big_fish" if randf() < big else "fish")
	fish = 0
	return out


func to_dict() -> Dictionary:
	var k: Array = [key.x, key.y, key.z, key.w] if key is Vector4i else [key.x, key.y, key.z]
	return {"kind": kind, "key": k, "dir": dir, "open": is_open, "fish": fish}


## Nets and doors: the use button.
func prompt(_inv: Inventory) -> Dictionary:
	if kind == "door":
		return {"text": "Закрыть" if is_open else "Открыть", "ok": true, "icon": "door"}
	if kind == "trap":
		return {"text": "Достать рыбу (%d)" % fish if fish > 0 else "Пока пусто", "ok": fish > 0, "icon": "fish"}
	if kind == "hammock":
		var dn: DayNight = get_parent().daynight
		return {"text": "Спать", "ok": dn != null and dn.is_night(), "icon": "hammock"}
	var text := "Собрать (%d/%d)" % [caught.size(), capacity] if not caught.is_empty() else "Пусто (0/%d)" % capacity
	return {"text": text, "ok": not caught.is_empty(), "icon": kind}
