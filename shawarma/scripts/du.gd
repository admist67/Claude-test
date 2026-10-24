class_name DU
## Sticker-style drawing helpers (thick plum outline + hard drop shadow) and the
## procedural art for ingredients and the shawarma roll.

const INK := Color("#2b1d33")
const SHADOW := Color(0.17, 0.11, 0.2, 0.35)
const CREAM := Color("#fff1d6")
const ORANGE := Color("#ff8a3d")
const GREEN := Color("#3ccf7a")
const RED := Color("#ff4d5e")
const GOLD := Color("#ffc93c")
const FONT: FontFile = preload("res://assets/fonts/Nunito-900.ttf")
const FONT_B: FontFile = preload("res://assets/fonts/Nunito-800.ttf")

const LAVASH := Color("#f3d39b")
const LAVASH_SPOT := Color("#d9a35f")
const MEAT := Color("#b5652d")
const MEAT_DARK := Color("#8a4a22")


static func rrect_pts(r: Rect2, rad: float, seg := 5) -> PackedVector2Array:
	# Keep a sliver of straight edge: touching corner arcs give duplicate points and the
	# polygon fails to triangulate.
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5 - 0.6)
	if rad < 1.0:
		return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var pts := PackedVector2Array()
	var centers := [
		Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
	for k in 4:
		var a0 := -PI / 2.0 + k * PI / 2.0
		for i in seg + 1:
			var a := a0 + (PI / 2.0) * i / seg
			pts.append(centers[k] + Vector2(cos(a), sin(a)) * rad)
	return pts


static func closed(pts: PackedVector2Array) -> PackedVector2Array:
	var c := pts.duplicate()
	c.append(pts[0])
	return c


static func poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, ow := 4.0, shadow := 0.0) -> void:
	if shadow > 0.0:
		ci.draw_colored_polygon(Transform2D(0.0, Vector2(0, shadow)) * pts, SHADOW)
	ci.draw_colored_polygon(pts, fill)
	if ow > 0.0:
		ci.draw_polyline(closed(pts), INK, ow, true)


static func rect(ci: CanvasItem, r: Rect2, rad: float, fill: Color, ow := 4.0, shadow := 6.0) -> void:
	poly(ci, rrect_pts(r, rad), fill, ow, shadow)


static func circle(ci: CanvasItem, c: Vector2, r: float, fill: Color, ow := 4.0, shadow := 0.0) -> void:
	if shadow > 0.0:
		ci.draw_circle(c + Vector2(0, shadow), r, SHADOW)
	ci.draw_circle(c, r, fill)
	if ow > 0.0:
		ci.draw_arc(c, r, 0.0, TAU, maxi(16, int(r)), INK, ow, true)


static func ellipse_pts(c: Vector2, rx: float, ry: float, n := 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## Text centred on `c` (vertically roughly on the cap height).
static func text(ci: CanvasItem, c: Vector2, s: String, size: int, color: Color, outline := 0, font: Font = FONT, outline_color := INK) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(c.x - w / 2.0, c.y + size * 0.36)
	if outline > 0:
		ci.draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, outline_color)
	ci.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func star(ci: CanvasItem, c: Vector2, r: float, fill: Color, ow := 3.0) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	poly(ci, pts, fill, ow)


static func coin(ci: CanvasItem, c: Vector2, r: float) -> void:
	circle(ci, c, r, GOLD, 3.0)
	ci.draw_arc(c, r * 0.68, 0.0, TAU, 20, Color("#e09b1a"), 2.5, true)
	text(ci, c + Vector2(0, -1), "₽", int(r * 1.1), Color("#b86f00"), 0, FONT)


static func lerp3(a: Color, b: Color, c: Color, t: float) -> Color:
	return a.lerp(b, t * 2.0) if t < 0.5 else b.lerp(c, (t - 0.5) * 2.0)


# --- Ingredients -------------------------------------------------------------

## Draws ingredient `id` as an icon of radius ~s around c.
static func ing(ci: CanvasItem, id: String, c: Vector2, s: float, ow := 3.0) -> void:
	match id:
		"lavash":
			circle(ci, c, s, LAVASH, ow)
			for k in 5:
				var a := k * 2.4
				ci.draw_circle(c + Vector2(cos(a), sin(a)) * s * (0.25 + 0.12 * k), s * 0.1, LAVASH_SPOT)
		"meat":
			for k in 3:
				var off := Vector2((k - 1) * s * 0.42, (k % 2) * s * 0.18 - s * 0.08)
				var pts := Transform2D(-0.5 + k * 0.45, c + off) * rrect_pts(Rect2(-s * 0.28, -s * 0.62, s * 0.56, s * 1.24), s * 0.25)
				poly(ci, pts, MEAT if k != 1 else MEAT.lightened(0.12), ow)
				ci.draw_line(c + off + Vector2(-s * 0.1, -s * 0.3), c + off + Vector2(s * 0.08, s * 0.3), MEAT_DARK, maxf(2.0, s * 0.08))
		"tomato":
			circle(ci, c, s, Color("#e8443a"), ow)
			ci.draw_circle(c, s * 0.68, Color("#ff7566"))
			for k in 4:
				var a := k * TAU / 4.0 + 0.4
				ci.draw_circle(c + Vector2(cos(a), sin(a)) * s * 0.38, s * 0.13, Color("#ffd8a8"))
		"cucumber":
			circle(ci, c, s, Color("#3f8f34"), ow)
			ci.draw_circle(c, s * 0.78, Color("#c8eaa0"))
			for k in 5:
				var a := k * TAU / 5.0
				ci.draw_circle(c + Vector2(cos(a), sin(a)) * s * 0.36, s * 0.09, Color("#8cc063"))
		"cabbage":
			# Shredded cabbage: a pale leaf with veins and loose strips.
			var leaf := PackedVector2Array()
			for i in 15:
				var a := PI * 1.1 + PI * 0.8 * i / 14.0
				var wob := 1.0 + 0.08 * sin(i * 2.7)
				leaf.append(c + Vector2(cos(a) * s * wob, sin(a) * s * 0.9 * wob + s * 0.35))
			leaf.append(c + Vector2(s * 0.2, s * 0.55))
			poly(ci, leaf, Color("#e4f5c8"), ow)
			ci.draw_line(c + Vector2(0, s * 0.45), c + Vector2(-s * 0.1, -s * 0.5), Color("#9cc77a"), maxf(2.0, s * 0.1), true)
			for k in 3:
				ci.draw_line(c + Vector2(-s * 0.05, s * (0.2 - k * 0.25)), c + Vector2(-s * 0.55, s * (-0.05 - k * 0.22)), Color("#9cc77a"), maxf(1.5, s * 0.07), true)
			for k in 3:
				var p0 := c + Vector2(-s * 0.7 + k * s * 0.6, s * 0.75)
				ci.draw_line(p0, p0 + Vector2(s * 0.45, -s * 0.12), INK, maxf(3.0, s * 0.2), true)
				ci.draw_line(p0, p0 + Vector2(s * 0.45, -s * 0.12), Color("#cfe8a9"), maxf(1.5, s * 0.12), true)
		"onion":
			ci.draw_arc(c, s * 0.8, 0.0, TAU, 28, INK, s * 0.42 + ow * 2.0, true)
			ci.draw_arc(c, s * 0.8, 0.0, TAU, 28, Color("#c99ad6"), s * 0.42, true)
			ci.draw_arc(c, s * 0.8, 0.0, TAU, 28, Color("#f1e2f6"), s * 0.12, true)
		"fries":
			for k in 4:
				var pts := Transform2D(-0.35 + k * 0.24, c + Vector2((k - 1.5) * s * 0.36, (k % 2) * s * 0.12)) \
					* rrect_pts(Rect2(-s * 0.15, -s * 0.8, s * 0.3, s * 1.6), 3.0)
				poly(ci, pts, Color("#ffcf4a"), ow)
		"cheese":
			var pts := PackedVector2Array([c + Vector2(-s, s * 0.7), c + Vector2(s, s * 0.7), c + Vector2(s * 0.6, -s * 0.8)])
			poly(ci, pts, Color("#ffd84d"), ow)
			ci.draw_circle(c + Vector2(s * 0.3, s * 0.25), s * 0.17, Color("#e8b92e"))
			ci.draw_circle(c + Vector2(-s * 0.25, s * 0.42), s * 0.11, Color("#e8b92e"))
			ci.draw_circle(c + Vector2(s * 0.55, -s * 0.2), s * 0.09, Color("#e8b92e"))
		"jalapeno":
			# A whole green chili with a stem.
			var body := PackedVector2Array()
			for i in 13:
				var u := i / 12.0
				body.append(c + Vector2(-s * 0.75 + u * s * 1.5, -s * 0.28 + sin(u * PI) * -s * 0.18 + u * u * s * 0.45))
			for i in 13:
				var u := 1.0 - i / 12.0
				body.append(c + Vector2(-s * 0.75 + u * s * 1.5, s * 0.22 + sin(u * PI) * -s * 0.05 + u * u * s * 0.55 - u * s * 0.1))
			poly(ci, body, Color("#2f9e44"), ow)
			ci.draw_line(c + Vector2(-s * 0.5, -s * 0.1), c + Vector2(s * 0.3, -s * 0.05), Color("#7bd88f"), maxf(2.0, s * 0.12), true)
			ci.draw_line(c + Vector2(-s * 0.72, -s * 0.05), c + Vector2(-s * 1.0, -s * 0.45), INK, maxf(4.0, s * 0.22), true)
			ci.draw_line(c + Vector2(-s * 0.72, -s * 0.05), c + Vector2(-s * 1.0, -s * 0.45), Color("#6b8e23"), maxf(2.0, s * 0.12), true)
		"drink":
			# A soda can.
			rect(ci, Rect2(c.x - s * 0.5, c.y - s * 0.8, s * 1.0, s * 1.6), s * 0.18, Color("#e8443a"), ow, 0.0)
			ci.draw_rect(Rect2(c.x - s * 0.5 + 2, c.y - s * 0.2, s * 1.0 - 4, s * 0.35), Color.WHITE)
			ci.draw_rect(Rect2(c.x - s * 0.5 + 2, c.y - s * 0.8 + 2, s * 1.0 - 4, s * 0.14), Color("#c7c2dc"))
		"garlic", "hot":
			var col := Color("#fff8e6") if id == "garlic" else Color("#ff5a2a")
			var pts := PackedVector2Array()
			for i in 13:
				var a := PI * i / 12.0
				pts.append(c + Vector2(cos(a) * s * 0.75, s * 0.25 + sin(a) * s * 0.75))
			pts.append(c + Vector2(0, -s))
			poly(ci, pts, col, ow)
			ci.draw_circle(c + Vector2(-s * 0.28, s * 0.25), s * 0.15, Color(1, 1, 1, 0.7))


## Small scattered pieces of a filling as they lie on the lavash.
static func piece(ci: CanvasItem, id: String, c: Vector2, s: float, rot: float) -> void:
	match id:
		"meat":
			var pts := Transform2D(rot, c) * rrect_pts(Rect2(-s * 0.9, -s * 0.32, s * 1.8, s * 0.64), s * 0.3)
			poly(ci, pts, MEAT if int(rot * 10) % 2 == 0 else MEAT_DARK.lightened(0.15), 2.5)
		"cabbage":
			ci.draw_arc(c, s * 0.7, rot, rot + 2.2, 8, INK, s * 0.5, true)
			ci.draw_arc(c, s * 0.7, rot, rot + 2.2, 8, Color("#d9efb6"), s * 0.3, true)
		"fries":
			var pts := Transform2D(rot, c) * rrect_pts(Rect2(-s * 0.2, -s, s * 0.4, s * 2.0), 2.0)
			poly(ci, pts, Color("#ffcf4a"), 2.5)
		"onion":
			ci.draw_arc(c, s * 0.6, rot, rot + 3.5, 10, INK, s * 0.36, true)
			ci.draw_arc(c, s * 0.6, rot, rot + 3.5, 10, Color("#c99ad6"), s * 0.18, true)
		"cheese":
			var pts := Transform2D(rot, c) * rrect_pts(Rect2(-s * 0.6, -s * 0.6, s * 1.2, s * 1.2), 2.0)
			poly(ci, pts, Color("#ffd84d"), 2.5)
		"jalapeno":
			ci.draw_arc(c, s * 0.5, 0.0, TAU, 10, INK, s * 0.4, true)
			ci.draw_arc(c, s * 0.5, 0.0, TAU, 10, Color("#2f9e44"), s * 0.24, true)
		_:
			ing(ci, id, c, s * 0.75, 2.5)


# --- The roll ----------------------------------------------------------------

static func toast_color(t: float, bal: Dictionary) -> Color:
	var from := float(bal["grill_perfect_from"])
	var to := float(bal["grill_perfect_to"])
	var burnt := float(bal["grill_burnt_at"])
	if t <= from:
		return LAVASH.lerp(Color("#eab46a"), clampf(t / from, 0, 1))
	if t <= to:
		return Color("#eab46a").lerp(Color("#d48d43"), (t - from) / (to - from))
	if t <= burnt:
		return Color("#d48d43").lerp(Color("#8a5326"), (t - to) / (burnt - to))
	return Color("#8a5326").lerp(Color("#3d2418"), clampf((t - burnt) / 4.0, 0, 1))


## The wrapped shawarma centred on c. toast = seconds on the grill; filling = ids to peek out.
static func roll(ci: CanvasItem, c: Vector2, toast: float, bal: Dictionary, scale := 1.0, rot := 0.0, filling: Array = []) -> void:
	ci.draw_set_transform(c, rot, Vector2(scale, scale))
	var body := Rect2(-80, -30, 160, 60)
	var col := toast_color(toast, bal)
	rect(ci, body, 30.0, col, 4.0, 6.0)
	var from := float(bal["grill_perfect_from"])
	var marks := clampf(toast / from, 0.0, 1.0)
	if marks > 0.05:
		var mc := col.darkened(0.35)
		mc.a = marks
		for k in 5:
			var x := -52.0 + k * 24.0
			ci.draw_line(Vector2(x - 8, -22), Vector2(x + 10, 22), mc, 5.0, true)
	ci.draw_arc(Vector2(-40, 0), 22.0, -1.2, 1.2, 10, col.darkened(0.2), 3.0, true)
	# Open end with the filling peeking out.
	circle(ci, Vector2(66, 0), 24.0, col.lightened(0.08), 3.5)
	ci.draw_circle(Vector2(66, 0), 17.0, MEAT)
	var dots := filling if not filling.is_empty() else ["cucumber", "tomato"]
	for k in mini(dots.size(), 4):
		var a := k * TAU / 4.0 + 0.6
		var id: String = dots[k]
		var dc: Color = Color("#6cc24a")
		match id:
			"tomato", "hot": dc = Color("#e8443a")
			"cabbage", "garlic": dc = Color("#e9f5d5")
			"onion": dc = Color("#c99ad6")
			"fries", "cheese": dc = Color("#ffcf4a")
		ci.draw_circle(Vector2(66, 0) + Vector2(cos(a), sin(a)) * 9.0, 5.0, dc)
	if toast > float(bal["grill_burnt_at"]):
		ci.draw_circle(Vector2(-20, -6), 9.0, Color(0.15, 0.08, 0.05, 0.6))
		ci.draw_circle(Vector2(18, 8), 7.0, Color(0.15, 0.08, 0.05, 0.6))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
