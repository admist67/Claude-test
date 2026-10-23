class_name OrderBubble
## Draws a customer's order bubble in screen space: ingredient icons, patience bar and
## the customer-type badge. The bubble's tip points down at `tip`.

const CELL := 64.0


## checks: ingredient ids (and "meat") already on the board, drawn as green ticks.
static func draw(ci: CanvasItem, tip: Vector2, order: Order, patience: float, type_id: String, s := 1.0, glow := false, checks := {}) -> void:
	var icons: Array = ["meat"]
	icons.append_array(order.items)
	var cols := mini(icons.size(), 3)
	var rows := int(ceil(icons.size() / 3.0))
	var bw := cols * CELL + 30.0
	var bh := rows * CELL + 44.0
	ci.draw_set_transform(tip, 0.0, Vector2(s, s))
	var r := Rect2(-bw / 2.0, -18.0 - bh, bw, bh)
	if glow:
		DU.rect(ci, r.grow(9.0), 30.0, Color(0.24, 0.81, 0.48, 0.85), 0.0, 0.0)
	DU.rect(ci, r, 24.0, Color.WHITE, 5.0, 7.0)
	DU.poly(ci, PackedVector2Array([Vector2(-14, -22), Vector2(14, -22), Vector2.ZERO]), Color.WHITE, 0.0)
	ci.draw_polyline(PackedVector2Array([Vector2(-14, -19), Vector2.ZERO, Vector2(14, -19)]), DU.INK, 5.0, true)
	for i in icons.size():
		var in_row := mini(icons.size() - (i / 3) * 3, 3)
		var cx := -in_row * CELL / 2.0 + CELL / 2.0 + (i % 3) * CELL
		var cy := r.position.y + 14.0 + CELL / 2.0 + (i / 3) * CELL
		DU.ing(ci, icons[i], Vector2(cx, cy), 25.0, 3.0)
		if checks.has(icons[i]):
			tick(ci, Vector2(cx + 16, cy + 16), 1.3)
		if i == 0 and order.meat == 2:
			DU.circle(ci, Vector2(cx + 22, cy - 20), 15.0, DU.RED, 3.0)
			DU.text(ci, Vector2(cx + 22, cy - 21), "x2", 17, Color.WHITE)
	var bar := Rect2(r.position.x + 16, r.end.y - 24, bw - 32, 12)
	ci.draw_colored_polygon(DU.rrect_pts(bar, 6.0), Color("#e6e1ee"))
	if patience > 0.02:
		ci.draw_colored_polygon(DU.rrect_pts(Rect2(bar.position, Vector2(bar.size.x * patience, bar.size.y)), 6.0), patience_color(patience))
	ci.draw_polyline(DU.closed(DU.rrect_pts(bar, 6.0)), DU.INK, 3.0, true)
	badge(ci, r.position + Vector2(8, 8), type_id, 1.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func tick(ci: CanvasItem, c: Vector2, s := 1.0) -> void:
	DU.circle(ci, c, 9.0 * s, DU.GREEN, 2.5 * s)
	ci.draw_polyline(PackedVector2Array([c + Vector2(-5, 0) * s, c + Vector2(-1, 4) * s, c + Vector2(5, -4) * s]), Color.WHITE, 3.0 * s, true)


static func patience_color(p: float) -> Color:
	return DU.GREEN if p > 0.5 else (DU.GOLD if p > 0.25 else DU.RED)


## Small round badge for the special customer types.
static func badge(ci: CanvasItem, c: Vector2, type_id: String, s: float) -> void:
	if not type_id in ["hurry", "gourmet", "taxi", "granny", "student"]:
		return
	var col: Color = {"hurry": DU.RED, "gourmet": Color("#8e7dff"), "taxi": Color("#ffcc33"),
		"granny": Color("#ff8fab"), "student": Color("#4f7cff")}[type_id]
	DU.circle(ci, c, 18.0 * s, col, 3.5 * s)
	match type_id:
		"hurry":
			ci.draw_line(c, c + Vector2(0, -10) * s, DU.INK, 3.5 * s)
			ci.draw_line(c, c + Vector2(7, 3) * s, DU.INK, 3.5 * s)
		"gourmet":
			DU.star(ci, c, 11.0 * s, DU.GOLD, 2.5 * s)
		"taxi":
			DU.text(ci, c, "T", int(19 * s), DU.INK)
		"granny":
			ci.draw_circle(c + Vector2(-4, -2) * s, 5.0 * s, Color.WHITE)
			ci.draw_circle(c + Vector2(4, -2) * s, 5.0 * s, Color.WHITE)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-9, 0) * s, c + Vector2(9, 0) * s, c + Vector2(0, 9) * s]), Color.WHITE)
		"student":
			DU.text(ci, c, "S", int(18 * s), Color.WHITE)
