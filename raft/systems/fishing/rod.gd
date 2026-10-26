class_name Rod
extends Node3D
## Fishing rod. Hold and release to cast the bobber; wait for a bite — the bobber dives and
## the phone buzzes — then press within the bite window to hook the fish. Too early pulls
## the line out empty; too late lets the fish go and you wait again.
## A hooked fish has to be played: holding the button reels it in but strains the line,
## letting go eases the line while the fish swims off a little. Now and then it jerks —
## the bobber shivers a moment before (time to let go) — hold through a jerk and the line
## may snap; give it slack too long and it gets away.
## Numbers in data/balance.json "fishing" ("fight").

signal caught(id: String)
signal missed(text: String)
signal splashed(pos: Vector3)
signal bit
signal used(n: int)               # a fight ended: the rod wears by n

enum State { IDLE, CHARGE, FLY, WAIT, BITE, FIGHT }

var state := State.IDLE
var power := 0.0
var baited := false               # bait on the hook: bites come sooner, big fish more often
var player: Player
var cfg: Dictionary
var rng := RandomNumberGenerator.new()
var fish := ""                    # the fish on the line while fighting
var progress := 0.0               # 0 = gone, 1 = landed
var tension := 0.0                # 1 = the line snaps
var jerking := false              # the fish fights right now
var warning := false              # it is about to jerk
var holding := false
var _bobber: MeshInstance3D
var _line: MeshInstance3D
var _im: ImmediateMesh
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _fly_t := 0.0
var _fly_dur := 0.6
var _timer := 0.0
var _t := 0.0
var _phase_t := 0.0
var _fight: Dictionary
var _bite_at := Vector3.ZERO


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
			_start_fight()
		State.FIGHT:
			holding = true


func release() -> void:
	if state == State.CHARGE:
		_cast()
	elif state == State.FIGHT:
		holding = false


func cancel() -> void:
	_stop()


func _stop() -> void:
	state = State.IDLE
	visible = false
	baited = false
	holding = false
	jerking = false
	warning = false


## Hooked: the fight begins with the button held.
func _start_fight() -> void:
	fish = _roll()
	var fcfg: Dictionary = cfg["fight"]
	_fight = fcfg[fish] if fcfg.has(fish) else fcfg["fish"]
	progress = float(fcfg["start"])
	tension = 0.15
	holding = true
	jerking = false
	_phase_t = rng.randf_range(float(_fight["calm"][0]), float(_fight["calm"][1])) * 0.6
	_bite_at = _bobber.global_position
	state = State.FIGHT
	Sfx.play("reel", -6.0)


func _end_fight(result: String) -> void:
	var id := fish
	_stop()
	match result:
		"caught":
			used.emit(1)
			caught.emit(id)
		"snap":
			used.emit(int(cfg["fight"]["snap_wear"]))
			Sfx.play("snag", -2.0)
			missed.emit("Леска лопнула! Отпускай, когда рыба дёргает")
		_:
			used.emit(1)
			missed.emit("Рыба сорвалась — не давай ей много слабины")


func _fight_step(delta: float) -> void:
	_phase_t -= delta
	if _phase_t <= 0.0:
		# calm → a short warning → a jerk → calm again
		if warning:
			warning = false
			jerking = true
			_phase_t = rng.randf_range(float(_fight["jerk"][0]), float(_fight["jerk"][1]))
			Input.vibrate_handheld(70)
			Sfx.play("splash", -12.0, 0.2)
		elif jerking:
			jerking = false
			_phase_t = rng.randf_range(float(_fight["calm"][0]), float(_fight["calm"][1]))
		else:
			warning = true
			_phase_t = float(cfg["fight"]["warn"])
			Input.vibrate_handheld(25)
	if holding:
		progress += float(_fight["reel"]) * (float(_fight["jerk_reel"]) if jerking else 1.0) * delta
		tension += float(_fight["jerk_strain" if jerking else "strain"]) * delta
	else:
		progress -= float(_fight["slip"]) * (1.7 if jerking else 1.0) * delta
		tension -= float(_fight["ease"]) * delta
	tension = clampf(tension, 0.0, 1.0)
	if tension >= 1.0:
		_end_fight("snap")
	elif progress >= 1.0:
		_end_fight("caught")
	elif progress <= 0.0:
		_end_fight("escape")
	else:
		# The bobber comes in toward the raft as the fish tires, thrashing while it jerks.
		var near := tip().lerp(_bite_at, 0.25)
		var p := _bite_at.lerp(near, progress)
		p += Vector3(sin(_t * 23.0), 0, cos(_t * 19.0)) * (0.18 if jerking else (0.09 if warning else 0.04))
		p.y = Ocean.height_at(p.x, p.z) + (-0.15 + sin(_t * 31.0) * 0.08 if jerking else -0.05)
		_bobber.global_position = p


## The rod tip in world space, taken from the rod model in the hand.
func tip() -> Vector3:
	return player.held_point(Vector3(0, 0.85, 0))


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
	var big := float(cfg["bait"]["big_mult"]) if baited else 1.0
	var total := 0.0
	for e: Dictionary in table:
		total += float(e["w"]) * (big if e["item"] == "big_fish" else 1.0)
	var r := rng.randf() * total
	for e: Dictionary in table:
		r -= float(e["w"]) * (big if e["item"] == "big_fish" else 1.0)
		if r <= 0.0:
			return e["item"]
	return table[0]["item"]


func _new_wait() -> void:
	_timer = rng.randf_range(float(cfg["bite"][0]), float(cfg["bite"][1]))
	if baited:
		_timer *= float(cfg["bait"]["wait_mult"])
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
				missed.emit("Не успел подсечь! Жди следующую")
				_new_wait()
		State.FIGHT:
			_fight_step(delta)
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
	elif state == State.FIGHT:
		sag *= 0.4 * (1.0 - tension)
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
