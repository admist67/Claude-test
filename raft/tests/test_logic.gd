extends SceneTree
## Survival, crafting, loot and save formats. Run: godot --headless --path . -s res://tests/test_logic.gd

var fails := 0


func check(name: String, cond: bool) -> void:
	if not cond:
		fails += 1
		printerr("FAIL: " + name)


func _json(p: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(p))


func _init() -> void:
	var bal := _json("res://data/balance.json")
	var v_cfg: Dictionary = bal["vitals"]
	var items := {}
	for it: Dictionary in _json("res://data/items.json")["items"]:
		items[it["id"]] = it

	# Vitals: thirst runs out first, then health drains, death is reported once health hits 0.
	var v := Vitals.new()
	var minutes_to_dry := 100.0 / float(v_cfg["thirst_per_min"])
	check("not dead while drinking", not v.tick(minutes_to_dry * 60.0 - 1.0, v_cfg))
	check("thirst nearly empty", v.thirst < 1.0 and v.hunger > 0.0 and v.health == 100.0)
	v.tick(2.0, v_cfg)
	check("thirst hurts", v.cause == "thirst" and v.health < 100.0)
	var died := false
	for i in 2000:
		if v.tick(1.0, v_cfg):
			died = true
			break
	check("starving kills", died and v.health == 0.0)
	v.respawn(v_cfg)
	check("respawn stats", v.health == float(v_cfg["respawn_stats"]) and v.cause == "")
	v.consume(items["water"])
	check("water quenches", v.thirst == float(v_cfg["respawn_stats"]) + float(items["water"]["water"]))
	v.consume(items["water"])
	v.consume(items["water"])
	check("thirst capped", v.thirst == 100.0)
	var r := Vitals.new()
	r.health = 50.0
	r.tick(60.0, v_cfg)
	check("regen when fed", r.health > 50.0)
	var z := Vitals.new()
	z.tick(600.0, v_cfg, 0.0)
	check("tuning 0 freezes hunger", z.hunger == 100.0 and z.thirst == 100.0)

	# Inventory and crafting.
	var inv := Inventory.new()
	var recipes: Array = _json("res://data/recipes.json")["recipes"]
	var rope: Dictionary = recipes.filter(func(x: Dictionary) -> bool: return x["id"] == "rope")[0]
	var hammer: Dictionary = recipes.filter(func(x: Dictionary) -> bool: return x["id"] == "hammer")[0]
	check("cannot craft from nothing", not inv.craft(rope))
	inv.add("leaf", 5)
	check("rope crafted", inv.craft(rope) and inv.count("rope") == 1 and inv.count("leaf") == 3)
	inv.add("plank", 3)
	inv.add("rope", 1)
	check("hammer crafted", inv.craft(hammer) and inv.count("hammer") == 1 and inv.count("plank") == 0 and inv.count("rope") == 0)
	inv.add("plank", 3)
	inv.add("rope", 2)
	check("hammer only once", not inv.can_craft(hammer))
	check("pay all or nothing", not inv.pay({"plank": 3, "plastic": 1}) and inv.count("plank") == 3)
	inv.add("coconut", 5)
	inv.lose_share(float(v_cfg["death_keep"]), items)
	check("death keeps tools", inv.count("hammer") == 1)
	check("death halves the rest", inv.count("coconut") == 2 and inv.count("plank") == 1)
	var inv2 := Inventory.new()
	inv2.from_dict(inv.to_dict())
	check("inventory round trip", inv2.to_dict() == inv.to_dict())

	# Every item mentioned in data exists.
	for rec: Dictionary in recipes:
		check("recipe item %s" % rec["id"], items.has(rec["id"]))
		for id: String in rec["cost"]:
			check("recipe cost %s" % id, items.has(id))
	var build: Array = _json("res://data/buildables.json")["build"]
	for d: Dictionary in build:
		for id: String in d["cost"]:
			check("build cost %s" % id, items.has(id))
		for id: String in d.get("fuel", {}):
			check("fuel %s" % id, items.has(id) and float(d["fuel"][id]) >= float(d["time"]))
		for id: String in d.get("cook", {}):
			check("cook %s" % id, items.has(id) and items.has(d["cook"][id]))
		if d.has("out"):
			check("station out %s" % d["out"], items.has(d["out"]))
	for e: Dictionary in bal["fishing"]["catch"]:
		check("catch %s" % e["item"], items.has(e["item"]))
	var stats := ["tiles", "minutes", "days", "barrels", "fish", "cooked", "shark_driven", "planted", "harvest", "slept", "storms", "bait_used", "upper_built"]
	for g: Dictionary in _json("res://data/goals.json")["goals"]:
		var st: String = g["stat"]
		var known := st in stats or st.begins_with("built_") or st.begins_with("got_") or st.begins_with("made_")
		check("goal stat %s" % st, known)
		if st.begins_with("got_") or st.begins_with("made_"):
			check("goal item %s" % st, items.has(st.split("_", true, 1)[1]))

	# Loot tables give known items in range; barrels roll twice.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for d: Dictionary in _json("res://data/debris.json")["debris"]:
		for i in 200:
			var loot := Loot.roll(d, rng)
			check("loot count %s" % d["id"], loot.size() == int(d.get("rolls", 1)))
			for e: Array in loot:
				check("loot item %s" % e[0], items.has(e[0]) and int(e[1]) >= 1)

	# Save format: cells survive JSON.
	var cells: Array = [Vector2i(0, 0), Vector2i(-3, 2), Vector2i(5, -1)]
	var back := SaveGame.cells_from_json(JSON.parse_string(JSON.stringify(SaveGame.cells_to_json(cells))))
	check("cells round trip", Array(back) == cells)

	# Hotbar layout: new items join at the end, swaps and hiding survive a save.
	var hl := HotbarLayout.new()
	var have: Array[String] = ["hook", "rod", "fish"]
	check("hotbar default order", ",".join(hl.slots(have)) == "hook,rod,fish")
	hl.swap("hook", "fish")
	hl.hide("rod")
	check("hotbar swap and hide", ",".join(hl.slots(have)) == "fish,hook")
	var hl2 := HotbarLayout.new()
	hl2.from_dict(JSON.parse_string(JSON.stringify(hl.to_dict())))
	have.append("spear")
	check("hotbar save + new item at end", ",".join(hl2.slots(have)) == "fish,hook,spear")
	hl2.swap("hook", "rod")
	check("swap with hidden trades visibility", ",".join(hl2.slots(have)) == "fish,rod,spear" and "hook" in hl2.hidden)
	hl2.unhide("hook")
	check("unhidden goes last", ",".join(hl2.slots(have)) == "fish,rod,spear,hook")

	print("tests: %s" % ("OK" if fails == 0 else "%d failed" % fails))
	quit(1 if fails > 0 else 0)
