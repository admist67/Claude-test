extends Node2D
## Game flow: menu → uncle's note → shift (customers, stations, touch input) → summary.

enum G { MENU, NOTE, PLAYING, SUMMARY }

const KITCHEN_H := 720.0
const SLOT_X := [130.0, 360.0, 590.0]
const SAVE_PATH := "user://save.json"
const MONEY_PILL := Vector2(40, 36)

const StreetS := preload("res://scripts/street.gd")
const KioskS := preload("res://scripts/kiosk.gd")
const SpitS := preload("res://scripts/spit.gd")
const BoardS := preload("res://scripts/board.gd")
const GrillS := preload("res://scripts/grill.gd")
const TrayS := preload("res://scripts/tray.gd")
const CustomerS := preload("res://scripts/customer.gd")
const FxS := preload("res://scripts/fx.gd")
const HintsS := preload("res://scripts/hints.gd")
const HudS := preload("res://scripts/hud.gd")


class DragLayer extends Node2D:
	var game: Node2D
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var d: Dictionary = game.drag
		if d.is_empty():
			return
		var made: Dictionary = d["made"]
		DU.roll(self, d["pos"] + Vector2(0, -40), made["toast"], Bal.b, 1.05, sin(t * 6.0) * 0.08, made["items"])


var g := G.MENU
var rng := RandomNumberGenerator.new()
var world: Node2D
var street: Node2D
var customers_root: Node2D
var kiosk: Node2D
var kitchen: Node2D
var spit: Node2D
var board: Node2D
var grill: Node2D
var tray: Node2D
var drag_layer: DragLayer
var fx: Node2D
var hints: Node2D
var hud: CanvasLayer
var street_h := 560.0

# Saved progress.
var day := 1
var bank := 0
var sound_on := true

# Current shift.
var shift_t := 0.0
var is_open := false
var closing_t := 0.0
var spawn_t := 0.0
var rush := false
var slots: Array = [null, null, null]
var stats := {}
var ratings: Array = []
var goal := 1200
var money_today := 0
var unlocked: Array = []
var tutorial_left := 0
var shake := 0.0

# Touch input.
var pressing := false
var press_pos := Vector2.ZERO
var press_target := ""
var consumed := false
var drag: Dictionary = {}


func _ready() -> void:
	rng.randomize()
	_load()
	world = Node2D.new()
	add_child(world)
	street = StreetS.new()
	world.add_child(street)
	customers_root = Node2D.new()
	world.add_child(customers_root)
	kiosk = KioskS.new()
	world.add_child(kiosk)
	kitchen = Node2D.new()
	world.add_child(kitchen)
	spit = SpitS.new()
	board = BoardS.new()
	grill = GrillS.new()
	tray = TrayS.new()
	for n in [spit, board, grill, tray]:
		kitchen.add_child(n)
	board.bal = Bal.b
	grill.bal = Bal.b
	drag_layer = DragLayer.new()
	drag_layer.game = self
	world.add_child(drag_layer)
	fx = FxS.new()
	world.add_child(fx)
	hints = HintsS.new()
	world.add_child(hints)
	hud = HudS.new()
	add_child(hud)
	hud.start_pressed.connect(_show_note)
	hud.note_closed.connect(_start_shift)
	hud.next_day_pressed.connect(_show_note)
	hud.menu_pressed.connect(_to_menu)
	hud.pause_pressed.connect(_pause)
	hud.resume_pressed.connect(_resume)
	hud.sound_toggled.connect(_toggle_sound)
	grill.perfect_reached.connect(func(p: Vector2):
		Sfx.play("perfect", 0.03, -4.0)
		fx.sparkle(p)
	)
	grill.burnt.connect(func(p: Vector2):
		Sfx.play("burnt")
		fx.puff(p, Color(0.2, 0.15, 0.15, 0.8), 16, 120.0, true)
	)
	tray.unlocked = Bal.unlocked_on(day)
	get_viewport().size_changed.connect(_layout)
	_layout()
	Sfx.set_enabled(sound_on)
	_to_menu()


func _layout() -> void:
	var vh := get_viewport_rect().size.y
	street_h = maxf(560.0, vh - KITCHEN_H)
	street.height = street_h
	kiosk.street_h = street_h
	kiosk.view_h = vh
	kiosk.queue_redraw()
	kitchen.position.y = street_h
	customers_root.position.y = street_h - 6.0


# --- Flow ---------------------------------------------------------------------

func _to_menu() -> void:
	get_tree().paused = false
	g = G.MENU
	_clear_table()
	hud.show_menu(day, bank, sound_on)


func _show_note() -> void:
	g = G.NOTE
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
	tray.unlocked = unlocked
	grill.unlocked = int(Bal.f("grill_slots"))
	spit.setup(int(Bal.f("spit_capacity")), Bal.f("spit_regen_seconds"))
	stats = {"served": 0, "lost": 0, "revenue": 0, "tips": 0}
	ratings.clear()
	money_today = 0
	hud.bar.money = 0
	hud.bar.shown = 0
	hud.bar.goal = goal
	hud.bar.rating = 0.0
	shift_t = 0.0
	spawn_t = Bal.f("first_customer_delay")
	is_open = true
	rush = false
	tutorial_left = int(Bal.f("tutorial_serves")) if day == 1 else 0
	g = G.PLAYING
	Sfx.start_music()
	fx.banner("Смена началась!", "Цель: %d ₽" % goal, DU.ORANGE, street_h * 0.5)


func _close() -> void:
	is_open = false
	closing_t = 0.0
	fx.banner("Закрываемся!", "Обслужи тех, кто ждёт", Color("#8e7dff"), street_h * 0.5)


func _end_shift() -> void:
	g = G.SUMMARY
	for c in slots:
		if c != null and is_instance_valid(c):
			c.leave(_exit_x(c), "Завтра зайду", "meh")
	slots = [null, null, null]
	_clear_table()
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
	for i in GrillS.MAX_SLOTS:
		grill.slots[i] = null
	drag = {}
	pressing = false
	hints.clear()
	street.rush = 0.0
	Sfx.set_sizzle(0.0)


func _pause() -> void:
	if g != G.PLAYING or get_tree().paused:
		return
	get_tree().paused = true
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


# --- Shift loop -----------------------------------------------------------------

func _process(delta: float) -> void:
	shake = maxf(0.0, shake - delta * 2.5)
	world.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 12.0
	if g != G.PLAYING:
		return
	var shift_len := Bal.f("shift_seconds")
	if is_open:
		shift_t += delta
		var hour := _hour()
		var was := rush
		rush = hour >= Bal.f("rush_from_hour") and hour < Bal.f("rush_to_hour")
		if rush and not was:
			fx.banner("НОЧНОЙ ЧАС ПИК!", "Чаевые ×2", Color("#ff4fa3"), street_h * 0.5)
			Sfx.play("jingle", 0.0)
			Sfx.music.pitch_scale = 1.08
		elif was and not rush:
			fx.banner("Час пик позади", "", Color("#8e7dff"), street_h * 0.5)
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
	street.rush = move_toward(street.rush, 1.0 if rush else 0.0, delta)
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
		v *= 1.6
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
		pat *= 2.5
	pat *= Bal.tune["patience"]
	var c := CustomerS.new()
	c.setup(ct, order, pat, slot, rng)
	customers_root.add_child(c)
	var from_x := -140.0 if SLOT_X[slot] < 360.0 or (slot == 1 and rng.randf() < 0.5) else 860.0
	c.arrive(from_x, SLOT_X[slot])
	c.gave_up.connect(_on_gave_up)
	slots[slot] = c


func _exit_x(c: Node2D) -> float:
	return -160.0 if c.position.x < 360.0 else 880.0


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
	shake = 0.5
	fx.float_text(c.global_position + Vector2(0, -300), "Ушёл!", DU.RED, 36)


func _serve(c, made: Dictionary) -> void:
	slots[c.slot] = null
	var ev: Dictionary = c.order.evaluate(made, Bal.b)
	var tip_mult := float(c.ctype["tip_mult"]) * (Bal.f("rush_tip_mult") if rush else 1.0)
	var refuse := float(c.ctype.get("refuse_below", Bal.f("refuse_below_quality")))
	var pay: Dictionary = c.order.payment(ev["quality"], c.patience_frac(), tip_mult, refuse, Bal.b)
	var head: Vector2 = c.global_position + Vector2(0, -230)
	ratings.append(pay["stars"])
	hud.bar.rating = _rating()
	if pay["refused"]:
		stats["lost"] += 1
		var why := "Это не мой заказ!" if ev["accuracy"] < 0.6 else "Это есть нельзя!"
		c.leave(_exit_x(c), why, "angry")
		Sfx.play("angry")
		Sfx.buzz(70)
		shake = 0.4
		fx.float_text(head, "Отказ!", DU.RED, 40)
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
	fx.coins(head, MONEY_PILL, clampi(total / 40, 3, 10), func():
		hud.bar.bump = 1.0
	)
	fx.float_text(head, "+%d ₽" % total, DU.GREEN, 42)
	if pay["tip"] > 0:
		fx.float_text(head + Vector2(0, 52), "чаевые +%d" % pay["tip"], DU.GOLD, 26, 60.0)
	if ev["toast"] == "perfect" and ev["accuracy"] >= 1.0:
		fx.float_text(head + Vector2(0, -64), "Идеально!", Color("#ff4fa3"), 46)
		fx.sparkle(head)
	elif ev["missing"] > 0:
		fx.float_text(head + Vector2(0, -64), "Чего-то не хватает…", DU.GOLD, 28)
	elif ev["extra"] > 0:
		fx.float_text(head + Vector2(0, -64), "Я такое не просил", DU.GOLD, 28)
	elif ev["toast"] == "burnt":
		fx.float_text(head + Vector2(0, -64), "Подгорело!", DU.GOLD, 30)
	elif ev["toast"] == "raw" or ev["toast"] == "under":
		fx.float_text(head + Vector2(0, -64), "Холодная…", DU.GOLD, 30)
	if tutorial_left > 0:
		tutorial_left -= 1


func _rating() -> float:
	if ratings.is_empty():
		return 0.0
	var s := 0.0
	for r in ratings:
		s += r
	return s / ratings.size()


# --- Touch input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if g != G.PLAYING:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(event.position)
		else:
			_release(event.position)
	elif event is InputEventMouseMotion and pressing:
		_motion(event.position)


func _press(p: Vector2) -> void:
	pressing = true
	press_pos = p
	consumed = false
	press_target = ""
	var gi: int = grill.slot_at(grill.to_local(p))
	if gi >= 0:
		drag = {"made": grill.take(gi), "slot": gi, "pos": p, "moved": false}
		Sfx.play("tap", 0.1, -6.0)
		Sfx.buzz(10)
		return
	if SpitS.AREA.has_point(spit.to_local(p)):
		press_target = "spit"
		return
	var bl: Vector2 = board.to_local(p)
	if BoardS.TRASH.grow(8).has_point(bl):
		press_target = "trash"
		return
	if BoardS.AREA.has_point(bl):
		press_target = "board"
		return
	var bin: String = tray.bin_at(tray.to_local(p))
	if bin != "":
		press_target = "bin:" + bin


func _motion(p: Vector2) -> void:
	if not drag.is_empty():
		drag["pos"] = p
		if p.distance_to(press_pos) > 14.0:
			drag["moved"] = true
		var over = _customer_at(p)
		for c in slots:
			if c != null:
				c.hover = c == over
		return
	if consumed:
		return
	var d := p - press_pos
	if press_target == "spit" and d.y > 45.0 and absf(d.y) > absf(d.x):
		consumed = true
		_cut()
	elif press_target == "board" and d.y < -45.0 and absf(d.y) > absf(d.x):
		consumed = true
		_roll()


func _release(p: Vector2) -> void:
	pressing = false
	if not drag.is_empty():
		_drop(p)
		return
	if consumed or p.distance_to(press_pos) > 30.0:
		return
	match press_target:
		"spit":
			spit.shake = 0.6
			_error(p, "Проведи пальцем вниз")
		"board":
			if board.state == BoardS.S.ROLLED:
				_to_grill()
			elif board.state == BoardS.S.OPEN:
				_error(p, "Проведи вверх — завернуть")
			else:
				_error(p, "Сначала возьми лаваш")
		"trash":
			_trash()
		_:
			if press_target.begins_with("bin:"):
				_bin(press_target.substr(4))


func _error(pos: Vector2, text: String) -> void:
	Sfx.play("error", 0.05, -4.0)
	Sfx.buzz(40)
	fx.float_text(pos + Vector2(0, -50), text, DU.CREAM, 26, 50.0)


func _bin(id: String) -> void:
	tray.poke(id)
	var from: Vector2 = tray.bin_center_global(id)
	if not unlocked.has(id):
		_error(from, "Откроется позже")
		return
	if id == "lavash":
		if board.put_lavash():
			Sfx.play("lavash")
			Sfx.buzz(15)
			fx.fly("lavash", from, board.center_global(), 0.22, 26.0)
		else:
			_error(from, "Доска занята")
		return
	if board.state != BoardS.S.OPEN:
		_error(from, "Сначала лаваш" if board.state == BoardS.S.EMPTY else "Уже завёрнуто")
		return
	if board.add_item(id):
		Sfx.play("plop")
		Sfx.buzz(10)
		fx.fly(id, from, board.center_global() + Vector2(rng.randf_range(-40, 40), rng.randf_range(-30, 30)), 0.22, 18.0)
	else:
		_error(from, "Уже есть")


func _cut() -> void:
	var at: Vector2 = spit.cut_point()
	if board.state != BoardS.S.OPEN:
		spit.shake = 1.0
		_error(at, "Сначала лаваш" if board.state == BoardS.S.EMPTY else "Уже завёрнуто")
		return
	if board.meat >= 2:
		_error(at, "Мяса хватит")
		return
	if not spit.can_cut():
		_error(at, "Мясо ещё жарится…")
		return
	spit.cut()
	board.add_meat()
	Sfx.play("chop")
	Sfx.buzz(20)
	for k in 6:
		fx.fly("meat", at + Vector2(0, k * 12.0), board.center_global() + Vector2(rng.randf_range(-45, 45), rng.randf_range(-35, 35)), 0.3, 9.0, k * 0.03)


func _roll() -> void:
	if board.roll():
		Sfx.play("roll")
		Sfx.buzz(20)
	elif board.state == BoardS.S.EMPTY:
		_error(board.center_global(), "Сначала лаваш")
	elif board.state == BoardS.S.OPEN:
		_error(board.center_global(), "Добавь начинку")


func _to_grill() -> void:
	if grill.free_slot() < 0:
		grill.shake = 1.0
		_error(grill.to_global(Vector2(614, 260)), "Гриль занят!")
		return
	grill.put(board.take_roll(), board.center_global())
	Sfx.play("clank")
	Sfx.buzz(20)


func _trash() -> void:
	board.trash_bump = 1.0
	if board.state == BoardS.S.EMPTY:
		return
	fx.puff(board.center_global(), DU.LAVASH, 12, 200.0)
	board.clear()
	Sfx.play("plop", 0.15)
	Sfx.buzz(20)


func _drop(p: Vector2) -> void:
	var made: Dictionary = drag["made"]
	var slot: int = drag["slot"]
	var moved: bool = drag["moved"]
	drag = {}
	for c in slots:
		if c != null:
			c.hover = false
	var c = _customer_at(p)
	if c != null:
		_serve(c, made)
		return
	if BoardS.TRASH.grow(20).has_point(board.to_local(p)):
		fx.puff(p, DU.LAVASH, 12, 200.0)
		Sfx.play("plop", 0.15)
		return
	grill.restore(slot, made)
	if not moved:
		_error(p, "Перетащи клиенту")


func _customer_at(p: Vector2):
	var best = null
	var best_d := INF
	for c in slots:
		if c == null or not is_instance_valid(c) or c.st != CustomerS.St.WAIT:
			continue
		if c.drop_rect().has_point(p):
			var d := absf(c.global_position.x - p.x)
			if d < best_d:
				best_d = d
				best = c
	return best


# --- Tutorial hints -----------------------------------------------------------------

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
	var to: Vector2 = c.global_position + Vector2(0, -120)
	if not drag.is_empty():
		hints.show_hint("drag", drag["pos"], "Отпусти на клиенте", to)
		return
	for i in grill.unlocked:
		var s = grill.slots[i]
		if s != null and s["t"] >= Bal.f("grill_perfect_from") and s["fly"] <= 0.0:
			hints.show_hint("drag", grill.slot_center_global(i), "Перетащи клиенту!", to)
			return
	match board.state:
		BoardS.S.EMPTY:
			if grill.busy_count() > 0:
				for i in grill.unlocked:
					if grill.slots[i] != null:
						hints.show_hint("tap", grill.slot_center_global(i), "Жарится… жди зелёную зону")
						return
			hints.show_hint("tap", tray.bin_center_global("lavash"), "Нажми на лаваш")
		BoardS.S.OPEN:
			if board.meat < c.order.meat:
				hints.show_hint("down", spit.to_global(Vector2(112, 250)), "Проведи вниз — срежь мясо")
				return
			for id in c.order.items:
				if not board.items.has(id):
					hints.show_hint("tap", tray.bin_center_global(id), "Добавь: " + Bal.ing_name(id))
					return
			hints.show_hint("up", board.center_global(), "Проведи вверх — заверни")
		BoardS.S.ROLLED:
			hints.show_hint("tap", board.center_global(), "Нажми — на гриль")


# --- Save -------------------------------------------------------------------------

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
