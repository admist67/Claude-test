class_name Footprint
## Where things stand on the raft floor, as rectangles (four corners in raft-local x, z):
## free decor and lights may not overlap each other, walls, pillars or stations.

## A rectangle (its four corners in raft-local x, z) of `size` centered at `at`, turned by `yaw`.
static func rect(at: Vector3, yaw: float, size: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var c := cos(yaw)
	var s := sin(yaw)
	for q: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var lx := q.x * size.x / 2.0
		var lz := q.y * size.y / 2.0
		# Basis(UP, yaw) * (lx, 0, lz)
		out.append(Vector2(at.x + c * lx + s * lz, at.z - s * lx + c * lz))
	return out


## The footprint of a free part `kind` at raft-local (x, z) `at`, turned by `yaw`
## (data "foot": [width, depth] or [width, depth, offset x, offset z]). With `base`, only
## what has to stand on the floor (data "base", e.g. a lantern's post, not its arm).
static func of(kind: String, at: Vector2, yaw: float, base := false) -> PackedVector2Array:
	var d: Dictionary = Data.build_by_id.get(kind, {})
	var f: Array = d.get("base", d.get("foot", [0.5, 0.5])) if base else d.get("foot", [0.5, 0.5])
	var off := Vector3(f[2], 0, f[3]) if f.size() > 3 else Vector3.ZERO
	var c := Vector3(at.x, 0, at.y) + Basis(Vector3.UP, yaw) * off
	return rect(c, yaw, Vector2(f[0], f[1]))


## Do two convex quads overlap (more than touching)?
static func overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	for poly in [a, b]:
		for i in 4:
			var e: Vector2 = poly[(i + 1) % 4] - poly[i]
			var n := Vector2(-e.y, e.x).normalized()
			var amin := INF
			var amax := -INF
			var bmin := INF
			var bmax := -INF
			for q in a:
				amin = minf(amin, q.dot(n))
				amax = maxf(amax, q.dot(n))
			for q in b:
				bmin = minf(bmin, q.dot(n))
				bmax = maxf(bmax, q.dot(n))
			if amax <= bmin + 0.01 or bmax <= amin + 0.01:
				return false
	return true
