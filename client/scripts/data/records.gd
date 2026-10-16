class_name Records
extends RefCounted
## Solo progress and personal records, stored per local profile (user://profiles/<name>/records.json).
##
## courses.<id>: {completed, rounds, best_total, best_time, best_clean, medal, layout, holes: {<hole id>: {best, aces, swishes}},
##                legacy: {<old layout>: {best_total, best_time, best_clean, medal, holes}}}
## totals:       {holes_in_one, swishes, rounds}
##
## Medals compare a full round with the course par: gold = 3 or more under par, silver = par or
## better, bronze = completed. Clean Ball rounds (no abilities) are tracked separately as well.

const PATH_FMT := "user://profiles/%s/records.json"
const MEDALS := ["", "bronze", "silver", "gold"]


static func _path() -> String:
	return PATH_FMT % Backend.local_profile


static func load_all() -> Dictionary:
	if not FileAccess.file_exists(_path()):
		return {"courses": {}, "totals": {"holes_in_one": 0, "swishes": 0, "rounds": 0}}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path()))
	if not parsed is Dictionary:
		return {"courses": {}, "totals": {"holes_in_one": 0, "swishes": 0, "rounds": 0}}
	var d: Dictionary = parsed
	if not d.has("courses"):
		d["courses"] = {}
	if not d.has("totals"):
		d["totals"] = {"holes_in_one": 0, "swishes": 0, "rounds": 0}
	if _migrate_layouts(d):
		_save(d)
	return d


## Bests belong to one hole layout. When a course is rebuilt (its "layout" number changes), the old
## bests and medal move to `legacy` instead of being compared with the new holes. Completion (which
## unlocks balls) and round counts carry over. Nothing is deleted.
static func _migrate_layouts(d: Dictionary) -> bool:
	var gd: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("GameData") if Engine.get_main_loop() is SceneTree else null
	if gd == null:
		return false
	var changed := false
	for cid: String in (d.courses as Dictionary).keys():
		var c: Dictionary = d.courses[cid]
		var current := int((gd.course(cid) as Dictionary).get("layout", 1))
		var stored := int(c.get("layout", 1))
		if stored == current:
			continue
		var legacy: Dictionary = c.get("legacy", {})
		var old := {}
		for k in ["best_total", "best_time", "best_clean", "medal", "holes"]:
			if c.has(k):
				old[k] = c[k]
				c.erase(k)
		legacy[str(stored)] = old
		c["legacy"] = legacy
		c["holes"] = {}
		c["medal"] = ""
		c["layout"] = current
		changed = true
	return changed


static func _save(d: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(_path().get_base_dir())
	var tmp := _path() + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Records: cannot write %s" % tmp)
		return
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	# Replace atomically so a crash mid-write never corrupts the records.
	DirAccess.rename_absolute(tmp, _path())


static func course(cid: String) -> Dictionary:
	return (load_all().courses as Dictionary).get(cid, {})


static func course_par(course_dict: Dictionary) -> int:
	var total := 0
	for h: Dictionary in course_dict.get("holes", []):
		total += int(h.get("par", 3))
	return total


static func medal_for(total: int, par: int) -> String:
	if total <= par - 3:
		return "gold"
	if total <= par:
		return "silver"
	return "bronze"


## Daily challenge: best strokes per date (records.daily = {"YYYY-MM-DD": strokes}).
static func daily_best(date: String) -> int:
	return int((load_all().get("daily", {}) as Dictionary).get(date, 0))


static func record_daily(date: String, strokes: int) -> Dictionary:
	var d := load_all()
	var daily: Dictionary = d.get("daily", {})
	var prev := int(daily.get(date, 0))
	var new_best := prev == 0 or strokes < prev
	if new_best:
		daily[date] = strokes
	d["daily"] = daily
	_save(d)
	return {"new_best": new_best, "best": int(daily[date])}


## Records one finished round. Returns {new_best: bool, medal: String, total: int, par: int, aces: int, swishes: int}.
static func record_round(course_dict: Dictionary, scorecard: Array, clean: bool) -> Dictionary:
	var cid := str(course_dict.id)
	var d := load_all()
	var c: Dictionary = (d.courses as Dictionary).get(cid, {"completed": false, "rounds": 0, "holes": {}, "medal": "",
		"layout": int(course_dict.get("layout", 1))})
	var total := 0
	var time := 0.0
	var aces := 0
	var swishes := 0
	for row: Dictionary in scorecard:
		total += int(row.strokes)
		time += float(row.get("time", 0.0))
		var hid := str(row.hole_id)
		var hr: Dictionary = (c.holes as Dictionary).get(hid, {"best": 0, "aces": 0, "swishes": 0})
		if int(hr.best) == 0 or int(row.strokes) < int(hr.best):
			hr.best = int(row.strokes)
		if bool(row.get("ace", false)):
			hr.aces = int(hr.aces) + 1
			aces += 1
		if bool(row.get("swish", false)):
			hr.swishes = int(hr.swishes) + 1
			swishes += 1
		c.holes[hid] = hr
	var par := course_par(course_dict)
	var full := scorecard.size() == (course_dict.get("holes", []) as Array).size()
	var new_best := false
	var medal := ""
	if full:
		c.completed = true
		c.rounds = int(c.get("rounds", 0)) + 1
		if not c.has("best_total") or total < int(c.best_total):
			c.best_total = total
			c.best_time = time
			new_best = true
		elif total == int(c.best_total) and time < float(c.get("best_time", INF)):
			c.best_time = time
		if clean and (not c.has("best_clean") or total < int(c.best_clean)):
			c.best_clean = total
		medal = medal_for(total, par)
		if MEDALS.find(medal) > MEDALS.find(str(c.get("medal", ""))):
			c.medal = medal
		d.totals.rounds = int(d.totals.get("rounds", 0)) + 1
	d.totals.holes_in_one = int(d.totals.get("holes_in_one", 0)) + aces
	d.totals.swishes = int(d.totals.get("swishes", 0)) + swishes
	d.courses[cid] = c
	_save(d)
	return {"new_best": new_best, "medal": medal, "total": total, "par": par, "aces": aces, "swishes": swishes}
