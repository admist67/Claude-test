class_name Icons
## Flat procedural icons for items and buttons, drawn into any CanvasItem.

const OUT := Color(0.1, 0.12, 0.16, 0.9)


static func draw(ci: CanvasItem, id: String, c: Vector2, s: float) -> void:
	var u := s / 2.0
	match id:
		"plank":
			_rot_rect(ci, c, Vector2(s * 0.95, s * 0.3), -0.5, Color("#c08f55"))
			_rot_rect(ci, c + Vector2(u * 0.3, -u * 0.18), Vector2(s * 0.12, s * 0.3), -0.5, Color("#9c7140"))
		"plastic":
			ci.draw_rect(Rect2(c - Vector2(u * 0.55, u * 0.45), Vector2(u * 1.1, u * 1.2)), Color("#8fc9ea"))
			ci.draw_rect(Rect2(c + Vector2(u * 0.05, -u * 0.75), Vector2(u * 0.35, u * 0.32)), Color("#2a6fb0"))
			ci.draw_rect(Rect2(c + Vector2(-u * 0.5, -u * 0.6), Vector2(u * 0.16, u * 0.5)), Color("#8fc9ea"))
		"leaf":
			var a := c + Vector2(-u * 0.8, u * 0.75)
			var b := c + Vector2(u * 0.8, -u * 0.75)
			var n := (b - a).normalized().orthogonal()
			for i in 5:
				var p := a.lerp(b, 0.15 + i * 0.17)
				var tip := (b - a).normalized() * u * 0.25
				ci.draw_colored_polygon(PackedVector2Array([p, p + n * u * 0.55 + tip, p + tip * 1.4]), Color("#4f9e38"))
				ci.draw_colored_polygon(PackedVector2Array([p, p + tip * 1.4, p - n * u * 0.55 + tip]), Color("#3c842b"))
			ci.draw_line(a, b, Color("#7a8a3a"), maxf(2.0, s * 0.06))
		"rope":
			for i in 3:
				ci.draw_arc(c + Vector2(0, (i - 1) * u * 0.28), u * 0.62, 0, TAU, 24, Color("#cfae7a"), maxf(2.0, s * 0.09), true)
		"coconut":
			ci.draw_circle(c, u * 0.72, Color("#6b4426"))
			for o: Vector2 in [Vector2(-0.2, -0.15), Vector2(0.15, -0.2), Vector2(0, 0.12)]:
				ci.draw_circle(c + o * u, u * 0.09, Color("#3a2414"))
		"banana":
			ci.draw_arc(c + Vector2(u * 0.2, -u * 0.4), u * 0.8, 1.7, 3.3, 20, Color("#f3d34a"), s * 0.22, true)
		"pineapple":
			ci.draw_circle(c + Vector2(0, u * 0.2), u * 0.55, Color("#e7a93a"))
			for i in 3:
				var x := (i - 1) * u * 0.25
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(x - u * 0.12, -u * 0.25), c + Vector2(x + u * 0.12, -u * 0.25), c + Vector2(x * 1.6, -u * 0.95)]), Color("#4f9e38"))
		"water":
			ci.draw_rect(Rect2(c + Vector2(-u * 0.32, -u * 0.35), Vector2(u * 0.64, u * 1.15)), Color("#7fc4f0"))
			ci.draw_rect(Rect2(c + Vector2(-u * 0.14, -u * 0.75), Vector2(u * 0.28, u * 0.42)), Color("#7fc4f0"))
			ci.draw_rect(Rect2(c + Vector2(-u * 0.18, -u * 0.88), Vector2(u * 0.36, u * 0.16)), Color("#2a6fb0"))
			ci.draw_rect(Rect2(c + Vector2(-u * 0.32, u * 0.1), Vector2(u * 0.64, u * 0.7)), Color("#3d8fd6"))
		"hook":
			var w := maxf(3.0, s * 0.1)
			ci.draw_line(c + Vector2(0, -u * 0.85), c + Vector2(0, u * 0.35), Color("#d9d9d9"), w)
			ci.draw_arc(c + Vector2(-u * 0.32, u * 0.3), u * 0.32, 0.0, PI, 12, Color("#d9d9d9"), w)
			ci.draw_arc(c + Vector2(u * 0.32, u * 0.3), u * 0.32, 0.0, PI, 12, Color("#d9d9d9"), w)
			ci.draw_circle(c + Vector2(0, -u * 0.85), u * 0.18, Color("#ff6a3d"))
		"hammer":
			_rot_rect(ci, c + Vector2(u * 0.1, u * 0.15), Vector2(s * 0.14, s * 0.85), 0.6, Color("#a97a45"))
			_rot_rect(ci, c + Vector2(-u * 0.25, -u * 0.35), Vector2(s * 0.55, s * 0.24), 0.6, Color("#8d959c"))
		"tile":
			for i in 3:
				ci.draw_rect(Rect2(c + Vector2(-u * 0.8, -u * 0.75 + i * u * 0.52), Vector2(u * 1.6, u * 0.42)), Color("#c89a5b") if i != 1 else Color("#b7864c"))
		"hand":
			ci.draw_circle(c + Vector2(0, u * 0.15), u * 0.5, Color("#f1c9a0"))
			for i in 4:
				ci.draw_rect(Rect2(c + Vector2(-u * 0.48 + i * u * 0.25, -u * 0.75), Vector2(u * 0.2, u * 0.7)), Color("#f1c9a0"))
			ci.draw_rect(Rect2(c + Vector2(u * 0.35, -u * 0.05), Vector2(u * 0.45, u * 0.2)), Color("#f1c9a0"))
		"bag":
			ci.draw_rect(Rect2(c + Vector2(-u * 0.7, -u * 0.35), Vector2(u * 1.4, u * 1.1)), Color("#b7864c"))
			ci.draw_arc(c + Vector2(0, -u * 0.35), u * 0.4, PI, TAU, 12, Color("#7a5532"), maxf(3.0, s * 0.09))
			ci.draw_rect(Rect2(c + Vector2(-u * 0.7, -u * 0.1), Vector2(u * 1.4, u * 0.15)), Color("#7a5532"))
		"pause":
			ci.draw_rect(Rect2(c + Vector2(-u * 0.45, -u * 0.6), Vector2(u * 0.3, u * 1.2)), Color.WHITE)
			ci.draw_rect(Rect2(c + Vector2(u * 0.15, -u * 0.6), Vector2(u * 0.3, u * 1.2)), Color.WHITE)
		"health":
			ci.draw_circle(c + Vector2(-u * 0.3, -u * 0.15), u * 0.38, Color("#ff5a5a"))
			ci.draw_circle(c + Vector2(u * 0.3, -u * 0.15), u * 0.38, Color("#ff5a5a"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-u * 0.68, -u * 0.05), c + Vector2(u * 0.68, -u * 0.05), c + Vector2(0, u * 0.75)]), Color("#ff5a5a"))
		"hunger":
			ci.draw_circle(c + Vector2(-u * 0.12, -u * 0.12), u * 0.5, Color("#e8873a"))
			_rot_rect(ci, c + Vector2(u * 0.4, u * 0.4), Vector2(s * 0.12, s * 0.4), -0.8, Color("#f2e6c4"))
		"thirst":
			ci.draw_circle(c + Vector2(0, u * 0.2), u * 0.5, Color("#4fb3f0"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-u * 0.46, u * 0.05), c + Vector2(u * 0.46, u * 0.05), c + Vector2(0, -u * 0.8)]), Color("#4fb3f0"))
		_:
			ci.draw_circle(c, u * 0.5, Color("#ff00ff"))


static func _rot_rect(ci: CanvasItem, c: Vector2, size: Vector2, ang: float, col: Color) -> void:
	var h := size / 2.0
	var pts := PackedVector2Array()
	for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		pts.append(c + (h * s).rotated(ang))
	ci.draw_colored_polygon(pts, col)
