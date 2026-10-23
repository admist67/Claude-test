extends Node3D
## Builds the static world: the kiosk interior (walls, counters, lamps, decor), the night
## street outside the service window, lights and the environment. Kiosk inner space:
## x -2..2, z -1 (window) .. 2 (back wall); counter tops at y = 1.0.

const K := "res://assets/models/"

var neon: Label3D
var street_lights: Array[OmniLight3D] = []
var env: Environment


func _ready() -> void:
	_environment()
	_kiosk()
	_decor()
	_street()


func set_rush(k: float) -> void:
	var pink := Color(2.6, 0.55, 1.5)
	var cyan := Color(0.5, 2.2, 2.6)
	neon.modulate = pink.lerp(cyan, k)
	for l in street_lights:
		l.light_color = Color("#ffd58a").lerp(Color("#ff7ad9"), k * 0.6)


func _environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0d0a24")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#7a6cb0")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color("#241c48")
	env.fog_density = 0.012
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("#9aa6ff")
	moon.light_energy = 0.3
	moon.rotation_degrees = Vector3(-55, 35, 0)
	add_child(moon)


func _checker(a: Color, b: Color) -> ImageTexture:
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.set_pixel(0, 0, a)
	img.set_pixel(1, 1, a)
	img.set_pixel(1, 0, b)
	img.set_pixel(0, 1, b)
	return ImageTexture.create_from_image(img)


func _kiosk() -> void:
	var floor_m := StandardMaterial3D.new()
	floor_m.albedo_texture = _checker(Color("#6e4c3c"), Color("#8c6652"))
	floor_m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	floor_m.uv1_scale = Vector3(8, 6, 1)
	floor_m.roughness = 0.7
	M3.wall(self, Vector3(4.2, 0.1, 3.2), Vector3(0, -0.05, 0.5), floor_m)
	var wall_m := M3.mat(Color("#f1e3c8"), 0.9)
	var trim_m := M3.mat(Color("#a85f2e"), 0.7)
	M3.wall(self, Vector3(4.2, 2.75, 0.1), Vector3(0, 1.375, 2.05), wall_m)
	M3.wall(self, Vector3(0.1, 2.75, 3.2), Vector3(-2.05, 1.375, 0.5), wall_m)
	M3.wall(self, Vector3(0.1, 2.75, 3.2), Vector3(2.05, 1.375, 0.5), wall_m)
	M3.box(self, Vector3(4.2, 0.1, 3.2), Vector3(0, 2.8, 0.5), M3.mat(Color("#3a2c3f")))
	# Front wall with the service window (x -1.85..1.85, y 1.0..2.35).
	M3.wall(self, Vector3(4.2, 1.0, 0.1), Vector3(0, 0.5, -1.05), M3.mat(Color("#c95d3b")))
	M3.wall(self, Vector3(4.2, 0.4, 0.1), Vector3(0, 2.55, -1.05), wall_m)
	M3.wall(self, Vector3(0.25, 1.35, 0.1), Vector3(-1.975, 1.675, -1.05), wall_m)
	M3.wall(self, Vector3(0.25, 1.35, 0.1), Vector3(1.975, 1.675, -1.05), wall_m)
	M3.box(self, Vector3(3.8, 0.08, 0.14), Vector3(0, 2.36, -1.05), trim_m)
	M3.box(self, Vector3(0.08, 1.4, 0.14), Vector3(-1.86, 1.68, -1.05), trim_m)
	M3.box(self, Vector3(0.08, 1.4, 0.14), Vector3(1.86, 1.68, -1.05), trim_m)
	# Tiled band behind the back counter.
	for k in 16:
		M3.box(self, Vector3(0.24, 0.24, 0.01), Vector3(-1.875 + k * 0.25, 1.15, 1.995), M3.mat(Color("#ffffff") if k % 2 == 0 else Color("#e9f0f5"), 0.3))
		M3.box(self, Vector3(0.24, 0.24, 0.01), Vector3(-1.875 + k * 0.25, 1.4, 1.995), M3.mat(Color("#e9f0f5") if k % 2 == 0 else Color("#ffffff"), 0.3))
	# Counters: front (serving), back (prep), left (spit), right (grill).
	var body_m := M3.mat(Color("#b8432f"), 0.7)
	var top_m := M3.mat(Color("#cfcbe0"), 0.35, 0.6)
	_counter(Vector3(4.0, 0.95, 0.55), Vector3(0, 0.475, -0.725), body_m, top_m, Vector3(4.0, 0.05, 0.8), Vector3(0, 0.975, -0.83))
	_counter(Vector3(4.0, 0.95, 0.65), Vector3(0, 0.475, 1.675), body_m, top_m, Vector3(4.0, 0.05, 0.69), Vector3(0, 0.975, 1.655))
	_counter(Vector3(0.6, 0.95, 1.8), Vector3(-1.7, 0.475, 0.45), body_m, top_m, Vector3(0.64, 0.05, 1.8), Vector3(-1.68, 0.975, 0.45))
	_counter(Vector3(0.6, 0.95, 1.8), Vector3(1.7, 0.475, 0.45), body_m, top_m, Vector3(0.64, 0.05, 1.8), Vector3(1.68, 0.975, 0.45))
	# Drawer handles facing the room.
	for x in [-1.4, -0.7, 0.0, 0.7, 1.4]:
		M3.box(self, Vector3(0.22, 0.03, 0.03), Vector3(x, 0.8, 1.34), top_m)
		M3.box(self, Vector3(0.22, 0.03, 0.03), Vector3(x, 0.8, -0.44), top_m)
	# Ceiling lamps.
	for x in [-0.9, 0.9]:
		M3.model(self, K + "furniture/lampSquareCeiling.glb", Vector3(x - 0.12, 2.29, 0.62), 2.0)
		var l := OmniLight3D.new()
		l.position = Vector3(x, 2.15, 0.5)
		l.light_color = Color("#ffd9a0")
		l.light_energy = 1.5
		l.omni_range = 4.5
		add_child(l)
	var spot := OmniLight3D.new()
	spot.position = Vector3(0, 1.9, 1.3)
	spot.light_color = Color("#ffe2b8")
	spot.light_energy = 0.8
	spot.omni_range = 2.5
	add_child(spot)


func _counter(size: Vector3, pos: Vector3, body_m: Material, top_m: Material, top_size: Vector3, top_pos: Vector3) -> void:
	M3.wall(self, size, pos, body_m)
	M3.box(self, top_size, top_pos, top_m)


func _decor() -> void:
	M3.model(self, K + "furniture/hoodModern.glb", Vector3(-1.95, 1.85, 0.52), 1.9, PI / 2.0)
	M3.model(self, K + "market/cash-register.glb", Vector3(1.4, 1.0, -0.72), 0.42, PI)
	M3.model(self, K + "furniture/kitchenCoffeeMachine.glb", Vector3(-1.62, 1.0, -0.62), 1.6, PI)
	M3.model(self, K + "furniture/radio.glb", Vector3(1.9, 1.0, -0.15), 1.2, -PI / 2.0)
	M3.model(self, K + "furniture/plantSmall1.glb", Vector3(-1.05, 1.0, -0.8), 2.2)
	M3.model(self, K + "food/soda-can.glb", Vector3(-0.8, 1.0, -0.85), 0.45)
	M3.model(self, K + "food/soda-can.glb", Vector3(-0.68, 1.0, -0.82), 0.45)
	M3.model(self, K + "furniture/kitchenFridgeSmall.glb", Vector3(-1.95, 0.0, -0.4), 2.0, PI / 2.0)
	# Menu board and neon sign on the back wall (labels face the room: -Z).
	M3.box(self, Vector3(1.5, 0.62, 0.03), Vector3(-0.85, 2.05, 1.985), M3.mat(Color("#20302a")))
	M3.box(self, Vector3(1.58, 0.7, 0.02), Vector3(-0.85, 2.05, 1.995), M3.mat(Color("#a85f2e")))
	var menu := M3.label(self, "МЕНЮ\nШаурма классика ..... 120 ₽\nДвойное мясо ......... +60 ₽\nКаждая добавка ......... +25 ₽", Vector3(-0.85, 2.05, 1.965), 40, Color("#f4f1e8"), 0, 0.0022)
	menu.rotation.y = PI
	menu.line_spacing = 6.0
	neon = M3.label(self, "ШАУРМА", Vector3(0.95, 2.12, 1.96), 110, Color(2.6, 0.55, 1.5), 0, 0.0042)
	neon.rotation.y = PI
	var neon_light := OmniLight3D.new()
	neon_light.position = Vector3(0.95, 2.1, 1.7)
	neon_light.light_color = Color("#ff5fb0")
	neon_light.light_energy = 0.6
	neon_light.omni_range = 1.6
	add_child(neon_light)
	var open_sign := M3.label(self, "ОТКРЫТО", Vector3(0, 2.46, -1.0), 60, Color(0.6, 2.4, 2.6), 0, 0.003)
	open_sign.rotation.y = 0.0


func _street() -> void:
	M3.box(self, Vector3(70, 0.1, 5.0), Vector3(0, -0.05, -3.6), M3.mat(Color("#4a4466"), 0.9))
	M3.box(self, Vector3(70, 0.16, 0.25), Vector3(0, 0.0, -6.1), M3.mat(Color("#6a6488")))
	M3.box(self, Vector3(70, 0.08, 8.0), Vector3(0, -0.07, -10.2), M3.mat(Color("#25222f"), 0.85))
	for k in 14:
		M3.box(self, Vector3(1.6, 0.02, 0.14), Vector3(-26 + k * 4.0, -0.02, -10.2), M3.mat(Color("#e8e2c8")))
	M3.box(self, Vector3(70, 0.12, 4.0), Vector3(0, -0.04, -16.2), M3.mat(Color("#4a4466"), 0.9))
	# Kiosk awning outside the window: red/cream stripes.
	var awning := Node3D.new()
	awning.position = Vector3(0, 2.66, -1.42)
	awning.rotation.x = 0.38
	add_child(awning)
	for k in 10:
		M3.box(awning, Vector3(0.43, 0.03, 0.78), Vector3(-1.94 + k * 0.43, 0, 0), M3.mat(Color("#e2493b") if k % 2 == 0 else Color("#fff1d6")))
	# Buildings across the road and a far skyline.
	var names := ["a", "b", "c", "d", "e", "f", "g", "h", "b", "d"]
	for i in names.size():
		M3.model(self, K + "city/building-%s.glb" % names[i], Vector3(-31.5 + i * 7.0, 0, -21.5), 7.2)
	for i in 12:
		M3.model(self, K + "city/low-detail-building-%s.glb" % ["a", "b", "c", "d"][i % 4], Vector3(-36 + i * 6.5, 0, -34.0 - (i % 3) * 3.0), 9.0)
	# Street lights.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for x in [-7.5, 7.5]:
		M3.model(self, K + "roads/light-curved.glb", Vector3(x, 0, -5.8), 6.0, PI)
		M3.sphere(self, 0.18, Vector3(x, 3.75, -7.0), M3.glow(Color("#ffe0a0"), 3.0))
		var l := OmniLight3D.new()
		l.position = Vector3(x, 3.6, -6.9)
		l.light_color = Color("#ffd58a")
		l.light_energy = 2.2
		l.omni_range = 9.0
		add_child(l)
		street_lights.append(l)
	# Metro sign on a pole.
	M3.cyl(self, 0.05, 0.05, 3.0, Vector3(-3.4, 1.5, -2.8), M3.mat(Color("#5b5480"), 0.5, 0.5))
	var disc := M3.cyl(self, 0.38, 0.38, 0.06, Vector3(-3.4, 3.1, -2.8), M3.glow(Color("#3a7bff"), 1.6))
	disc.rotation.x = PI / 2.0
	M3.label(self, "M", Vector3(-3.4, 3.1, -2.76), 120, Color(2, 2, 2), 0, 0.004)
	# Sidewalk props.
	for k in 3:
		M3.model(self, K + "roads/construction-cone.glb", Vector3(-6.0 + k * 0.6, 0, -4.8), 5.0)
	# Moon and stars.
	M3.sphere(self, 4.0, Vector3(30, 42, -95), M3.glow(Color("#fff1c9"), 1.4))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var star := SphereMesh.new()
	star.radius = 0.25
	star.height = 0.5
	star.radial_segments = 4
	star.rings = 2
	mm.mesh = star
	mm.instance_count = 140
	for i in mm.instance_count:
		var a := rng.randf_range(-PI * 0.9, PI * 0.1) - PI / 2.0
		var e := rng.randf_range(0.25, 1.2)
		var p := Vector3(cos(a) * cos(e), sin(e), sin(a) * cos(e)) * 120.0
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * rng.randf_range(0.6, 1.4)), p))
	var stars := MultiMeshInstance3D.new()
	stars.multimesh = mm
	stars.material_override = M3.flat(Color(1, 0.95, 0.85))
	add_child(stars)
