class_name RaftActions
extends Node
## What the use button does with things on the raft: stations (the grill and the planter
## ask what goes in), fish traps, the hammer taking things down; and tools wearing out
## with use until they break. Glue between the game and those systems.

var game: Node                     # main.gd
var picker: PickPanel
var wear := Durability.new()
var _picking: Station


func setup(g: Node, layer: CanvasLayer) -> void:
	game = g
	picker = PickPanel.new()
	picker.visible = false
	layer.add_child(picker)
	picker.picked.connect(_on_picked)
	picker.closed.connect(_close_picker)


## The use button on a station. An idle grill or planter opens the list to choose from.
func use_station(st: Station) -> void:
	if st.wants_choice():
		if not st.prompt(game.inv)["ok"]:
			_finish(st, st.interact(game.inv), false)      # says what is missing
			return
		_picking = st
		game.open_modal()
		picker.open("Что жарить?" if st.kind == "grill" else "Что посадить?", st.choices(game.inv))
		return
	var was_busy := st.busy()
	_finish(st, st.interact(game.inv), was_busy)


func _on_picked(id: String) -> void:
	var st := _picking
	_close_picker()
	if is_instance_valid(st):
		_finish(st, st.start(game.inv, id), false)


func _close_picker() -> void:
	picker.visible = false
	_picking = null
	game.close_modal()


## Stats, sounds and toasts after a station did something: res = [message, item taken].
func _finish(st: Station, res: Array, was_busy: bool) -> void:
	var stats: Dictionary = game.stats
	var got: String = res[1]
	if st.kind == "anchor":
		game.trips.on_anchor(st)
	if st.kind == "planter" and not was_busy and st.busy():
		stats["planted"] = int(stats.get("planted", 0)) + 1
	game.player.swing()
	if got != "":
		stats["got_" + got] = int(stats.get("got_" + got, 0)) + 1
		if st.kind == "grill":
			stats["cooked"] = int(stats.get("cooked", 0)) + 1
		if st.kind == "planter":
			stats["harvest"] = int(stats.get("harvest", 0)) + 1
		Sfx.play("pop", -2.0)
		game.hud.toast(res[0], got)
	else:
		Sfx.play("craft" if st.busy() else "build_fail", -6.0)
		game.hud.toast(res[0], st.kind)
	game.check_goals()


## Fish from a trap: raw fish, now and then a big one.
func empty_trap(trap: Part) -> void:
	if trap.fish <= 0:
		game.hud.toast("В ловушке пока пусто", "fish")
		return
	var stats: Dictionary = game.stats
	for id: String in trap.take_fish():
		game.inv.add(id)
		stats["got_" + id] = int(stats.get("got_" + id, 0)) + 1
		stats["trap_fish"] = int(stats.get("trap_fish", 0)) + 1
		game.hud.toast("+1 " + Data.item_name(id), id)
	game.player.swing()
	Sfx.play("pop", -2.0)
	game.check_goals()


## The hammer takes a part or station down and gives back half of what it cost.
func demolish(target: Node3D) -> void:
	var raft: Raft = game.raft
	var kind: String = target.kind
	var cost: Dictionary = Data.build_by_id[kind]["cost"]
	var share := float(Data.b["raft"]["refund"])
	for id: String in cost:
		var n := int(floor(int(cost[id]) * share))
		if n > 0:
			game.inv.add(id, n)
	if target is Station:
		var st: Station = target
		if st.ready_item != "":
			game.inv.add(st.ready_item, int(st.def.get("count", 1)))
		raft.stations.erase(st.cell)
		st.queue_free()
		raft.parts.prune()
	else:
		raft.parts.remove_part(target)
	game.player.swing()
	Sfx.play("hammer", -2.0, 0.2)
	game.hud.toast("Разобрано: " + Data.build_by_id[kind]["name"], kind)


## A tool used `n` times wears out; at zero it breaks and is gone (make a new one in the
## bag). A warning comes when a fifth of it is left.
func use_tool(id: String, n := 1) -> void:
	var full := int(Data.item(id).get("durability", 0))
	if full <= 0 or game.inv.count(id) == 0:
		return
	var before := wear.uses_left(id, full)
	if wear.use(id, n, full):
		game.inv.remove(id)
		Sfx.play("snag", -2.0)
		game.hud.toast("Сломалось: %s. Сделай новое в сумке" % Data.item_name(id), id)
		return
	var warn := int(ceil(full * 0.2))
	if before > warn and wear.uses_left(id, full) <= warn:
		game.hud.toast("%s скоро сломается" % Data.item_name(id), id)


## How worn a tool is, 1 = new; -1 for things that do not wear.
func condition(id: String) -> float:
	var full := int(Data.item(id).get("durability", 0))
	return wear.ratio(id, full) if full > 0 else -1.0
