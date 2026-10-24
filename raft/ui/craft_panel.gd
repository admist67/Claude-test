class_name CraftPanel
extends Control
## The bag: what you carry (slots with counts) and what you can make (recipe cards),
## plus what the hammer can build. The sea keeps moving meanwhile.

signal craft_requested(recipe: Dictionary)
signal closed

var inv: Inventory
var _res: GridContainer
var _list: VBoxContainer
var _builds: HBoxContainer


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
	pc.custom_minimum_size = Vector2(1060, 600)
	cc.add_child(pc)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	pc.add_child(root)
	var top := HBoxContainer.new()
	top.add_child(IconRect.new("bag", 48.0, UiTheme.GOLD))
	top.add_child(UiTheme.label("  Сумка", 44, UiTheme.GOLD, true))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(UiTheme.round_button("cross", func() -> void: closed.emit(), 64.0))
	root.add_child(top)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(360, 0)
	left.add_child(UiTheme.label("Припасы", 26, UiTheme.WOOD, true))
	_res = GridContainer.new()
	_res.columns = 4
	_res.add_theme_constant_override("h_separation", 8)
	_res.add_theme_constant_override("v_separation", 8)
	left.add_child(_res)
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	right.add_child(UiTheme.label("Создать", 26, UiTheme.WOOD, true))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	right.add_child(_list)
	right.add_child(UiTheme.label("Построить молотком", 26, UiTheme.WOOD, true))
	_builds = HBoxContainer.new()
	_builds.add_theme_constant_override("separation", 10)
	right.add_child(_builds)
	cols.add_child(right)


## A dark rounded card (recipe rows, resource slots).
static func card(min_size: Vector2, sel := false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.box("res://assets/ui/slot_sel.png" if sel else "res://assets/ui/slot.png", 24, Vector4(12, 8, 12, 8)))
	p.custom_minimum_size = min_size
	return p


func _slot(id: String, n: int) -> Control:
	var c := card(Vector2(84, 84))
	var box := Control.new()
	c.add_child(box)
	var ic := IconRect.new(id, 60.0)
	ic.position = Vector2(0, -4)
	box.add_child(ic)
	var l := UiTheme.label(str(n), 20, Color.WHITE)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(30, 38)
	l.size = Vector2(32, 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(l)
	c.tooltip_text = Data.item_name(id)
	return c


func _cost(cost: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for id: String in cost:
		var need := int(cost[id])
		row.add_child(IconRect.new(id, 38.0))
		var ok := inv.count(id) >= need
		row.add_child(UiTheme.label("%d/%d " % [inv.count(id), need], 20, UiTheme.CREAM if ok else UiTheme.DANGER))
	return row


## Shows the bag; a short shield swallows the tap that opened it.
func open() -> void:
	refresh()
	visible = true
	add_child(TapShield.new())


func refresh() -> void:
	for box: Node in [_res, _list, _builds]:
		for c in box.get_children():
			c.queue_free()
	var any := false
	for id: String in Data.items:
		if Data.item(id)["kind"] == "tool" or inv.count(id) == 0:
			continue
		any = true
		_res.add_child(_slot(id, inv.count(id)))
	if not any:
		_res.add_child(UiTheme.label("Пусто.\nЛови мусор крюком!", 22))
	for r: Dictionary in Data.recipes:
		if r.get("once", false) and inv.count(r["id"]) > 0:
			continue
		var c := card(Vector2(0, 80))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		c.add_child(row)
		row.add_child(IconRect.new(r["id"], 64.0))
		var name_l := UiTheme.label(Data.item_name(r["id"]), 26, UiTheme.CREAM, true)
		name_l.custom_minimum_size = Vector2(170, 0)
		name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_l)
		var cost := _cost(r["cost"])
		cost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(cost)
		var b := UiTheme.button("Сделать", func() -> void: craft_requested.emit(r), 24)
		b.custom_minimum_size = Vector2(170, 64)
		b.disabled = not inv.can_craft(r)
		row.add_child(b)
		_list.add_child(c)
	for d: Dictionary in Data.build:
		var c := card(Vector2(0, 0))
		var v := VBoxContainer.new()
		c.add_child(v)
		var head := HBoxContainer.new()
		head.add_child(IconRect.new(d["id"], 52.0))
		head.add_child(UiTheme.label(d["name"], 19, UiTheme.CREAM))
		v.add_child(head)
		var cost := _cost(d["cost"])
		v.add_child(cost)
		_builds.add_child(c)
