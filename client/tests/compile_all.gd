extends SceneTree
## Loads every GDScript in the project to surface parse/compile errors. Exit code 1 on failure.

func _initialize() -> void:
	var bad := 0
	var count := 0
	for path in _scripts("res://scripts") + _scripts("res://tests"):
		if path.ends_with("compile_all.gd"):
			continue
		count += 1
		var s: Script = load(path)
		if s == null or not s.can_instantiate():
			# can_instantiate is false for scripts that failed to compile.
			print("COMPILE FAIL: ", path)
			bad += 1
	print("compiled %d scripts, %d failed" % [count, bad])
	quit(1 if bad > 0 else 0)


func _scripts(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for d in dir.get_directories():
		out.append_array(_scripts(dir_path.path_join(d)))
	return out
