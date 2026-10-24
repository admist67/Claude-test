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
var net_target: Part              # a net or a door under the crosshair
var demolish_target: Node3D       # a part or station the hammer can take down
var rng := RandomNumberGenerator.new()

var ocean: Ocean
var daynight: DayNight
var raft: Raft
var player: Player
var hook: Hook
var rod: Rod
var shark: Shark
var storm: Storm
var fade: ColorRect
var field: DebrisField
var builder: Builder
var touch: TouchControls
var hud: Hud
var bag: CraftPanel
var build_panel: BuildPanel
var menus: Menus
var menu_cam: Camera3D
var _save_t := 0.0
var _menu_t := 0.0
var _reel_t := 0.0
var _spear_cd := 0.0


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
	shark.fled.connect(_on_shark_driven)
	raft.parts.daynight = daynight
	storm = Storm.new()
	add_child(storm)
	daynight.storm = storm
	storm.warned.connect(func() -> void:
		hud.toast("Надвигается шторм!", "warning")
		Sfx.play("warning", -6.0)
	)
	storm.started.connect(func() -> void: hud.toast("Шторм! Держись за плот", "warning"))
	storm.ended.connect(func() -> void:
		stats["storms"] = int(stats.get("storms", 0)) + 1
		hud.toast("Шторм стих — море несёт много обломков", "plank")
		_check_goals()
	)
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
	build_panel = BuildPanel.new()
	build_panel.inv = inv
	build_panel.visible = false
	layer.add_child(build_panel)
	build_panel.picked.connect(func(id: String) -> void:
		builder.kind = id
		_close_build()
	)
	build_panel.closed.connect(_close_build)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(fade)
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
	storm.restore(float(Data.b["storm"]["first"]))
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
		"parts": raft.parts.to_list(),
		"phase": daynight.phase,
		"storm_t": storm.timer if storm.state == Storm.State.CALM else float(Data.b["storm"]["interval"][0]),
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
	raft.parts.from_list(d.get("parts", []))
	for sd: Dictionary in d.get("stations", []):
		if Data.build_by_id.has(sd["kind"]):
			var a: Array = sd["cell"]
			var sk := Vector3i(int(a[0]), int(a[1]), int(a[2]) if a.size() > 2 else 0)
			if raft.parts.has_floor(Vector2i(sk.x, sk.y), sk.z):
				raft.add_station(sd["kind"], sk, Data.build_by_id[sd["kind"]]).load_state(sd)
	for e: Array in d.get("hp", []):
		var hc := Vector2i(int(e[0]), int(e[1]))
		if raft.has_tile(hc):
			raft.hp[hc] = int(e[2])
			raft.refresh_tile(hc)
	shark.reset(float(Data.b["shark"]["first_delay"]))
	daynight.phase = float(d.get("phase", Data.b["day"]["start_phase"]))
	storm.restore(float(d.get("storm_t", Data.b["storm"]["first"])))
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
	storm.cam = menu_cam
	menus.has_save = SaveGame.exists()
	menus.show_main()
	Sfx.ambience(true)


func _start() -> void:
	mode = Mode.PLAY
	menus.hide_all()
	player.cam.current = true
	ocean.cam = player.cam
	storm.cam = player.cam
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


## What the selected item does: tools act by their "use" (the metal hook is a hook).
func tool_use() -> String:
	return Data.item(selected()).get("use", selected())


func _apply_selection() -> void:
	var id := selected()
	var use := tool_use()
	if use != "hook" and hook.busy():
		hook.cancel()
	if use != "rod" and rod.busy():
		rod.cancel()
	hook.upgraded = id == "metal_hook"
	player.hold(id)
	builder.active = use == "hammer"
	touch.set_builds(build_choices().size())


## The build button above the hotbar while the hammer is out: shows what gets built.
func build_choices() -> Array:
	return [builder.kind] if tool_use() == "hammer" else []


func _open_build() -> void:
	if mode != Mode.PLAY:
		return
	mode = Mode.BAG
	_freeze_input()
	build_panel.open(builder.kind)


func _close_build() -> void:
	build_panel.visible = false
	mode = Mode.PLAY
	touch.enabled = true


func _on_pressed(b: String) -> void:
	match b:
		"action":
			_action_down()
		"use":
			_use()
		"rotate":
			builder.turn()
			Sfx.play("click", -6.0)
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
				Sfx.play("click", -8.0)
				_open_build.call_deferred()


func _on_released(b: String) -> void:
	if b == "action" and tool_use() == "hook":
		hook.release()
	elif b == "action" and tool_use() == "rod":
		if rod.state == Rod.State.CHARGE and inv.remove("bait"):
			rod.baited = true
			stats["bait_used"] = int(stats.get("bait_used", 0)) + 1
			hud.toast("Наживка на крючке", "bait")
		rod.release()


func _action_down() -> void:
	var id := selected()
	var use := tool_use()
	if use == "hook":
		hook.press()
	elif use == "rod":
		rod.press()
	elif use == "spear":
		_stab()
	elif use == "hammer":
		var fixing := builder.repair
		var upper := builder.level >= 1 and builder.kind != "roof"
		if builder.place():
			if upper:
				stats["upper_built"] = int(stats.get("upper_built", 0)) + 1
			player.swing()
			Sfx.play("hammer")
			var what: String = "Клетка починена" if fixing else ("Плот стал больше!" if builder.kind == "tile" else "Построено: " + builder.def()["name"])
			hud.toast(what, "hammer" if fixing else builder.kind)
			_check_goals()
		else:
			Sfx.play("build_fail", -4.0)
			if builder.has_target and builder.valid and not builder.affordable():
				hud.toast("Не хватает материалов", "plank")
			elif not builder.has_target or not builder.valid:
				hud.toast(_build_hint(builder.def()["on"]), builder.kind)
	elif Data.item(id).get("kind", "") == "food":
		_consume(id)


## The use button: take from / feed a station, or pick up floating debris by hand.
func _use() -> void:
	if demolish_target:
		_demolish(demolish_target)
		return
	if net_target and net_target.kind == "door":
		net_target.toggle()
		return
	if net_target and net_target.kind == "hammock":
		_sleep()
		return
	if net_target:
		var got: Array = net_target.caught.duplicate()
		net_target.caught.clear()
		player.swing()
		for d: Debris in got:
			if is_instance_valid(d):
				d.net = null
				_collect(d)
		return
	if station_target:
		var was_busy := station_target.busy()
		var res: Array = station_target.interact(inv)
		var got: String = res[1]
		if station_target.kind == "planter" and not was_busy and station_target.busy():
			stats["planted"] = int(stats.get("planted", 0)) + 1
		player.swing()
		if got != "":
			stats["got_" + got] = int(stats.get("got_" + got, 0)) + 1
			if station_target.kind == "grill":
				stats["cooked"] = int(stats.get("cooked", 0)) + 1
			if station_target.kind == "planter":
				stats["harvest"] = int(stats.get("harvest", 0)) + 1
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
	if _spear_cd > 0.0:
		return
	_spear_cd = float(Data.b["player"]["spear_cooldown"])
	player.swing()
	var metal := selected() == "metal_spear"
	var ms: Dictionary = Data.b["shark"]["metal_spear"]
	if shark.try_hit(player.cam.global_position, -player.cam.global_basis.z, int(ms["power"]) if metal else 1, float(ms["reach"]) if metal else 0.0):
		if shark.hits_left() > 0:
			hud.toast("Попал!", "spear")
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


## Enough spear hits: the shark swims off, leaving a torn-off piece behind.
func _on_shark_driven() -> void:
	stats["shark_driven"] = int(stats.get("shark_driven", 0)) + 1
	hud.toast("Акула уплыла зализывать раны", "spear")
	for id: String in Data.b["shark"]["reward"]:
		var n := int(Data.b["shark"]["reward"][id])
		inv.add(id, n)
		hud.toast("+%d %s" % [n, Data.item_name(id)], id)
	Sfx.play("goal", -4.0)
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


## The hammer takes a part or station down and gives back half of what it cost.
func _demolish(target: Node3D) -> void:
	var kind: String = target.kind
	var cost: Dictionary = Data.build_by_id[kind]["cost"]
	var share := float(Data.b["raft"]["refund"])
	for id: String in cost:
		var n := int(floor(int(cost[id]) * share))
		if n > 0:
			inv.add(id, n)
	if target is Station:
		var st: Station = target
		if st.ready_item != "":
			inv.add(st.ready_item, int(st.def.get("count", 1)))
		raft.stations.erase(st.cell)
		st.queue_free()
		raft.parts.prune()
	else:
		raft.parts.remove_part(target)
	player.swing()
	Sfx.play("hammer", -2.0, 0.2)
	hud.toast("Разобрано: " + Data.build_by_id[kind]["name"], kind)


## Sleep in a hammock: the night passes in a fade, hunger and thirst drop a bit.
func _sleep() -> void:
	if not daynight.is_night():
		hud.toast("Спать можно только ночью", "moon")
		return
	_freeze_input()
	mode = Mode.PAUSE
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.7)
	tw.tween_callback(func() -> void:
		daynight.phase = 0.03
		daynight.day += 1
		daynight.apply()
		var sl: Dictionary = Data.b["sleep"]
		vitals.hunger = maxf(5.0, vitals.hunger - float(sl["hunger"]))
		vitals.thirst = maxf(5.0, vitals.thirst - float(sl["thirst"]))
		stats["slept"] = int(stats.get("slept", 0)) + 1
	)
	tw.tween_interval(0.6)
	tw.tween_property(fade, "color:a", 0.0, 0.9)
	tw.tween_callback(func() -> void:
		mode = Mode.PLAY
		touch.enabled = true
		hud.toast("Доброе утро! День %d" % daynight.day, "sun")
		_check_goals()
		_save()
	)


func _on_fish(id: String) -> void:
	inv.add(id)
	stats["got_" + id] = int(stats.get("got_" + id, 0)) + 1
	stats["fish"] = int(stats.get("fish", 0)) + 1
	Sfx.play("goal", -6.0)
	hud.toast("Поймана: " + Data.item_name(id), id)
	player.swing()
	_check_goals()


func _build_hint(on: String) -> String:
	match on:
		"water":
			return "Посмотри на воду у края плота"
		"edge":
			return "Посмотри на пол у края клетки, где нужна стена"
		"edge_out":
			return "Посмотри на пол у внешнего края плота"
		"corner":
			return "Посмотри на пол у угла клетки"
		"roof":
			return "Крыше нужна опора: стена, столб или соседняя крыша"
	return "Посмотри на свободную клетку плота"


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
		return raft.count_kind(name.substr(6))
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
	if demolish_target:
		return {"icon": demolish_target.kind, "label": "Разобрать", "ok": true}
	if net_target:
		var p: Dictionary = net_target.prompt(inv)
		return {"icon": p["icon"], "label": p["text"], "ok": p["ok"]}
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
	match tool_use():
		"":
			out = {"icon": "hand", "label": "", "ok": false}
		"hook":
			var labels := {Hook.State.IDLE: "Бросить", Hook.State.CHARGE: "Отпусти!", Hook.State.FLY: "…", Hook.State.WATER: "Тянуть"}
			out["label"] = labels[hook.state]
		"rod":
			var labels := {Rod.State.IDLE: "Забросить", Rod.State.CHARGE: "Отпусти!", Rod.State.FLY: "…", Rod.State.WAIT: "Вытащить", Rod.State.BITE: "Тяни!"}
			out["label"] = labels[rod.state]
		"spear":
			out = {"icon": id, "label": "Ударить", "ok": shark.alive_near() and _spear_cd <= 0.0, "cooldown": _spear_cd / float(Data.b["player"]["spear_cooldown"])}
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
	_spear_cd = maxf(0.0, _spear_cd - delta)
	field.extra_mult = storm.debris_mult()
	Station.rain = storm.k
	if mode == Mode.PLAY:
		var aimed := _aimed_body()
		demolish_target = aimed if tool_use() == "hammer" and (aimed is Part or aimed is Station) else null
		station_target = null if demolish_target else aimed as Station
		net_target = aimed if not demolish_target and aimed is Part and aimed.kind in ["net", "door", "hammock"] else null
		grab_target = null if station_target or net_target or demolish_target else field.nearest(player.global_position, player.flat_forward(), float(Data.b["player"]["reach"]))
		for d in field.items:
			d.highlight = d == grab_target
		touch.buttons["use"]["on"] = grab_target != null or station_target != null or net_target != null or demolish_target != null
		touch.buttons["rotate"]["on"] = tool_use() == "hammer" and builder.rotatable()
		if hook.reeling and hook.state == Hook.State.WATER:
			_reel_t -= delta
			if _reel_t <= 0.0:
				_reel_t = 0.16
				Sfx.play("reel", -14.0, 0.05)
		_save_t += delta
		if _save_t >= float(Data.b["save_interval"]):
			_save_t = 0.0
			_save()


## The body the crosshair is right on (a ray from the screen center), if any. Doors are
## forgiving: one roughly ahead and close counts even when the ray slips past it.
func _aimed_body() -> Node:
	var from := player.cam.global_position
	var fwd := -player.cam.global_basis.z
	var to := from + fwd * (float(Data.b["player"]["use_reach"]) + 0.6)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | Part.USE_LAYER, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var body: Node = null
	if not hit.is_empty():
		body = hit["collider"]
		if body.has_meta("part"):
			body = body.get_meta("part")
		if body is Part or body is Station:
			return body
	for d: Part in raft.parts.doors():
		var v := d.global_position + Vector3(0, 1.0, 0) - from
		if v.length() < 3.0 and v.normalized().dot(fwd) > 0.82:
			return d
	return body
