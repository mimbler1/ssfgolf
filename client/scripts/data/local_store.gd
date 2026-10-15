class_name LocalStore
extends RefCounted
## Local persistence for the golfer appearance and named presets.
## The equipped appearance is also synced to the player's online profile when signed in.

const PATH_FMT := "user://profiles/%s/golfer.json"


static func _path() -> String:
	return PATH_FMT % Backend.local_profile


static func _read() -> Dictionary:
	if not FileAccess.file_exists(_path()):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path()))
	return parsed if parsed is Dictionary else {}


static func _write(d: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(_path().get_base_dir())
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, "\t"))


static func appearance() -> Dictionary:
	return Appearance.normalize(_read().get("appearance", Appearance.DEFAULT))


static func save_appearance(a: Dictionary) -> void:
	var d := _read()
	d["appearance"] = Appearance.normalize(a)
	_write(d)


## Saved presets: Array of {name: String, appearance: Dictionary, savedAt: int}
static func presets() -> Array:
	var list: Variant = _read().get("presets", [])
	return list if list is Array else []


static func save_presets(list: Array) -> void:
	var d := _read()
	d["presets"] = list
	_write(d)
