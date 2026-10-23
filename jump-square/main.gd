extends Node2D
## Jump Square: tap (or press Space / click) to jump over the blocks.

enum State { READY, PLAYING, OVER }

const GROUND_OFFSET := 140.0   # ground distance from the bottom of the screen
const PLAYER_SIZE := 64.0
const PLAYER_X := 220.0
const GRAVITY := 3200.0
const JUMP_VELOCITY := -1250.0
const START_SPEED := 520.0
const MAX_SPEED := 1100.0
const SAVE_PATH := "user://best.save"

const COLOR_PLAYER := Color("#ffcc4d")
const COLOR_BLOCK := Color("#ff5c7a")
const COLOR_GROUND := Color("#3a3f5c")
const COLOR_TEXT := Color("#f2f4ff")

var state := State.READY
var player_y := 0.0
var player_vy := 0.0
var player_angle := 0.0
var speed := START_SPEED
var score := 0.0
var best := 0
var obstacles: Array[Rect2] = []
var spawn_timer := 0.0
var ground_scroll := 0.0
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
	best = _load_best()
	_reset()


func _ground_y() -> float:
	return get_viewport_rect().size.y - GROUND_OFFSET


func _reset() -> void:
	player_y = _ground_y() - PLAYER_SIZE
	player_vy = 0.0
	player_angle = 0.0
	speed = START_SPEED
	score = 0.0
	obstacles.clear()
	spawn_timer = 1.0


func _unhandled_input(event: InputEvent) -> void:
	# Touches on Android arrive as emulated mouse clicks, so this covers phones too.
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo \
			and event.keycode in [KEY_SPACE, KEY_UP, KEY_W])
	if not pressed:
		return
	match state:
		State.READY:
			state = State.PLAYING
			_jump()
		State.PLAYING:
			_jump()
		State.OVER:
			_reset()
			state = State.READY


func _jump() -> void:
	if _on_ground():
		player_vy = JUMP_VELOCITY


func _on_ground() -> bool:
	return player_y >= _ground_y() - PLAYER_SIZE - 0.5


func _process(delta: float) -> void:
	var ground := _ground_y()
	if state == State.PLAYING:
		speed = min(MAX_SPEED, speed + 12.0 * delta)
		score += speed * delta / 100.0

		player_vy += GRAVITY * delta
		player_y += player_vy * delta
		if player_y > ground - PLAYER_SIZE:
			player_y = ground - PLAYER_SIZE
			player_vy = 0.0
			player_angle = snappedf(player_angle, PI / 2.0)
		else:
			player_angle += 6.0 * delta

		var moved: Array[Rect2] = []
		for r in obstacles:
			r.position.x -= speed * delta
			if r.end.x > -10.0:
				moved.append(r)
		obstacles = moved

		spawn_timer -= delta
		if spawn_timer <= 0.0:
			_spawn_obstacle()
			spawn_timer = randf_range(0.9, 1.8) * START_SPEED / speed + 0.35

		var player_rect := Rect2(PLAYER_X + 6.0, player_y + 6.0, PLAYER_SIZE - 12.0, PLAYER_SIZE - 12.0)
		for r in obstacles:
			if player_rect.intersects(r):
				_game_over()
				break

	if state != State.OVER:
		ground_scroll = fmod(ground_scroll + (speed if state == State.PLAYING else 120.0) * delta, 80.0)
	queue_redraw()


func _spawn_obstacle() -> void:
	var w := randf_range(40.0, 70.0)
	var h := randf_range(50.0, 110.0)
	var x := get_viewport_rect().size.x + 20.0
	obstacles.append(Rect2(x, _ground_y() - h, w, h))


func _game_over() -> void:
	state = State.OVER
	if int(score) > best:
		best = int(score)
		_save_best()


func _draw() -> void:
	var size := get_viewport_rect().size
	var ground := _ground_y()

	draw_rect(Rect2(0, ground, size.x, size.y - ground), COLOR_GROUND)
	var x := -ground_scroll
	while x < size.x:
		draw_rect(Rect2(x, ground + 24.0, 40.0, 6.0), COLOR_GROUND.lightened(0.2))
		x += 80.0

	for r in obstacles:
		draw_rect(r, COLOR_BLOCK)

	var center := Vector2(PLAYER_X + PLAYER_SIZE / 2.0, player_y + PLAYER_SIZE / 2.0)
	draw_set_transform(center, player_angle)
	draw_rect(Rect2(-PLAYER_SIZE / 2.0, -PLAYER_SIZE / 2.0, PLAYER_SIZE, PLAYER_SIZE), COLOR_PLAYER)
	draw_rect(Rect2(8.0, -16.0, 10.0, 10.0), Color.BLACK)
	draw_set_transform(Vector2.ZERO)

	_text("%d" % int(score), Vector2(0, 80), 56, size.x)
	_text("Рекорд: %d" % best, Vector2(0, 130), 28, size.x, COLOR_TEXT.darkened(0.3))
	match state:
		State.READY:
			_text("Нажми, чтобы прыгнуть", Vector2(0, size.y * 0.42), 44, size.x)
		State.OVER:
			_text("Игра окончена", Vector2(0, size.y * 0.38), 64, size.x, COLOR_BLOCK)
			_text("Нажми, чтобы начать заново", Vector2(0, size.y * 0.38 + 70.0), 36, size.x)


func _text(s: String, pos: Vector2, font_size: int, width: float, color := COLOR_TEXT) -> void:
	draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)


func _load_best() -> int:
	if not FileAccess.file_exists(SAVE_PATH):
		return 0
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	return f.get_32() if f else 0


func _save_best() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_32(best)
