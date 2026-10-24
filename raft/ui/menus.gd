class_name Menus
extends Control
## Main menu, worlds (up to SaveGame.MAX named saves: play, rename, delete), pause (save,
## save as a new world, playtest tuning sliders) and the death screen.

signal new_game(world_name: String)
signal play_world(id: int)
signal save_now
signal save_as(world_name: String)
signal resume
signal to_menu
signal respawn

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


func _open(dim: float, framed := false, top_half := false) -> VBoxContainer:
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
	if top_half:
		cc.anchor_bottom = 0.55     # above the on-screen keyboard
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
	var last := SaveGame.last()
	if last >= 0:
		v.add_child(UiTheme.button("Продолжить", func() -> void: play_world.emit(last)))
		v.add_child(_centered(SaveGame.info(last)["name"] + " · " + _when(SaveGame.info(last)), 20, Color(1, 1, 1, 0.8)))
	v.add_child(UiTheme.button("Новая игра", _ask_new))
	if not SaveGame.worlds().is_empty():
		v.add_child(UiTheme.button("Миры (%d из %d)" % [SaveGame.worlds().size(), SaveGame.MAX], show_worlds))


func _ask_new() -> void:
	if not SaveGame.can_add():
		_full(show_main)
		return
	ask_name("Новый мир", SaveGame.next_name(), "Начать", func(n: String) -> void: new_game.emit(n), show_main)


func _full(back: Callable) -> void:
	show_message("Миров уже %d" % SaveGame.MAX, "Удали лишний мир в меню «Миры», чтобы начать новый.", "Назад", back)


## Day, time played and when the world was saved, for the lists.
func _when(w: Dictionary) -> String:
	var mins := int(float(w["played"]) / 60.0)
	var played := "%d мин" % mins if mins < 60 else "%d ч %d мин" % [mins / 60, mins % 60]
	var t := Time.get_datetime_dict_from_unix_time(int(float(w["time"])) + int(Time.get_time_zone_from_system()["bias"]) * 60)
	return "день %d · %s · %02d.%02d %02d:%02d" % [int(w["day"]), played, t["day"], t["month"], t["hour"], t["minute"]]


func show_worlds() -> void:
	var v := _open(0.45, true)
	var list := SaveGame.worlds()
	v.add_child(_title("Миры", 56, UiTheme.GOLD))
	v.add_child(_centered("%d из %d" % [list.size(), SaveGame.MAX], 20, Color(1, 1, 1, 0.75)))
	var sc := TouchScroll.new()
	sc.custom_minimum_size = Vector2(880, mini(list.size(), 4) * 92)
	v.add_child(sc)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)
	sc.add_child(rows)
	for w: Dictionary in list:
		var id := int(w["id"])
		var c := CraftPanel.card(Vector2(860, 84), id == SaveGame.last())
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		c.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UiTheme.label(w["name"], 26, UiTheme.CREAM, true))
		info.add_child(UiTheme.label(_when(w), 18, Color(1, 1, 1, 0.75)))
		row.add_child(info)
		var btns := [["Играть", 170, func() -> void: play_world.emit(id)], ["Имя", 110, _rename.bind(w)], ["Удалить", 140, _confirm_delete.bind(w)]]
		for b: Array in btns:
			var btn := UiTheme.button(b[0], func() -> void: pass, 22)
			btn.custom_minimum_size = Vector2(b[1], 60)
			btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(btn)
			sc.on_tap(btn, b[2])
		rows.add_child(c)
	sc.settle(rows)
	var back := UiTheme.button("Назад", show_main, 24)
	back.custom_minimum_size = Vector2(250, 64)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)


func _rename(w: Dictionary) -> void:
	ask_name("Название мира", w["name"], "Готово", _renamed.bind(int(w["id"])), show_worlds)


func _renamed(world_name: String, id: int) -> void:
	SaveGame.rename(id, world_name)
	show_worlds()


func _delete(id: int) -> void:
	SaveGame.remove(id)
	if SaveGame.worlds().is_empty():
		show_main()
	else:
		show_worlds()


func _confirm_delete(w: Dictionary) -> void:
	var v := _open(0.5, true)
	v.add_child(_title("Удалить «%s»?" % w["name"], 44, UiTheme.DANGER))
	v.add_child(_centered("Плот, припасы и постройки этого мира пропадут.", 24))
	v.add_child(_gap(8))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var yes := UiTheme.button("Удалить", _delete.bind(int(w["id"])), 24)
	yes.custom_minimum_size = Vector2(230, 64)
	row.add_child(yes)
	var no := UiTheme.button("Отмена", show_worlds, 24)
	no.custom_minimum_size = Vector2(230, 64)
	row.add_child(no)
	v.add_child(row)


## A name box (opens the phone keyboard), above the keyboard.
func ask_name(title: String, def: String, ok: String, done: Callable, back: Callable) -> void:
	var v := _open(0.5, true, true)
	v.add_child(_title(title, 48, UiTheme.GOLD))
	var le := LineEdit.new()
	le.text = def
	le.max_length = 24
	le.select_all_on_focus = true
	le.custom_minimum_size = Vector2(560, 66)
	le.add_theme_font_size_override("font_size", 30)
	le.alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(le)
	var go := func() -> void:
		var n := le.text.strip_edges()
		done.call(n if n != "" else def)
	le.text_submitted.connect(func(_t: String) -> void: go.call())
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var yes := UiTheme.button(ok, go, 24)
	yes.custom_minimum_size = Vector2(230, 64)
	row.add_child(yes)
	var no := UiTheme.button("Назад", back, 24)
	no.custom_minimum_size = Vector2(230, 64)
	row.add_child(no)
	v.add_child(row)


func _ask_save_as(world_name: String) -> void:
	var back := func() -> void: show_pause(world_name)
	if not SaveGame.can_add():
		_full(back)
		return
	ask_name("Сохранить как новый мир", world_name + " 2", "Сохранить", func(n: String) -> void: save_as.emit(n), back)


func show_pause(world_name: String, note := "") -> void:
	var v := _open(0.45, true)
	v.add_child(_title("Пауза", 56, UiTheme.GOLD))
	v.add_child(_centered("Мир: " + world_name + ("   ✓ " + note if note != "" else ""), 20, Color("#9be59b") if note != "" else Color(1, 1, 1, 0.75)))
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 14)
	var btns := [["Продолжить", 250, func() -> void: resume.emit()], ["Сохранить", 210, func() -> void: save_now.emit()], ["Сохранить как…", 250, _ask_save_as.bind(world_name)]]
	for b: Array in btns:
		var btn := UiTheme.button(b[0], b[2], 24)
		btn.custom_minimum_size = Vector2(b[1], 64)
		top.add_child(btn)
	v.add_child(top)
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
	var menu := UiTheme.button("В меню (миры)", func() -> void: to_menu.emit(), 24)
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
