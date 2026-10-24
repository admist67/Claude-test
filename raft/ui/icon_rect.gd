class_name IconRect
extends Control
## A Control that shows one procedural icon (for panels built from containers).

var id := ""


func _init(icon_id := "", size := 44.0) -> void:
	id = icon_id
	custom_minimum_size = Vector2(size, size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	Icons.draw(self, id, size / 2.0, minf(size.x, size.y) * 0.9)
