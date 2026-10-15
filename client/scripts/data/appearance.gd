class_name Appearance
extends RefCounted
## Versioned golfer appearance format (v1). Mirrors the backend schema in docs/API.md.
## Unknown ids fall back to defaults so newer content never breaks older clients.

const VERSION := 1

const HEAD_SHAPES := {"round": "Round", "oval": "Oval", "square": "Boxy", "bean": "Bean"}
const EYES := {"dot": "Dots", "happy": "Happy", "big": "Big Eyes", "sleepy": "Sleepy", "angry": "Fierce", "shades": "Shades", "visor": "Visor", "wink": "Wink"}
const MOUTHS := {"smile": "Smile", "grin": "Grin", "flat": "Neutral", "open": "Excited", "smirk": "Smirk", "tongue": "Cheeky", "none": "None"}
const HATS := {"": "No Hat", "cap": "Ball Cap", "beanie": "Beanie", "tophat": "Top Hat", "cowboy": "Ranger", "crown": "Crown", "headband": "Headband", "wizard": "Wizard", "bucket": "Bucket Hat", "halo": "Halo"}
const SHIRTS := {"": "No Shirt", "tee": "Tee", "polo": "Polo", "hoodie": "Hoodie", "vest": "Vest", "jersey": "Jersey"}

const PALETTE := [
	"#2b2d42", "#11121c", "#ffffff", "#f4f1de", "#ffd166", "#ffb703", "#fb8500", "#e63946",
	"#ef476f", "#ff8fab", "#b5179e", "#7209b7", "#4361ee", "#4cc9f0", "#06d6a0", "#2a9d8f",
	"#80ed99", "#588157", "#8d6e63", "#e9c46a", "#adb5bd", "#6c757d", "#264653", "#000000",
]

const DEFAULT := {
	"v": 1,
	"character": "stickman",
	"bodyColor": "#2b2d42",
	"outlineColor": "#11121c",
	"headShape": "round",
	"headScale": 1.0,
	"limbThickness": 1.0,
	"eyes": "dot",
	"mouth": "smile",
	"hat": null,
	"hatColor": "#e63946",
	"shirt": "tee",
	"shirtColor": "#457b9d",
	"ballColor": "#ffffff",
	"trailColor": "#ffd166",
}

## Ready-made starting points shown in the Golfer Studio.
const PRESETS := [
	{"name": "Classic", "data": {"bodyColor": "#2b2d42", "outlineColor": "#11121c", "shirt": "tee", "shirtColor": "#457b9d", "hat": null, "eyes": "dot", "mouth": "smile"}},
	{"name": "Caddie Pro", "data": {"bodyColor": "#264653", "shirt": "polo", "shirtColor": "#f4f1de", "hat": "cap", "hatColor": "#e63946", "eyes": "happy", "mouth": "grin", "ballColor": "#fff3b0", "trailColor": "#e63946"}},
	{"name": "Snow Day", "data": {"bodyColor": "#4361ee", "shirt": "hoodie", "shirtColor": "#4cc9f0", "hat": "beanie", "hatColor": "#ffffff", "eyes": "big", "mouth": "open", "trailColor": "#ffffff"}},
	{"name": "Royal Swing", "data": {"bodyColor": "#7209b7", "shirt": "vest", "shirtColor": "#ffd166", "hat": "crown", "hatColor": "#ffd166", "eyes": "sleepy", "mouth": "smirk", "ballColor": "#ffd166", "trailColor": "#b5179e"}},
	{"name": "Trailblazer", "data": {"bodyColor": "#8d6e63", "shirt": "jersey", "shirtColor": "#fb8500", "hat": "cowboy", "hatColor": "#6d4c41", "eyes": "angry", "mouth": "flat", "trailColor": "#fb8500"}},
	{"name": "Arcane", "data": {"bodyColor": "#11121c", "outlineColor": "#000000", "shirt": "hoodie", "shirtColor": "#3a0ca3", "hat": "wizard", "hatColor": "#4361ee", "eyes": "visor", "mouth": "none", "ballColor": "#c77dff", "trailColor": "#4cc9f0"}},
	{"name": "Sunny", "data": {"bodyColor": "#ffb703", "outlineColor": "#7a4b00", "shirt": "tee", "shirtColor": "#ffffff", "hat": "bucket", "hatColor": "#06d6a0", "eyes": "happy", "mouth": "tongue", "trailColor": "#06d6a0"}},
	{"name": "Angelic", "data": {"bodyColor": "#f4f1de", "outlineColor": "#6c757d", "shirt": "polo", "shirtColor": "#ff8fab", "hat": "halo", "hatColor": "#ffd166", "eyes": "wink", "mouth": "smile", "trailColor": "#ff8fab"}},
]


static func normalize(raw: Variant) -> Dictionary:
	var out := DEFAULT.duplicate(true)
	if not raw is Dictionary:
		return out
	var d: Dictionary = raw
	for key in ["bodyColor", "outlineColor", "hatColor", "shirtColor", "ballColor", "trailColor"]:
		if d.has(key) and _is_hex(d[key]):
			out[key] = str(d[key])
	if d.has("character") and CharacterDefs.has(str(d.character)):
		out.character = str(d.character)
	if d.has("headShape") and HEAD_SHAPES.has(str(d.headShape)):
		out.headShape = str(d.headShape)
	if d.has("eyes") and EYES.has(str(d.eyes)):
		out.eyes = str(d.eyes)
	if d.has("mouth") and MOUTHS.has(str(d.mouth)):
		out.mouth = str(d.mouth)
	if d.has("hat"):
		out.hat = d.hat if d.hat != null and HATS.has(str(d.hat)) and str(d.hat) != "" else null
	if d.has("shirt"):
		out.shirt = d.shirt if d.shirt != null and SHIRTS.has(str(d.shirt)) and str(d.shirt) != "" else null
	if d.has("headScale"):
		out.headScale = clampf(float(d.headScale), 0.8, 1.3)
	if d.has("limbThickness"):
		out.limbThickness = clampf(float(d.limbThickness), 0.7, 1.5)
	return out


static func with_preset(base: Dictionary, preset_data: Dictionary) -> Dictionary:
	var merged := DEFAULT.duplicate(true)
	merged.ballColor = base.get("ballColor", merged.ballColor)
	for k in preset_data:
		merged[k] = preset_data[k]
	return normalize(merged)


static func _is_hex(v: Variant) -> bool:
	if not v is String:
		return false
	var s: String = v
	if s.length() != 7 or not s.begins_with("#"):
		return false
	return s.substr(1).is_valid_hex_number()
