extends Node2D
## Short-lived juice: floating text, flying coins and bits, puffs, sparkles and banners.

var screen_w := 720.0


class Floater extends Node2D:
	var text := ""
	var color := Color.WHITE
	var size := 34

	func _draw() -> void:
		DU.text(self, Vector2.ZERO, text, size, color, 9)


class Bit extends Node2D:
	var id := ""
	var s := 16.0
	var draw_coin := false

	func _draw() -> void:
		if draw_coin:
			DU.coin(self, Vector2.ZERO, s)
		elif id == "lavash":
			DU.poly(self, DU.ellipse_pts(Vector2.ZERO, s * 2.2, s), DU.LAVASH, 3.0)
		else:
			DU.ing(self, id, Vector2.ZERO, s, 2.5)


class Banner extends Node2D:
	var title := ""
	var sub := ""
	var color := Color.WHITE

	func _draw() -> void:
		var w := maxf(DU.FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x, 300.0) + 60.0
		DU.rect(self, Rect2(-w / 2.0, -58, w, 84.0 if sub.is_empty() else 116.0), 26.0, color, 5.0, 8.0)
		DU.text(self, Vector2(0, -18), title, 46, Color.WHITE, 10)
		if not sub.is_empty():
			DU.text(self, Vector2(0, 30), sub, 28, DU.CREAM, 7)


func float_text(pos: Vector2, s: String, color: Color, size := 34, rise := 80.0) -> void:
	var n := Floater.new()
	n.text = s
	n.color = color
	n.size = size
	n.position = pos
	n.scale = Vector2(0.4, 0.4)
	add_child(n)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "position:y", pos.y - rise, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "modulate:a", 0.0, 0.25)
	tw.tween_callback(n.queue_free)


## Flies a small icon along an arc from a to b.
func fly(id: String, a: Vector2, b: Vector2, dur := 0.25, s := 16.0, delay := 0.0, coin := false, on_done := Callable()) -> void:
	var n := Bit.new()
	n.id = id
	n.s = s
	n.draw_coin = coin
	n.position = a
	n.visible = delay <= 0.0
	add_child(n)
	var tw := n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
		tw.tween_callback(n.show)
	var mid := (a + b) / 2.0 + Vector2(0, -minf(160.0, a.distance_to(b) * 0.4))
	var step := func(k: float) -> void:
		n.position = a.lerp(mid, k).lerp(mid.lerp(b, k), k)
		n.rotation = k * 4.0
		n.scale = Vector2.ONE * (1.0 + sin(k * PI) * 0.3)
	tw.tween_method(step, 0.0, 1.0, dur)
	if on_done.is_valid():
		tw.tween_callback(on_done)
	tw.tween_callback(n.queue_free)


func coins(a: Vector2, b: Vector2, count: int, on_each: Callable) -> void:
	for i in count:
		fly("", a + Vector2(randf_range(-30, 30), randf_range(-20, 20)), b, 0.55, 14.0, i * 0.06, true, on_each)


func puff(pos: Vector2, color: Color, amount := 14, speed := 160.0, up := false) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.7
	p.spread = 180.0
	p.direction = Vector2(0, -1)
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, -80) if up else Vector2(0, 400)
	p.scale_amount_min = 6.0
	p.scale_amount_max = 12.0
	var grad := Gradient.new()
	grad.set_color(0, color)
	var end := color
	end.a = 0.0
	grad.set_color(1, end)
	p.color_ramp = grad
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func sparkle(pos: Vector2) -> void:
	puff(pos, Color(1, 0.95, 0.5), 18, 260.0)


func banner(title: String, sub: String, color: Color, y: float) -> void:
	var n := Banner.new()
	n.title = title
	n.sub = sub
	n.color = color
	n.position = Vector2(screen_w / 2.0, y)
	n.scale = Vector2(0.2, 0.2)
	add_child(n)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.6)
	tw.tween_property(n, "modulate:a", 0.0, 0.35)
	tw.tween_callback(n.queue_free)
