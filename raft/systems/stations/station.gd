class_name Station
extends StaticBody3D
## A cooking station on a raft tile. The purifier boils seawater into a cup of fresh
## water, the grill cooks fish. Fuel (leaves, planks) burns only while something cooks;
## the result waits on the station until the player takes it.

signal finished(station: Station)

var kind := ""
var cell := Vector2i.ZERO
var def: Dictionary
var fuel := 0.0             # seconds of fire left
var cooking := ""           # item being cooked; "seawater" in the purifier
var progress := 0.0
var ready_item := ""
var _fire: Node3D
var _light: OmniLight3D
var _steam: CPUParticles3D
var _food: MeshInstance3D
var _t := 0.0


func setup(k: String, c: Vector2i, d: Dictionary) -> void:
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
	if cooking != "" and fuel > 0.0:
		fuel = maxf(0.0, fuel - delta)
		progress += delta
		if progress >= float(def["time"]):
			ready_item = _output(cooking)
			cooking = ""
			progress = 0.0
			_refresh()
			Sfx.play("ready", -6.0)
			Events.toast.emit("Готово: " + Data.item_name(ready_item), ready_item)
			finished.emit(self)
	var lit := cooking != "" and fuel > 0.0
	_fire.visible = lit
	_light.visible = lit
	if lit:
		var f := 0.8 + 0.2 * sin(_t * 17.0) + 0.1 * sin(_t * 29.0)
		_fire.scale = Vector3(1.0, f, 1.0)
		_light.light_energy = 0.9 * f
	if _steam:
		_steam.emitting = lit


func _output(input: String) -> String:
	if kind == "purifier":
		return def["out"]
	return def["cook"].get(input, "")


func _raw_in(inv: Inventory) -> String:
	for id: String in def.get("cook", {}):
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
	if ready_item != "":
		return {"text": "Забрать", "ok": true, "icon": ready_item}
	if cooking != "":
		if fuel <= 0.0:
			return {"text": "Подбросить", "ok": _fuel_in(inv) != "", "icon": "leaf"}
		return {"text": "%d%%" % int(progress / float(def["time"]) * 100.0), "ok": false, "icon": kind}
	var raw := "seawater" if kind == "purifier" else _raw_in(inv)
	if raw == "":
		return {"text": "Нет рыбы", "ok": false, "icon": "fish"}
	var ok := fuel > 0.0 or _fuel_in(inv) != ""
	return {"text": "Кипятить" if kind == "purifier" else "Жарить", "ok": ok, "icon": kind}


## Does what prompt() says. Returns [message, item taken or ""].
func interact(inv: Inventory) -> Array:
	if ready_item != "":
		var got := ready_item
		inv.add(got)
		ready_item = ""
		_refresh()
		return ["+1 " + Data.item_name(got), got]
	if cooking != "":
		if fuel <= 0.0:
			return ["Подброшено топливо" if _add_fuel(inv) else "Нужно топливо: лист или доска", ""]
		return ["Ещё готовится…", ""]
	var raw := "seawater" if kind == "purifier" else _raw_in(inv)
	if raw == "":
		return ["Нужна сырая рыба — поймай удочкой", ""]
	if fuel <= 0.0 and not _add_fuel(inv):
		return ["Нужно топливо: лист или доска", ""]
	if raw != "seawater":
		inv.remove(raw)
	cooking = raw
	progress = 0.0
	_refresh()
	Sfx.play("ignite", -6.0)
	return ["Вода закипает…" if kind == "purifier" else "Рыба на гриле", ""]


func _add_fuel(inv: Inventory) -> bool:
	var id := _fuel_in(inv)
	if id == "" or not inv.remove(id):
		return false
	fuel += float(def["fuel"][id])
	return true


func _refresh() -> void:
	var show := ready_item if ready_item != "" else (cooking if cooking != "seawater" else "")
	_food.visible = show != ""
	if show != "":
		_food.mesh = Looks.mesh(show)
		_food.rotation.y = 0.3


func to_dict() -> Dictionary:
	return {"kind": kind, "cell": [cell.x, cell.y], "fuel": fuel, "cooking": cooking, "progress": progress, "ready": ready_item}


func load_state(d: Dictionary) -> void:
	fuel = float(d.get("fuel", 0.0))
	cooking = d.get("cooking", "")
	progress = float(d.get("progress", 0.0))
	ready_item = d.get("ready", "")
	_refresh()
