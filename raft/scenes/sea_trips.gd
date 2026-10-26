class_name SeaTrips
extends Node
## Trips off the raft: jumping into the sea at the raft's edge, climbing back on, the
## islands drifting by (held by the anchor), gathering on them, the shark biting swimmers,
## and the current bringing back anyone who swims too far. Glue between the game and the
## Islands system; the game asks it what the use button does off the raft.

var game: Node                     # main.gd
var islands: Islands
var jump_at: Variant = null        # global point in the sea to jump to, or null
var climb_at: Variant = null       # raft-local deck point to climb onto, or null
var _cfg: Dictionary


func setup(g: Node) -> void:
	game = g
	_cfg = Data.b["player"]
	islands = Islands.new()
	islands.raft = g.raft
	islands.player = g.player
	g.add_child(islands)
	islands.sighted.connect(_on_sighted)
	islands.pinched.connect(_on_pinched)
	islands.crab_died.connect(_on_crab_died)
	g.shark.bit_player.connect(_on_bitten)
	g.shark.attacked.connect(_on_shark_attack)
	g.shark.bit.connect(_on_shark_bite)
	g.shark.fled.connect(_on_shark_driven)


func anchored() -> bool:
	for st: Station in game.raft.stations.values():
		if st.kind == "anchor" and st.stored == 1:
			return true
	return false


## Every frame in play: what the use button could do here, and the sea's rules.
func update() -> void:
	var p: Player = game.player
	islands.anchored = anchored()
	var goals: Array = Data.goals
	islands.want_chest = game.goal_i < goals.size() and goals[game.goal_i]["stat"] == "chests"
	game.shark.swimmer = p if p.swimming else null
	jump_at = null
	climb_at = null
	if p.off_raft:
		climb_at = _climb_spot()
		_check_visit()
		_check_far()
	elif not game.tool_use() in ["hook", "rod"]:
		jump_at = _jump_spot()         # not while fishing at the edge: no slipping in


## The edge of the deck ahead, with open water past it (no wall in the way).
func _jump_spot() -> Variant:
	var p: Player = game.player
	var raft: Raft = game.raft
	if p.position.y > 0.6:
		return null
	var f := raft.global_basis.inverse() * p.flat_forward()
	f.y = 0.0
	f = f.normalized()
	if raft.walkable(p.position + f * 0.9) or not raft.walkable(p.position):
		return null
	var from := p.cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from + p.flat_forward() * 1.6 + Vector3(0, -0.6, 0), 1, [p.get_rid()])
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and hit["collider"] is Part:
		return null
	return raft.to_global(p.position + f * 1.7)


## Swimming next to the deck: the point on the nearest tile to climb onto.
func _climb_spot() -> Variant:
	var p: Player = game.player
	var raft: Raft = game.raft
	if not p.swimming:
		return null
	var local := raft.to_local(p.global_position)
	var h := raft.tile_size / 2.0
	var best: Variant = null
	var bd := 1.3
	for c: Vector2i in raft.edge_cells():
		var cc := raft.cell_center(c)
		var off := Vector2(clampf(local.x - cc.x, -h, h), clampf(local.z - cc.z, -h, h))
		var d := Vector2(local.x - cc.x, local.z - cc.z).distance_to(off)
		if d < bd:
			bd = d
			var inside := Vector2(clampf(off.x, -h + 0.4, h - 0.4), clampf(off.y, -h + 0.4, h - 0.4))
			best = cc + Vector3(inside.x, 0.05, inside.y)
	return best


## The use button off the raft (or at its edge). Returns true when it did something.
func use() -> bool:
	var p: Player = game.player
	if climb_at != null:
		p.place(climb_at, p.yaw)
		Sfx.play("splash", -8.0)
		game.hud.toast("Ты на плоту", "tile")
		return true
	if jump_at != null:
		p.jump_in(jump_at)
		game.on_splash(jump_at)
		if not game.stats.has("swim_hint"):
			game.stats["swim_hint"] = 1
			game.hud.toast("Назад — подплыви к краю плота и нажми «Забраться»", "tile")
		return true
	return false


func view() -> Dictionary:
	if climb_at != null:
		return {"icon": "tile", "label": "Забраться", "ok": true}
	if jump_at != null:
		return {"icon": "drop", "label": "Прыгнуть в воду", "ok": true}
	return {}


func gather(spot: IslandSpot) -> void:
	if spot.kind == "chest":
		if spot.left > 0:
			spot.open_chest()
			game.stats["chests"] = int(game.stats.get("chests", 0)) + 1
			game.check_goals()
		game.actions.open_chest(spot.items, "Сундук на острове", 99, true)
		return
	if spot.kind == "rock":
		if game.tool_use() == "pickaxe":
			mine(spot)
		else:
			Sfx.play("build_fail", -6.0)
			game.hud.toast("Камень копают киркой — сделай её в сумке", "pickaxe")
		return
	var loot := spot.take()
	if loot.is_empty():
		Sfx.play("build_fail", -6.0)
		return
	game.player.swing()
	Sfx.play("pop", -2.0)
	for id: String in loot:
		var n := int(loot[id])
		game.inv.add(id, n)
		game.stats["got_" + id] = int(game.stats.get("got_" + id, 0)) + n
		game.hud.toast("+%d %s" % [n, Data.item_name(id)], id)
	game.check_goals()


## A pickaxe blow on the rock in front: every few blows a chunk of stone comes off.
func mine(spot: IslandSpot) -> void:
	if spot == null or spot.kind != "rock" or spot.left <= 0:
		game.hud.toast("Наведись на камень", "pickaxe")
		return
	game.player.swing()
	Sfx.play("hammer", -3.0, 0.25)
	Fx.burst(game, spot.global_position + Vector3(0, 0.5, 0), Color("#8a8a86"), 8)
	game.actions.use_tool(game.hand)
	var loot := spot.dig()
	for id: String in loot:
		var n := int(loot[id])
		game.inv.add(id, n)
		game.stats["got_" + id] = int(game.stats.get("got_" + id, 0)) + n
		game.stats["mined"] = int(game.stats.get("mined", 0)) + n
		game.hud.toast("+%d %s" % [n, Data.item_name(id)], id)
	if not loot.is_empty():
		Sfx.play("pop", -2.0)
		game.check_goals()


## The anchor went down: counts when an island is near.
func on_anchor(st: Station) -> void:
	if st.stored == 1 and islands.near():
		game.stats["anchored_island"] = int(game.stats.get("anchored_island", 0)) + 1
		game.check_goals()


func _on_sighted(_isl: Island) -> void:
	game.stats["islands_seen"] = int(game.stats.get("islands_seen", 0)) + 1
	Sfx.play("goal", -8.0)
	var tip := "" if anchored() else " Брось якорь, когда он будет рядом"
	game.hud.toast("Впереди остров!" + tip, "anchor")
	game.check_goals()


## Standing on an island's ground for the first time.
func _check_visit() -> void:
	var p: Player = game.player
	var isl := islands.island
	if isl == null or isl.visited or p.swimming or not p.is_on_floor():
		return
	var flat := Vector2(p.global_position.x - isl.position.x, p.global_position.z - isl.position.z)
	if flat.length() < isl.radius * 0.95:
		isl.visited = true
		game.stats["island_visits"] = int(game.stats.get("island_visits", 0)) + 1
		game.hud.toast("Ты на острове!", "anchor")
		Sfx.play("goal", -4.0)
		game.check_goals()


## Too far from the raft: the current carries you back to its edge.
func _check_far() -> void:
	var p: Player = game.player
	var c: Vector3 = game.raft.global_transform * game.raft.centroid()
	if Vector2(p.global_position.x - c.x, p.global_position.z - c.z).length() > float(_cfg["max_swim"]) or p.global_position.y < -20.0:
		p.place(game.raft.nearest_tile(game.raft.to_local(p.global_position)), p.yaw)
		game.hud.toast("Течение принесло тебя обратно к плоту", "tile")


func _on_pinched() -> void:
	Sfx.play("bite", -6.0, 0.3)
	Input.vibrate_handheld(60)
	if not game.stats.has("crab_hint"):
		game.stats["crab_hint"] = 1
		game.hud.toast("Краб щиплется! Отбейся копьём", "spear")
	if game.vitals.damage(float(Data.b["islands"]["crabs"]["pinch"]), "crab"):
		game.die()


func _on_crab_died() -> void:
	var stats: Dictionary = game.stats
	stats["crabs"] = int(stats.get("crabs", 0)) + 1
	Sfx.play("goal", -6.0)
	for id: String in Data.b["islands"]["crabs"]["loot"]:
		var n := int(Data.b["islands"]["crabs"]["loot"][id])
		game.inv.add(id, n)
		stats["got_" + id] = int(stats.get("got_" + id, 0)) + n
		game.hud.toast("Краб повержен! +%d %s" % [n, Data.item_name(id)], id)
	game.check_goals()


func _on_shark_attack(_cell: Vector2i) -> void:
	Sfx.play("warning", -2.0)
	game.hud.toast("Акула грызёт плот!", "spear")
	if game.inv.count("spear") == 0 and not game.stats.has("spear_hint"):
		game.stats["spear_hint"] = 1
		game.hud.toast("Сделай копьё в сумке, чтобы отбиться", "spear")


func _on_shark_bite(cell: Vector2i, sank: bool) -> void:
	Sfx.play("bite")
	var p: Vector3 = game.raft.to_global(game.raft.cell_center(cell))
	Fx.burst(game, p, Color("#8a6a48"), 14)
	game.on_splash(p)
	Input.vibrate_handheld(120)
	if sank:
		game.hud.toast("Акула утащила клетку плота!", "tile")
		if not game.player.off_raft and not game.raft.on_raft(game.player.position):
			game.player.place(game.raft.nearest_tile(game.player.position), game.player.yaw)
	else:
		game.hud.toast("Чини молотком: 1 доска", "hammer")


## Enough spear hits: the shark swims off, leaving a torn-off piece behind.
func _on_shark_driven() -> void:
	var stats: Dictionary = game.stats
	stats["shark_driven"] = int(stats.get("shark_driven", 0)) + 1
	game.hud.toast("Акула уплыла зализывать раны", "spear")
	for id: String in Data.b["shark"]["reward"]:
		var n := int(Data.b["shark"]["reward"][id])
		game.inv.add(id, n)
		game.hud.toast("+%d %s" % [n, Data.item_name(id)], id)
	Sfx.play("goal", -4.0)
	game.check_goals()


func _on_bitten() -> void:
	var p: Player = game.player
	Sfx.play("bite")
	Input.vibrate_handheld(160)
	Fx.burst(game, p.global_position + Vector3(0, 1.0, 0), Color("#b8231d"), 16)
	game.hud.toast("Акула кусает! Забирайся на плот", "spear")
	if game.vitals.damage(float(Data.b["shark"]["player_bite"]), "shark"):
		game.die()


## Distance from the player to the raft's center, for the HUD marker.
func raft_dist() -> float:
	var c: Vector3 = game.raft.global_transform * game.raft.centroid()
	return Vector2(game.player.global_position.x - c.x, game.player.global_position.z - c.z).length()


func to_dict() -> Dictionary:
	return islands.to_dict()


func from_dict(d: Dictionary) -> void:
	islands.from_dict(d)
