class_name Gulls
extends Node3D
## Seagulls after the crops. Now and then one flies in to a planter where something grows,
## lands on it and pecks; when it has pecked long enough the seedling (or the ripe fruit)
## is gone. A spear hit scares it off; a scarecrow near a planter keeps them away from it.
## One gull at a time. Numbers in data/balance.json "gulls".

signal coming(st: Station)
signal ate(st: Station)
signal scared

var raft: Raft
var active := false                 # only while playing
var cfg: Dictionary
var timer := 0.0
var gull: Gull
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	cfg = Data.b["gulls"]
	rng.randomize()
	timer = float(cfg["first"])


## Is this planter guarded by a scarecrow?
func guarded(st: Station) -> bool:
	for p: Part in raft.parts.decor.values():
		if p.kind == "scarecrow" and p.global_position.distance_to(st.global_position) < float(cfg["protect"]):
			return true
	return false


func _targets() -> Array[Station]:
	var out: Array[Station] = []
	for st: Station in raft.stations.values():
		if st.has_crop() and not guarded(st):
			out.append(st)
	return out


func _process(delta: float) -> void:
	if gull == null:
		if not active:
			return
		timer -= delta
		if timer <= 0.0:
			timer = rng.randf_range(float(cfg["interval"][0]), float(cfg["interval"][1]))
			var ts := _targets()
			if not ts.is_empty():
				_spawn(ts[rng.randi() % ts.size()])
		return
	if gull.gone:
		gull.queue_free()
		gull = null
		return
	match gull.state:
		Gull.State.FLY, Gull.State.PECK:
			# Harvested meanwhile, or a scarecrow went up: never mind.
			if not is_instance_valid(gull.target) or not gull.target.has_crop() or guarded(gull.target):
				gull.flee()
			elif gull.state == Gull.State.PECK and gull.peck_t >= float(cfg["eat_time"]):
				gull.target.pecked()
				ate.emit(gull.target)
				Sfx.play("gull", -4.0, 0.15)
				gull.flee()


func _spawn(st: Station) -> void:
	gull = Gull.new()
	gull.target = st
	gull.speed = float(cfg["speed"])
	add_child(gull)
	var a := rng.randf() * TAU
	gull.global_position = st.global_position + Vector3(cos(a), 0, sin(a)) * float(cfg["from"]) + Vector3(0, 9.0, 0)
	Sfx.play("gull", -6.0, 0.15)
	coming.emit(st)


## A spear thrust from `eye` along `fwd` (a longer spear reaches `extra` further): hits
## the gull if it is close and in front.
func hit(eye: Vector3, fwd: Vector3, extra: float) -> bool:
	if gull == null or gull.state == Gull.State.FLEE:
		return false
	var v := gull.global_position + Vector3(0, 0.15, 0) - eye
	if v.length() > float(cfg["reach"]) + extra or v.normalized().dot(fwd) < 0.82:
		return false
	gull.flee()
	Sfx.play("gull", -2.0, 0.25)
	Fx.burst(self, gull.global_position + Vector3(0, 0.2, 0), Color("#f4f4f2"), 12)
	scared.emit()
	return true


## A gull within `d` meters of a point, not already flying off.
func near(at: Vector3, d: float) -> bool:
	return gull != null and gull.state != Gull.State.FLEE and gull.global_position.distance_to(at) < d
