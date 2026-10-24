class_name Storm
extends Node
## Storms: every so often the sky darkens, rain pours, lightning flashes and the waves
## grow; afterwards the sea brings more debris for a while. Numbers in balance "storm".

signal warned
signal started
signal ended

enum State { CALM, WARN, STORM }

var state := State.CALM
var k := 0.0                    # intensity 0..1 (waves, sky, rain)
var flash := 0.0                # lightning, 1 at the strike, fades fast
var timer := 0.0                # time left in the current state
var after := 0.0                # bonus-debris time after a storm
var cam: Camera3D
var cfg: Dictionary
var rng := RandomNumberGenerator.new()
var _elapsed := 0.0
var _bolt := 0.0
var _thunder := -1.0
var _rain: CPUParticles3D
var _rain_snd: AudioStreamPlayer


func _ready() -> void:
	cfg = Data.b["storm"]
	rng.randomize()
	timer = float(cfg["first"])
	_rain = CPUParticles3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.012, 0.55, 0.012)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.85, 0.9, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat
	_rain.mesh = m
	_rain.amount = 450
	_rain.lifetime = 0.9
	_rain.local_coords = false
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(11, 0.5, 11)
	_rain.direction = Vector3(0.15, -1, 0.1)
	_rain.spread = 4.0
	_rain.initial_velocity_min = 13.0
	_rain.initial_velocity_max = 17.0
	_rain.gravity = Vector3(0, -9.8, 0)
	_rain.emitting = false
	add_child(_rain)
	_rain_snd = AudioStreamPlayer.new()
	if ResourceLoader.exists("res://assets/sfx/rain.ogg"):
		var st: AudioStreamOggVorbis = load("res://assets/sfx/rain.ogg")
		st.loop = true
		_rain_snd.stream = st
	add_child(_rain_snd)


func active() -> bool:
	return state == State.STORM


## Extra debris during and right after a storm.
func debris_mult() -> float:
	var m := float(cfg["debris_mult"])
	return lerpf(1.0, m, maxf(k, 1.0 if after > 0.0 else 0.0))


func _process(delta: float) -> void:
	timer -= delta
	after = maxf(0.0, after - delta)
	match state:
		State.CALM:
			k = move_toward(k, 0.0, delta / float(cfg["ramp"]))
			if timer <= float(cfg["warn"]):
				state = State.WARN
				warned.emit()
		State.WARN:
			k = 0.25 * clampf(1.0 - timer / float(cfg["warn"]), 0.0, 1.0)
			if timer <= 0.0:
				state = State.STORM
				timer = float(cfg["duration"])
				_elapsed = 0.0
				_bolt = rng.randf_range(2.0, 5.0)
				started.emit()
		State.STORM:
			_elapsed += delta
			var ramp := float(cfg["ramp"])
			k = clampf(0.25 + 0.75 * minf(_elapsed / ramp, timer / ramp), 0.0, 1.0)
			_bolt -= delta
			if _bolt <= 0.0 and k > 0.6:
				_bolt = rng.randf_range(float(cfg["lightning"][0]), float(cfg["lightning"][1]))
				flash = 1.0
				_thunder = rng.randf_range(0.3, 1.2)
			if timer <= 0.0:
				state = State.CALM
				timer = rng.randf_range(float(cfg["interval"][0]), float(cfg["interval"][1]))
				after = float(cfg["after"])
				ended.emit()
	if _thunder > 0.0:
		_thunder -= delta
		if _thunder <= 0.0:
			Sfx.play("thunder", -2.0, 0.15)
	flash = maxf(0.0, flash - delta * 3.0)
	Ocean.amp_mult = lerpf(1.0, float(cfg["waves"]), k)
	_rain.emitting = k > 0.35
	if cam:
		_rain.global_position = cam.global_position + Vector3(0, 7, 0)
	if _rain_snd.stream:
		if k > 0.1 and not _rain_snd.playing and not Sfx.muted:
			_rain_snd.play()
		elif (k <= 0.05 or Sfx.muted) and _rain_snd.playing:
			_rain_snd.stop()
		_rain_snd.volume_db = linear_to_db(maxf(0.001, k)) - 4.0


## Calm again with `left` seconds to the next storm (after loading a save).
func restore(left: float) -> void:
	state = State.CALM
	k = 0.0
	timer = maxf(float(cfg["warn"]) + 5.0, left)
