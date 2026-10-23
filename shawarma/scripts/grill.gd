extends Node2D
## Contact grill. Rolls toast over time: green zone = perfect, then they burn.

signal perfect_reached(pos: Vector2)
signal burnt(pos: Vector2)

const AREA := Rect2(522, 44, 184, 422)
const MAX_SLOTS := 3

var unlocked := 2
var slots: Array = [null, null, null]   # {"made": Dictionary, "t": float, "fly": float, "from": Vector2, "rang": int}
var bal: Dictionary
var heat := 0.0
var shake := 0.0


func slot_rect(i: int) -> Rect2:
	return Rect2(534, 96 + i * 120, 160, 108)


func free_slot() -> int:
	for i in unlocked:
		if slots[i] == null:
			return i
	return -1


func slot_at(local_p: Vector2) -> int:
	for i in unlocked:
		if slots[i] != null and slot_rect(i).grow(8).has_point(local_p):
			return i
	return -1


func put(made: Dictionary, from_global: Vector2) -> int:
	var i := free_slot()
	if i < 0:
		return -1
	slots[i] = {"made": made, "t": made["toast"], "fly": 1.0, "from": to_local(from_global), "rang": 0}
	return i


func take(i: int) -> Dictionary:
	var s: Dictionary = slots[i]
	slots[i] = null
	var made: Dictionary = s["made"]
	made["toast"] = s["t"]
	return made


## Puts a dragged roll back where it was.
func restore(i: int, made: Dictionary) -> void:
	slots[i] = {"made": made, "t": made["toast"], "fly": 0.0, "from": Vector2.ZERO, "rang": _rang_for(made["toast"])}


func _rang_for(t: float) -> int:
	if t >= float(bal["grill_burnt_at"]):
		return 2
	if t >= float(bal["grill_perfect_from"]):
		return 1
	return 0


func busy_count() -> int:
	var n := 0
	for s in slots:
		if s != null:
			n += 1
	return n


func slot_center_global(i: int) -> Vector2:
	return to_global(slot_rect(i).get_center())


func _process(delta: float) -> void:
	heat += delta
	shake = maxf(0.0, shake - delta * 4.0)
	for i in MAX_SLOTS:
		var s = slots[i]
		if s == null:
			continue
		s["fly"] = maxf(0.0, s["fly"] - delta * 4.5)
		if s["fly"] > 0.0:
			continue
		s["t"] += delta * Bal.tune["grill"]
		var r := _rang_for(s["t"])
		if r > s["rang"]:
			s["rang"] = r
			if r == 1:
				perfect_reached.emit(slot_center_global(i))
			elif r == 2:
				burnt.emit(slot_center_global(i))
	queue_redraw()


func _draw() -> void:
	var sx := sin(shake * 40.0) * 6.0 * shake
	draw_set_transform(Vector2(sx, 0))
	DU.rect(self, AREA, 26.0, Color("#5b4f73"), 4.0, 8.0)
	DU.rect(self, Rect2(AREA.position.x + 12, AREA.position.y + 10, AREA.size.x - 24, 34), 12.0, Color("#7a6d96"), 3.0, 0.0)
	DU.text(self, Vector2(AREA.get_center().x, AREA.position.y + 26), "ГРИЛЬ", 22, DU.CREAM, 0)
	for i in MAX_SLOTS:
		var r := slot_rect(i)
		DU.rect(self, r, 14.0, Color("#2e2638"), 3.5, 0.0)
		if i >= unlocked:
			DU.rect(self, Rect2(r.get_center().x - 14, r.get_center().y - 8, 28, 22), 5.0, Color("#7a6d96"), 3.0, 0.0)
			draw_arc(r.get_center() + Vector2(0, -9), 9.0, PI, TAU, 10, Color("#7a6d96"), 4.0, true)
			continue
		var h := 0.25 + 0.15 * sin(heat * 2.0 + i)
		draw_colored_polygon(DU.rrect_pts(r.grow(-6), 10.0), Color(1.0, 0.4, 0.1, h * 0.5))
		for k in 6:
			var x := r.position.x + 18 + k * 25
			draw_line(Vector2(x, r.position.y + 10), Vector2(x, r.end.y - 26), Color("#463a57"), 4.0)
		var s = slots[i]
		if s == null:
			continue
		var c := r.get_center() + Vector2(0, -8)
		var fly: float = s["fly"]
		var pos: Vector2 = c.lerp(s["from"], fly * fly) if fly > 0.0 else c
		var made: Dictionary = s["made"]
		DU.roll(self, pos, s["t"], bal, 0.82 + fly * 0.4, 0.0, made["items"])
		if fly <= 0.0:
			_draw_steam(c, s["t"], i)
			_draw_toast_bar(r, s["t"])
	draw_set_transform(Vector2.ZERO)


func _draw_steam(c: Vector2, t: float, i: int) -> void:
	var dark := t >= float(bal["grill_burnt_at"])
	for k in 3:
		var ph := fmod(heat * 0.9 + k * 0.33 + i * 0.2, 1.0)
		var p := c + Vector2(-30 + k * 30 + sin(heat * 3.0 + k) * 6.0, -20 - ph * 50.0)
		var col := Color(0.25, 0.2, 0.2, 0.5 * (1.0 - ph)) if dark else Color(1, 1, 1, 0.35 * (1.0 - ph))
		draw_circle(p, 7.0 + ph * 8.0, col)


func _draw_toast_bar(r: Rect2, t: float) -> void:
	var burnt_at := float(bal["grill_burnt_at"])
	var bar := Rect2(r.position.x + 12, r.end.y - 18, r.size.x - 24, 10)
	var w := bar.size.x
	var x_from := bar.position.x + w * float(bal["grill_perfect_from"]) / burnt_at
	var x_to := bar.position.x + w * float(bal["grill_perfect_to"]) / burnt_at
	draw_rect(Rect2(bar.position.x, bar.position.y, x_from - bar.position.x, bar.size.y), Color("#e8d2a6"))
	draw_rect(Rect2(x_from, bar.position.y, x_to - x_from, bar.size.y), DU.GREEN)
	draw_rect(Rect2(x_to, bar.position.y, bar.end.x - x_to, bar.size.y), Color("#ff8a3d"))
	draw_polyline(DU.closed(DU.rrect_pts(bar, 2.0)), DU.INK, 2.5)
	var mx := bar.position.x + w * clampf(t / burnt_at, 0.0, 1.0)
	DU.poly(self, PackedVector2Array([Vector2(mx - 7, bar.position.y - 9), Vector2(mx + 7, bar.position.y - 9), Vector2(mx, bar.position.y + 3)]), DU.CREAM, 2.5)
