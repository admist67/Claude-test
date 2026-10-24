class_name UiTheme
## The nautical look: wooden buttons, wood-framed dark panels, parchment plaques
## (textures from tools/build_ui.py), Kelly Slab for titles and Nunito for text.

const CREAM := Color("#f2e6c4")
const GOLD := Color("#f2c46b")
const INK := Color("#3a2614")
const WOOD := Color("#c89a5b")
const DANGER := Color("#ff8a7a")

static var _title: Font
static var _body: Font


static func title_font() -> Font:
	if _title == null:
		_title = load("res://assets/fonts/KellySlab-Regular.ttf")
	return _title


static func body_font() -> Font:
	if _body == null:
		_body = load("res://assets/fonts/Nunito-800.ttf")
	return _body


static func box(path: String, margin: float, pad := Vector4(18, 10, 18, 10)) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(path)
	s.texture_margin_left = margin
	s.texture_margin_right = margin
	s.texture_margin_top = margin
	s.texture_margin_bottom = margin
	s.content_margin_left = pad.x
	s.content_margin_top = pad.y
	s.content_margin_right = pad.z
	s.content_margin_bottom = pad.w
	return s


static func make() -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 26
	t.set_stylebox("normal", "Button", box("res://assets/ui/button.png", 26, Vector4(26, 12, 26, 14)))
	t.set_stylebox("hover", "Button", box("res://assets/ui/button.png", 26, Vector4(26, 12, 26, 14)))
	t.set_stylebox("pressed", "Button", box("res://assets/ui/button_pressed.png", 26, Vector4(26, 14, 26, 12)))
	t.set_stylebox("disabled", "Button", box("res://assets/ui/button_disabled.png", 26, Vector4(26, 12, 26, 14)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", Color("#2a170b"))
	t.set_color("font_disabled_color", "Button", Color(0.82, 0.8, 0.76))
	t.set_stylebox("panel", "PanelContainer", box("res://assets/ui/panel.png", 40, Vector4(34, 30, 34, 30)))
	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))
	t.set_stylebox("slider", "HSlider", _flat(Color(0.03, 0.1, 0.13, 0.9), 8, 10))
	t.set_stylebox("grabber_area", "HSlider", _flat(WOOD, 8, 10))
	t.set_stylebox("grabber_area_highlight", "HSlider", _flat(WOOD.lightened(0.15), 8, 10))
	return t


static func _flat(c: Color, r: int, h: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(r)
	s.content_margin_top = h / 2.0
	s.content_margin_bottom = h / 2.0
	return s


static func label(text: String, size := 26, col := CREAM, title := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if title:
		l.add_theme_font_override("font", title_font())
	return l


static func button(text: String, cb: Callable, size := 28) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(330, 76)
	b.pressed.connect(func() -> void:
		Sfx.play("click", -6.0)
		cb.call()
	)
	return b


## A round wooden button with a glyph (close, settings...).
static func round_button(glyph: String, cb: Callable, d := 72.0) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = load("res://assets/ui/ring.png")
	b.texture_pressed = load("res://assets/ui/ring_hot.png")
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.custom_minimum_size = Vector2(d, d)
	var ic := IconRect.new(glyph, 1.0)
	ic.custom_minimum_size = Vector2.ZERO
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := d * 0.28
	ic.offset_left = m
	ic.offset_top = m
	ic.offset_right = -m
	ic.offset_bottom = -m
	b.add_child(ic)
	b.pressed.connect(func() -> void:
		Sfx.play("click", -6.0)
		cb.call()
	)
	return b
