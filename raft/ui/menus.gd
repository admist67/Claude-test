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


func _open(dim: float, framed := false) -> VBoxContainer:
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
	v.add_theme_constant_override("separation", 14)
	_screen.add_child(TapShield.new())
	if framed:
		var pc := PanelContainer.new()
		pc.custom_minimum_size = Vector2(620, 0)
		cc.add_child(pc)
		pc.add_child(v)
	else:
		cc.add_child(v)
	return v


func _title(text: String, size: int, col := Color.WHITE) -> Label:
	var t := UiTheme.label(text, size, col, true)
	t.add_theme_constant_override("outline_size", maxi(8, size / 8))
	t.add_theme_color_override("font_outline_color", Color("#0b2530"))
	t.add_theme_constant_override("shadow_offset_y", 5)
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return t


func _centered(text: String, size: int, col := UiTheme.CREAM) -> Label:
	var l := UiTheme.label(text, size, col)
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func show_main() -> void:
	var v := _open(0.2)
	v.add_child(_title("ПЛОТ", 150, UiTheme.CREAM))
	v.add_child(_centered("выживание посреди океана", 30))
	v.add_child(_gap(22))
	if has_save:
		v.add_child(UiTheme.button("Продолжить", func() -> void: continue_game.emit()))
	v.add_child(UiTheme.button("Новая игра", func() -> void: new_game.emit()))


func show_pause() -> void:
	var v := _open(0.45, true)
	v.add_child(_title("Пауза", 56, UiTheme.GOLD))
	v.add_child(UiTheme.button("Продолжить", func() -> void: resume.emit()))
	v.add_child(_gap(4))
	v.add_child(UiTheme.label("Настройки для теста", 22, UiTheme.WOOD, true))
	v.add_child(_slider("Чувствительность обзора", "look", 0.4, 2.0))
	v.add_child(_slider("Скорость голода и жажды", "hunger", 0.0, 2.0))
	v.add_child(_slider("Количество мусора", "debris", 0.5, 2.5))
	v.add_child(_slider("Дальность крюка", "hook", 0.6, 1.6))
	v.add_child(_slider("Скорость дня и ночи", "time", 0.25, 4.0))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var snd := UiTheme.button("", func() -> void: pass, 24)
	snd.text = "Звук: вкл" if not Sfx.muted else "Звук: выкл"
	snd.pressed.connect(func() -> void:
		Sfx.set_muted(not Sfx.muted)
		snd.text = "Звук: вкл" if not Sfx.muted else "Звук: выкл"
	)
	snd.custom_minimum_size = Vector2(250, 64)
	row.add_child(snd)
	var menu := UiTheme.button("В меню", func() -> void: to_menu.emit(), 24)
	menu.custom_minimum_size = Vector2(250, 64)
	row.add_child(menu)
	v.add_child(row)


func show_death(cause: String) -> void:
	var v := _open(0.6)
	v.add_child(_title("Ты погиб", 84, UiTheme.DANGER))
	var why := {"thirst": "Океан вокруг, а пить нечего…", "hunger": "Голод победил.", "": "Море было сильнее."}
	v.add_child(_centered(why.get(cause, why[""]), 30))
	v.add_child(_centered("Половина припасов утонула. Плот остался.", 22, Color(1, 1, 1, 0.75)))
	v.add_child(_gap(12))
	v.add_child(UiTheme.button("Очнуться на плоту", func() -> void: respawn.emit()))


func show_message(title: String, text: String, button: String, cb: Callable) -> void:
	var v := _open(0.4, true)
	v.add_child(_title(title, 54, Color("#9be59b")))
	v.add_child(_centered(text, 26))
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
	l.custom_minimum_size = Vector2(290, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = float(Data.tune[key])
	s.custom_minimum_size = Vector2(200, 44)
	var val := UiTheme.label("×%.2f" % s.value, 20)
	s.value_changed.connect(func(x: float) -> void:
		Data.tune[key] = x
		val.text = "×%.2f" % x
	)
	row.add_child(s)
	row.add_child(val)
	return row
