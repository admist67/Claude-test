extends RefCounted
## Daily quests: three goals picked for the day from data/quests.json, with progress and a
## money reward when done. The game reports events; finished quests are returned so the
## game can celebrate and pay.

var list: Array = []   # {id, text, target, progress, done, reward, arg}


## ctx: {"day", "cafe": bool, "recipe": bool, "types": [[type_id, name], ...]}
func pick(ctx: Dictionary, rng: RandomNumberGenerator, count: int) -> void:
	list.clear()
	var day: int = ctx["day"]
	var pool: Array = []
	for q in Bal.quests:
		if int(q.get("min_day", 1)) > day:
			continue
		if q.get("needs", "") == "cafe" and not ctx["cafe"]:
			continue
		if q.get("needs", "") == "recipe" and not ctx["recipe"]:
			continue
		if q["id"] == "type" and ctx["types"].is_empty():
			continue
		pool.append(q)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	for q in pool.slice(0, count):
		var target := mini(int(q["max"]), int(round(float(q["base"]) + float(q["per_day"]) * (day - 1))))
		var item := {"id": q["id"], "target": maxi(1, target), "progress": 0, "done": false, "reward": int(q["reward"]), "arg": ""}
		if q["id"] == "type":
			var t: Array = ctx["types"][rng.randi_range(0, ctx["types"].size() - 1)]
			item["arg"] = t[0]
			item["text"] = q["text"] % [t[1], item["target"]]
		elif q["id"] == "no_lost":
			item["text"] = q["text"]
		else:
			item["text"] = q["text"] % item["target"]
		list.append(item)


## Adds progress to quests of this id (and arg); returns the ones that just got done.
func bump(id: String, amount := 1, arg := "") -> Array:
	var done: Array = []
	for q in list:
		if q["done"] or q["id"] != id or (q["arg"] != "" and q["arg"] != arg):
			continue
		q["progress"] = mini(q["target"], q["progress"] + amount)
		if q["progress"] >= q["target"]:
			q["done"] = true
			done.append(q)
	return done


## For "reach at least N" goals such as the combo.
func reach(id: String, value: int) -> Array:
	var done: Array = []
	for q in list:
		if q["done"] or q["id"] != id:
			continue
		q["progress"] = mini(q["target"], maxi(q["progress"], value))
		if q["progress"] >= q["target"]:
			q["done"] = true
			done.append(q)
	return done


## A customer left angry: the "nobody leaves angry" goal fails for today.
func fail(id: String) -> void:
	for q in list:
		if q["id"] == id and not q["done"]:
			q["failed"] = true


## End of shift: "nobody leaves angry" counts if it never failed.
func finish() -> Array:
	var done: Array = []
	for q in list:
		if q["id"] == "no_lost" and not q["done"] and not q.get("failed", false):
			q["done"] = true
			q["progress"] = 1
			done.append(q)
	return done
