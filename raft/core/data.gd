extends Node
## Autoload "Data": tuning numbers and content tables from data/*.json.

var b: Dictionary = {}
var items: Dictionary = {}
var recipes: Array = []
var debris: Array = []
var goals: Array = []
var build: Array = []
var build_by_id: Dictionary = {}
## Live multipliers from the pause-menu tuning sliders (playtest knobs).
var tune := {"look": 1.0, "hunger": 1.0, "debris": 1.0, "hook": 1.0, "time": 1.0}


func _ready() -> void:
	b = load_json("res://data/balance.json")
	for it: Dictionary in load_json("res://data/items.json")["items"]:
		items[it["id"]] = it
	recipes = load_json("res://data/recipes.json")["recipes"]
	debris = load_json("res://data/debris.json")["debris"]
	goals = load_json("res://data/goals.json")["goals"]
	build = load_json("res://data/buildables.json")["build"]
	for d: Dictionary in build:
		build_by_id[d["id"]] = d


static func load_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func item(id: String) -> Dictionary:
	return items.get(id, {})


func item_name(id: String) -> String:
	return item(id).get("name", id)
