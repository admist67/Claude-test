class_name IslandSpot
extends StaticBody3D
## Something to gather on an island: a palm, a banana or pineapple plant, a rock, a
## driftwood log or a sea chest. The use button takes its loot a few times; the fruit
## disappears, a rock shrinks, a log is carried off, a chest stays open.

var kind := ""
var def: Dictionary
var left := 0
var look: Node3D                  # the whole visual (rocks and logs go with their last loot)
var fruit: Node3D                 # coconuts, bananas, the pineapple: gone when picked clean
var lid: Node3D                   # chests
var block: CollisionShape3D       # its solid shape in the island body (rocks, logs, chests)


func setup(k: String, d: Dictionary, use_size: Vector3, use_pos: Vector3) -> void:
	kind = k
	def = d
	left = int(d["charges"])
	collision_layer = Part.USE_LAYER
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = use_size
	cs.shape = shape
	cs.position = use_pos
	add_child(cs)


func prompt() -> Dictionary:
	var first: String = def["loot"].keys()[0]
	if left <= 0:
		return {"text": "Пусто", "ok": false, "icon": first}
	return {"text": def["verb"], "ok": true, "icon": first}


## Takes one share of the loot: {item: count}.
func take() -> Dictionary:
	if left <= 0:
		return {}
	left -= 1
	refresh()
	return def["loot"]


## Shows what is left (after taking, or after loading a save).
func refresh() -> void:
	var full := int(def["charges"])
	if fruit:
		fruit.visible = left > 0
	if lid:
		lid.rotation.x = 0.0 if left > 0 else -1.9
	if look and kind in ["rock", "log"]:
		look.visible = left > 0
		look.scale = Vector3.ONE * (0.55 + 0.45 * float(left) / full)
		for c in get_children():
			if c is CollisionShape3D:
				c.disabled = left <= 0
		if block:
			block.disabled = left <= 0
