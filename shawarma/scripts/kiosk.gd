extends Node2D
## Kiosk frame in front of the customers: striped awning, side pillars and the counter top;
## plus the warm kitchen wall behind the stations.

var street_h := 560.0
var view_h := 1280.0


func _draw() -> void:
	var h := street_h
	# Kitchen wall (warm) with tiles and a lamp glow.
	draw_rect(Rect2(0, h, 720, view_h - h), Color("#4a2f45"))
	for y in range(int(h) + 40, int(view_h), 46):
		draw_line(Vector2(0, y), Vector2(720, y), Color("#553752"), 2.0)
	for k in 6:
		draw_circle(Vector2(360, h + 60), 420.0 - k * 60.0, Color(1, 0.83, 0.43, 0.025 + k * 0.012))
	# Steel worktop under the bins.
	DU.rect(self, Rect2(-10, h + 472, 740, view_h - h - 462), 0.0, Color("#6f6888"), 4.0, 0.0)
	draw_rect(Rect2(0, h + 476, 720, 6), Color("#8f88aa"))
	# Pillars.
	DU.rect(self, Rect2(-8, 96, 30, h - 70), 8.0, Color("#a85f2e"), 4.0, 0.0)
	DU.rect(self, Rect2(698, 96, 30, h - 70), 8.0, Color("#a85f2e"), 4.0, 0.0)
	# Awning: red/cream stripes with a scalloped edge.
	var top := 64.0
	var bottom := 126.0
	draw_rect(Rect2(0, top, 720, bottom - top), Color("#fff1d6"))
	for k in 9:
		if k % 2 == 0:
			draw_rect(Rect2(k * 80, top, 80, bottom - top), Color("#e2493b"))
	for k in 9:
		var col := Color("#e2493b") if k % 2 == 0 else Color("#fff1d6")
		var c := Vector2(k * 80 + 40, bottom)
		var pts := PackedVector2Array()
		for i in 13:
			var a := PI * i / 12.0
			pts.append(c + Vector2(cos(a) * 40, sin(a) * 22))
		draw_colored_polygon(pts, col)
		draw_polyline(pts, DU.INK, 4.0, true)
	draw_line(Vector2(0, top), Vector2(720, top), DU.INK, 4.0)
	draw_rect(Rect2(0, 0, 720, top), Color("#2b1d33"))
	# Counter top over the customers' waists.
	DU.rect(self, Rect2(-10, h - 16, 740, 42), 10.0, Color("#c9783f"), 4.0, 8.0)
	draw_rect(Rect2(0, h - 10, 720, 7), Color("#e09a5c"))
