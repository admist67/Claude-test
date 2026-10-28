class_name RaftActions
extends Node
## What the use button does with things on the raft: stations (the grill and the planter
## ask what goes in, a chest opens its storage), fish traps, the hammer taking things
## down, the bucket scooping seawater; tools wearing out with use until they break; and
## the gulls after the crops.
## Glue between the game and those systems.

var game: Node                     # main.gd
var picker: PickPanel
var storage: StoragePanel
var wear := Durability.new()
var gulls: Gulls
var _picking: Station
var _chest: Station


func setup(g: Node, layer: CanvasLayer) -> void:
	game = g
	picker = PickPanel.new()
	picker.visible = false
	layer.add_child(picker)
	picker.picked.connect(_on_picked)
	picker.closed.connect(_close_picker)
	storage = StoragePanel.new()
	storage.visible = false
	storage.inv = g.inv
	storage.condition = condition
	layer.add_child(storage)
	storage.closed.connect(_close_chest)
	storage.moved.connect(func(_id: String, _n: int, into: bool) -> void:
		if into:
			game.stats["stored"] = int(game.stats.get("stored", 0)) + 1
			game.check_goals()
	)
	gulls = Gulls.new()
	gulls.raft = g.raft
	g.add_child(gulls)
	gulls.coming.connect(func(_st: Station) -> void: game.hud.toast("Чайка летит к грядке! Прогони её копьём", "planter"))
	gulls.ate.connect(func(_st: Station) -> void: game.hud.toast("Чайка склевала урожай. Поставь рядом пугало", "scarecrow"))
	gulls.scared.connect(func() -> void:
		game.stats["gulls_scared"] = int(game.stats.get("gulls_scared", 0)) + 1
		game.hud.toast("Чайка улетела!", "spear")
		game.check_goals()
	)


## The use button on a station. An idle grill or planter opens the list to choose from.
func use_station(st: Station) -> void:
	if st.kind == "chest":
		_chest = st
		st.open_lid(true)
		open_chest(st.items, "Сундук", int(st.def.get("slots", 20)), false)
		return
	if st.wants_choice():
		if not st.prompt(game.inv)["ok"]:
			_finish(st, st.interact(game.inv), false)      # says what is missing
			return
		_picking = st
		game.open_modal()
		var titles := {"grill": "Что жарить?", "big_grill": "Что жарить? (до 3 сразу)", "planter": "Что посадить?", "rack": "Что сушить?"}
		picker.open(titles[st.kind], st.choices(game.inv))
		return
	var was_busy := st.busy()
	_finish(st, st.interact(game.inv), was_busy)


## A chest's storage over the game: `items` is the chest's own dictionary.
func open_chest(items: Dictionary, title: String, slots: int, take_only: bool) -> void:
	game.open_modal()
	Sfx.play("door", -6.0)
	storage.open(title, items, slots, take_only)


func _close_chest() -> void:
	storage.visible = false
	if is_instance_valid(_chest):
		_chest.open_lid(false)
	_chest = null
	game.close_modal()


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
	if st.kind == "sail" and st.stored == 1:
		stats["sail_up"] = int(stats.get("sail_up", 0)) + 1
		if game.trips.anchored():
			res = ["Парус поднят, но якорь держит плот на месте", ""]
	if st.kind == "planter" and not was_busy and st.busy():
		stats["planted"] = int(stats.get("planted", 0)) + 1
	if st.kind == "purifier" and not was_busy and st.busy():
		stats["poured"] = int(stats.get("poured", 0)) + 1
	game.player.swing()
	if got != "":
		stats["got_" + got] = int(stats.get("got_" + got, 0)) + 1
		if st.is_grill():
			stats["cooked"] = int(stats.get("cooked", 0)) + 1
		if st.kind == "planter":
			stats["harvest"] = int(stats.get("harvest", 0)) + 1
		Sfx.play("pop", -2.0)
		game.hud.toast(res[0], got)
	else:
		if not st.kind in ["anchor", "sail"]:          # those make their own sound
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


## The bucket in hand: scoop seawater over the raft's edge (or while swimming), pour it
## into the purifier, or back into the sea.
func use_bucket() -> void:
	var full: bool = game.hand == "bucket_water"
	var st: Station = game.station_target
	if full and st and st.kind == "purifier":
		use_station(st)
		return
	var at: Variant = _water_ahead()
	if at == null:
		Sfx.play("build_fail", -6.0)
		game.hud.toast("Залей воду в очиститель" if full else "Посмотри на воду у края плота", "bucket")
		return
	game.player.swing()
	game.on_splash(at)
	game.swap_item("bucket_water" if full else "bucket", "bucket" if full else "bucket_water")
	game.hud.toast("Вылито в море" if full else "Ведро морской воды — залей в очиститель", "bucket" if full else "bucket_water")


## Where the view meets open sea close by (not the deck, nothing in the way), or null.
func _water_ahead() -> Variant:
	var p: Player = game.player
	if p.swimming:
		return p.global_position + Vector3(0, 1.2, 0)
	var from := p.cam.global_position
	var fwd := -p.cam.global_basis.z
	if fwd.y > -0.15:
		return null
	var t := (Ocean.height_at(from.x, from.z) - from.y) / fwd.y
	if t > 4.5:
		return null
	var hit := from + fwd * t
	var q := PhysicsRayQueryParameters3D.create(from, hit, 1, [p.get_rid()])
	if not game.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		return null
	var raft: Raft = game.raft
	return null if raft.walkable(raft.to_local(hit)) else hit


## How worn a tool is, 1 = new; -1 for things that do not wear.
func condition(id: String) -> float:
	var full := int(Data.item(id).get("durability", 0))
	return wear.ratio(id, full) if full > 0 else -1.0
