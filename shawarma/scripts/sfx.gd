extends Node
## Autoload "Sfx": one-shot sounds from a player pool, the music loop, the grill sizzle and vibration.

const NAMES := ["tap", "lavash", "chop", "plop", "roll", "clank", "perfect", "cash", "angry",
	"bell", "burnt", "error", "ui", "jingle"]

var streams := {}
var pool: Array[AudioStreamPlayer] = []
var music: AudioStreamPlayer
var sizzle: AudioStreamPlayer
var enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMES:
		streams[n] = load("res://assets/sfx/%s.wav" % n)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	music = AudioStreamPlayer.new()
	var m: AudioStreamOggVorbis = load("res://assets/music/night_loop.ogg")
	m.loop = true
	music.stream = m
	music.volume_db = -9.0
	add_child(music)
	sizzle = AudioStreamPlayer.new()
	var s: AudioStreamWAV = load("res://assets/sfx/sizzle.wav")
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate)
	sizzle.stream = s
	add_child(sizzle)


func play(sound: String, jitter := 0.07, vol_db := 0.0) -> void:
	if not enabled:
		return
	for p in pool:
		if not p.playing:
			p.stream = streams[sound]
			p.pitch_scale = 1.0 + randf_range(-jitter, jitter)
			p.volume_db = vol_db
			p.play()
			return


## level 0..1 — how many rolls are on the grill.
func set_sizzle(level: float) -> void:
	if level <= 0.01 or not enabled:
		if sizzle.playing:
			sizzle.stop()
		return
	if not sizzle.playing:
		sizzle.play()
	sizzle.volume_db = linear_to_db(level) - 12.0


func start_music() -> void:
	if enabled and not music.playing:
		music.play()


func set_enabled(on: bool) -> void:
	enabled = on
	if on:
		music.play()
	else:
		music.stop()
		sizzle.stop()


func buzz(ms := 25) -> void:
	if enabled:
		Input.vibrate_handheld(ms)
