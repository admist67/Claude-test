class_name Station
extends StaticBody3D
## A station on a raft tile. The purifier boils seawater into a cup of fresh water, the
## grill cooks fish and meat, the planter grows seeds into pineapples. Fuel (leaves,
## planks) burns only while something cooks; the result waits until the player takes it.
## The rain collector fills by itself (much faster in a storm) and holds a few cups.
## The anchor's winch drops and raises the anchor (stored = 1 while it holds the raft).
## The purifier boils a bucket of seawater; a chest keeps items (`items`). The drying rack
## turns raw fish into dried fish without fire. The sail is raised and lowered (stored = 1
## while it is up). The big grill cooks up to three of a kind at once (data "batch").

signal finished(station: Station)

static var rain := 0.0            # storm intensity, set by the game; speeds up collectors

var kind := ""
var cell := Vector3i.ZERO         # x, z, level
var def: Dictionary
var fuel := 0.0             # seconds of fire left
var cooking := ""           # item being cooked; "seawater" in the purifier
var progress := 0.0
var ready_item := ""
var amount := 1                   # how many cook at once (the big grill: up to 3)
var stored := 0                    # collector: cups of rain water inside; anchor: 1 = down
var items: Dictionary = {}         # chest: item id -> count
var _fire: Node3D
var _light: OmniLight3D
var _steam: CPUParticles3D
var _food: MeshInstance3D
var _more: Array[MeshInstance3D] = []   # the big grill's other two places on the grate
var _crop: Node3D
var _water: MeshInstance3D
var _rope: MeshInstance3D
var _lid: Node3D
var _cloth: MeshInstance3D
var _t := 0.0


func setup(k: String, c: Vector3i, d: Dictionary) -> void:
	kind = k
	cell = c
	def = d
	var body := MeshInstance3D.new()
	add_child(body)
	if kind == "chest":
		var parts := IslandLooks.chest()
		body.mesh = parts[0]
		_lid = Node3D.new()
		_lid.position = Vector3(0, 0.45, -0.3)
		var lm := MeshInstance3D.new()
		lm.mesh = parts[1]
		_lid.add_child(lm)
		add_child(_lid)
	else:
		body.mesh = Looks.mesh(kind)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	var tall := kind in ["grill", "purifier"]
	shape.size = Vector3(0.9, 1.0, 0.68) if tall else Vector3(0.8, 0.8, 0.65)
	if kind == "big_grill":
		shape.size = Vector3(1.3, 1.0, 0.75)
	cs.shape = shape
	cs.position.y = shape.size.y / 2.0
	add_child(cs)
	_fire = _make_fire()
	_fire.position = Vector3(0, 0.1, 0.3) if kind == "purifier" else Vector3(0, 0.56, 0.27)
	if kind == "big_grill":
		_fire.position = Vector3(0, 0.5, 0.2)
		_fire.scale = Vector3(2.6, 1.0, 1.0)
	add_child(_fire)
	_light = OmniLight3D.new()
	_light.light_color = Color("#ff9a4a")
	_light.omni_range = 3.5
	_light.position = Vector3(0, 0.3, 0.5) if kind == "purifier" else Vector3(0, 0.75, 0.5)
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
		_steam.position = Vector3(0, 0.98, 0)
		_steam.emitting = false
		add_child(_steam)
	_food = MeshInstance3D.new()
	_food.position = Vector3(0, 0.93, 0) if is_grill() else Vector3(0.44, 0.47, 0.06)
	add_child(_food)
	if kind == "big_grill":
		_food.position = Vector3(0, 0.97, 0.02)
		for x: float in [-0.38, 0.38]:
			var m := MeshInstance3D.new()
			m.position = Vector3(x, 0.97, 0.02)
			add_child(m)
			_more.append(m)
	if kind == "collector":
		_water = MeshInstance3D.new()
		var wm := CylinderMesh.new()
		wm.top_radius = 0.29
		wm.bottom_radius = 0.29
		wm.height = 0.02
		wm.material = Mk.mat(Color("#3f8fc0"), 0.1)
		_water.mesh = wm
		add_child(_water)
	if kind == "anchor":
		_rope = MeshInstance3D.new()
		_rope.mesh = Looks.mesh("anchor_rope")
		_rope.position = Vector3(0, 0.5, 0.5)
		add_child(_rope)
	if kind == "planter":
		_food.position = Vector3(0, 0.3, 0)
		_crop = Node3D.new()
		add_child(_crop)
	if kind == "rack":
		_food.position = Vector3(0, 0.98, 0)
	if kind == "sail":
		_cloth = MeshInstance3D.new()
		_cloth.mesh = Looks.mesh("sail_cloth")
		_cloth.position = Vector3(0, GearLooks.YARD, 0)
		_cloth.scale = Vector3(1.0, 0.06, 0.06)
		add_child(_cloth)
	_refresh()


## The ripe crop on the planter: two of what grew.
func _grow_crop(id: String) -> void:
	for c in _crop.get_children():
		c.queue_free()
	_crop.set_meta("fruit", id)
	for i in 2:
		var fruit := Looks.held(id)
		fruit.scale = Vector3.ONE * 2.2
		fruit.position = Vector3(-0.22 + i * 0.44, 0.36, 0.1 - i * 0.2)
		_crop.add_child(fruit)


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


func is_grill() -> bool:
	return kind in ["grill", "big_grill"]


## A gull ate what grows here: the seedling or the ripe fruit is gone.
func pecked() -> void:
	cooking = ""
	ready_item = ""
	progress = 0.0
	_refresh()


## Something grows on this planter (a gull would like it).
func has_crop() -> bool:
	return kind == "planter" and (cooking != "" or ready_item != "")


func _process(delta: float) -> void:
	_t += delta
	if kind == "sail":
		# Unfurls down from the yard and fills with wind; furls back up.
		var k := move_toward(_cloth.scale.y, 1.0 if stored == 1 else 0.06, delta * 1.4)
		_cloth.scale = Vector3(1.0, k, k * (1.0 + 0.1 * sin(_t * 2.1) + 0.04 * sin(_t * 5.3)))
		return
	if kind in ["anchor", "chest"]:
		return
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


## Grill and planter, idle: the player picks what goes in (see choices()).
func wants_choice() -> bool:
	return kind in ["grill", "big_grill", "planter", "rack"] and cooking == "" and ready_item == ""


## What can go in now: [{"id", "count", "out", "out_n"}] for the items the player has.
func choices(inv: Inventory) -> Array:
	var out: Array = []
	for id: String in _table():
		if inv.count(id) > 0:
			var n := mini(inv.count(id), int(def.get("batch", 1)))
			out.append({"id": id, "count": inv.count(id), "out": _table()[id], "out_n": int(def.get("count", 1)) * n})
	return out


## The chest, the anchor, the collector and a purifier waiting for water; {} otherwise.
func _special_prompt(inv: Inventory) -> Dictionary:
	match kind:
		"chest":
			var n := 0
			for id: String in items:
				n += int(items[id])
			return {"text": "Открыть сундук" + (" (%d)" % n if n > 0 else ""), "ok": true, "icon": "chest"}
		"anchor":
			return {"text": "Поднять якорь" if stored == 1 else "Бросить якорь", "ok": true, "icon": "anchor"}
		"sail":
			return {"text": "Спустить парус" if stored == 1 else "Поднять парус", "ok": true, "icon": "sail"}
		"collector":
			if stored > 0:
				return {"text": "Набрать (%d)" % stored, "ok": true, "icon": "cup_water"}
			return {"text": "%d%%" % int(progress / float(def["time"]) * 100.0), "ok": false, "icon": "collector"}
		"purifier":
			if cooking == "" and ready_item == "" and inv.count("bucket_water") == 0:
				return {"text": "Нужно ведро воды", "ok": false, "icon": "bucket"}
	return {}


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
	var special := _special_prompt(inv)
	if not special.is_empty():
		return special
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
	var verbs := {"purifier": "Залить воду", "grill": "Жарить", "big_grill": "Жарить", "planter": "Посадить", "rack": "Сушить"}
	return {"text": verbs[kind], "ok": ok, "icon": raw if kind == "planter" else ("bucket_water" if kind == "purifier" else kind)}


## Does what prompt() says. Returns [message, item taken or ""].
func interact(inv: Inventory) -> Array:
	if kind == "anchor":
		stored = 1 - stored
		_refresh()
		Sfx.play("splash" if stored == 1 else "reel", -4.0)
		return ["Якорь брошен — плот стоит на месте" if stored == 1 else "Якорь поднят — плывём дальше", ""]
	if kind == "sail":
		stored = 1 - stored
		Sfx.play("flap", -2.0)
		return ["Парус поднят — острова будут попадаться чаще" if stored == 1 else "Парус спущен", ""]
	if kind == "collector":
		return _take_rain(inv)
	if ready_item != "":
		var got := ready_item
		var n := int(def.get("count", 1)) * amount
		inv.add(got, n)
		ready_item = ""
		amount = 1
		_refresh()
		return ["+%d %s" % [n, Data.item_name(got)], got]
	if cooking != "":
		return [_feed_fire(inv), ""]
	var raw := "seawater" if kind == "purifier" else _raw_in(inv)
	if raw == "":
		var need := {"planter": "Нужны семена — ищи в бочках", "rack": "Нужна сырая рыба"}
		return [need.get(kind, "Нужна сырая рыба или мясо"), ""]
	return start(inv, raw)


## Puts `raw` in (seawater for the purifier) and lights the fire. Returns [message, ""].
func start(inv: Inventory, raw: String) -> Array:
	if raw == "seawater" and inv.count("bucket_water") == 0:
		return ["Набери ведром морской воды (с края плота) и залей сюда", ""]
	if raw != "seawater" and inv.count(raw) == 0:
		return ["Нет: " + Data.item_name(raw), ""]
	if needs_fuel() and fuel <= 0.0 and not _add_fuel(inv):
		return ["Нужно топливо: лист или доска", ""]
	if raw != "seawater":
		amount = mini(inv.count(raw), int(def.get("batch", 1)))
		inv.remove(raw, amount)
	else:
		inv.add("bucket")              # the water goes in, the empty bucket back to the hand
		inv.remove("bucket_water")
	cooking = raw
	progress = 0.0
	_refresh()
	if kind == "planter":
		Sfx.play("craft", -6.0)
		return ["Семена посажены", ""]
	if kind == "rack":
		Sfx.play("craft", -6.0)
		return ["Сушится: " + Data.item_name(raw), ""]
	Sfx.play("ignite", -6.0)
	if kind == "purifier":
		return ["Вода закипает…", ""]
	return ["На гриле: " + Data.item_name(raw) + (" ×%d" % amount if amount > 1 else ""), ""]


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


## The chest's lid while its panel is open.
func open_lid(open: bool) -> void:
	if _lid:
		create_tween().tween_property(_lid, "rotation:x", -1.9 if open else 0.0, 0.3)


func _refresh() -> void:
	if kind == "chest":
		return
	if kind == "anchor":
		_rope.visible = stored == 1
		return
	if kind in ["collector", "sail"]:
		return
	if kind == "planter":
		_food.visible = cooking != "" or ready_item != ""
		_food.mesh = Looks.mesh("sprout")
		_food.scale = Vector3.ONE * (1.2 if ready_item != "" else 0.3 + 0.9 * progress / float(def["time"]))
		_crop.visible = ready_item != ""
		if ready_item != "" and _crop.get_meta("fruit", "") != ready_item:
			_grow_crop(ready_item)
		return
	var show := ready_item if ready_item != "" else (cooking if cooking != "seawater" else "")
	var top := 0.97 if kind == "big_grill" else 0.93
	for i in _more.size() + 1:
		var f: MeshInstance3D = _food if i == 0 else _more[i - 1]
		f.visible = show != "" and i < amount
		if f.visible:
			f.mesh = Looks.mesh(show)
			f.rotation.y = 0.3 if kind != "big_grill" else PI / 2.0 + 0.15 * (i - 1)
			# Fish lie on their side on the grate.
			var flat := is_grill() and "fish" in show
			f.rotation.x = -PI / 2.0 if flat else 0.0
			f.rotation.z = -PI / 2.0 if kind == "rack" else 0.0     # hangs nose down
			if is_grill():
				f.position.y = top + (0.02 if flat else 0.0)


func to_dict() -> Dictionary:
	return {"kind": kind, "cell": [cell.x, cell.y, cell.z], "fuel": fuel, "cooking": cooking, "progress": progress, "ready": ready_item, "stored": stored,
		"items": items, "amount": amount}


func load_state(d: Dictionary) -> void:
	fuel = float(d.get("fuel", 0.0))
	cooking = d.get("cooking", "")
	progress = float(d.get("progress", 0.0))
	ready_item = d.get("ready", "")
	stored = int(d.get("stored", 0))
	amount = int(d.get("amount", 1))
	items.clear()
	var it: Dictionary = d.get("items", {})
	for id: String in it:
		items[id] = int(it[id])
	_refresh()
