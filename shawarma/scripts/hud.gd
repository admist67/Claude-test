extends CanvasLayer
## Top bar (today's cash vs goal, clock, rating, pause) and the menu / note / summary / pause screens.

signal start_pressed
signal note_closed
signal next_day_pressed
signal menu_pressed
signal resume_pressed
signal pause_pressed
signal sound_toggled
signal shop_pressed
signal shop_closed
signal buy_pressed(id: String)
signal shop_tab(tab: String)
signal endless_pressed
signal new_game_pressed

var bar: Bar
var pause_btn: Button
var screen: Control
var theme_res: Theme


class Bar extends Node2D:
	var money := 0.0
	var shown := 0.0
	var goal := 1200
	var clock := "18:00"
	var rating := 0.0
	var rush := false
	var bump := 0.0
	var width := 720.0
	var combo := 0
	var combo_mult := 1.0
	var combo_bump := 0.0

	func _process(delta: float) -> void:
		shown = move_toward(shown, money, maxf(40.0, absf(money - shown) * 6.0) * delta)
		bump = maxf(0.0, bump - delta * 4.0)
		combo_bump = maxf(0.0, combo_bump - delta * 3.0)
		queue_redraw()

	func _draw() -> void:
		var s := 1.0 + sin(bump * PI) * 0.08
		draw_set_transform(Vector2(119, 36), 0.0, Vector2(s, s))
		var r := Rect2(-107, -26, 214, 52)
		DU.rect(self, r, 26.0, DU.CREAM, 4.0, 5.0)
		var f := clampf(shown / maxf(1.0, goal), 0.0, 1.0)
		if f > 0.05:
			draw_colored_polygon(DU.rrect_pts(Rect2(r.position + Vector2(4, 4), Vector2((r.size.x - 8) * f, r.size.y - 8)), 22.0), Color("#b9f0cf") if f < 1.0 else Color("#7fe0a6"))
		DU.coin(self, Vector2(-80, 0), 17.0)
		DU.text(self, Vector2(18, -1), "%d / %d" % [roundi(shown), goal], 24, DU.INK, 0)
		draw_set_transform(Vector2.ZERO)
		var cr := Rect2(width / 2.0 - 98.0, 10, 196, 52)
		DU.rect(self, cr, 26.0, Color("#ff4fa3") if rush else DU.CREAM, 4.0, 5.0)
		var moon := Vector2(cr.position.x + 30, cr.get_center().y)
		DU.circle(self, moon, 13.0, DU.GOLD, 3.0)
		draw_circle(moon + Vector2(7, -5), 11.0, Color("#ff4fa3") if rush else DU.CREAM)
		DU.text(self, cr.get_center() + Vector2(16, -1), clock, 28, Color.WHITE if rush else DU.INK, 6 if rush else 0)
		var rr := Rect2(width - 272.0, 10, 180, 52)
		DU.rect(self, rr, 26.0, DU.CREAM, 4.0, 5.0)
		DU.star(self, Vector2(rr.position.x + 30, rr.get_center().y), 17.0, DU.GOLD, 3.0)
		DU.text(self, rr.get_center() + Vector2(16, -1), "—" if rating <= 0.0 else "%.1f" % rating, 28, DU.INK, 0)
		if combo >= 2:
			var cs := 1.0 + sin(combo_bump * PI) * 0.25
			draw_set_transform(Vector2(119, 92), sin(combo_bump * 12.0) * 0.08 * combo_bump, Vector2(cs, cs))
			DU.rect(self, Rect2(-95, -20, 190, 40), 20.0, Color("#ff5a2a"), 4.0, 4.0)
			var fl := PackedVector2Array([Vector2(-72, 12), Vector2(-82, -2), Vector2(-74, -6), Vector2(-76, -16), Vector2(-64, -4), Vector2(-62, -12), Vector2(-56, 4), Vector2(-60, 12)])
			DU.poly(self, fl, DU.GOLD, 2.5)
			DU.text(self, Vector2(14, -1), "КОМБО ×%s" % str(snappedf(combo_mult, 0.01)), 22, Color.WHITE, 6)
			draw_set_transform(Vector2.ZERO)


class Logo extends Control:
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var wob := sin(t * 2.0) * 0.03
		draw_set_transform(c + Vector2(0, -50), wob, Vector2.ONE)
		DU.text(self, Vector2(0, 8), "ШАУРМА", 104, DU.ORANGE.darkened(0.3), 0)
		DU.text(self, Vector2.ZERO, "ШАУРМА", 104, DU.CREAM, 16)
		draw_set_transform(c + Vector2(0, 62), -wob, Vector2.ONE)
		DU.rect(self, Rect2(-120, -44, 240, 88), 30.0, DU.ORANGE, 6.0, 8.0)
		DU.text(self, Vector2.ZERO, "ШЕФ", 66, Color.WHITE, 12)
		DU.roll(self, Vector2(195, -10), 5.0, Bal.b, 0.75, -0.5, ["tomato", "cucumber"])
		draw_set_transform(Vector2.ZERO)


class Stars extends Control:
	var count := 0
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		for i in 3:
			var on := i < count
			var appear := clampf((t - 0.3 - i * 0.35) * 4.0, 0.0, 1.0) if on else 1.0
			var s := (1.0 + sin(appear * PI) * 0.4) * (appear if on else 1.0)
			var c := Vector2(size.x / 2.0 + (i - 1) * 96.0, size.y / 2.0 + (0.0 if i == 1 else 14.0))
			draw_set_transform(c, 0.0, Vector2(s, s))
			DU.star(self, Vector2.ZERO, 42.0 if i == 1 else 36.0, DU.GOLD if on else Color("#d9d0c2"), 5.0)
			draw_set_transform(Vector2.ZERO)


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme_res = _make_theme()
	bar = Bar.new()
	add_child(bar)
	pause_btn = Button.new()
	pause_btn.text = "II"
	pause_btn.theme = theme_res
	pause_btn.position = Vector2(638, 8)
	pause_btn.size = Vector2(72, 56)
	pause_btn.add_theme_font_size_override("font_size", 28)
	pause_btn.pressed.connect(func(): Sfx.play("ui"); pause_pressed.emit())
	add_child(pause_btn)


func set_width(w: float) -> void:
	bar.width = w
	pause_btn.position = Vector2(w - 82.0, 8)


func set_bar_visible(on: bool) -> void:
	bar.visible = on
	pause_btn.visible = on


func clear_screen() -> void:
	if screen:
		screen.queue_free()
		screen = null


func _new_screen(dim := 0.45) -> VBoxContainer:
	clear_screen()
	screen = Control.new()
	screen.theme = theme_res
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(screen)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.05, 0.12, dim)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	screen.modulate.a = 0.0
	screen.create_tween().tween_property(screen, "modulate:a", 1.0, 0.2)
	return box


func _panel(box: VBoxContainer) -> VBoxContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(600, 0)
	box.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	return v


func _label(parent: Control, text: String, size := 28, color := DU.INK, center := true, width := 520.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(width, 0)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _button(parent: Control, text: String, cb: Callable, primary := true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(420, 92)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if not primary:
		b.add_theme_stylebox_override("normal", _box(Color("#8e7dff"), 24))
		b.add_theme_stylebox_override("hover", _box(Color("#8e7dff").lightened(0.1), 24))
		b.add_theme_stylebox_override("pressed", _box(Color("#8e7dff").darkened(0.15), 24))
		b.custom_minimum_size = Vector2(420, 76)
		b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(func():
		Sfx.play("ui")
		Sfx.buzz(15)
		cb.call()
	)
	parent.add_child(b)
	return b


func show_menu(day: int, bank: int, sound_on: bool, has_shop := false) -> void:
	set_bar_visible(false)
	var box := _new_screen(0.35)
	var logo := Logo.new()
	logo.custom_minimum_size = Vector2(640, 270)
	box.add_child(logo)
	var day_text := "День %d из 15" % day if day <= 15 else "День %d · без конца" % day
	_label(box, "%s   ·   В кассе: %d ₽" % [day_text, bank], 28, DU.CREAM).add_theme_constant_override("outline_size", 8)
	_button(box, "Начать смену", func(): start_pressed.emit())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	if has_shop:
		var shop_b := _button(row, "Магазин", func(): shop_pressed.emit(), false)
		shop_b.custom_minimum_size = Vector2(260, 76)
	var snd := _button(row, "Звук: вкл" if sound_on else "Звук: выкл", func(): sound_toggled.emit(), false)
	snd.custom_minimum_size = Vector2(260, 76)


func show_note(day: int, note: String, goal: int, new_items: Array, event := {}) -> void:
	set_bar_visible(false)
	var v := _panel(_new_screen())
	var panel: Control = v.get_parent()
	panel.custom_minimum_size = Vector2(760, 0)
	_label(v, "День %d" % day, 42, DU.ORANGE.darkened(0.2))
	_label(v, "Записка от дяди Ромы", 22, Color("#7a6d96"))
	_label(v, note, 26, DU.INK, true, 680.0)
	if not new_items.is_empty():
		_label(v, "Новое: " + ", ".join(new_items), 26, Color("#2a9d5c"))
	if not event.is_empty():
		_label(v, "Событие дня: %s — %s" % [event["title"], event["desc"]], 25, Color("#7b4fd6"), true, 680.0)
	_label(v, "Цель смены: %d ₽" % goal, 30, DU.INK)
	_button(v, "Открываемся!", func(): note_closed.emit())


func show_summary(st: Dictionary) -> void:
	set_bar_visible(false)
	var v := _panel(_new_screen(0.55))
	_label(v, "Смена окончена!", 44, DU.ORANGE.darkened(0.2))
	var stars := Stars.new()
	stars.count = st["stars"]
	stars.custom_minimum_size = Vector2(520, 96)
	v.add_child(stars)
	var rows := [
		["Обслужено", "%d" % st["served"]],
		["Ушли недовольными", "%d" % st["lost"]],
		["Выручка", "%d ₽" % st["revenue"]],
		["Чаевые", "%d ₽" % st["tips"]],
		["Рейтинг", "—" if st["rating"] <= 0.0 else "%.1f ★" % st["rating"]],
	]
	if int(st.get("wages", 0)) > 0:
		rows.append(["Зарплаты персоналу", "-%d ₽" % st["wages"]])
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(grid)
	for r in rows:
		var a := Label.new()
		a.text = r[0]
		a.add_theme_color_override("font_color", Color("#6b5a7a"))
		a.add_theme_font_size_override("font_size", 26)
		grid.add_child(a)
		var b := Label.new()
		b.text = r[1]
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_theme_color_override("font_color", DU.INK)
		b.add_theme_font_size_override("font_size", 26)
		grid.add_child(b)
	_label(v, "Итого за день: %d ₽  (цель %d)" % [st["total"], st["goal"]], 28, Color("#2a9d5c") if st["total"] >= st["goal"] else DU.RED)
	_button(v, "Следующий день", func(): next_day_pressed.emit())
	_button(v, "В меню", func(): menu_pressed.emit(), false)


## items: [{id, name, desc, level, max, price, locked}] — price < 0 when maxed out,
## locked = reason text when it can't be bought yet.
func show_shop(bank: int, items: Array, tab := "kitchen") -> void:
	set_bar_visible(false)
	var box := _new_screen(0.62)
	box.add_theme_constant_override("separation", 10)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(head)
	var title := _label(head, "Магазин дяди Ромы", 38, DU.CREAM, false, 0.0)
	title.add_theme_constant_override("outline_size", 12)
	var cash := _label(head, "В кассе: %d ₽" % bank, 28, DU.GOLD, false, 0.0)
	cash.add_theme_constant_override("outline_size", 8)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 14)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(tabs)
	for spec in [["kitchen", "Кухня"], ["cafe", "Кафе и персонал"]]:
		var tid: String = spec[0]
		var tb := _button(tabs, spec[1], func(): shop_tab.emit(tid), tid == tab)
		tb.custom_minimum_size = Vector2(300, 60)
		tb.add_theme_font_size_override("font_size", 26)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(grid)
	for it in items:
		var card := PanelContainer.new()
		var sb := _box(DU.CREAM, 20)
		sb.content_margin_left = 16
		sb.content_margin_right = 12
		sb.content_margin_top = 8
		sb.content_margin_bottom = 10
		card.add_theme_stylebox_override("panel", sb)
		card.custom_minimum_size = Vector2(580, 0)
		grid.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		row.add_child(col)
		var name_l := Label.new()
		name_l.text = it["name"] if int(it["max"]) == 1 else "%s  (%d/%d)" % [it["name"], it["level"], it["max"]]
		name_l.add_theme_font_size_override("font_size", 23)
		name_l.add_theme_color_override("font_color", DU.INK)
		col.add_child(name_l)
		var desc_l := Label.new()
		desc_l.text = it["desc"]
		desc_l.add_theme_font_size_override("font_size", 18)
		desc_l.add_theme_color_override("font_color", Color("#6b5a7a"))
		desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_l.custom_minimum_size = Vector2(340, 0)
		col.add_child(desc_l)
		var price: int = it["price"]
		var locked: String = it.get("locked", "")
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(176, 64)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.add_theme_font_size_override("font_size", 24 if locked == "" else 18)
		btn.text = locked if locked != "" else ("Куплено" if price < 0 else "%d ₽" % price)
		btn.disabled = locked != "" or price < 0 or price > bank
		var id: String = it["id"]
		btn.pressed.connect(func():
			Sfx.play("cash", 0.02)
			Sfx.buzz(25)
			buy_pressed.emit(id)
		)
		row.add_child(btn)
	var next_b := _button(box, "Дальше", func(): shop_closed.emit())
	next_b.custom_minimum_size = Vector2(360, 80)


func show_finale(stars: int, max_stars: int, title: String, text: String) -> void:
	set_bar_visible(false)
	var v := _panel(_new_screen(0.65))
	var panel: Control = v.get_parent()
	panel.custom_minimum_size = Vector2(760, 0)
	_label(v, "Дядя Рома вернулся!", 42, DU.ORANGE.darkened(0.2))
	var st := Stars.new()
	st.count = 3 if stars >= max_stars * 0.8 else (2 if stars >= max_stars * 0.5 else 1)
	st.custom_minimum_size = Vector2(520, 96)
	v.add_child(st)
	_label(v, "Звёзд за 15 дней: %d из %d" % [stars, max_stars], 26, Color("#6b5a7a"))
	_label(v, title, 36, DU.INK)
	_label(v, text, 25, DU.INK, true, 680.0)
	_button(v, "Играть дальше", func(): endless_pressed.emit())
	_button(v, "Новая игра", func(): new_game_pressed.emit(), false)


func show_pause() -> void:
	var v := _panel(_new_screen(0.6))
	_label(v, "Пауза", 44, DU.ORANGE.darkened(0.2))
	_label(v, "Настройки для теста баланса", 22, Color("#7a6d96"))
	var specs := [["patience", "Терпение клиентов"], ["spawn", "Частота клиентов"], ["grill", "Скорость гриля"]]
	if Bal.tune.has("look"):
		specs.append(["look", "Чувствительность обзора"])
	for spec in specs:
		var key: String = spec[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		v.add_child(row)
		var l := _label(row, "%s: x%.1f" % [spec[1], Bal.tune[key]], 22, DU.INK, false)
		l.custom_minimum_size = Vector2(330, 0)
		var s := HSlider.new()
		s.min_value = 0.5
		s.max_value = 2.0
		s.step = 0.1
		s.value = Bal.tune[key]
		s.custom_minimum_size = Vector2(240, 44)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		s.value_changed.connect(func(val: float):
			Bal.tune[key] = val
			l.text = "%s: x%.1f" % [spec[1], val]
		)
		row.add_child(s)
	_button(v, "Продолжить", func(): resume_pressed.emit())
	_button(v, "В меню", func(): menu_pressed.emit(), false)


func _box(col: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = DU.INK
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = DU.SHADOW
	sb.shadow_size = 1
	sb.shadow_offset = Vector2(0, 7)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 10
	sb.content_margin_bottom = 14
	return sb


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = DU.FONT
	th.default_font_size = 28
	var panel := _box(DU.CREAM, 34)
	panel.content_margin_left = 36
	panel.content_margin_right = 36
	panel.content_margin_top = 30
	panel.content_margin_bottom = 34
	th.set_stylebox("panel", "PanelContainer", panel)
	th.set_stylebox("normal", "Button", _box(DU.ORANGE, 28))
	th.set_stylebox("hover", "Button", _box(DU.ORANGE.lightened(0.08), 28))
	var pressed := _box(DU.ORANGE.darkened(0.15), 28)
	pressed.shadow_offset = Vector2(0, 2)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_stylebox("disabled", "Button", _box(Color("#c9c2d6"), 28))
	th.set_color("font_disabled_color", "Button", Color("#f4f0fa"))
	th.set_color("font_color", "Button", Color.WHITE)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", DU.CREAM)
	th.set_color("font_outline_color", "Button", DU.INK)
	th.set_constant("outline_size", "Button", 10)
	th.set_font_size("font_size", "Button", 36)
	th.set_color("font_outline_color", "Label", DU.INK)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#e6dccb")
	track.border_color = DU.INK
	track.set_border_width_all(3)
	track.set_corner_radius_all(10)
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	th.set_stylebox("slider", "HSlider", track)
	var fill := track.duplicate()
	fill.bg_color = DU.ORANGE
	th.set_stylebox("grabber_area", "HSlider", fill)
	th.set_stylebox("grabber_area_highlight", "HSlider", fill)
	return th
