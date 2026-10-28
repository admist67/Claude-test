class_name Combat
extends Node
## The spear and the crossbow against the shark, gulls and crabs. The spear stabs at arm's
## length. The crossbow shoots a bolt far and straight; then the action button reloads it
## with the next bolt from the bag. Glue between the game and those creatures.
## Numbers in data/balance.json "crossbow", "shark" ("metal_spear").

var game: Node                     # main.gd
var loaded := false                # a bolt sits on the crossbow
var reloading := 0.0               # seconds left of a reload
var spear_cd := 0.0
var _cfg: Dictionary


func setup(g: Node) -> void:
	game = g
	_cfg = Data.b["crossbow"]


func tick(delta: float) -> void:
	spear_cd = maxf(0.0, spear_cd - delta)
	if reloading > 0.0:
		reloading -= delta
		if reloading <= 0.0:
			reloading = 0.0
			loaded = true
			Sfx.play("snag", -6.0, 0.1)
	game.player.show_bolt(loaded)


## A creature to fight is near (the spear button lights up).
func foe_near() -> bool:
	var p: Vector3 = game.player.global_position
	return game.shark.alive_near() or game.trips.islands.crab_near(p, 4.0) or game.actions.gulls.near(p, 4.5)


func stab() -> void:
	if spear_cd > 0.0:
		return
	spear_cd = float(Data.b["player"]["spear_cooldown"])
	game.player.swing()
	var metal: bool = game.selected() == "metal_spear"
	var ms: Dictionary = Data.b["shark"]["metal_spear"]
	var power := int(ms["power"]) if metal else 1
	var extra := float(ms["reach"]) if metal else 0.0
	var eye: Vector3 = game.player.cam.global_position
	var fwd: Vector3 = -game.player.cam.global_basis.z
	if _hit(eye, fwd, power, extra, 0.6) == Vector3.INF:
		Sfx.play("throw", -6.0, 0.2)
	else:
		game.actions.use_tool(game.selected())


## Shoots when loaded, otherwise starts reloading.
func crossbow() -> void:
	if reloading > 0.0:
		return
	if loaded:
		_shoot()
	elif game.inv.count("bolt") == 0:
		game.hud.toast("Нет стрел — сделай их в сумке", "bolt")
		Sfx.play("build_fail", -6.0)
	else:
		game.inv.remove("bolt")
		reloading = float(_cfg["reload"])
		game.player.reload_motion(reloading)
		Sfx.play("reel", -4.0)


func _shoot() -> void:
	loaded = false
	game.player.show_bolt(false)
	game.player.swing()
	Sfx.play("throw", -2.0, 0.1)
	var eye: Vector3 = game.player.cam.global_position
	var fwd: Vector3 = -game.player.cam.global_basis.z
	var reach := float(_cfg["range"])
	var at := _hit(eye, fwd, int(_cfg["power"]), reach, float(_cfg["cone"]))
	if at == Vector3.INF:
		at = eye + fwd * reach
		if fwd.y < -0.02:
			at = eye + fwd * minf(reach, (eye.y - Ocean.height_at(eye.x, eye.z)) / -fwd.y)
	_fly(game.player.held_point(Vector3(0, 0.02, -0.35)), at)
	game.actions.use_tool("crossbow")


## Strikes whatever is in front: the shark, a crab, a gull. Returns where it hit, or INF.
## The spear's own reach comes from the creature; the crossbow passes its range.
func _hit(eye: Vector3, fwd: Vector3, power: int, reach: float, cone: float) -> Vector3:
	var far := cone > 0.8
	var shark: Shark = game.shark
	var shark_extra := reach - float(Data.b["shark"]["hit_reach"]) - 1.0 if far else reach
	if shark.try_hit(eye, fwd, power, shark_extra, cone):
		if far:
			game.stats["bolt_hits"] = int(game.stats.get("bolt_hits", 0)) + 1
			game.check_goals()
		if shark.hits_left() > 0:
			game.hud.toast("Попал!", "crossbow" if far else "spear")
		return shark.global_position
	var crab: Crab = game.trips.islands.hit_crab(eye, fwd, power, reach if far else float(Data.b["player"]["crab_reach"]) + reach, cone)
	if crab:
		Sfx.play("shark_hit", -4.0)
		Fx.burst(game, crab.global_position + Vector3(0, 0.3, 0), Color("#d4572f"), 10)
		return crab.global_position
	var gulls: Gulls = game.actions.gulls
	var gull_at := gulls.gull.global_position if gulls.gull else Vector3.ZERO
	if gulls.hit(eye, fwd, reach - float(gulls.cfg["reach"]) if far else reach, cone):
		return gull_at
	return Vector3.INF


## A bolt flying from `from` to `to`, then sticking in the water or fading.
func _fly(from: Vector3, to: Vector3) -> void:
	var bolt := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = Looks.mesh("bolt")
	mi.rotation.x = -PI / 2.0
	bolt.add_child(mi)
	game.add_child(bolt)
	bolt.global_position = from
	if from.distance_to(to) > 0.05:
		bolt.look_at(to)
	var t := from.distance_to(to) / float(_cfg["speed"])
	var tw := bolt.create_tween()
	tw.tween_property(bolt, "global_position", to, t)
	tw.tween_callback(func() -> void:
		if to.y < 0.3:
			Fx.burst(game, to, Color(0.85, 0.93, 1.0), 6)
	)
	tw.tween_interval(0.4)
	tw.tween_callback(bolt.queue_free)


## The action button with a spear or a crossbow in hand.
func view(id: String) -> Dictionary:
	if id == "crossbow":
		if reloading > 0.0:
			return {"icon": "bolt", "label": "Заряжаю…", "ok": false, "cooldown": reloading / float(_cfg["reload"])}
		if loaded:
			return {"icon": id, "label": "Выстрел", "ok": true}
		var n: int = game.inv.count("bolt")
		return {"icon": "bolt", "label": "Перезарядить (%d)" % n if n > 0 else "Нет стрел", "ok": n > 0}
	var cd := float(Data.b["player"]["spear_cooldown"])
	return {"icon": id, "label": "Ударить", "ok": foe_near() and spear_cd <= 0.0, "cooldown": spear_cd / cd}
