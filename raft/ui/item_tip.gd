class_name ItemTip
extends PanelContainer
## A small dark label that fades in over an item card, stays two seconds and fades out:
## the item's name. Lives in a full-screen panel, so its position is screen space. It
## rides along with its card while the list scrolls and hides while the card is out of view.

var _label: Label
var _tw: Tween
var _shown := 0                   # counts calls, so a newer tip wins over an older one
var _over: Control                # the card it points at
var _clip: Control                # the scrolling list around the card, if any
var _live := false                # from the fade-in to the end of the fade-out


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
	_live = false
	_over = over
	_clip = _scroller_of(over)
	_label.text = text
	size = Vector2.ZERO
	modulate.a = 0.0
	visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	if me != _shown or not is_instance_valid(over):
		return
	_live = true
	_follow()
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "modulate:a", 1.0, 0.2)
	_tw.tween_interval(2.0)
	_tw.tween_property(self, "modulate:a", 0.0, 0.4)
	_tw.tween_callback(func() -> void:
		_live = false
		visible = false
	)


func _process(_delta: float) -> void:
	if _live:
		_follow()


## Sits above the card; hidden while the card is scrolled out of its list, gone with it.
func _follow() -> void:
	if not is_instance_valid(_over) or not _over.is_visible_in_tree():
		_live = false
		visible = false
		return
	var r := _over.get_global_rect()
	var vs := get_viewport_rect().size
	var p := Vector2(r.get_center().x - size.x / 2.0, r.position.y - size.y - 6.0)
	position = Vector2(clampf(p.x, 8.0, vs.x - size.x - 8.0), maxf(8.0, p.y))
	visible = _clip == null or _clip.get_global_rect().has_point(r.get_center())


static func _scroller_of(c: Control) -> Control:
	var n := c.get_parent()
	while n != null:
		if n is ScrollContainer:
			return n
		n = n.get_parent()
	return null
