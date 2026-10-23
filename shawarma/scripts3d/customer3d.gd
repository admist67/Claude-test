extends Node3D
## A 3D customer outside the window: Kenney character with animations, a speech line and
## patience. The order bubble is drawn in screen space by orders_ui.gd.
## Tappable kind: "customer" (its StaticBody's parent is this node).

signal gave_up(c)

enum St { ENTER, WAIT, LEAVE }

const SCALE := 2.05
const WALK_SPEED := 1.7

var st := St.ENTER
var ctype: Dictionary
var order: Order
var patience := 40.0
var patience_max := 40.0
var slot := 0
var model: Node3D
var anim: AnimationPlayer
var bubble_pop := 0.0      # order bubble scale, drawn in screen space by orders_ui.gd
var say_label: Label3D
var say_t := 0.0


func setup(type_def: Dictionary, o: Order, patience_s: float, slot_i: int, model_path: String) -> void:
	ctype = type_def
	order = o
	patience = patience_s
	patience_max = patience_s
	slot = slot_i
	model = M3.model(self, model_path, Vector3.ZERO, SCALE)
	anim = model.find_child("AnimationPlayer", true, false)
	if anim:
		for a in ["idle", "walk"]:
			if anim.has_animation(a):
				anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	say_label = M3.label(self, "", Vector3(0, 2.42, 0), 56, DU.CREAM, 16, 0.0032)
	say_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	say_label.visible = false
	var body := M3.solid(self, Vector3(0.8, 1.3, 0.7), Vector3(0, 1.45, 0), M3.LAYER_USE, "customer")
	body.set_meta("customer", self)
	var greet: Array = type_def["greet"]
	say_label.text = greet[randi() % greet.size()]


func _play(a: String, speed := 1.0) -> void:
	if anim and anim.has_animation(a):
		anim.play(a, 0.2, speed)


func _face(dir: Vector3) -> void:
	if dir.length() > 0.01:
		rotation.y = atan2(dir.x, dir.z)


## Walks from `from` along the street lane, then steps up to the window at `to`.
func arrive(from: Vector3, to: Vector3) -> void:
	position = from
	var lane := Vector3(to.x, 0, from.z)
	_play("walk")
	_face(lane - from)
	var tw := create_tween()
	tw.tween_property(self, "position", lane, from.distance_to(lane) / WALK_SPEED)
	tw.tween_callback(func(): _face(to - lane))
	tw.tween_property(self, "position", to, lane.distance_to(to) / WALK_SPEED)
	tw.tween_callback(_on_arrived)


func _on_arrived() -> void:
	st = St.WAIT
	_face(Vector3(0, 0, 1))
	_play("idle")
	bubble_pop = 0.0
	create_tween().tween_property(self, "bubble_pop", 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_say(say_label.text, 2.4)
	Sfx.play("bell", 0.05, -6.0)


func _say(text: String, dur: float) -> void:
	say_label.text = text
	say_label.visible = true
	say_t = dur


## mood: "happy" / "meh" / "angry"
func leave(exit_x: float, phrase: String, mood: String) -> void:
	st = St.LEAVE
	bubble_pop = 0.0
	_say(phrase, 2.0)
	_play("emote-no" if mood == "angry" else ("emote-yes" if mood == "happy" else "idle"))
	var back := Vector3(position.x, 0, position.z - 0.8)
	var out := Vector3(exit_x, 0, back.z)
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_callback(func():
		_play("walk")
		_face(back - position)
	)
	tw.tween_property(self, "position", back, 0.8 / WALK_SPEED)
	tw.tween_callback(func(): _face(out - back))
	tw.tween_property(self, "position", out, back.distance_to(out) / WALK_SPEED)
	tw.tween_callback(queue_free)


func patience_frac() -> float:
	return clampf(patience / patience_max, 0.0, 1.0)


func head_global() -> Vector3:
	return to_global(Vector3(0, 1.7, 0))


func _process(delta: float) -> void:
	if say_t > 0.0:
		say_t -= delta
		if say_t <= 0.0:
			say_label.visible = false
	if st == St.WAIT:
		patience -= delta
		if patience <= 0.0:
			gave_up.emit(self)
