class_name CraftPanel
extends Control
## The bag: what you carry and what you can make from it. The sea keeps moving meanwhile.

signal craft_requested(recipe: Dictionary)
signal closed

var inv: Inventory
var _res: GridContainer
var _list: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.make()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(980, 520)
	cc.add_child(pc)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	pc.add_child(root)
	var top := HBoxContainer.new()
	top.add_child(UiTheme.label("Сумка", 34))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var x := UiTheme.button("Закрыть", func() -> void: closed.emit(), 26)
	x.custom_minimum_size = Vector2(180, 60)
	top.add_child(x)
	root.add_child(top)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 34)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(330, 0)
	left.add_child(UiTheme.label("Припасы", 24, UiTheme.WOOD))
	_res = GridContainer.new()
	_res.columns = 2
	_res.add_theme_constant_override("h_separation", 22)
	_res.add_theme_constant_override("v_separation", 8)
	left.add_child(_res)
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(UiTheme.label("Создать", 24, UiTheme.WOOD))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	right.add_child(_list)
	cols.add_child(right)


func refresh() -> void:
	for c in _res.get_children():
		c.queue_free()
	for c in _list.get_children():
		c.queue_free()
	var any := false
	for id: String in Data.items:
		if Data.item(id)["kind"] == "tool" or inv.count(id) == 0:
			continue
		any = true
		var row := HBoxContainer.new()
		row.add_child(IconRect.new(id, 40.0))
		row.add_child(UiTheme.label("%s × %d" % [Data.item_name(id), inv.count(id)], 22))
		_res.add_child(row)
	if not any:
		_res.add_child(UiTheme.label("Пусто. Лови мусор крюком!", 22))
	for r: Dictionary in Data.recipes:
		if r.get("once", false) and inv.count(r["id"]) > 0:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(IconRect.new(r["id"], 52.0))
		var name_l := UiTheme.label(Data.item_name(r["id"]), 26)
		name_l.custom_minimum_size = Vector2(170, 0)
		row.add_child(name_l)
		for id: String in r["cost"]:
			var need := int(r["cost"][id])
			row.add_child(IconRect.new(id, 36.0))
			row.add_child(UiTheme.label("%d/%d" % [inv.count(id), need], 22, UiTheme.CREAM if inv.count(id) >= need else Color("#ff8a7a")))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sp)
		var b := UiTheme.button("Сделать", func() -> void: craft_requested.emit(r), 24)
		b.custom_minimum_size = Vector2(170, 62)
		b.disabled = not inv.can_craft(r)
		row.add_child(b)
		_list.add_child(row)
	var cost: Dictionary = Data.b["raft"]["tile_cost"]
	var hint := "Клетка плота (молотком): "
	for id: String in cost:
		hint += "%s × %d  " % [Data.item_name(id), int(cost[id])]
	var l := UiTheme.label(hint, 20, Color(1, 1, 1, 0.7))
	_list.add_child(l)
