class_name StoragePanel
extends Control
## An open chest: what you carry on the left, what is inside on the right. Tap an item to
## move it across, the whole stack or one at a time (the toggle); its name pops up over
## it where it landed. An island chest only gives: take its things before the island
## drifts away.

signal closed
signal moved(id: String, n: int, into_chest: bool)

var inv: Inventory
var condition: Callable           # id -> tool wear (as the bag shows it)
var store: Dictionary = {}        # the chest's items (the chest's own dictionary)
var slots := 20                   # how many kinds fit
var take_only := false
var one := false                  # move one at a time instead of the whole stack
var _title: Label
var _mine: GridContainer
var _box: GridContainer
var _ms: TouchScroll
var _bs: TouchScroll
var _mode: Button
var _mine_title: Label
var _tip: ItemTip
var _mine_slots := {}             # id -> its card on my side
var _box_slots := {}              # id -> its card on the chest's side


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
	pc.custom_minimum_size = Vector2(1180, 0)
	cc.add_child(pc)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	pc.add_child(root)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.add_child(IconRect.new("chest", 52.0))
	_title = UiTheme.label("", 38, UiTheme.GOLD, true)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	_mode = UiTheme.button("", _toggle, 20)
	_mode.custom_minimum_size = Vector2(220, 58)
	top.add_child(_mode)
	var all := UiTheme.button("Забрать всё", _take_all, 20)
	all.custom_minimum_size = Vector2(200, 58)
	top.add_child(all)
	top.add_child(UiTheme.round_button("cross", func() -> void: closed.emit(), 64.0))
	root.add_child(top)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	root.add_child(body)
	var lp := _pane(body, "У тебя — нажми, чтобы положить")
	_ms = lp[0]
	_mine = lp[1]
	_mine_title = lp[2]
	var rp := _pane(body, "В сундуке — нажми, чтобы забрать")
	_bs = rp[0]
	_box = rp[1]
	_tip = ItemTip.new()
	add_child(_tip)


func _pane(parent: Control, title: String) -> Array:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	parent.add_child(v)
	var l := UiTheme.label(title, 22, UiTheme.WOOD, true)
	v.add_child(l)
	var sc := TouchScroll.new()
	sc.custom_minimum_size = Vector2(560, 440)
	v.add_child(sc)
	var g := GridContainer.new()
	g.columns = 5
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	sc.add_child(g)
	return [sc, g, l]


func open(title: String, items: Dictionary, n_slots: int, only_take: bool) -> void:
	_title.text = title
	store = items
	slots = n_slots
	take_only = only_take
	refresh()
	visible = true
	add_child(TapShield.new())


func refresh() -> void:
	_mode.text = "Брать: по одному" if one else "Брать: всё сразу"
	for g: GridContainer in [_mine, _box]:
		for c in g.get_children():
			c.queue_free()
	_ms.clear_taps()
	_bs.clear_taps()
	_mine_slots.clear()
	_box_slots.clear()
	for id: String in _sorted(store.keys()):
		var s := CraftPanel.item_slot(id, int(store[id]), false, _wear(id))
		_box.add_child(s)
		_bs.on_tap(s, _take.bind(id))
		_box_slots[id] = s
	if store.is_empty():
		_box.add_child(UiTheme.label("Пусто", 22, Color(1, 1, 1, 0.6)))
	_mine_title.text = "Забирай всё: остров скоро уплывёт" if take_only else "У тебя — нажми, чтобы положить (%d/%d мест)" % [store.size(), slots]
	if not take_only:
		var mine: Array = Data.items.keys().filter(func(id: String) -> bool: return inv.count(id) > 0)
		for id: String in mine:
			var s := CraftPanel.item_slot(id, inv.count(id), false, _wear(id))
			_mine.add_child(s)
			_ms.on_tap(s, _put.bind(id))
			_mine_slots[id] = s
	_ms.settle(_mine)
	_bs.settle(_box)


func _wear(id: String) -> float:
	return condition.call(id) if condition.is_valid() else -1.0


## Ids in item-list order.
func _sorted(ids: Array) -> Array:
	var order: Array = Data.items.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return order.find(a) < order.find(b))
	return ids


func _toggle() -> void:
	one = not one
	refresh()


func _take(id: String) -> void:
	var n := 1 if one else int(store[id])
	store[id] = int(store[id]) - n
	if int(store[id]) <= 0:
		store.erase(id)
	inv.add(id, n)
	moved.emit(id, n, false)
	refresh()
	if _mine_slots.has(id):
		_tip.show_over(Data.item_name(id), _mine_slots[id])


func _put(id: String) -> void:
	if not store.has(id) and store.size() >= slots:
		Events.toast.emit("В сундуке нет места", "chest")
		return
	var n := 1 if one else inv.count(id)
	if not inv.remove(id, n):
		return
	store[id] = int(store.get(id, 0)) + n
	moved.emit(id, n, true)
	refresh()
	_tip.show_over(Data.item_name(id), _box_slots[id])


func _take_all() -> void:
	for id: String in store.keys():
		inv.add(id, int(store[id]))
		moved.emit(id, int(store[id]), false)
	store.clear()
	refresh()
