extends Node2D
## Night street behind the kiosk window: sky, city, metro sign, lamp, neon sign in the window.

var height := 560.0
var rush := 0.0        # 0..1 night-rush glow
var t := 0.0
var stars: Array = []
var windows: Array = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 40:
		stars.append([Vector2(rng.randf_range(20, 700), rng.randf_range(150, 520)), rng.randf_range(1.0, 2.6), rng.randf() * TAU])
	for i in 70:
		windows.append([rng.randi_range(0, 9), rng.randi_range(0, 7), rng.randf() < 0.55, rng.randf() * TAU])


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var h := height
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(720, 0), Vector2(720, h), Vector2(0, h)]),
		PackedColorArray([Color("#141130"), Color("#141130"), Color("#33285e"), Color("#33285e")]))
	for s in stars:
		var p: Vector2 = s[0]
		if p.y > h - 200:
			continue
		var a := 0.5 + 0.5 * sin(t * 1.5 + s[2])
		draw_circle(p, s[1], Color(1, 0.95, 0.8, 0.35 + 0.5 * a))
	# Moon.
	var moon := Vector2(600, maxf(200.0, h * 0.36))
	draw_circle(moon, 62.0, Color(1, 0.9, 0.6, 0.08))
	DU.circle(self, moon, 40.0, Color("#fff1c9"), 0.0)
	draw_circle(moon + Vector2(-12, -8), 8.0, Color("#f0dca8"))
	draw_circle(moon + Vector2(14, 10), 6.0, Color("#f0dca8"))
	# Far and near buildings with windows.
	var base := h - 70.0
	var far := [[0, 210], [90, 260], [170, 190], [250, 300], [360, 230], [450, 280], [560, 200], [640, 250]]
	for b in far:
		draw_rect(Rect2(b[0], base - b[1], 100, b[1]), Color("#221c42"))
	var near := [[-10, 150, 130], [130, 220, 120], [260, 170, 150], [420, 240, 130], [560, 180, 170]]
	for bi in near.size():
		var b: Array = near[bi]
		var r := Rect2(b[0], base - b[1], b[2], b[1])
		draw_rect(r, Color("#2c2554"))
		draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 6), Color("#3a3170"))
		for wi in windows:
			if wi[0] % 5 != bi:
				continue
			var col: int = wi[1] % 4
			var row: int = wi[1] / 2 + wi[0] / 5 * 2
			var wr := Rect2(r.position.x + 16 + col * 28, r.position.y + 22 + row * 34, 16, 20)
			if wr.end.x > r.end.x - 8 or wr.end.y > base - 10:
				continue
			var lit: bool = wi[2]
			if lit:
				var fl := 0.85 + 0.15 * sin(t * 0.7 + wi[3])
				draw_rect(wr, Color(1, 0.8, 0.42, fl))
			else:
				draw_rect(wr, Color("#3d3478"))
	# Metro sign on a pole (generic blue M).
	var mp := Vector2(70, base - 150)
	draw_rect(Rect2(mp.x - 4, mp.y, 8, 150), Color("#5b5480"))
	draw_circle(mp, 44.0, Color(0.3, 0.6, 1.0, 0.12))
	DU.circle(self, mp, 30.0, Color("#3a7bff"), 4.0)
	DU.text(self, mp + Vector2(0, -2), "M", 34, Color.WHITE)
	# Street lamp.
	var lp := Vector2(650, base - 210)
	draw_rect(Rect2(lp.x - 5, lp.y, 10, 210), Color("#5b5480"))
	for k in 5:
		draw_circle(lp + Vector2(0, 8), 120.0 - k * 22.0, Color(1, 0.82, 0.45, 0.04 + k * 0.025))
	DU.rect(self, Rect2(lp.x - 22, lp.y - 6, 44, 20), 8.0, Color("#ffe39a"), 3.5, 0.0)
	# Sidewalk.
	draw_rect(Rect2(0, base, 720, h - base), Color("#3b3358"))
	draw_rect(Rect2(0, base, 720, 8), Color("#4d4473"))
	for k in 8:
		draw_line(Vector2(k * 100 + 40, base + 8), Vector2(k * 100 + 20, h), Color("#332c4f"), 3.0)
	# Neon sign hanging in the window.
	_draw_neon(Vector2(360, 178))
	if rush > 0.01:
		var a := rush * (0.16 + 0.06 * sin(t * 6.0))
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(160, 0), Vector2(160, h), Vector2(0, h)]),
			PackedColorArray([Color(1, 0.3, 0.65, a), Color(1, 0.3, 0.65, 0), Color(1, 0.3, 0.65, 0), Color(1, 0.3, 0.65, a)]))
		draw_polygon(PackedVector2Array([Vector2(560, 0), Vector2(720, 0), Vector2(720, h), Vector2(560, h)]),
			PackedColorArray([Color(0.3, 0.95, 1, 0), Color(0.3, 0.95, 1, a), Color(0.3, 0.95, 1, a), Color(0.3, 0.95, 1, 0)]))


func _draw_neon(c: Vector2) -> void:
	var on := 1.0
	if rush > 0.5 and fmod(t, 2.3) > 2.1:
		on = 0.3
	var pink := Color(1, 0.31, 0.64)
	var cyan := Color(0.31, 0.94, 1)
	var col := pink.lerp(cyan, (sin(t * 2.0) * 0.5 + 0.5) * rush)
	for k in 3:
		var g := col
		g.a = (0.10 + 0.05 * k) * on
		DU.text(self, c, "ШАУРМА", 54, Color(0, 0, 0, 0), 26 - k * 8, DU.FONT, g)
	var core := col.lerp(Color.WHITE, 0.55)
	core.a = on
	DU.text(self, c, "ШАУРМА", 54, core, 4, DU.FONT, col)
