class_name Shark
extends Node3D
## The shark. Circles the raft with its fin above water; every so often picks an edge tile,
## swims to it and bites until the tile sinks or a spear drives it off. It cannot be
## killed: each visit it takes 3–6 spear hits (rolled anew) before it swims away.
## Anyone swimming is easier prey: it comes sooner and goes for them instead of the raft.
## It does not come at all before the player has made a first spear (`enabled`).
## An island nearby (`avoid`) is swum around, never through, and it bites only from open water.
## Numbers in data/balance.json "shark".

signal attacked(cell: Vector2i)
signal bit(cell: Vector2i, sank: bool)
signal hurt(left: int)
signal fled
signal bit_player

enum State { AWAY, CIRCLE, APPROACH, BITE, FLEE, HUNT }

var state := State.AWAY
var raft: Raft
var daynight: DayNight
var cfg: Dictionary
var rng := RandomNumberGenerator.new()
var need := 4                 # hits that drive it off this visit
var target := Vector2i.ZERO
var swimmer: Node3D               # the player while swimming, else null
var enabled := true               # false until the first spear: the sea stays calm
var avoid: Array = []             # [center, shore radius] of an island nearby, or []
var _side := 0.0                  # which way round the island it is going (0: not going round)
var _hunt_cd := 0.0
var _timer := 0.0
var _angle := 0.0
var _goal := Vector3.ZERO
var _bite_t := 0.0
var _t := 0.0
var _depth := -0.75
var _lunge := 0.0
var _hurt_t := 0.0
var _hits := 0                # hits during this visit
var _body: MeshInstance3D
var _tail: MeshInstance3D


func _ready() -> void:
	cfg = Data.b["shark"]
	rng.randomize()
	top_level = true
	var parts := Looks.shark_parts()
	_body = MeshInstance3D.new()
	_body.mesh = parts[0]
	add_child(_body)
	_tail = MeshInstance3D.new()
	_tail.mesh = parts[1]
	_tail.position = Vector3(0, 0, _joint_z())
	_body.add_child(_tail)
	reset(float(cfg["first_delay"]))


func _joint_z() -> float:
	return (9.0 / 14.0 - 0.5) * 2.6


## Back to waiting off-screen; the next visit comes after `delay` seconds.
func reset(delay: float) -> void:
	state = State.AWAY
	_new_visit()
	_timer = delay
	visible = false


func _new_visit() -> void:
	_hits = 0
	need = rng.randi_range(int(cfg["hits"][0]), int(cfg["hits"][1]))


func hits_left() -> int:
	return maxi(0, need - _hits)


func attacking() -> bool:
	return state == State.APPROACH or state == State.BITE


func hunting() -> bool:
	return state == State.HUNT


func alive_near() -> bool:
	return state in [State.CIRCLE, State.APPROACH, State.BITE, State.FLEE, State.HUNT]


func _center() -> Vector3:
	var c := raft.global_transform * raft.centroid()
	return Vector3(c.x, 0, c.z)


func _radius() -> float:
	var r := float(cfg["orbit_radius"])
	for c: Vector2i in raft.tiles:
		r = maxf(r, raft.cell_center(c).distance_to(raft.centroid()) + 5.0)
	return r


func _next_attack() -> float:
	var t := rng.randf_range(float(cfg["interval"][0]), float(cfg["interval"][1]))
	return t * (float(cfg["night_mult"]) if daynight and daynight.is_night() else 1.0)


## A spear thrust (or a bolt) from `eye` along `fwd`. Returns true on a hit.
## `power` hits at once (metal spear: 2), `reach` added to the spear's range, `cone` how
## straight at it the strike has to go.
func try_hit(eye: Vector3, fwd: Vector3, power := 1, reach := 0.0, cone := 0.6) -> bool:
	if not alive_near() or state == State.FLEE:
		return false
	var to := global_position - eye
	var flat := Vector2(to.x, to.z)
	if flat.length() > float(cfg["hit_reach"]) + 1.0 + reach:
		return false
	var f2 := Vector2(fwd.x, fwd.z).normalized()
	if flat.normalized().dot(f2) < cone:
		return false
	_hits += power
	_hurt_t = 0.4
	_hunt_cd = 3.5
	hurt.emit(hits_left())
	if _hits >= need:
		_flee(float(cfg["flee_time"]), true)
	else:
		# Backs off for a moment, then comes again.
		state = State.CIRCLE
		_timer = 4.0
	return true


func _flee(time: float, by_player := false) -> void:
	state = State.FLEE
	_timer = time
	_new_visit()
	if by_player:
		fled.emit()


func _process(delta: float) -> void:
	_t += delta
	_hurt_t = maxf(0.0, _hurt_t - delta)
	_hunt_cd = maxf(0.0, _hunt_cd - delta)
	if swimmer and _hunt_cd <= 0.0 and state in [State.CIRCLE, State.APPROACH, State.BITE]:
		state = State.HUNT
		_bite_t = 0.6
	match state:
		State.AWAY:
			if not enabled:
				return
			_timer -= delta * (3.0 if swimmer else 1.0)
			if _timer <= 0.0:
				state = State.CIRCLE
				_angle = rng.randf() * TAU
				global_position = _center() + Vector3(cos(_angle), 0, sin(_angle)) * (_radius() + 12.0)
				visible = true
				_timer = 8.0
		State.CIRCLE:
			_angle += float(cfg["speed"]) / _radius() * delta
			var p := _center() + Vector3(cos(_angle), 0, sin(_angle)) * _radius()
			_swim_to(p, float(cfg["approach_speed"]), delta)
			_timer -= delta
			if _timer <= 0.0:
				_pick_target()
		State.APPROACH:
			_update_goal()
			if not raft.has_tile(target) or not _open_water(_goal):
				_pick_target()
				return
			if _swim_to(_goal, float(cfg["approach_speed"]), delta) < 0.4:
				state = State.BITE
				_bite_t = float(cfg["first_bite"])
		State.BITE:
			if not raft.has_tile(target):
				_flee(float(cfg["flee_time"]))
				return
			_update_goal()
			_swim_to(_goal, 2.0, delta)
			_face(raft.to_global(raft.cell_center(target)))
			_bite_t -= delta
			if _bite_t <= 0.0:
				_bite_t = float(cfg["bite_every"])
				_lunge = 1.0
				var sank := raft.damage_tile(target)
				bit.emit(target, sank)
				if sank:
					_flee(float(cfg["flee_time"]))
		State.HUNT:
			if swimmer == null:
				state = State.CIRCLE
				_timer = 4.0
			else:
				var p := swimmer.global_position
				if _swim_to(p, float(cfg["hunt_speed"]), delta) < 1.3:
					_face(p)
					_bite_t -= delta
					if _bite_t <= 0.0:
						_bite_t = float(cfg["bite_every"])
						_lunge = 1.0
						bit_player.emit()
		State.FLEE:
			var away := (global_position - _center())
			away.y = 0.0
			_swim_to(global_position + away.normalized() * 6.0, float(cfg["approach_speed"]) * 1.3, delta)
			_timer -= delta
			if _timer <= 0.0:
				state = State.CIRCLE
				_timer = _next_attack()
	_animate(delta)


func _pick_target() -> void:
	var edges := raft.edge_cells().filter(func(c: Vector2i) -> bool: return _open_water(_goal_for(c)))
	if edges.is_empty():
		state = State.CIRCLE
		_timer = _next_attack()
		return
	# Prefer the edge tile closest to where the shark already is.
	var best: Vector2i = edges[0]
	var bd := INF
	for c in edges:
		var d := raft.to_global(raft.cell_center(c)).distance_to(global_position) + rng.randf() * 2.0
		if d < bd:
			bd = d
			best = c
	target = best
	state = State.APPROACH
	attacked.emit(target)


func _update_goal() -> void:
	_goal = _goal_for(target)


## A point in the water just outside a tile's free side (one away from an island).
func _goal_for(cell: Vector2i) -> Vector3:
	var c := raft.cell_center(cell)
	var sides: Array[Vector3] = []
	var sum := Vector3.ZERO
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not raft.has_tile(cell + d):
			sides.append(Vector3(d.x, 0, d.y))
			sum += Vector3(d.x, 0, d.y)
	if sum != Vector3.ZERO:
		sides.push_front(sum)
	if sides.is_empty():
		sides.append((c - raft.centroid()).normalized())
	var best := Vector3.ZERO
	for i in sides.size():
		var local := c + sides[i].normalized() * (raft.tile_size * 0.5 + 1.0)
		var g := raft.to_global(Vector3(local.x, 0, local.z))
		if i == 0:
			best = g
		if _open_water(g):
			return g
	return best


## Far enough from the island to get to: outside the circle it swims round (see _around).
func _open_water(p: Vector3) -> bool:
	return avoid.is_empty() or Vector2(p.x - avoid[0].x, p.z - avoid[0].z).length() > float(avoid[1]) + 2.4


## Moves toward `p` on the water plane, round an island in the way; returns the remaining
## distance.
func _swim_to(p: Vector3, speed: float, delta: float) -> float:
	var pos := global_position
	var to := Vector3(p.x - pos.x, 0, p.z - pos.z)
	var d := to.length()
	if d > 0.01:
		var step := _around(pos, to / d, d) * minf(d, speed * delta)
		pos += step
		if not avoid.is_empty():
			# Never inside the island: slide along its shore.
			var c: Vector3 = avoid[0]
			var out := Vector3(pos.x - c.x, 0, pos.z - c.z)
			var r := float(avoid[1]) + 0.8
			if out.length() < r:
				var q := c + out.normalized() * r
				pos = Vector3(q.x, pos.y, q.z)
		if state != State.BITE:
			_face(pos + step * 10.0)
	global_position = pos
	return d


## The way to swim: straight at the goal, or along the shore while the island is between.
func _around(pos: Vector3, dir: Vector3, dist: float) -> Vector3:
	if avoid.is_empty():
		_side = 0.0
		return dir
	var c: Vector3 = avoid[0]
	var r := float(avoid[1]) + 1.6
	var to_c := Vector3(c.x - pos.x, 0, c.z - pos.z)
	var along := to_c.dot(dir)
	var miss := (to_c - dir * along).length()
	if along <= 0.0 or miss >= r or along - sqrt(maxf(0.0, r * r - miss * miss)) > dist:
		_side = 0.0
		return dir
	var radial := -to_c.normalized()
	var tangent := Vector3(-radial.z, 0, radial.x)
	if _side == 0.0:
		_side = 1.0 if tangent.dot(dir) >= 0.0 else -1.0
	return tangent * _side


func _face(at: Vector3) -> void:
	var dir := Vector3(at.x - global_position.x, 0, at.z - global_position.z)
	if dir.length() < 0.01:
		return
	var want := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, want, 0.12)


func _animate(delta: float) -> void:
	var surface := Ocean.height_at(global_position.x, global_position.z)
	var depth_goal := -0.45 if state in [State.BITE, State.HUNT] else -0.75
	_depth = lerpf(_depth, depth_goal, delta * 3.0)
	_lunge = maxf(0.0, _lunge - delta * 3.0)
	global_position.y = surface + _depth + sin(_lunge * PI) * 0.25
	var swim := 6.0 if state == State.FLEE else 3.5
	_tail.rotation.y = sin(_t * swim) * 0.4
	_body.rotation.y = -sin(_t * swim) * 0.06
	_body.position.z = -sin(_lunge * PI) * 0.6
	_body.rotation.z = sin(_t * 30.0) * 0.15 * _hurt_t
