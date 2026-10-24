class_name TouchControls
extends Control
## Multi-touch input: a floating joystick on the left, look-drags elsewhere, and round
## buttons (action, use, bag, pause, hotbar and build slots) that work while another finger moves.
## Also maps keyboard/mouse for desktop testing.

signal pressed(button: String)
signal released(button: String)
signal looked(rel: Vector2)

const JOY_R := 90.0
const KEYS := {KEY_SPACE: "action", KEY_F: "action", KEY_E: "use", KEY_TAB: "bag", KEY_I: "bag", KEY_ESCAPE: "pause", KEY_R: "rotate"}

var move := Vector2.ZERO
var enabled := false
## name -> {"c": Vector2, "r": float, "on": bool}; positions set by layout().
var buttons: Dictionary = {}
var held: Dictionary = {}          # button name -> true while pressed
var joy_index := -1
var joy_center := Vector2.ZERO
var _ptr: Dictionary = {}          # touch index -> {"btn": String, "last": Vector2}
var _slots := 0
var _builds := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for n: String in ["action", "use", "bag", "pause", "rotate"]:
		buttons[n] = {"c": Vector2.ZERO, "r": 40.0, "on": n != "rotate"}


func set_slots(n: int) -> void:
	for i in _slots:
		buttons.erase("slot%d" % i)
	_slots = n
	for i in n:
		buttons["slot%d" % i] = {"c": Vector2.ZERO, "r": 36.0, "on": true}
	layout()


## Build-choice buttons shown above the hotbar while the hammer is out.
func set_builds(n: int) -> void:
	for i in _builds:
		buttons.erase("build%d" % i)
	_builds = n
	for i in n:
		buttons["build%d" % i] = {"c": Vector2.ZERO, "r": 44.0, "on": true}
	layout()


func layout() -> void:
	if not buttons.has("action"):
		return
	var vs := get_viewport_rect().size
	_place("action", Vector2(vs.x - 135, vs.y - 145), 78.0)
	_place("use", Vector2(vs.x - 135, vs.y - 330), 58.0)
	_place("bag", Vector2(vs.x - 66, 66), 42.0)
	_place("pause", Vector2(52, 52), 34.0)
	_place("rotate", Vector2(vs.x / 2.0 + 112, vs.y - 168), 36.0)
	# Many food kinds: squeeze the hotbar between the joystick and the action button.
	var gap := minf(84.0, (vs.x - 640.0) / maxf(1.0, _slots - 1))
	var r := minf(38.0, gap * 0.46)
	var x0 := vs.x / 2.0 - gap * (_slots - 1) / 2.0
	for i in _slots:
		_place("slot%d" % i, Vector2(x0 + gap * i, vs.y - 54), r)
	var bgap := 104.0
	var b0 := vs.x / 2.0 - bgap * (_builds - 1) / 2.0
	for i in _builds:
		_place("build%d" % i, Vector2(b0 + bgap * i, vs.y - 168), 44.0)


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
			elif joy_index < 0 and event.position.x < vs.x * 0.38 and event.position.y > 130.0:
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
	elif e.keycode >= KEY_F1 and e.keycode <= KEY_F3 and e.keycode - KEY_F1 < _builds:
		b = "build%d" % (e.keycode - KEY_F1)
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
	var c := Vector2(170, vs.y - 165) if joy_index < 0 else joy_center
	var knob := c + move * JOY_R
	var a := 0.55 if joy_index >= 0 else 0.3
	draw_circle(c, JOY_R, Color(0.03, 0.1, 0.13, 0.28 * a / 0.3))
	draw_arc(c, JOY_R, 0, TAU, 48, Color(0.95, 0.85, 0.62, a), 4.0, true)
	draw_arc(c, JOY_R - 9, 0, TAU, 48, Color(0.95, 0.85, 0.62, a * 0.35), 2.0, true)
	draw_circle(knob, 38.0, Color(0.95, 0.88, 0.7, a + 0.15))
	draw_arc(knob, 38.0, 0, TAU, 32, Color(0.35, 0.22, 0.1, a + 0.2), 3.0, true)
