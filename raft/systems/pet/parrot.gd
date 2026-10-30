class_name Parrot
extends Node3D
## A scarlet macaw. Sits upright and looks about, preens, bobs its head, flicks its tail,
## stretches a wing; flies in an arc with its wings beating; hovers screaming; pecks at
## food; carries a find in its beak; sleeps with its head tucked in. Only motion here:
## where it goes and why is PetCare's. Moves in its parent's space; origin at its feet,
## facing -Z.

signal arrived

enum Mode { PERCH, FLY, HOVER, SLEEP }

const PERCH_TILT := 0.95          # the body upright on a perch
const FLY_TILT := 0.12
const SIZE := 1.35

var mode := Mode.PERCH
var hungry := false               # sulks: ruffled, head low
var speed := 4.5
var _model: Node3D
var _body: Node3D
var _head: Node3D
var _jaw: Node3D
var _wings: Array[Node3D] = []
var _tail: Node3D
var _legs: MeshInstance3D
var _carry: Node3D
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _u := 0.0
var _dur := 1.0
var _arc := 1.0
var _t := 0.0
var _open := 0.0                  # wings: 0 folded .. 1 spread
var _flap := 0.0
var _tilt := PERCH_TILT
var _head_aim := Vector2.ZERO     # yaw, pitch the head turns toward
var _head_now := Vector2.ZERO
var _jaw_open := 0.0
var _tail_aim := 0.0
var _stretch := 0.0
var _next := 1.5                  # seconds to the next gesture
var _gesture := ""
var _gesture_t := 0.0
var _hover_at := Vector3(INF, INF, INF)
var _face := 0.0
# Folded: the wing hangs down the side, its feathers toward the tail.
var _q_fold := Quaternion(Vector3.RIGHT, PI * 0.47)


func _ready() -> void:
	_model = Node3D.new()
	_model.rotation.y = PI / 2.0
	_model.scale = Vector3.ONE * SIZE
	add_child(_model)
	_legs = _mi("legs", _model)
	_body = Node3D.new()
	_body.position = Vector3(0, 0.068, 0)
	_model.add_child(_body)
	_mi("body", _body)
	_head = Node3D.new()
	_head.position = Vector3(0.162, 0.012, 0)
	_body.add_child(_head)
	_mi("head", _head)
	_jaw = Node3D.new()
	_jaw.position = Vector3(0.05, 0.004, 0)
	_head.add_child(_jaw)
	_mi("jaw", _jaw)
	_carry = Node3D.new()
	_carry.position = Vector3(0.1, -0.035, 0)
	_head.add_child(_carry)
	for s: float in [1.0, -1.0]:
		var w := Node3D.new()
		w.position = Vector3(0.085, 0.042, s * 0.062)
		_body.add_child(w)
		_mi("wing", w)
		_wings.append(w)
	_tail = Node3D.new()
	_tail.position = Vector3(-0.12, 0.004, 0)
	_body.add_child(_tail)
	_mi("tail", _tail)
	_face = rotation.y


func _mi(part: String, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ParrotLooks.mesh(part)
	parent.add_child(mi)
	return mi


## A body the crosshair finds (the use button on a tamed pet).
func make_usable() -> void:
	var b := StaticBody3D.new()
	b.collision_layer = Part.USE_LAYER
	b.collision_mask = 0
	b.set_meta("part", self)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 0.7, 0.6)
	cs.shape = shape
	cs.position = Vector3(0, 0.32, 0)
	b.add_child(cs)
	add_child(b)


## Flies in an arc to `p` (in the parent's space); `arc` metres above the straight line.
func fly_to(p: Vector3, arc := 1.0) -> void:
	_from = position
	_to = p
	var d := _from.distance_to(_to)
	_dur = maxf(0.45, d / speed)
	_arc = arc + d * 0.1
	_u = 0.0
	mode = Mode.FLY
	_gesture = ""
	if d > 1.5:
		Sfx.play("flap", -14.0, 0.2)


## A short hop on the deck.
func hop_to(p: Vector3) -> void:
	fly_to(p, 0.25)
	_dur = maxf(0.35, _from.distance_to(_to) / 2.2)
	_arc = 0.25


## Hangs in the air at `p`, beating its wings.
func hover(p: Vector3) -> void:
	if mode != Mode.HOVER:
		fly_to(p, 0.4)
	_hover_at = p


func sleep(on: bool) -> void:
	if on and mode == Mode.PERCH:
		mode = Mode.SLEEP
	elif not on and mode == Mode.SLEEP:
		mode = Mode.PERCH


func squawk() -> void:
	_gesture = "squawk"
	_gesture_t = 0.6
	Sfx.play("parrot", -3.0, 0.12)


func eat() -> void:
	_gesture = "eat"
	_gesture_t = 1.6
	Sfx.play("eat", -6.0)


## A happy little dance: head bobbing.
func dance() -> void:
	_gesture = "bob"
	_gesture_t = 1.4


func carry(id: String) -> void:
	drop()
	var m := MeshInstance3D.new()
	m.mesh = Looks.mesh(id)
	m.scale = Vector3.ONE * 0.42
	m.rotation = Vector3(0.3, 0.6, 0.2)
	_carry.add_child(m)


func drop() -> void:
	for c in _carry.get_children():
		c.queue_free()


func face_to(p: Vector3) -> void:
	var d := p - position
	if Vector2(d.x, d.z).length() > 0.01:
		_face = atan2(-d.x, -d.z)


func _process(delta: float) -> void:
	_t += delta
	match mode:
		Mode.FLY:
			_u = minf(1.0, _u + delta / _dur)
			var e := _u * _u * (3.0 - 2.0 * _u)
			position = _from.lerp(_to, e) + Vector3(0, sin(PI * _u) * _arc, 0)
			if Vector2(_to.x - position.x, _to.z - position.z).length() > 0.05:
				face_to(_to)
			_open = move_toward(_open, 1.0 if _arc > 0.3 else 0.6, delta * 6.0)
			_tilt = lerpf(_tilt, PERCH_TILT * 0.75 if _u > 0.8 else FLY_TILT, delta * 6.0)
			_flap = sin(_t * (19.0 if _u > 0.8 or _u < 0.15 else 13.0)) * 0.8
			if _u >= 1.0:
				position = _to
				mode = Mode.HOVER if _hover_at == _to else Mode.PERCH
				arrived.emit()
		Mode.HOVER:
			position = _hover_at + Vector3(sin(_t * 1.3) * 0.15, sin(_t * 2.7) * 0.08, cos(_t * 1.1) * 0.15)
			_open = move_toward(_open, 1.0, delta * 6.0)
			_tilt = lerpf(_tilt, 0.6, delta * 4.0)
			_flap = sin(_t * 21.0) * 0.9
		_:
			_open = move_toward(_open, _stretch, delta * 4.0)
			_tilt = lerpf(_tilt, PERCH_TILT - (0.15 if mode == Mode.SLEEP else 0.0), delta * 5.0)
			_flap = 0.0
			_idle(delta)
	if mode != Mode.HOVER and mode != Mode.FLY:
		_hover_at = Vector3(INF, INF, INF)
	rotation.y = lerp_angle(rotation.y, _face, minf(1.0, delta * 7.0))
	_pose(delta)


## Gestures on a perch, one at a time.
func _idle(delta: float) -> void:
	_gesture_t -= delta
	if mode == Mode.SLEEP:
		_head_aim = Vector2(2.3, -0.45)
		_tail_aim = 0.0
		_stretch = 0.0
		return
	if _gesture_t <= 0.0:
		_gesture = ""
		_stretch = 0.0
		_next -= delta
		_head_aim = Vector2(_head_aim.x * 0.98, (-0.25 if hungry else 0.0))
		if _next <= 0.0:
			_next = randf_range(1.2, 3.5)
			_gesture = ["look", "look", "look", "preen", "bob", "tail", "stretch"][randi() % 7]
			_gesture_t = randf_range(1.0, 1.8)
			if _gesture == "look":
				_head_aim = Vector2(randf_range(-1.0, 1.0), randf_range(-0.3, 0.3))
	match _gesture:
		"preen":
			_head_aim = Vector2(1.7, -0.7 + sin(_t * 18.0) * 0.08)
		"bob":
			_head_aim = Vector2(0.0, sin(_t * 14.0) * 0.35)
		"tail":
			_tail_aim = sin(_t * 16.0) * 0.25
		"stretch":
			_stretch = 0.55
		"squawk":
			_head_aim = Vector2(0.0, 0.35)
		"eat":
			_head_aim = Vector2(0.0, -0.8 + absf(sin(_t * 9.0)) * 0.3)
	if _gesture != "tail":
		_tail_aim = sin(_t * 1.3) * 0.05


func _pose(delta: float) -> void:
	_body.rotation = Vector3(0, 0, _tilt)
	var breathe := 1.0 + sin(_t * (1.4 if mode == Mode.SLEEP else 2.4)) * 0.015
	var fluff := 1.08 if hungry or mode == Mode.SLEEP else 1.0
	_body.scale = Vector3(1.0, breathe * fluff, fluff)
	_head_now = _head_now.lerp(_head_aim, minf(1.0, delta * 9.0))
	_head.transform.basis = Basis(Vector3.BACK, -_tilt * 0.85 + _head_now.y) * Basis(Vector3.UP, _head_now.x)
	_jaw_open = move_toward(_jaw_open, 0.45 if _gesture == "squawk" and _gesture_t > 0.15 else 0.0, delta * 5.0)
	_jaw.rotation.z = -_jaw_open
	var q := _q_fold.slerp(Quaternion(Vector3.RIGHT, _flap * _open), _open)
	# Folded, the hand tucks in: the wing gets shorter and narrower.
	var tuck := Basis.from_scale(Vector3(0.85, 1.0, 0.5).lerp(Vector3.ONE, _open))
	_wings[0].transform.basis = Basis(q) * tuck
	_wings[1].transform.basis = Basis.from_scale(Vector3(1, 1, -1)) * Basis(q) * tuck
	if _stretch > 0.0 and mode != Mode.FLY:
		_wings[1].transform.basis = Basis.from_scale(Vector3(1, 1, -1)) * Basis(_q_fold) * Basis.from_scale(Vector3(0.85, 1.0, 0.5))
	var fan := _open * 0.25
	_tail.transform.basis = Basis(Vector3.UP, _tail_aim) * Basis(Vector3.BACK, 0.12 - _open * 0.12) * Basis.from_scale(Vector3(1, 1, 1.0 + fan))
	_legs.visible = mode != Mode.FLY or _u > 0.85 or _arc < 0.3
