class_name IconRect
extends Control
## A Control that shows one icon (for panels built from containers).

var id := ""
var mod := Color.WHITE


func _init(icon_id := "", size_px := 44.0, tint := Color.WHITE) -> void:
	id = icon_id
	mod = tint
	custom_minimum_size = Vector2(size_px, size_px)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	Icons.draw(self, id, size / 2.0, minf(size.x, size.y), mod)
