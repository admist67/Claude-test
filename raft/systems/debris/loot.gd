class_name Loot
## Rolls a debris loot table: def {"loot": [{"item", "n": [min, max], "w"}], "rolls"?}.


static func roll(def: Dictionary, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var table: Array = def["loot"]
	var total := 0.0
	for e: Dictionary in table:
		total += float(e["w"])
	for i in int(def.get("rolls", 1)):
		var r := rng.randf() * total
		for e: Dictionary in table:
			r -= float(e["w"])
			if r <= 0.0:
				out.append([e["item"], rng.randi_range(int(e["n"][0]), int(e["n"][1]))])
				break
	return out
