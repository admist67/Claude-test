class_name Hud
extends Control
## Draws the in-game overlay from the game state: vitals, crosshair, hook power, buttons,
## hotbar, current goal and pickup toasts. Decides nothing.

var game: Node            # main.gd
var touch: TouchControls
var font: Font
var _toasts: Array = []   # [{"text", "t", "icon"}]
var _goal_flash := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = get_theme_default_font()


func toast(text: String, icon := "") -> void:
	_toasts.push_front({"text": text, "t": 2.6, "icon": icon})
	if _toasts.size() > 5:
		_toasts.pop_back()


func flash_goal() -> void:
	_goal_flash = 1.6


func _process(delta: float) -> void:
	for t: Dictionary in _toasts:
		t["t"] -= delta
	_toasts = _toasts.filter(func(t: Dictionary) -> bool: return t["t"] > 0.0)
	_goal_flash = maxf(0.0, _goal_flash - delta)
	queue_redraw()


func _text(s: String, pos: Vector2, size: int, col := Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string_outline(font, pos, s, align, width, size, 6, Color(0, 0, 0, 0.55))
	draw_string(font, pos, s, align, width, size, col)


func _draw() -> void:
	if game == null or not game.playing():
		return
	var vs := get_viewport_rect().size
	_draw_hurt(vs)
	_draw_vitals()
	_draw_crosshair(vs)
	_draw_goal(vs)
	_draw_buttons()
	_draw_toasts(vs)


func _draw_hurt(vs: Vector2) -> void:
	var v: Vitals = game.vitals
	if v.cause == "":
		return
	var a := 0.18 + 0.12 * sin(Time.get_ticks_msec() / 220.0)
	var col := Color(0.9, 0.1, 0.05, a)
	var w := 60.0
	draw_rect(Rect2(0, 0, vs.x, w), col)
	draw_rect(Rect2(0, vs.y - w, vs.x, w), col)
	draw_rect(Rect2(0, 0, w, vs.y), col)
	draw_rect(Rect2(vs.x - w, 0, w, vs.y), col)


func _draw_vitals() -> void:
	var v: Vitals = game.vitals
	var rows := [["health", v.health, Color("#ff5a5a")], ["hunger", v.hunger, Color("#e8873a")], ["thirst", v.thirst, Color("#4fb3f0")]]
	var y := 30.0
	for r: Array in rows:
		var val: float = r[1]
		Icons.draw(self, r[0], Vector2(122, y + 11), 26.0)
		var rect := Rect2(142, y, 190, 22)
		draw_rect(rect, Color(0, 0, 0, 0.4))
		var low := val < 25.0 and int(Time.get_ticks_msec() / 300) % 2 == 0
		draw_rect(Rect2(rect.position + Vector2(3, 3), Vector2((rect.size.x - 6) * val / 100.0, rect.size.y - 6)), Color.WHITE if low else r[2])
		y += 32.0


func _draw_crosshair(vs: Vector2) -> void:
	var c := vs / 2.0
	if game.grab_target:
		draw_arc(c, 16.0, 0, TAU, 24, Color(1, 1, 1, 0.9), 3.0, true)
	draw_circle(c, 3.5, Color(1, 1, 1, 0.85))
	var hook: Hook = game.hook
	if hook.state == Hook.State.CHARGE:
		var r := Rect2(c + Vector2(-70, 40), Vector2(140, 14))
		draw_rect(r, Color(0, 0, 0, 0.45))
		var col := Color("#f2e6c4").lerp(Color("#ff6a3d"), hook.power)
		draw_rect(Rect2(r.position + Vector2(2, 2), Vector2((r.size.x - 4) * hook.power, r.size.y - 4)), col)


func _draw_goal(vs: Vector2) -> void:
	var g: Dictionary = game.goal_view()
	if g.is_empty():
		return
	var text: String = g["text"]
	var prog: String = g["prog"]
	var w := 520.0
	var r := Rect2(vs.x / 2.0 - w / 2.0, 14, w, 52)
	var bg := Color(0, 0, 0, 0.35).lerp(Color(0.3, 0.8, 0.4, 0.7), _goal_flash / 1.6)
	draw_rect(r, bg)
	_text(text, r.position + Vector2(16, 34), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, w - 120)
	_text(prog, r.position + Vector2(w - 100, 34), 22, Color("#f2e6c4"), HORIZONTAL_ALIGNMENT_RIGHT, 84)


func _btn_bg(c: Vector2, r: float, active: bool, pressed: bool) -> void:
	draw_circle(c, r, Color(0, 0, 0, 0.32) if not pressed else Color(1, 1, 1, 0.3))
	draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.85 if active else 0.3), 3.5, true)


func _draw_buttons() -> void:
	var b: Dictionary = touch.buttons
	var held: Dictionary = touch.held
	# Action button: the selected item and what it will do.
	var a: Dictionary = b["action"]
	var act: Dictionary = game.action_view()
	_btn_bg(a["c"], a["r"], act["ok"], held.has("action"))
	Icons.draw(self, act["icon"], a["c"] + Vector2(0, -8), 62.0)
	_text(act["label"], a["c"] + Vector2(-a["r"], 46), 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, a["r"] * 2.0)
	if act.has("cost"):
		var x: float = a["c"].x - a["r"] - 20
		var y: float = a["c"].y - a["r"] - 26
		var inv: Inventory = game.inv
		for id: String in act["cost"]:
			var need := int(act["cost"][id])
			Icons.draw(self, id, Vector2(x, y), 30.0)
			_text("%d/%d" % [inv.count(id), need], Vector2(x + 18, y + 9), 18, Color.WHITE if inv.count(id) >= need else Color("#ff8a7a"))
			x += 92.0
	var g: Dictionary = b["grab"]
	if g["on"]:
		_btn_bg(g["c"], g["r"], true, held.has("grab"))
		Icons.draw(self, "hand", g["c"] + Vector2(0, -6), 42.0)
		_text("Взять", g["c"] + Vector2(-g["r"], 36), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, g["r"] * 2.0)
	var bag: Dictionary = b["bag"]
	_btn_bg(bag["c"], bag["r"], true, held.has("bag"))
	Icons.draw(self, "bag", bag["c"], 44.0)
	var p: Dictionary = b["pause"]
	_btn_bg(p["c"], p["r"], true, held.has("pause"))
	Icons.draw(self, "pause", p["c"], 26.0)
	# Hotbar.
	var bar: Array = game.hotbar
	for i in bar.size():
		var s: Dictionary = b["slot%d" % i]
		var sel: bool = i == game.sel
		draw_circle(s["c"], s["r"], Color(1, 1, 1, 0.28) if sel else Color(0, 0, 0, 0.32))
		draw_arc(s["c"], s["r"], 0, TAU, 32, Color("#f2e6c4") if sel else Color(1, 1, 1, 0.35), 4.0 if sel else 2.0, true)
		Icons.draw(self, bar[i], s["c"], 40.0)
		var kind: String = Data.item(bar[i]).get("kind", "")
		if kind == "food":
			_text(str(game.inv.count(bar[i])), s["c"] + Vector2(10, 32), 18)


func _draw_toasts(vs: Vector2) -> void:
	var y := vs.y * 0.42
	for t: Dictionary in _toasts:
		var a := clampf(t["t"] / 0.5, 0.0, 1.0)
		var x := vs.x - 330.0
		if t["icon"] != "":
			Icons.draw(self, t["icon"], Vector2(x - 22, y - 8), 30.0)
		_text(t["text"], Vector2(x, y), 22, Color(1, 1, 1, a))
		y += 36.0
