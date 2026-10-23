class_name Order
extends RefCounted
## A customer's order and the pure formulas that judge and price what was served.

var meat := 1
var items: Array[String] = []   # veggie ids, then one sauce id


static func generate(rng: RandomNumberGenerator, defs: Array, ctype: Dictionary, bal: Dictionary) -> Order:
	var o := Order.new()
	var veg: Array = []
	var sauces: Array = []
	for ing in defs:
		if ing["kind"] == "veg":
			veg.append(ing["id"])
		elif ing["kind"] == "sauce":
			sauces.append(ing["id"])
	for i in range(veg.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = veg[i]
		veg[i] = veg[j]
		veg[j] = tmp
	var vmin := int(ctype.get("veg_min", bal["order_veg_min"]))
	var vmax := int(ctype.get("veg_max", bal["order_veg_max"]))
	var n := clampi(rng.randi_range(vmin, vmax), 0, veg.size())
	for i in n:
		o.items.append(veg[i])
	if not sauces.is_empty():
		o.items.append(sauces[rng.randi_range(0, sauces.size() - 1)])
	var dm := float(ctype.get("double_meat_chance", bal["double_meat_chance"]))
	o.meat = 2 if rng.randf() < dm else 1
	return o


func price(bal: Dictionary) -> int:
	return int(bal["price_base"]) + int(bal["price_per_item"]) * items.size() \
		+ int(bal["price_extra_meat"]) * (meat - 1)


static func toast_state(t: float, bal: Dictionary) -> String:
	var from := float(bal["grill_perfect_from"])
	if t < from * 0.5:
		return "raw"
	if t < from:
		return "under"
	if t <= float(bal["grill_perfect_to"]):
		return "perfect"
	if t < float(bal["grill_burnt_at"]):
		return "over"
	return "burnt"


## made = {"meat": int, "items": Array, "toast": float seconds on the grill}
func evaluate(made: Dictionary, bal: Dictionary) -> Dictionary:
	var made_items: Array = made["items"]
	var missing := 0
	var extra := 0
	for id in items:
		if not made_items.has(id):
			missing += 1
	for id in made_items:
		if not items.has(id):
			extra += 1
	var acc := 1.0 - missing * float(bal["penalty_missing"]) - extra * float(bal["penalty_extra"])
	var made_meat := int(made["meat"])
	if made_meat == 0:
		acc -= float(bal["penalty_missing"])
	else:
		acc -= absi(made_meat - meat) * float(bal["penalty_meat_count"])
	acc = clampf(acc, 0.0, 1.0)
	var state := toast_state(float(made["toast"]), bal)
	var tq := float(bal["toast_quality"][state])
	return {"quality": acc * tq, "accuracy": acc, "toast": state, "missing": missing, "extra": extra}


## Returns {"refused": bool, "pay": int, "tip": int, "stars": int}.
func payment(quality: float, patience_frac: float, tip_mult: float, refuse_below: float, bal: Dictionary) -> Dictionary:
	if quality < refuse_below:
		return {"refused": true, "pay": 0, "tip": 0, "stars": 1}
	var p := price(bal)
	var pay := roundi(p * (0.6 + 0.4 * quality))
	var tip := roundi(p * float(bal["tip_max_share"]) * quality * clampf(patience_frac, 0.0, 1.0) * tip_mult)
	return {"refused": false, "pay": pay, "tip": tip, "stars": clampi(roundi(quality * 5.0), 1, 5)}
