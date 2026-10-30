class_name GearLooks
## The sail (mast and yards; the cloth is its own mesh hanging from the top yard so it can
## unfurl), the fish drying rack, the scarecrow, flippers, nails, a first-aid kit, the
## crossbow (pointing along -Z) and its bolt (along +Y).

const IDS := ["sail", "sail_cloth", "sail_icon", "rack", "scarecrow", "flippers", "nails", "medkit", "crossbow", "crossbow_icon", "bolt",
		"big_grill"]
const YARD := 3.25                # height of the top yard the cloth hangs from
const DROP := 2.15                # how far the unfurled cloth hangs
const WOOD := Color(1, 0.93, 0.84)
const DARK := Color(1, 0.95, 0.9)
const CLOTH := Color("#efe2c2")
const STRAW := Color("#e2c46a")
const ROPE := Color(1, 0.97, 0.9)


## Builds `id` into `st`. Returns true when it needs the leaf (cut-out) material.
static func build(st: SurfaceTool, id: String) -> bool:
	match id:
		"sail":
			_mast(st)
		"sail_cloth":
			_cloth(st, Vector3.ZERO)
		"sail_icon":
			_mast(st)
			_cloth(st, Vector3(0, YARD, 0))
		"rack":
			_rack(st)
		"big_grill":
			_big_grill(st)
		"crossbow":
			_crossbow(st)
		"crossbow_icon":
			_crossbow(st)
			_bolt(st, Vector3(0, 0.045, -0.12), Vector3(-PI / 2.0, 0, 0))
		"bolt":
			_bolt(st, Vector3.ZERO, Vector3.ZERO)
		"scarecrow":
			_scarecrow(st)
		"flippers":
			for f in 2:
				_flipper(st, Vector3(-0.07 + f * 0.15, f * 0.03, f * 0.05), -0.12 + f * 0.24)
		"nails":
			var rng := RandomNumberGenerator.new()
			rng.seed = 5
			for i in 7:
				var at := Vector3(rng.randf_range(-0.08, 0.08), 0.012 + i * 0.008, rng.randf_range(-0.08, 0.08))
				var rot := Vector3(PI / 2.0, rng.randf_range(0, TAU), rng.randf_range(-0.2, 0.2))
				var b := Basis.from_euler(rot)
				Mk.st_cyl(st, 0.009, 0.15, at, Color(0.75, 0.76, 0.8), "metal", rot, 6)
				Mk.st_cyl(st, 0.02, 0.008, at + b * Vector3(0, 0.075, 0), Color(0.62, 0.63, 0.68), "metal", rot, 10)
				Mk.st_box(st, Vector3(0.008, 0.02, 0.008), at + b * Vector3(0, -0.083, 0), Color(0.7, 0.7, 0.74), "metal", rot)
		"medkit":
			Mk.st_box(st, Vector3(0.28, 0.18, 0.13), Vector3(0, 0.09, 0), Color("#f4f2ec"), "plastic")
			Mk.st_box(st, Vector3(0.285, 0.02, 0.135), Vector3(0, 0.125, 0), Color("#d9d6cc"), "plastic")
			Mk.st_box(st, Vector3(0.1, 0.03, 0.03), Vector3(0, 0.195, 0), Color("#d8352a"), "plastic")
			for x: float in [-0.055, 0.055]:
				Mk.st_box(st, Vector3(0.02, 0.03, 0.03), Vector3(x, 0.185, 0), Color("#d8352a"), "plastic")
			for z: float in [0.066, -0.066]:
				Mk.st_box(st, Vector3(0.025, 0.08, 0.004), Vector3(0, 0.075, z), Color("#d8352a"), "white")
				Mk.st_box(st, Vector3(0.08, 0.025, 0.004), Vector3(0, 0.075, z), Color("#d8352a"), "white")
			for x: float in [-0.1, 0.1]:
				Mk.st_box(st, Vector3(0.03, 0.03, 0.01), Vector3(x, 0.125, 0.068), Color(0.7, 0.7, 0.72), "metal")
	return false


## A rod of radius `r` from `a` to `b`.
static func _bar(st: SurfaceTool, a: Vector3, b: Vector3, r: float, c: Color, cell: String, seg := 8) -> void:
	var d := b - a
	var up := d.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var basis := Basis(side, up, side.cross(up))
	Mk.st_cyl(st, r, d.length(), (a + b) / 2.0, c, cell, basis.get_euler(), seg, 0.8)


## The mast on its foot, the top yard with the furled sail tied to it, the bottom boom,
## stays down to the deck and a red pennant on top.
static func _mast(st: SurfaceTool) -> void:
	Mk.st_box(st, Vector3(0.5, 0.12, 0.5), Vector3(0, 0.06, 0), DARK, "wood_dark")
	for a in 4:
		var yaw := a * PI / 2.0
		Mk.st_box(st, Vector3(0.08, 0.3, 0.2), Basis(Vector3.UP, yaw) * Vector3(0, 0.27, 0.14), DARK, "wood_dark", Vector3(0, yaw, 0))
	Mk.st_cyl(st, 0.07, 3.75, Vector3(0, 1.875, 0), WOOD, "wood_warm", Vector3.ZERO, 10, 1.2)
	for y: float in [0.5, 1.15, 3.42]:
		Mk.st_cyl(st, 0.08, 0.07, Vector3(0, y, 0), Color(1, 0.96, 0.9), "rope", Vector3.ZERO, 10, 0.6)
	var rz := Vector3(0, 0, PI / 2.0)
	Mk.st_cyl(st, 0.045, 2.0, Vector3(0, YARD + 0.06, 0.06), WOOD, "wood_warm", rz, 8)
	Mk.st_cyl(st, 0.04, 1.8, Vector3(0, YARD - DROP + 0.02, 0.06), WOOD, "wood_warm", rz, 8)
	Mk.st_cyl(st, 0.075, 1.75, Vector3(0, YARD - 0.05, 0.1), CLOTH.darkened(0.08), "canvas", rz, 10, 0.8)
	for x: float in [-0.6, -0.2, 0.2, 0.6]:
		Mk.st_cyl(st, 0.082, 0.04, Vector3(x, YARD - 0.05, 0.1), Color(1, 0.96, 0.9), "rope", rz, 10, 0.6)
	for x: float in [-0.95, 0.95]:
		_bar(st, Vector3(x, YARD + 0.06, 0.06), Vector3(x * 0.55, 0.13, -0.55), 0.012, Color(1, 0.96, 0.9), "rope", 5)
	_bar(st, Vector3(0, 3.7, 0), Vector3(0, 0.13, 0.6), 0.012, Color(1, 0.96, 0.9), "rope", 5)
	for i in 3:
		Mk.st_box(st, Vector3(0.32 - i * 0.09, 0.07 - i * 0.015, 0.012), Vector3(0.2 + i * 0.045, 3.66 - i * 0.004, 0), Color("#d8352a").darkened(i * 0.06), "canvas", Vector3.ZERO, 0.8)


## The unfurled sail hanging from the yard (`at`): a cream canvas with a red band, its
## belly pushed forward by the wind; both sides drawn.
static func _cloth(st: SurfaceTool, at: Vector3) -> void:
	var nx := 8
	var ny := 8
	var r := Mk.cell("canvas")
	var p := func(u: float, v: float) -> Vector3:
		var half := lerpf(0.86, 0.92, v)
		return at + Vector3((u - 0.5) * 2.0 * half, -v * DROP, 0.12 + 0.42 * sin(PI * u) * pow(sin(PI * minf(1.0, v * 0.85 + 0.12)), 0.8))
	for i in nx:
		for j in ny:
			var u0 := float(i) / nx
			var u1 := float(i + 1) / nx
			var v0 := float(j) / ny
			var v1 := float(j + 1) / ny
			var q: Array = [p.call(u0, v0), p.call(u1, v0), p.call(u1, v1), p.call(u0, v1)]
			var n: Vector3 = (q[1] - q[0]).cross(q[3] - q[0]).normalized()
			var band := v0 >= 0.5 and v0 < 0.72
			var c := Color("#c8432f") if band else CLOTH.darkened(0.05 * (i % 2))
			var uv := [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]
			for side: float in [1.0, -1.0]:
				st.set_color(c if side > 0.0 else c.darkened(0.15))
				st.set_normal(-n * side)
				var order := [0, 1, 2, 0, 2, 3] if side > 0.0 else [0, 2, 1, 0, 3, 2]
				for k: int in order:
					st.set_uv(r.position + uv[k] * r.size)
					st.add_vertex(q[k])


## Two A-frames, a top bar with hooks on strings, a pole for more fish below.
static func _rack(st: SurfaceTool) -> void:
	for x: float in [-0.5, 0.5]:
		for z: float in [-0.32, 0.32]:
			_bar(st, Vector3(x, 0.0, z), Vector3(x, 1.34, z * 0.1), 0.035, DARK, "wood_dark")
		Mk.st_box(st, Vector3(0.06, 0.06, 0.5), Vector3(x, 0.45, 0), DARK, "wood_dark")
	Mk.st_cyl(st, 0.035, 1.2, Vector3(0, 1.28, 0), WOOD, "wood_warm", Vector3(0, 0, PI / 2.0), 8)
	for x: float in [-0.5, 0.5]:
		Mk.st_cyl(st, 0.05, 0.08, Vector3(x, 1.28, 0), Color(1, 0.96, 0.9), "rope", Vector3(0, 0, PI / 2.0), 8, 0.6)
	for x: float in [-0.3, 0.0, 0.3]:
		Mk.st_box(st, Vector3(0.012, 0.16, 0.012), Vector3(x, 1.18, 0), Color(1, 0.96, 0.9), "rope", Vector3.ZERO, 0.6)
		Mk.st_box(st, Vector3(0.03, 0.012, 0.012), Vector3(x + 0.01, 1.1, 0), Color(0.6, 0.6, 0.64), "metal")
	# A thatch of palm leaves over the bar against the rain.
	for s: float in [-1.0, 1.0]:
		Mk.st_box(st, Vector3(1.3, 0.025, 0.42), Vector3(0, 1.47, s * 0.17), Color("#b8a058"), "canvas", Vector3(s * 0.5, 0, 0), 0.8)


static func _scarecrow(st: SurfaceTool) -> void:
	Mk.st_box(st, Vector3(0.36, 0.06, 0.36), Vector3(0, 0.03, 0), DARK, "wood_dark")
	Mk.st_box(st, Vector3(0.08, 1.9, 0.08), Vector3(0, 0.95, 0), DARK, "wood_dark")
	Mk.st_box(st, Vector3(1.15, 0.07, 0.07), Vector3(0, 1.45, 0), DARK, "wood_dark")
	# A plaid shirt stuffed with straw, a scarf, rope belt.
	Mk.st_box(st, Vector3(0.44, 0.56, 0.24), Vector3(0, 1.22, 0), Color("#4f78b0"), "canvas", Vector3.ZERO, 0.6)
	for x: float in [-0.12, 0.0, 0.12]:
		Mk.st_box(st, Vector3(0.03, 0.56, 0.245), Vector3(x, 1.22, 0), Color("#2f4f80"), "canvas", Vector3.ZERO, 0.6)
	Mk.st_box(st, Vector3(0.45, 0.04, 0.25), Vector3(0, 1.05, 0), Color("#2f4f80"), "canvas", Vector3.ZERO, 0.6)
	Mk.st_box(st, Vector3(0.46, 0.05, 0.255), Vector3(0, 1.0, 0), Color(1, 0.95, 0.88), "rope", Vector3.ZERO, 0.6)
	for s: float in [-1.0, 1.0]:
		Mk.st_box(st, Vector3(0.38, 0.17, 0.17), Vector3(s * 0.38, 1.44, 0), Color("#4f78b0"), "canvas", Vector3(0, 0, s * -0.08), 0.6)
		for k in 3:
			var at := Vector3(s * (0.61 + 0.03 * k), 1.44 + (k - 1) * 0.04, (k - 1) * 0.03)
			Mk.st_box(st, Vector3(0.12, 0.025, 0.025), at, STRAW, "rope", Vector3(0, (k - 1) * 0.4, s * (0.3 - k * 0.3)), 0.6)
	for k in 5:
		Mk.st_box(st, Vector3(0.025, 0.14, 0.025), Vector3(-0.16 + k * 0.08, 0.88, 0.05), STRAW, "rope", Vector3(0.2, 0, (k - 2) * 0.15), 0.6)
	Mk.st_cyl(st, 0.13, 0.06, Vector3(0, 1.53, 0), Color("#c8432f"), "canvas", Vector3.ZERO, 12, 0.6)
	# The sack head with button eyes and a stitched smile, a wide straw hat.
	Mk.st_cyl(st, 0.14, 0.26, Vector3(0, 1.7, 0), Color("#d9c08a"), "canvas", Vector3.ZERO, 12, 0.6, 0.18)
	for x: float in [-0.05, 0.05]:
		Mk.st_cyl(st, 0.022, 0.02, Vector3(x, 1.74, 0.15), Color(0.08, 0.08, 0.1), "plastic", Vector3(PI / 2.0, 0, 0), 8)
	for k in 5:
		Mk.st_box(st, Vector3(0.02, 0.008, 0.01), Vector3(-0.05 + k * 0.025, 1.645 - absf(k - 2) * -0.006, 0.15), Color(0.15, 0.1, 0.08), "white")
	Mk.st_cyl(st, 0.27, 0.025, Vector3(0, 1.84, 0), STRAW, "rope", Vector3(0.08, 0, 0.05), 16, 0.6)
	Mk.st_cyl(st, 0.14, 0.15, Vector3(0, 1.92, 0), STRAW.darkened(0.05), "rope", Vector3(0.08, 0, 0.05), 12, 0.6)
	Mk.st_cyl(st, 0.142, 0.03, Vector3(0, 1.88, 0), Color("#c8432f"), "canvas", Vector3(0.08, 0, 0.05), 12, 0.6)


## One flipper along +Z: a dark foot pocket and a ribbed yellow blade curling up at the tip.
static func _flipper(st: SurfaceTool, at: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var rot := Vector3(0, yaw, 0)
	var pocket := Color("#27384a")
	var blade := Color("#f2c230")
	Mk.st_box(st, Vector3(0.11, 0.07, 0.17), at + b * Vector3(0, 0.035, -0.12), pocket, "plastic", rot)
	Mk.st_box(st, Vector3(0.12, 0.02, 0.05), at + b * Vector3(0, 0.07, -0.19), pocket.lightened(0.1), "plastic", rot)
	Mk.st_box(st, Vector3(0.15, 0.014, 0.2), at + b * Vector3(0, 0.012, 0.06), blade, "plastic", rot)
	Mk.st_box(st, Vector3(0.17, 0.012, 0.12), at + b * Vector3(0, 0.03, 0.21), blade.lightened(0.08), "plastic", Vector3(-0.3, yaw, 0))
	for x: float in [-0.065, 0.065]:
		Mk.st_box(st, Vector3(0.016, 0.022, 0.3), at + b * Vector3(x, 0.022, 0.1), pocket, "plastic", rot)


## A crossbow pointing along -Z: a stock with a dropped butt and a pistol grip, a rail
## with a brass nut and a sight, a trigger and its guard, rope wraps on the fore-end, a bow
## of curved two-tone limbs with brass tips held by a steel band, the string drawn back to
## the nut and a steel stirrup at the front.
static func _crossbow(st: SurfaceTool) -> void:
	var walnut := Color(0.8, 0.58, 0.4)
	var steel := Color(0.66, 0.68, 0.72)
	var brass := Color("#c9a24a")
	var front := -0.25
	Mk.st_box(st, Vector3(0.048, 0.05, 0.3), Vector3(0, 0.0, -0.16), WOOD, "wood_warm")
	Mk.st_box(st, Vector3(0.058, 0.066, 0.24), Vector3(0, -0.004, 0.1), WOOD, "wood_warm")
	Mk.st_box(st, Vector3(0.062, 0.13, 0.2), Vector3(0, -0.05, 0.3), walnut, "wood_warm", Vector3(-0.22, 0, 0))
	Mk.st_box(st, Vector3(0.066, 0.14, 0.024), Vector3(0, -0.075, 0.405), Color(0.25, 0.18, 0.12), "wood_dark", Vector3(-0.22, 0, 0))
	Mk.st_box(st, Vector3(0.026, 0.008, 0.46), Vector3(0, 0.029, -0.07), Color(0.32, 0.22, 0.14), "wood_dark")
	Mk.st_box(st, Vector3(0.036, 0.026, 0.032), Vector3(0, 0.038, 0.06), brass, "metal")
	Mk.st_box(st, Vector3(0.008, 0.034, 0.008), Vector3(0, 0.05, 0.18), steel, "metal")
	Mk.st_box(st, Vector3(0.044, 0.13, 0.052), Vector3(0, -0.085, 0.16), walnut, "wood_warm", Vector3(0.3, 0, 0))
	Mk.st_box(st, Vector3(0.008, 0.045, 0.012), Vector3(0, -0.047, 0.085), steel, "metal", Vector3(0.35, 0, 0))
	Mk.st_box(st, Vector3(0.01, 0.01, 0.1), Vector3(0, -0.09, 0.085), steel, "metal")
	Mk.st_box(st, Vector3(0.01, 0.055, 0.01), Vector3(0, -0.062, 0.035), steel, "metal")
	for z: float in [-0.13, -0.09, -0.05]:
		Mk.st_cyl(st, 0.034, 0.022, Vector3(0, 0.0, z), ROPE, "rope", Vector3(PI / 2.0, 0, 0), 10, 0.6)
	for z: float in [0.0, 0.2]:
		for sx: float in [-1.0, 1.0]:
			Mk.st_box(st, Vector3(0.006, 0.014, 0.014), Vector3(sx * 0.03, 0.0, z), brass, "metal")
	# The bow: a steel band, then each limb in three pieces sweeping back.
	Mk.st_box(st, Vector3(0.09, 0.075, 0.06), Vector3(0, 0.012, front), steel, "metal")
	for sx: float in [-1.0, 1.0]:
		var p := Vector3(sx * 0.045, 0.022, front)
		var ang := 0.0
		for k in 3:
			var ln := 0.11 - k * 0.01
			ang += 0.17 + k * 0.08
			var dir := Vector3(sx * cos(ang), 0, sin(ang))
			var yaw := atan2(-dir.z, dir.x)
			var mid := p + dir * ln / 2.0
			Mk.st_box(st, Vector3(ln + 0.01, 0.03 - k * 0.004, 0.036 - k * 0.004), mid, WOOD.darkened(0.12), "wood_warm", Vector3(0, yaw, 0))
			Mk.st_box(st, Vector3(ln + 0.01, 0.008, 0.026 - k * 0.004), mid + Vector3(0, 0.017 - k * 0.002, 0), Color(0.3, 0.22, 0.16), "wood_dark", Vector3(0, yaw, 0))
			p += dir * ln
		Mk.st_box(st, Vector3(0.03, 0.028, 0.028), p, brass, "metal", Vector3(0, atan2(-sin(ang), sx * cos(ang)), 0))
		_bar(st, p + Vector3(0, 0.004, 0.0), Vector3(0, 0.044, 0.062), 0.0035, ROPE, "rope", 4)
	Mk.st_box(st, Vector3(0.11, 0.014, 0.014), Vector3(0, -0.02, front - 0.15), steel, "metal")
	for sx: float in [-0.055, 0.055]:
		Mk.st_box(st, Vector3(0.014, 0.014, 0.13), Vector3(sx, -0.01, front - 0.085), steel, "metal", Vector3(0.12, 0, 0))


## A bolt along +Y: a wooden shaft, an iron head, red and white fletching at the back.
static func _bolt(st: SurfaceTool, at: Vector3, rot: Vector3) -> void:
	var b := Basis.from_euler(rot)
	Mk.st_cyl(st, 0.007, 0.34, at, WOOD, "wood_warm", rot, 6)
	Mk.st_box(st, Vector3(0.022, 0.05, 0.008), at + b * Vector3(0, 0.19, 0), Color(0.7, 0.71, 0.75), "metal", rot)
	Mk.st_box(st, Vector3(0.008, 0.05, 0.022), at + b * Vector3(0, 0.185, 0), Color(0.7, 0.71, 0.75), "metal", rot)
	Mk.st_box(st, Vector3(0.04, 0.065, 0.002), at + b * Vector3(0, -0.14, 0), Color("#d8352a"), "canvas", rot, 0.5)
	Mk.st_box(st, Vector3(0.002, 0.065, 0.04), at + b * Vector3(0, -0.14, 0), Color("#f4f1ea"), "canvas", rot, 0.5)


## The big grill: a stone base with a brick top and a firebox opening, a wide iron grate
## for three, an open domed lid at the back, a chimney, side shelves with tongs and a
## spatula, firewood stacked below.
static func _big_grill(st: SurfaceTool) -> void:
	var iron := Color(0.4, 0.41, 0.45)
	var stone := Color(0.92, 0.9, 0.86)
	var brick := Color(1, 0.9, 0.82)
	Mk.st_box(st, Vector3(1.3, 0.62, 0.72), Vector3(0, 0.31, 0), stone, "rock", Vector3.ZERO, 1.2)
	Mk.st_box(st, Vector3(1.34, 0.22, 0.76), Vector3(0, 0.73, 0), brick, "bricks", Vector3.ZERO, 1.0)
	Mk.st_box(st, Vector3(1.38, 0.05, 0.8), Vector3(0, 0.86, 0), brick.darkened(0.12), "bricks", Vector3.ZERO, 1.0)
	# The firebox mouth and an ash drawer with a handle.
	Mk.st_box(st, Vector3(0.9, 0.24, 0.04), Vector3(0, 0.5, 0.35), Color(0.12, 0.1, 0.09), "ash")
	Mk.st_box(st, Vector3(0.94, 0.03, 0.05), Vector3(0, 0.635, 0.36), iron, "metal")
	Mk.st_box(st, Vector3(0.6, 0.14, 0.03), Vector3(0, 0.2, 0.365), iron.darkened(0.15), "metal")
	Mk.st_box(st, Vector3(0.16, 0.025, 0.04), Vector3(0, 0.2, 0.39), Color(0.75, 0.6, 0.35), "metal")
	for x: float in [-0.66, 0.66]:
		for z: float in [-0.37, 0.37]:
			Mk.st_box(st, Vector3(0.05, 0.86, 0.05), Vector3(x, 0.43, z), iron, "metal")
	# The grate: a frame and fifteen bars.
	Mk.st_box(st, Vector3(1.2, 0.03, 0.62), Vector3(0, 0.89, 0), Color(0.16, 0.14, 0.13), "ash")
	for k in 15:
		Mk.st_box(st, Vector3(0.016, 0.016, 0.6), Vector3(-0.56 + k * 0.08, 0.93, 0), iron, "metal")
	for z: float in [-0.28, 0.0, 0.28]:
		Mk.st_box(st, Vector3(1.16, 0.018, 0.018), Vector3(0, 0.93, z), iron, "metal")
	# The lid, tipped open against the back, and the chimney out of it.
	var lid_rot := Vector3(-1.25, 0, 0)
	var b := Basis.from_euler(lid_rot)
	var hinge := Vector3(0, 0.92, -0.34)
	for i in 6:
		var a := PI * (i + 0.5) / 6.0
		var p := hinge + b * Vector3(0, sin(a) * 0.22, -0.3 + cos(a) * 0.3)
		Mk.st_box(st, Vector3(1.16, 0.03, 0.13), p, Color(0.6, 0.61, 0.66) if i % 2 == 0 else Color(0.52, 0.53, 0.58), "metal", Vector3(lid_rot.x - (a - PI / 2.0), 0, 0))
	Mk.st_box(st, Vector3(0.2, 0.05, 0.05), hinge + b * Vector3(0, 0.25, -0.3), Color(0.55, 0.4, 0.25), "wood_dark", lid_rot)
	Mk.st_cyl(st, 0.06, 0.6, Vector3(0.45, 1.25, -0.4), iron.darkened(0.15), "metal", Vector3.ZERO, 10)
	Mk.st_cyl(st, 0.09, 0.05, Vector3(0.45, 1.57, -0.4), iron.darkened(0.25), "metal", Vector3.ZERO, 10)
	# Side shelves with tools and a salt pot.
	for sx: float in [-1.0, 1.0]:
		Mk.st_box(st, Vector3(0.3, 0.04, 0.5), Vector3(sx * 0.82, 0.84, 0), WOOD, "wood")
		Mk.st_box(st, Vector3(0.03, 0.22, 0.03), Vector3(sx * 0.86, 0.72, 0.2), iron, "metal", Vector3(0, 0, sx * 0.5))
	Mk.st_box(st, Vector3(0.05, 0.012, 0.3), Vector3(-0.82, 0.87, 0.02), Color(0.7, 0.71, 0.75), "metal", Vector3(0, 0.15, 0))
	Mk.st_box(st, Vector3(0.09, 0.008, 0.08), Vector3(-0.83, 0.87, -0.16), Color(0.7, 0.71, 0.75), "metal", Vector3(0, 0.15, 0))
	for dx: float in [-0.012, 0.012]:
		Mk.st_box(st, Vector3(0.014, 0.012, 0.32), Vector3(0.8 + dx, 0.87, 0.0), Color(0.7, 0.71, 0.75), "metal", Vector3(0, dx * 6.0, 0))
	Mk.st_cyl(st, 0.05, 0.08, Vector3(0.84, 0.9, -0.17), Color("#7a5532"), "clay", Vector3.ZERO, 10, 0.5)
	Mk.st_cyl(st, 0.045, 0.01, Vector3(0.84, 0.945, -0.17), Color("#f4f2ec"), "white", Vector3.ZERO, 10)
	# Firewood stacked at the side.
	for i in 4:
		Mk.st_cyl(st, 0.05, 0.42, Vector3(-0.82 + (i % 2) * 0.1, 0.06 + (i / 2) * 0.09, -0.05 + (i % 2) * 0.05), Color(0.85, 0.7, 0.55), "wood", Vector3(PI / 2.0, 0.1 * i, 0), 8)
