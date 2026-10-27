class_name BuildPanel
extends Control
## What the hammer builds, in two sections (tabs, from data/buildables.json "tabs"):
## building and decor, and the household things you use. Cards grouped under headings,
## scrolled by dragging anywhere on them. Tap a card to pick it.

signal picked(id: String)
signal closed

var inv: Inventory
var current := ""
var tab := 0
var _body: VBoxContainer
var _scroller: TouchScroll
var _tabs: Array[Button] = []


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
	pc.custom_minimum_size = Vector2(1130, 0)
	cc.add_child(pc)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	pc.add_child(root)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(IconRect.new("hammer", 48.0))
	top.add_child(UiTheme.label(" Что строим?  ", 40, UiTheme.GOLD, true))
	for i in Data.build_tabs.size():
		var b := UiTheme.button(Data.build_tabs[i]["name"], func() -> void: _show(i), 24)
		b.custom_minimum_size = Vector2(230, 60)
		top.add_child(b)
		_tabs.append(b)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(UiTheme.round_button("cross", func() -> void: closed.emit(), 64.0))
	root.add_child(top)
	_scroller = TouchScroll.new()
	_scroller.custom_minimum_size = Vector2(1090, 540)
	root.add_child(_scroller)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	_scroller.add_child(_body)


## Opens on the section that holds what the hammer builds now.
func open(cur: String) -> void:
	current = cur
	var group: String = Data.build_by_id.get(cur, {}).get("group", "")
	for i in Data.build_tabs.size():
		if group in Data.build_tabs[i]["groups"]:
			tab = i
	_show(tab)
	visible = true
	add_child(TapShield.new())


func _show(i: int) -> void:
	tab = i
	for k in _tabs.size():
		_tabs[k].modulate = Color.WHITE if k == tab else Color(0.5, 0.5, 0.5)
	for c in _body.get_children():
		c.queue_free()
	_scroller.clear_taps()
	_scroller.scroll_vertical = 0
	for group: String in Data.build_tabs[tab]["groups"]:
		_body.add_child(UiTheme.label(group, 26, UiTheme.WOOD, true))
		var g := GridContainer.new()
		g.columns = 5
		g.add_theme_constant_override("h_separation", 10)
		g.add_theme_constant_override("v_separation", 10)
		_body.add_child(g)
		for d: Dictionary in Data.build:
			if d["group"] == group:
				g.add_child(_card(d))
	_scroller.settle(_body)


func _card(d: Dictionary) -> Control:
	var c := card_for(d, inv, d["id"] == current)
	_scroller.on_tap(c, func() -> void: picked.emit(d["id"]))
	return c


## A building card, all the same size: a big icon, the name under it and the cost at the
## bottom (have/need, red when short). Also used in the bag's buildings tab.
static func card_for(d: Dictionary, inv: Inventory, sel := false) -> Control:
	var c := CraftPanel.card(Vector2(208, 236), sel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	c.add_child(v)
	# The icon takes whatever the name and the cost leave: no empty gap in short cards.
	var icon := IconRect.new(d["id"], 96.0)
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(icon)
	var name_l := UiTheme.label(d["name"], 19, UiTheme.CREAM, true)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.custom_minimum_size = Vector2(180, 0)
	v.add_child(name_l)
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 0)
	for id: String in d["cost"]:
		var need := int(d["cost"][id])
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 1)
		chip.add_child(IconRect.new(id, 26.0))
		chip.add_child(UiTheme.label("%d/%d" % [inv.count(id), need], 16, UiTheme.CREAM if inv.count(id) >= need else UiTheme.DANGER))
		row.add_child(chip)
	v.add_child(row)
	return c
