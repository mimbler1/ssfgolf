class_name InkDrawing
extends RefCounted
## Player drawings on clothing (docs/INK_ART_SPEC.md §8). Editable stroke data, stored in the
## garment's own (u, v) space so it bends and flutters with the fabric.
##
## Format v1, one entry per target item ("pants", "top", "hat"):
##   {"v": 1, "legs": "both" | "front", "strokes": [{"c": "#rrggbb", "w": 2.0, "a": 1.0, "p": [x, y, ...]}]}
## x and y are quantised 0..1000 across the garment template: x = across (v), y = along (u).

const VERSION := 1
const TARGETS := ["pants", "top", "hat"]
const MAX_STROKES := 48
const MAX_POINTS := 1500
const MIN_W := 0.4
const MAX_W := 9.0


static func normalize_all(raw: Variant) -> Dictionary:
	var out := {}
	if not raw is Dictionary:
		return out
	for t: String in TARGETS:
		if (raw as Dictionary).has(t):
			var d := normalize(raw[t])
			if not (d.strokes as Array).is_empty():
				out[t] = d
	return out


## Validates one drawing: clamps sizes, colours, alpha and coordinates; drops what is malformed.
static func normalize(raw: Variant) -> Dictionary:
	var out := {"v": VERSION, "legs": "both", "strokes": []}
	if not raw is Dictionary:
		return out
	var d: Dictionary = raw
	if str(d.get("legs", "both")) == "front":
		out.legs = "front"
	var total := 0
	for s in d.get("strokes", []):
		if not s is Dictionary or (out.strokes as Array).size() >= MAX_STROKES:
			continue
		var p = s.get("p", [])
		if not p is Array or (p as Array).size() < 2:
			continue
		var pts: Array = []
		var arr: Array = p
		for i in range(0, arr.size() - 1, 2):
			if total >= MAX_POINTS:
				break
			if not (arr[i] is float or arr[i] is int) or not (arr[i + 1] is float or arr[i + 1] is int):
				continue
			pts.append(clampi(int(arr[i]), 0, 1000))
			pts.append(clampi(int(arr[i + 1]), 0, 1000))
			total += 1
		if pts.size() < 2:
			continue
		var c := str(s.get("c", "#1c1714"))
		(out.strokes as Array).append({
			"c": c.to_lower() if InkLook.is_hex(c) else "#1c1714",
			"w": snappedf(clampf(float(s.get("w", 2.0)), MIN_W, MAX_W), 0.1),
			"a": snappedf(clampf(float(s.get("a", 1.0)), 0.1, 1.0), 0.01),
			"p": pts,
		})
	return out


static func point_count(d: Dictionary) -> int:
	var n := 0
	for s: Dictionary in d.get("strokes", []):
		n += (s.p as Array).size() / 2
	return n


## Draws `d` through `mapper(u, v) -> Vector2` (u along, v across in -1..1). `width_k` converts a
## stroke width in template units to local units at that garment's scale.
static func draw(cv: InkCanvas, d: Dictionary, mapper: Callable, width_k: float, darken: float = 0.0) -> void:
	var i := 0
	for s: Dictionary in d.get("strokes", []):
		var p: Array = s.p
		var line := PackedVector2Array()
		for k in range(0, p.size() - 1, 2):
			var v := float(p[k]) / 500.0 - 1.0
			var u := float(p[k + 1]) / 1000.0
			line.append(mapper.call(u, v))
		var c := Color(str(s.c))
		c.a = float(s.a)
		if darken > 0.0:
			c = c.darkened(darken)
		if line.size() == 1:
			cv.dot(line[0], float(s.w) * width_k * 0.5, c)
		else:
			cv.stroke(line, float(s.w) * width_k, c, 0.08, 0.08, float(i), 0.08, 0.0, 0.6)
		i += 1
