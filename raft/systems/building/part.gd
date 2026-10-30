class_name Part
extends StaticBody3D
## One raft structure: wall, window, door, net (on a tile edge), pillar, lantern (on a
## corner), roof or stairs (on a cell). Doors open and close with the use button,
## nets hold the debris that drifts into them, fish traps catch a fish now and then,
## lanterns and torches light up at night. Decor stands in a cell: a bell rings, a
## ship's wheel spins, a flag flutters.

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
var _moving: Node3D               # the bell, the wheel, the flag's cloth
var _t := 0.0



func setup(k: String, at_key: Variant, d: int) -> void:
	kind = k
	key = at_key
	dir = d
	var mi := MeshInstance3D.new()
	var moving: Dictionary = {"bell": Vector3(0.2, 1.9, 0), "wheel": Vector3(0, 1.05, 0.13), "flag": Vector3(0, 2.92, 0)}
	if kind == "door":
		mi.mesh = Looks.mesh("door_frame")
	elif moving.has(kind):
		mi.mesh = Looks.mesh(kind + "_base")
		_moving = Node3D.new()
		_moving.position = moving[kind]
		var pm := MeshInstance3D.new()
		pm.mesh = Looks.mesh(kind + ("_bell" if kind == "bell" else ("_wheel" if kind == "wheel" else "_cloth")))
		_moving.add_child(pm)
		add_child(_moving)
	else:
		mi.mesh = Looks.mesh(kind)
	add_child(mi)
	if kind == "perch":
		# The food in its bowl (`fish` counts the portions).
		var food := MeshInstance3D.new()
		food.mesh = Looks.mesh("perch_food")
		_moving = food
		add_child(food)
	_decor_shapes()
	match kind:
		"wall", "window", "wall_bamboo", "wall_woven", "window_round", "window_shutters":
			_box(Vector3(Looks.T, H, 0.12), Vector3(0, H / 2.0, 0))
		"wall_stone":
			_box(Vector3(Looks.T, H, 0.2), Vector3(0, H / 2.0, 0))
		"half_wall":
			_box(Vector3(Looks.T, 1.07, 0.14), Vector3(0, 0.53, 0))
		"arch":
			for x: float in [-0.66, 0.66]:
				_box(Vector3(0.2, H, 0.18), Vector3(x, H / 2.0, 0))
			_box(Vector3(Looks.T, 0.3, 0.2), Vector3(0, H - 0.15, 0))
		"lifebuoy", "trophy", "map", "shelf":
			_use_box(Vector3(0.7, 0.6, 0.3), Vector3(0, 1.5, 0.12))
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
		"lantern", "lantern_tall", "lantern_wall", "torch", "candle", "fire_pit":
			var spots := {"lantern": Vector3(0.22, 1.02, 0), "lantern_tall": Vector3(0.22, Looks.TALL_LAMP - 0.33, 0), "lantern_wall": Vector3(0, 1.69, 0.26),
					"torch": Vector3(0, 1.74, 0), "candle": Vector3(0, 0.25, 0), "fire_pit": Vector3(0, 0.22, 0)}
			var at: Vector3 = spots[kind]
			if kind == "torch":
				_box(Vector3(0.1, 1.6, 0.1), Vector3(0, 0.8, 0))
			elif kind == "candle":
				_box(Vector3(0.16, 0.24, 0.16), Vector3(0, 0.12, 0))
			elif kind == "fire_pit":
				_box(Vector3(0.8, 0.22, 0.8), Vector3(0, 0.11, 0))
			elif kind == "lantern_wall":
				_use_box(Vector3(0.3, 0.5, 0.35), Vector3(0, 1.75, 0.15))
			else:
				var ph := 1.35 if kind == "lantern" else Looks.TALL_LAMP
				_box(Vector3(0.12, ph, 0.12), Vector3(0, ph / 2.0, 0))
			_glow = MeshInstance3D.new()
			var gm := BoxMesh.new()
			var sizes := {"torch": Vector3(0.1, 0.22, 0.1), "candle": Vector3(0.025, 0.05, 0.025), "fire_pit": Vector3(0.32, 0.26, 0.32)}
			gm.size = sizes.get(kind, Vector3(0.136, 0.18, 0.136))      # a lantern: over its glass
			var fire := kind in ["torch", "candle", "fire_pit"]
			var m := StandardMaterial3D.new()
			m.albedo_color = Color("#ffb04a") if fire else Color("#ffd27a")
			m.emission_enabled = true
			m.emission = Color("#ff8a2a") if fire else Color("#ffb347")
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
			var ranges := {"lantern_tall": "range_tall", "candle": "range_candle", "fire_pit": "range_fire"}
			_light.omni_range = float(lc[ranges.get(kind, "range")])
			add_child(_light)
		"roof", "roof_thatch":
			_box(Vector3(Looks.T, 0.14, Looks.T), Vector3(0, H - 0.07, 0))
		"stairs", "stairs_rope", "stairs_bamboo":
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


## Solid shapes of the decor (a rug has none); the bell and the wheel can be used.
func _decor_shapes() -> void:
	match kind:
		"railing":
			_box(Vector3(Looks.T, 1.05, 0.1), Vector3(0, 0.52, 0))
		"table":
			_box(Vector3(1.0, 0.78, 0.7), Vector3(0, 0.39, 0))
		"stool":
			_box(Vector3(0.42, 0.47, 0.42), Vector3(0, 0.235, 0))
		"crate":
			_box(Vector3(0.62, 0.62, 0.62), Vector3(0, 0.31, 0))
		"plant_pot":
			_box(Vector3(0.44, 0.9, 0.44), Vector3(0, 0.45, 0))
		"bench":
			_box(Vector3(1.2, 0.48, 0.42), Vector3(0, 0.24, 0))
		"deck_chair":
			_box(Vector3(0.6, 0.5, 1.15), Vector3(0, 0.25, 0))
		"keg":
			_box(Vector3(0.52, 0.72, 0.52), Vector3(0, 0.36, 0))
		"flower_box":
			_box(Vector3(0.82, 0.3, 0.32), Vector3(0, 0.15, 0))
		"perch":
			_box(Vector3(0.1, 1.25, 0.1), Vector3(0, 0.62, 0))
			_use_box(Vector3(0.8, 0.5, 0.4), Vector3(-0.1, 1.0, 0))
		"scarecrow":
			_box(Vector3(0.2, 1.9, 0.2), Vector3(0, 0.95, 0))
			_box(Vector3(1.1, 0.6, 0.3), Vector3(0, 1.3, 0))
		"wheel":
			_box(Vector3(0.3, 1.0, 0.3), Vector3(0, 0.5, 0))
			_use_box(Vector3(1.0, 1.0, 0.4), Vector3(0, 1.05, 0.15))
		"flag":
			_box(Vector3(0.12, 3.0, 0.12), Vector3(0, 1.5, 0))
		"bell":
			_box(Vector3(0.14, 2.0, 0.14), Vector3(-0.2, 1.0, 0))
			_use_box(Vector3(0.5, 1.2, 0.5), Vector3(0.2, 1.5, 0))


## The bell rings, the wheel turns.
func use_decor() -> void:
	if not _moving:
		return
	var tw := create_tween()
	if kind == "bell":
		Sfx.play("ready", 0.0, 0.1)
		tw.tween_property(_moving, "rotation:z", 0.5, 0.15)
		tw.tween_property(_moving, "rotation:z", -0.35, 0.3)
		tw.tween_property(_moving, "rotation:z", 0.15, 0.25)
		tw.tween_property(_moving, "rotation:z", 0.0, 0.2)
	else:
		Sfx.play("reel", -6.0)
		tw.tween_property(_moving, "rotation:z", _moving.rotation.z + TAU * 0.75, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


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


## Door swing; lantern light fading on/off; a trap's next fish; the flag in the wind.
func tick(delta: float, lamps_on: bool) -> void:
	_t += delta
	if kind == "perch":
		_moving.visible = fish > 0
	if kind == "flag":
		_moving.rotation.y = sin(_t * 1.7) * 0.25 + sin(_t * 4.3) * 0.06
		_moving.scale.x = 0.94 + 0.06 * sin(_t * 3.1)
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
		var flicker := (0.85 + 0.15 * sin(_t * 17.0) + 0.08 * sin(_t * 31.0)) if kind in ["torch", "candle", "fire_pit"] else 1.0
		if kind == "fire_pit":
			_glow.scale = Vector3(1.0, flicker, 1.0)
		_light.light_energy = float(lc["energy"]) * _lit * flicker
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
	var k: Array = [key.x, key.y, key.z, key.w] if key is Vector4i or key is Vector4 else [key.x, key.y, key.z]
	return {"kind": kind, "key": k, "dir": dir, "open": is_open, "fish": fish}


## Nets and doors: the use button.
func prompt(_inv: Inventory) -> Dictionary:
	if kind == "door":
		return {"text": "Закрыть" if is_open else "Открыть", "ok": true, "icon": "door"}
	if kind == "trap":
		return {"text": "Достать рыбу (%d)" % fish if fish > 0 else "Пока пусто", "ok": fish > 0, "icon": "fish"}
	if kind == "bell":
		return {"text": "Позвонить", "ok": true, "icon": "bell"}
	if kind == "wheel":
		return {"text": "Покрутить", "ok": true, "icon": "wheel"}
	if kind == "perch":
		var cap := int(Data.b["pet"]["bowl"])
		return {"text": "Насыпать корм (%d/%d)" % [fish, cap], "ok": fish < cap, "icon": "banana"}
	if kind == "hammock":
		var dn: DayNight = get_parent().daynight
		return {"text": "Спать", "ok": dn != null and dn.is_night(), "icon": "hammock"}
	var text := "Собрать (%d/%d)" % [caught.size(), capacity] if not caught.is_empty() else "Пусто (0/%d)" % capacity
	return {"text": text, "ok": not caught.is_empty(), "icon": kind}
