extends Node3D
## Contact grill on the right counter, facing -X (the room). Slots along Z.
## Rolls toast over time: green zone = perfect, then they burn. Tappable kinds: "grill:<i>".

signal perfect_reached(pos: Vector3)
signal burnt(pos: Vector3)

const MAX_SLOTS := 3
const SLOT_Z := [-0.36, 0.0, 0.36]
const BAR_LEN := 0.3

var unlocked := 2
var slots: Array = [null, null, null]   # {"made", "t", "rang", "mesh"}
var bal: Dictionary
var bars: Array = []                    # per slot: {"root", "marker"}
var steam: Array[CPUParticles3D] = []
var locks: Array[Node3D] = []


func _ready() -> void:
	var dark := M3.mat(Color("#3d3450"), 0.5, 0.6)
	M3.box(self, Vector3(0.46, 0.1, 1.12), Vector3(0, 0.05, 0), M3.mat(Color("#5b4f73"), 0.4, 0.6))
	M3.box(self, Vector3(0.08, 0.16, 1.12), Vector3(0.2, 0.18, 0), dark)
	var label := M3.label(self, "ГРИЛЬ", Vector3(-0.235, 0.05, 0), 48, DU.CREAM, 10, 0.0022)
	label.rotation.y = -PI / 2.0
	for i in MAX_SLOTS:
		var z: float = SLOT_Z[i]
		M3.box(self, Vector3(0.34, 0.015, 0.3), Vector3(-0.02, 0.105, z), M3.mat(Color("#2a2234"), 0.5, 0.5))
		for k in 6:
			M3.box(self, Vector3(0.3, 0.012, 0.012), Vector3(-0.02, 0.115, z - 0.12 + k * 0.048), M3.mat(Color("#4a3e5c"), 0.4, 0.6))
		M3.box(self, Vector3(0.3, 0.004, 0.26), Vector3(-0.02, 0.112, z), M3.glow(Color("#ff5a1a"), 0.5))
		M3.solid(self, Vector3(0.42, 0.22, 0.34), Vector3(-0.02, 0.15, z), M3.LAYER_USE, "grill:%d" % i)
		bars.append(_make_bar(z))
		var p := CPUParticles3D.new()
		p.position = Vector3(-0.02, 0.17, z)
		p.amount = 10
		p.lifetime = 1.2
		p.emitting = false
		p.direction = Vector3.UP
		p.spread = 15.0
		p.initial_velocity_min = 0.15
		p.initial_velocity_max = 0.3
		p.gravity = Vector3(0, 0.1, 0)
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.2
		var sm := SphereMesh.new()
		sm.radius = 0.025
		sm.height = 0.05
		sm.radial_segments = 6
		sm.rings = 3
		p.mesh = sm
		p.material_override = M3.flat(Color(1, 1, 1, 0.35))
		add_child(p)
		steam.append(p)
		var lock := Node3D.new()
		lock.position = Vector3(-0.02, 0.13, z)
		add_child(lock)
		M3.box(lock, Vector3(0.34, 0.03, 0.3), Vector3.ZERO, M3.mat(Color("#2a2234")))
		var ll := M3.label(lock, "закрыто", Vector3(0, 0.03, 0), 40, Color("#9a8fb8"), 8, 0.0022)
		ll.rotation = Vector3(-PI / 2.0, -PI / 2.0, 0)
		locks.append(lock)
	_update_locks()


func _make_bar(z: float) -> Dictionary:
	var root := Node3D.new()
	root.position = Vector3(0.12, 0.34, z)
	root.visible = false
	add_child(root)
	var burnt_at := float(Bal.b["grill_burnt_at"])
	var from := float(Bal.b["grill_perfect_from"]) / burnt_at
	var to := float(Bal.b["grill_perfect_to"]) / burnt_at
	M3.box(root, Vector3(0.006, 0.05, BAR_LEN + 0.02), Vector3(0.004, 0, 0), M3.flat(DU.INK))
	_seg(root, 0.0, from, Color("#e8d2a6"))
	_seg(root, from, to, DU.GREEN)
	_seg(root, to, 1.0, Color("#ff8a3d"))
	var marker := M3.box(root, Vector3(0.012, 0.07, 0.014), Vector3(-0.004, 0, -BAR_LEN / 2.0), M3.flat(Color.WHITE))
	return {"root": root, "marker": marker}


func _seg(root: Node3D, a: float, b: float, col: Color) -> void:
	var len := (b - a) * BAR_LEN
	# Seen from the room (looking +X) -Z is on the left: the bar fills from -Z to +Z.
	M3.box(root, Vector3(0.004, 0.034, len), Vector3(0, 0, -BAR_LEN / 2.0 + a * BAR_LEN + len / 2.0), M3.flat(col))


func _update_locks() -> void:
	for i in MAX_SLOTS:
		locks[i].visible = i >= unlocked


func set_unlocked(n: int) -> void:
	unlocked = n
	_update_locks()


func free_slot() -> int:
	for i in unlocked:
		if slots[i] == null:
			return i
	return -1


func slot_global(i: int) -> Vector3:
	return to_global(Vector3(-0.02, 0.16, SLOT_Z[i]))


func put_in(i: int, made: Dictionary, from_global: Vector3) -> void:
	var mesh := M3.make_roll()
	add_child(mesh)
	mesh.rotation.y = PI / 2.0
	var target := Vector3(-0.02, 0.165, SLOT_Z[i])
	mesh.global_position = from_global
	var tw := mesh.create_tween()
	tw.tween_property(mesh, "position", target, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	M3.set_toast(mesh, made["toast"], bal)
	slots[i] = {"made": made, "t": float(made["toast"]), "rang": _rang_for(made["toast"]), "mesh": mesh}
	bars[i]["root"].visible = true


func take(i: int) -> Dictionary:
	var s: Dictionary = slots[i]
	slots[i] = null
	s["mesh"].queue_free()
	bars[i]["root"].visible = false
	steam[i].emitting = false
	var made: Dictionary = s["made"]
	made["toast"] = s["t"]
	return made


func clear_all() -> void:
	for i in MAX_SLOTS:
		if slots[i] != null:
			take(i)


func busy_count() -> int:
	var n := 0
	for s in slots:
		if s != null:
			n += 1
	return n


func _rang_for(t: float) -> int:
	if t >= float(bal["grill_burnt_at"]):
		return 2
	if t >= float(bal["grill_perfect_from"]):
		return 1
	return 0


func _process(delta: float) -> void:
	var burnt_at := float(bal["grill_burnt_at"])
	for i in MAX_SLOTS:
		var s = slots[i]
		if s == null:
			continue
		s["t"] += delta * Bal.tune["grill"]
		M3.set_toast(s["mesh"], s["t"], bal)
		var f := clampf(s["t"] / burnt_at, 0.0, 1.0)
		bars[i]["marker"].position.z = -BAR_LEN / 2.0 + f * BAR_LEN
		var r := _rang_for(s["t"])
		steam[i].emitting = true
		steam[i].material_override = M3.flat(Color(0.15, 0.1, 0.1, 0.6) if r == 2 else Color(1, 1, 1, 0.35))
		if r > s["rang"]:
			s["rang"] = r
			if r == 1:
				perfect_reached.emit(slot_global(i))
			else:
				burnt.emit(slot_global(i))
