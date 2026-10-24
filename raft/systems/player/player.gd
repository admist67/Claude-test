class_name Player
extends CharacterBody3D
## First-person survivor. Lives inside the Raft node (bobs with it) and cannot walk off it.
## Moves with the touch joystick (or WASD), looks with drags (or the mouse).

var raft: Raft
var cam: Camera3D
var hand: Node3D
var yaw := 0.0
var pitch := -0.15
var move_input := Vector2.ZERO
var cfg: Dictionary
var _bob := 0.0
var _last_ok := Vector3.ZERO
var _held: Node3D
var _held_id := ""


func _ready() -> void:
	cfg = Data.b["player"]
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(62.0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.25
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	cam = Camera3D.new()
	cam.position.y = float(cfg["eye"])
	cam.fov = 75.0
	cam.near = 0.05
	cam.far = 160.0
	add_child(cam)
	hand = Node3D.new()
	hand.position = Vector3(0.26, -0.26, -0.5)
	cam.add_child(hand)
	_last_ok = position


## Puts the player at a raft-local point (new game, load, respawn).
func place(local: Vector3, look_yaw := 0.0) -> void:
	position = local
	_last_ok = local
	velocity = Vector3.ZERO
	yaw = look_yaw
	pitch = -0.12


func look(rel: Vector2) -> void:
	var k: float = float(cfg["look_sens"]) * float(Data.tune["look"])
	yaw -= rel.x * k
	pitch = clampf(pitch - rel.y * k, -1.35, 1.2)


## Global forward of the view, flattened onto the water plane.
func flat_forward() -> Vector3:
	var f := -cam.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD


func hand_tip() -> Vector3:
	return hand.global_position + -cam.global_basis.z * 0.25


## Where a thrown rope leaves the view: just below the bottom-right edge of the screen.
func rope_anchor() -> Vector3:
	return cam.global_transform * Vector3(0.32, -0.5, -0.55)


## A point on the held model (its local space), e.g. the rod tip.
func held_point(local: Vector3) -> Vector3:
	if _held and _held.get_child_count() > 0:
		return (_held.get_child(0) as Node3D).global_transform * local
	return hand_tip()


## Shows the selected hotbar item in the right hand.
func hold(id: String) -> void:
	if id == _held_id:
		return
	_held_id = id
	if _held:
		_held.queue_free()
		_held = null
	if id == "":
		return
	_held = Looks.held(id)
	hand.add_child(_held)
	hand.position.y = -0.5
	create_tween().tween_property(hand, "position:y", -0.26, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func swing() -> void:
	var tw := create_tween()
	tw.tween_property(hand, "rotation:x", -0.7, 0.08)
	tw.tween_property(hand, "rotation:x", 0.0, 0.18)


func set_hand_visible(v: bool) -> void:
	if _held:
		_held.visible = v


func _physics_process(delta: float) -> void:
	rotation.y = yaw
	cam.rotation.x = pitch
	var inp := move_input
	var kb := Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		kb.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		kb.x += 1.0
	if Input.is_key_pressed(KEY_W):
		kb.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		kb.y += 1.0
	if kb.length() > 0.1:
		inp = kb.limit_length(1.0)
	var dir := global_basis * Vector3(inp.x, 0, inp.y)
	dir.y = 0.0
	var on_stairs := raft.parts.on_stairs(position)
	var target := dir * float(cfg["speed"]) * (float(cfg["stairs_speed"]) if on_stairs else 1.0)
	var acc := float(cfg["accel"]) * delta
	velocity.x = move_toward(velocity.x, target.x, acc)
	velocity.z = move_toward(velocity.z, target.z, acc)
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta
	var before := position
	move_and_slide()
	_keep_on_raft(before)
	var speed := Vector2(velocity.x, velocity.z).length()
	_bob += delta * speed * 4.2
	cam.position.y = float(cfg["eye"]) + sin(_bob) * 0.03 * minf(1.0, speed)
	hand.rotation.z = sin(_bob * 0.5) * 0.05


## Slides along the raft edge instead of walking into the sea.
func _keep_on_raft(before: Vector3) -> void:
	if position.y < -1.0:
		position = _last_ok
		velocity = Vector3.ZERO
		return
	if _ok(position):
		_last_ok = position
		return
	var p := position
	for cand: Vector3 in [Vector3(before.x, p.y, p.z), Vector3(p.x, p.y, before.z), before]:
		if _ok(cand):
			position = cand
			_last_ok = cand
			return
	position = _last_ok


func _ok(p: Vector3) -> bool:
	var m := float(cfg["edge_margin"])
	for o: Vector3 in [Vector3.ZERO, Vector3(m, 0, 0), Vector3(-m, 0, 0), Vector3(0, 0, m), Vector3(0, 0, -m)]:
		if not raft.walkable(p + o):
			return false
	return true
