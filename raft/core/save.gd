class_name SaveGame
## One save slot in user://. The state is a plain Dictionary built by the game.

const VERSION := 1

static var path := "user://raft_save.json"


static func exists() -> bool:
	return FileAccess.file_exists(path)


static func write(state: Dictionary) -> void:
	state["version"] = VERSION
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(state))


static func read() -> Dictionary:
	if not exists():
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if d is Dictionary and int(d.get("version", 0)) == VERSION:
		return d
	return {}


static func clear() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Tiles as [[x, y], ...] for JSON.
static func cells_to_json(cells: Array) -> Array:
	var out: Array = []
	for c: Vector2i in cells:
		out.append([c.x, c.y])
	return out


static func cells_from_json(a: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for e: Array in a:
		out.append(Vector2i(int(e[0]), int(e[1])))
	return out
