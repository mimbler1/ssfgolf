class_name CharacterSheet
extends RefCounted
## A baked character sprite sheet: one packed atlas PNG plus JSON frame metadata, produced by
## the sprite baker (tools/bake_sprites.ps1). Sheets are loaded on first use and cached.
##
## JSON: {"bake_scale": float, "anims": {name: {"fps": float, "loop": bool, "mode": "time"|"power",
##        "frames": [[atlas_x, atlas_y, w, h, offset_x, offset_y], ...]}}}
## Offsets are relative to the golfer's origin (ground point between the feet), in sheet pixels.

const DIR := "res://assets/characters"

static var _cache: Dictionary = {}

var id := ""
var texture: Texture2D
var bake_scale := 3.0
var anims: Dictionary = {}


## Returns the sheet for a roster id, or null if it has not been baked.
static func get_sheet(char_id: String) -> CharacterSheet:
	if _cache.has(char_id):
		return _cache[char_id]
	var sheet: CharacterSheet = null
	var json_path := DIR.path_join(char_id + ".json")
	var png_path := DIR.path_join(char_id + ".png")
	if FileAccess.file_exists(json_path) and ResourceLoader.exists(png_path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
		if data is Dictionary:
			sheet = CharacterSheet.new()
			sheet.id = char_id
			sheet.texture = load(png_path)
			sheet.bake_scale = float(data.get("bake_scale", 3.0))
			sheet.anims = data.get("anims", {})
	_cache[char_id] = sheet
	return sheet


func has_anim(name: String) -> bool:
	return anims.has(name)


## Frame for `name` at animation time `t` (or aim `power` for power-indexed anims).
## Returns {x, y, w, h, ox, oy} or {} if the anim is missing.
func frame(name: String, t: float, power: float = 0.0) -> Dictionary:
	var a: Dictionary = anims.get(name, {})
	var frames: Array = a.get("frames", [])
	if frames.is_empty():
		return {}
	var n := frames.size()
	var i := 0
	if str(a.get("mode", "time")) == "power":
		i = clampi(roundi(clampf(power, 0.0, 1.0) * float(n - 1)), 0, n - 1)
	else:
		var k := int(floor(t * float(a.get("fps", 12.0))))
		i = posmod(k, n) if bool(a.get("loop", true)) else clampi(k, 0, n - 1)
	var f: Array = frames[i]
	return {"x": f[0], "y": f[1], "w": f[2], "h": f[3], "ox": f[4], "oy": f[5]}
