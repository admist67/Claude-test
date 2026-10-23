extends Node2D
## Cutting board: lay lavash, add fillings, swipe up to roll. Plus the trash button.

enum S { EMPTY, OPEN, ROLLED }

const AREA := Rect2(200, 56, 312, 306)
const CENTER := Vector2(356, 209)
const TRASH := Rect2(450, 374, 62, 62)
const R := 122.0

var state := S.EMPTY
var meat := 0
var items: Array[String] = []
var appear := 1.0      # lavash pop-in 0..1
var roll_t := 1.0      # rolling animation 0..1
var pop := {}          # id -> pop-in timer 0..1
var shake := 0.0
var trash_bump := 0.0
var bal: Dictionary


func _process(delta: float) -> void:
	appear = minf(1.0, appear + delta * 4.0)
	roll_t = minf(1.0, roll_t + delta * 3.2)
	for id in pop.keys():
		pop[id] = minf(1.0, pop[id] + delta * 5.0)
	shake = maxf(0.0, shake - delta * 4.0)
	trash_bump = maxf(0.0, trash_bump - delta * 4.0)
	queue_redraw()


func center_global() -> Vector2:
	return to_global(CENTER)


func put_lavash() -> bool:
	if state != S.EMPTY:
		return false
	state = S.OPEN
	meat = 0
	items.clear()
	pop.clear()
	appear = 0.0
	return true


func add_item(id: String) -> bool:
	if state != S.OPEN or items.has(id):
		return false
	items.append(id)
	pop[id] = -0.6   # starts after the flying piece lands
	return true


func add_meat() -> bool:
	if state != S.OPEN or meat >= 2:
		return false
	meat += 1
	pop["meat%d" % meat] = -0.8
	return true


func roll() -> bool:
	if state != S.OPEN or (meat == 0 and items.is_empty()):
		return false
	state = S.ROLLED
	roll_t = 0.0
	return true


func take_roll() -> Dictionary:
	var made := {"meat": meat, "items": items.duplicate(), "toast": 0.0}
	clear()
	return made


func clear() -> void:
	state = S.EMPTY
	meat = 0
	items.clear()
	pop.clear()


func _pop_scale(key: String) -> float:
	var t: float = pop.get(key, 1.0)
	if t <= 0.0:
		return 0.0
	return 1.0 + sin(t * PI) * 0.35


func _draw() -> void:
	var sx := sin(shake * 40.0) * 7.0 * shake
	draw_set_transform(Vector2(sx, 0))
	# Wooden board with a handle hole.
	DU.rect(self, AREA, 34.0, Color("#e3a565"), 4.0, 8.0)
	draw_colored_polygon(DU.rrect_pts(AREA.grow(-14), 26.0), Color("#eab274"))
	for k in 4:
		var y := AREA.position.y + 62 + k * 62
		draw_line(Vector2(AREA.position.x + 34 + (k % 2) * 30, y), Vector2(AREA.end.x - 60 + (k % 2) * 20, y + 6), Color("#dc9c5c"), 3.0, true)
	DU.circle(self, Vector2(AREA.end.x - 26, AREA.position.y + 26), 9.0, Color("#b97a3d"), 3.0)
	match state:
		S.OPEN:
			if roll_t < 1.0:
				pass
			_draw_lavash()
		S.ROLLED:
			if roll_t < 1.0:
				var k := roll_t
				draw_set_transform(CENTER + Vector2(sx, 0), 0.0, Vector2(1.0, lerpf(1.0, 0.25, k)))
				DU.circle(self, Vector2.ZERO, R, DU.LAVASH, 4.0)
				draw_set_transform(Vector2(sx, 0))
				if k > 0.6:
					var s := lerpf(0.4, 1.3, (k - 0.6) / 0.4)
					DU.roll(self, CENTER + Vector2(sx, 0), 0.0, bal, s, -0.08, items)
			else:
				var bounce := 1.25 + sin(Time.get_ticks_msec() / 300.0) * 0.02
				DU.roll(self, CENTER + Vector2(sx, 0), 0.0, bal, bounce, -0.08, items)
	draw_set_transform(Vector2.ZERO)
	# Trash button.
	var tb := 1.0 + sin(trash_bump * PI) * 0.25
	var tc := TRASH.get_center()
	draw_set_transform(tc, 0.0, Vector2(tb, tb))
	DU.circle(self, Vector2.ZERO, 30.0, Color("#6c6488"), 4.0, 5.0)
	DU.rect(self, Rect2(-13, -8, 26, 24), 4.0, Color("#d8d3e6"), 3.0, 0.0)
	DU.rect(self, Rect2(-16, -15, 32, 7), 3.0, Color("#d8d3e6"), 3.0, 0.0)
	for k in 3:
		draw_line(Vector2(-6 + k * 6, -3), Vector2(-6 + k * 6, 11), DU.INK, 2.5)
	draw_set_transform(Vector2.ZERO)


func _draw_lavash() -> void:
	var a := appear
	var s := 1.0 + sin(a * PI) * 0.12 if a < 1.0 else 1.0
	s *= lerpf(0.3, 1.0, minf(1.0, a * 1.6))
	draw_set_transform(CENTER, (1.0 - a) * 0.6, Vector2(s, s))
	DU.circle(self, Vector2.ZERO, R, DU.LAVASH, 4.0, 6.0)
	for k in 9:
		var ang := k * 2.39
		draw_circle(Vector2(cos(ang), sin(ang)) * (24.0 + k * 10.0), 6.0, DU.LAVASH_SPOT)
	# Meat in the middle, then veggies around, sauce zigzag on top.
	for m in meat:
		var ps := _pop_scale("meat%d" % (m + 1))
		if ps <= 0.0:
			continue
		for k in 9:
			var ang := k * 0.7 + m * 0.35
			var p := Vector2(cos(ang), sin(ang)) * (8.0 + (k % 3) * 17.0)
			DU.piece(self, "meat", p * ps, 19.0 * ps, ang + 0.4)
	var veg_i := 0
	var sauce := ""
	for id in items:
		if Bal.ing_by_id[id]["kind"] == "sauce":
			sauce = id
			continue
		var ps := _pop_scale(id)
		if ps > 0.0:
			for k in 7:
				var ang := veg_i * 0.9 + k * TAU / 7.0
				var dist := 70.0 + (k % 2) * 18.0 - veg_i * 8.0
				DU.piece(self, id, Vector2(cos(ang), sin(ang)) * dist, 19.0 * ps, ang + k)
		veg_i += 1
	if sauce != "":
		var ps := _pop_scale(sauce)
		if ps > 0.0:
			for row in 2:
				var zz := PackedVector2Array()
				for k in 25:
					zz.append(Vector2(-80 + k * 6.6, -16 + row * 34 + sin(k * 0.9 + row) * 12.0 * ps))
				draw_polyline(zz, DU.INK, 9.0, true)
				draw_polyline(zz, Bal.color(sauce), 5.0, true)
	draw_set_transform(Vector2.ZERO)
