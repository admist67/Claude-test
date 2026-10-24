class_name Menus
extends Control
## Main menu, pause (with playtest tuning sliders) and the death screen.

signal new_game
signal continue_game
signal resume
signal to_menu
signal respawn

var has_save := false

var _screen: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.make()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func hide_all() -> void:
	if _screen:
		_screen.queue_free()
		_screen = null
	visible = false


func _open(dim: float) -> VBoxContainer:
	hide_all()
	visible = true
	_screen = Control.new()
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_screen)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.1, 0.14, dim)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(bg)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(cc)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	cc.add_child(v)
	return v


func show_main() -> void:
	var v := _open(0.15)
	var t := UiTheme.label("ПЛОТ", 120, Color.WHITE)
	t.add_theme_constant_override("outline_size", 18)
	t.add_theme_color_override("font_outline_color", Color("#1f6f86"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := UiTheme.label("выживание посреди океана", 28, UiTheme.CREAM)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	v.add_child(_gap(18))
	if has_save:
		v.add_child(UiTheme.button("Продолжить", func() -> void: continue_game.emit()))
	v.add_child(UiTheme.button("Новая игра", func() -> void: new_game.emit()))


func show_pause() -> void:
	var v := _open(0.55)
	var t := UiTheme.label("Пауза", 54)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(UiTheme.button("Продолжить", func() -> void: resume.emit()))
	v.add_child(_gap(6))
	v.add_child(UiTheme.label("Настройки для теста", 22, UiTheme.WOOD))
	v.add_child(_slider("Чувствительность обзора", "look", 0.4, 2.0))
	v.add_child(_slider("Скорость голода и жажды", "hunger", 0.0, 2.0))
	v.add_child(_slider("Количество мусора", "debris", 0.5, 2.5))
	v.add_child(_slider("Дальность крюка", "hook", 0.6, 1.6))
	var snd := UiTheme.button("", func() -> void: pass, 24)
	snd.text = "Звук: вкл" if not Sfx.muted else "Звук: выкл"
	snd.pressed.connect(func() -> void:
		Sfx.set_muted(not Sfx.muted)
		snd.text = "Звук: вкл" if not Sfx.muted else "Звук: выкл"
	)
	snd.custom_minimum_size = Vector2(320, 58)
	v.add_child(snd)
	v.add_child(UiTheme.button("В главное меню", func() -> void: to_menu.emit(), 24))


func show_death(cause: String) -> void:
	var v := _open(0.6)
	var t := UiTheme.label("Ты погиб", 64, Color("#ff8a7a"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var why := {"thirst": "Океан вокруг, а пить нечего…", "hunger": "Голод победил.", "": "Море было сильнее."}
	var s := UiTheme.label(why.get(cause, why[""]), 28)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var s2 := UiTheme.label("Половина припасов утонула. Плот остался.", 22, Color(1, 1, 1, 0.7))
	s2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s2)
	v.add_child(_gap(10))
	v.add_child(UiTheme.button("Очнуться на плоту", func() -> void: respawn.emit()))


func show_message(title: String, text: String, button: String, cb: Callable) -> void:
	var v := _open(0.45)
	var t := UiTheme.label(title, 54, Color("#9be59b"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := UiTheme.label(text, 26)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	v.add_child(_gap(10))
	v.add_child(UiTheme.button(button, cb))


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _slider(text: String, key: String, lo: float, hi: float) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := UiTheme.label(text, 20)
	l.custom_minimum_size = Vector2(300, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = float(Data.tune[key])
	s.custom_minimum_size = Vector2(300, 44)
	var val := UiTheme.label("×%.2f" % s.value, 20)
	s.value_changed.connect(func(x: float) -> void:
		Data.tune[key] = x
		val.text = "×%.2f" % x
	)
	row.add_child(s)
	row.add_child(val)
	return row
