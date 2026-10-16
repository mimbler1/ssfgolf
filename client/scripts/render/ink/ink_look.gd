class_name InkLook
extends RefCounted
## Customisation catalogue for the hand-drawn golfer and the `ink` part of Appearance v2
## (docs/INK_ART_SPEC.md §5–8). Unknown ids fall back to defaults, so newer content never
## breaks older clients.

const HAIR := {
	"none": "Bald", "spikes": "Spikes", "swept": "Swept Back", "messy": "Messy", "mohawk": "Mohawk",
	"curly": "Curly", "afro": "Afro", "bob": "Bob", "long": "Long", "ponytail": "Ponytail",
	"pigtails": "Pigtails", "bun": "Bun", "braid": "Braid", "buzz": "Buzz Cut", "quiff": "Quiff", "fringe": "Fringe",
}
const HEAD_FILL := {"paper": "Paper", "hollow": "Ink Only"}
const EYES := {"dots": "Dots", "lines": "Lines", "ovals": "Ovals", "happy": "Happy", "sleepy": "Sleepy",
	"wide": "Wide", "wink": "Wink", "angry": "Fierce", "none": "None"}
const BROWS := {"none": "None", "flat": "Flat", "arched": "Arched", "angry": "Angry", "worried": "Worried", "thick": "Thick"}
const MOUTHS := {"smile": "Smile", "grin": "Grin", "flat": "Neutral", "open": "Excited", "smirk": "Smirk",
	"tongue": "Cheeky", "frown": "Frown", "o": "Oh!", "none": "None"}
const MARKS := {"none": "None", "freckles": "Freckles", "blush": "Blush", "scar": "Scar", "beard": "Beard",
	"mustache": "Mustache", "paint": "Face Paint"}

const PANTS_CUTS := {
	"flare": "Flared", "bell": "Bell Bottoms", "baggy": "Baggy", "straight": "Straight", "skinny": "Skinny",
	"shorts": "Shorts", "capri": "Capri", "harem": "Harem",
}
## Shape presets: waist / cuff half-widths (rig units), flare curve power, mid-leg bag, length.
const CUT_SHAPES := {
	"flare": {"waist": 3.9, "cuff": 6.6, "pow": 1.8, "bag": 0.3, "len": 1.0},
	"bell": {"waist": 3.7, "cuff": 8.6, "pow": 2.7, "bag": 0.0, "len": 1.0},
	"baggy": {"waist": 4.6, "cuff": 5.6, "pow": 1.0, "bag": 2.3, "len": 1.0},
	"straight": {"waist": 3.8, "cuff": 4.3, "pow": 1.0, "bag": 0.25, "len": 1.0},
	"skinny": {"waist": 3.3, "cuff": 2.6, "pow": 1.0, "bag": 0.1, "len": 1.0},
	"shorts": {"waist": 4.1, "cuff": 5.4, "pow": 1.0, "bag": 0.3, "len": 0.5},
	"capri": {"waist": 3.8, "cuff": 4.8, "pow": 1.2, "bag": 0.5, "len": 0.76},
	"harem": {"waist": 4.6, "cuff": 2.7, "pow": 1.0, "bag": 3.6, "len": 1.0},
}
const PATTERNS := {
	"solid": "Solid", "stripes": "Racing Stripe", "pinstripe": "Pinstripe", "hoops": "Hoops", "twotone": "Two-Tone",
	"dots": "Polka Dots", "checks": "Checks", "zigzag": "Zigzag", "stars": "Stars", "flames": "Flames", "split": "Split Legs",
}
const CUFFS := {"open": "Open", "narrow": "Gathered", "rolled": "Rolled", "frayed": "Frayed"}

const TOPS := {"none": "None", "tee": "Tee", "polo": "Polo", "tank": "Tank Top", "hoodie": "Hoodie", "jacket": "Jacket",
	"sweater": "Sweater", "vest": "Vest", "coat": "Long Coat", "robe": "Robe", "jersey": "Jersey"}
const HATS := {"": "No Hat", "cap": "Ball Cap", "cap_back": "Backwards Cap", "beanie": "Beanie", "bucket": "Bucket Hat",
	"tophat": "Top Hat", "cowboy": "Ranger", "crown": "Crown", "headband": "Headband", "wizard": "Wizard",
	"viking": "Viking", "halo": "Halo", "bandana": "Bandana", "pirate": "Tricorn", "dino": "Dino Hood",
	"antenna": "Antenna", "helmet": "Space Bubble", "helm": "Knight Helm"}
const EYEWEAR := {"": "None", "round": "Round Specs", "square": "Square Specs", "shades": "Shades", "visor": "Visor",
	"monocle": "Monocle", "goggles": "Goggles", "patch": "Eye Patch"}
const NECK := {"": "None", "scarf": "Scarf", "bandana": "Neckerchief", "bowtie": "Bow Tie"}
const BACK := {"": "None", "cape": "Cape", "backpack": "Backpack", "golfbag": "Golf Bag", "wings": "Wings"}
const GLOVES := {"": "None", "golf": "Golf Glove", "mitten": "Mittens", "wristband": "Wristbands"}
const SHOES := {"classic": "Ink", "sneaker": "Sneakers", "boot": "Boots", "loafer": "Loafers", "spike": "Golf Spikes"}
const COMPANIONS := {"": "None", "bird": "Birdie", "ghost": "Boo", "drone": "Drone", "star": "Lucky Star", "dino": "Dino Buddy"}
const CLUBS := {"iron": "Iron", "driver": "Driver", "wood": "Classic Wood", "putter": "Putter", "golden": "Golden Iron",
	"candy": "Candy Cane", "laser": "Laser Club", "bone": "Bone Club"}

## Hat styles that cover the crown of the head (hair spikes above the brim are tucked away).
const HATS_COVER_CROWN := ["cap", "cap_back", "beanie", "bucket", "tophat", "cowboy", "wizard", "viking", "bandana", "pirate", "dino", "helm"]

const PALETTE := [
	"#1c1714", "#ffffff", "#fbf6ec", "#e9e1d0", "#ffd166", "#f2b630", "#f28c38", "#e8543a",
	"#d6304a", "#ef7aa0", "#b5179e", "#7a3fcf", "#3c6fe0", "#3fa3e8", "#4cc9f0", "#1fb5a3",
	"#3dbf7f", "#5d8a3a", "#8d6e63", "#c9a46b", "#adb5bd", "#6c757d", "#2b3a55", "#4a2c1d",
]

const DEFAULT := {
	"hair": "spikes", "hairColor": "",
	"headFill": "paper",
	"eyes": "dots", "brows": "none", "mouth": "smile", "mark": "none",
	"pantsCut": "flare", "pantsColor": "#3c6fe0", "pantsColor2": "#ffd166", "pantsPattern": "solid",
	"pantsLength": 1.0, "pantsFlare": 1.0, "pantsWaist": 0.0, "pantsCuff": "open",
	"top": "none", "topColor": "#ffffff", "topColor2": "#1c1714",
	"hat": "", "hatColor": "#e8543a",
	"eyewear": "", "eyewearColor": "#1c1714",
	"neck": "", "neckColor": "#d6304a",
	"back": "", "backColor": "#d6304a",
	"gloves": "", "glovesColor": "#ffffff",
	"shoes": "classic", "shoesColor": "#1c1714",
	"companion": "",
	"club": "iron",
	"drawings": {},
}

## Option tables by key, for validation and the Golfer Studio.
const OPTIONS := {
	"hair": HAIR, "headFill": HEAD_FILL, "eyes": EYES, "brows": BROWS, "mouth": MOUTHS, "mark": MARKS,
	"pantsCut": PANTS_CUTS, "pantsPattern": PATTERNS, "pantsCuff": CUFFS, "top": TOPS, "hat": HATS,
	"eyewear": EYEWEAR, "neck": NECK, "back": BACK, "gloves": GLOVES, "shoes": SHOES,
	"companion": COMPANIONS, "club": CLUBS,
}
const COLOR_KEYS := ["hairColor", "pantsColor", "pantsColor2", "topColor", "topColor2", "hatColor", "eyewearColor",
	"neckColor", "backColor", "glovesColor", "shoesColor"]
const RANGES := {"pantsLength": [0.45, 1.0], "pantsFlare": [0.6, 1.8], "pantsWaist": [-4.0, 4.0]}

## Themed outfits. They replace the old roster artwork: every former character id is now a look
## on the same stick figure, so stored profiles, unlocks and server ids stay valid.
const OUTFITS := {
	"stickman": {"name": "Stickman", "tagline": "The classic. Yours to design from head to toe.", "rarity": "common", "ink": {}},
	"rex": {"name": "Rex", "tagline": "Never met a fairway he couldn't fly over.", "rarity": "common",
		"ball": "#ffffff", "trail": "#ff9a3c",
		"ink": {"hair": "quiff", "hairColor": "#e0702a", "top": "polo", "topColor": "#f4f1de", "pantsCut": "straight",
			"pantsColor": "#3e8a4f", "shoes": "sneaker", "shoesColor": "#ffffff", "mouth": "grin"}},
	"mira": {"name": "Mira", "tagline": "Ponytail up, putter ready, rivals nervous.", "rarity": "rare",
		"ball": "#fff3b0", "trail": "#b65cff",
		"ink": {"hair": "ponytail", "hairColor": "#7a3fcf", "top": "tank", "topColor": "#ef7aa0", "pantsCut": "capri",
			"pantsColor": "#5b3fa8", "club": "putter", "brows": "arched", "mouth": "smirk"}},
	"bjorn": {"name": "Bjorn", "tagline": "Swings like he's splitting logs. Usually is.", "rarity": "epic",
		"ball": "#e8f0ff", "trail": "#ff5a3c",
		"ink": {"hair": "messy", "hairColor": "#c9772f", "mark": "beard", "hat": "viking", "hatColor": "#adb5bd",
			"top": "sweater", "topColor": "#a8322d", "pantsCut": "baggy", "pantsColor": "#4a5a6a", "shoes": "boot", "shoesColor": "#4a2c1d", "brows": "thick"}},
	"adventurer": {"name": "Adventurer", "tagline": "Packs light. Swings heavy.", "rarity": "epic", "hidden": true,
		"ink": {"hat": "bucket", "hatColor": "#c9a46b", "back": "backpack", "backColor": "#8d6e63", "top": "jacket",
			"topColor": "#5d8a3a", "pantsCut": "baggy", "pantsColor": "#a68a5b", "shoes": "boot", "shoesColor": "#4a2c1d"}},
	"bolt": {"name": "Bolt", "tagline": "Caddie bot 3000. Calculates every bounce.", "rarity": "rare",
		"ink": {"hair": "none", "hat": "antenna", "hatColor": "#e8543a", "eyewear": "visor", "eyewearColor": "#4cc9f0",
			"top": "jacket", "topColor": "#8d99ae", "topColor2": "#5c677d", "pantsCut": "straight", "pantsColor": "#5c677d",
			"pantsPattern": "hoops", "pantsColor2": "#adb5bd", "gloves": "mitten", "glovesColor": "#adb5bd", "shoes": "boot", "shoesColor": "#3d4452",
			"companion": "drone", "club": "laser", "mouth": "flat", "eyes": "none"}},
	"pirate": {"name": "Cap'n Slice", "tagline": "Never met a water hazard he couldn't sail over.", "rarity": "epic",
		"ink": {"hat": "pirate", "hatColor": "#1c1714", "eyewear": "patch", "mark": "beard", "hairColor": "#1c1714", "hair": "long",
			"top": "coat", "topColor": "#a3262a", "topColor2": "#f2b630", "pantsCut": "baggy", "pantsColor": "#fbf6ec",
			"pantsPattern": "hoops", "pantsColor2": "#d6304a", "shoes": "boot", "companion": "bird", "mouth": "grin"}},
	"wizard": {"name": "Fizzwick", "tagline": "Swears the ball goes wherever he tells it.", "rarity": "epic",
		"ink": {"hat": "wizard", "hatColor": "#3c6fe0", "mark": "beard", "top": "robe", "topColor": "#3a2a9c", "topColor2": "#ffd166",
			"pantsCut": "harem", "pantsColor": "#7a3fcf", "pantsPattern": "stars", "pantsColor2": "#ffd166", "companion": "star", "club": "wood", "eyes": "sleepy"}},
	"dino": {"name": "Tee-Rex", "tagline": "Tiny arms. Enormous drives.", "rarity": "rare",
		"ink": {"hat": "dino", "hatColor": "#4caf50", "top": "hoodie", "topColor": "#4caf50", "pantsCut": "baggy",
			"pantsColor": "#3d8b40", "pantsPattern": "dots", "pantsColor2": "#7bd17f", "shoes": "boot", "shoesColor": "#2e6b31", "mouth": "grin", "companion": "dino"}},
	"astronaut": {"name": "Nova", "tagline": "Practised her drive in zero gravity. Twice.", "rarity": "legendary",
		"ink": {"hat": "helmet", "hatColor": "#bfe9ff", "hair": "bob", "hairColor": "#3a2a2a", "top": "jacket", "topColor": "#f4f4f4",
			"topColor2": "#e8543a", "back": "backpack", "backColor": "#d9d9d9", "pantsCut": "straight", "pantsColor": "#f4f4f4",
			"pantsPattern": "stripes", "pantsColor2": "#e8543a", "gloves": "mitten", "glovesColor": "#f4f4f4", "shoes": "boot", "shoesColor": "#bfc6cf"}},
	"skeleton": {"name": "Rattles", "tagline": "All skin and no bones. Wait, other way round.", "rarity": "rare",
		"ink": {"hair": "none", "headFill": "paper", "eyes": "ovals", "mouth": "grin", "top": "tee", "topColor": "#2b2d42",
			"pantsCut": "skinny", "pantsColor": "#2b2d42", "pantsPattern": "pinstripe", "pantsColor2": "#e9e1d0", "club": "bone"}},
	"frost": {"name": "Frost", "tagline": "Gentle yeti. Plays every course barefoot.", "rarity": "rare",
		"ink": {"hair": "afro", "hairColor": "#f4fbff", "hat": "beanie", "hatColor": "#4cc9f0", "neck": "scarf", "neckColor": "#3c6fe0",
			"top": "sweater", "topColor": "#dff3ff", "pantsCut": "baggy", "pantsColor": "#3fa3e8", "gloves": "mitten", "glovesColor": "#4cc9f0"}},
	"cowboy": {"name": "Dusty", "tagline": "Fastest backswing in the West.", "rarity": "uncommon",
		"ink": {"hat": "cowboy", "hatColor": "#8b5a2b", "neck": "bandana", "neckColor": "#d6304a", "mark": "mustache",
			"top": "vest", "topColor": "#c9a46b", "pantsCut": "bell", "pantsColor": "#6d4c41", "shoes": "boot", "shoesColor": "#4a2c1d", "eyes": "lines"}},
	"knight": {"name": "Sir Putts", "tagline": "Sworn to protect the green.", "rarity": "legendary",
		"ink": {"hat": "helm", "hatColor": "#b8c0cc", "back": "cape", "backColor": "#b02a3a", "top": "jersey", "topColor": "#b8c0cc",
			"topColor2": "#b02a3a", "pantsCut": "straight", "pantsColor": "#8d99ae", "pantsPattern": "twotone", "pantsColor2": "#b02a3a",
			"gloves": "mitten", "glovesColor": "#b8c0cc", "shoes": "boot", "shoesColor": "#6c757d", "club": "golden"}},
	"ace": {"name": "Ace", "tagline": "Tour pro. Fairways fear him.", "rarity": "uncommon",
		"ink": {"hat": "cap", "hatColor": "#ffffff", "eyewear": "shades", "top": "polo", "topColor": "#1d3557", "pantsCut": "straight",
			"pantsColor": "#f4f1de", "pantsPattern": "pinstripe", "pantsColor2": "#1d3557", "gloves": "golf", "shoes": "spike", "shoesColor": "#ffffff", "club": "driver"}},
	"nana": {"name": "Nana Birdie", "tagline": "Eighty-one years young. Still outdrives you.", "rarity": "rare",
		"ink": {"hair": "bun", "hairColor": "#d9d4cc", "eyewear": "round", "top": "sweater", "topColor": "#b8a1d9", "pantsCut": "straight",
			"pantsColor": "#e07a9f", "pantsPattern": "checks", "pantsColor2": "#f7c6d6", "shoes": "loafer", "shoesColor": "#6d4c41", "companion": "bird", "mouth": "smile", "brows": "arched"}},
	"brick": {"name": "Brick", "tagline": "Lumberjack. Swings like he's felling an oak.", "rarity": "uncommon",
		"ink": {"hat": "beanie", "hatColor": "#d6304a", "mark": "beard", "hairColor": "#6b3d1f", "top": "jacket", "topColor": "#b5302a",
			"topColor2": "#1c1714", "pantsCut": "baggy", "pantsColor": "#3d5a80", "shoes": "boot", "shoesColor": "#4a2c1d", "brows": "thick", "club": "wood"}},
	"skipper": {"name": "Skipper", "tagline": "Ten years old. Already has a hole-in-one.", "rarity": "common",
		"ink": {"hat": "cap_back", "hatColor": "#3c6fe0", "top": "tee", "topColor": "#ffd166", "pantsCut": "shorts", "pantsColor": "#e8543a",
			"shoes": "sneaker", "shoesColor": "#d6304a", "mark": "freckles", "eyes": "wide", "mouth": "open"}},
}

## Signature parts: each one unlocks with the themed outfit it comes from (Collection ownership
## of that character item), so rare outfits keep their value. Everything else is free.
## key -> {value: outfit id}. Mirrored by backend/src/profile/appearance.ts SIGNATURE_PARTS.
const SIGNATURE := {
	"hat": {"viking": "bjorn", "pirate": "pirate", "wizard": "wizard", "dino": "dino", "antenna": "bolt", "helmet": "astronaut", "helm": "knight"},
	"eyewear": {"visor": "bolt", "patch": "pirate"},
	"back": {"cape": "knight", "wings": "astronaut"},
	"companion": {"drone": "bolt", "bird": "pirate", "star": "wizard", "dino": "dino", "ghost": "skeleton"},
	"club": {"laser": "bolt", "golden": "knight", "bone": "skeleton"},
	"pantsPattern": {"stars": "wizard", "flames": "cowboy"},
}


## The outfit that unlocks part `key = value` ("" when the part is free).
static func signature_outfit(key: String, value: String) -> String:
	return str((SIGNATURE.get(key, {}) as Dictionary).get(value, ""))


## Old v1 eye ids -> (eyes, eyewear).
const V1_EYES := {"dot": ["dots", ""], "happy": ["happy", ""], "big": ["wide", ""], "sleepy": ["sleepy", ""],
	"angry": ["angry", ""], "shades": ["dots", "shades"], "visor": ["none", "visor"], "wink": ["wink", ""]}


static func outfit_ids(include_hidden: bool = false) -> Array:
	return OUTFITS.keys().filter(func(id: String) -> bool: return include_hidden or not bool(OUTFITS[id].get("hidden", false)))


static func has_outfit(id: String) -> bool:
	return OUTFITS.has(id)


static func outfit(id: String) -> Dictionary:
	return OUTFITS.get(id, OUTFITS.stickman)


## Full ink look for an outfit id (defaults + the outfit's patch).
static func outfit_look(id: String) -> Dictionary:
	var out := DEFAULT.duplicate(true)
	var patch: Dictionary = outfit(id).ink
	for k in patch:
		out[k] = patch[k]
	return out


## Validates and fills an `ink` dictionary.
static func normalize(raw: Variant) -> Dictionary:
	var out := DEFAULT.duplicate(true)
	if not raw is Dictionary:
		return out
	var d: Dictionary = raw
	for key: String in OPTIONS:
		if d.has(key) and (OPTIONS[key] as Dictionary).has(str(d[key])):
			out[key] = str(d[key])
	for key: String in COLOR_KEYS:
		if d.has(key):
			var s := str(d[key])
			if is_hex(s) or (key == "hairColor" and s == ""):
				out[key] = s.to_lower()
	for key: String in RANGES:
		if d.has(key) and (d[key] is float or d[key] is int):
			var r: Array = RANGES[key]
			out[key] = clampf(float(d[key]), float(r[0]), float(r[1]))
	out.drawings = InkDrawing.normalize_all(d.get("drawings", {}))
	return out


## Builds an ink look for an Appearance that has no `ink` yet (v1 profiles): the character id
## becomes its outfit, and a customised v1 stickman keeps its colours, hat, shirt and face.
static func from_v1(a: Dictionary) -> Dictionary:
	var id := str(a.get("character", "stickman"))
	var out := outfit_look(id if OUTFITS.has(id) else "stickman")
	if id != "stickman" and OUTFITS.has(id):
		return out
	var hat = a.get("hat")
	if hat != null and HATS.has(str(hat)):
		out.hat = str(hat)
	out.hatColor = str(a.get("hatColor", out.hatColor))
	var shirt = a.get("shirt")
	if shirt != null and TOPS.has(str(shirt)):
		out.top = str(shirt)
	out.topColor = str(a.get("shirtColor", out.topColor))
	var e: Array = V1_EYES.get(str(a.get("eyes", "dot")), ["dots", ""])
	out.eyes = e[0]
	out.eyewear = e[1]
	if MOUTHS.has(str(a.get("mouth", ""))):
		out.mouth = str(a.mouth)
	# The v1 body colour becomes the pants colour unless it was a near-black ink body.
	var body := Color(str(a.get("bodyColor", "#2b2d42")))
	if body.get_luminance() > 0.22:
		out.pantsColor = str(a.bodyColor)
	return out


static func is_hex(s: String) -> bool:
	return s.length() == 7 and s.begins_with("#") and s.substr(1).is_valid_hex_number()


static func cut_shape(look: Dictionary) -> Dictionary:
	var c: Dictionary = (CUT_SHAPES.get(str(look.pantsCut), CUT_SHAPES.flare) as Dictionary).duplicate()
	c.cuff = float(c.cuff) * float(look.pantsFlare)
	c.len = minf(float(c.len), float(look.pantsLength)) if float(look.pantsLength) < 0.999 else float(c.len)
	return c
