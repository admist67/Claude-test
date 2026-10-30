class_name Debris
extends Node3D
## One floating thing. Drifts with the current (+Z), rides the waves, slides around the raft,
## or hangs on the hook while it is reeled in.

var def: Dictionary
var id := ""
var raft: Raft
var hook: Node3D               # set while caught
var hook_offset := Vector3.ZERO
var net: Part                  # set while held in a collection net
var net_offset := Vector3.ZERO
var drift := 1.4
var sink := 0.06
var spin := 0.0
var highlight := false
var _t := 0.0


func setup(d: Dictionary, r: Raft, cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	def = d
	id = d["id"]
	raft = r
	drift = float(cfg["drift_speed"]) * rng.randf_range(0.85, 1.15)
	sink = float(cfg["sink"]) - float(d.get("lift", 0.0))
	spin = rng.randf_range(-0.3, 0.3)
	rotation.y = rng.randf() * TAU
	_t = rng.randf() * 10.0
	var look := Looks.debris(id)
	look.scale = Vector3.ONE * 1.35
	add_child(look)
	# Floating things would cast shadows only on the sea, which takes no sun shadows.
	for n in look.find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Rolls the loot table: [[item, n], ...].
func roll_loot(rng: RandomNumberGenerator) -> Array:
	return Loot.roll(def, rng)


func _process(delta: float) -> void:
	_t += delta
	var p := global_position
	if hook:
		var to := hook.global_position + hook_offset
		p = p.lerp(Vector3(to.x, p.y, to.z), 1.0 - exp(-8.0 * delta))
	elif net:
		var at := raft.to_global(net.position + Basis(Vector3.UP, net.rotation.y) * net_offset)
		p = p.lerp(Vector3(at.x, p.y, at.z), 1.0 - exp(-4.0 * delta))
	else:
		p.z += drift * delta
		var local := raft.to_local(Vector3(p.x, raft.global_position.y, p.z + 0.35))
		if raft.on_raft(local):
			# Bumped into the raft: slide along its front edge.
			var side := signf(local.x - raft.centroid().x)
			p = global_position
			p.x += (side if side != 0.0 else 1.0) * drift * 1.2 * delta
		global_position = p
		raft.parts.try_net(self)
	p.y = Ocean.height_at(p.x, p.z) - sink + (0.04 * sin(_t * 6.0) if highlight else 0.0)
	global_position = p
	rotation.y += spin * delta
	var sx := Ocean.height_at(p.x + 0.4, p.z) - Ocean.height_at(p.x - 0.4, p.z)
	var sz := Ocean.height_at(p.x, p.z + 0.4) - Ocean.height_at(p.x, p.z - 0.4)
	rotation.x = -sz * 0.9
	rotation.z = sx * 0.9
