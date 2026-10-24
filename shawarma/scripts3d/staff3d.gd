extends Node3D
## Hired staff and their simple job logic:
## - helper: lays lavash and the meat for the next uncovered order on the empty board;
## - waiter: carries finished rolls from the grill and drinks to customers;
## - cleaner: clears dirty café tables.

const WorkerS := preload("res://scripts3d/worker3d.gd")
const CafeS := preload("res://scripts3d/cafe3d.gd")
const CustomerS := preload("res://scripts3d/customer3d.gd")
const BoardS := preload("res://scripts3d/board3d.gd")
const K := "res://assets/models/characters/character-"
const HOME := {"helper": Vector3(-2.1, 0, 1.45), "waiter": Vector3(2.2, 0, -1.9), "cleaner": Vector3(4.8, 0, -1.7)}
const LOOK := {"helper": Vector3(-2.1, 0, 3.0), "waiter": Vector3(0, 0, -3.0), "cleaner": Vector3(0, 0, -3.0)}

var game: Node3D          # main3d.gd
var workers := {}         # role -> worker
var helper_wait := 0.0
var restocking := {}


func hire(roles: Array) -> void:
	restocking.clear()
	for r in workers.keys():
		if not roles.has(r):
			workers[r].queue_free()
			workers.erase(r)
	for r in roles:
		if workers.has(r):
			continue
		var w := WorkerS.new()
		add_child(w)
		match r:
			"helper":
				w.setup(r, "Помощник", K + "male-c.glb", Color("#e2493b"))
			"waiter":
				w.setup(r, "Официант", K + "female-d.glb", Color("#2b1d33"))
			"cleaner":
				w.setup(r, "Уборщица", K + "female-f.glb", Color("#3ccf7a"))
		workers[r] = w
		reset(r)


func reset(r: String) -> void:
	var w = workers[r]
	w.position = HOME[r]
	w.hold({})
	w.rotation.y = 0.0
	w._face_to(LOOK[r])


func reset_all() -> void:
	for r in workers:
		var w = workers[r]
		w.create_tween().kill()
		w.busy = false
		reset(r)


func roles() -> Array:
	return workers.keys()


func tick(delta: float) -> void:
	# A worker right in front of the camera would fill the screen: hide them up close.
	var eye: Vector3 = game.player.global_position
	for r in workers:
		var w = workers[r]
		w.visible = Vector2(w.position.x - eye.x, w.position.z - eye.z).length() > 0.95
	if workers.has("helper"):
		_helper(delta)
	if workers.has("waiter"):
		_waiter()
	if workers.has("cleaner"):
		_cleaner()


func _go_home(w) -> void:
	w.go(CafeS.route(w.position, HOME[w.role]), func(): w._face_to(LOOK[w.role]))


# --- Helper ------------------------------------------------------------------------

func _helper(delta: float) -> void:
	var w = workers["helper"]
	if w.busy:
		return
	var low: Array = game.bins.lowest()
	if not low.is_empty() and game.bins.frac(low[0]) < 0.3 and not restocking.has(low[0]):
		_restock(w, low[0])
		return
	if game.board.state != BoardS.S.EMPTY:
		helper_wait = 1.2
		return
	helper_wait -= delta
	if helper_wait > 0.0:
		return
	var c = game.next_uncovered()
	if c == null:
		return
	var done := func() -> void:
		if game.board.state == BoardS.S.EMPTY and is_instance_valid(c):
			game.board.put_lavash()
			for k in c.order.meat:
				if game.spit.can_cut():
					game.spit.cut()
					game.board.add_meat()
			Sfx.play("lavash", 0.05, -6.0)
		_go_home(w)
	w.go([Vector3(-1.4, 0, 1.45)], done, 1.0, Vector3(-1.4, 0, 3.0))


## Fetches a crate from the storage and refills bin `id`.
func _restock(w, id: String) -> void:
	restocking[id] = true
	var storage: Vector3 = game.bins.target("storage")
	var bin: Vector3 = game.bins.target(id)
	var put := func() -> void:
		w.drop()
		game.bins.refill(id)
		restocking.erase(id)
		Sfx.play("plop", 0.05, -6.0)
		_go_home(w)
	var grab := func() -> void:
		w.hold({"crate": true})
		w.go([Vector3(bin.x, 0, 1.45)], put, 0.5, bin)
	w.go([Vector3(storage.x, 0, 1.45)], grab, 0.5, storage)


# --- Waiter ------------------------------------------------------------------------

func _waiter() -> void:
	var w = workers["waiter"]
	if w.busy:
		return
	var grill = game.grill
	var from := Bal.f("grill_perfect_from") + 0.2
	for i in grill.unlocked:
		var s = grill.slots[i]
		if s == null or s["t"] < from:
			continue
		var c = game.customer_for(s["made"])
		if c == null:
			continue
		c.set_meta("waiter_roll", true)
		var stand := Vector3(2.05, 0, grill.slot_global(i).z)
		var slot: int = i
		var take := func() -> void:
			if grill.slots[slot] != null and is_instance_valid(c) and c.st == CustomerS.St.WAIT:
				w.hold(grill.take(slot))
				_deliver(w, c)
			else:
				if is_instance_valid(c):
					c.remove_meta("waiter_roll")
				_go_home(w)
		w.go(CafeS.route(w.position, stand), take, 0.4, grill.slot_global(i))
		return
	if game.cafe.enabled:
		for c in game.all_customers():
			if c.st == CustomerS.St.WAIT and c.order.drink and not c.got_drink and not c.has_meta("waiter_drink"):
				c.set_meta("waiter_drink", true)
				var stand := Vector3(2.05, 0, CafeS.COOLER.z)
				var guest = c
				var grab := func() -> void:
					w.hold({"drink": true})
					_deliver(w, guest)
				w.go(CafeS.route(w.position, stand), grab, 0.5, CafeS.COOLER)
				return


func _serve_spot(c) -> Vector3:
	if c.dine:
		return c.position + Vector3(0.55, 0, 0.35)
	return Vector3(clampf(c.position.x, -2.2, 1.1), 0, -0.3)


func _deliver(w, c) -> void:
	if not is_instance_valid(c) or c.st != CustomerS.St.WAIT:
		_discard(w)
		return
	var spot := _serve_spot(c)
	var hand_over := func() -> void:
		var item: Dictionary = w.drop()
		if is_instance_valid(c) and c.st == CustomerS.St.WAIT:
			c.remove_meta("waiter_roll")
			c.remove_meta("waiter_drink")
			game.give(c, item, true)
		_go_home(w)
	w.go(CafeS.route(w.position, spot), hand_over, 0.3, c.position)


func _discard(w) -> void:
	w.drop()
	_go_home(w)


# --- Cleaner -----------------------------------------------------------------------

func _cleaner() -> void:
	var w = workers["cleaner"]
	if w.busy or not game.cafe.enabled:
		return
	for i in game.cafe.dirty_tables():
		if game.cafe.tables[i].get("cleaning", false):
			continue
		game.cafe.tables[i]["cleaning"] = true
		var p: Vector3 = CafeS.TABLES[i] + Vector3(0.65, 0, 0.2)
		var t: int = i
		var wipe := func() -> void:
			game.cafe.tables[t]["cleaning"] = false
			if game.cafe.tables[t]["state"] == "dirty":
				game.cafe.set_state(t, "free")
				Sfx.play("plop", 0.1, -6.0)
			_go_home(w)
		w.go(CafeS.route(w.position, p), wipe, 1.6, CafeS.TABLES[i])
		return
