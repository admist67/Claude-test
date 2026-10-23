extends Node2D
## Tutorial pointer: a pulsing arrow (tap / swipe down / swipe up / drag) with a caption.

var kind := ""          # "", "tap", "down", "up", "drag"
var target := Vector2.ZERO
var target2 := Vector2.ZERO
var caption := ""
var t := 0.0


func show_hint(k: String, at: Vector2, text: String, to := Vector2.ZERO) -> void:
	if k != kind or caption != text:
		t = 0.0
	kind = k
	target = at
	target2 = to
	caption = text


func clear() -> void:
	kind = ""


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	if kind == "":
		return
	var a := clampf(t * 4.0, 0.0, 1.0)
	modulate.a = a
	var p := target
	match kind:
		"tap":
			p = target + Vector2(0, -70 - absf(sin(t * 4.0)) * 22.0)
			_arrow(p, PI / 2.0)
			draw_arc(target, 30.0 + fmod(t, 1.0) * 30.0, 0.0, TAU, 32, Color(1, 1, 1, 0.8 * (1.0 - fmod(t, 1.0))), 5.0, true)
		"down":
			var k := fmod(t * 0.9, 1.0)
			p = target + Vector2(0, -90 + k * 180.0)
			_arrow(p, PI / 2.0)
		"up":
			var k := fmod(t * 0.9, 1.0)
			p = target + Vector2(0, 90 - k * 180.0)
			_arrow(p, -PI / 2.0)
		"drag":
			var k := fmod(t * 0.6, 1.0)
			p = target.lerp(target2, k * k * (3.0 - 2.0 * k))
			DU.circle(self, p, 22.0, Color(1, 1, 1, 0.85), 4.0)
			draw_dashed_line(target, target2, Color(1, 1, 1, 0.5), 4.0, 16.0)
	var cap_pos := target + Vector2(0, -150) if kind != "drag" else target2 + Vector2(0, 80)
	if kind == "down":
		cap_pos = target + Vector2(130, -150)
	var w := DU.FONT.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 32.0
	cap_pos.x = clampf(cap_pos.x, w / 2.0 + 10.0, 710.0 - w / 2.0)
	DU.rect(self, Rect2(cap_pos.x - w / 2.0, cap_pos.y - 24, w, 46), 20.0, DU.ORANGE, 4.0, 5.0)
	DU.text(self, cap_pos + Vector2(0, -2), caption, 24, Color.WHITE, 6)


func _arrow(p: Vector2, ang: float) -> void:
	var pts := PackedVector2Array([Vector2(28, 0), Vector2(-4, -26), Vector2(-4, -11), Vector2(-34, -11),
		Vector2(-34, 11), Vector2(-4, 11), Vector2(-4, 26)])
	DU.poly(self, Transform2D(ang, p) * pts, Color.WHITE, 4.0, 5.0)
