extends Node
## Autoload "Bal": tuning numbers and content tables from data/*.json.

var b: Dictionary = {}
var ingredients: Array = []
var customers: Array = []
var days: Array = []
var ing_by_id: Dictionary = {}
## Live multipliers from the pause-menu tuning sliders (playtest knobs).
var tune := {"patience": 1.0, "spawn": 1.0, "grill": 1.0, "look": 1.0}


func _ready() -> void:
	b = load_json("res://data/balance.json")
	ingredients = load_json("res://data/ingredients.json")["ingredients"]
	customers = load_json("res://data/customers.json")["customers"]
	days = load_json("res://data/days.json")["days"]
	for ing in ingredients:
		ing_by_id[ing["id"]] = ing


static func load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


func f(key: String) -> float:
	return float(b[key])


func color(id: String) -> Color:
	return Color(ing_by_id[id]["color"])


func ing_name(id: String) -> String:
	return ing_by_id[id]["name"]


func unlocked_on(day: int) -> Array:
	var ids: Array = []
	for ing in ingredients:
		if int(ing["unlock_day"]) <= day:
			ids.append(ing["id"])
	return ids


func note_for(day: int) -> String:
	for d in days:
		if int(d["day"]) == day:
			return d["note"]
	return "Новый день, новые клиенты. Не подведи! — дядя Рома"
