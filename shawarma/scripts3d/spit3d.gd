extends Node3D
## Vertical doner spit (faces +X, the room). Swipe down on the meat to shave a portion;
## the stock slowly cooks back. Tappable kind: "spit".

var capacity := 10
var regen := 2.5
var stock := 10.0
var knife_t := 0.0
var cone: MeshInstance3D
var knife: Node3D
var heat_bars: Array[MeshInstance3D] = []
var t := 0.0


func _ready() -> void:
	var metal := M3.mat(Color("#c7c2dc"), 0.3, 0.8)
	M3.box(self, Vector3(0.4, 0.04, 0.4), Vector3(0, 0.02, 0), M3.mat(Color("#8f8aa8"), 0.4, 0.7))
	M3.cyl(self, 0.012, 0.012, 0.8, Vector3(0, 0.42, 0), metal, 8)
	M3.sphere(self, 0.025, Vector3(0, 0.83, 0), metal)
	# Heater panel behind the meat, against the wall.
	M3.box(self, Vector3(0.05, 0.62, 0.36), Vector3(-0.2, 0.4, 0), M3.mat(Color("#4b4060"), 0.6, 0.3))
	for k in 5:
		heat_bars.append(M3.box(self, Vector3(0.01, 0.06, 0.28), Vector3(-0.172, 0.16 + k * 0.12, 0), M3.glow(Color("#ff7a2a"), 2.5)))
	# The meat cone with a layered noise texture.
	var noise := FastNoiseLite.new()
	noise.frequency = 0.06
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 128
	tex.height = 128
	tex.seamless = true
	var ramp := Gradient.new()
	ramp.set_color(0, Color("#6e3415"))
	ramp.set_color(1, Color("#d08446"))
	tex.color_ramp = ramp
	var meat_m := StandardMaterial3D.new()
	meat_m.albedo_texture = tex
	meat_m.uv1_scale = Vector3(3, 6, 1)
	meat_m.roughness = 0.75
	cone = M3.cyl(self, 0.16, 0.085, 0.54, Vector3(0, 0.42, 0), meat_m, 20)
	M3.cyl(cone, 0.155, 0.155, 0.015, Vector3(0, 0.275, 0), M3.mat(Color("#c97a43")), 20)
	knife = Node3D.new()
	add_child(knife)
	M3.box(knife, Vector3(0.006, 0.2, 0.045), Vector3(0, -0.06, 0), M3.mat(Color("#e9e6f5"), 0.2, 0.9))
	M3.box(knife, Vector3(0.022, 0.1, 0.03), Vector3(0, 0.09, -0.005), M3.mat(Color("#3b2b44"), 0.6))
	M3.solid(self, Vector3(0.42, 0.62, 0.42), Vector3(0.02, 0.42, 0), M3.LAYER_USE, "spit")


func setup(cap: int, regen_s: float) -> void:
	capacity = cap
	regen = regen_s
	stock = cap


func can_cut() -> bool:
	return stock >= 1.0


func cut() -> void:
	stock -= 1.0
	knife_t = 1.0


func cut_point() -> Vector3:
	return to_global(Vector3(0.17, 0.45, 0))


func _process(delta: float) -> void:
	t += delta
	if stock < capacity:
		stock = minf(capacity, stock + delta / regen)
	cone.rotation.y += delta * 0.8
	var f := clampf(stock / capacity, 0.0, 1.0)
	var s := 0.5 + 0.5 * sqrt(f)
	cone.scale = Vector3(s, 1.0, s)
	knife_t = maxf(0.0, knife_t - delta * 3.0)
	knife.position = Vector3(0.03 + 0.16 * s, lerpf(0.6, 0.25, sin(knife_t * PI)) if knife_t > 0.0 else 0.6, 0.1)
	for k in heat_bars.size():
		heat_bars[k].scale.y = 0.85 + 0.15 * sin(t * 4.0 + k)
