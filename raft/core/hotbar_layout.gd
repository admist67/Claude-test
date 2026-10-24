class_name HotbarLayout
extends RefCounted
## The player's own hotbar: the order of its slots and the items kept off it. An item
## carried for the first time joins at the end.

var order: Array[String] = []
var hidden: Array[String] = []


## The hotbar, in order, out of `have` (every hotbar item the player carries).
func slots(have: Array[String]) -> Array[String]:
	for id in have:
		if not id in order:
			order.append(id)
	var out: Array[String] = []
	for id in order:
		if id in have and not id in hidden:
			out.append(id)
	return out


## Trades places; with a hidden item it also trades visibility (it comes back in a's slot).
func swap(a: String, b: String) -> void:
	var i := order.find(a)
	var j := order.find(b)
	if i < 0 or j < 0 or i == j:
		return
	order[i] = b
	order[j] = a
	if (a in hidden) != (b in hidden):
		for id: String in [a, b]:
			if id in hidden:
				hidden.erase(id)
			else:
				hidden.append(id)


func hide(id: String) -> void:
	if not id in hidden:
		hidden.append(id)


## Back on the hotbar, at its end.
func unhide(id: String) -> void:
	hidden.erase(id)
	order.erase(id)
	order.append(id)


func to_dict() -> Dictionary:
	return {"order": order.duplicate(), "hidden": hidden.duplicate()}


func from_dict(d: Dictionary) -> void:
	order.assign(d.get("order", []))
	hidden.assign(d.get("hidden", []))
