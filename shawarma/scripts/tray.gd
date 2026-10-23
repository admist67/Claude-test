extends Node2D
## Ingredient bins along the bottom of the counter. Tap a bin to use it.

const ORDER := ["lavash", "tomato", "cucumber", "cabbage", "onion", "fries", "cheese", "jalapeno", "garlic", "hot"]

var unlocked: Array = []
var bump := {}


func bin_rect(i: int) -> Rect2:
	return Rect2(12 + (i % 5) * 140, 488 + (i / 5) * 112, 136, 104)


func bin_at(local_p: Vector2) -> String:
	for i in ORDER.size():
		if bin_rect(i).has_point(local_p):
			return ORDER[i]
	return ""


func bin_center_global(id: String) -> Vector2:
	return to_global(bin_rect(ORDER.find(id)).get_center())


func poke(id: String) -> void:
	bump[id] = 1.0


func _process(delta: float) -> void:
	for id in bump.keys():
		bump[id] = maxf(0.0, bump[id] - delta * 4.0)
	queue_redraw()


func _draw() -> void:
	for i in ORDER.size():
		var id: String = ORDER[i]
		var r := bin_rect(i)
		var c := r.get_center()
		var b: float = bump.get(id, 0.0)
		var s := 1.0 + sin(b * PI) * 0.12
		draw_set_transform(c, 0.0, Vector2(s, s))
		var lr := Rect2(-r.size.x / 2.0, -r.size.y / 2.0, r.size.x, r.size.y)
		DU.rect(self, lr, 18.0, Color("#d8d3e6"), 4.0, 6.0)
		DU.rect(self, lr.grow(-9), 12.0, Color("#3a3048"), 0.0, 0.0)
		var open := unlocked.has(id)
		if id == "lavash":
			for k in 3:
				DU.poly(self, DU.ellipse_pts(Vector2(0, 8 - k * 9), 46.0, 20.0), DU.LAVASH.darkened(0.05 * (2 - k)), 3.0)
		else:
			var spots := [Vector2(-30, -6), Vector2(0, -16), Vector2(30, -6), Vector2(-16, 10), Vector2(18, 10)]
			for k in spots.size():
				DU.ing(self, id, spots[k], 17.0, 2.5)
		DU.text(self, Vector2(0, 36), Bal.ing_name(id), 17, DU.CREAM, 5)
		if not open:
			DU.rect(self, lr.grow(-4), 14.0, Color(0.12, 0.08, 0.16, 0.72), 0.0, 0.0)
			DU.rect(self, Rect2(-14, -6, 28, 22), 5.0, DU.GOLD, 3.0, 0.0)
			draw_arc(Vector2(0, -7), 9.0, PI, TAU, 10, DU.INK, 4.0, true)
		draw_set_transform(Vector2.ZERO)
