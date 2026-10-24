class_name Rod
extends Node3D
## Fishing rod. Hold and release to cast the bobber; wait for a bite — the bobber dives and
## the phone buzzes — then press within the bite window to hook the fish. Too early pulls
## the line out empty; too late lets the fish go and you wait again.

signal caught(id: String)
signal missed(text: String)
signal splashed(pos: Vector3)
signal bit

enum State { IDLE, CHARGE, FLY, WAIT, BITE }

var state := State.IDLE
var power := 0.0
var player: Player
var cfg: Dictionary
var rng := RandomNumberGenerator.new()
var _bobber: MeshInstance3D
var _line: MeshInstance3D
var _im: ImmediateMesh
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _fly_t := 0.0
var _fly_dur := 0.6
var _timer := 0.0
var _t := 0.0


func _ready() -> void:
	cfg = Data.b["fishing"]
	rng.randomize()
	top_level = true
	_bobber = MeshInstance3D.new()
	_bobber.mesh = Looks.mesh("bobber")
	_bobber.top_level = true
	add_child(_bobber)
	_im = ImmediateMesh.new()
	_line = MeshInstance3D.new()
	_line.mesh = _im
	_line.top_level = true
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(0.95, 0.95, 0.9, 0.9)
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_line.material_override = lm
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)
	visible = false


func busy() -> bool:
	return state != State.IDLE


func press() -> void:
	match state:
		State.IDLE:
			state = State.CHARGE
			power = 0.0
		State.WAIT:
			missed.emit("Рано! Жди, пока поплавок нырнёт")
			_stop()
		State.BITE:
			var id := _roll()
			_stop()
			caught.emit(id)


func release() -> void:
	if state == State.CHARGE:
		_cast()


func cancel() -> void:
	_stop()


func _stop() -> void:
	state = State.IDLE
	visible = false


## The rod tip in world space: ahead of and above the hand.
func tip() -> Vector3:
	var b := player.cam.global_basis
	return player.hand.global_position + b.y * 0.26 + b.x * 0.25 + -b.z * 0.42


func _cast() -> void:
	var dist := lerpf(float(cfg["min_dist"]), float(cfg["max_dist"]), power)
	_from = tip()
	_to = _from + player.flat_forward() * dist
	_to.y = Ocean.height_at(_to.x, _to.z)
	_fly_t = 0.0
	_fly_dur = 0.35 + dist * 0.035
	state = State.FLY
	visible = true
	player.swing()
	Sfx.play("throw", -8.0, 0.15)


func _roll() -> String:
	var table: Array = cfg["catch"]
	var total := 0.0
	for e: Dictionary in table:
		total += float(e["w"])
	var r := rng.randf() * total
	for e: Dictionary in table:
		r -= float(e["w"])
		if r <= 0.0:
			return e["item"]
	return table[0]["item"]


func _new_wait() -> void:
	_timer = rng.randf_range(float(cfg["bite"][0]), float(cfg["bite"][1]))
	state = State.WAIT


func _process(delta: float) -> void:
	_t += delta
	match state:
		State.CHARGE:
			power = minf(1.0, power + delta / float(cfg["charge_time"]))
		State.FLY:
			_fly_t += delta
			var u := minf(1.0, _fly_t / _fly_dur)
			_to.y = Ocean.height_at(_to.x, _to.z)
			_bobber.global_position = _from.lerp(_to, u) + Vector3(0, sin(PI * u) * 1.2, 0)
			if u >= 1.0:
				splashed.emit(_to)
				_new_wait()
		State.WAIT:
			_float(0.0)
			_timer -= delta
			if _timer <= 0.0:
				state = State.BITE
				_timer = float(cfg["window"])
				Sfx.play("splash", -10.0, 0.2)
				Input.vibrate_handheld(180)
				bit.emit()
		State.BITE:
			_float(-0.12 + sin(_t * 30.0) * 0.03)
			_timer -= delta
			if _timer <= 0.0:
				missed.emit("Сорвалась! Жди следующую")
				_new_wait()
	if visible:
		_draw_line()


func _float(dip: float) -> void:
	var p := _bobber.global_position
	p.y = Ocean.height_at(p.x, p.z) + 0.03 + dip
	_bobber.global_position = p


func _draw_line() -> void:
	_im.clear_surfaces()
	var a := tip()
	var b := _bobber.global_position + Vector3(0, 0.1, 0)
	var sag := 0.0 if state == State.FLY else clampf(a.distance_to(b) * 0.08, 0.0, 0.7)
	if state == State.BITE:
		sag *= 0.2
	var eye := player.cam.global_position
	var pts: Array[Vector3] = []
	for i in 11:
		var u := i / 10.0
		pts.append(a.lerp(b, u) - Vector3(0, sin(PI * u) * sag, 0))
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 10:
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var side := (p1 - p0).cross(eye - p0).normalized() * 0.006
		for v: Vector3 in [p0 - side, p0 + side, p1 + side, p0 - side, p1 + side, p1 - side]:
			_im.surface_add_vertex(v)
	_im.surface_end()
