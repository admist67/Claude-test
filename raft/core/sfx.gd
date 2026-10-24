extends Node
## Autoload "Sfx": one-shot sounds from assets/sfx and the looping ocean ambience.

const NAMES := ["throw", "splash", "snag", "pop", "reel", "hammer", "eat", "drink", "craft", "click", "hurt", "goal", "build_fail"]
const POOL := 8

var muted := false
var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _amb: AudioStreamPlayer


func _ready() -> void:
	for n: String in NAMES:
		var p := "res://assets/sfx/%s.wav" % n
		if ResourceLoader.exists(p):
			_streams[n] = load(p)
	for i in POOL:
		var a := AudioStreamPlayer.new()
		add_child(a)
		_pool.append(a)
	_amb = AudioStreamPlayer.new()
	if ResourceLoader.exists("res://assets/sfx/ocean.ogg"):
		var s: AudioStreamOggVorbis = load("res://assets/sfx/ocean.ogg")
		s.loop = true
		_amb.stream = s
		_amb.volume_db = -8.0
	add_child(_amb)


func play(n: String, db := 0.0, pitch_var := 0.08) -> void:
	if muted or not _streams.has(n):
		return
	var a := _pool[_next]
	_next = (_next + 1) % POOL
	a.stream = _streams[n]
	a.volume_db = db
	a.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	a.play()


func ambience(on: bool) -> void:
	if on and not muted and _amb.stream and not _amb.playing:
		_amb.play()
	elif not on:
		_amb.stop()


func set_muted(m: bool) -> void:
	muted = m
	if m:
		_amb.stop()
	else:
		ambience(true)
