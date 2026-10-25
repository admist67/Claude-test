class_name Durability
extends RefCounted
## Wear on tools: uses left per tool id ("durability" in data/items.json is a new tool's
## full count). A tool with no entry is new; when it breaks the entry goes, so the next one
## made is new again.

var left: Dictionary = {}


func uses_left(id: String, full: int) -> int:
	return int(left.get(id, full))


func ratio(id: String, full: int) -> float:
	return clampf(float(uses_left(id, full)) / maxf(1.0, full), 0.0, 1.0)


## Spends `n` uses. Returns true when the tool just broke.
func use(id: String, n: int, full: int) -> bool:
	var l := uses_left(id, full) - n
	if l <= 0:
		left.erase(id)
		return true
	left[id] = l
	return false


## A freshly made tool.
func renew(id: String) -> void:
	left.erase(id)


func to_dict() -> Dictionary:
	return left.duplicate()


func from_dict(d: Dictionary) -> void:
	left.clear()
	for id: String in d:
		left[id] = int(d[id])
