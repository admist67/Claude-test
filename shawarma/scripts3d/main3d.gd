extends Node3D
## 3D game flow: menu → uncle's note → shift in first person → summary.
## Same rules as the 2D version (Order, balance, customers); input is joystick + look +
## taps on objects (raycast) + vertical swipes on the spit / board.

enum G { MENU, NOTE, PLAYING, SUMMARY }

const SAVE_PATH := "user://save3d.json"
const REACH := 2.1
const SLOT_X := [-1.1, 0.0, 1.1]
const WINDOW_Z := -2.0
const LANE_Z := -3.0
const MONEY_PILL := Vector2(40, 36)
const CHARACTERS := ["female-a", "female-b", "female-c", "female-d", "female-e", "female-f",
	"male-a", "male-b", "male-c", "male-d", "male-e", "male-f"]

const WorldS := preload("res://scripts3d/world3d.gd")
const SpitS := preload("res://scripts3d/spit3d.gd")
const BoardS := preload("res://scripts3d/board3d.gd")
const GrillS := preload("res://scripts3d/grill3d.gd")
const BinsS := preload("res://scripts3d/bins3d.gd")
const CustomerS := preload("res://scripts3d/customer3d.gd")
const PlayerS := preload("res://scripts3d/player.gd")
const TouchS := preload("res://scripts3d/touch.gd")
const FxS := preload("res://scripts/fx.gd")
const HintsS := preload("res://scripts/hints.gd")
const HudS := preload("res://scripts/hud.gd")

var g := G.MENU
var rng := RandomNumberGenerator.new()
var world: Node3D
var spit: Node3D
var board: Node3D
var grill: Node3D
var bins: Node3D
var player: CharacterBody3D
var customers_root: Node3D
var touch: CanvasLayer
var fx: Node2D
var hints: Node2D
var hud: CanvasLayer

var day := 1
var bank := 0
var sound_on := true

var shift_t := 0.0
var is_open := false
var closing_t := 0.0
var spawn_t := 0.0
var rush := false
var rush_k := 0.0
var slots: Array = [null, null, null]
var stats := {}
var ratings: Array = []
var goal := 1500
var money_today := 0
var unlocked: Array = []
var tutorial_left := 0


func _ready() -> void:
	rng.randomize()
	_load()
	world = WorldS.new()
	add_child(world)
	spit = SpitS.new()
	spit.position = Vector3(-1.72, 1.0, 0.75)
	add_child(spit)
	board = BoardS.new()
	board.bal = Bal.b
	board.position = Vector3(-0.85, 1.0, 1.62)
	add_child(board)
	bins = BinsS.new()
	bins.position = Vector3(0, 1.0, 1.62)
	add_child(bins)
	grill = GrillS.new()
	grill.bal = Bal.b
	grill.position = Vector3(1.72, 1.0, 0.3)
	add_child(grill)
	M3.model(self, "res://assets/models/furniture/trashcan.glb", Vector3(1.15, 0, 1.05), 2.2)
	M3.solid(self, Vector3(0.5, 0.95, 0.5), Vector3(1.15, 0.47, 1.05), M3.LAYER_USE, "trash")
	M3.solid(self, Vector3(0.45, 0.95, 0.45), Vector3(1.15, 0.47, 1.05))
	customers_root = Node3D.new()
	add_child(customers_root)
	player = PlayerS.new()
	player.position = Vector3(0, 0, 0.35)
	add_child(player)
	var fx_layer := CanvasLayer.new()
	fx_layer.layer = 4
	add_child(fx_layer)
	fx = FxS.new()
	fx_layer.add_child(fx)
	hints = HintsS.new()
	fx_layer.add_child(hints)
	touch = TouchS.new()
	touch.classify = _is_gesture_target
	touch.tapped.connect(_tap)
	touch.swiped.connect(_swipe)
	touch.looked.connect(func(rel: Vector2): player.look(rel))
	add_child(touch)
	hud = HudS.new()
	add_child(hud)
	hud.start_pressed.connect(_show_note)
	hud.note_closed.connect(_start_shift)
	hud.next_day_pressed.connect(_show_note)
	hud.menu_pressed.connect(_to_menu)
	hud.pause_pressed.connect(_pause)
	hud.resume_pressed.connect(_resume)
	hud.sound_toggled.connect(_toggle_sound)
	grill.perfect_reached.connect(func(p: Vector3):
		Sfx.play("perfect", 0.03, -4.0)
		_puff(p, Color(1, 0.95, 0.5), 14, false)
	)
	grill.burnt.connect(func(p: Vector3):
		Sfx.play("burnt")
		_puff(p, Color(0.2, 0.15, 0.15, 0.8), 14, true)
	)
	get_viewport().size_changed.connect(_layout)
	_layout()
	Sfx.set_enabled(sound_on)
	_to_menu()


func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	hud.set_width(vs.x)
	fx.screen_w = vs.x
	hints.screen_w = vs.x
	hints.screen_h = vs.y


# --- Flow ---------------------------------------------------------------------

func _to_menu() -> void:
	get_tree().paused = false
	g = G.MENU
	touch.enabled = false
	_clear_table()
	player.position = Vector3(0, 0, 0.35)
	player.yaw = 0.0
	player.pitch = -0.08
	hud.show_menu(day, bank, sound_on)


func _show_note() -> void:
	g = G.NOTE
	touch.enabled = false
	goal = int(Bal.f("goal_base") + Bal.f("goal_step") * (day - 1))
	unlocked = Bal.unlocked_on(day)
	var fresh: Array = []
	if day > 1:
		for ing in Bal.ingredients:
			if int(ing["unlock_day"]) == day:
				fresh.append(ing["name"])
	hud.show_note(day, Bal.note_for(day), goal, fresh)


func _start_shift() -> void:
	hud.clear_screen()
	hud.set_bar_visible(true)
	_clear_table()
	bins.set_unlocked(unlocked)
	grill.set_unlocked(int(Bal.f("grill_slots")))
	spit.setup(int(Bal.f("spit_capacity")), Bal.f("spit_regen_seconds"))
	stats = {"served": 0, "lost": 0, "revenue": 0, "tips": 0}
	ratings.clear()
	money_today = 0
	hud.bar.money = 0
	hud.bar.shown = 0
	hud.bar.goal = goal
	hud.bar.rating = 0.0
	shift_t = 0.0
	spawn_t = Bal.f("first_customer_delay") + 2.0
	is_open = true
	rush = false
	tutorial_left = int(Bal.f("tutorial_serves")) if day == 1 else 0
	g = G.PLAYING
	touch.reset()
	touch.enabled = true
	Sfx.start_music()
	fx.banner("Смена началась!", "Цель: %d ₽   ·   слева джойстик, справа — обзор" % goal, DU.ORANGE, 200.0)


func _close() -> void:
	is_open = false
	closing_t = 0.0
	fx.banner("Закрываемся!", "Обслужи тех, кто ждёт", Color("#8e7dff"), 200.0)


func _end_shift() -> void:
	g = G.SUMMARY
	touch.enabled = false
	for c in slots:
		if c != null and is_instance_valid(c):
			c.leave(_exit_x(c), "Завтра зайду", "meh")
	slots = [null, null, null]
	board.clear()
	grill.clear_all()
	player.drop()
	hints.clear()
	Sfx.set_sizzle(0.0)
	Sfx.music.pitch_scale = 1.0
	var stars := 0
	if money_today >= goal:
		stars = 1
	if money_today >= goal * 1.5:
		stars = 2
	if money_today >= goal * 2:
		stars = 3
	bank += money_today
	var summary := {"stars": stars, "served": stats["served"], "lost": stats["lost"], "revenue": stats["revenue"],
		"tips": stats["tips"], "rating": _rating(), "total": money_today, "goal": goal}
	day += 1
	_save()
	Sfx.play("jingle", 0.0)
	hud.show_summary(summary)


func _clear_table() -> void:
	for c in customers_root.get_children():
		c.queue_free()
	slots = [null, null, null]
	board.clear()
	grill.clear_all()
	player.drop()
	hints.clear()
	rush_k = 0.0
	world.set_rush(0.0)
	Sfx.set_sizzle(0.0)


func _pause() -> void:
	if g != G.PLAYING or get_tree().paused:
		return
	get_tree().paused = true
	touch.reset()
	Sfx.set_sizzle(0.0)
	hud.show_pause()


func _resume() -> void:
	get_tree().paused = false
	hud.clear_screen()


func _toggle_sound() -> void:
	sound_on = not sound_on
	Sfx.set_enabled(sound_on)
	_save()
	hud.show_menu(day, bank, sound_on)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if get_tree().paused:
			_resume()
		elif g == G.PLAYING:
			_pause()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if g == G.PLAYING:
			_pause()


# --- Shift loop -------------------------------------------------------------------

func _process(delta: float) -> void:
	if g == G.MENU:
		player.yaw = sin(Time.get_ticks_msec() / 4000.0) * 0.25
		return
	if g != G.PLAYING:
		return
	player.move_input = touch.move
	var shift_len := Bal.f("shift_seconds")
	if is_open:
		shift_t += delta
		var hour := _hour()
		var was := rush
		rush = hour >= Bal.f("rush_from_hour") and hour < Bal.f("rush_to_hour")
		if rush and not was:
			fx.banner("НОЧНОЙ ЧАС ПИК!", "Чаевые ×2", Color("#ff4fa3"), 200.0)
			Sfx.play("jingle", 0.0)
			Sfx.music.pitch_scale = 1.08
		elif was and not rush:
			fx.banner("Час пик позади", "", Color("#8e7dff"), 200.0)
			Sfx.music.pitch_scale = 1.0
		spawn_t -= delta
		if spawn_t <= 0.0:
			if _free_slot() >= 0:
				_spawn()
				spawn_t = _next_interval(shift_t / shift_len)
			else:
				spawn_t = 1.0
		if shift_t >= shift_len:
			_close()
	else:
		closing_t += delta
		if _customer_count() == 0 or closing_t > Bal.f("close_grace_seconds"):
			_end_shift()
			return
	rush_k = move_toward(rush_k, 1.0 if rush else 0.0, delta)
	world.set_rush(rush_k)
	hud.bar.clock = _clock_text()
	hud.bar.rush = rush
	Sfx.set_sizzle(grill.busy_count() / 3.0)
	_update_hints()


func _hour() -> float:
	var a := Bal.f("shift_start_hour")
	var b := Bal.f("shift_end_hour")
	return a + (b - a) * minf(1.0, shift_t / Bal.f("shift_seconds"))


func _clock_text() -> String:
	var h := _hour()
	var m := int(fmod(h, 1.0) * 60.0) / 10 * 10
	return "%02d:%02d" % [int(h) % 24, m]


func _next_interval(progress: float) -> float:
	var v := lerpf(Bal.f("spawn_interval_start"), Bal.f("spawn_interval_end"), progress)
	v *= maxf(1.0, Bal.f("day1_ease") - Bal.f("ease_per_day") * (day - 1))
	if rush:
		v *= Bal.f("rush_spawn_mult")
	if tutorial_left > 0:
		v *= 1.8
	return v / Bal.tune["spawn"] * rng.randf_range(0.85, 1.15)


func _free_slot() -> int:
	var free: Array = []
	for i in 3:
		if slots[i] == null:
			free.append(i)
	if free.is_empty():
		return -1
	return free[rng.randi_range(0, free.size() - 1)]


func _customer_count() -> int:
	var n := 0
	for c in slots:
		if c != null:
			n += 1
	return n


func _pick_type() -> Dictionary:
	var pool: Array = []
	var total := 0.0
	for ct in Bal.customers:
		if int(ct["min_day"]) > day or (ct["rush_only"] and not rush):
			continue
		pool.append(ct)
		total += float(ct["weight"])
	var r := rng.randf() * total
	for ct in pool:
		r -= float(ct["weight"])
		if r <= 0.0:
			return ct
	return pool[0]


func _spawn() -> void:
	var slot := _free_slot()
	var ct := _pick_type()
	var defs: Array = []
	for id in unlocked:
		var kind: String = Bal.ing_by_id[id]["kind"]
		if kind == "veg" or kind == "sauce":
			defs.append(Bal.ing_by_id[id])
	var order := Order.generate(rng, defs, ct, Bal.b)
	var pat := (Bal.f("patience_base") + Bal.f("patience_per_item") * order.items.size()) * float(ct["patience_mult"])
	if rush:
		pat *= Bal.f("rush_patience_mult")
	if tutorial_left > 0:
		pat *= 3.0
	pat *= Bal.tune["patience"] * 1.25   # walking around the kiosk takes time
	var used: Array = []
	for c in slots:
		if c != null:
			used.append(c.get_meta("model"))
	var model_name: String = CHARACTERS[rng.randi_range(0, CHARACTERS.size() - 1)]
	while used.has(model_name):
		model_name = CHARACTERS[rng.randi_range(0, CHARACTERS.size() - 1)]
	var c := CustomerS.new()
	c.set_meta("model", model_name)
	customers_root.add_child(c)
	c.setup(ct, order, pat, slot, "res://assets/models/characters/character-%s.glb" % model_name)
	var side := -1.0 if SLOT_X[slot] < 0.0 or (slot == 1 and rng.randf() < 0.5) else 1.0
	c.arrive(Vector3(side * 9.0, 0, LANE_Z), Vector3(SLOT_X[slot], 0, WINDOW_Z))
	c.gave_up.connect(_on_gave_up)
	slots[slot] = c


func _exit_x(c: Node3D) -> float:
	return -10.0 if c.position.x < 0.0 else 10.0


func _on_gave_up(c) -> void:
	if slots[c.slot] != c:
		return
	slots[c.slot] = null
	stats["lost"] += 1
	ratings.append(1)
	hud.bar.rating = _rating()
	var phrases: Array = c.ctype["angry"]
	c.leave(_exit_x(c), phrases[rng.randi_range(0, phrases.size() - 1)], "angry")
	Sfx.play("angry")
	Sfx.buzz(70)
	_float(c.head_global() + Vector3(0, 0.6, 0), "Ушёл!", DU.RED, 36)


func _serve(c, made: Dictionary) -> void:
	slots[c.slot] = null
	var ev: Dictionary = c.order.evaluate(made, Bal.b)
	var tip_mult := float(c.ctype["tip_mult"]) * (Bal.f("rush_tip_mult") if rush else 1.0)
	var refuse := float(c.ctype.get("refuse_below", Bal.f("refuse_below_quality")))
	var pay: Dictionary = c.order.payment(ev["quality"], c.patience_frac(), tip_mult, refuse, Bal.b)
	var head: Vector3 = c.head_global() + Vector3(0, 0.55, 0)
	ratings.append(pay["stars"])
	hud.bar.rating = _rating()
	if pay["refused"]:
		stats["lost"] += 1
		c.leave(_exit_x(c), "Это не мой заказ!" if ev["accuracy"] < 0.6 else "Это есть нельзя!", "angry")
		Sfx.play("angry")
		Sfx.buzz(70)
		_float(head, "Отказ!", DU.RED, 40)
		return
	var total: int = pay["pay"] + pay["tip"]
	stats["served"] += 1
	stats["revenue"] += pay["pay"]
	stats["tips"] += pay["tip"]
	money_today += total
	hud.bar.money = money_today
	var happy: Array = c.ctype["happy"]
	var good: bool = ev["quality"] >= 0.75
	c.leave(_exit_x(c), happy[rng.randi_range(0, happy.size() - 1)] if good else "Ну… сойдёт", "happy" if good else "meh")
	Sfx.play("cash", 0.03)
	Sfx.buzz(30)
	var sp := _screen(head)
	if sp.x >= 0.0:
		fx.coins(sp, MONEY_PILL, clampi(total / 40, 3, 10), func():
			hud.bar.bump = 1.0
		)
	_float(head, "+%d ₽" % total, DU.GREEN, 42)
	if pay["tip"] > 0:
		_float(head + Vector3(0, -0.22, 0), "чаевые +%d" % pay["tip"], DU.GOLD, 26)
	var note := ""
	if ev["toast"] == "perfect" and ev["accuracy"] >= 1.0:
		note = "Идеально!"
		_puff(head, Color(1, 0.95, 0.5), 18, false)
	elif ev["missing"] > 0:
		note = "Чего-то не хватает…"
	elif ev["extra"] > 0:
		note = "Я такое не просил"
	elif ev["toast"] == "burnt":
		note = "Подгорело!"
	elif ev["toast"] == "raw" or ev["toast"] == "under":
		note = "Холодная…"
	if note != "":
		_float(head + Vector3(0, 0.25, 0), note, Color("#ff4fa3") if note == "Идеально!" else DU.GOLD, 34)
	if tutorial_left > 0:
		tutorial_left -= 1


func _rating() -> float:
	if ratings.is_empty():
		return 0.0
	var s := 0.0
	for r in ratings:
		s += r
	return s / ratings.size()


# --- Interaction ---------------------------------------------------------------------

func _ray(screen: Vector2) -> Dictionary:
	var cam: Camera3D = player.cam
	var from := cam.project_ray_origin(screen)
	var q := PhysicsRayQueryParameters3D.create(from, from + cam.project_ray_normal(screen) * 8.0, M3.LAYER_USE)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {}
	var col: Object = hit["collider"]
	return {"kind": col.get_meta("kind", ""), "pos": hit["position"], "dist": from.distance_to(hit["position"]), "node": col}


func _is_gesture_target(pos: Vector2) -> bool:
	var hit := _ray(pos)
	if hit.is_empty() or hit["dist"] > REACH:
		return false
	return hit["kind"] == "spit" or (hit["kind"] == "board" and board.state == BoardS.S.OPEN)


func _tap(pos: Vector2) -> void:
	var hit := _ray(pos)
	if hit.is_empty():
		return
	var kind: String = hit["kind"]
	if hit["dist"] > REACH:
		_error(pos, "Подойди ближе")
		return
	if kind == "lavash":
		_lavash(pos)
	elif kind.begins_with("bin:"):
		_bin(kind.substr(4), pos)
	elif kind == "board":
		_board_tap(pos)
	elif kind == "spit":
		_error(pos, "Проведи пальцем вниз по мясу")
	elif kind.begins_with("grill:"):
		_grill_tap(int(kind.substr(6)), pos)
	elif kind == "customer":
		var c = hit["node"].get_meta("customer")
		if not player.held.is_empty() and c.st == CustomerS.St.WAIT:
			_serve(c, player.drop())
		elif player.held.is_empty():
			_error(pos, "Сначала приготовь заказ")
	elif kind == "trash":
		_trash(pos)


func _swipe(pos: Vector2, down: bool) -> void:
	var hit := _ray(pos)
	if hit.is_empty() or hit["dist"] > REACH:
		return
	if hit["kind"] == "spit" and down:
		_cut(pos)
	elif hit["kind"] == "board" and not down:
		_roll(pos)


func _error(pos: Vector2, text: String) -> void:
	Sfx.play("error", 0.05, -4.0)
	Sfx.buzz(40)
	fx.float_text(pos + Vector2(0, -40), text, DU.CREAM, 28, 50.0)


func _lavash(pos: Vector2) -> void:
	bins.poke("lavash")
	if not player.held.is_empty():
		_error(pos, "Руки заняты")
		return
	if board.put_lavash():
		Sfx.play("lavash")
		Sfx.buzz(15)
	else:
		_error(pos, "Доска занята")


func _bin(id: String, pos: Vector2) -> void:
	bins.poke(id)
	if not unlocked.has(id):
		_error(pos, "Откроется позже")
		return
	if board.state != BoardS.S.OPEN:
		_error(pos, "Сначала лаваш" if board.state == BoardS.S.EMPTY else "Уже завёрнуто")
		return
	if board.add_item(id):
		Sfx.play("plop")
		Sfx.buzz(10)
		_fly(bins.target(id), board.center_global(), M3.mat(Bal.color(id)), Vector3(0.03, 0.01, 0.03), 3)
	else:
		_error(pos, "Уже есть")


func _cut(pos: Vector2) -> void:
	if board.state != BoardS.S.OPEN:
		_error(pos, "Сначала лаваш" if board.state == BoardS.S.EMPTY else "Уже завёрнуто")
		return
	if board.meat >= 2:
		_error(pos, "Мяса хватит")
		return
	if not spit.can_cut():
		_error(pos, "Мясо ещё жарится…")
		return
	spit.cut()
	board.add_meat()
	Sfx.play("chop")
	Sfx.buzz(20)
	_fly(spit.cut_point(), board.center_global(), M3.mat(DU.MEAT), Vector3(0.05, 0.012, 0.02), 6)


func _roll(pos: Vector2) -> void:
	if board.roll():
		Sfx.play("roll")
		Sfx.buzz(20)
	elif board.state == BoardS.S.OPEN:
		_error(pos, "Добавь начинку")


func _board_tap(pos: Vector2) -> void:
	match board.state:
		BoardS.S.ROLLED:
			if not player.held.is_empty():
				_error(pos, "Руки заняты")
				return
			player.hold(board.take_roll())
			Sfx.play("tap", 0.1)
			Sfx.buzz(15)
		BoardS.S.OPEN:
			_error(pos, "Проведи вверх — завернуть")
		_:
			_error(pos, "Возьми лаваш" if player.held.is_empty() else "Положи на гриль")


func _grill_tap(i: int, pos: Vector2) -> void:
	if i >= grill.unlocked:
		_error(pos, "Закрыто")
		return
	if not player.held.is_empty():
		if grill.slots[i] != null:
			_error(pos, "Занято")
			return
		grill.put_in(i, player.drop(), player.hand_global())
		Sfx.play("clank")
		Sfx.buzz(20)
	elif grill.slots[i] != null:
		player.hold(grill.take(i))
		Sfx.play("tap", 0.1)
		Sfx.buzz(15)
	else:
		_error(pos, "Положи сюда свёрток")


func _trash(pos: Vector2) -> void:
	if not player.held.is_empty():
		player.drop()
		_puff(Vector3(1.15, 1.0, 1.05), DU.LAVASH, 10, false)
		Sfx.play("plop", 0.15)
	elif board.state != BoardS.S.EMPTY:
		board.clear()
		_puff(board.center_global(), DU.LAVASH, 10, false)
		Sfx.play("plop", 0.15)
	else:
		_error(pos, "Тут мусорка")


# --- 3D juice helpers ------------------------------------------------------------------

func _fly(from: Vector3, to: Vector3, material: Material, size: Vector3, count: int) -> void:
	for k in count:
		var mi := M3.box(self, size, from, material)
		var mid := (from + to) / 2.0 + Vector3(0, 0.25, 0)
		var dst := to + Vector3(rng.randf_range(-0.06, 0.06), 0, rng.randf_range(-0.06, 0.06))
		var step := func(t: float) -> void:
			mi.position = from.lerp(mid, t).lerp(mid.lerp(dst, t), t)
			mi.rotation.y = t * 6.0
		var tw := mi.create_tween()
		tw.tween_interval(k * 0.03)
		tw.tween_method(step, 0.0, 1.0, 0.28)
		tw.tween_callback(mi.queue_free)


func _puff(pos: Vector3, color: Color, amount: int, up: bool) -> void:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.8
	p.spread = 180.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0, 0.4, 0) if up else Vector3(0, -2.0, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.02
	sm.height = 0.04
	sm.radial_segments = 6
	sm.rings = 3
	p.mesh = sm
	p.material_override = M3.flat(color)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.3).timeout.connect(p.queue_free)


func _screen(world_pos: Vector3) -> Vector2:
	var cam: Camera3D = player.cam
	if cam.is_position_behind(world_pos):
		return Vector2(-1, -1)
	var p := cam.unproject_position(world_pos)
	var vs := get_viewport().get_visible_rect().size
	if p.x < 0 or p.y < 0 or p.x > vs.x or p.y > vs.y:
		return Vector2(-1, -1)
	return p


func _float(world_pos: Vector3, text: String, color: Color, size: int) -> void:
	var p := _screen(world_pos)
	if p.x >= 0.0:
		fx.float_text(p, text, color, size)


# --- Tutorial hints ---------------------------------------------------------------------

func _hint_at(kind: String, world_pos: Vector3, caption: String) -> void:
	var p := _screen(world_pos)
	if p.x >= 0.0:
		hints.show_hint(kind, p, caption)
		return
	var local: Vector3 = player.cam.global_transform.affine_inverse() * world_pos
	hints.show_hint("turn", Vector2(-1.0 if local.x < 0.0 else 1.0, 0), "Повернись: " + caption)


func _update_hints() -> void:
	if tutorial_left <= 0:
		hints.clear()
		return
	var c = null
	for s in slots:
		if s != null and s.st == CustomerS.St.WAIT and (c == null or s.patience < c.patience):
			c = s
	if c == null:
		hints.clear()
		return
	var from := Bal.f("grill_perfect_from")
	if not player.held.is_empty():
		if float(player.held["toast"]) < from and grill.free_slot() >= 0:
			_hint_at("tap", grill.slot_global(grill.free_slot()), "Положи на гриль")
		else:
			_hint_at("tap", c.head_global(), "Отдай клиенту — нажми на него")
		return
	for i in grill.unlocked:
		var s = grill.slots[i]
		if s != null and s["t"] >= from:
			_hint_at("tap", grill.slot_global(i), "Готово! Возьми с гриля")
			return
	match board.state:
		BoardS.S.EMPTY:
			for i in grill.unlocked:
				if grill.slots[i] != null:
					_hint_at("tap", grill.slot_global(i), "Жарится… жди зелёную зону")
					return
			_hint_at("tap", bins.target("lavash"), "Нажми на лаваш")
		BoardS.S.OPEN:
			if board.meat < c.order.meat:
				_hint_at("down", spit.cut_point(), "Проведи вниз по мясу")
				return
			for id in c.order.items:
				if not board.items.has(id):
					_hint_at("tap", bins.target(id), "Добавь: " + Bal.ing_name(id))
					return
			_hint_at("up", board.center_global(), "Проведи вверх — заверни")
		BoardS.S.ROLLED:
			_hint_at("tap", board.center_global(), "Возьми свёрток")


# --- Save ---------------------------------------------------------------------------

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if d is Dictionary:
		day = int(d.get("day", 1))
		bank = int(d.get("bank", 0))
		sound_on = bool(d.get("sound", true))


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"day": day, "bank": bank, "sound": sound_on}))
