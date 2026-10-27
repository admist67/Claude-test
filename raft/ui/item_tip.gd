class_name ItemTip
extends PanelContainer
## A small dark label that fades in over an item card, stays two seconds and fades out:
## the item's name. Lives in a full-screen panel, so its position is screen space.

var _label: Label
var _tw: Tween
var _shown := 0                   # counts calls, so a newer tip wins over an older one


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.06, 0.08, 0.92)
	sb.border_color = Color(UiTheme.GOLD, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	add_theme_stylebox_override("panel", sb)
	_label = UiTheme.label("", 20, UiTheme.CREAM)
	add_child(_label)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	visible = false


## Shows `text` above the card `over` (once it is laid out: it may be brand new).
func show_over(text: String, over: Control) -> void:
	_shown += 1
	var me := _shown
	_label.text = text
	size = Vector2.ZERO
	modulate.a = 0.0
	visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	if me != _shown or not is_instance_valid(over):
		return
	var r := over.get_global_rect()
	var vs := get_viewport_rect().size
	var p := Vector2(r.get_center().x - size.x / 2.0, r.position.y - size.y - 6.0)
	position = Vector2(clampf(p.x, 8.0, vs.x - size.x - 8.0), maxf(8.0, p.y))
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "modulate:a", 1.0, 0.2)
	_tw.tween_interval(2.0)
	_tw.tween_property(self, "modulate:a", 0.0, 0.4)
	_tw.tween_callback(func() -> void: visible = false)
