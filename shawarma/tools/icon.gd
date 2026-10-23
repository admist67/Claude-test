extends Node
## Renders the app icon (icon.png, 512x512) with the game's own drawing code, then quits.


class Art extends Node2D:
	func _draw() -> void:
		var r := Rect2(0, 0, 512, 512)
		draw_polygon(PackedVector2Array([r.position, Vector2(512, 0), Vector2(512, 512), Vector2(0, 512)]),
			PackedColorArray([Color("#ff9a4d"), Color("#ff9a4d"), Color("#e2493b"), Color("#e2493b")]))
		for k in 6:
			draw_circle(Vector2(256, 230), 230.0 - k * 34.0, Color(1, 0.9, 0.5, 0.05))
		DU.roll(self, Vector2(262, 262), 5.0, Bal.b, 2.15, -0.62, ["tomato", "cucumber", "cabbage", "onion"])
		DU.star(self, Vector2(118, 128), 36.0, DU.GOLD, 5.0)
		DU.star(self, Vector2(408, 400), 24.0, DU.CREAM, 4.0)


func _ready() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 512)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	vp.add_child(Art.new())
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://icon.png"))
	get_tree().quit()
