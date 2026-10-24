class_name DebrisField
extends Node3D
## Spawns debris ahead of the raft, lets it drift past and removes it behind.

var raft: Raft
var items: Array[Debris] = []
var cfg: Dictionary
var rng := RandomNumberGenerator.new()
var extra_mult := 1.0             # storms
var _timer := 0.0
var _total_w := 0.0


func _ready() -> void:
	cfg = Data.b["debris"]
	rng.randomize()
	for d: Dictionary in Data.debris:
		_total_w += float(d["weight"])


## Fills the sea at the start so it is not empty for the first half-minute.
func prefill() -> void:
	var c := raft.centroid()
	for i in int(cfg["prefill"]):
		var z := c.z - rng.randf_range(4.0, float(cfg["spawn_ahead"]))
		_spawn(z)


func clear_all() -> void:
	for d in items:
		d.queue_free()
	items.clear()


func _pick() -> Dictionary:
	var r := rng.randf() * _total_w
	for d: Dictionary in Data.debris:
		r -= float(d["weight"])
		if r <= 0.0:
			return d
	return Data.debris[0]


func _spawn(z: float) -> void:
	var c := raft.centroid()
	var spread := float(cfg["spread"])
	var x := rng.randf_range(-spread, spread)
	if rng.randf() < float(cfg["near_bias"]):
		x = rng.randf_range(-5.0, 5.0)
	var d := Debris.new()
	add_child(d)
	d.global_position = Vector3(c.x + x, 0.0, z)
	d.setup(_pick(), raft, cfg, rng)
	items.append(d)


func _process(delta: float) -> void:
	var c := raft.centroid()
	_timer -= delta * float(Data.tune["debris"]) * extra_mult
	if _timer <= 0.0:
		_timer = float(cfg["interval"]) + rng.randf_range(-1.0, 1.0) * float(cfg["jitter"])
		if items.size() < int(cfg["max"]):
			_spawn(c.z - float(cfg["spawn_ahead"]))
	for i in range(items.size() - 1, -1, -1):
		var d := items[i]
		if d.hook == null and d.net == null and d.global_position.z > c.z + float(cfg["despawn_behind"]):
			d.queue_free()
			items.remove_at(i)


func take(d: Debris) -> void:
	items.erase(d)
	d.queue_free()


## Nearest free debris within `reach` of `from` and in front of the view.
func nearest(from: Vector3, fwd: Vector3, reach: float) -> Debris:
	var best: Debris = null
	var bd := reach
	for d in items:
		if d.hook or d.net:
			continue
		var v := d.global_position - from
		v.y = 0.0
		var dist := v.length()
		if dist < bd and (dist < 1.0 or v.normalized().dot(fwd) > 0.2):
			bd = dist
			best = d
	return best
