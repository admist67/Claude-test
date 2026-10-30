class_name PetCare
extends Node
## The pet parrot. A wild one waits on some islands, sitting on a driftwood perch: feed it
## fruit three times and it trusts you, takes a name and flies over to the raft. There it
## lives: sits on rails, walls, tables, crates and its own perch, hops about the deck and
## talks. It gets hungry: feed it from your hand (fruit, seeds, salad) or fill the bowl on
## its perch and it eats by itself. Well fed it helps: flies out over the sea and brings
## back finds, screams and hovers where the shark bites, chases gulls off the crops, calls
## out land. Hungry, it sulks and asks for food. At night it sleeps, on its perch if there
## is one. Glue between the game and the Parrot. Numbers in data/balance.json "pet".

const PHRASES := ["%s хороший!", "Полундра!", "Свистать всех наверх!", "Пиастры! Пиастры!", "Привет!", "Плот — наш дом!", "%s молодец!",
		"Хочу на остров!", "Море! Море!", "Кар-рамба!"]
const TOPS := {"table": 0.8, "keg": 0.74, "crate": 0.64, "stool": 0.48, "bench": 0.5, "flower_box": 0.3, "deck_chair": 0.62}

var game: Node                     # main.gd
var cfg: Dictionary
var pet: Parrot
var tamed := false
var pet_name := "Кеша"
var satiety := 70.0
var target: Parrot                 # the pet, while the crosshair is on it
var _task := ""                    # "", "fetch", "back", "guard", "gull", "bowl", "sleep"
var _task_t := 0.0
var _fetch_t := 120.0
var _move_t := 3.0
var _talk_t := 40.0
var _gift := ""
var _rng := RandomNumberGenerator.new()


func setup(g: Node) -> void:
	game = g
	cfg = Data.b["pet"]
	_rng.randomize()
	g.trips.islands.sighted.connect(func(_i: Island) -> void:
		if pet and _task != "sleep":
			pet.squawk()
			say("Земля! Земля!")
	)
	g.shark.attacked.connect(_on_shark)
	g.actions.gulls.coming.connect(func(_st: Station) -> void:
		if _helps() and _task == "":
			_task = "gull"
			_task_t = 30.0
	)


## A new world: no parrot yet.
func reset() -> void:
	if pet:
		pet.queue_free()
	pet = null
	tamed = false
	pet_name = "Кеша"
	satiety = 70.0
	_task = ""


func to_dict() -> Dictionary:
	return {"tamed": tamed, "name": pet_name, "satiety": satiety}


func from_dict(d: Dictionary) -> void:
	reset()
	tamed = bool(d.get("tamed", false))
	pet_name = String(d.get("name", "Кеша"))
	satiety = float(d.get("satiety", 70.0))
	if tamed:
		pet = Parrot.new()
		game.raft.add_child(pet)
		pet.make_usable()
		pet.position = _spot()


## Well fed and awake: it helps.
func _helps() -> bool:
	return pet != null and satiety >= float(cfg["hungry"]) and _task != "sleep"


## A phrase over the parrot's head.
func say(text: String) -> void:
	if pet:
		game.hud.say(text, pet)


# ---------------------------------------------------------------- taming

## The first food in the bag the parrot likes, cheapest first; "" if none.
func food_in_bag() -> String:
	var foods: Dictionary = cfg["foods"]
	var best := ""
	for id: String in foods:
		if game.inv.count(id) > 0 and (best == "" or int(foods[id]) < int(foods[best])):
			best = id
	return best


## The use button on the wild parrot on an island.
func tame(spot: IslandSpot) -> void:
	var wild := spot.fruit as Parrot
	if tamed or spot.left <= 0 or wild == null:
		return
	var food := food_in_bag()
	if food == "":
		game.hud.toast("Попугаи любят бананы, ананасы, кокосы и семена", "banana")
		Sfx.play("build_fail", -6.0)
		return
	game.inv.remove(food)
	spot.left -= 1
	game.stats["parrot_fed"] = int(game.stats.get("parrot_fed", 0)) + 1
	wild.face_to((wild.get_parent() as Node3D).to_local(game.player.global_position))
	wild.eat()
	Fx.burst(game, wild.global_position + Vector3(0, 0.5, 0), Color("#ff6f8a"), 8)
	game.player.swing()
	if spot.left > 0:
		game.hud.toast("Попугай доверяет тебе всё больше (%d/%d)" % [int(spot.def["charges"]) - spot.left, int(spot.def["charges"])], "parrot")
		game.check_goals()
		return
	# Tamed: it flies over to the raft and takes a name.
	spot.fruit = null
	tamed = true
	satiety = 80.0
	pet = wild
	pet.reparent(game.raft)
	pet.make_usable()
	pet.squawk()
	pet.fly_to(_spot(), 2.0)
	game.stats["parrot_tamed"] = 1
	game.check_goals()
	game.open_modal()
	var done := func(n: String) -> void:
		pet_name = n
		game.menus.hide_all()
		game.close_modal()
		game.hud.toast("%s теперь живёт на плоту!" % pet_name, "parrot")
		say("%s хороший!" % pet_name)
	game.menus.ask_name("Как назовёшь попугая?", pet_name, "Готово", done, func() -> void: done.call(pet_name))


# ---------------------------------------------------------------- on the raft

## The view points right at the pet, close by (a ray easily slips past a small bird on a
## wall top).
func looked_at(from: Vector3, fwd: Vector3) -> bool:
	if pet == null:
		return false
	var to := pet.global_position + Vector3(0, 0.3, 0) - from
	return to.length() < 3.4 and to.normalized().dot(fwd) > 0.975


## What the use button does on the pet.
func view() -> Dictionary:
	var food := food_in_bag()
	if food != "" and satiety < 90.0:
		return {"icon": food, "label": "Покормить: %s" % Data.item_name(food), "ok": true}
	return {"icon": "parrot", "label": "Погладить (%s)" % ("голоден" if satiety < float(cfg["hungry"]) else "сыт"), "ok": true}


func use() -> void:
	if pet == null:
		return
	pet.face_to(game.raft.to_local(game.player.global_position))
	var food := food_in_bag()
	if food != "" and satiety < 90.0:
		game.inv.remove(food)
		satiety = minf(100.0, satiety + float(cfg["foods"][food]))
		pet.eat()
		game.stats["parrot_fed"] = int(game.stats.get("parrot_fed", 0)) + 1
		say(["Ням!", "Вкусно!", "%s сыт!" % pet_name, "Спасибо!"][_rng.randi() % 4])
	else:
		pet.dance()
		Sfx.play("pop", -4.0, 0.2)
		say(_phrase())
	Fx.burst(game, pet.global_position + Vector3(0, 0.5, 0), Color("#ff6f8a"), 8)
	game.player.swing()
	game.check_goals()


## The use button on the perch: a fruit into its bowl.
func fill_bowl(perch: Part) -> void:
	var cap := int(cfg["bowl"])
	if perch.fish >= cap:
		game.hud.toast("Миска полна", "perch")
		return
	var food := food_in_bag()
	if food == "":
		game.hud.toast("Нужны фрукты или семена", "banana")
		Sfx.play("build_fail", -6.0)
		return
	game.inv.remove(food)
	perch.fish += 1
	game.stats["bowl_filled"] = int(game.stats.get("bowl_filled", 0)) + 1
	Sfx.play("craft", -6.0)
	game.hud.toast("В миске корма: %d/%d" % [perch.fish, cap], food)
	game.check_goals()


func _phrase() -> String:
	var p: String = PHRASES[_rng.randi() % PHRASES.size()]
	return p % pet_name if "%s" in p else p


func _process(delta: float) -> void:
	if pet == null or not game.trips.islands.active:
		return
	var sleeping := _task == "sleep"
	satiety = maxf(0.0, satiety - float(cfg["hunger_per_min"]) / 60.0 * delta * (0.4 if sleeping else 1.0))
	pet.hungry = satiety < float(cfg["hungry"])
	if game.daynight.is_night():
		if not sleeping and pet.mode != Parrot.Mode.FLY:
			_go_sleep()
		return
	if sleeping:
		_task = ""
		pet.sleep(false)
		pet.squawk()
		say("Доброе утро!")
	_talk(delta)
	match _task:
		"fetch", "back":
			_fetching(delta)
		"guard":
			_task_t -= delta
			if _task_t <= 0.0 or not game.shark.attacking():
				_task = ""
				pet.fly_to(_spot(), 1.0)
		"gull":
			_chasing(delta)
		"bowl":
			_task_t -= delta
			if _task_t <= 0.0:
				_task = ""
		_:
			_idle(delta)


## Every now and then: a new place to sit, a trip over the sea, the bowl. While you look
## at it, it stays where it is and looks back.
func _idle(delta: float) -> void:
	if pet.mode == Parrot.Mode.FLY:
		return
	var perch := _perch()
	if perch and perch.fish > 0 and satiety < float(cfg["bowl_at"]):
		_task = "bowl"
		_task_t = 6.0
		pet.fly_to(_bowl_spot(perch), 0.8)
		pet.arrived.connect(func() -> void:
			if is_instance_valid(perch) and perch.fish > 0:
				perch.fish -= 1
				satiety = minf(100.0, satiety + float(cfg["portion"]))
				pet.eat()
				say("Ням-ням!")
		, CONNECT_ONE_SHOT)
		return
	if _helps():
		_fetch_t -= delta
		if _fetch_t <= 0.0:
			_fetch_t = _rng.randf_range(float(cfg["fetch"][0]), float(cfg["fetch"][1]))
			_task = "fetch"
			_task_t = float(cfg["away"])
			var a := _rng.randf() * TAU
			pet.fly_to(game.raft.centroid() + Vector3(cos(a) * 24.0, 6.0, sin(a) * 24.0), 3.0)
			say("Полетел за добычей!")
			return
	if target == pet:
		_move_t = maxf(_move_t, 4.0)
		pet.face_to(game.raft.to_local(game.player.global_position))
		return
	_move_t -= delta
	if _move_t <= 0.0:
		_move_t = _rng.randf_range(float(cfg["move"][0]), float(cfg["move"][1]))
		var to := _spot()
		if to.distance_to(pet.position) < 2.0 and absf(to.y - pet.position.y) < 0.2:
			pet.hop_to(to)
		else:
			pet.fly_to(to, 0.8)


## Out over the sea, a few seconds away, back with a find to drop at the player's feet.
func _fetching(delta: float) -> void:
	if pet.mode == Parrot.Mode.FLY:
		return
	if _task == "fetch":
		_task_t -= delta
		if _task_t > 0.0:
			return
		_gift = _roll_gift()
		pet.carry(_gift)
		_task = "back"
		var feet: Vector3 = game.raft.to_local(game.player.global_position)
		var at := Vector3(feet.x + _rng.randf_range(-0.6, 0.6), feet.y, feet.z + _rng.randf_range(-0.6, 0.6))
		pet.fly_to(at if game.raft.walkable(at) else _spot(), 3.0)
		return
	# Landed with the find.
	pet.drop()
	game.inv.add(_gift)
	game.stats["parrot_gifts"] = int(game.stats.get("parrot_gifts", 0)) + 1
	game.stats["got_" + _gift] = int(game.stats.get("got_" + _gift, 0)) + 1
	game.hud.toast("%s принёс: %s" % [pet_name, Data.item_name(_gift)], _gift)
	say("Подарок!")
	pet.dance()
	_task = ""
	_move_t = 4.0
	game.check_goals()


func _roll_gift() -> String:
	var table: Array = cfg["gifts"]
	var total := 0.0
	for e: Array in table:
		total += float(e[1])
	var r := _rng.randf() * total
	for e: Array in table:
		r -= float(e[1])
		if r <= 0.0:
			return e[0]
	return table[0][0]


func _on_shark(cell: Vector2i) -> void:
	if not _helps() or _task in ["fetch", "back"]:
		return
	_task = "guard"
	_task_t = 8.0
	pet.hover(game.raft.cell_center(cell) + Vector3(0, 2.4, 0))
	pet.squawk()
	say("Акула! Акула!")


## After a gull coming for the crops: once it is near the raft, fly at it until it gives up.
func _chasing(delta: float) -> void:
	_task_t -= delta
	var g: Gull = game.actions.gulls.gull
	if _task_t <= 0.0 or g == null or g.state == Gull.State.FLEE:
		_task = ""
		pet.fly_to(_spot(), 1.0)
		return
	var at: Vector3 = game.raft.to_local(g.global_position)
	if at.distance_to(game.raft.centroid()) > 16.0:
		return
	if pet.position.distance_to(at) < 1.4:
		g.flee()
		pet.squawk()
		say("Кыш! Кыш!")
		game.stats["parrot_gulls"] = int(game.stats.get("parrot_gulls", 0)) + 1
		game.stats["gulls_scared"] = int(game.stats.get("gulls_scared", 0)) + 1
		game.hud.toast("%s прогнал чайку!" % pet_name, "parrot")
		game.check_goals()
	elif pet.mode != Parrot.Mode.FLY:
		pet.fly_to(at + Vector3(0, 0.3, 0), 0.6)


func _go_sleep() -> void:
	_task = "sleep"
	pet.drop()
	var perch := _perch()
	pet.fly_to(_perch_spot(perch) if perch else pet.position, 0.8)
	pet.arrived.connect(func() -> void:
		if _task == "sleep":
			pet.sleep(true)
	, CONNECT_ONE_SHOT)


func _talk(delta: float) -> void:
	_talk_t -= delta
	if _talk_t > 0.0:
		return
	_talk_t = _rng.randf_range(float(cfg["talk"][0]), float(cfg["talk"][1]))
	if pet.hungry:
		pet.squawk()
		say(["Хочу есть!", "%s голодный!" % pet_name, "Банан! Банан!"][_rng.randi() % 3])
		game.hud.toast("%s проголодался — покорми его" % pet_name, "parrot")
	elif _rng.randf() < 0.6:
		say(_phrase())


# ---------------------------------------------------------------- places

func _perch() -> Part:
	var ps: Array = game.raft.parts.free_of("perch")
	return ps[0] if not ps.is_empty() else null


func _perch_spot(perch: Part) -> Vector3:
	return perch.position + Basis(Vector3.UP, perch.rotation.y) * Vector3(0.12, FixtureLooks.PERCH_BAR + 0.005, 0)


func _bowl_spot(perch: Part) -> Vector3:
	return perch.position + Basis(Vector3.UP, perch.rotation.y) * (FixtureLooks.BOWL + Vector3(0.11, -0.03, 0))


## Somewhere to sit, raft-local: the perch, the top of a rail or a wall, a table, a crate,
## or a free bit of deck (near the player now and then).
func _spot() -> Vector3:
	var parts: RaftParts = game.raft.parts
	var out: Array[Vector3] = []
	var perch := _perch()
	if perch:
		out.append(_perch_spot(perch))
		out.append(_perch_spot(perch))
	for k: Vector4i in parts.edges:
		var p: Part = parts.edges[k]
		var h := 1.05 if p.kind in ["railing", "half_wall"] else (RaftParts.H + 0.02 if p.kind in RaftParts.WALLS else -1.0)
		if h > 0.0:
			var along := Basis(Vector3.UP, RaftParts.edge_yaw(k)) * Vector3(_rng.randf_range(-0.5, 0.5), 0, 0)
			out.append(parts.edge_center(k) + along + Vector3(0, h, 0))
	for p: Part in parts.free.values():
		if TOPS.has(p.kind):
			out.append(p.position + Vector3(0, float(TOPS[p.kind]), 0))
	var tiles: Array = game.raft.tiles.keys()
	for i in 3:
		var c: Vector2i = tiles[_rng.randi() % tiles.size()]
		if not parts.cell_busy(Vector3i(c.x, c.y, 0)):
			out.append(game.raft.cell_center(c) + Vector3(_rng.randf_range(-0.45, 0.45), 0.0, _rng.randf_range(-0.45, 0.45)))
	var me: Vector3 = game.raft.to_local(game.player.global_position)
	var near := Vector3(me.x + _rng.randf_range(-0.9, 0.9), 0.0, me.z + _rng.randf_range(-0.9, 0.9))
	if game.raft.walkable(near) and _rng.randf() < 0.35:
		return near
	return out[_rng.randi() % out.size()] if not out.is_empty() else game.raft.centroid()
