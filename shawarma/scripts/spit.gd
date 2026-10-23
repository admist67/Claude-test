extends Node2D
## Vertical meat spit. Swipe down to shave a portion; the stock slowly cooks back.

const AREA := Rect2(14, 44, 178, 420)
const ROD_X := 112.0

var capacity := 10
var regen := 2.5
var stock := 10.0
var spin := 0.0
var knife_t := 0.0
var shake := 0.0
var glow := 0.0


func setup(cap: int, regen_s: float) -> void:
	capacity = cap
	regen = regen_s
	stock = cap


func _process(delta: float) -> void:
	if stock < capacity:
		stock = minf(capacity, stock + delta / regen)
	spin += delta
	glow += delta
	knife_t = maxf(0.0, knife_t - delta * 3.5)
	shake = maxf(0.0, shake - delta * 4.0)
	queue_redraw()


func can_cut() -> bool:
	return stock >= 1.0


func cut() -> void:
	stock -= 1.0
	knife_t = 1.0


## Global point where shavings leave the spit.
func cut_point() -> Vector2:
	return to_global(Vector2(ROD_X + 40, 260))


func _draw() -> void:
	var sx := sin(shake * 40.0) * 6.0 * shake
	draw_set_transform(Vector2(sx, 0))
	# Heater panel with glowing bars.
	DU.rect(self, Rect2(22, 70, 44, 350), 14.0, Color("#4b4060"), 4.0, 6.0)
	for k in 6:
		var a := 0.65 + 0.35 * sin(glow * 3.0 + k)
		draw_rect(Rect2(32, 92 + k * 54, 24, 30), Color(1.0, 0.45 + 0.2 * a, 0.15, 0.55 + 0.4 * a))
	# Rod and base.
	DU.rect(self, Rect2(46, 420, 144, 26), 10.0, Color("#8f8aa8"), 4.0, 6.0)
	DU.rect(self, Rect2(ROD_X - 5, 56, 10, 370), 4.0, Color("#c7c2dc"), 3.0, 0.0)
	DU.circle(self, Vector2(ROD_X, 58), 10.0, Color("#c7c2dc"), 3.0)
	# Meat cone (doner): layered slices, rotating bits, crispy edge; shrinks with the stock.
	var f := clampf(stock / capacity, 0.0, 1.0)
	var top_w := 30.0 + 42.0 * sqrt(f)
	var bot_w := 16.0 + 22.0 * sqrt(f)
	var y0 := 96.0
	var y1 := 398.0
	var sil := PackedVector2Array()
	sil.append(Vector2(ROD_X - top_w, y0))
	for i in 13:
		var a := PI - PI * i / 12.0
		sil.append(Vector2(ROD_X + cos(a) * bot_w, y1 + sin(a) * 10.0))
	sil.append(Vector2(ROD_X + top_w, y0))
	for i in 13:
		var a := -PI * i / 12.0
		sil.append(Vector2(ROD_X + cos(a) * top_w, y0 + sin(a) * 14.0))
	DU.poly(self, sil, DU.MEAT, 4.0, 6.0)
	var crisp := PackedVector2Array([Vector2(ROD_X - top_w + 2, y0 + 4), Vector2(ROD_X - top_w * 0.62, y0 + 10),
		Vector2(ROD_X - bot_w * 0.6, y1 + 4), Vector2(ROD_X - bot_w + 2, y1 - 2)])
	draw_colored_polygon(crisp, Color("#7a3d18"))
	for k in range(1, 9):
		var y := lerpf(y0, y1, k / 9.0)
		var w := lerpf(top_w, bot_w, k / 9.0)
		var arc := PackedVector2Array()
		for i in 13:
			var a := PI * i / 12.0
			arc.append(Vector2(ROD_X + cos(a) * w, y + sin(a) * 7.0))
		draw_polyline(arc, DU.MEAT_DARK, 3.0, true)
		for b in 3:
			var ang := spin * 1.6 + k * 1.7 + b * 2.1
			if cos(ang) > 0.0:
				var bx := ROD_X + sin(ang) * w * 0.82
				draw_circle(Vector2(bx, y - 12.0), 4.0 + cos(ang) * 2.0, Color("#6e3415"))
	draw_line(Vector2(ROD_X + top_w * 0.42, y0 + 18), Vector2(ROD_X + bot_w * 0.42, y1 - 10), Color(1, 0.85, 0.6, 0.35), 7.0, true)
	DU.poly(self, DU.ellipse_pts(Vector2(ROD_X, y0), top_w, 14.0, 28), Color("#c97a43"), 4.0)
	DU.circle(self, Vector2(ROD_X, y0), 6.0, Color("#c7c2dc"), 2.5)
	# Stock bar.
	DU.rect(self, Rect2(46, 452, 144, 14), 7.0, Color("#2e2638"), 3.0, 0.0)
	var fill_w := 136.0 * f
	if fill_w > 6.0:
		draw_colored_polygon(DU.rrect_pts(Rect2(50, 455, fill_w, 8), 4.0), Color("#ff9b4a") if f > 0.2 else DU.RED)
	# Knife: rests on the right, slashes down when cutting.
	var ky := lerpf(110.0, 380.0, 1.0 - knife_t) if knife_t > 0.0 else 110.0
	var kx := ROD_X + top_w * 0.85 + 6.0
	var blade := PackedVector2Array([Vector2(kx, ky - 46), Vector2(kx + 16, ky - 40), Vector2(kx + 14, ky + 30), Vector2(kx, ky + 40)])
	DU.poly(self, blade, Color("#e9e6f5"), 3.0)
	DU.rect(self, Rect2(kx - 2, ky - 86, 18, 42), 6.0, Color("#3b2b44"), 3.0, 0.0)
	draw_set_transform(Vector2.ZERO)
