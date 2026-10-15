class_name WorldArt
extends RefCounted
## Authored art for a world theme (res://assets/worlds/<id>/world.json, built by
## tools/artgen/build_stage.py). TerrainView and Backdrop use it when a course theme names it
## (`theme.art`), and fall back to their procedural drawing otherwise.
##
## Art is drawn at `art_scale` world px per art px with nearest filtering (ART_STYLE_GUIDE §2).
## Nothing here touches collision: terrain geometry and materials still come from the course.

const ROOT := "res://assets/worlds/%s/"

static var _cache: Dictionary = {}

var id := ""
var data: Dictionary = {}
var scale := 2.0


static func load_for(theme: Dictionary) -> WorldArt:
	var wid := str(theme.get("art", ""))
	if wid == "":
		return null
	if _cache.has(wid):
		return _cache[wid]
	var w: WorldArt = null
	var path := (ROOT % wid) + "world.json"
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			w = WorldArt.new()
			w.id = wid
			w.data = parsed
			w.scale = float(w.data.get("art_scale", 2.0))
		else:
			push_error("WorldArt %s: bad world.json" % wid)
	_cache[wid] = w
	return w


func tex(rel: String) -> Texture2D:
	if rel == "":
		return null
	var t := load((ROOT % id) + rel) as Texture2D
	if t == null:
		push_error("WorldArt %s: missing %s" % [id, rel])
	return t


## Material entry: {fill?, cap?, cap_base?, wall?} (see world.json).
func material(name: String) -> Dictionary:
	var mats: Dictionary = data.get("materials", {})
	return mats.get(name, mats.get("default", {}))


func decor_variants(kind: String) -> Array:
	return (data.get("decor", {}) as Dictionary).get(kind, [])


## A textured polygon in world space: the texture repeats at art scale, anchored to world (0, 0)
## so neighbouring polygons line up seamlessly.
func textured_polygon(points: PackedVector2Array, texture: Texture2D) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.texture = texture
	p.texture_scale = Vector2(1.0 / scale, 1.0 / scale)
	p.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return p


## A textured strip that follows a surface run. The cap texture's row `base` (art px) sits on the
## surface line; rows above it overhang into the air (grass tufts), rows below cover the topsoil.
func cap_line(points: PackedVector2Array, normals: PackedVector2Array, texture: Texture2D, base: float) -> Line2D:
	var h := float(texture.get_height())
	var width := h * scale
	# Line2D centres the texture on the line: shift the line so `base` lands on the surface.
	var shift := (h * 0.5 - base) * scale
	var pts := PackedVector2Array()
	for i in points.size():
		pts.append(points[i] - normals[i] * shift)
	var l := Line2D.new()
	l.points = pts
	l.width = width
	l.texture = texture
	l.texture_mode = Line2D.LINE_TEXTURE_TILE
	l.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_NONE
	l.end_cap_mode = Line2D.LINE_CAP_NONE
	return l


## Sprite with its bottom-centre on `pos` (decor standing on the ground).
func ground_sprite(texture: Texture2D, pos: Vector2, flip: bool = false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = texture
	s.centered = false
	s.offset = Vector2(-texture.get_width() * 0.5, -texture.get_height())
	s.scale = Vector2(-scale if flip else scale, scale)
	s.position = pos
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s
