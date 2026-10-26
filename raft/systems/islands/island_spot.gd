class_name IslandSpot
extends StaticBody3D
## Something to gather on an island: a palm, a banana or pineapple plant, a rock, a
## driftwood log or a sea chest. The use button takes its loot a few times; the fruit
## disappears, a log is carried off. A rock is dug with a pickaxe, a few blows for each
## chunk, and shrinks. A chest is opened and emptied by hand (`items`), then stays open.

var kind := ""
var def: Dictionary
var left := 0
var look: Node3D                  # the whole visual (rocks and logs go with their last loot)
var fruit: Node3D                 # coconuts, bananas, the pineapple: gone when picked clean
var lid: Node3D                   # chests
var block: CollisionShape3D       # its solid shape in the island body (rocks, logs, chests)
var items: Dictionary = {}        # a chest's contents
var dug := 0                      # a rock: blows toward the next chunk


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
	if kind == "chest":
		return {"text": "Открыть сундук" if not items.is_empty() else "Пусто", "ok": not items.is_empty(), "icon": "chest"}
	if left <= 0:
		return {"text": "Пусто", "ok": false, "icon": first}
	if kind == "rock":
		return {"text": "Нужна кирка", "ok": false, "icon": "pickaxe"}
	return {"text": def["verb"], "ok": true, "icon": first}


## A pickaxe blow on a rock: every few blows a chunk breaks off (its loot), else {}.
func dig() -> Dictionary:
	if kind != "rock" or left <= 0:
		return {}
	dug += 1
	if look:
		var tw := create_tween()
		tw.tween_property(look, "rotation:z", 0.06, 0.05)
		tw.tween_property(look, "rotation:z", 0.0, 0.1)
	if dug < int(def["hits"]):
		return {}
	dug = 0
	return take()


## The chest is opened for the first time: the lid goes up.
func open_chest() -> void:
	if left > 0:
		left = 0
		refresh()


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
