class_name SaveGame
## Worlds: up to MAX named saves in `dir`, one file each, and an index with their names,
## day, time played and when they were last saved. The state is a plain Dictionary built
## by the game. The single save of older versions becomes the first world.

const VERSION := 1
const MAX := 10
const OLD_PATH := "user://raft_save.json"

static var dir := "user://saves/"


static func _index_path() -> String:
	return dir + "index.json"


static func _file(id: int) -> String:
	return dir + "world_%d.json" % id


static func _index() -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(_index_path())) if FileAccess.file_exists(_index_path()) else null
	if not d is Dictionary:
		d = {"last": -1, "worlds": []}
	return d


static func _store(index: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(_index_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(index))


static func _entry(index: Dictionary, id: int) -> Dictionary:
	for w: Dictionary in index["worlds"]:
		if int(w["id"]) == id:
			return w
	return {}


## The worlds, last saved first: [{id, name, day, played, time}].
static func worlds() -> Array:
	var list: Array = _index()["worlds"].duplicate()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["time"]) > float(b["time"]))
	return list


static func info(id: int) -> Dictionary:
	return _entry(_index(), id)


static func can_add() -> bool:
	return _index()["worlds"].size() < MAX


## The world played last, or -1.
static func last() -> int:
	var index := _index()
	return int(index["last"]) if not _entry(index, int(index["last"])).is_empty() else -1


## A new empty world; its file appears on the first write. -1 when there are MAX already.
static func create(world_name: String) -> int:
	var index := _index()
	if index["worlds"].size() >= MAX:
		return -1
	var id := 1
	for w: Dictionary in index["worlds"]:
		id = maxi(id, int(w["id"]) + 1)
	index["worlds"].append({"id": id, "name": world_name, "day": 1, "played": 0.0, "time": Time.get_unix_time_from_system()})
	index["last"] = id
	_store(index)
	return id


static func write(id: int, state: Dictionary) -> void:
	var index := _index()
	var w := _entry(index, id)
	if w.is_empty():
		return
	state["version"] = VERSION
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(_file(id), FileAccess.WRITE)
	if not f:
		return
	f.store_string(JSON.stringify(state))
	f.close()
	w["day"] = int(state.get("day", 1))
	w["played"] = float(state.get("played", 0.0))
	w["time"] = Time.get_unix_time_from_system()
	index["last"] = id
	_store(index)


static func read(id: int) -> Dictionary:
	if not FileAccess.file_exists(_file(id)):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(_file(id)))
	if d is Dictionary and int(d.get("version", 0)) == VERSION:
		return d
	return {}


static func rename(id: int, world_name: String) -> void:
	var index := _index()
	var w := _entry(index, id)
	if not w.is_empty():
		w["name"] = world_name
		_store(index)


static func remove(id: int) -> void:
	var index := _index()
	index["worlds"] = index["worlds"].filter(func(w: Dictionary) -> bool: return int(w["id"]) != id)
	if int(index["last"]) == id:
		index["last"] = -1
	_store(index)
	if FileAccess.file_exists(_file(id)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_file(id)))


## Deletes every world (the capture bot starts clean).
static func clear_all() -> void:
	for w: Dictionary in worlds():
		remove(int(w["id"]))


## The one save of v0.6 and earlier becomes a world named "Мой плот".
static func migrate() -> void:
	if not FileAccess.file_exists(OLD_PATH) or not _index()["worlds"].is_empty():
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(OLD_PATH))
	if d is Dictionary:
		var id := create("Мой плот")
		write(id, d)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OLD_PATH))


## A free default name: "Плот 1", "Плот 2"...
static func next_name() -> String:
	var taken := worlds().map(func(w: Dictionary) -> String: return w["name"])
	var n := 1
	while "Плот %d" % n in taken:
		n += 1
	return "Плот %d" % n


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
