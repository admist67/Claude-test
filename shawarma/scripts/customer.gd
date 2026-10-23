extends Node2D
## A customer at the window: procedural look, order bubble, patience and reactions.
## Origin = where the counter top crosses the customer's body.

signal gave_up(c)

enum St { ENTER, WAIT, LEAVE }

const SKINS := ["#f6d2b8", "#eab38f", "#c98a62", "#9a6243", "#6e4530", "#f3c9a5"]
const SHIRTS := ["#4f7cff", "#ff6b6b", "#2ec4b6", "#ffb703", "#8e7dff", "#ff8fab", "#43aa8b", "#f28482"]
const HAIRS := ["#2b1d1d", "#5a3a22", "#a0522d", "#e8c07d", "#1f1f2e", "#c0392b", "#d9d4cf"]

var st := St.ENTER
var ctype: Dictionary
var order: Order
var patience := 40.0
var patience_max := 40.0
var slot := 0
var look := {}
var t := 0.0
var bubble := 0.0
var say := ""
var say_t := 0.0
var face := ""          # "" = by patience; "happy" / "meh" / "angry" after the outcome
var hover := false
var blink_t := 2.0


func setup(type_def: Dictionary, o: Order, patience_s: float, slot_i: int, rng: RandomNumberGenerator) -> void:
	ctype = type_def
	order = o
	patience = patience_s
	patience_max = patience_s
	slot = slot_i
	look = {
		"skin": Color(SKINS[rng.randi_range(0, SKINS.size() - 1)]),
		"shirt": Color(SHIRTS[rng.randi_range(0, SHIRTS.size() - 1)]),
		"hair": Color(HAIRS[rng.randi_range(0, HAIRS.size() - 2)]),
		"style": rng.randi_range(0, 4),
		"glasses": type_def.get("glasses", rng.randf() < 0.15),
		"mustache": type_def.get("mustache", rng.randf() < 0.12),
		"headwear": type_def.get("headwear", ""),
		"w": rng.randf_range(0.9, 1.1),
	}
	if look["headwear"] == "scarf":
		look["hair"] = Color(HAIRS[HAIRS.size() - 1])
		look["shirt"] = Color("#8e6c8a")
	if look["headwear"] == "flatcap":
		look["shirt"] = Color("#3d5a80")
	var greet: Array = type_def["greet"]
	say = greet[rng.randi_range(0, greet.size() - 1)]


func arrive(from_x: float, to_x: float) -> void:
	position.x = from_x
	var tw := create_tween()
	tw.tween_property(self, "position:x", to_x, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_on_arrived)


func _on_arrived() -> void:
	st = St.WAIT
	say_t = 2.2
	Sfx.play("bell", 0.05, -6.0)


func leave(to_x: float, phrase: String, mood: String) -> void:
	st = St.LEAVE
	face = mood
	say = phrase
	say_t = 1.6
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(self, "position:x", to_x, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func patience_frac() -> float:
	return clampf(patience / patience_max, 0.0, 1.0)


## Global rect that accepts a dropped roll.
func drop_rect() -> Rect2:
	var g := global_position
	return Rect2(g.x - 95, g.y - 420, 190, 450)


func _process(delta: float) -> void:
	t += delta
	say_t = maxf(0.0, say_t - delta)
	blink_t -= delta
	if blink_t < -0.12:
		blink_t = randf_range(1.5, 4.0)
	if st == St.WAIT:
		bubble = minf(1.0, bubble + delta * 3.0)
		patience -= delta
		if patience <= 0.0:
			gave_up.emit(self)
	else:
		bubble = maxf(0.0, bubble - delta * 4.0)
	queue_redraw()


func _draw() -> void:
	var walking := st != St.WAIT
	var bob := absf(sin(t * 9.0)) * -8.0 if walking else sin(t * 2.2) * 2.5
	var w: float = look["w"]
	var skin: Color = look["skin"]
	var angry_tint := face == "angry" or (face == "" and patience_frac() < 0.15 and st == St.WAIT)
	if angry_tint:
		skin = skin.lerp(Color("#ff6b5b"), 0.35)
	draw_set_transform(Vector2(0, bob))
	if hover:
		DU.poly(self, DU.rrect_pts(Rect2(-82 * w, -250, 164 * w, 290), 60.0), Color(1, 0.85, 0.3, 0.35), 0.0)
	# Body.
	var shirt: Color = look["shirt"]
	DU.rect(self, Rect2(-64 * w, -132, 128 * w, 190), 46.0, shirt, 4.0, 0.0)
	DU.rect(self, Rect2(-14, -146, 28, 22), 6.0, skin.darkened(0.08), 3.0, 0.0)
	draw_arc(Vector2(0, -132), 20.0, 0.3, PI - 0.3, 10, shirt.darkened(0.3), 4.0, true)
	if look["headwear"] == "headphones":
		draw_line(Vector2(-34 * w, -120), Vector2(-40 * w, 30), Color("#2b2b3a"), 9.0)
		draw_line(Vector2(34 * w, -120), Vector2(40 * w, 30), Color("#2b2b3a"), 9.0)
	if look["headwear"] == "flatcap":
		DU.rect(self, Rect2(-50 * w, -110, 100 * w, 30), 6.0, Color("#ffcc33"), 3.0, 0.0)
		for k in 5:
			draw_rect(Rect2(-50 * w + k * 20 * w, -110 + (k % 2) * 15, 10 * w, 15), Color("#2b1d33"))
	_draw_head(Vector2(0, -186), skin)
	draw_set_transform(Vector2.ZERO)
	if bubble > 0.01 and order != null:
		_draw_bubble()
	if say_t > 0.0 and say != "":
		_draw_say()


func _draw_head(c: Vector2, skin: Color) -> void:
	var hair: Color = look["hair"]
	var style: int = look["style"]
	var hw: String = look["headwear"]
	if hw == "scarf":
		DU.circle(self, c + Vector2(0, 4), 54.0, Color("#c0587e"), 4.0)
	elif style == 1:
		DU.rect(self, Rect2(c.x - 52, c.y - 40, 104, 96), 40.0, hair, 4.0, 0.0)
	elif style == 2:
		DU.circle(self, c + Vector2(0, -50), 20.0, hair, 4.0)
	if hw != "scarf" and style != 3:
		DU.circle(self, c + Vector2(0, -6), 48.0, hair, 4.0)
	DU.circle(self, c + Vector2(-44, 4), 10.0, skin, 3.5)
	DU.circle(self, c + Vector2(44, 4), 10.0, skin, 3.5)
	DU.circle(self, c, 44.0, skin, 4.0)
	# Fringe / hats.
	if hw == "scarf":
		var pts := PackedVector2Array()
		for i in 13:
			var a := PI + PI * i / 12.0
			pts.append(c + Vector2(cos(a) * 50, sin(a) * 50 + 8))
		for i in 13:
			var a := TAU - PI * i / 12.0
			pts.append(c + Vector2(cos(a) * 38, sin(a) * 30 - 6))
		DU.poly(self, pts, Color("#c0587e"), 4.0)
		for k in 4:
			draw_circle(c + Vector2(-26 + k * 17, -34 + absf(k - 1.5) * 6), 3.5, DU.CREAM)
	elif hw == "cap":
		var cap := PackedVector2Array()
		for i in 13:
			var a := PI + PI * i / 12.0
			cap.append(c + Vector2(cos(a) * 47, sin(a) * 47 - 4))
		DU.poly(self, cap, Color("#e63946"), 4.0)
		DU.rect(self, Rect2(c.x - 10, c.y - 12, 72, 14), 7.0, Color("#c1121f"), 3.5, 0.0)
	elif hw == "flatcap":
		var fc := PackedVector2Array()
		for i in 13:
			var a := PI + PI * i / 12.0
			fc.append(c + Vector2(cos(a) * 49, sin(a) * 36 - 10))
		DU.poly(self, fc, Color("#3a3a4a"), 4.0)
		DU.rect(self, Rect2(c.x - 50, c.y - 16, 100, 12), 6.0, Color("#2a2a36"), 3.5, 0.0)
	elif hw == "beret":
		DU.poly(self, DU.ellipse_pts(c + Vector2(6, -38), 46.0, 18.0), Color("#c1121f"), 4.0)
		DU.circle(self, c + Vector2(8, -58), 5.0, Color("#c1121f"), 3.0)
	elif style != 3:
		var fr := PackedVector2Array()
		for i in 11:
			var a := PI * 1.08 + PI * 0.84 * i / 10.0
			fr.append(c + Vector2(cos(a) * 46, sin(a) * 46))
		fr.append(c + Vector2(30, -26))
		fr.append(c + Vector2(0, -18 - (style % 2) * 8))
		fr.append(c + Vector2(-30, -24))
		DU.poly(self, fr, hair, 4.0)
	else:
		draw_arc(c + Vector2(-14, -22), 12.0, 3.6, 4.6, 6, Color(1, 1, 1, 0.5), 4.0, true)
	if hw == "headphones":
		draw_arc(c + Vector2(0, -4), 52.0, PI + 0.2, TAU - 0.2, 20, Color("#2b2b3a"), 9.0, true)
		DU.rect(self, Rect2(c.x - 60, c.y - 12, 20, 34), 8.0, Color("#ff4fa3"), 3.5, 0.0)
		DU.rect(self, Rect2(c.x + 40, c.y - 12, 20, 34), 8.0, Color("#ff4fa3"), 3.5, 0.0)
	_draw_face(c)


func _draw_face(c: Vector2) -> void:
	var f := patience_frac()
	var mood := face
	if mood == "":
		mood = "happy" if f > 0.6 else ("meh" if f > 0.3 else "worried")
	var ey := c.y - 4
	if blink_t < 0.0:
		draw_line(Vector2(c.x - 22, ey), Vector2(c.x - 10, ey), DU.INK, 4.0)
		draw_line(Vector2(c.x + 10, ey), Vector2(c.x + 22, ey), DU.INK, 4.0)
	else:
		draw_circle(Vector2(c.x - 16, ey), 5.5, DU.INK)
		draw_circle(Vector2(c.x + 16, ey), 5.5, DU.INK)
		draw_circle(Vector2(c.x - 14, ey - 2), 1.8, Color.WHITE)
		draw_circle(Vector2(c.x + 18, ey - 2), 1.8, Color.WHITE)
	var brow := 0.0
	match mood:
		"angry": brow = 0.45
		"worried": brow = -0.35
	draw_line(Vector2(c.x - 26, ey - 16 - brow * 8), Vector2(c.x - 8, ey - 16 + brow * 8), DU.INK, 4.0)
	draw_line(Vector2(c.x + 8, ey - 16 + brow * 8), Vector2(c.x + 26, ey - 16 - brow * 8), DU.INK, 4.0)
	draw_circle(Vector2(c.x - 28, c.y + 12), 7.0, Color(1, 0.45, 0.5, 0.3))
	draw_circle(Vector2(c.x + 28, c.y + 12), 7.0, Color(1, 0.45, 0.5, 0.3))
	var m := Vector2(c.x, c.y + 20)
	match mood:
		"happy":
			if face == "happy":
				var pts := PackedVector2Array([m + Vector2(-14, -4), m + Vector2(14, -4)])
				for i in 9:
					var a := PI * i / 8.0
					pts.append(m + Vector2(cos(a) * 14, sin(a) * 12 - 4))
				DU.poly(self, pts, Color("#7a2335"), 3.0)
			else:
				draw_arc(m + Vector2(0, -8), 13.0, 0.35, PI - 0.35, 10, DU.INK, 4.0, true)
		"meh":
			draw_line(m + Vector2(-10, 0), m + Vector2(10, 0), DU.INK, 4.0)
		_:
			draw_arc(m + Vector2(0, 10), 12.0, PI + 0.4, TAU - 0.4, 10, DU.INK, 4.0, true)
	if look["mustache"]:
		DU.poly(self, PackedVector2Array([m + Vector2(-18, -6), m + Vector2(0, -12), m + Vector2(18, -6), m + Vector2(10, -2), m + Vector2(0, -6), m + Vector2(-10, -2)]), look["hair"], 3.0)
	if look["glasses"]:
		draw_arc(Vector2(c.x - 16, ey), 12.0, 0.0, TAU, 16, DU.INK, 3.5, true)
		draw_arc(Vector2(c.x + 16, ey), 12.0, 0.0, TAU, 16, DU.INK, 3.5, true)
		draw_line(Vector2(c.x - 4, ey), Vector2(c.x + 4, ey), DU.INK, 3.0)
	if mood == "worried" and st == St.WAIT:
		var d := c + Vector2(40, -30)
		DU.poly(self, PackedVector2Array([d + Vector2(0, -12), d + Vector2(7, 2), d + Vector2(0, 8), d + Vector2(-7, 2)]), Color("#8fd3ff"), 2.5)
	if face == "angry":
		for k in 2:
			var p := c + Vector2(-50 + k * 100, -40 - fmod(t * 40.0, 30.0))
			draw_circle(p, 9.0, Color(1, 1, 1, 0.6))


func bubble_h() -> float:
	return ceilf((order.items.size() + 1) / 3.0) * 54.0 + 36.0


func _draw_bubble() -> void:
	var icons: Array = ["meat"]
	icons.append_array(order.items)
	var cols := mini(icons.size(), 3)
	var cell := 54.0
	var bw := cols * cell + 24.0
	var bh := bubble_h()
	var bottom := -256.0
	var s := bubble
	s = s * (1.0 + 0.15 * sin(s * PI))
	draw_set_transform(Vector2(0, bottom), 0.0, Vector2(s, s))
	var r := Rect2(-bw / 2.0, -bh, bw, bh)
	DU.rect(self, r, 20.0, Color.WHITE, 4.0, 6.0)
	DU.poly(self, PackedVector2Array([Vector2(-12, -3), Vector2(12, -3), Vector2(0, 16)]), Color.WHITE, 0.0)
	draw_polyline(PackedVector2Array([Vector2(-12, 0), Vector2(0, 16), Vector2(12, 0)]), DU.INK, 4.0, true)
	for i in icons.size():
		var cx := -((mini(icons.size() - (i / 3) * 3, 3)) * cell) / 2.0 + cell / 2.0 + (i % 3) * cell
		var cy := -bh + 12 + cell / 2.0 + (i / 3) * cell
		DU.ing(self, icons[i], Vector2(cx, cy), 21.0, 2.5)
		if i == 0 and order.meat == 2:
			DU.circle(self, Vector2(cx + 18, cy - 16), 13.0, DU.RED, 2.5)
			DU.text(self, Vector2(cx + 18, cy - 17), "x2", 15, Color.WHITE)
	var f := patience_frac()
	var bar := Rect2(-bw / 2.0 + 14, -20, bw - 28, 10)
	draw_colored_polygon(DU.rrect_pts(bar, 5.0), Color("#e6e1ee"))
	if f > 0.02:
		var col := DU.GREEN if f > 0.5 else (DU.GOLD if f > 0.25 else DU.RED)
		draw_colored_polygon(DU.rrect_pts(Rect2(bar.position, Vector2(bar.size.x * f, bar.size.y)), 5.0), col)
	draw_polyline(DU.closed(DU.rrect_pts(bar, 5.0)), DU.INK, 2.5, true)
	if ctype.get("type_id", "") in ["hurry", "gourmet", "taxi"]:
		var badge := Vector2(-bw / 2.0 + 6, -bh + 6)
		var bc: Color = {"hurry": DU.RED, "gourmet": Color("#8e7dff"), "taxi": Color("#ffcc33")}[ctype["type_id"]]
		DU.circle(self, badge, 15.0, bc, 3.0)
		match ctype["type_id"]:
			"hurry":
				draw_line(badge, badge + Vector2(0, -8), DU.INK, 3.0)
				draw_line(badge, badge + Vector2(6, 2), DU.INK, 3.0)
			"gourmet":
				DU.star(self, badge, 9.0, DU.GOLD, 2.0)
			"taxi":
				DU.text(self, badge, "T", 16, DU.INK)
	draw_set_transform(Vector2.ZERO)


func _draw_say() -> void:
	var a := clampf(say_t * 3.0, 0.0, 1.0)
	var size := 21
	var w := DU.FONT.get_string_size(say, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 28.0
	var y := -246.0 if st != St.WAIT else -256.0 - bubble_h() - 30.0
	var x := clampf(0.0, -position.x + w / 2.0 + 8.0, 720.0 - position.x - w / 2.0 - 8.0)
	var r := Rect2(x - w / 2.0, y - 22, w, 40)
	var bg := DU.CREAM
	bg.a = a
	DU.rect(self, r, 18.0, bg, 3.0 * a, 0.0)
	var tc := DU.INK
	tc.a = a
	DU.text(self, Vector2(x, y - 3), say, size, tc)
