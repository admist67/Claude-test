class_name BuildPanel
extends Control
## What the hammer builds: a grid of cards with icon, name and cost. Tap a card to pick it.

signal picked(id: String)
signal closed

var inv: Inventory
var current := ""
var _grid: GridContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.make()
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.04, 0.06, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(1000, 0)
	cc.add_child(pc)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	pc.add_child(root)
	var top := HBoxContainer.new()
	top.add_child(IconRect.new("hammer", 48.0))
	top.add_child(UiTheme.label("  Что строим?", 40, UiTheme.GOLD, true))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(UiTheme.round_button("cross", func() -> void: closed.emit(), 64.0))
	root.add_child(top)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	root.add_child(_grid)


func open(cur: String) -> void:
	current = cur
	for c in _grid.get_children():
		c.queue_free()
	for d: Dictionary in Data.build:
		_grid.add_child(_card(d))
	visible = true
	add_child(TapShield.new())


func _card(d: Dictionary) -> Control:
	var c := CraftPanel.card(Vector2(228, 0), d["id"] == current)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	c.add_child(v)
	var head := HBoxContainer.new()
	head.add_child(IconRect.new(d["id"], 64.0))
	var name_l := UiTheme.label(d["name"], 21, UiTheme.CREAM, true)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.custom_minimum_size = Vector2(130, 0)
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(name_l)
	v.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	for id: String in d["cost"]:
		var need := int(d["cost"][id])
		row.add_child(IconRect.new(id, 30.0))
		row.add_child(UiTheme.label("%d/%d " % [inv.count(id), need], 17, UiTheme.CREAM if inv.count(id) >= need else UiTheme.DANGER))
	v.add_child(row)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Sfx.play("click", -6.0)
			picked.emit(d["id"])
	)
	return c
