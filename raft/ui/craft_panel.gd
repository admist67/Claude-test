class_name CraftPanel
extends Control
## The bag, in three tabs: what you carry (materials, food and water, tools), what you can
## make (recipes by kind) and what the hammer builds (by group). The sea keeps moving.

signal craft_requested(recipe: Dictionary)
signal closed

const TABS := ["Припасы", "Создать", "Постройки"]

var inv: Inventory
var tab := 0
var _tabs: Array[Button] = []
var _body: VBoxContainer
var _scroller: ScrollContainer


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
	_scroller = ScrollContainer.new()
	_scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
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
	_scroller.scroll_vertical = 0
	refresh()


func refresh() -> void:
	for i in _tabs.size():
		_tabs[i].modulate = Color.WHITE if i == tab else Color(0.62, 0.62, 0.62)
	for c in _body.get_children():
		c.queue_free()
	match tab:
		0:
			_supplies()
		1:
			_recipes()
		2:
			_buildings()


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
	var groups := [["Материалы", "resource"], ["Еда и вода", "food"], ["Инструменты", "tool"]]
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


func _slot(id: String, n: int) -> Control:
	var c := card(Vector2(92, 92))
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
	c.tooltip_text = Data.item_name(id)
	return c


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
	var b := UiTheme.button("Сделать", func() -> void: craft_requested.emit(r), 22)
	b.custom_minimum_size = Vector2(150, 60)
	b.disabled = not inv.can_craft(r)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
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
