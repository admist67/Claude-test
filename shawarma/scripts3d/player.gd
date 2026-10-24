extends CharacterBody3D
## First-person cook: moves with the touch joystick (or WASD), looks with drags,
## carries one roll in the right hand.

const SPEED := 2.4
const ACCEL := 14.0
const EYE := 1.6
const LOOK_SENS := 0.0042

var cam: Camera3D
var yaw := 0.0
var pitch := -0.25
var move_input := Vector2.ZERO
var held: Dictionary = {}
var held_mesh: MeshInstance3D
var held_can: Node3D
var held_crate: Node3D
var held_ext: Node3D
var hand: Node3D
var bob := 0.0
var speed_mult := 1.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = M3.LAYER_WORLD
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.24
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	cam = Camera3D.new()
	cam.position.y = EYE
	cam.fov = 72.0
	cam.near = 0.03
	add_child(cam)
	hand = Node3D.new()
	hand.position = Vector3(0.24, -0.24, -0.46)
	hand.scale = Vector3.ONE * 0.7
	cam.add_child(hand)
	held_mesh = M3.make_roll()
	held_mesh.rotation = Vector3(0.3, 0.9, PI / 2.0)
	held_mesh.visible = false
	hand.add_child(held_mesh)
	held_can = M3.model(hand, "res://assets/models/food/soda-can.glb", Vector3(0, -0.08, 0), 0.45)
	held_can.visible = false
	held_crate = Node3D.new()
	hand.add_child(held_crate)
	M3.box(held_crate, Vector3(0.34, 0.16, 0.26), Vector3(-0.1, -0.05, 0), M3.mat(Color("#c98b55"), 0.8))
	M3.box(held_crate, Vector3(0.3, 0.03, 0.22), Vector3(-0.1, 0.04, 0), M3.mat(Color("#6cc24a"), 0.8))
	held_crate.visible = false
	held_ext = Node3D.new()
	hand.add_child(held_ext)
	M3.cyl(held_ext, 0.05, 0.05, 0.3, Vector3(0, -0.05, 0), M3.mat(Color("#e2493b"), 0.4), 12)
	M3.box(held_ext, Vector3(0.12, 0.03, 0.03), Vector3(-0.05, 0.12, 0), M3.mat(Color("#2b1d33")))
	held_ext.visible = false


func look(rel: Vector2) -> void:
	var k: float = LOOK_SENS * Bal.tune.get("look", 1.0)
	yaw -= rel.x * k
	pitch = clampf(pitch - rel.y * k, -1.3, 1.0)


## Holds a roll (made dict), a drink {"drink"}, a crate {"crate"} or the extinguisher {"ext"}.
func hold(made: Dictionary) -> void:
	held = made
	held_can.visible = made.has("drink")
	held_crate.visible = made.has("crate")
	held_ext.visible = made.has("ext")
	held_mesh.visible = not (made.has("drink") or made.has("crate") or made.has("ext"))
	if held_mesh.visible:
		M3.set_toast(held_mesh, made["toast"], Bal.b)
	hand.position.y = -0.44
	create_tween().tween_property(hand, "position:y", -0.24, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func drop() -> Dictionary:
	var made := held
	held = {}
	held_mesh.visible = false
	held_can.visible = false
	held_crate.visible = false
	held_ext.visible = false
	return made


func holding_roll() -> bool:
	return not held.is_empty() and not (held.has("drink") or held.has("crate") or held.has("ext"))


func hand_global() -> Vector3:
	return hand.global_position


func _physics_process(delta: float) -> void:
	rotation.y = yaw
	cam.rotation.x = pitch
	var inp := move_input
	var kb := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
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
	var dir := (transform.basis * Vector3(inp.x, 0, inp.y))
	dir.y = 0.0
	var target := dir * SPEED * speed_mult
	velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	var speed := Vector2(velocity.x, velocity.z).length()
	bob += delta * speed * 4.5
	cam.position.y = EYE + sin(bob) * 0.025 * minf(1.0, speed)
	hand.rotation.z = sin(bob * 0.5) * 0.04
