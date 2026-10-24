extends Node3D
## A 3D customer: Kenney character with animations, a speech line and patience. Takeaway
## customers wait at the window; café guests (dine) sit at a table, may want a drink, eat
## and leave the table dirty. The order bubble is drawn in screen space by orders_ui.gd.
## Tappable kind: "customer" (the StaticBody's meta "customer" points here).

signal gave_up(c)

enum St { ENTER, WAIT, EAT, LEAVE }

const SCALE := 2.05
const WALK_SPEED := 1.7

var st := St.ENTER
var ctype: Dictionary
var order: Order
var patience := 40.0
var patience_max := 40.0
var slot := -1             # window slot, or -1 for café guests
var dine := false
var table := -1
var rolls: Array = []      # rolls handed over (couriers need order.count of them)
var got_drink := false
var bubble_h := 1.95       # bubble anchor height (lower when seated)
var model: Node3D
var anim: AnimationPlayer
var body: StaticBody3D
var bubble_pop := 0.0
var say_label: Label3D
var say_t := 0.0


func setup(type_def: Dictionary, o: Order, patience_s: float, model_path: String) -> void:
	ctype = type_def
	order = o
	patience = patience_s
	patience_max = patience_s
	model = M3.model(self, model_path, Vector3.ZERO, SCALE)
	anim = model.find_child("AnimationPlayer", true, false)
	if anim:
		for a in ["idle", "walk", "sit"]:
			if anim.has_animation(a):
				anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	say_label = M3.label(self, "", Vector3(0, 2.42, 0), 56, DU.CREAM, 16, 0.0032)
	say_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	say_label.visible = false
	body = M3.solid(self, Vector3(0.8, 1.3, 0.7), Vector3(0, 1.45, 0), M3.LAYER_USE, "customer")
	body.set_meta("customer", self)
	var greet: Array = type_def["greet"]
	say_label.text = greet[randi() % greet.size()]
	if type_def.get("type_id", "") == "courier":
		M3.box(self, Vector3(0.62, 0.62, 0.42), Vector3(0, 1.05, -0.42), M3.mat(Color("#ff8a3d"), 0.6))
		M3.box(self, Vector3(0.64, 0.12, 0.44), Vector3(0, 1.2, -0.42), M3.mat(Color("#2b1d33"), 0.6))


func _play(a: String, speed := 1.0) -> void:
	if anim and anim.has_animation(a):
		anim.play(a, 0.2, speed)


func _face(dir: Vector3) -> void:
	if dir.length() > 0.01:
		rotation.y = atan2(dir.x, dir.z)


func _face_to(q: Vector3) -> void:
	_face(q - position)


## Walks through the points in order; calls `then` at the end.
func walk(points: Array, then := Callable()) -> Tween:
	var tw := create_tween()
	tw.tween_callback(_play.bind("walk"))
	var prev := position
	for p in points:
		var q: Vector3 = p
		tw.tween_callback(_face_to.bind(q))
		tw.tween_property(self, "position", q, maxf(0.05, prev.distance_to(q) / WALK_SPEED))
		prev = q
	if then.is_valid():
		tw.tween_callback(then)
	return tw


## Starts at points[0] and walks the rest; at the end waits (standing or seated).
func arrive(points: Array) -> void:
	position = points[0]
	walk(points.slice(1), _on_arrived)


func _on_arrived() -> void:
	st = St.WAIT
	_face(Vector3(0, 0, 1))
	if dine:
		_play("sit")
		model.position.y = 0.2   # up onto the chair seat
		bubble_h = 1.75
		body.position.y = 1.0
	else:
		_play("idle")
	bubble_pop = 0.0
	create_tween().tween_property(self, "bubble_pop", 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_say(say_label.text, 2.4)
	Sfx.play("bell", 0.05, -6.0)


func _say(text: String, dur: float) -> void:
	say_label.text = text
	say_label.visible = true
	say_t = dur


func needs_roll() -> bool:
	return rolls.size() < order.count


## True once everything ordered has been handed over.
func complete() -> bool:
	return not needs_roll() and (got_drink or not order.drink)


## Café guest eats for a while, then leaves along `exit`.
func eat_then_leave(dur: float, exit: Array, phrase: String, mood: String) -> void:
	st = St.EAT
	bubble_pop = 0.0
	_say(phrase, 2.0)
	_play("emote-yes" if mood == "happy" else "sit")
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_callback(_play.bind("sit"))
	tw.tween_interval(maxf(0.5, dur - 1.0))
	tw.tween_callback(func():
		st = St.LEAVE
		body.position.y = 1.45
		model.position.y = 0.0
		walk(exit, queue_free)
	)


## mood: "happy" / "meh" / "angry". Window customers step back first.
func leave(exit: Array, phrase: String, mood: String) -> void:
	st = St.LEAVE
	bubble_pop = 0.0
	_say(phrase, 2.0)
	if dine:
		body.position.y = 1.45
		model.position.y = 0.0
	_play("emote-no" if mood == "angry" else ("emote-yes" if mood == "happy" else "idle"))
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_callback(func(): walk(exit, queue_free))


func patience_frac() -> float:
	return clampf(patience / patience_max, 0.0, 1.0)


func head_global() -> Vector3:
	return to_global(Vector3(0, 1.3 if dine and st != St.LEAVE else 1.7, 0))


func _process(delta: float) -> void:
	if say_t > 0.0:
		say_t -= delta
		if say_t <= 0.0:
			say_label.visible = false
	if st == St.WAIT:
		patience -= delta
		if patience <= 0.0:
			gave_up.emit(self)
