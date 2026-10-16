class_name Unlocks
extends RefCounted
## Which balls a player may use (data/unlocks.json, docs/POWERUP_SPEC.md "Unlocks").
## A ball unlocks when any of its conditions is met: player level, completing a course in solo
## play, or an achievement. Online, the server applies the level route only.

static var _data: Dictionary = {}


static func table() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/unlocks.json"))
		_data = (parsed as Dictionary).get("abilities", {}) if parsed is Dictionary else {}
	return _data


## Balls unlocked by level alone (what the game server trusts).
static func for_level(level: int) -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in table():
		if int(table()[id].get("level", 999)) <= level:
			out.append(id)
	return out


## Balls unlocked for solo play: level, completed courses or achievements.
static func for_local(level: int, records: Dictionary) -> PackedStringArray:
	var out := for_level(level)
	var courses: Dictionary = records.get("courses", {})
	var totals: Dictionary = records.get("totals", {})
	for id: String in table():
		if out.has(id):
			continue
		var cond: Dictionary = table()[id]
		var cid := str(cond.get("course", ""))
		if cid != "" and bool((courses.get(cid, {}) as Dictionary).get("completed", false)):
			out.append(id)
		elif str(cond.get("achievement", "")) == "hole_in_one" and int(totals.get("holes_in_one", 0)) > 0:
			out.append(id)
	return out


## Human-readable unlock condition, for locked cards.
static func describe(id: String) -> String:
	var c: Dictionary = table().get(id, {})
	var parts: PackedStringArray = []
	if c.has("level"):
		parts.append("reach level %d" % int(c.level))
	if c.has("course"):
		parts.append("complete %s" % str(c.course).capitalize())
	if c.has("achievement"):
		parts.append("score a hole-in-one")
	return "Unlock: " + " or ".join(parts)
