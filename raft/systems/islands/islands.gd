class_name Islands
extends Node3D
## Every few minutes an island comes from ahead and drifts past the raft's side, gone
## behind it, unless the raft is anchored: then it stays where it is. One at a time.
## Numbers in data/balance.json "islands".

signal sighted(island: Island)
signal pinched                      # a crab got the player
signal crab_died

var raft: Raft
var player: Player
var cfg: Dictionary
var island: Island
var anchored := false
var pace := 1.0                     # the sail is up: the next island comes sooner
var want_chest := false             # the chest goal is on: the next island has one for sure
var active := false                 # only while playing: no islands go by in the menu
var timer := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	cfg = Data.b["islands"]
	rng.randomize()


## No island; the next one comes after `delay` seconds.
func reset(delay: float) -> void:
	clear()
	timer = delay


func clear() -> void:
	if island:
		island.queue_free()
		island = null


## The raft's center on the water (world).
func _center() -> Vector3:
	return raft.global_transform * raft.centroid()


## An island close enough to swim to (or just passing alongside).
func near() -> bool:
	if island == null:
		return false
	var d := Vector2(island.position.x, island.position.z).distance_to(Vector2(_center().x, _center().z))
	return d < island.radius + _half_width() + float(cfg["near"])


func _half_width() -> float:
	var w := 0.0
	var c := raft.centroid()
	for t: Vector2i in raft.tiles:
		w = maxf(w, absf(raft.cell_center(t).x - c.x))
	return w + raft.tile_size / 2.0


func _physics_process(delta: float) -> void:
	if not active:
		return
	if island == null:
		timer -= delta * pace
		if timer <= 0.0:
			_spawn(rng.randi())
		return
	if not anchored:
		island.position.z += float(cfg["speed"]) * delta
	if island.position.z - _center().z > float(cfg["behind"]) + island.radius:
		clear()
		timer = rng.randf_range(float(cfg["interval"][0]), float(cfg["interval"][1]))


func _spawn(s: int) -> void:
	var c := _center()
	var isl := Island.new()
	isl.build(s, cfg, want_chest)
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	isl.position = Vector3(c.x + side * (_half_width() + isl.radius * 1.15 + float(cfg["side_gap"])), 0.0, c.z - float(cfg["ahead"]))
	add_child(isl)
	island = isl
	_wire(isl)
	sighted.emit(isl)


## The island's crabs know the player and report bites and deaths.
func _wire(isl: Island) -> void:
	for c in isl.crabs:
		c.player = player
		c.pinched.connect(func() -> void: pinched.emit())
		c.died.connect(func(_c: Crab) -> void: crab_died.emit())


## A spear thrust: hits a crab in front if there is one.
func hit_crab(eye: Vector3, fwd: Vector3, power: int, reach: float) -> bool:
	if island == null:
		return false
	for c in island.crabs:
		if c.try_hit(eye, fwd, power, reach):
			return true
	return false


## A live crab within `d` meters of a world point.
func crab_near(at: Vector3, d: float) -> bool:
	if island == null:
		return false
	for c in island.crabs:
		if not c.dead and c.global_position.distance_to(at) < d:
			return true
	return false


func to_dict() -> Dictionary:
	return {"timer": timer, "island": island.to_dict() if island else {}}


func from_dict(d: Dictionary) -> void:
	reset(float(d.get("timer", cfg["first"])))
	var id: Dictionary = d.get("island", {})
	if id.has("seed"):
		var isl := Island.new()
		isl.build(int(id["seed"]), cfg, bool(id.get("chest", false)))
		add_child(isl)
		isl.load_state(id)
		island = isl
		_wire(isl)
