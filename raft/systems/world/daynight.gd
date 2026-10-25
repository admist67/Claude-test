class_name DayNight
extends Node
## Time of day: moves the sun and moon and recolors the sky, light, fog and water.
## phase 0..1 over one day; 0 = dawn, 0.5 = dusk. Keys in data/balance.json "day".

signal new_day(day: int)

const KEYS := [
	# phase, sky top, horizon, sun color, sun energy, ambient, light level
	[0.0, "#2c3e66", "#f0a070", "#ffb070", 0.35, "#6a6e8a", 0.55],
	[0.08, "#3f86c9", "#bfe0ee", "#fff1d8", 0.85, "#9cc4d4", 0.9],
	[0.25, "#2f7fd0", "#a9dbee", "#fff6e6", 1.0, "#9fc6d6", 1.0],
	[0.42, "#3f86c9", "#c8e2ee", "#ffe9c8", 0.85, "#9cbfd0", 0.9],
	[0.5, "#34406e", "#f39060", "#ff9050", 0.35, "#7a6a80", 0.55],
	[0.56, "#0b1226", "#28345a", "#9fb4ff", 0.0, "#2a3450", 0.22],
	[0.94, "#0b1226", "#28345a", "#9fb4ff", 0.0, "#2a3450", 0.22],
	[1.0, "#2c3e66", "#f0a070", "#ffb070", 0.35, "#6a6e8a", 0.55],
]

var phase := 0.12
var day := 1
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial
var ocean: Ocean
var storm: Storm
var cfg: Dictionary
var _t := 0.0


func _ready() -> void:
	cfg = Data.b["day"]


func is_night() -> bool:
	return phase > 0.53 and phase < 0.97


## Lanterns burn a little longer than the night: from before sunset to after dawn.
func lamps_on() -> bool:
	var l: Dictionary = Data.b["lamps"]
	return phase > float(l["on"]) or phase < float(l["off"])


func clock_text() -> String:
	var hours := fposmod(phase * 24.0 + 6.0, 24.0)
	return "%02d:%02d" % [int(hours), int(fmod(hours, 1.0) * 60.0)]


func _process(delta: float) -> void:
	_t += delta
	# Day lasts day_seconds, night is shorter: walk the phase at two speeds.
	var day_len := float(cfg["day_seconds"])
	var night_len := float(cfg["night_seconds"])
	var speed := (0.5 / day_len) if phase < 0.5 else (0.5 / night_len)
	phase += delta * speed * float(Data.tune.get("time", 1.0))
	if phase >= 1.0:
		phase -= 1.0
		day += 1
		new_day.emit(day)
	apply()


func apply() -> void:
	var k := _sample()
	var sk := storm.k if storm else 0.0
	var fl := storm.flash if storm else 0.0
	if sk > 0.0:
		var grey := Color("#4a535c")
		k["top"] = k["top"].lerp(Color("#2c343c"), sk * 0.85)
		k["horizon"] = k["horizon"].lerp(grey, sk * 0.75)
		k["ambient"] = k["ambient"].lerp(Color("#5a646e"), sk * 0.6)
		k["energy"] = k["energy"] * (1.0 - 0.8 * sk)
		k["light"] = k["light"] * (1.0 - 0.45 * sk)
	var sun_angle := phase * TAU            # 0 rising in the east, PI setting in the west
	var sun_dir := Vector3(cos(sun_angle) * 0.75, sin(sun_angle), -0.45).normalized()
	var moon_dir := -sun_dir
	sun.look_at_from_position(Vector3.ZERO, -sun_dir if sun_dir.y > -0.05 else Vector3(0, -1, 0.01), Vector3.UP)
	sun.light_color = k["sun"]
	sun.light_energy = k["energy"] * 0.65
	sun.visible = sun.light_energy > 0.01
	var night := clampf((0.6 - float(k["light"])) / 0.38, 0.0, 1.0)
	moon.look_at_from_position(Vector3.ZERO, -moon_dir if moon_dir.y > 0.0 else Vector3(0.2, -1, 0.1), Vector3.UP)
	moon.light_energy = 0.22 * night
	moon.visible = night > 0.05
	env.ambient_light_color = k["ambient"]
	env.ambient_light_energy = 0.55 + fl * 1.6
	env.fog_light_color = k["horizon"]
	sky_mat.set_shader_parameter("top_color", _v(k["top"]))
	sky_mat.set_shader_parameter("horizon_color", _v(k["horizon"]))
	sky_mat.set_shader_parameter("sun_dir", sun_dir)
	sky_mat.set_shader_parameter("sun_color", _v(k["sun"]) * clampf(k["energy"] * 1.2, 0.0, 1.0))
	sky_mat.set_shader_parameter("moon_dir", moon_dir)
	sky_mat.set_shader_parameter("night", night)
	sky_mat.set_shader_parameter("cloud_lit", _v(Color.WHITE.lerp(k["sun"], 0.35)) * clampf(k["light"], 0.12, 1.0))
	sky_mat.set_shader_parameter("cloud_shade", _v(k["horizon"].lerp(Color("#8090a0"), 0.5)) * clampf(k["light"], 0.1, 1.0))
	sky_mat.set_shader_parameter("t", _t)
	sky_mat.set_shader_parameter("flash", fl)
	sky_mat.set_shader_parameter("cloud_cover", 0.48 + 0.45 * sk)
	ocean.set_sky(k["top"], k["horizon"], k["light"])


func _v(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


func _sample() -> Dictionary:
	var i := 0
	while i < KEYS.size() - 2 and phase >= float(KEYS[i + 1][0]):
		i += 1
	var a: Array = KEYS[i]
	var b: Array = KEYS[i + 1]
	var u := clampf((phase - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0])), 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	return {
		"top": Color(a[1]).lerp(Color(b[1]), u),
		"horizon": Color(a[2]).lerp(Color(b[2]), u),
		"sun": Color(a[3]).lerp(Color(b[3]), u),
		"energy": lerpf(a[4], b[4], u),
		"ambient": Color(a[5]).lerp(Color(b[5]), u),
		"light": lerpf(a[6], b[6], u),
	}
