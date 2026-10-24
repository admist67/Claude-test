class_name TouchScroll
extends ScrollContainer
## A list you scroll by dragging anywhere on it, cards and buttons included, with a little
## glide after the finger lets go. Nothing inside takes the pointer: a short tap goes to
## the target registered under the finger.

const DEAD := 12.0               # px the finger moves before a tap becomes a drag

var _taps: Array = []            # [Control, Callable]
var _from := Vector2.ZERO
var _start := 0.0
var _down := false
var _drag := false
var _vel := 0.0
var _last_y := 0.0
var _last_t := 0


func _ready() -> void:
	horizontal_scroll_mode = SCROLL_MODE_DISABLED
	mouse_filter = MOUSE_FILTER_STOP


## Clears the tap targets (before the list is rebuilt).
func clear_taps() -> void:
	_taps.clear()


## `fn` runs when `c` is tapped (not dragged). Disabled buttons ignore taps.
func on_tap(c: Control, fn: Callable) -> void:
	_taps.append([c, fn])


## After filling the list: everything inside lets the pointer through to the scroller.
func settle(root: Node) -> void:
	for n in root.get_children():
		if n is Control:
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		settle(n)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if e.pressed:
			_down = true
			_drag = false
			_vel = 0.0
			_from = e.global_position
			_start = scroll_vertical
			_last_y = e.global_position.y
			_last_t = Time.get_ticks_msec()
		elif _down:
			_down = false
			if Time.get_ticks_msec() - _last_t > 90:
				_vel = 0.0              # the finger stopped before letting go: no glide
			if not _drag:
				_tap(e.global_position)
	elif e is InputEventMouseMotion and _down:
		accept_event()
		if not _drag and absf(e.global_position.y - _from.y) > DEAD:
			_drag = true
		if _drag:
			scroll_vertical = int(_start - (e.global_position.y - _from.y))
			var now := Time.get_ticks_msec()
			var dt := maxf(0.001, (now - _last_t) / 1000.0)
			_vel = lerpf(_vel, -(e.global_position.y - _last_y) / dt, 0.5)
			_last_y = e.global_position.y
			_last_t = now


func _tap(at: Vector2) -> void:
	for t: Array in _taps:
		var c: Control = t[0]
		if not is_instance_valid(c) or not c.is_visible_in_tree() or not c.get_global_rect().has_point(at):
			continue
		if c is BaseButton and c.disabled:
			return
		Sfx.play("click", -6.0)
		t[1].call()
		return


func _process(delta: float) -> void:
	if _down or absf(_vel) < 20.0:
		_vel = 0.0
		return
	scroll_vertical = int(scroll_vertical + _vel * delta)
	_vel = move_toward(_vel, 0.0, absf(_vel) * 4.0 * delta + 200.0 * delta)
