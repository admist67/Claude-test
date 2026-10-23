class_name M3
## Helpers for the procedural 3D props: cached materials, primitive meshes, colliders,
## Kenney model instancing, labels and the shawarma roll.

const LAYER_WORLD := 1
const LAYER_USE := 2

static var _mats := {}


static func mat(color: Color, rough := 0.8, metal := 0.0, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s|%s" % [color.to_html(), rough, metal, emission.to_html(), energy]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	_mats[key] = m
	return m


static func glow(color: Color, energy := 2.0) -> StandardMaterial3D:
	return mat(color, 1.0, 0.0, color, energy)


static func flat(color: Color) -> StandardMaterial3D:
	var key := "flat|" + color.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m


static func box(parent: Node, size: Vector3, pos: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func cyl(parent: Node, top_r: float, bot_r: float, h: float, pos: Vector3, material: Material, segs := 24) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


static func sphere(parent: Node, r: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


## Static collider box. layer 1 blocks the player, layer 2 is tappable (kind = what it is).
static func solid(parent: Node, size: Vector3, pos: Vector3, layer := LAYER_WORLD, kind := "") -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = layer
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	b.position = pos
	if kind != "":
		b.set_meta("kind", kind)
	parent.add_child(b)
	return b


## A visible box that also blocks the player.
static func wall(parent: Node, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	solid(parent, size, pos)
	return box(parent, size, pos, material)


static func model(parent: Node, path: String, pos: Vector3, scale: float, rot_y := 0.0) -> Node3D:
	var n: Node3D = load(path).instantiate()
	n.position = pos
	n.scale = Vector3.ONE * scale
	n.rotation.y = rot_y
	parent.add_child(n)
	return n


## Overrides every mesh surface under n with one material (recolour a Kenney model).
static func paint(n: Node, material: Material) -> void:
	if n is MeshInstance3D:
		n.material_override = material
	for c in n.get_children():
		paint(c, material)


static func label(parent: Node, text: String, pos: Vector3, size_px := 64, color := Color.WHITE, outline := 12, pixel := 0.004) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = DU.FONT
	l.font_size = size_px
	l.outline_size = outline
	l.outline_modulate = DU.INK
	l.modulate = color
	l.pixel_size = pixel
	l.position = pos
	parent.add_child(l)
	return l


# --- The shawarma roll -------------------------------------------------------

static func make_roll() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.042
	cm.height = 0.25
	cm.radial_segments = 16
	cm.rings = 4
	mi.mesh = cm
	mi.rotation.z = PI / 2.0
	var m := StandardMaterial3D.new()
	m.albedo_color = DU.LAVASH
	m.roughness = 0.9
	mi.material_override = m
	for k in 4:
		var mark := box(mi, Vector3(0.012, 0.08, 0.006), Vector3(0.036, -0.075 + k * 0.05, 0.0), null, Vector3(0, 0, 0.5))
		var mm := StandardMaterial3D.new()
		mm.albedo_color = Color(0.35, 0.18, 0.08, 0.0)
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mark.material_override = mm
		mark.set_meta("mark", true)
	var end := cyl(mi, 0.03, 0.03, 0.01, Vector3(0, 0.126, 0), mat(DU.MEAT))
	end.set_meta("end", true)
	return mi


static func set_toast(roll: MeshInstance3D, t: float, bal: Dictionary) -> void:
	(roll.material_override as StandardMaterial3D).albedo_color = DU.toast_color(t, bal)
	var a := clampf(t / float(bal["grill_perfect_from"]), 0.0, 1.0) * 0.85
	for c in roll.get_children():
		if c.has_meta("mark"):
			(c.material_override as StandardMaterial3D).albedo_color.a = a
