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
var _item := ""           # the hotbar item just picked: its name floats above its slot
var _item_t := 9.0
var _shake := 0.0
var _tex: Dictionary = {}
var _frame := 0
var _say := {}                    # a speech bubble: {"text", "node", "t"}


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


## A speech bubble over a 3D thing (the parrot) for a few seconds.
func say(text: String, node: Node3D) -> void:
	_say = {"text": text, "node": node, "t": 3.0}


## The name of a picked hotbar item fades in above its slot and fades out after 2 s.
func show_item(id: String) -> void:
	_item = id
	_item_t = 0.0


func _process(delta: float) -> void:
	for t: Dictionary in _toasts:
		t["t"] -= delta
		t["age"] += delta
	_toasts = _toasts.filter(func(t: Dictionary) -> bool: return t["t"] > 0.0)
	_goal_flash = maxf(0.0, _goal_flash - delta)
	_item_t += delta
	_frame += 1
	if not _say.is_empty():
		_say["t"] -= delta
		if _say["t"] <= 0.0 or not is_instance_valid(_say["node"]):
			_say = {}
	# Half the frames are enough for a still HUD; anything moving gets every frame.
	if _frame % 2 == 0 or _moving():
		queue_redraw()


## Something on the HUD moves or follows the 3D view right now.
func _moving() -> bool:
	if game == null or not game.playing():
		return false
	var rod: Rod = game.rod
	return not _toasts.is_empty() or not _say.is_empty() or _goal_flash > 0.0 or _item_t < 3.0 or game.shark.attacking() or game.shark.hunting() \
		or game.player.off_raft or game.hook.state == Hook.State.CHARGE or rod.state in [Rod.State.CHARGE, Rod.State.FIGHT, Rod.State.BITE] \
		or game.combat.reloading > 0.0 or game.combat.spear_cd > 0.0 or game.vitals.health < 30.0


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
	_draw_shark(vs)
	_draw_sea(vs)
	_draw_crosshair(vs)
	_draw_hotbar()
	_draw_builds()
	_draw_buttons()
	_draw_toasts(vs)
	_draw_say(vs)


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
	var day := "День %d" % dn.day
	var time := dn.clock_text()
	var dw := title.get_string_size(day, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var tw := font.get_string_size(time, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var w := 62.0 + dw + 14.0 + tw + 22.0
	var r := Rect2(vs.x - 120 - w, 40, w, 52)
	_box("pill", r, 24)
	Icons.draw(self, "moon" if dn.is_night() else "sun", r.position + Vector2(32, 26), 32.0, Color("#bcd0ff") if dn.is_night() else UiTheme.GOLD)
	_text(day, r.position + Vector2(60, 35), 24, UiTheme.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, title, 0)
	_text(time, r.position + Vector2(60 + dw + 14, 34), 18, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_LEFT, -1, font, 0)


## The goal plaque: one line (cut to fit), or opened to the full text with a hide button;
## hidden, it is a small anchor button.
func _draw_goal(_vs: Vector2) -> void:
	var g: Dictionary = game.goal_view()
	if g.is_empty():
		return
	var r := touch.goal_rect()
	var mod := Color.WHITE.lerp(Color(0.7, 1.0, 0.7), _goal_flash / 1.8)
	if game.goal_hidden:
		_ring(r.get_center(), r.size.x / 2.0, touch.held.has("goal"), mod)
		Icons.draw(self, "anchor", r.get_center(), 34.0, UiTheme.GOLD)
		return
	var w := r.size.x
	_box("plaque", r, 30, mod)
	Icons.draw(self, "anchor", r.position + Vector2(36, 31), 30.0, UiTheme.INK)
	_text(g["prog"], r.position + Vector2(w - 92, 39), 22, Color("#8a3b12"), HORIZONTAL_ALIGNMENT_RIGHT, 70, title, 0)
	if not game.goal_open:
		var t: String = g["text"]
		if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x > w - 150:
			while t.length() > 1 and font.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x > w - 150:
				t = t.substr(0, t.length() - 1)
			t = t.strip_edges() + "…"
		_text(t, r.position + Vector2(62, 39), 22, UiTheme.INK, HORIZONTAL_ALIGNMENT_LEFT, w - 150, font, 0)
		return
	draw_multiline_string(font, r.position + Vector2(62, 39), g["text"], HORIZONTAL_ALIGNMENT_LEFT, w - 160, 22, 3, UiTheme.INK)
	var hb: Rect2 = touch.buttons["goal_hide"]["rect"]
	_box("pill", hb, 17)
	_text("Скрыть", hb.position + Vector2(0, 28), 19, UiTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER, hb.size.x, font, 0)


## While the shark attacks: a red warning under the goal and an arrow toward it.
func _draw_shark(vs: Vector2) -> void:
	var sh: Shark = game.shark
	if not sh.attacking() and not sh.hunting():
		return
	var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 140.0)
	var warn := "Акула плывёт к тебе! Скорее на плот" if sh.hunting() else "Акула атакует плот!"
	_label_pill_col(warn, Vector2(vs.x / 2.0 - 30, _below_goal()), Color("#ff8a7a", pulse))
	var cam: Camera3D = game.player.cam
	var p: Vector3 = sh.global_position
	var c := vs / 2.0
	var dir: Vector2
	if cam.is_position_behind(p):
		var sp := cam.unproject_position(p)
		dir = (c - sp).normalized()
	else:
		var sp := cam.unproject_position(p)
		if Rect2(Vector2(60, 60), vs - Vector2(120, 120)).has_point(sp):
			draw_arc(sp, 40.0 * pulse, 0, TAU, 32, Color("#ff5a4a", 0.9), 4.0, true)
			return
		dir = (sp - c).normalized()
	var edge := c + dir * minf(vs.x * 0.42, vs.y * 0.4)
	var tip := edge + dir * 26.0
	var side := dir.orthogonal() * 18.0
	draw_colored_polygon(PackedVector2Array([tip, edge + side, edge - side]), Color("#ff5a4a", pulse))
	Icons.draw(self, "spear", edge - dir * 34.0, 40.0, Color(1, 1, 1, pulse))


## Where a warning pill goes: under the goal plaque, however big it is now.
func _below_goal() -> float:
	return touch.goal_rect().end.y + 26.0


## An island alongside (drop the anchor!) and, off the raft, a marker toward it.
func _draw_sea(vs: Vector2) -> void:
	var trips: SeaTrips = game.trips
	var isl := trips.islands.island
	if isl and not trips.islands.anchored and trips.islands.near() and not game.player.off_raft and not game.shark.attacking():
		var pulse := 0.8 + 0.2 * sin(Time.get_ticks_msec() / 200.0)
		var tip := "Остров рядом — брось якорь!" if game.raft.count_stations("anchor") > 0 else "Остров рядом! Нужен якорь"
		_label_pill_col(tip, Vector2(vs.x / 2.0 - 30, _below_goal()), Color("#9be59b", pulse))
	if game.player.off_raft:
		_marker(game.raft.global_transform * game.raft.centroid() + Vector3(0, 1.0, 0), "Плот %d м" % int(trips.raft_dist()), vs)


## A label over a world point; at the screen edge with an arrow when it is off screen.
func _marker(p: Vector3, text: String, vs: Vector2) -> void:
	var cam: Camera3D = game.player.cam
	var c := vs / 2.0
	var sp := cam.unproject_position(p)
	var inside := not cam.is_position_behind(p) and Rect2(Vector2(80, 120), vs - Vector2(160, 300)).has_point(sp)
	if inside:
		_label_pill(text, sp)
		return
	var dir := (sp - c).normalized() if not cam.is_position_behind(p) else (c - sp).normalized()
	var edge := c + dir * minf(vs.x * 0.4, vs.y * 0.36)
	var side := dir.orthogonal() * 14.0
	draw_colored_polygon(PackedVector2Array([edge + dir * 22.0, edge + side, edge - side]), UiTheme.GOLD)
	_label_pill(text, edge - dir * 40.0)


func _label_pill_col(text: String, c: Vector2, col: Color) -> void:
	var w := title.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 40.0
	var r := Rect2(c - Vector2(w / 2.0, 20), Vector2(w, 40))
	_box("pill", r, 19)
	_text(text, r.position + Vector2(0, 28), 24, col, HORIZONTAL_ALIGNMENT_CENTER, w, title, 0)


func _draw_crosshair(vs: Vector2) -> void:
	var c := vs / 2.0
	if game.grab_target or game.station_target or game.net_target:
		draw_arc(c, 15.0, 0, TAU, 28, Color(1, 1, 1, 0.9), 3.0, true)
	draw_circle(c, 3.0, Color(1, 1, 1, 0.85))
	var power := -1.0
	if game.hook.state == Hook.State.CHARGE:
		power = game.hook.power
	elif game.rod.state == Rod.State.CHARGE:
		power = game.rod.power
	if power >= 0.0:
		_power_bar(Rect2(c + Vector2(-80, 44), Vector2(160, 18)), power)
	if game.rod.state == Rod.State.FIGHT:
		_draw_fight(c)
	if game.rod.state == Rod.State.BITE:
		var s := 1.0 + 0.15 * sin(Time.get_ticks_msec() / 50.0)
		Icons.draw(self, "exclamation", c + Vector2(0, -80), 70.0 * s, Color("#ffd24a"))
		_text("Клюёт! Жми!", c + Vector2(-150, 100), 38, Color("#ffd24a"), HORIZONTAL_ALIGNMENT_CENTER, 300, title)


## Playing a hooked fish: how far it is (fish → hook) and the line's tension, with the
## hint that matters right now.
func _draw_fight(c: Vector2) -> void:
	var rod: Rod = game.rod
	var w := 300.0
	var top := c + Vector2(-w / 2.0, 70)
	# Distance: the fish icon slides toward the hook as it comes in.
	var track := Rect2(top, Vector2(w, 10))
	_round_rect(track.grow(3.0), Color(0.02, 0.06, 0.08, 0.7), 8.0)
	_round_rect(Rect2(track.position, Vector2(track.size.x * rod.progress, track.size.y)), Color("#6fc0e8"), 5.0)
	Icons.draw(self, "hook", track.end + Vector2(18, -5), 34.0)
	var shake := Vector2(sin(Time.get_ticks_msec() / 25.0), 0) * (5.0 if rod.jerking else 0.0)
	Icons.draw(self, rod.fish, track.position + Vector2(track.size.x * rod.progress, 5) + shake, 44.0)
	# Tension: a bar that turns red near the top; the last fifth is the danger zone.
	var bar := Rect2(top + Vector2(0, 36), Vector2(w, 18))
	_round_rect(bar.grow(2.0), Color(0.02, 0.06, 0.08, 0.75), 11.0)
	_round_rect(Rect2(bar.position + Vector2(w * 0.8, 0), Vector2(w * 0.2, bar.size.y)), Color(0.7, 0.1, 0.05, 0.45), 9.0)
	var t := rod.tension
	var col := Color("#6cd36c").lerp(Color("#f0c040"), clampf(t * 1.6, 0.0, 1.0)).lerp(Color("#ff4a3a"), clampf((t - 0.6) * 2.5, 0.0, 1.0))
	_round_rect(Rect2(bar.position, Vector2(maxf(bar.size.y, w * t), bar.size.y)), col, 9.0)
	_round_rect_border(bar, Color(0, 0, 0, 0), UiTheme.GOLD, 9.0, 2)
	_text("Натяжение", bar.position + Vector2(0, 40), 18, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_LEFT, -1, font)
	var hint := "Держи и тяни"
	if rod.jerking:
		hint = "Рыба дёргает — отпусти!"
	elif rod.warning:
		hint = "Сейчас дёрнет — отпускай!"
	elif rod.tension >= 0.75:
		hint = "Леска на пределе — отпусти!"
	var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 90.0)
	var hc := Color("#ff8a7a", pulse) if rod.jerking or rod.tension >= 0.75 else (Color("#ffb35a", pulse) if rod.warning else Color("#ffd24a"))
	_text(hint, c + Vector2(-320, -70), 34, hc, HORIZONTAL_ALIGNMENT_CENTER, 640, title)


## The charge bar: a dark rounded frame with a gold rim and a rounded fill inset inside it.
func _power_bar(r: Rect2, power: float) -> void:
	var h := r.size.y
	_round_rect(r.grow(2.0), Color(0.02, 0.06, 0.08, 0.75), (h + 4.0) / 2.0)
	_round_rect_border(r, Color(0.04, 0.12, 0.15, 0.95), UiTheme.GOLD, h / 2.0, 2)
	var inner := r.grow(-4.0)
	var ih := inner.size.y
	var w := ih + (inner.size.x - ih) * power
	var fill := Rect2(inner.position, Vector2(w, ih))
	var col := UiTheme.GOLD.lerp(Color("#ff6a3d"), power)
	if power >= 1.0:
		col = col.lerp(Color.WHITE, 0.2 + 0.2 * sin(Time.get_ticks_msec() / 60.0))
	_round_rect(fill, col, ih / 2.0)
	_round_rect(Rect2(fill.position + Vector2(ih * 0.4, ih * 0.16), Vector2(maxf(0.0, w - ih * 0.8), ih * 0.28)), Color(1, 1, 1, 0.38), ih * 0.14)


func _round_rect_border(r: Rect2, bg: Color, border: Color, radius: float, bw: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	sb.draw(get_canvas_item(), r)


func _round_rect(r: Rect2, col: Color, radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	sb.draw(get_canvas_item(), r)


func _draw_buttons() -> void:
	var b: Dictionary = touch.buttons
	var held: Dictionary = touch.held
	var a: Dictionary = b["action"]
	var act: Dictionary = game.action_view()
	_ring(a["c"], a["r"], held.has("action"), Color.WHITE if act["ok"] else Color(0.7, 0.7, 0.7))
	Icons.draw(self, act["icon"], a["c"] + Vector2(0, -10), 92.0, Color.WHITE if act["ok"] else Color(1, 1, 1, 0.55))
	if float(act.get("cooldown", 0.0)) > 0.0:
		draw_arc(a["c"], a["r"] - 6, -PI / 2.0, -PI / 2.0 + TAU * float(act["cooldown"]), 48, UiTheme.GOLD, 6.0, true)
	_label_pill(act["label"], a["c"] + Vector2(0, a["r"] - 4))
	if act.has("cost"):
		_cost_row(act["cost"], a["c"] + Vector2(a["r"] + 10, -a["r"] - 24), true)
	var u: Dictionary = b["use"]
	if u["on"]:
		var use: Dictionary = game.use_view()
		_ring(u["c"], u["r"], held.has("use"), Color.WHITE if use["ok"] else Color(0.7, 0.7, 0.7))
		if use.has("progress"):
			draw_arc(u["c"], u["r"] - 4, -PI / 2.0, -PI / 2.0 + TAU * float(use["progress"]), 40, UiTheme.GOLD, 6.0, true)
		Icons.draw(self, use["icon"], u["c"] + Vector2(0, -4), 66.0, Color.WHITE if use["ok"] else Color(1, 1, 1, 0.6))
		_label_pill(use["label"], u["c"] + Vector2(0, u["r"] - 2))
	var rb: Dictionary = b["rotate"]
	if rb["on"]:
		_ring(rb["c"], rb["r"], held.has("rotate"))
		Icons.draw(self, "rotate", rb["c"], 40.0, UiTheme.CREAM)
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
		var k: float = game.actions.condition(bar[i])
		if k >= 0.0:
			var wr := Rect2(c + Vector2(-r * 0.62, r * 0.5), Vector2(r * 1.24, 6))
			draw_rect(wr.grow(1.0), Color(0.02, 0.06, 0.08, 0.85))
			draw_rect(Rect2(wr.position, Vector2(maxf(2.0, wr.size.x * k), wr.size.y)), CraftPanel.wear_color(k))
	var at := bar.find(_item)
	if at >= 0 and _item_t < 2.5:
		var a := minf(_item_t / 0.25, 1.0) * clampf((2.5 - _item_t) / 0.5, 0.0, 1.0)
		var slot: Dictionary = b["slot%d" % at]
		var text := Data.item_name(_item)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 30.0
		var pc: Vector2 = slot["c"] - Vector2(0, float(slot["r"]) + 34.0 + (1.0 - a) * 8.0)
		_box("pill", Rect2(pc - Vector2(w / 2.0, 18), Vector2(w, 36)), 17, Color(1, 1, 1, a))
		_text(text, pc + Vector2(-w / 2.0, 7), 20, Color(UiTheme.CREAM, a), HORIZONTAL_ALIGNMENT_CENTER, w, font, 0)


## The build button above the hotbar: what the hammer builds; tap to choose another.
func _draw_builds() -> void:
	var ids: Array = game.build_choices()
	if ids.is_empty():
		return
	var s: Dictionary = touch.buttons["build0"]
	var c: Vector2 = s["c"]
	var r: float = s["r"]
	if ids[0] == "":
		# The hammer was just taken: nothing chosen yet.
		draw_texture_rect(_tex["slot_sel"], Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)
		Icons.draw(self, "plus", c, r * 1.1, UiTheme.GOLD)
		_label_pill("Что строить?", c + Vector2(0, -r - 20))
		return
	var can: bool = game.inv.has_all(Data.build_by_id[ids[0]]["cost"])
	draw_texture_rect(_tex["slot_sel"], Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, Color.WHITE if can else Color(1, 0.7, 0.65))
	Icons.draw(self, ids[0], c, r * 1.6)
	draw_circle(c + Vector2(r * 0.72, -r * 0.72), 15.0, Color(0.03, 0.1, 0.13, 0.9))
	Icons.draw(self, "plus", c + Vector2(r * 0.72, -r * 0.72), 22.0, UiTheme.GOLD)
	_label_pill(Data.build_by_id[ids[0]]["name"], c + Vector2(0, -r - 20))


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


## The speech bubble: white, rounded, a little tail pointing at the speaker.
func _draw_say(vs: Vector2) -> void:
	if _say.is_empty():
		return
	var node: Node3D = _say["node"]
	var cam: Camera3D = game.player.cam
	var p := node.global_position + Vector3(0, 0.72, 0)
	if cam.is_position_behind(p) or cam.global_position.distance_to(p) > 24.0:
		return
	var sp := cam.unproject_position(p)
	if not Rect2(Vector2.ZERO, vs).grow(-40.0).has_point(sp):
		return
	var t: float = _say["t"]
	var a := clampf(t / 0.4, 0.0, 1.0) * clampf((3.0 - t) / 0.2, 0.0, 1.0)
	var text: String = _say["text"]
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 36.0
	var r := Rect2(sp - Vector2(w / 2.0, 62.0), Vector2(w, 46.0))
	draw_colored_polygon(PackedVector2Array([sp + Vector2(-12, -18), sp + Vector2(10, -18), sp + Vector2(-2, -2)]), Color(1, 1, 1, 0.95 * a))
	_round_rect_border(r, Color(1, 1, 1, 0.95 * a), Color(0.3, 0.22, 0.14, 0.8 * a), 18.0, 2)
	_text(text, Vector2(r.position.x + 18.0, r.position.y + 31.0), 22, Color(0.12, 0.1, 0.08, a), HORIZONTAL_ALIGNMENT_LEFT, -1, font, 0)
