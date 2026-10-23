extends CanvasLayer
## Multi-touch controls: a floating joystick on the left part of the screen, look-drag
## anywhere else, taps, and vertical swipes that start on a gesture object (spit / board).

signal tapped(pos: Vector2)
signal swiped(pos: Vector2, down: bool)
signal looked(rel: Vector2)

const JOY_R := 90.0
const TAP_SLOP := 14.0
const SWIPE_LEN := 40.0

var move := Vector2.ZERO
var classify: Callable          # func(pos) -> bool: does a swipe here mean a gesture?
var enabled := false
var joy_index := -1
var joy_center := Vector2.ZERO
var joy_pos := Vector2.ZERO
var pointers := {}              # index -> {"start", "last", "mode", "gesture"}
var pad: Node2D


class Pad extends Node2D:
	var owner_touch

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var t = owner_touch
		if not t.enabled:
			return
		var vs := get_viewport_rect().size
		if t.joy_index < 0:
			var c := Vector2(150, vs.y - 150)
			draw_circle(c, 90.0, Color(1, 1, 1, 0.08))
			draw_arc(c, 90.0, 0, TAU, 40, Color(1, 1, 1, 0.25), 4.0, true)
			draw_circle(c, 38.0, Color(1, 1, 1, 0.2))
			return
		draw_circle(t.joy_center, 90.0, Color(1, 1, 1, 0.12))
		draw_arc(t.joy_center, 90.0, 0, TAU, 40, Color(1, 1, 1, 0.45), 4.0, true)
		DU.circle(self, t.joy_center + t.move * 90.0, 40.0, Color(1, 1, 1, 0.75), 4.0)


func _ready() -> void:
	layer = 5
	pad = Pad.new()
	pad.owner_touch = self
	add_child(pad)


func reset() -> void:
	joy_index = -1
	move = Vector2.ZERO
	pointers.clear()


func _input(event: InputEvent) -> void:
	if not enabled or get_tree().paused:
		return
	var vs := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.y < 74.0:
				return   # top bar
			if joy_index < 0 and event.position.x < vs.x * 0.36:
				joy_index = event.index
				joy_center = event.position
				move = Vector2.ZERO
			else:
				var g: bool = classify.is_valid() and classify.call(event.position)
				pointers[event.index] = {"start": event.position, "last": event.position, "mode": "pending", "gesture": g}
		else:
			if event.index == joy_index:
				joy_index = -1
				move = Vector2.ZERO
			elif pointers.has(event.index):
				var p: Dictionary = pointers[event.index]
				if p["mode"] == "pending":
					tapped.emit(event.position)
				pointers.erase(event.index)
	elif event is InputEventScreenDrag:
		if event.index == joy_index:
			move = ((event.position - joy_center) / JOY_R).limit_length(1.0)
		elif pointers.has(event.index):
			var p: Dictionary = pointers[event.index]
			var d: Vector2 = event.position - p["start"]
			if p["mode"] == "pending" and d.length() > TAP_SLOP:
				p["mode"] = "gesture" if p["gesture"] and absf(d.y) > absf(d.x) else "look"
			if p["mode"] == "look":
				looked.emit(event.position - p["last"])
			elif p["mode"] == "gesture" and absf(d.y) > SWIPE_LEN:
				swiped.emit(p["start"], d.y > 0.0)
				p["mode"] = "done"
			p["last"] = event.position
