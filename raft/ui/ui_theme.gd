class_name UiTheme
## The shared look of menus and panels: rounded wood-and-sea buttons, big touch targets.

const PANEL := Color(0.07, 0.2, 0.26, 0.92)
const WOOD := Color("#c89a5b")
const CREAM := Color("#f2e6c4")


static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 26
	var normal := _box(WOOD, 14)
	var hover := _box(WOOD.lightened(0.12), 14)
	var press := _box(WOOD.darkened(0.2), 14)
	var dis := _box(Color(0.35, 0.4, 0.42, 0.8), 14)
	for s: Array in [["normal", normal], ["hover", hover], ["pressed", press], ["disabled", dis], ["focus", StyleBoxEmpty.new()]]:
		t.set_stylebox(s[0], "Button", s[1])
	t.set_color("font_color", "Button", Color("#2b1d12"))
	t.set_color("font_hover_color", "Button", Color("#2b1d12"))
	t.set_color("font_pressed_color", "Button", Color("#2b1d12"))
	t.set_color("font_disabled_color", "Button", Color(0.85, 0.85, 0.85))
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, 22, 28))
	t.set_color("font_color", "Label", CREAM)
	t.set_constant("outline_size", "Label", 0)
	return t


static func _box(c: Color, radius: int, pad := 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad + 6
	s.content_margin_right = pad + 6
	s.content_margin_top = pad - 4
	s.content_margin_bottom = pad - 4
	return s


static func label(text: String, size := 26, col := CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


static func button(text: String, cb: Callable, size := 30) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(320, 74)
	b.pressed.connect(func() -> void:
		Sfx.play("click", -6.0)
		cb.call()
	)
	return b
