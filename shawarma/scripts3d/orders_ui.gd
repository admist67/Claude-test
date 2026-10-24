extends Node2D
## Screen-space order UI: bubbles projected above the customers at the window, and the
## kitchen ticket rail under the top bar for customers whose bubble is off screen (when the
## cook looks at the stations). Ticks show what is already on the board; the order that
## matches the roll in hand glows.

const CustomerS := preload("res://scripts3d/customer3d.gd")
const ICON := 30.0
const RAIL_LEFT := 400.0   # right of the quests panel (hud.gd)

var cam: Camera3D
var customers: Array = []
var board_items: Array = []
var board_meat := 0
var board_open := false
var held: Dictionary = {}
var screen_w := 1280.0
var t := 0.0


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _waiting() -> Array:
	var list: Array = []
	for c in customers:
		if c != null and is_instance_valid(c) and c.st == CustomerS.St.WAIT:
			list.append(c)
	list.sort_custom(func(a, b): return a.position.x < b.position.x)
	return list


## Customer the board / hand is most likely for.
func _focus(list: Array):
	if held.has("crate") or held.has("ext"):
		return null
	if not held.is_empty():
		for c in list:
			if held.has("drink"):
				if c.order.drink and not c.got_drink:
					return c
			elif c.needs_roll() and c.order.matches(held):
				return c
		return null
	if not board_open:
		return null
	var best = null
	var best_score := -99
	for c in list:
		if not c.needs_roll():
			continue
		var score := 0
		for id in board_items:
			score += 1 if c.order.items.has(id) else -2
		if board_meat > 0:
			score += 1 if board_meat == c.order.meat else -1
		if best == null or score > best_score or (score == best_score and c.patience < best.patience):
			best = c
			best_score = score
	return best


func _checks(c) -> Dictionary:
	var d := {}
	if c.got_drink:
		d["drink"] = true
	if not c.needs_roll():
		d["meat"] = true
		for id in c.order.items:
			d[id] = true
		return d
	if not board_open or not held.is_empty():
		return d
	if board_meat >= c.order.meat:
		d["meat"] = true
	for id in board_items:
		d[id] = true
	return d


func _draw() -> void:
	var list := _waiting()
	if list.is_empty():
		return
	var focus = _focus(list)
	var match_held := not held.is_empty()
	var vs := get_viewport_rect().size
	var off_screen: Array = []
	for c in list:
		var anchor: Vector3 = c.to_global(Vector3(0, c.bubble_h, 0))
		var p := cam.unproject_position(anchor)
		if cam.is_position_behind(anchor) or p.x < 40.0 or p.x > vs.x - 40.0 or p.y < 60.0 or p.y > vs.y:
			off_screen.append(c)
			continue
		var s: float = clampf(1.9 / cam.global_position.distance_to(anchor), 0.42, 1.0) * c.bubble_pop
		if s > 0.02:
			var ch := _checks(c) if c == focus or c.got_drink or not c.rolls.is_empty() else {}
			OrderBubble.draw(self, p, c.order, c.patience_frac(), c.ctype.get("type_id", ""), s, match_held and c == focus, ch, c.rolls.size())
	_draw_tickets(off_screen, focus)


func _draw_tickets(list: Array, focus) -> void:
	if list.is_empty():
		return
	# The rail sits right of the quests panel and wraps into a second row when full.
	var left := RAIL_LEFT
	var right := screen_w - 16.0
	var widths: Array = []
	var row_w: Array = [0.0]
	var row_of: Array = []
	for c in list:
		var w: float = (c.order.items.size() + (2 if c.order.drink else 1)) * (ICON + 8.0) + 26.0
		widths.append(w)
		if row_w[-1] > 0.0 and row_w[-1] + w > right - left:
			row_w.append(0.0)
		row_of.append(row_w.size() - 1)
		row_w[-1] += w + 12.0
	var x := 0.0
	var y := 0.0
	for i in list.size():
		var c = list[i]
		var w: float = widths[i]
		if i == 0 or row_of[i] != row_of[i - 1]:
			x = (left + right) / 2.0 - (row_w[row_of[i]] - 12.0) / 2.0
			y = 76.0 + row_of[i] * 74.0
		var r := Rect2(x, y, w, 62)
		var f: float = c.patience_frac()
		var low := f < 0.25 and fmod(t, 0.6) < 0.3
		var is_focus: bool = c == focus
		if is_focus:
			DU.rect(self, r.grow(6.0), 16.0, Color(0.24, 0.81, 0.48, 0.9) if not held.is_empty() else Color(1, 0.85, 0.3, 0.9), 0.0, 0.0)
		DU.rect(self, r, 12.0, Color("#fff8e8") if not low else Color("#ffd6d6"), 3.5, 4.0)
		draw_colored_polygon(DU.rrect_pts(Rect2(r.position.x + 4, r.end.y - 11, (r.size.x - 8) * f, 7), 3.0), OrderBubble.patience_color(f))
		var icons: Array = ["meat"]
		icons.append_array(c.order.items)
		if c.order.drink:
			icons.append("drink")
		var checks := _checks(c)
		for k in icons.size():
			var ic := Vector2(r.position.x + 18 + ICON / 2.0 + k * (ICON + 8.0), r.position.y + 25)
			var id: String = icons[k]
			DU.ing(self, id, ic, ICON * 0.45, 2.5)
			if k == 0 and c.order.meat == 2:
				DU.text(self, ic + Vector2(12, -13), "x2", 14, DU.RED, 4)
			if (is_focus or not c.rolls.is_empty() or c.got_drink) and checks.has(id):
				OrderBubble.tick(self, ic + Vector2(11, 10))
		if c.order.count > 1:
			DU.text(self, Vector2(r.end.x - 16, r.position.y + 50), "×%d" % (c.order.count - c.rolls.size()), 18, DU.RED, 4)
		if c.order.signature:
			OrderBubble.crown(self, Vector2(r.get_center().x, r.position.y - 2), 0.6)
		OrderBubble.badge(self, r.position + Vector2(4, 4), c.ctype.get("type_id", ""), 0.6)
		if c.dine:
			DU.circle(self, Vector2(r.end.x - 4, r.position.y + 4), 10.0, Color.WHITE, 2.5)
			DU.circle(self, Vector2(r.end.x - 4, r.position.y + 4), 5.0, Color("#e6e1ee"), 1.5)
		x += w + 12.0
