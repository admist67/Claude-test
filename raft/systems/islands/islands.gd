class_name Islands
extends Node3D
## Every few minutes an island comes from ahead and drifts past the raft's side, gone
## behind it, unless the raft is anchored: then it stays where it is. One at a time.
## Numbers in data/balance.json "islands".

signal sighted(island: Island)

var raft: Raft
var cfg: Dictionary
var island: Island
var anchored := false
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
		timer -= delta
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
	isl.build(s, cfg)
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	isl.position = Vector3(c.x + side * (_half_width() + isl.radius * 1.15 + float(cfg["side_gap"])), 0.0, c.z - float(cfg["ahead"]))
	add_child(isl)
	island = isl
	sighted.emit(isl)


func to_dict() -> Dictionary:
	return {"timer": timer, "island": island.to_dict() if island else {}}


func from_dict(d: Dictionary) -> void:
	reset(float(d.get("timer", cfg["first"])))
	var id: Dictionary = d.get("island", {})
	if id.has("seed"):
		var isl := Island.new()
		isl.build(int(id["seed"]), cfg)
		add_child(isl)
		isl.load_state(id)
		island = isl
