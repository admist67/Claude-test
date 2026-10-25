class_name Fx
## One-shot particle puffs: chips flying off (wood, blood) and splashes on the water.


## Small flying chips at a point.
static func burst(parent: Node, pos: Vector3, col: Color, n: int) -> void:
	_puff(parent, pos, col, 0.8, 0.06, n, 0.9, 60.0, 1.5, 3.5)


static func splash(parent: Node, pos: Vector3, n := 18) -> void:
	var p := _puff(parent, pos, Color("#f2f6f2"), 0.4, 0.07, n, 0.8, 35.0, 2.0, 4.0)
	p.explosiveness = 0.95
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4


static func _puff(parent: Node, pos: Vector3, col: Color, rough: float, size: float, n: int, life: float, spread: float, v0: float, v1: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var m := BoxMesh.new()
	m.size = Vector3.ONE * size
	m.material = Mk.mat(col, rough)
	p.mesh = m
	p.amount = n
	p.one_shot = true
	p.explosiveness = 0.9
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = v0
	p.initial_velocity_max = v1
	p.gravity = Vector3(0, -9.8, 0)
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	parent.get_tree().create_timer(1.5).timeout.connect(p.queue_free)
	return p
