extends Node3D
## 3D game flow: menu → uncle's note → shift in first person → summary → shop.
## Same rules as the 2D version (Order, balance, customers); input is joystick + look +
## taps on objects (raycast) + vertical swipes on the spit / board. With the café, guests
## also sit at terrace tables (and may want a drink); hired staff help (staff3d.gd).

enum G { MENU, NOTE, PLAYING, SUMMARY }

const SAVE_PATH := "user://save3d.json"
const REACH := 2.1
const SLOT_X := [-1.15, -0.1, 0.8]
const WINDOW_Z := -2.0
const LANE_Z := -3.0
const MONEY_PILL := Vector2(40, 36)
const CHARACTERS := ["female-a", "female-b", "female-c", "female-e",
	"male-a", "male-b", "male-d", "male-e", "male-f"]   # male-c, female-d, female-f are the staff

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
const OrdersS := preload("res://scripts3d/orders_ui.gd")
const CafeS := preload("res://scripts3d/cafe3d.gd")
const StaffS := preload("res://scripts3d/staff3d.gd")
const LAST_DAY := 15

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
var orders: Node2D
var cafe: Node3D
var staff: Node3D
var shop_tab := "kitchen"

var day := 1
var bank := 0
var sound_on := true
var up := {}              # upgrade id -> level
var stars_hist: Array = []

var shift_t := 0.0
var is_open := false
var closing_t := 0.0
var spawn_t := 0.0
var rush := false
var rush_k := 0.0
var slots: Array = [null, null, null]     # window (takeaway) customers
var diners: Array = []                    # café guests at tables
var stats := {}
var ratings: Array = []
var goal := 1500
var money_today := 0
var unlocked: Array = []
var tutorial_left := 0
var combo := 0
var event := {}
var mods := {"patience": 1.0, "spawn": 1.0, "tips": 1.0}


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
	grill.position = Vector3(1.72, 1.0, 0.55)
	add_child(grill)
	cafe = CafeS.new()
	add_child(cafe)
	staff = StaffS.new()
	staff.game = self
	add_child(staff)
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
	orders = OrdersS.new()
	orders.cam = player.cam
	fx_layer.add_child(orders)
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
	hud.next_day_pressed.connect(_after_summary)
	hud.shop_pressed.connect(_show_shop)
	hud.shop_closed.connect(_shop_closed)
	hud.buy_pressed.connect(_buy)
	hud.shop_tab.connect(func(tab: String):
		shop_tab = tab
		_show_shop()
	)
	hud.endless_pressed.connect(_show_shop)
	hud.new_game_pressed.connect(_new_game)
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
	_apply_cafe()
	_to_menu()


func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	hud.set_width(vs.x)
	orders.screen_w = vs.x
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
	hud.show_menu(day, bank, sound_on, day > 1)


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
	hud.show_note(day, Bal.note_for(day), goal, fresh, Bal.event_for(day))


func _start_shift() -> void:
	hud.clear_screen()
	hud.set_bar_visible(true)
	_clear_table()
	bins.set_unlocked(unlocked)
	_apply_upgrades()
	_apply_cafe()
	event = Bal.event_for(day)
	mods["patience"] *= float(event.get("patience", 1.0))
	mods["spawn"] *= float(event.get("spawn", 1.0))
	world.set_rain(event.get("rain", false))
	Sfx.set_rain(event.get("rain", false))
	combo = 0
	hud.bar.combo = 0
	stats = {"served": 0, "lost": 0, "revenue": 0, "tips": 0, "dine": 0}
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
	var sub := "Цель: %d ₽   ·   слева джойстик, справа — обзор" % goal
	if not event.is_empty():
		sub = "Цель: %d ₽   ·   %s" % [goal, event["title"]]
	fx.banner("День %d — смена началась!" % day, sub, DU.ORANGE, 200.0)


func _close() -> void:
	is_open = false
	closing_t = 0.0
	fx.banner("Закрываемся!", "Обслужи тех, кто ждёт", Color("#8e7dff"), 200.0)


func _end_shift() -> void:
	g = G.SUMMARY
	touch.enabled = false
	for c in all_customers():
		if c.st == CustomerS.St.WAIT:
			c.leave(_exit_path(c), "Завтра зайду", "meh")
	slots = [null, null, null]
	diners.clear()
	staff.reset_all()
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
	var wages := _wages()
	bank += money_today - wages
	stars_hist.append(stars)
	world.set_rain(false)
	Sfx.set_rain(false)
	var summary := {"stars": stars, "served": stats["served"], "lost": stats["lost"], "revenue": stats["revenue"],
		"tips": stats["tips"], "rating": _rating(), "total": money_today - wages, "goal": goal, "wages": wages}
	day += 1
	_save()
	Sfx.play("jingle", 0.0)
	hud.show_summary(summary)


func _clear_table() -> void:
	for c in customers_root.get_children():
		c.queue_free()
	slots = [null, null, null]
	diners.clear()
	for i in cafe.tables.size():
		cafe.set_state(i, "free")
	staff.reset_all()
	orders.customers = []
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
	hud.show_menu(day, bank, sound_on, day > 1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if get_tree().paused:
			_resume()
		elif g == G.PLAYING:
			_pause()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if g == G.PLAYING:
			_pause()


# --- Upgrades, shop, finale ---------------------------------------------------------

func _lv(id: String) -> int:
	return int(up.get(id, 0))


func _apply_upgrades() -> void:
	var cap := int(Bal.f("spit_capacity")) + 4 * _lv("spit")
	spit.setup(cap, Bal.f("spit_regen_seconds") / (1.0 + 0.5 * _lv("spit")))
	grill.set_unlocked(int(Bal.f("grill_slots")) + _lv("grill3"))
	grill.speed = 1.0 + 0.25 * _lv("turbo")
	player.speed_mult = 1.0 + 0.3 * _lv("shoes")
	mods = {
		"patience": 1.0 + 0.15 * _lv("garland"),
		"spawn": 1.0 / (1.0 + 0.15 * _lv("neon")),
		"tips": 1.0 + 0.2 * _lv("tipjar"),
	}
	world.set_decor(up)


## Shop cards for one tab ("" = all tabs).
func _shop_items(tab := "") -> Array:
	var items: Array = []
	for u in Bal.upgrades:
		if tab != "" and u.get("tab", "kitchen") != tab:
			continue
		var lv := _lv(u["id"])
		var prices: Array = u["prices"]
		var desc: String = u["desc"]
		if u.has("wage"):
			desc += " · зарплата %d ₽ за смену" % int(u["wage"])
		var locked := ""
		if u.has("requires") and _lv(u["requires"]) == 0:
			locked = "Нужно кафе"
		items.append({"id": u["id"], "name": u["name"], "desc": desc, "level": lv, "max": prices.size(),
			"price": int(prices[lv]) if lv < prices.size() else -1, "locked": locked})
	return items


func _show_shop() -> void:
	touch.enabled = false
	hud.show_shop(bank, _shop_items(shop_tab), shop_tab)


func _buy(id: String) -> void:
	for it in _shop_items():
		if it["id"] == id and it["locked"] == "" and it["price"] >= 0 and it["price"] <= bank:
			bank -= it["price"]
			up[id] = _lv(id) + 1
			_save()
			world.set_decor(up)
			_apply_cafe()
	hud.show_shop(bank, _shop_items(shop_tab), shop_tab)


func _shop_closed() -> void:
	if g == G.MENU:
		hud.show_menu(day, bank, sound_on, day > 1)
	else:
		_show_note()


func _after_summary() -> void:
	shop_tab = "cafe" if _lv("cafe") == 0 else "kitchen"
	if day == LAST_DAY + 1 and stars_hist.size() >= LAST_DAY:
		var total := 0
		for st in stars_hist.slice(0, LAST_DAY):
			total += int(st)
		var f := Bal.finale_for(total)
		Sfx.play("jingle", 0.0)
		hud.show_finale(total, LAST_DAY * 3, f["title"], f["text"])
		return
	_show_shop()


func _new_game() -> void:
	day = 1
	bank = 0
	up = {}
	stars_hist = []
	_save()
	world.set_decor(up)
	_apply_cafe()
	_to_menu()


## Builds the café terrace, the kiosk passage and the hired staff from the upgrades.
func _apply_cafe() -> void:
	var on := _lv("cafe") > 0
	var count := 2 + 2 * _lv("tables") if on else 0
	if cafe.root == null or cafe.enabled != on or cafe.tables.size() != count:
		world.set_cafe(on)
		cafe.build(on, count)
	var roles: Array = []
	for r in ["helper", "waiter", "cleaner"]:
		if _lv(r) > 0:
			roles.append(r)
	staff.hire(roles)


func _wages() -> int:
	var total := 0
	for u in Bal.upgrades:
		if u.has("wage") and _lv(u["id"]) > 0:
			total += int(u["wage"])
	return total


func _combo_mult() -> float:
	return 1.0 + 0.1 * clampi(combo - 1, 0, 5)


func _set_combo(n: int) -> void:
	combo = n
	hud.bar.combo = combo
	hud.bar.combo_mult = _combo_mult()
	if combo >= 2:
		hud.bar.combo_bump = 1.0


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
		rush = hour >= float(event.get("rush_from", Bal.f("rush_from_hour"))) and hour < Bal.f("rush_to_hour")
		if rush and not was:
			fx.banner("НОЧНОЙ ЧАС ПИК!", "Чаевые ×2", Color("#ff4fa3"), 200.0)
			Sfx.play("jingle", 0.0)
			Sfx.music.pitch_scale = 1.08
		elif was and not rush:
			fx.banner("Час пик позади", "", Color("#8e7dff"), 200.0)
			Sfx.music.pitch_scale = 1.0
		spawn_t -= delta
		if spawn_t <= 0.0:
			if _free_slot() >= 0 or (cafe.enabled and cafe.free_table() >= 0):
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
	staff.tick(delta)
	orders.customers = all_customers()
	orders.board_open = board.state == BoardS.S.OPEN
	orders.board_items = board.items
	orders.board_meat = board.meat
	orders.held = player.held
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
		v *= float(event.get("rush_spawn", Bal.f("rush_spawn_mult")))
	if tutorial_left > 0:
		v *= 1.8
	v *= mods["spawn"]
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
	return all_customers().size()


## Every customer still in the scene (window and café tables).
func all_customers() -> Array:
	var list: Array = []
	for c in slots:
		if c != null and is_instance_valid(c):
			list.append(c)
	for c in diners:
		if is_instance_valid(c):
			list.append(c)
	return list


func _waiting() -> Array:
	var list: Array = []
	for c in all_customers():
		if c.st == CustomerS.St.WAIT:
			list.append(c)
	list.sort_custom(func(a, b): return a.patience < b.patience)
	return list


## The waiting customer a finished roll is for (exact fillings), most impatient first.
func customer_for(made: Dictionary):
	for c in _waiting():
		if c.got_roll.is_empty() and not c.has_meta("waiter_roll") and c.order.matches(made):
			return c
	return null


## Next waiting customer whose roll nobody is making yet (for the helper cook).
func next_uncovered():
	var taken: Array = []
	for i in grill.unlocked:
		if grill.slots[i] != null:
			taken.append(customer_for(grill.slots[i]["made"]))
	if not player.held.is_empty() and not player.held.has("drink"):
		taken.append(customer_for(player.held))
	for c in _waiting():
		if c.got_roll.is_empty() and not c.has_meta("waiter_roll") and not taken.has(c):
			return c
	return null


func _pick_type() -> Dictionary:
	var pool: Array = []
	var total := 0.0
	var weights: Dictionary = event.get("weights", {})
	for ct in Bal.customers:
		var all_day: bool = event.get("taxi_all_day", false) and ct["type_id"] == "taxi"
		if int(ct["min_day"]) > day or (ct["rush_only"] and not rush and not all_day):
			continue
		pool.append(ct)
		total += float(ct["weight"]) * float(weights.get(ct["type_id"], 1.0))
	var r := rng.randf() * total
	for ct in pool:
		r -= float(ct["weight"]) * float(weights.get(ct["type_id"], 1.0))
		if r <= 0.0:
			return ct
	return pool[0]


func _spawn() -> void:
	var slot := _free_slot()
	var table: int = cafe.free_table() if cafe.enabled else -1
	var dine := table >= 0 and (slot < 0 or rng.randf() < Bal.f("dine_chance"))
	if not dine and slot < 0:
		return
	var ct := _pick_type()
	var defs: Array = []
	for id in unlocked:
		var kind: String = Bal.ing_by_id[id]["kind"]
		if kind == "veg" or kind == "sauce":
			defs.append(Bal.ing_by_id[id])
	var order := Order.generate(rng, defs, ct, Bal.b)
	order.drink = dine and rng.randf() < Bal.f("drink_chance")
	var pat := (Bal.f("patience_base") + Bal.f("patience_per_item") * order.items.size()) * float(ct["patience_mult"])
	if dine:
		pat *= Bal.f("dine_patience")
	if rush:
		pat *= Bal.f("rush_patience_mult")
	if tutorial_left > 0:
		pat *= 3.0
	pat *= Bal.tune["patience"] * 1.25 * mods["patience"]   # walking around the kiosk takes time
	var used: Array = []
	for c in all_customers():
		used.append(c.get_meta("model"))
	var model_name: String = CHARACTERS[rng.randi_range(0, CHARACTERS.size() - 1)]
	var tries := 0
	while used.has(model_name) and tries < 20:
		model_name = CHARACTERS[rng.randi_range(0, CHARACTERS.size() - 1)]
		tries += 1
	var c := CustomerS.new()
	c.set_meta("model", model_name)
	customers_root.add_child(c)
	c.setup(ct, order, pat, "res://assets/models/characters/character-%s.glb" % model_name)
	c.gave_up.connect(_on_gave_up)
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	if dine:
		c.dine = true
		c.table = table
		cafe.set_state(table, "busy")
		diners.append(c)
		c.arrive(cafe.path_in(side, table))
		return
	c.slot = slot
	slots[slot] = c
	var x: float = SLOT_X[slot]
	if cafe.enabled:
		c.arrive([Vector3(side * 9.0, 0, CafeS.LANE_Z), Vector3(CafeS.GAP_X, 0, CafeS.LANE_Z),
			Vector3(CafeS.GAP_X, 0, CafeS.INNER_Z), Vector3(x, 0, -2.6), Vector3(x, 0, WINDOW_Z)])
	else:
		c.arrive([Vector3(side * 9.0, 0, LANE_Z), Vector3(x, 0, LANE_Z), Vector3(x, 0, WINDOW_Z)])


func _exit_path(c: Node3D) -> Array:
	var side := -1.0 if c.position.x < 0.0 else 1.0
	if c.dine:
		return cafe.path_out(c.position, side)
	if cafe.enabled:
		return [Vector3(c.position.x, 0, -2.6), Vector3(CafeS.GAP_X, 0, CafeS.INNER_Z),
			Vector3(CafeS.GAP_X, 0, CafeS.LANE_Z), Vector3(side * 10.0, 0, CafeS.LANE_Z)]
	return [Vector3(c.position.x, 0, -2.8), Vector3(side * 10.0, 0, -2.8)]


## Frees the customer's place (window slot or table) when they stop waiting.
func _release(c, dirty: bool) -> void:
	if c.dine:
		diners.erase(c)
		if c.table >= 0 and c.table < cafe.tables.size():
			if dirty:
				var t: int = c.table
				get_tree().create_timer(Bal.f("eat_seconds") + 1.2).timeout.connect(func():
					if t < cafe.tables.size() and cafe.tables[t]["state"] == "busy":
						cafe.set_state(t, "dirty")
				)
			else:
				cafe.set_state(c.table, "free")
	elif c.slot >= 0 and slots[c.slot] == c:
		slots[c.slot] = null


func _on_gave_up(c) -> void:
	if c.st != CustomerS.St.WAIT:
		return
	_release(c, not c.got_roll.is_empty() or c.got_drink)
	stats["lost"] += 1
	ratings.append(1)
	hud.bar.rating = _rating()
	_set_combo(0)
	var phrases: Array = c.ctype["angry"]
	c.leave(_exit_path(c), phrases[rng.randi_range(0, phrases.size() - 1)], "angry")
	Sfx.play("angry")
	Sfx.buzz(70)
	_float(c.head_global() + Vector3(0, 0.6, 0), "Ушёл!", DU.RED, 36)


## Hands a roll or a drink to a customer (by the cook or a waiter). Returns false if they
## don't need it. When the whole order has arrived the customer pays.
func give(c, item: Dictionary, by_staff := false) -> bool:
	if c.st != CustomerS.St.WAIT or item.is_empty():
		return false
	if item.has("drink"):
		if not c.order.drink or c.got_drink:
			return false
		c.got_drink = true
	else:
		if not c.got_roll.is_empty():
			return false
		c.got_roll = item
	Sfx.play("plop", 0.1, -2.0)
	if c.complete():
		_serve(c, c.got_roll)
	elif not by_staff:
		_float(c.head_global() + Vector3(0, 0.5, 0), "Ещё напиток!" if not c.got_drink else "Теперь шаурму!", DU.CREAM, 30)
	return true


func _serve(c, made: Dictionary) -> void:
	_release(c, true)
	var ev: Dictionary = c.order.evaluate(made, Bal.b)
	var refuse := float(c.ctype.get("refuse_below", Bal.f("refuse_below_quality")))
	var perfect: bool = ev["toast"] == "perfect" and ev["accuracy"] >= 1.0
	_set_combo(combo + 1 if perfect and ev["quality"] >= refuse else 0)
	var tip_mult: float = float(c.ctype["tip_mult"]) * (Bal.f("rush_tip_mult") if rush else 1.0) * mods["tips"] * _combo_mult()
	var pay: Dictionary = c.order.payment(ev["quality"], c.patience_frac(), tip_mult, refuse, Bal.b)
	if c.dine and not pay["refused"]:
		pay["pay"] = roundi(pay["pay"] * Bal.f("dine_bonus"))
		pay["tip"] = roundi(pay["tip"] * Bal.f("dine_bonus"))
	var head: Vector3 = c.head_global() + Vector3(0, 0.55, 0)
	ratings.append(pay["stars"])
	hud.bar.rating = _rating()
	if pay["refused"]:
		stats["lost"] += 1
		c.leave(_exit_path(c), "Это не мой заказ!" if ev["accuracy"] < 0.6 else "Это есть нельзя!", "angry")
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
	var phrase: String = happy[rng.randi_range(0, happy.size() - 1)] if good else "Ну… сойдёт"
	if c.dine:
		stats["dine"] += 1
		c.eat_then_leave(Bal.f("eat_seconds"), _exit_path(c), phrase, "happy" if good else "meh")
	else:
		c.leave(_exit_path(c), phrase, "happy" if good else "meh")
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
	if combo >= 2:
		fx.float_text(Vector2(119, 130), "Комбо ×%s!" % str(snappedf(_combo_mult(), 0.01)), Color("#ff5a2a"), 30, 40.0)
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
		if c.st != CustomerS.St.WAIT:
			return
		if player.held.is_empty():
			_error(pos, "Сначала приготовь заказ")
		elif give(c, player.held):
			player.drop()
		else:
			_error(pos, "Ему это не нужно" if player.held.has("drink") else "Он уже получил шаурму")
	elif kind == "trash":
		_trash(pos)
	elif kind == "drinks":
		if not player.held.is_empty():
			_error(pos, "Руки заняты")
		else:
			player.hold({"drink": true})
			Sfx.play("clank", 0.1, -6.0)
			Sfx.buzz(15)
	elif kind.begins_with("table:"):
		var t := int(kind.substr(6))
		if t < cafe.tables.size() and cafe.tables[t]["state"] == "dirty":
			cafe.set_state(t, "free")
			_puff(CafeS.TABLES[t] + Vector3(0, 0.9, 0), Color.WHITE, 12, true)
			Sfx.play("plop", 0.1)
			Sfx.buzz(15)


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
		var wanted := false
		for c in _waiting():
			if c.got_roll.is_empty() and c.order.items.has(id):
				wanted = true
		if not wanted:
			fx.float_text(pos + Vector2(0, -80), "Этого никто не заказывал!", DU.GOLD, 26, 50.0)
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
		if player.held.has("drink"):
			_error(pos, "Это напиток — отнеси гостю")
			return
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
		if not player.held.has("drink") and float(player.held["toast"]) < from and grill.free_slot() >= 0:
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
		up = d.get("up", {})
		stars_hist = d.get("stars", [])


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"day": day, "bank": bank, "sound": sound_on, "up": up, "stars": stars_hist}))
