class_name Ocean
extends MeshInstance3D
## The water plane follows the camera; height_at() is the same wave sum as the shader,
## so the raft, debris and hook float exactly on the waves you see. set_sky() feeds the
## day/night colors into the reflection.

static var waves: Array[Vector4] = []
static var time := 0.0

var cam: Camera3D
var _cell := 1.0
var _mat: ShaderMaterial


static func height_at(x: float, z: float) -> float:
	var s := 0.0
	for w in waves:
		var k := TAU / w.w
		s += w.z * sin(k * (w.x * x + w.y * z) - sqrt(9.8 * k) * time)
	return s


func _ready() -> void:
	var cfg: Dictionary = Data.b["ocean"]
	waves.clear()
	for a: Array in cfg["waves"]:
		var d := Vector2(a[0], a[1]).normalized()
		waves.append(Vector4(d.x, d.y, a[2], a[3]))
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE * float(cfg["size"])
	pm.subdivide_width = int(cfg["subdiv"])
	pm.subdivide_depth = int(cfg["subdiv"])
	mesh = pm
	_cell = float(cfg["size"]) / float(cfg["subdiv"] + 1)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://systems/ocean/ocean.gdshader")
	_mat.set_shader_parameter("waves", PackedVector4Array(waves))
	_mat.set_shader_parameter("ripple", load("res://assets/textures/water_normal.png"))
	_mat.set_shader_parameter("noise_tex", load("res://assets/textures/noise.png"))
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 4.0


func set_sky(top: Color, horizon: Color, light: float) -> void:
	_mat.set_shader_parameter("sky_top", Vector3(top.r, top.g, top.b))
	_mat.set_shader_parameter("sky_horizon", Vector3(horizon.r, horizon.g, horizon.b))
	_mat.set_shader_parameter("light_level", light)


func _process(delta: float) -> void:
	time += delta
	_mat.set_shader_parameter("t", time)
	if cam:
		var p := cam.global_position
		global_position = Vector3(snappedf(p.x, _cell), 0.0, snappedf(p.z, _cell))
