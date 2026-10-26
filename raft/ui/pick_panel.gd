class_name PickPanel
extends Control
## "What goes in?": cards for each item a station can take (icon, name, how many you
## have, what comes out). Tap one to put it in; the cross closes without choosing.

signal picked(id: String)
signal closed

var _title: Label
var _row: GridContainer
var _scroller: TouchScroll


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
	pc.custom_minimum_size = Vector2(1010, 0)
	cc.add_child(pc)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	pc.add_child(root)
	var top := HBoxContainer.new()
	_title = UiTheme.label("", 38, UiTheme.GOLD, true)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	top.add_child(UiTheme.round_button("cross", func() -> void: closed.emit(), 64.0))
	root.add_child(top)
	_scroller = TouchScroll.new()
	_scroller.custom_minimum_size = Vector2(970, 300)
	root.add_child(_scroller)
	_row = GridContainer.new()
	_row.columns = 3
	_row.add_theme_constant_override("h_separation", 12)
	_row.add_theme_constant_override("v_separation", 12)
	_scroller.add_child(_row)


## options: [{"id", "count", "out", "out_n"}].
func open(title: String, options: Array) -> void:
	_title.text = title
	for c in _row.get_children():
		c.queue_free()
	_scroller.clear_taps()
	for o: Dictionary in options:
		var card := CraftPanel.card(Vector2(312, 0))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		card.add_child(v)
		var head := HBoxContainer.new()
		head.add_child(IconRect.new(o["id"], 64.0))
		var nl := UiTheme.label(Data.item_name(o["id"]), 20, UiTheme.CREAM, true)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.custom_minimum_size = Vector2(210, 0)
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		head.add_child(nl)
		v.add_child(head)
		v.add_child(UiTheme.label("Есть: %d" % int(o["count"]), 18, Color(1, 1, 1, 0.75)))
		var out := HBoxContainer.new()
		out.add_child(UiTheme.label("→ ", 20, UiTheme.GOLD))
		out.add_child(IconRect.new(o["out"], 32.0))
		var n := int(o.get("out_n", 1))
		out.add_child(UiTheme.label(" " + Data.item_name(o["out"]) + ("" if n == 1 else " ×%d" % n), 17, UiTheme.CREAM))
		v.add_child(out)
		_row.add_child(card)
		var id: String = o["id"]
		_scroller.on_tap(card, func() -> void: picked.emit(id))
	_scroller.settle(_row)
	visible = true
	add_child(TapShield.new())
