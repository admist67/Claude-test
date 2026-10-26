class_name CraftPanel
extends Control
## The bag, in three tabs: what you carry (the hotbar to arrange, materials, food and
## water, tools), what you can make (recipes by kind) and what the hammer builds (by group).
## The lists scroll by dragging anywhere on them. The sea keeps moving.

signal craft_requested(recipe: Dictionary)
signal hotbar_changed
signal closed

const TABS := ["Припасы", "Создать", "Постройки"]

var inv: Inventory
var hotbar: HotbarLayout
var carried: Callable            # -> Array[String]: the hotbar items the player has
var condition: Callable          # id -> float: a tool's wear (1 new .. 0), -1 if it does not wear
var tab := 0
var _tabs: Array[Button] = []
var _body: VBoxContainer
var _scroller: TouchScroll
var _pick := ""                  # hotbar item picked to swap with the next one tapped


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.make()
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.04, 0.06, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(1100, 640)
	cc.add_child(pc)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	pc.add_child(root)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(IconRect.new("bag", 48.0, UiTheme.GOLD))
	top.add_child(UiTheme.label(" Сумка  ", 44, UiTheme.GOLD, true))
	for i in TABS.size():
		var b := UiTheme.button(TABS[i], func() -> void: _show(i), 24)
		b.custom_minimum_size = Vector2(190, 60)
		top.add_child(b)
		_tabs.append(b)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(UiTheme.round_button("cross", func() -> void: closed.emit(), 64.0))
	root.add_child(top)
	_scroller = TouchScroll.new()
	_scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_scroller)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	_scroller.add_child(_body)


## A dark rounded card (recipe rows, resource slots).
static func card(min_size: Vector2, sel := false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.box("res://assets/ui/slot_sel.png" if sel else "res://assets/ui/slot.png", 24, Vector4(12, 8, 12, 8)))
	p.custom_minimum_size = min_size
	return p


## Shows the bag; a short shield swallows the tap that opened it.
func open() -> void:
	refresh()
	visible = true
	add_child(TapShield.new())


func _show(i: int) -> void:
	tab = i
	_pick = ""
	_scroller.scroll_vertical = 0
	refresh()


func refresh() -> void:
	for i in _tabs.size():
		_tabs[i].modulate = Color.WHITE if i == tab else Color(0.62, 0.62, 0.62)
	for c in _body.get_children():
		c.queue_free()
	_scroller.clear_taps()
	match tab:
		0:
			_supplies()
		1:
			_recipes()
		2:
			_buildings()
	_scroller.settle(_body)


func _section(title: String) -> void:
	_body.add_child(UiTheme.label(title, 26, UiTheme.WOOD, true))


func _grid(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	_body.add_child(g)
	return g


func _supplies() -> void:
	_hotbar_editor()
	var groups := [["Материалы", "resource"], ["Еда, вода, лечение", "food"], ["Инструменты", "tool"]]
	var any := false
	for gr: Array in groups:
		var ids: Array = Data.items.keys().filter(func(id: String) -> bool: return Data.item(id)["kind"] == gr[1] and inv.count(id) > 0)
		if ids.is_empty():
			continue
		any = true
		_section(gr[0])
		var g := _grid(10)
		for id: String in ids:
			g.add_child(_slot(id, inv.count(id)))
	if not any:
		_body.add_child(UiTheme.label("Пусто. Лови мусор крюком!", 24))


## The hotbar as it is on screen: tap an item, then another — they trade places; a picked
## item can be hidden, and a hidden one comes back with a tap.
func _hotbar_editor() -> void:
	var have: Array[String] = carried.call()
	if have.is_empty():
		return
	var slots := hotbar.slots(have)
	_section("Хотбар — нажми предмет, потом другой: поменяются местами")
	var g := _grid(10)
	for id in slots:
		var s := _slot(id, inv.count(id), id == _pick)
		g.add_child(s)
		_scroller.on_tap(s, _hotbar_tap.bind(id))
	if _pick != "":
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var hide_b := UiTheme.button("Скрыть из хотбара", func() -> void: pass, 22)
		hide_b.custom_minimum_size = Vector2(280, 58)
		hide_b.disabled = slots.size() <= 1 or _pick in hotbar.hidden
		row.add_child(hide_b)
		_scroller.on_tap(hide_b, func() -> void:
			hotbar.hide(_pick)
			_hotbar_done()
		)
		var cancel := UiTheme.button("Отмена", func() -> void: pass, 22)
		cancel.custom_minimum_size = Vector2(170, 58)
		row.add_child(cancel)
		_scroller.on_tap(cancel, func() -> void:
			_pick = ""
			refresh()
		)
		_body.add_child(row)
	var off: Array = have.filter(func(id: String) -> bool: return id in hotbar.hidden)
	if off.is_empty():
		return
	_section("Скрыты — нажми, чтобы вернуть")
	var hg := _grid(10)
	for id: String in off:
		var s := _slot(id, inv.count(id), id == _pick)
		s.modulate = Color(1, 1, 1, 0.55)
		hg.add_child(s)
		_scroller.on_tap(s, func() -> void:
			if _pick != "" and _pick != id:
				hotbar.swap(_pick, id)
			else:
				hotbar.unhide(id)
			_hotbar_done()
		)


func _hotbar_tap(id: String) -> void:
	if _pick == "":
		_pick = id
		refresh()
	elif _pick == id:
		_pick = ""
		refresh()
	else:
		hotbar.swap(_pick, id)
		_hotbar_done()


func _hotbar_done() -> void:
	_pick = ""
	hotbar_changed.emit()
	refresh()


func _slot(id: String, n: int, sel := false) -> Control:
	var c := card(Vector2(92, 92), sel)
	var box := Control.new()
	c.add_child(box)
	var ic := IconRect.new(id, 64.0)
	ic.position = Vector2(2, -4)
	box.add_child(ic)
	var l := UiTheme.label(str(n), 20, Color.WHITE)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(34, 44)
	l.size = Vector2(32, 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(l)
	var k: float = condition.call(id) if condition.is_valid() else -1.0
	if k >= 0.0:
		box.add_child(_wear_bar(k, Vector2(10, 62), 64.0))
	c.tooltip_text = Data.item_name(id)
	return c


## A small bar under a tool: green when new, red when about to break.
static func _wear_bar(k: float, at: Vector2, w: float) -> Control:
	var back := ColorRect.new()
	back.color = Color(0.02, 0.06, 0.08, 0.8)
	back.position = at
	back.size = Vector2(w, 7)
	var fill := ColorRect.new()
	fill.color = wear_color(k)
	fill.position = Vector2(1, 1)
	fill.size = Vector2(maxf(2.0, (w - 2.0) * k), 5)
	back.add_child(fill)
	return back


static func wear_color(k: float) -> Color:
	return Color("#e0503c").lerp(Color("#f0c040"), clampf(k * 2.0, 0.0, 1.0)).lerp(Color("#6cd36c"), clampf(k * 2.0 - 1.0, 0.0, 1.0))


## Cost chips "icon have/need"; compact ones wrap onto several lines (building cards).
func _cost(cost: Dictionary, compact := false) -> Container:
	var row: Container = HFlowContainer.new() if compact else HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for id: String in cost:
		var need := int(cost[id])
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 2)
		chip.add_child(IconRect.new(id, 28.0 if compact else 36.0))
		var ok := inv.count(id) >= need
		chip.add_child(UiTheme.label("%d/%d " % [inv.count(id), need], 16 if compact else 19, UiTheme.CREAM if ok else UiTheme.DANGER))
		row.add_child(chip)
	return row


func _recipes() -> void:
	var groups := [["Инструменты", true], ["Материалы и еда", false]]
	for gr: Array in groups:
		var list: Array = Data.recipes.filter(func(r: Dictionary) -> bool:
			var is_tool: bool = Data.item(r["id"])["kind"] == "tool"
			return is_tool == gr[1] and not (r.get("once", false) and inv.count(r["id"]) > 0)
		)
		if list.is_empty():
			continue
		_section(gr[0])
		var g := _grid(2)
		for r: Dictionary in list:
			g.add_child(_recipe_card(r))


func _recipe_card(r: Dictionary) -> Control:
	var c := card(Vector2(500, 84))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	c.add_child(row)
	row.add_child(IconRect.new(r["id"], 62.0))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name := Data.item_name(r["id"]) + ("" if int(r["out"]) == 1 else " ×%d" % int(r["out"]))
	v.add_child(UiTheme.label(name, 22, UiTheme.CREAM, true))
	v.add_child(_cost(r["cost"], true))
	row.add_child(v)
	var b := UiTheme.button("Сделать", func() -> void: pass, 22)
	b.custom_minimum_size = Vector2(150, 60)
	b.disabled = not inv.can_craft(r)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	_scroller.on_tap(b, func() -> void: craft_requested.emit(r))
	return c


func _buildings() -> void:
	var order: Array = []
	for d: Dictionary in Data.build:
		if not d["group"] in order:
			order.append(d["group"])
	for group: String in order:
		_section(group)
		var g := _grid(4)
		for d: Dictionary in Data.build:
			if d["group"] != group:
				continue
			var c := card(Vector2(246, 0))
			var v := VBoxContainer.new()
			c.add_child(v)
			var head := HBoxContainer.new()
			head.add_child(IconRect.new(d["id"], 54.0))
			var nl := UiTheme.label(d["name"], 18, UiTheme.CREAM)
			nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nl.custom_minimum_size = Vector2(150, 0)
			nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			head.add_child(nl)
			v.add_child(head)
			v.add_child(_cost(d["cost"], true))
			g.add_child(c)
