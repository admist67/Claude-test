class_name Crab
extends Node3D
## A beach crab guarding an island. It wanders the sand; when the player walks onto the
## island close by, it scuttles over and pinches until the player leaves or spears it
## (it backs off for a moment after each hit). It never goes into the water.
## Numbers in data/balance.json "islands" → "crabs". Lives in island-local space.

signal pinched
signal died(crab: Crab)

var island: Island
var player: Player
var cfg: Dictionary
var hp := 2
var dead := false
var _target := Vector2.ZERO
var _wait := 0.0
var _pinch_t := 0.0
var _stun := 0.0
var _t := 0.0
var _legs: Array[Node3D] = []
var _claws: Array[Node3D] = []
var _body: Node3D
var _rng := RandomNumberGenerator.new()


func setup(isl: Island, c: Dictionary, s: int) -> void:
	island = isl
	cfg = c
	hp = int(c["hp"])
	_rng.seed = s
	_body = Node3D.new()
	add_child(_body)
	var parts := IslandLooks.crab()
	_body.add_child(_mi(parts[0]))
	for i in 2:
		var leg := Node3D.new()
		leg.add_child(_mi(parts[1 + i]))
		_body.add_child(leg)
		_legs.append(leg)
		var claw := Node3D.new()
		claw.position = Vector3(-0.17 if i == 0 else 0.17, 0.2, -0.14)
		claw.add_child(_mi(parts[3 + i]))
		_body.add_child(claw)
		_claws.append(claw)
	_pick_target()


func _mi(m: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	return mi


func _pick_target() -> void:
	var a := _rng.randf() * TAU
	_target = Vector2(cos(a), sin(a)) * island.radius * _rng.randf_range(0.15, 0.75)
	_wait = _rng.randf_range(0.5, 2.5)


## A spear thrust from `eye` along `fwd` (world). True on a hit.
func try_hit(eye: Vector3, fwd: Vector3, power: int, reach: float, cone := 0.55) -> bool:
	if dead:
		return false
	var to := global_position + Vector3(0, 0.2, 0) - eye
	if to.length() > reach or to.normalized().dot(fwd) < cone:
		return false
	hp -= power
	_stun = 0.7
	var back := Vector2(to.x, to.z).normalized() * 0.6
	position += Vector3(back.x, 0, back.y)
	if hp <= 0:
		dead = true
		_body.rotation.z = PI          # belly up
		died.emit(self)
		get_tree().create_timer(2.0).timeout.connect(queue_free)
	return true


func _physics_process(delta: float) -> void:
	if dead or player == null:
		return
	_t += delta
	_stun = maxf(0.0, _stun - delta)
	_pinch_t = maxf(0.0, _pinch_t - delta)
	var me := Vector2(position.x, position.z)
	var pl := island.to_local(player.global_position)
	var p2 := Vector2(pl.x, pl.z)
	var on_land: bool = not player.swimming and pl.y > -0.6
	var chasing := on_land and me.distance_to(p2) < float(cfg["notice"])
	var goal := p2 if chasing else _target
	var moving := false
	if _stun <= 0.0:
		var d := goal - me
		if chasing and d.length() < float(cfg["reach"]):
			_face(d)
			if _pinch_t <= 0.0:
				_pinch_t = float(cfg["pinch_every"])
				pinched.emit()
				_claws[0].rotation.x = -0.6
				_claws[1].rotation.x = -0.6
		elif d.length() > 0.15:
			if not chasing and _wait > 0.0:
				_wait -= delta
			else:
				var step := d.normalized() * minf(d.length(), float(cfg["speed"]) * (1.0 if chasing else 0.5) * delta)
				me += step
				_face(d)
				moving = true
		elif not chasing:
			_pick_target()
	# Stay on the sand: never past the shore.
	var a := atan2(me.y, me.x)
	var lim := island.radius * IslandLooks.shore(a, island.wob) * 0.85
	if me.length() > lim:
		me = me.normalized() * lim
	position = Vector3(me.x, island.height_at(me) - 0.03, me.y)
	# Legs scuttle while it walks; the claws snap shut again after a pinch.
	var wig := sin(_t * 22.0) * 0.25 if moving else 0.0
	_legs[0].rotation.z = wig
	_legs[1].rotation.z = -wig
	for c in _claws:
		c.rotation.x = move_toward(c.rotation.x, sin(_t * 3.0) * 0.08, delta * 3.0)


func _face(d: Vector2) -> void:
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.y), 0.2)
