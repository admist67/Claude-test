class_name Inventory
extends RefCounted
## Item counts by id. No slots, weight or durability (anti-pillar).

signal changed

var counts: Dictionary = {}


func count(id: String) -> int:
	return counts.get(id, 0)


func add(id: String, n := 1) -> void:
	counts[id] = count(id) + n
	changed.emit()


func remove(id: String, n := 1) -> bool:
	if count(id) < n:
		return false
	counts[id] = count(id) - n
	if counts[id] == 0:
		counts.erase(id)
	changed.emit()
	return true


func has_all(cost: Dictionary) -> bool:
	for id: String in cost:
		if count(id) < int(cost[id]):
			return false
	return true


func pay(cost: Dictionary) -> bool:
	if not has_all(cost):
		return false
	for id: String in cost:
		counts[id] = count(id) - int(cost[id])
		if counts[id] == 0:
			counts.erase(id)
	changed.emit()
	return true


## Death penalty: keeps tools, keeps `keep` share (rounded down) of everything else.
func lose_share(keep: float, items: Dictionary) -> void:
	for id: String in counts.keys():
		if items.get(id, {}).get("kind", "") == "tool":
			continue
		counts[id] = int(floor(count(id) * keep))
		if counts[id] == 0:
			counts.erase(id)
	changed.emit()


## Recipe helpers: a recipe is {"id", "out", "cost", "once"?}.
func can_craft(r: Dictionary) -> bool:
	if r.get("once", false) and count(r["id"]) > 0:
		return false
	return has_all(r["cost"])


func craft(r: Dictionary) -> bool:
	if not can_craft(r) or not pay(r["cost"]):
		return false
	add(r["id"], int(r["out"]))
	return true


func to_dict() -> Dictionary:
	return counts.duplicate()


func from_dict(d: Dictionary) -> void:
	counts.clear()
	for id: String in d:
		counts[id] = int(d[id])
	changed.emit()
