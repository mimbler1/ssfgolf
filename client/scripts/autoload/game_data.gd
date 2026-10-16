extends Node
## Loads data-driven game content (balance, materials, courses, themes) once at startup.

const BALANCE_PATH := "res://data/balance.json"
const MATERIALS_PATH := "res://data/materials.json"
const COURSES_DIR := "res://data/courses"
const VERSION := "0.1.0"
const PROTOCOL_VERSION := 2  ## 2: shots carry spin, c_spin, ability state flags

var balance: Dictionary = {}
var materials: Dictionary = {}
var courses: Dictionary = {}           ## id (and alias) -> course dictionary
var course_order: PackedStringArray = PackedStringArray()   ## every course file, by id
## The six main courses in play order (course "order" field); practice-only courses excluded.
var main_courses: PackedStringArray = PackedStringArray()

## Online matchmaking plays holes drawn from every main course (each hole keeps its own theme).
const POOL_ID := "blitz_pool"
var abilities: Array[Dictionary] = []
var _ability_index: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	balance = load_json(BALANCE_PATH)
	materials = load_json(MATERIALS_PATH).get("materials", {})
	abilities.clear()
	_ability_index.clear()
	for a: Dictionary in balance.get("abilities", []):
		_ability_index[a.id] = abilities.size()
		abilities.append(a)
	courses.clear()
	course_order.clear()
	var dir := DirAccess.open(COURSES_DIR)
	if dir == null:
		push_error("Missing courses directory")
		return
	var files := dir.get_files()
	files.sort()
	for f in files:
		# Exported builds may list remapped names; only plain JSON course files are loaded.
		if not f.ends_with(".json"):
			continue
		var c := load_json(COURSES_DIR.path_join(f))
		if c.is_empty():
			continue
		courses[str(c.id)] = c
		course_order.append(str(c.id))
		for alias: String in c.get("aliases", []):
			courses[alias] = c
	var mains: Array = []
	for id in course_order:
		if not bool(courses[id].get("practiceOnly", false)) and courses[id].has("order"):
			mains.append(id)
	mains.sort_custom(func(a: String, b: String) -> bool: return int(courses[a].order) < int(courses[b].order))
	main_courses = PackedStringArray(mains)
	courses[POOL_ID] = _build_pool()


## Every hole of every main course, each tagged with its course's theme and id.
func _build_pool() -> Dictionary:
	var holes: Array = []
	for id in main_courses:
		var c: Dictionary = courses[id]
		for h: Dictionary in c.holes:
			var hh := h.duplicate(true)
			hh["theme"] = c.theme
			hh["course_id"] = id
			holes.append(hh)
	var first: Dictionary = courses[main_courses[0]] if not main_courses.is_empty() else {}
	return {"id": POOL_ID, "name": "All Courses", "theme": first.get("theme", {}), "holes": holes}


## Theme for one hole: the hole's own (pool holes) or its course's.
static func hole_theme(course_dict: Dictionary, hole_dict: Dictionary) -> Dictionary:
	return hole_dict.get("theme", course_dict.get("theme", {}))


static func load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_error("Invalid JSON in %s" % path)
	return {}


func ability(id: String) -> Dictionary:
	return abilities[_ability_index[id]] if _ability_index.has(id) else {}


func ability_index(id: String) -> int:
	return int(_ability_index.get(id, 0))


func ability_id_at(index: int) -> String:
	return str(abilities[index].id) if index >= 0 and index < abilities.size() else "standard"


func course(id: String) -> Dictionary:
	return courses.get(id, {})


func hole(course_id: String, index: int) -> Dictionary:
	var c := course(course_id)
	var holes: Array = c.get("holes", [])
	return holes[index] if index >= 0 and index < holes.size() else {}


func theme_for(course_id: String) -> Dictionary:
	return course(course_id).get("theme", {})
