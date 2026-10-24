class_name TouchControls
extends Control
## Multi-touch input: a floating joystick on the left, look-drags elsewhere, and round
## buttons (action, grab, bag, pause, hotbar slots) that work while another finger moves.
## Also maps keyboard/mouse for desktop testing.

signal pressed(button: String)
signal released(button: String)
signal looked(rel: Vector2)

const JOY_R := 90.0
const KEYS := {KEY_SPACE: "action", KEY_F: "action", KEY_E: "grab", KEY_TAB: "bag", KEY_I: "bag", KEY_ESCAPE: "pause"}

var move := Vector2.ZERO
var enabled := false
## name -> {"c": Vector2, "r": float, "on": bool}; positions set by layout().
var buttons: Dictionary = {}
var held: Dictionary = {}          # button name -> true while pressed
var joy_index := -1
var joy_center := Vector2.ZERO
var _ptr: Dictionary = {}          # touch index -> {"btn": String, "last": Vector2}
var _slots := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for n: String in ["action", "grab", "bag", "pause"]:
		buttons[n] = {"c": Vector2.ZERO, "r": 40.0, "on": true}


func set_slots(n: int) -> void:
	for i in _slots:
		buttons.erase("slot%d" % i)
	_slots = n
	for i in n:
		buttons["slot%d" % i] = {"c": Vector2.ZERO, "r": 36.0, "on": true}
	layout()


func layout() -> void:
	if not buttons.has("action"):
		return
	var vs := get_viewport_rect().size
	_place("action", Vector2(vs.x - 140, vs.y - 150), 78.0)
	_place("grab", Vector2(vs.x - 300, vs.y - 105), 54.0)
	_place("bag", Vector2(vs.x - 66, 64), 42.0)
	_place("pause", Vector2(52, 52), 32.0)
	var gap := 86.0
	var x0 := vs.x / 2.0 - gap * (_slots - 1) / 2.0
	for i in _slots:
		_place("slot%d" % i, Vector2(x0 + gap * i, vs.y - 56), 36.0)


func _place(n: String, c: Vector2, r: float) -> void:
	buttons[n]["c"] = c
	buttons[n]["r"] = r


func reset() -> void:
	joy_index = -1
	move = Vector2.ZERO
	for b: String in held.keys():
		released.emit(b)
	held.clear()
	_ptr.clear()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		layout()


func _hit(pos: Vector2) -> String:
	for n: String in buttons:
		var b: Dictionary = buttons[n]
		if b["on"] and pos.distance_to(b["c"]) <= float(b["r"]) * 1.15:
			return n
	return ""


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventKey and not event.echo:
		_key(event)
		return
	var vs := get_viewport_rect().size
	if event is InputEventScreenTouch:
		if event.pressed:
			var b := _hit(event.position)
			if b != "":
				_ptr[event.index] = {"btn": b, "last": event.position}
				held[b] = true
				pressed.emit(b)
			elif joy_index < 0 and event.position.x < vs.x * 0.38 and event.position.y > 110.0:
				joy_index = event.index
				joy_center = event.position
				move = Vector2.ZERO
			else:
				_ptr[event.index] = {"btn": "", "last": event.position}
		else:
			if event.index == joy_index:
				joy_index = -1
				move = Vector2.ZERO
			elif _ptr.has(event.index):
				var b: String = _ptr[event.index]["btn"]
				if b != "":
					held.erase(b)
					released.emit(b)
				_ptr.erase(event.index)
		queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == joy_index:
			move = ((event.position - joy_center) / JOY_R).limit_length(1.0)
			queue_redraw()
		elif _ptr.has(event.index):
			var p: Dictionary = _ptr[event.index]
			# Free drags look around; dragging the action button aims while charging.
			if p["btn"] == "" or p["btn"] == "action":
				looked.emit(event.position - p["last"])
			p["last"] = event.position


func _key(e: InputEventKey) -> void:
	var b := ""
	if KEYS.has(e.keycode):
		b = KEYS[e.keycode]
	elif e.keycode >= KEY_1 and e.keycode <= KEY_9 and e.keycode - KEY_1 < _slots:
		b = "slot%d" % (e.keycode - KEY_1)
	if b == "":
		return
	if e.pressed and not held.has(b):
		held[b] = true
		pressed.emit(b)
	elif not e.pressed and held.has(b):
		held.erase(b)
		released.emit(b)


func _draw() -> void:
	if not enabled:
		return
	var vs := get_viewport_rect().size
	if joy_index < 0:
		var c := Vector2(160, vs.y - 160)
		draw_circle(c, JOY_R, Color(1, 1, 1, 0.07))
		draw_arc(c, JOY_R, 0, TAU, 40, Color(1, 1, 1, 0.3), 4.0, true)
		draw_circle(c, 36.0, Color(1, 1, 1, 0.22))
	else:
		draw_circle(joy_center, JOY_R, Color(1, 1, 1, 0.1))
		draw_arc(joy_center, JOY_R, 0, TAU, 40, Color(1, 1, 1, 0.45), 4.0, true)
		draw_circle(joy_center + move * JOY_R, 38.0, Color(1, 1, 1, 0.6))
