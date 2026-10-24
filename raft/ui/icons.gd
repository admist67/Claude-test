class_name Icons
## Icons as textures: 3D renders of items (assets/icons, tools/render_icons.tscn) and white
## glyphs (assets/ui/glyphs: Kenney Game Icons CC0 and tools/build_ui.py).

const ALIASES := {"health": "heart", "hunger": "food", "thirst": "drop", "check": "checkmark", "close": "cross"}

static var _cache: Dictionary = {}


static func tex(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var name: String = ALIASES.get(id, id)
	var t: Texture2D = null
	for p: String in ["res://assets/icons/%s.png" % name, "res://assets/ui/glyphs/%s.png" % name]:
		if ResourceLoader.exists(p):
			t = load(p)
			break
	_cache[id] = t
	return t


## Draws icon `id` centered at `c`, fitting a square of side `s`.
static func draw(ci: CanvasItem, id: String, c: Vector2, s: float, mod := Color.WHITE) -> void:
	var t := tex(id)
	if t == null:
		ci.draw_circle(c, s * 0.3, Color("#ff00ff"))
		return
	ci.draw_texture_rect(t, Rect2(c - Vector2(s, s) / 2.0, Vector2(s, s)), false, mod)
