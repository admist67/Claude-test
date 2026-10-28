class_name Vitals
extends RefCounted
## Hunger, thirst and health (0..100). Pure logic: the game calls tick() every frame.

var hunger := 100.0
var thirst := 100.0
var health := 100.0
var cause := ""          # what is hurting right now: "hunger", "thirst" or ""


## Advances time; mult scales hunger/thirst speed (tuning knob). Returns true on death.
func tick(delta: float, v: Dictionary, mult := 1.0) -> bool:
	var m := delta / 60.0
	hunger = maxf(0.0, hunger - float(v["hunger_per_min"]) * mult * m)
	thirst = maxf(0.0, thirst - float(v["thirst_per_min"]) * mult * m)
	cause = ""
	if thirst <= 0.0:
		cause = "thirst"
		health -= float(v["starve_dmg_per_min"]) * m
	if hunger <= 0.0:
		cause = "hunger" if cause == "" else cause
		health -= float(v["starve_dmg_per_min"]) * m
	if hunger > float(v["regen_above"]) and thirst > float(v["regen_above"]):
		health = minf(100.0, health + float(v["regen_per_min"]) * m)
	health = maxf(0.0, health)
	return health <= 0.0


func consume(def: Dictionary) -> void:
	hunger = minf(100.0, hunger + float(def.get("food", 0)))
	thirst = clampf(thirst + float(def.get("water", 0)), 0.0, 100.0)
	health = minf(100.0, health + float(def.get("health", 0)))


func damage(n: float, why: String) -> bool:
	health = maxf(0.0, health - n)
	cause = why
	return health <= 0.0


func respawn(v: Dictionary) -> void:
	hunger = float(v["respawn_stats"])
	thirst = float(v["respawn_stats"])
	health = float(v["respawn_stats"])
	cause = ""


func to_dict() -> Dictionary:
	return {"hunger": hunger, "thirst": thirst, "health": health}


func from_dict(d: Dictionary) -> void:
	hunger = float(d.get("hunger", 100.0))
	thirst = float(d.get("thirst", 100.0))
	health = float(d.get("health", 100.0))
