class_name Hook
extends Node3D
## The plastic hook on a rope. Hold to charge, release to throw; hold again to reel in.
## Debris it touches in the water hangs on and comes back with it.

signal splashed(pos: Vector3)
signal delivered(caught: Array)

enum State { IDLE, CHARGE, FLY, WATER }

var state := State.IDLE
var power := 0.0
var reeling := false
var caught: Array[Debris] = []
var player: Player
var field: DebrisField
var cfg: Dictionary
var _head: Node3D
var _rope: MeshInstance3D
var _im: ImmediateMesh
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _fly_t := 0.0
var _fly_dur := 1.0
var _arc := 1.0


func _ready() -> void:
	cfg = Data.b["hook"]
	top_level = true
	var hm := MeshInstance3D.new()
	hm.mesh = Looks.mesh("hook_head")
	_head = hm
	_head.scale = Vector3.ONE * 1.5
	add_child(_head)
	_im = ImmediateMesh.new()
	_rope = MeshInstance3D.new()
	_rope.mesh = _im
	_rope.top_level = true
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color("#e8d6a8")
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rope.material_override = rm
	_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rope)
	visible = false


func busy() -> bool:
	return state != State.IDLE


func press() -> void:
	match state:
		State.IDLE:
			state = State.CHARGE
			power = 0.0
		State.WATER:
			reeling = true


func release() -> void:
	match state:
		State.CHARGE:
			_throw()
		State.WATER:
			reeling = false


## Pulls the hook back at once (tool switched, death). Caught debris falls back into the sea.
func cancel() -> void:
	for d in caught:
		d.hook = null
	caught.clear()
	state = State.IDLE
	reeling = false
	visible = false
	if player:
		player.set_hand_visible(true)


func _throw() -> void:
	var p := power
	var dist := lerpf(float(cfg["min_dist"]), float(cfg["max_dist"]) * float(Data.tune["hook"]), p)
	_from = player.hand_tip()
	_to = _from + player.flat_forward() * dist
	_to.y = Ocean.height_at(_to.x, _to.z)
	_fly_t = 0.0
	_fly_dur = float(cfg["flight_base"]) + float(cfg["flight_per_m"]) * dist
	_arc = 0.8 + dist * 0.18
	state = State.FLY
	visible = true
	global_position = _from
	player.set_hand_visible(false)
	player.swing()
	Sfx.play("throw", -4.0)


func _process(delta: float) -> void:
	match state:
		State.CHARGE:
			power = minf(1.0, power + delta / float(cfg["charge_time"]))
		State.FLY:
			_fly_t += delta
			var u := minf(1.0, _fly_t / _fly_dur)
			_to.y = Ocean.height_at(_to.x, _to.z)
			global_position = _from.lerp(_to, u) + Vector3(0, sin(PI * u) * _arc, 0)
			_head.rotation.x = lerpf(-1.2, 0.0, u)
			if u >= 1.0:
				state = State.WATER
				splashed.emit(global_position)
		State.WATER:
			_in_water(delta)
	if visible:
		_draw_rope()


func _in_water(delta: float) -> void:
	var p := global_position
	if reeling:
		var target := player.hand_tip()
		var v := Vector3(target.x - p.x, 0, target.z - p.z)
		var d := v.length()
		if d < float(cfg["return_dist"]):
			_deliver()
			return
		p += v / d * minf(d, float(cfg["reel_speed"]) * delta)
	p.y = Ocean.height_at(p.x, p.z) + 0.05
	global_position = p
	_head.rotation.x = sin(Ocean.time * 2.0) * 0.2
	if caught.size() < int(cfg["max_items"]):
		for d in field.items:
			if d.hook == null and Vector2(d.global_position.x - p.x, d.global_position.z - p.z).length() < float(cfg["catch_radius"]):
				d.hook = self
				d.hook_offset = Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
				caught.append(d)
				Sfx.play("snag", -6.0, 0.15)
				if caught.size() >= int(cfg["max_items"]):
					break
	# Drifted out of reach (the raft can't move away, but just in case): pull back.
	if Vector2(p.x - player.global_position.x, p.z - player.global_position.z).length() > float(cfg["max_dist"]) * 1.6:
		reeling = true


func _deliver() -> void:
	var got: Array = caught.duplicate()
	caught.clear()
	for d: Debris in got:
		d.hook = null
	state = State.IDLE
	reeling = false
	visible = false
	player.set_hand_visible(true)
	delivered.emit(got)


func _draw_rope() -> void:
	_im.clear_surfaces()
	var a := player.hand_tip()
	var b := global_position + Vector3(0, 0.45, 0)
	var sag := 0.0 if state == State.FLY else clampf(a.distance_to(b) * 0.06, 0.0, 0.8)
	var eye := player.cam.global_position
	var pts: Array[Vector3] = []
	for i in 13:
		var u := i / 12.0
		pts.append(a.lerp(b, u) - Vector3(0, sin(PI * u) * sag, 0))
	# A camera-facing ribbon: GL lines are 1 px thin on phone screens.
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 12:
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var side := (p1 - p0).cross(eye - p0).normalized() * 0.018
		_im.surface_add_vertex(p0 - side)
		_im.surface_add_vertex(p0 + side)
		_im.surface_add_vertex(p1 + side)
		_im.surface_add_vertex(p0 - side)
		_im.surface_add_vertex(p1 + side)
		_im.surface_add_vertex(p1 - side)
	_im.surface_end()
