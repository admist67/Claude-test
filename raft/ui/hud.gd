class_name Hud
extends Control
## Draws the in-game overlay from the game state: ring gauges, goal plaque, clock,
## crosshair, charge bar, round buttons, hotbar, build choices and toasts. Decides nothing.

var game: Node            # main.gd
var touch: TouchControls
var font: Font
var title: Font
var _toasts: Array = []   # [{"text", "t", "icon", "age"}]
var _goal_flash := 0.0
var _shake := 0.0
var _tex: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = UiTheme.body_font()
	title = UiTheme.title_font()
	for n: String in ["ring", "ring_hot", "slot", "slot_sel", "plaque", "pill"]:
		_tex[n] = load("res://assets/ui/%s.png" % n)


func toast(text: String, icon := "") -> void:
	_toasts.push_front({"text": text, "t": 2.8, "icon": icon, "age": 0.0})
	if _toasts.size() > 5:
		_toasts.pop_back()


func flash_goal() -> void:
	_goal_flash = 1.8


func _process(delta: float) -> void:
	for t: Dictionary in _toasts:
		t["t"] -= delta
		t["age"] += delta
	_toasts = _toasts.filter(func(t: Dictionary) -> bool: return t["t"] > 0.0)
	_goal_flash = maxf(0.0, _goal_flash - delta)
	queue_redraw()


func _text(s: String, pos: Vector2, size: int, col := UiTheme.CREAM, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, f: Font = null, outline := 6) -> void:
	var fnt := f if f else font
	if outline > 0:
		draw_string_outline(fnt, pos, s, align, width, size, outline, Color(0.02, 0.06, 0.08, 0.75))
	draw_string(fnt, pos, s, align, width, size, col)


## A texture stretched as a 9-slice box.
func _box(name: String, r: Rect2, margin: float, mod := Color.WHITE) -> void:
	var t: Texture2D = _tex[name]
	var m := Vector2(margin, margin)
	var stretch := RenderingServer.NINE_PATCH_STRETCH
	RenderingServer.canvas_item_add_nine_patch(get_canvas_item(), r, Rect2(Vector2.ZERO, t.get_size()), t.get_rid(), m, m, stretch, stretch, true, mod)


func _ring(c: Vector2, r: float, hot := false, mod := Color.WHITE) -> void:
	draw_texture_rect(_tex["ring_hot" if hot else "ring"], Rect2(c - Vector2(r, r) * 1.04, Vector2(r, r) * 2.08), false, mod)


func _draw() -> void:
	if game == null or not game.playing():
		return
	var vs := get_viewport_rect().size
	_draw_hurt(vs)
	_draw_vitals()
	_draw_clock(vs)
	_draw_goal(vs)
	_draw_crosshair(vs)
	_draw_hotbar()
	_draw_builds()
	_draw_buttons()
	_draw_toasts(vs)


func _draw_hurt(vs: Vector2) -> void:
	var v: Vitals = game.vitals
	if v.cause == "":
		return
	var a := 0.32 + 0.14 * sin(Time.get_ticks_msec() / 220.0)
	var red := Color(0.75, 0.05, 0.02, a)
	var clear := Color(0.75, 0.05, 0.02, 0.0)
	var w := 120.0
	for r: Array in [[Vector2(0, 0), Vector2(vs.x, 0), Vector2(vs.x, w), Vector2(0, w)], [Vector2(0, vs.y), Vector2(vs.x, vs.y), Vector2(vs.x, vs.y - w), Vector2(0, vs.y - w)]]:
		draw_polygon(PackedVector2Array(r), PackedColorArray([red, red, clear, clear]))
	for r: Array in [[Vector2(0, 0), Vector2(0, vs.y), Vector2(w, vs.y), Vector2(w, 0)], [Vector2(vs.x, 0), Vector2(vs.x, vs.y), Vector2(vs.x - w, vs.y), Vector2(vs.x - w, 0)]]:
		draw_polygon(PackedVector2Array(r), PackedColorArray([red, red, clear, clear]))


func _draw_vitals() -> void:
	var v: Vitals = game.vitals
	var rows := [["health", v.health, Color("#ff5a5a")], ["hunger", v.hunger, Color("#f0a040")], ["thirst", v.thirst, Color("#4fb8f5")]]
	var x := 128.0
	for r: Array in rows:
		var val: float = r[1]
		var c := Vector2(x, 54)
		var low := val < 25.0
		var pulse := 1.0 + (0.08 * sin(Time.get_ticks_msec() / 120.0) if low else 0.0)
		draw_circle(c, 31.0 * pulse, Color(0.03, 0.1, 0.13, 0.62))
		draw_arc(c, 27.0 * pulse, 0, TAU, 40, Color(1, 1, 1, 0.1), 7.0, true)
		draw_arc(c, 27.0 * pulse, -PI / 2.0, -PI / 2.0 + TAU * val / 100.0, 40, Color.WHITE if low and int(Time.get_ticks_msec() / 250) % 2 == 0 else r[2], 7.0, true)
		Icons.draw(self, r[0], c, 30.0, r[2].lightened(0.25))
		x += 78.0


func _draw_clock(vs: Vector2) -> void:
	var dn: DayNight = game.daynight
	var r := Rect2(vs.x - 316, 40, 196, 52)
	_box("pill", r, 24)
	Icons.draw(self, "moon" if dn.is_night() else "sun", r.position + Vector2(30, 26), 32.0, Color("#bcd0ff") if dn.is_night() else UiTheme.GOLD)
	_text("День %d" % dn.day, r.position + Vector2(56, 35), 24, UiTheme.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, title, 0)
	_text(dn.clock_text(), r.position + Vector2(132, 35), 18, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_LEFT, -1, font, 0)


func _draw_goal(vs: Vector2) -> void:
	var g: Dictionary = game.goal_view()
	if g.is_empty():
		return
	var w := 520.0
	var r := Rect2(vs.x / 2.0 - w / 2.0 - 30, 22, w, 62)
	var mod := Color.WHITE.lerp(Color(0.7, 1.0, 0.7), _goal_flash / 1.8)
	_box("plaque", r, 30, mod)
	Icons.draw(self, "anchor", r.position + Vector2(36, 31), 30.0, UiTheme.INK)
	_text(g["text"], r.position + Vector2(62, 39), 22, UiTheme.INK, HORIZONTAL_ALIGNMENT_LEFT, w - 150, font, 0)
	_text(g["prog"], r.position + Vector2(w - 92, 39), 22, Color("#8a3b12"), HORIZONTAL_ALIGNMENT_RIGHT, 70, title, 0)


func _draw_crosshair(vs: Vector2) -> void:
	var c := vs / 2.0
	if game.grab_target or game.station_target:
		draw_arc(c, 15.0, 0, TAU, 28, Color(1, 1, 1, 0.9), 3.0, true)
	draw_circle(c, 3.0, Color(1, 1, 1, 0.85))
	var power := -1.0
	if game.hook.state == Hook.State.CHARGE:
		power = game.hook.power
	elif game.rod.state == Rod.State.CHARGE:
		power = game.rod.power
	if power >= 0.0:
		var r := Rect2(c + Vector2(-90, 46), Vector2(180, 22))
		_box("pill", r, 11)
		var col := UiTheme.CREAM.lerp(Color("#ff6a3d"), power)
		draw_rect(Rect2(r.position + Vector2(8, 7), Vector2((r.size.x - 16) * power, 8)), col)
	if game.rod.state == Rod.State.BITE:
		var s := 1.0 + 0.15 * sin(Time.get_ticks_msec() / 50.0)
		Icons.draw(self, "exclamation", c + Vector2(0, -80), 70.0 * s, Color("#ffd24a"))
		_text("Клюёт! Жми!", c + Vector2(-150, 100), 38, Color("#ffd24a"), HORIZONTAL_ALIGNMENT_CENTER, 300, title)


func _draw_buttons() -> void:
	var b: Dictionary = touch.buttons
	var held: Dictionary = touch.held
	var a: Dictionary = b["action"]
	var act: Dictionary = game.action_view()
	_ring(a["c"], a["r"], held.has("action"), Color.WHITE if act["ok"] else Color(0.7, 0.7, 0.7))
	Icons.draw(self, act["icon"], a["c"] + Vector2(0, -10), 92.0, Color.WHITE if act["ok"] else Color(1, 1, 1, 0.55))
	_label_pill(act["label"], a["c"] + Vector2(0, a["r"] - 4))
	if act.has("cost"):
		_cost_row(act["cost"], a["c"] + Vector2(-a["r"] - 30, a["r"] - 4), true)
	var u: Dictionary = b["use"]
	if u["on"]:
		var use: Dictionary = game.use_view()
		_ring(u["c"], u["r"], held.has("use"), Color.WHITE if use["ok"] else Color(0.7, 0.7, 0.7))
		if use.has("progress"):
			draw_arc(u["c"], u["r"] - 4, -PI / 2.0, -PI / 2.0 + TAU * float(use["progress"]), 40, UiTheme.GOLD, 6.0, true)
		Icons.draw(self, use["icon"], u["c"] + Vector2(0, -4), 66.0, Color.WHITE if use["ok"] else Color(1, 1, 1, 0.6))
		_label_pill(use["label"], u["c"] + Vector2(0, u["r"] - 2))
	var bag: Dictionary = b["bag"]
	_ring(bag["c"], bag["r"], held.has("bag"))
	Icons.draw(self, "bag", bag["c"], 40.0, UiTheme.CREAM)
	var p: Dictionary = b["pause"]
	_ring(p["c"], p["r"], held.has("pause"))
	Icons.draw(self, "pause", p["c"], 30.0, UiTheme.CREAM)


func _label_pill(text: String, c: Vector2) -> void:
	if text == "":
		return
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 30.0
	var r := Rect2(c - Vector2(w / 2.0, 17), Vector2(w, 34))
	_box("pill", r, 17)
	_text(text, r.position + Vector2(0, 24), 19, UiTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER, w, font, 0)


## Cost chips "icon have/need", right-aligned to `at` when `right`.
func _cost_row(cost: Dictionary, at: Vector2, right := false) -> void:
	var inv: Inventory = game.inv
	var chips: Array = []
	var total := 0.0
	for id: String in cost:
		var need := int(cost[id])
		var s := "%d/%d" % [inv.count(id), need]
		var w := 40.0 + font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 14.0
		chips.append([id, s, w, inv.count(id) >= need])
		total += w + 6.0
	var x := at.x - total if right else at.x
	for ch: Array in chips:
		var r := Rect2(Vector2(x, at.y - 18), Vector2(ch[2], 36))
		_box("pill", r, 17)
		Icons.draw(self, ch[0], r.position + Vector2(22, 18), 32.0)
		_text(ch[1], r.position + Vector2(40, 25), 18, UiTheme.CREAM if ch[3] else UiTheme.DANGER, HORIZONTAL_ALIGNMENT_LEFT, -1, font, 0)
		x += ch[2] + 6.0


func _draw_hotbar() -> void:
	var b: Dictionary = touch.buttons
	var bar: Array = game.hotbar
	for i in bar.size():
		var s: Dictionary = b["slot%d" % i]
		var sel: bool = i == game.sel
		var c: Vector2 = s["c"] - Vector2(0, 8 if sel else 0)
		var r: float = s["r"]
		draw_texture_rect(_tex["slot_sel" if sel else "slot"], Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)
		Icons.draw(self, bar[i], c, r * 1.55)
		if Data.item(bar[i]).get("kind", "") == "food":
			var n := str(game.inv.count(bar[i]))
			_text(n, c + Vector2(r - 30, r - 6), 18, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 24)


func _draw_builds() -> void:
	var b: Dictionary = touch.buttons
	var ids: Array = game.build_choices()
	for i in ids.size():
		var s: Dictionary = b["build%d" % i]
		var sel: bool = ids[i] == game.builder.kind
		var c: Vector2 = s["c"]
		var r: float = s["r"]
		var can: bool = game.inv.has_all(Data.build_by_id[ids[i]]["cost"])
		draw_texture_rect(_tex["slot_sel" if sel else "slot"], Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, Color.WHITE if can else Color(1, 0.7, 0.65))
		Icons.draw(self, ids[i], c, r * 1.6)
	if ids.size() > 0:
		var first: Dictionary = b["build0"]
		_label_pill(Data.build_by_id[game.builder.kind]["name"], first["c"] + Vector2(-first["r"] - 92, 0))


func _draw_toasts(_vs: Vector2) -> void:
	var y := 150.0
	for t: Dictionary in _toasts:
		var a := clampf(t["t"] / 0.5, 0.0, 1.0)
		var slide := (1.0 - clampf(t["age"] / 0.18, 0.0, 1.0)) * -60.0
		var w := font.get_string_size(t["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x + (72.0 if t["icon"] != "" else 32.0)
		var r := Rect2(Vector2(22 + slide, y - 22), Vector2(w, 44))
		_box("pill", r, 20, Color(1, 1, 1, a))
		var tx := r.position.x + 16
		if t["icon"] != "":
			Icons.draw(self, t["icon"], r.position + Vector2(32, 22), 38.0, Color(1, 1, 1, a))
			tx += 40
		_text(t["text"], Vector2(tx, r.position.y + 29), 21, Color(UiTheme.CREAM, a), HORIZONTAL_ALIGNMENT_LEFT, -1, font, 0)
		y += 50.0
