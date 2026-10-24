extends Node3D
## Game root: builds the world, wires input and UI to the systems, runs survival,
## goals and saves. Mechanics live in systems/, drawing in ui/ and view/.

enum Mode { MENU, PLAY, BAG, PAUSE, DEAD }

const START_TILES: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]

var mode := Mode.MENU
var vitals := Vitals.new()
var inv := Inventory.new()
var stats: Dictionary = {}
var goal_i := 0
var played := 0.0
var hotbar: Array[String] = []
var sel := 0
var grab_target: Debris
var station_target: Station
var rng := RandomNumberGenerator.new()

var ocean: Ocean
var daynight: DayNight
var raft: Raft
var player: Player
var hook: Hook
var rod: Rod
var shark: Shark
var field: DebrisField
var builder: Builder
var touch: TouchControls
var hud: Hud
var bag: CraftPanel
var menus: Menus
var menu_cam: Camera3D
var _save_t := 0.0
var _menu_t := 0.0
var _reel_t := 0.0


func _ready() -> void:
	rng.randomize()
	_build_world()
	_build_ui()
	inv.changed.connect(_refresh_hotbar)
	_new_state()
	_to_menu()


# ---------------------------------------------------------------- world and UI

func _build_world() -> void:
	var env := Environment.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://systems/world/sky.gdshader")
	sky_mat.set_shader_parameter("noise_tex", load("res://assets/textures/noise.png"))
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9cc4d4")
	env.ambient_light_energy = 0.45
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("#a6dcec")
	env.fog_depth_begin = 22.0
	env.fog_depth_end = 72.0
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(-35.0), 0.0)
	sun.light_color = Color("#fff3dc")
	sun.light_energy = 0.62
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 28.0
	add_child(sun)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("#9fb4ff")
	add_child(moon)

	ocean = Ocean.new()
	add_child(ocean)
	daynight = DayNight.new()
	daynight.sun = sun
	daynight.moon = moon
	daynight.env = env
	daynight.sky_mat = sky_mat
	daynight.ocean = ocean
	add_child(daynight)
	raft = Raft.new()
	add_child(raft)
	player = Player.new()
	player.raft = raft
	raft.add_child(player)
	field = DebrisField.new()
	field.raft = raft
	add_child(field)
	hook = Hook.new()
	hook.player = player
	hook.field = field
	add_child(hook)
	hook.splashed.connect(_on_splash)
	hook.delivered.connect(_on_delivered)
	rod = Rod.new()
	rod.player = player
	add_child(rod)
	rod.splashed.connect(_on_splash)
	rod.caught.connect(_on_fish)
	rod.missed.connect(func(text: String) -> void:
		hud.toast(text, "fish")
		Sfx.play("build_fail", -10.0)
	)
	shark = Shark.new()
	shark.raft = raft
	shark.daynight = daynight
	add_child(shark)
	shark.attacked.connect(_on_shark_attack)
	shark.bit.connect(_on_shark_bite)
	shark.hurt.connect(func(_left: int) -> void:
		Sfx.play("shark_hit")
		_burst(shark.global_position + Vector3(0, 0.3, 0), Color("#b8231d"), 22)
	)
	shark.fled.connect(func() -> void:
		stats["shark_driven"] = int(stats.get("shark_driven", 0)) + 1
		hud.toast("Акула уплыла зализывать раны", "spear")
		_check_goals()
	)
	shark.died.connect(_on_shark_died)
	daynight.new_day.connect(func(d: int) -> void:
		hud.toast("Наступил день %d" % d, "sun")
		_check_goals()
	)
	builder = Builder.new()
	builder.raft = raft
	builder.player = player
	builder.inv = inv
	add_child(builder)
	menu_cam = Camera3D.new()
	menu_cam.fov = 60.0
	menu_cam.far = 160.0
	add_child(menu_cam)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	hud = Hud.new()
	hud.game = self
	layer.add_child(hud)
	touch = TouchControls.new()
	layer.add_child(touch)
	hud.touch = touch
	touch.pressed.connect(_on_pressed)
	touch.released.connect(_on_released)
	touch.looked.connect(func(rel: Vector2) -> void: player.look(rel))
	bag = CraftPanel.new()
	bag.inv = inv
	bag.visible = false
	layer.add_child(bag)
	bag.craft_requested.connect(_craft)
	bag.closed.connect(_close_bag)
	menus = Menus.new()
	layer.add_child(menus)
	menus.new_game.connect(func() -> void:
		SaveGame.clear()
		_new_state()
		_start()
	)
	menus.continue_game.connect(func() -> void:
		_apply_save(SaveGame.read())
		_start()
	)
	menus.resume.connect(_resume)
	menus.to_menu.connect(func() -> void:
		_save()
		get_tree().paused = false
		_to_menu()
	)
	menus.respawn.connect(_respawn)
	Events.toast.connect(func(text: String, icon: String) -> void: hud.toast(text, icon))


# ---------------------------------------------------------------- state

func _new_state() -> void:
	raft.clear()
	for c in START_TILES:
		raft.add_tile(c)
	vitals = Vitals.new()
	inv.from_dict({"hook": 1})
	stats = {}
	goal_i = 0
	played = 0.0
	sel = 0
	daynight.phase = float(Data.b["day"]["start_phase"])
	daynight.day = 1
	shark.reset(float(Data.b["shark"]["first_delay"]))
	player.place(raft.centroid())
	_reset_sea()


func _reset_sea() -> void:
	hook.cancel()
	rod.cancel()
	field.clear_all()
	field.prefill()


func _state() -> Dictionary:
	var p := player.position
	return {
		"tiles": SaveGame.cells_to_json(raft.cells()),
		"inv": inv.to_dict(),
		"vitals": vitals.to_dict(),
		"stats": stats,
		"goal": goal_i,
		"played": played,
		"pos": [p.x, p.y, p.z],
		"yaw": player.yaw,
		"stations": raft.stations.values().map(func(st: Station) -> Dictionary: return st.to_dict()),
		"phase": daynight.phase,
		"hp": raft.hp.keys().map(func(c: Vector2i) -> Array: return [c.x, c.y, raft.hp[c]]),
		"day": daynight.day,
	}


func _apply_save(d: Dictionary) -> void:
	if d.is_empty():
		_new_state()
		return
	raft.clear()
	for c in SaveGame.cells_from_json(d["tiles"]):
		raft.add_tile(c)
	for sd: Dictionary in d.get("stations", []):
		if Data.build_by_id.has(sd["kind"]):
			var c := Vector2i(int(sd["cell"][0]), int(sd["cell"][1]))
			if raft.has_tile(c):
				raft.add_station(sd["kind"], c, Data.build_by_id[sd["kind"]]).load_state(sd)
	for e: Array in d.get("hp", []):
		var hc := Vector2i(int(e[0]), int(e[1]))
		if raft.has_tile(hc):
			raft.hp[hc] = int(e[2])
			raft.refresh_tile(hc)
	shark.reset(float(Data.b["shark"]["first_delay"]))
	daynight.phase = float(d.get("phase", Data.b["day"]["start_phase"]))
	daynight.day = int(d.get("day", 1))
	inv.from_dict(d["inv"])
	vitals = Vitals.new()
	vitals.from_dict(d["vitals"])
	stats = d["stats"]
	goal_i = int(d["goal"])
	played = float(d["played"])
	var p: Array = d["pos"]
	var pos := Vector3(p[0], p[1], p[2])
	player.place(pos if raft.on_raft(pos) else raft.nearest_tile(pos), float(d["yaw"]))
	_reset_sea()


func _save() -> void:
	if mode != Mode.MENU:
		SaveGame.write(_state())


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_save()
		if mode == Mode.PLAY and what != NOTIFICATION_WM_CLOSE_REQUEST:
			_pause()


# ---------------------------------------------------------------- modes

## Stops touch input without throwing a half-charged hook.
func _freeze_input() -> void:
	if hook.state == Hook.State.CHARGE:
		hook.cancel()
	if rod.state == Rod.State.CHARGE:
		rod.cancel()
	touch.reset()
	touch.enabled = false


func playing() -> bool:
	return mode == Mode.PLAY


func _to_menu() -> void:
	mode = Mode.MENU
	_freeze_input()
	bag.visible = false
	hook.cancel()
	rod.cancel()
	menu_cam.current = true
	ocean.cam = menu_cam
	menus.has_save = SaveGame.exists()
	menus.show_main()
	Sfx.ambience(true)


func _start() -> void:
	mode = Mode.PLAY
	menus.hide_all()
	player.cam.current = true
	ocean.cam = player.cam
	touch.enabled = true
	touch.reset()
	_refresh_hotbar()
	Sfx.ambience(true)
	_save()


func _pause() -> void:
	if mode != Mode.PLAY:
		return
	mode = Mode.PAUSE
	_freeze_input()
	menus.show_pause()
	get_tree().paused = true


func _resume() -> void:
	get_tree().paused = false
	mode = Mode.PLAY
	menus.hide_all()
	touch.enabled = true


func _open_bag() -> void:
	mode = Mode.BAG
	_freeze_input()
	bag.open()


func _close_bag() -> void:
	bag.visible = false
	mode = Mode.PLAY
	touch.enabled = true


func _die() -> void:
	mode = Mode.DEAD
	_freeze_input()
	bag.visible = false
	hook.cancel()
	rod.cancel()
	Sfx.play("hurt")
	menus.show_death(vitals.cause)


func _respawn() -> void:
	vitals.respawn(Data.b["vitals"])
	inv.lose_share(float(Data.b["vitals"]["death_keep"]), Data.items)
	player.place(raft.nearest_tile(raft.centroid()), player.yaw)
	menus.hide_all()
	mode = Mode.PLAY
	touch.enabled = true
	_save()


# ---------------------------------------------------------------- input → actions

func selected() -> String:
	return hotbar[sel] if sel < hotbar.size() else ""


func _refresh_hotbar() -> void:
	var cur := selected()
	hotbar.clear()
	for id: String in Data.items:
		var k: String = Data.item(id)["kind"]
		if (k == "tool" or k == "food") and inv.count(id) > 0:
			hotbar.append(id)
	sel = maxi(0, hotbar.find(cur))
	touch.set_slots(hotbar.size())
	_apply_selection()


func _select(id: String) -> void:
	var i := hotbar.find(id)
	if i >= 0:
		sel = i
		_apply_selection()


func _apply_selection() -> void:
	var id := selected()
	if id != "hook" and hook.busy():
		hook.cancel()
	if id != "rod" and rod.busy():
		rod.cancel()
	player.hold(id)
	builder.active = id == "hammer"
	touch.set_builds(build_choices().size())


## What the hammer can build (shown above the hotbar while it is selected).
func build_choices() -> Array:
	if selected() != "hammer":
		return []
	return Data.build.map(func(d: Dictionary) -> String: return d["id"])


func _on_pressed(b: String) -> void:
	match b:
		"action":
			_action_down()
		"use":
			_use()
		# Open screens on the next frame: the same tap must not reach their fresh buttons.
		"bag":
			Sfx.play("click", -6.0)
			_open_bag.call_deferred()
		"pause":
			Sfx.play("click", -6.0)
			_pause.call_deferred()
		_:
			if b.begins_with("slot"):
				sel = int(b.substr(4))
				Sfx.play("click", -8.0)
				_apply_selection()
			elif b.begins_with("build"):
				var ids := build_choices()
				var i := int(b.substr(5))
				if i < ids.size():
					builder.kind = ids[i]
					Sfx.play("click", -8.0)


func _on_released(b: String) -> void:
	if b == "action" and selected() == "hook":
		hook.release()
	elif b == "action" and selected() == "rod":
		rod.release()


func _action_down() -> void:
	var id := selected()
	if id == "hook":
		hook.press()
	elif id == "rod":
		rod.press()
	elif id == "spear":
		_stab()
	elif id == "hammer":
		var fixing := builder.repair
		if builder.place():
			player.swing()
			Sfx.play("hammer")
			hud.toast("Клетка починена" if fixing else ("Плот стал больше!" if builder.kind == "tile" else "Построено: " + builder.def()["name"]), "hammer" if fixing else builder.kind)
			_check_goals()
		else:
			Sfx.play("build_fail", -4.0)
			if builder.has_target and builder.valid and not builder.affordable():
				hud.toast("Не хватает материалов", "plank")
			elif not builder.has_target or not builder.valid:
				var water: bool = builder.def()["on"] == "water"
				hud.toast("Посмотри на воду у края плота" if water else "Посмотри на свободную клетку плота", builder.kind)
	elif Data.item(id).get("kind", "") == "food":
		_consume(id)


## The use button: take from / feed a station, or pick up floating debris by hand.
func _use() -> void:
	if station_target:
		var res: Array = station_target.interact(inv)
		var got: String = res[1]
		player.swing()
		if got != "":
			stats["got_" + got] = int(stats.get("got_" + got, 0)) + 1
			if station_target.kind == "grill":
				stats["cooked"] = int(stats.get("cooked", 0)) + 1
			Sfx.play("pop", -2.0)
			hud.toast(res[0], got)
		else:
			Sfx.play("craft" if station_target.busy() else "build_fail", -6.0)
			hud.toast(res[0], station_target.kind)
		_check_goals()
	elif grab_target:
		player.swing()
		_collect(grab_target)


func _stab() -> void:
	player.swing()
	if shark.try_hit(player.cam.global_position, -player.cam.global_basis.z):
		hud.toast("Попал!" if shark.hp > 0 else "Акула повержена!", "spear")
	else:
		Sfx.play("throw", -6.0, 0.2)


func _on_shark_attack(_cell: Vector2i) -> void:
	Sfx.play("warning", -2.0)
	hud.toast("Акула грызёт плот!", "spear")
	if inv.count("spear") == 0 and not stats.has("spear_hint"):
		stats["spear_hint"] = 1
		hud.toast("Сделай копьё в сумке, чтобы отбиться", "spear")


func _on_shark_bite(cell: Vector2i, sank: bool) -> void:
	Sfx.play("bite")
	var p := raft.to_global(raft.cell_center(cell))
	_burst(p, Color("#8a6a48"), 14)
	_on_splash(p)
	Input.vibrate_handheld(120)
	if sank:
		hud.toast("Акула утащила клетку плота!", "tile")
		if not raft.on_raft(player.position):
			player.place(raft.nearest_tile(player.position), player.yaw)
	else:
		hud.toast("Чини молотком: 1 доска", "hammer")


func _on_shark_died(pos: Vector3) -> void:
	stats["shark_kills"] = int(stats.get("shark_kills", 0)) + 1
	for id: String in Data.b["shark"]["drop"]:
		var n := int(Data.b["shark"]["drop"][id])
		inv.add(id, n)
		hud.toast("+%d %s" % [n, Data.item_name(id)], id)
	_burst(pos, Color("#b8231d"), 30)
	Sfx.play("goal")
	_check_goals()


## Small flying chips (wood, blood) at a point.
func _burst(pos: Vector3, col: Color, n: int) -> void:
	var p := CPUParticles3D.new()
	var m := BoxMesh.new()
	m.size = Vector3.ONE * 0.06
	m.material = Mk.mat(col, 0.8)
	p.mesh = m
	p.amount = n
	p.one_shot = true
	p.explosiveness = 0.9
	p.lifetime = 0.9
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -9.8, 0)
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


func _on_fish(id: String) -> void:
	inv.add(id)
	stats["got_" + id] = int(stats.get("got_" + id, 0)) + 1
	stats["fish"] = int(stats.get("fish", 0)) + 1
	Sfx.play("goal", -6.0)
	hud.toast("Поймана: " + Data.item_name(id), id)
	player.swing()
	_check_goals()


func _consume(id: String) -> void:
	if not inv.remove(id):
		return
	var def := Data.item(id)
	vitals.consume(def)
	player.swing()
	var drink := float(def.get("water", 0)) > float(def.get("food", 0))
	Sfx.play("drink" if drink else "eat")
	hud.toast(("Выпито: " if drink else "Съедено: ") + Data.item_name(id), id)


func _craft(r: Dictionary) -> void:
	if not inv.craft(r):
		return
	var id: String = r["id"]
	stats["made_" + id] = int(stats.get("made_" + id, 0)) + 1
	Sfx.play("craft")
	hud.toast("Сделано: " + Data.item_name(id), id)
	Events.crafted.emit(id)
	if Data.item(id)["kind"] == "tool":
		_select(id)
		_close_bag()
	else:
		bag.refresh()
	_check_goals()


func _collect(d: Debris) -> void:
	for e: Array in d.roll_loot(rng):
		var id: String = e[0]
		var n: int = e[1]
		inv.add(id, n)
		stats["got_" + id] = int(stats.get("got_" + id, 0)) + n
		hud.toast("+%d %s" % [n, Data.item_name(id)], id)
	if d.id == "barrel":
		stats["barrels"] = int(stats.get("barrels", 0)) + 1
	Sfx.play("pop", -2.0)
	field.take(d)
	_check_goals()


func _on_delivered(caught: Array) -> void:
	for d: Debris in caught:
		_collect(d)
	if caught.is_empty():
		Sfx.play("snag", -10.0)


func _on_splash(pos: Vector3) -> void:
	Sfx.play("splash", -3.0)
	var p := CPUParticles3D.new()
	var m := BoxMesh.new()
	m.size = Vector3.ONE * 0.07
	m.material = Mk.mat(Color("#f2f6f2"), 0.4)
	p.mesh = m
	p.amount = 18
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.8
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


# ---------------------------------------------------------------- goals

func _stat(name: String) -> int:
	match name:
		"tiles":
			return raft.tiles.size()
		"minutes":
			return int(played / 60.0)
		"days":
			return daynight.day
	if name.begins_with("built_"):
		return raft.count_stations(name.substr(6))
	return int(stats.get(name, 0))


func _check_goals() -> void:
	var goals := Data.goals
	while goal_i < goals.size() and _stat(goals[goal_i]["stat"]) >= int(goals[goal_i]["n"]):
		goal_i += 1
		hud.flash_goal()
		Sfx.play("goal")
		if goal_i >= goals.size():
			hud.toast("Все цели выполнены!", "tile")
			_freeze_input()
			mode = Mode.PAUSE
			menus.show_message("Ты освоился в океане!", "Плот растёт, вода кипит, рыба жарится.\nДальше — акулы, шторм и питомец.", "Играть дальше", _resume)
		else:
			hud.toast("Цель выполнена!", "")


func goal_view() -> Dictionary:
	var goals := Data.goals
	if goal_i >= goals.size():
		return {"text": "Расширяй плот и выживай", "prog": "%d кл." % raft.tiles.size()}
	var g: Dictionary = goals[goal_i]
	return {"text": g["text"], "prog": "%d/%d" % [mini(_stat(g["stat"]), int(g["n"])), int(g["n"])]}


func use_view() -> Dictionary:
	if station_target:
		var p: Dictionary = station_target.prompt(inv)
		var out := {"icon": p["icon"], "label": p["text"], "ok": p["ok"]}
		if station_target.busy() and station_target.fuel > 0.0:
			out["progress"] = station_target.progress / float(station_target.def["time"])
		return out
	return {"icon": "hand", "label": "Взять", "ok": true}


func action_view() -> Dictionary:
	var id := selected()
	var out := {"icon": id, "label": "", "ok": true}
	match id:
		"":
			out = {"icon": "hand", "label": "", "ok": false}
		"hook":
			var labels := {Hook.State.IDLE: "Бросить", Hook.State.CHARGE: "Отпусти!", Hook.State.FLY: "…", Hook.State.WATER: "Тянуть"}
			out["label"] = labels[hook.state]
		"rod":
			var labels := {Rod.State.IDLE: "Забросить", Rod.State.CHARGE: "Отпусти!", Rod.State.FLY: "…", Rod.State.WAIT: "Вытащить", Rod.State.BITE: "Тяни!"}
			out["label"] = labels[rod.state]
		"spear":
			out = {"icon": "spear", "label": "Ударить", "ok": shark.alive_near()}
		"hammer":
			if builder.repair:
				out = {"icon": "hammer", "label": "Чинить", "ok": builder.affordable(), "cost": builder.cost()}
			else:
				out = {"icon": builder.kind, "label": "Строить", "ok": builder.has_target and builder.valid and builder.affordable(), "cost": builder.cost()}
		_:
			var def := Data.item(id)
			out["label"] = "Выпить" if float(def.get("water", 0)) > float(def.get("food", 0)) else "Съесть"
	return out


# ---------------------------------------------------------------- frame

func _process(delta: float) -> void:
	if mode == Mode.MENU:
		_menu_t += delta
		var c := raft.global_transform * raft.centroid()
		var a := _menu_t * 0.12
		menu_cam.global_position = c + Vector3(sin(a) * 9.0, 3.6, cos(a) * 9.0)
		menu_cam.look_at(c + Vector3(0, 0.6, 0))
		return
	if mode == Mode.PLAY or mode == Mode.BAG:
		player.move_input = touch.move if mode == Mode.PLAY else Vector2.ZERO
		played += delta
		if vitals.tick(delta, Data.b["vitals"], float(Data.tune["hunger"])):
			_die()
			return
		var prev_min := int((played - delta) / 60.0)
		if int(played / 60.0) != prev_min:
			_check_goals()
	if mode == Mode.PLAY:
		station_target = _station_in_view()
		grab_target = null if station_target else field.nearest(player.global_position, player.flat_forward(), float(Data.b["player"]["reach"]))
		for d in field.items:
			d.highlight = d == grab_target
		touch.buttons["use"]["on"] = grab_target != null or station_target != null
		if hook.reeling and hook.state == Hook.State.WATER:
			_reel_t -= delta
			if _reel_t <= 0.0:
				_reel_t = 0.16
				Sfx.play("reel", -14.0, 0.05)
		_save_t += delta
		if _save_t >= float(Data.b["save_interval"]):
			_save_t = 0.0
			_save()


## The station the player is looking at within reach, if any.
func _station_in_view() -> Station:
	var best: Station = null
	var best_dot := 0.55
	var eye := player.cam.global_position
	var fwd := -player.cam.global_basis.z
	for c: Vector2i in raft.stations:
		var st: Station = raft.stations[c]
		var to := st.global_position + Vector3(0, 0.45, 0) - eye
		if to.length() > float(Data.b["player"]["use_reach"]) + 0.6:
			continue
		var dot := to.normalized().dot(fwd)
		if dot > best_dot:
			best_dot = dot
			best = st
	return best
