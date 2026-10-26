class_name Island
extends AnimatableBody3D
## An island drifting past the raft: sand and grass you can walk on, palms, banana and
## pineapple plants, rocks, a driftwood log, a sea chest, and crabs guarding it all.
## Built from a seed, so a save brings back the same island with what was already taken.

## Where each kind of spot grows: [min, max] fraction of the radius from the center.
const BANDS := {"palm": [0.1, 0.62], "banana": [0.15, 0.55], "pineapple": [0.12, 0.5], "rock": [0.35, 0.78], "log": [0.8, 0.9], "chest": [0.25, 0.6]}

var seed_v := 0
var radius := 9.0
var wob: Array = []
var spots: Array[IslandSpot] = []
var crabs: Array[Crab] = []
var visited := false


func build(s: int, cfg: Dictionary) -> void:
	seed_v = s
	sync_to_physics = false           # moved by code; a placed or loaded island stays put
	collision_layer = 1
	collision_mask = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	radius = rng.randf_range(float(cfg["radius"][0]), float(cfg["radius"][1]))
	wob = [rng.randf_range(0.06, 0.14), rng.randf() * TAU, rng.randf_range(0.03, 0.09), rng.randf() * TAU, rng.randf_range(0.02, 0.05), rng.randf() * TAU]
	var mi := MeshInstance3D.new()
	mi.mesh = IslandLooks.ground(radius, wob, rng)
	add_child(mi)
	var cs := CollisionShape3D.new()
	var shape: ConcavePolygonShape3D = mi.mesh.create_trimesh_shape()
	shape.backface_collision = true
	cs.shape = shape
	add_child(cs)
	var taken: Array[Vector2] = []
	var sd: Dictionary = cfg["spots"]
	for kind: String in ["chest", "log", "rock", "palm", "banana", "pineapple"]:
		var d: Dictionary = sd[kind]
		var n := rng.randi_range(int(d["count"][0]), int(d["count"][1])) if d.has("count") else (1 if rng.randf() < float(d["chance"]) else 0)
		for i in n:
			var at := _free_spot(rng, kind, taken)
			if at.x > 1e6:
				continue
			taken.append(at)
			_add_spot(kind, d, at, rng)
	var cc: Dictionary = cfg["crabs"]
	for i in rng.randi_range(int(cc["count"][0]), int(cc["count"][1])):
		var crab := Crab.new()
		crab.setup(self, cc, rng.randi())
		var a := rng.randf() * TAU
		var p := Vector2(cos(a), sin(a)) * radius * rng.randf_range(0.2, 0.6)
		crab.position = Vector3(p.x, height_at(p), p.y)
		add_child(crab)
		crabs.append(crab)
		crab.died.connect(func(c: Crab) -> void: crabs.erase(c))


func height_at(p: Vector2) -> float:
	return IslandLooks.height(p, radius, wob)


func _free_spot(rng: RandomNumberGenerator, kind: String, taken: Array[Vector2]) -> Vector2:
	var band: Array = BANDS[kind]
	for t in 30:
		var a := rng.randf() * TAU
		var p := Vector2(cos(a), sin(a)) * radius * IslandLooks.shore(a, wob) * rng.randf_range(band[0], band[1])
		var ok := true
		for q in taken:
			if p.distance_to(q) < 2.3:
				ok = false
				break
		if ok:
			return p
	return Vector2(1e7, 1e7)


func _add_spot(kind: String, d: Dictionary, at: Vector2, rng: RandomNumberGenerator) -> void:
	var pos := Vector3(at.x, height_at(at) - 0.05, at.y)
	var spot := IslandSpot.new()
	var root := Node3D.new()
	root.rotation.y = rng.randf() * TAU
	match kind:
		"palm":
			var p := IslandLooks.palm(rng)
			for m: ArrayMesh in [p[0], p[1]]:
				root.add_child(_mi(m))
			spot.fruit = _mi(p[2])
			root.add_child(spot.fruit)
			spot.setup(kind, d, Vector3(1.0, 2.6, 1.0), Vector3(0, 1.3, 0))
			_block(CylinderShape3D.new(), pos + Vector3(0, 1.0, 0), 0.24, 2.0)
		"banana":
			var b := IslandLooks.banana(rng)
			root.add_child(_mi(b[0]))
			root.add_child(_mi(b[1]))
			spot.fruit = _mi(b[2])
			root.add_child(spot.fruit)
			spot.setup(kind, d, Vector3(1.4, 1.8, 1.4), Vector3(0, 0.9, 0))
		"pineapple":
			root.add_child(_mi(IslandLooks.pineapple_leaves(rng)))
			var f := Looks.held("pineapple")
			f.scale = Vector3.ONE * 2.6
			f.position = Vector3(0, 0.32, 0)
			spot.fruit = f
			root.add_child(f)
			spot.setup(kind, d, Vector3(1.0, 1.0, 1.0), Vector3(0, 0.5, 0))
		"rock":
			var r := IslandLooks.rock(rng)
			spot.look = _mi(r[0])
			root.add_child(spot.look)
			var size: Vector3 = r[1]
			spot.setup(kind, d, size * 1.25, Vector3(0, size.y * 0.5, 0))
			spot.block = _block(BoxShape3D.new(), pos + Vector3(0, size.y * 0.4, 0), size.x * 0.4, size.y * 0.8)
		"log":
			spot.look = _mi(IslandLooks.log_mesh())
			root.add_child(spot.look)
			spot.setup(kind, d, Vector3(2.4, 0.8, 0.8), Vector3(0, 0.3, 0))
		"chest":
			var c := IslandLooks.chest()
			root.add_child(_mi(c[0]))
			spot.lid = Node3D.new()
			spot.lid.position = Vector3(0, 0.45, -0.3)
			spot.lid.add_child(_mi(c[1]))
			root.add_child(spot.lid)
			spot.setup(kind, d, Vector3(1.1, 0.9, 0.8), Vector3(0, 0.4, 0))
			spot.block = _block(BoxShape3D.new(), pos + Vector3(0, 0.3, 0), 0.45, 0.6)
	spot.position = pos
	spot.rotation.y = root.rotation.y
	root.rotation.y = 0.0
	spot.add_child(root)
	add_child(spot)
	spots.append(spot)
	spot.refresh()


func _mi(m: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	return mi


## A solid shape in the island body: a trunk (cylinder) or a block (box `r` half wide).
func _block(shape: Shape3D, at: Vector3, r: float, h: float) -> CollisionShape3D:
	if shape is CylinderShape3D:
		shape.radius = r
		shape.height = h
	elif shape is BoxShape3D:
		shape.size = Vector3(r * 2.0, h, r * 2.0)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = at
	add_child(cs)
	return cs


func to_dict() -> Dictionary:
	var left := spots.map(func(s: IslandSpot) -> int: return s.left)
	return {"seed": seed_v, "x": position.x, "z": position.z, "left": left, "visited": visited, "crabs": crabs.size()}


## After build(seed): puts back where it was and what was taken.
func load_state(d: Dictionary) -> void:
	position = Vector3(float(d.get("x", 0.0)), 0.0, float(d.get("z", 0.0)))
	visited = bool(d.get("visited", false))
	var left: Array = d.get("left", [])
	for i in mini(left.size(), spots.size()):
		spots[i].left = int(left[i])
		spots[i].refresh()
	while crabs.size() > int(d.get("crabs", crabs.size())):
		crabs.pop_back().queue_free()
