class_name Station
extends StaticBody3D
## A station on a raft tile. The purifier boils seawater into a cup of fresh water, the
## grill cooks fish and meat, the planter grows seeds into pineapples. Fuel (leaves,
## planks) burns only while something cooks; the result waits until the player takes it.
## The rain collector fills by itself (much faster in a storm) and holds a few cups.

signal finished(station: Station)

static var rain := 0.0            # storm intensity, set by the game; speeds up collectors

var kind := ""
var cell := Vector3i.ZERO         # x, z, level
var def: Dictionary
var fuel := 0.0             # seconds of fire left
var cooking := ""           # item being cooked; "seawater" in the purifier
var progress := 0.0
var ready_item := ""
var stored := 0                    # collector: cups of rain water inside
var _fire: Node3D
var _light: OmniLight3D
var _steam: CPUParticles3D
var _food: MeshInstance3D
var _crop: Node3D
var _water: MeshInstance3D
var _t := 0.0


func setup(k: String, c: Vector3i, d: Dictionary) -> void:
	kind = k
	cell = c
	def = d
	var body := MeshInstance3D.new()
	body.mesh = Looks.mesh(kind)
	add_child(body)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 0.8, 0.65)
	cs.shape = shape
	cs.position.y = 0.4
	add_child(cs)
	_fire = _make_fire()
	_fire.position = Vector3(0, 0.08, 0.3 if kind == "purifier" else 0.29)
	add_child(_fire)
	_light = OmniLight3D.new()
	_light.light_color = Color("#ff9a4a")
	_light.omni_range = 3.5
	_light.position = Vector3(0, 0.3, 0.45)
	add_child(_light)
	_fire.visible = false
	_light.visible = false
	if kind == "purifier":
		_steam = CPUParticles3D.new()
		var m := QuadMesh.new()
		m.size = Vector2(0.12, 0.12)
		var sm := StandardMaterial3D.new()
		var puff := GradientTexture2D.new()
		puff.fill = GradientTexture2D.FILL_RADIAL
		puff.fill_from = Vector2(0.5, 0.5)
		puff.fill_to = Vector2(0.5, 0.0)
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.0)])
		puff.gradient = g
		sm.albedo_texture = puff
		sm.albedo_color = Color(1, 1, 1, 0.5)
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.material = sm
		_steam.mesh = m
		_steam.amount = 10
		_steam.lifetime = 1.6
		_steam.direction = Vector3.UP
		_steam.spread = 12.0
		_steam.gravity = Vector3(0, 0.25, 0)
		_steam.initial_velocity_min = 0.2
		_steam.initial_velocity_max = 0.4
		_steam.scale_amount_max = 2.0
		_steam.position = Vector3(0.38, 0.7, 0)
		_steam.emitting = false
		add_child(_steam)
	_food = MeshInstance3D.new()
	_food.position = Vector3(0, 0.47, 0) if kind == "grill" else Vector3(0.3, 0.37, 0.2)
	add_child(_food)
	if kind == "collector":
		_water = MeshInstance3D.new()
		var wm := CylinderMesh.new()
		wm.top_radius = 0.29
		wm.bottom_radius = 0.29
		wm.height = 0.02
		wm.material = Mk.mat(Color("#3f8fc0"), 0.1)
		_water.mesh = wm
		add_child(_water)
	if kind == "planter":
		_food.position = Vector3(0, 0.3, 0)
		_crop = Node3D.new()
		for i in 2:
			var fruit := Looks.held("pineapple")
			fruit.scale = Vector3.ONE * 2.2
			fruit.position = Vector3(-0.22 + i * 0.44, 0.36, 0.1 - i * 0.2)
			_crop.add_child(fruit)
		add_child(_crop)
	_refresh()


func _make_fire() -> Node3D:
	var root := Node3D.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#ffb347")
	m.emission_enabled = true
	m.emission = Color("#ff7a1a")
	m.emission_energy_multiplier = 2.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 3:
		var q := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.09, 0.16, 0.02)
		q.mesh = pm
		q.material_override = m
		q.position = Vector3((i - 1) * 0.07, 0.07, 0)
		q.rotation.y = i * 0.9
		root.add_child(q)
	return root


func busy() -> bool:
	return cooking != ""


func _process(delta: float) -> void:
	_t += delta
	if kind == "collector":
		_collect_rain(delta)
		return
	if cooking != "" and (fuel > 0.0 or not needs_fuel()):
		if needs_fuel():
			fuel = maxf(0.0, fuel - delta)
		progress += delta
		if kind == "planter":
			_food.scale = Vector3.ONE * (0.3 + 0.9 * progress / float(def["time"]))
		if progress >= float(def["time"]):
			ready_item = _output(cooking)
			cooking = ""
			progress = 0.0
			_refresh()
			Sfx.play("ready", -6.0)
			Events.toast.emit("Готово: " + Data.item_name(ready_item), ready_item)
			finished.emit(self)
	var lit := cooking != "" and fuel > 0.0 and needs_fuel()
	_fire.visible = lit
	_light.visible = lit
	if lit:
		var f := 0.8 + 0.2 * sin(_t * 17.0) + 0.1 * sin(_t * 29.0)
		_fire.scale = Vector3(1.0, f, 1.0)
		_light.light_energy = 0.9 * f
	if _steam:
		_steam.emitting = lit


func _collect_rain(delta: float) -> void:
	var cap := int(def["capacity"])
	if stored < cap:
		progress += delta * lerpf(1.0, float(def["storm_rate"]), rain)
		if progress >= float(def["time"]):
			progress = 0.0
			stored += 1
	var fill := (stored + (progress / float(def["time"]) if stored < cap else 0.0)) / float(cap)
	_water.position.y = 0.12 + 0.6 * fill
	_water.visible = fill > 0.01


func needs_fuel() -> bool:
	return def.has("fuel")


## What goes in → what comes out: grill "cook", planter "grow".
func _table() -> Dictionary:
	return def.get("cook", def.get("grow", {}))


func _output(input: String) -> String:
	if kind == "purifier":
		return def["out"]
	return _table().get(input, "")


func _raw_in(inv: Inventory) -> String:
	for id: String in _table():
		if inv.count(id) > 0:
			return id
	return ""


func _fuel_in(inv: Inventory) -> String:
	for id: String in def["fuel"]:
		if inv.count(id) > 0:
			return id
	return ""


## What the use button says right now: {"text", "ok"}.
func prompt(inv: Inventory) -> Dictionary:
	if kind == "collector":
		if stored > 0:
			return {"text": "Набрать (%d)" % stored, "ok": true, "icon": "cup_water"}
		return {"text": "%d%%" % int(progress / float(def["time"]) * 100.0), "ok": false, "icon": "collector"}
	if ready_item != "":
		return {"text": "Забрать", "ok": true, "icon": ready_item}
	if cooking != "":
		if needs_fuel() and fuel <= 0.0:
			return {"text": "Подбросить", "ok": _fuel_in(inv) != "", "icon": "leaf"}
		return {"text": "%d%%" % int(progress / float(def["time"]) * 100.0), "ok": false, "icon": kind}
	var raw := "seawater" if kind == "purifier" else _raw_in(inv)
	if raw == "":
		return {"text": "Нет семян" if kind == "planter" else "Нет рыбы", "ok": false, "icon": "seeds" if kind == "planter" else "fish"}
	var ok := not needs_fuel() or fuel > 0.0 or _fuel_in(inv) != ""
	var verbs := {"purifier": "Кипятить", "grill": "Жарить", "planter": "Посадить"}
	return {"text": verbs[kind], "ok": ok, "icon": raw if kind == "planter" else kind}


## Does what prompt() says. Returns [message, item taken or ""].
func interact(inv: Inventory) -> Array:
	if kind == "collector":
		return _take_rain(inv)
	if ready_item != "":
		var got := ready_item
		var n := int(def.get("count", 1))
		inv.add(got, n)
		ready_item = ""
		_refresh()
		return ["+%d %s" % [n, Data.item_name(got)], got]
	if cooking != "":
		return [_feed_fire(inv), ""]
	var raw := "seawater" if kind == "purifier" else _raw_in(inv)
	if raw == "":
		return ["Нужны семена — ищи в бочках" if kind == "planter" else "Нужна сырая рыба или мясо", ""]
	if needs_fuel() and fuel <= 0.0 and not _add_fuel(inv):
		return ["Нужно топливо: лист или доска", ""]
	if raw != "seawater":
		inv.remove(raw)
	cooking = raw
	progress = 0.0
	_refresh()
	if kind == "planter":
		Sfx.play("craft", -6.0)
		return ["Семена посажены", ""]
	Sfx.play("ignite", -6.0)
	return ["Вода закипает…" if kind == "purifier" else "На гриле: " + Data.item_name(raw), ""]


func _take_rain(inv: Inventory) -> Array:
	if stored == 0:
		return ["Бочка ещё набирает дождевую воду", ""]
	var n := stored
	stored = 0
	inv.add(def.get("out", "cup_water"), n)
	return ["+%d Пресная вода" % n, "cup_water"]


## While cooking: throw on more fuel if the fire went out.
func _feed_fire(inv: Inventory) -> String:
	if not needs_fuel() or fuel > 0.0:
		return "Ещё готовится…"
	return "Подброшено топливо" if _add_fuel(inv) else "Нужно топливо: лист или доска"


func _add_fuel(inv: Inventory) -> bool:
	var id := _fuel_in(inv)
	if id == "" or not inv.remove(id):
		return false
	fuel += float(def["fuel"][id])
	return true


func _refresh() -> void:
	if kind == "collector":
		return
	if kind == "planter":
		_food.visible = cooking != "" or ready_item != ""
		_food.mesh = Looks.mesh("sprout")
		_food.scale = Vector3.ONE * (1.2 if ready_item != "" else 0.3 + 0.9 * progress / float(def["time"]))
		_crop.visible = ready_item != ""
		return
	var show := ready_item if ready_item != "" else (cooking if cooking != "seawater" else "")
	_food.visible = show != ""
	if show != "":
		_food.mesh = Looks.mesh(show)
		_food.rotation.y = 0.3


func to_dict() -> Dictionary:
	return {"kind": kind, "cell": [cell.x, cell.y, cell.z], "fuel": fuel, "cooking": cooking, "progress": progress, "ready": ready_item, "stored": stored}


func load_state(d: Dictionary) -> void:
	fuel = float(d.get("fuel", 0.0))
	cooking = d.get("cooking", "")
	progress = float(d.get("progress", 0.0))
	ready_item = d.get("ready", "")
	stored = int(d.get("stored", 0))
	_refresh()
