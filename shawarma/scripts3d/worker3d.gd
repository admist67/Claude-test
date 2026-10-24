extends Node3D
## A hired worker NPC: walks routes, plays work animations and carries a roll or a drink.
## The decisions are made by staff3d.gd; this node only moves and shows.

const SCALE := 1.75
const SPEED := 1.6

var role := ""
var busy := false
var anim: AnimationPlayer
var carry_roll: MeshInstance3D
var carry_can: Node3D
var carry_crate: Node3D
var carrying: Dictionary = {}


func setup(role_id: String, title: String, model_path: String, apron: Color) -> void:
	role = role_id
	var model := M3.model(self, model_path, Vector3.ZERO, SCALE)
	anim = model.find_child("AnimationPlayer", true, false)
	if anim:
		for a in ["idle", "walk"]:
			if anim.has_animation(a):
				anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		anim.play("idle")
	M3.box(self, Vector3(0.36, 0.3, 0.02), Vector3(0, 0.53, 0.17), M3.mat(apron, 0.8))
	var tag := M3.label(self, title, Vector3(0, 1.7, 0), 40, apron.lightened(0.4), 10, 0.003)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	carry_roll = M3.make_roll()
	carry_roll.position = Vector3(0.0, 0.85, 0.3)
	carry_roll.rotation.y = PI / 2.0
	carry_roll.visible = false
	add_child(carry_roll)
	carry_can = M3.model(self, "res://assets/models/food/soda-can.glb", Vector3(0.12, 0.8, 0.28), 0.32)
	carry_can.visible = false
	carry_crate = Node3D.new()
	add_child(carry_crate)
	M3.box(carry_crate, Vector3(0.34, 0.16, 0.26), Vector3(0, 0.8, 0.3), M3.mat(Color("#c98b55"), 0.8))
	M3.box(carry_crate, Vector3(0.3, 0.03, 0.22), Vector3(0, 0.89, 0.3), M3.mat(Color("#6cc24a"), 0.8))
	carry_crate.visible = false


func _play(a: String) -> void:
	if anim and anim.has_animation(a) and anim.current_animation != a:
		anim.play(a, 0.2)


func _face_to(q: Vector3) -> void:
	var d := q - position
	if Vector2(d.x, d.z).length() > 0.01:
		rotation.y = atan2(d.x, d.z)


func hold(item: Dictionary) -> void:
	carrying = item
	carry_can.visible = item.has("drink")
	carry_crate.visible = item.has("crate")
	carry_roll.visible = not item.is_empty() and not item.has("drink") and not item.has("crate")
	if carry_roll.visible:
		M3.set_toast(carry_roll, item["toast"], Bal.b)


func drop() -> Dictionary:
	var item := carrying
	hold({})
	return item


## Walks the points, then optionally works for `work` seconds facing `look_at`, then `then`.
func go(points: Array, then: Callable, work := 0.0, look_at := Vector3.INF) -> void:
	busy = true
	var tw := create_tween()
	tw.tween_callback(_play.bind("walk"))
	var prev := position
	for p in points:
		var q: Vector3 = p
		tw.tween_callback(_face_to.bind(q))
		tw.tween_property(self, "position", q, maxf(0.05, prev.distance_to(q) / SPEED))
		prev = q
	if look_at != Vector3.INF:
		tw.tween_callback(_face_to.bind(look_at))
	if work > 0.0:
		tw.tween_callback(_play.bind("interact-right"))
		tw.tween_interval(work)
	tw.tween_callback(_play.bind("idle"))
	tw.tween_callback(func():
		busy = false
		then.call()
	)
