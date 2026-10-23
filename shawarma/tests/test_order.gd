extends SceneTree
## Order scoring and payment formulas. Run: godot --headless --path . -s res://tests/test_order.gd

var fails := 0


func check(name: String, cond: bool) -> void:
	if not cond:
		fails += 1
		printerr("FAIL: " + name)


func _init() -> void:
	var bal: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
	var o := Order.new()
	o.meat = 1
	o.items.assign(["tomato", "cabbage", "garlic"])
	var perfect_t := (float(bal["grill_perfect_from"]) + float(bal["grill_perfect_to"])) / 2.0
	var ev := o.evaluate({"meat": 1, "items": ["garlic", "tomato", "cabbage"], "toast": perfect_t}, bal)
	check("exact order is perfect", is_equal_approx(ev["quality"], 1.0) and ev["toast"] == "perfect")
	ev = o.evaluate({"meat": 1, "items": ["tomato", "garlic"], "toast": perfect_t}, bal)
	check("missing item penalty", is_equal_approx(ev["accuracy"], 1.0 - float(bal["penalty_missing"])))
	ev = o.evaluate({"meat": 0, "items": ["tomato", "cabbage", "garlic"], "toast": perfect_t}, bal)
	check("no meat penalty", ev["accuracy"] < 1.0)
	ev = o.evaluate({"meat": 1, "items": ["tomato", "cabbage", "garlic"], "toast": float(bal["grill_burnt_at"]) + 1.0}, bal)
	check("burnt lowers quality", ev["toast"] == "burnt" and ev["quality"] < 0.5)
	var pay := o.payment(1.0, 1.0, 1.0, 0.35, bal)
	check("full price on perfect", pay["pay"] == o.price(bal) and pay["tip"] > 0 and pay["stars"] == 5)
	pay = o.payment(0.2, 1.0, 1.0, 0.35, bal)
	check("refuse below threshold", pay["refused"] and pay["pay"] == 0)
	pay = o.payment(1.0, 0.0, 1.0, 0.35, bal)
	check("no tip when patience ran out", pay["tip"] == 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var defs: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/ingredients.json"))["ingredients"]
	for i in 50:
		var g := Order.generate(rng, defs, {}, bal)
		var sauces := 0
		for id in g.items:
			for d in defs:
				if d["id"] == id and d["kind"] == "sauce":
					sauces += 1
		check("one sauce per order", sauces == 1)
		check("order size", g.items.size() >= 2 and g.items.size() <= 4)
	print("tests: %s" % ("OK" if fails == 0 else "%d failed" % fails))
	quit(1 if fails > 0 else 0)
