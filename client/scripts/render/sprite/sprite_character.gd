class_name SpriteCharacter
extends RefCounted
## Hand-authored sprite characters (art/characters/<id>, exported by
## tools/sprites/build_character.py into res://assets/characters/<id>/).
##
## character.json lists every animation as a strip PNG with per-frame rects, durations and
## anchors (club grip, club head, hat point). Art is palette-indexed, so recolour variants are
## exact colour swaps of the artist's ramps, never a tint over the finished pixels.

const ROOT := "res://assets/characters/%s/"

## Sprite anims a game animation plays, in order of preference. Missing sprite anims fall back
## to "idle" so a character can ship its idle before the rest of its set is finished.
const GAME_TO_SPRITE := {
	"idle": ["idle"], "aim": ["prepare", "idle"], "swing": ["swing", "idle"],
	"watch": ["recovery", "idle"], "walk": ["walk", "idle"],
	"celebrate": ["victory", "idle"], "victory": ["victory", "idle"], "dance": ["victory", "idle"],
	"sad": ["defeat", "idle"],
}

static var _cache: Dictionary = {}   ## "<id>|<variant>" -> SpriteCharacter (false = none)

var id := ""
var meta: Dictionary = {}
var frame_size := Vector2i(96, 128)
var pivot := Vector2(48, 124)
var units_per_px := 1.0
## Rig units from the pivot to where the ball sits at address (v4 sprites set it per character).
var ball_offset := 34.0
## anim -> {loop: bool, frames: [{tex: AtlasTexture, ms: int, anchors: Dictionary}], contact: int}
var anims: Dictionary = {}


static func exists(char_id: String) -> bool:
	return FileAccess.file_exists((ROOT % char_id) + "character.json")


## Loaded (and cached) sprite data for a character, or null when it has no sprite art.
static func load_for(char_id: String, variant: String = "") -> SpriteCharacter:
	var key := "%s|%s" % [char_id, variant]
	if _cache.has(key):
		return _cache[key] as SpriteCharacter
	var sc: SpriteCharacter = null
	if exists(char_id):
		sc = SpriteCharacter.new()
		if not sc._load(char_id, variant):
			sc = null
	_cache[key] = sc
	return sc


func _load(char_id: String, variant: String) -> bool:
	id = char_id
	var txt := FileAccess.get_file_as_string((ROOT % id) + "character.json")
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY or int((parsed as Dictionary).get("format", 0)) != 1:
		push_error("SpriteCharacter %s: bad character.json" % id)
		return false
	meta = parsed
	frame_size = Vector2i(int(meta.frame_size[0]), int(meta.frame_size[1]))
	pivot = Vector2(float(meta.pivot[0]), float(meta.pivot[1]))
	units_per_px = float(meta.rig_units_per_px)
	ball_offset = float(meta.get("ball_offset", 34.0))
	var swap := _swap_table(variant)
	for anim: String in meta.anims:
		var a: Dictionary = meta.anims[anim]
		if (a.frames as Array).is_empty():
			continue
		var sheet := _sheet(str(a.sheet), swap)
		if sheet == null:
			return false
		var frames: Array = []
		for f: Dictionary in a.frames:
			var at := AtlasTexture.new()
			at.atlas = sheet
			var r: Array = f.rect
			at.region = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
			frames.append({"tex": at, "ms": int(f.ms), "anchors": f.get("anchors", {}), "name": str(f.name)})
		var cf: Variant = a.get("contact_frame")
		anims[anim] = {"loop": bool(a.loop), "frames": frames, "contact": int(cf) if cf != null else -1}
	return anims.has("idle")


## Source colour -> replacement colour for a variant (exact palette swap).
func _swap_table(variant: String) -> Dictionary:
	var out := {}
	var v: Dictionary = (meta.get("variants", {}) as Dictionary).get(variant, {})
	for k: String in v:
		out[Color(str(meta.palette[k])).to_rgba32()] = Color(str(v[k]))
	return out


func _sheet(file: String, swap: Dictionary) -> Texture2D:
	var path := (ROOT % id) + file
	var tex := load(path) as Texture2D
	if tex == null:
		push_error("SpriteCharacter %s: missing %s" % [id, path])
		return null
	if swap.is_empty():
		return tex
	var img := tex.get_image()
	img.decompress()
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				var k := Color(c.r, c.g, c.b, 1.0).to_rgba32()
				if swap.has(k):
					img.set_pixel(x, y, swap[k])
	return ImageTexture.create_from_image(img)


## The sprite anim to use for a game animation (see GAME_TO_SPRITE).
func resolve(game_anim: String) -> String:
	for a: String in GAME_TO_SPRITE.get(game_anim, ["idle"]):
		if anims.has(a):
			return a
	return "idle"


## Frame index for an anim at time t (seconds). One-shots hold their last frame.
func frame_at(anim: String, t: float) -> int:
	var a: Dictionary = anims[anim]
	var frames: Array = a.frames
	var total := 0
	for f: Dictionary in frames:
		total += int(f.ms)
	var ms := int(t * 1000.0)
	if a.loop:
		ms = posmod(ms, maxi(total, 1))
	elif ms >= total:
		return frames.size() - 1
	for i in frames.size():
		ms -= int(frames[i].ms)
		if ms < 0:
			return i
	return frames.size() - 1


## Seconds from the start of an anim to the start of its contact frame (0 when none).
func contact_time(anim: String) -> float:
	var a: Dictionary = anims[anim]
	var ms := 0
	for i in maxi(int(a.contact), 0):
		ms += int(a.frames[i].ms)
	return ms / 1000.0


func frame(anim: String, i: int) -> Dictionary:
	return anims[anim].frames[i]


## Opaque bounds of an idle frame in rig units (origin at the pivot, facing right).
func idle_bounds() -> Rect2:
	var img := (frame("idle", 0).tex as AtlasTexture).get_image()
	var used := img.get_used_rect()
	return Rect2((Vector2(used.position) - pivot) * units_per_px, Vector2(used.size) * units_per_px)
