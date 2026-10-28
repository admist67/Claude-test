class_name Gull
extends Node3D
## A seagull: flies in from the sea to a planter, lands on its edge and pecks; flies off
## when scared or done. The node's origin is at its feet; it faces -Z.

enum State { FLY, PECK, FLEE }

static var _meshes: Array[ArrayMesh] = []

var state := State.FLY
var target: Station
var speed := 5.5
var peck_t := 0.0                  # seconds spent pecking
var gone := false                  # flew far enough away to be removed
var _wings: Array[Node3D] = []
var _body: Node3D
var _t := 0.0
var _away := Vector3.ZERO


func _ready() -> void:
	if _meshes.is_empty():
		_meshes = [_body_mesh(), _wing_mesh()]
	_body = Node3D.new()
	_body.position = Vector3(0, 0.12, 0)
	add_child(_body)
	var bm := MeshInstance3D.new()
	bm.mesh = _meshes[0]
	bm.rotation.y = PI / 2.0
	_body.add_child(bm)
	for side: float in [1.0, -1.0]:
		var w := Node3D.new()
		w.position = Vector3(side * 0.05, 0.07, -0.02)
		w.scale.x = side
		var wm := MeshInstance3D.new()
		wm.mesh = _meshes[1]
		w.add_child(wm)
		_body.add_child(w)
		_wings.append(w)


## Where it lands: the top of the planter's frame, a little to one side.
func perch() -> Vector3:
	return target.global_transform * Vector3(0.48, 0.36, 0.1)


func flee() -> void:
	if state == State.FLEE:
		return
	state = State.FLEE
	var out := global_position - (target.global_position if is_instance_valid(target) else global_position + Vector3.FORWARD)
	out.y = 0.0
	_away = (out.normalized() if out.length() > 0.01 else Vector3.FORWARD) * speed * 1.3 + Vector3(0, 3.0, 0)
	_t = 0.0


func _process(delta: float) -> void:
	_t += delta
	match state:
		State.FLY:
			if not is_instance_valid(target):
				flee()
				return
			var goal := perch()
			var to := goal - global_position
			var dist := to.length()
			# Come in from above, gliding the last stretch.
			var aim := goal + Vector3(0, clampf(dist * 0.35 - 0.5, 0.0, 6.0), 0)
			var step := (aim - global_position).normalized() * speed * delta
			if dist < 0.25 or step.length() >= dist:
				global_position = goal
				state = State.PECK
				peck_t = 0.0
			else:
				global_position += step
				_face(to)
			_flap(9.0 if dist > 4.0 else 3.5, 0.75 if dist > 4.0 else 0.3)
		State.PECK:
			if not is_instance_valid(target):
				flee()
				return
			global_position = perch()
			peck_t += delta
			for w in _wings:
				w.rotation = Vector3(0, 1.35, -0.1)
			# A quick peck now and then, head down.
			var ph := fmod(peck_t, 0.9)
			_body.rotation.x = -0.55 if ph < 0.18 else 0.0
		State.FLEE:
			global_position += _away * delta
			_away.y = maxf(1.0, _away.y - delta * 1.5)
			_face(_away)
			_body.rotation.x = 0.0
			_flap(11.0, 0.85)
			gone = _t > 5.0


func _face(dir: Vector3) -> void:
	var flat := Vector3(dir.x, 0, dir.z)
	if flat.length() > 0.01:
		rotation.y = atan2(-flat.x, -flat.z)


func _flap(freq: float, amp: float) -> void:
	var a := sin(_t * freq) * amp
	for i in _wings.size():
		_wings[i].rotation = Vector3(0, 0, a)


## Body along +X: white loft with a gray back band, yellow beak with a red spot, black
## eyes, a short tail and orange legs.
static func _body_mesh() -> ArrayMesh:
	var st := Mk.st_begin()
	var w := Mk.cell("white")
	var rings: Array = []
	var prof := [[0.2, 0.035, 0.03, 0.08], [0.17, 0.05, 0.045, 0.08], [0.13, 0.045, 0.04, 0.07], [0.08, 0.05, 0.05, 0.04],
			[0.02, 0.075, 0.07, 0.0], [-0.08, 0.075, 0.075, 0.0], [-0.17, 0.05, 0.05, 0.01], [-0.25, 0.02, 0.03, 0.02]]
	for p: Array in prof:
		rings.append([p[0], p[1], p[2], p[3], 0.5])
	FoodLooks.loft(st, rings, 12, w, Color("#f4f4f2"), 0.215)
	Mk.st_box(st, Vector3(0.24, 0.02, 0.13), Vector3(-0.06, 0.07, 0), Color("#a7b0b8"), "white")
	var beak: Array = [[0.3, 0.008, 0.006, 0.075, 0.5], [0.26, 0.013, 0.01, 0.075, 0.5], [0.215, 0.017, 0.014, 0.078, 0.5]]
	FoodLooks.loft(st, beak, 8, w, Color("#f2c230"), 0.305)
	Mk.st_box(st, Vector3(0.012, 0.01, 0.022), Vector3(0.28, 0.068, 0), Color("#d8352a"), "white")
	for s: float in [-1.0, 1.0]:
		Mk.st_box(st, Vector3(0.016, 0.016, 0.01), Vector3(0.175, 0.095, s * 0.032), Color(0.05, 0.05, 0.06), "white")
	Mk.st_box(st, Vector3(0.1, 0.012, 0.09), Vector3(-0.29, 0.03, 0), Color("#e8eaea"), "white", Vector3(0, 0, 0.15))
	Mk.st_box(st, Vector3(0.04, 0.012, 0.09), Vector3(-0.34, 0.035, 0), Color(0.12, 0.12, 0.14), "white", Vector3(0, 0, 0.15))
	for s: float in [-1.0, 1.0]:
		Mk.st_box(st, Vector3(0.012, 0.12, 0.012), Vector3(0.0, -0.1, s * 0.035), Color("#e8903a"), "white")
		Mk.st_box(st, Vector3(0.05, 0.006, 0.03), Vector3(0.02, -0.157, s * 0.035), Color("#e8903a"), "white")
	return Mk.st_commit(st)


## One wing along +X from the shoulder: a gray inner part, a longer outer part with black tips.
static func _wing_mesh() -> ArrayMesh:
	var st := Mk.st_begin()
	Mk.st_box(st, Vector3(0.26, 0.018, 0.15), Vector3(0.13, 0, 0), Color("#a7b0b8"), "white")
	Mk.st_box(st, Vector3(0.22, 0.014, 0.12), Vector3(0.36, 0, 0.015), Color("#b8c0c6"), "white", Vector3(0, 0.12, 0))
	Mk.st_box(st, Vector3(0.12, 0.012, 0.09), Vector3(0.52, 0, 0.04), Color(0.1, 0.1, 0.12), "white", Vector3(0, 0.25, 0))
	Mk.st_box(st, Vector3(0.45, 0.01, 0.03), Vector3(0.25, 0, -0.07), Color("#f4f4f2"), "white")
	return Mk.st_commit(st)
