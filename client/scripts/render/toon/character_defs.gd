class_name CharacterDefs
extends RefCounted
## Data-driven golfer definitions (docs/CHARACTER_ART_SPEC.md). Every playable character is one
## entry: identity, rig proportions, palette, what the player may customise, motion style and
## progression data. `ToonCharacters` holds the builder for each `builder` id.
##
## Ids are stored in player profiles (appearance.character), so never rename or remove one.
## Run `validate()` (tests/test_characters.gd does) after adding or editing an entry.

## Shared rig (rig units, origin on the ground between the feet, facing +x).
const RIG := {
	"leg": 5.0,            ## visible leg/shoe height under the body
	"body": 26.0,          ## spine length, base to neck
	"r": [11.0, 10.0, 8.5],  ## body radii at base, middle, top
	"head_r": 14.0,
	"head_sink": 4.0,      ## how far the head overlaps the body top
	"shoulder_t": 0.74,    ## shoulder position along the spine
	"reach": 17.0,         ## shoulder-to-hand length (noodle arm)
	"arm_w": 2.3,          ## arm radius at the shoulder
	"hand_r": 3.4,
	"club": 22.0,          ## grip-to-hosel length
	"feet": 6.0,           ## half stance width
	"lean": 0.08,          ## resting forward lean (radians)
}

## Body and arm slimming applied to every rig.
const SLIM := 0.66
const ARM_SLIM := 0.8

const RARITIES := ["common", "uncommon", "rare", "epic", "legendary", "mythic"]
const KINDS := ["classic", "human", "robot", "creature", "undead", "armored"]
const WALKS := ["step", "roll", "waddle"]

## Every customisation slot a character can accept. Characters with a signature outfit leave the
## matching slots off so a player's stickman hat never lands on, say, the wizard.
const SLOTS := ["body_color", "outline_color", "head_shape", "face", "hat", "shirt", "proportions"]

const ROSTER := {
	# Hand-authored sprite character (art/characters/adventurer). Hidden from the roster until its
	# full animation set is drawn and approved; reachable by id for review (--dev-character).
	# Sprite golfers (v3 art direction): generated + cleaned pixel art, pose-guided animation
	# (tools/artgen, docs/SPRITE_PIPELINE.md). Idle + swing so far; other anims fall back to idle.
	"rex": {
		"name": "Rex", "tagline": "Never met a fairway he couldn't fly over.",
		"kind": "human", "builder": "sprite", "rarity": "common", "unlock": {"type": "default"},
		"scale": 1.0, "rig": {}, "colors": {}, "compat": [], "motion": {"walk": "step"},
		"ball": "#ffffff", "trail": "#ff9a3c",
	},
	"mira": {
		"name": "Mira", "tagline": "Ponytail up, putter ready, rivals nervous.",
		"kind": "human", "builder": "sprite", "rarity": "rare", "unlock": {"type": "default"},
		"scale": 1.0, "rig": {}, "colors": {}, "compat": [], "motion": {"walk": "step"},
		"ball": "#fff3b0", "trail": "#b65cff",
	},
	"bjorn": {
		"name": "Bjorn", "tagline": "Swings like he's splitting logs. Usually is.",
		"kind": "human", "builder": "sprite", "rarity": "epic", "unlock": {"type": "default"},
		"scale": 1.0, "rig": {}, "colors": {}, "compat": [], "motion": {"walk": "step"},
		"ball": "#e8f0ff", "trail": "#ff5a3c",
	},
	"adventurer": {
		"name": "Adventurer", "tagline": "Packs light. Swings heavy.",
		"kind": "human", "builder": "sprite", "rarity": "epic", "unlock": {"type": "default"},
		"scale": 1.0, "rig": {}, "colors": {}, "compat": [],
		"motion": {"walk": "step"},
		"ball": "#ffffff", "trail": "#ff7a6a",
		"hidden": true,
	},
	"stickman": {
		"name": "Stickman", "tagline": "The classic. Yours to design from head to toe.",
		"kind": "classic", "builder": "classic", "rarity": "common", "unlock": {"type": "default"},
		"scale": 1.0, "rig": {},
		"colors": {"shoe": "#2b2d42"},
		"compat": ["body_color", "outline_color", "head_shape", "face", "hat", "shirt", "proportions"],
		"motion": {"walk": "step"},
		"ball": "#ffffff", "trail": "#ffd166",
	},
	"bolt": {
		"name": "Bolt", "tagline": "Caddie bot 3000. Calculates every bounce.",
		"kind": "robot", "builder": "robot", "rarity": "rare", "unlock": {"type": "default"},
		"scale": 1.0,
		"rig": {"leg": 12.0, "body": 20.0, "r": [10.5, 10.5, 10.0], "head_r": 14.0, "head_sink": 1.0,
			"shoulder_t": 0.7, "reach": 16.0, "arm_w": 1.9, "hand_r": 3.6, "club": 23.0, "lean": 0.04},
		"colors": {"body": "#2ec4b6", "panel": "#fdf3d8", "metal": "#a9b6cc", "dark": "#3d4a63",
			"screen": "#13213a", "led": "#6ff7ff", "accent": "#ffd166", "light": "#ef476f", "tyre": "#2b2d42"},
		"compat": [],
		"motion": {"walk": "roll"},
		"ball": "#c9fffd", "trail": "#3fe0d0",
	},
	"pirate": {
		"name": "Cap'n Slice", "tagline": "Never met a water hazard he couldn't sail over.",
		"kind": "human", "builder": "pirate", "rarity": "rare", "unlock": {"type": "default"},
		"scale": 1.02,
		"rig": {"r": [12.0, 11.0, 9.5], "body": 25.0, "head_r": 14.0, "arm_w": 2.3},
		"colors": {"coat": "#2b4a8c", "trim": "#ffd166", "skin": "#eaa87c", "beard": "#d4572a", "wood": "#a0673d",
			"boot": "#3a2a24", "sash": "#e63946", "stripe": "#2ec4b6", "hat": "#262833"},
		"compat": [],
		"motion": {"walk": "waddle"},
		"ball": "#fff3d6", "trail": "#e63946",
	},
	"wizard": {
		"name": "Fizzwick", "tagline": "Swears the ball goes wherever he tells it.",
		"kind": "human", "builder": "wizard", "rarity": "epic", "unlock": {"type": "default"},
		"scale": 1.0,
		"rig": {"r": [12.0, 10.0, 8.5], "leg": 3.0, "body": 25.0, "head_r": 13.5, "arm_w": 2.0},
		"colors": {"robe": "#6c4bd8", "gold": "#ffd166", "skin": "#f5c9a6", "beard": "#f4f6fb", "spark": "#fff3b0"},
		"compat": [],
		"motion": {"walk": "step"},
		"ball": "#e9dcff", "trail": "#b388ff",
	},
	"dino": {
		"name": "Tee-Rex", "tagline": "Tiny arms. Enormous drives.",
		"kind": "creature", "builder": "dino", "rarity": "epic", "unlock": {"type": "default"},
		"scale": 1.08,
		"rig": {"leg": 7.0, "body": 22.0, "r": [12.5, 11.0, 9.0], "head_r": 12.5, "head_sink": 5.0,
			"shoulder_t": 0.62, "reach": 9.5, "arm_w": 1.9, "hand_r": 2.6, "club": 27.0, "lean": 0.34, "feet": 6.5},
		"colors": {"skin": "#5cc45a", "stripe": "#3d9a4a", "belly": "#f6e7b0", "plate": "#ff9f1c",
			"claw": "#fffbe8", "mouth": "#7a2a3a", "eye": "#1d1a2b"},
		"compat": [],
		"motion": {"walk": "waddle"},
		"ball": "#e8ffd6", "trail": "#7ee36f",
	},
	"astronaut": {
		"name": "Nova", "tagline": "Practised her drive in zero gravity. Twice.",
		"kind": "human", "builder": "astronaut", "rarity": "epic", "unlock": {"type": "default"},
		"scale": 1.0,
		"rig": {"r": [12.5, 12.0, 10.0], "body": 24.0, "head_r": 14.5, "head_sink": 2.5, "arm_w": 2.7, "hand_r": 3.9, "leg": 6.0},
		"colors": {"suit": "#f4f6fb", "accent": "#ff8c42", "grey": "#b9c3d6", "panel": "#2b3a66", "visor": "#2b3a66",
			"skin": "#b07a55", "hair": "#2b1d16"},
		"compat": [],
		"motion": {"walk": "step"},
		"ball": "#ffffff", "trail": "#ff8c42",
	},
	"skeleton": {
		"name": "Rattles", "tagline": "All skin and no bones. Wait, other way round.",
		"kind": "undead", "builder": "skeleton", "rarity": "rare", "unlock": {"type": "default"},
		"scale": 1.0,
		"rig": {"r": [9.5, 9.5, 8.5], "body": 24.0, "arm_w": 1.6, "hand_r": 3.0, "head_r": 14.0, "head_sink": 3.0, "leg": 8.0},
		"colors": {"bone": "#f3ecd8", "vest": "#3f8f5a", "vest2": "#f2c14e", "vest3": "#2c6b43", "glow": "#7df9ff",
			"dark": "#2a2440", "cap": "#8a6f5a", "pants": "#4a4560"},
		"compat": [],
		"motion": {"walk": "step"},
		"ball": "#f3ecd8", "trail": "#7df9ff",
	},
	"frost": {
		"name": "Frost", "tagline": "Gentle yeti. Plays every course barefoot.",
		"kind": "creature", "builder": "frost", "rarity": "rare", "unlock": {"type": "default"},
		"scale": 1.06,
		"rig": {"r": [15.0, 14.5, 12.0], "body": 22.0, "leg": 3.0, "head_r": 14.0, "head_sink": 6.0, "arm_w": 3.2,
			"hand_r": 4.4, "feet": 7.5, "shoulder_t": 0.7},
		"colors": {"fur": "#eef6ff", "skin": "#9fb7d6", "scarf": "#ef476f", "scarf2": "#ffd166", "horn": "#efe2c4", "belly": "#dde9f8"},
		"compat": [],
		"motion": {"walk": "waddle"},
		"ball": "#e6f7ff", "trail": "#9fe3ff",
	},
	"cowboy": {
		"name": "Dusty", "tagline": "Fastest backswing in the West.",
		"kind": "human", "builder": "cowboy", "rarity": "uncommon", "unlock": {"type": "default"},
		"scale": 1.0,
		"rig": {"r": [9.5, 8.8, 8.2], "body": 30.0, "head_r": 13.0, "leg": 7.0, "arm_w": 2.1, "reach": 18.0},
		"colors": {"skin": "#e7a97e", "hat": "#a8743f", "leather": "#8b5a2b", "gold": "#ffd166", "boot": "#6b3e22",
			"shirt": "#e9b949", "jeans": "#3e6bb0", "bandana": "#e63946", "stache": "#6b3e22"},
		"compat": [],
		"motion": {"walk": "step"},
		"ball": "#fff1d6", "trail": "#e9b949",
	},
	"knight": {
		"name": "Sir Putts", "tagline": "Sworn to protect the green.",
		"kind": "armored", "builder": "knight", "rarity": "legendary", "unlock": {"type": "default"},
		"scale": 1.0,
		"rig": {"r": [12.5, 11.5, 10.0], "body": 25.0, "head_r": 13.5, "head_sink": 2.0, "arm_w": 2.6, "hand_r": 3.8},
		"colors": {"steel": "#c3cbd9", "gold": "#ffd166", "tabard": "#3a5bd9", "cape": "#c62f3a", "plume": "#ef476f",
			"dark": "#1d1a2b", "eye": "#fff3b0"},
		"compat": [],
		"motion": {"walk": "step"},
		"ball": "#fff6d6", "trail": "#ffd166",
	},
	"ace": {
		"name": "Ace", "tagline": "Tour pro. Fairways fear him.",
		"kind": "human", "builder": "ace", "rarity": "uncommon", "unlock": {"type": "default"},
		"scale": 1.0,
		"rig": {"r": [10.5, 9.8, 8.5], "body": 28.0, "head_r": 13.5},
		"colors": {"skin": "#f1b98c", "hair": "#5b3a29", "shirt": "#1f4e8c", "pants": "#d9c8a2", "shoe2": "#6b3f26", "hat2": "#1f4e8c"},
		"compat": [],
		"motion": {"walk": "step"},
		"ball": "#ffffff", "trail": "#4cc9f0",
	},
	"nana": {
		"name": "Nana Birdie", "tagline": "Eighty-one years young. Still outdrives you.",
		"kind": "human", "builder": "nana", "rarity": "rare", "unlock": {"type": "default"},
		"scale": 0.94,
		"rig": {"r": [11.5, 10.5, 9.0], "body": 23.0, "head_r": 14.0, "leg": 6.0},
		"colors": {"skin": "#f6d2b8", "hair": "#e6e3ef", "shirt": "#ff8fab", "shirt2": "#fff6f0", "pants": "#9d8df1",
			"shoe": "#7a4b3a", "brow": "#b8b4c8", "glasses": "#8a5a9a", "hat": "#f2d27a", "hat2": "#ef476f"},
		"compat": [],
		"motion": {"walk": "step"},
		"ball": "#ffd6e5", "trail": "#ff8fab",
	},
	"brick": {
		"name": "Brick", "tagline": "Lumberjack. Swings like he's felling an oak.",
		"kind": "human", "builder": "brick", "rarity": "uncommon", "unlock": {"type": "default"},
		"scale": 1.06,
		"rig": {"r": [13.5, 13.0, 11.0], "body": 27.0, "arm_w": 3.0, "hand_r": 4.0, "head_r": 14.0},
		"colors": {"skin": "#e9a87c", "hair": "#c8562a", "shirt": "#c62f3a", "shirt2": "#2b1f2a", "pants": "#3e5f9e",
			"shoe": "#6b4426", "shoe2": "#3b2414", "belt": "#4a2e1d", "hat": "#2a9d8f", "hat2": "#1f7368"},
		"compat": [],
		"motion": {"walk": "step"},
		"ball": "#ffe1c4", "trail": "#c62f3a",
	},
	"skipper": {
		"name": "Skipper", "tagline": "Ten years old. Already has a hole-in-one.",
		"kind": "human", "builder": "skipper", "rarity": "uncommon", "unlock": {"type": "default"},
		"scale": 0.86,
		"rig": {"r": [10.0, 9.5, 8.5], "body": 20.0, "head_r": 15.5, "leg": 8.0},
		"colors": {"skin": "#c98a5e", "hair": "#2b1d16", "shirt": "#ffd166", "shirt2": "#ef476f", "pants": "#2f6fb5",
			"shoe": "#ef476f", "hat": "#4361ee", "hat2": "#ef476f"},
		"compat": [],
		"motion": {"walk": "step"},
		"ball": "#fff3b0", "trail": "#ffd166",
	},
}


## Selectable characters (hidden work-in-progress entries are left out).
static func ids() -> Array:
	return ROSTER.keys().filter(func(id: String) -> bool: return not bool(ROSTER[id].get("hidden", false)))


## Characters drawn from hand-authored sprite sheets instead of the toon rig.
static func is_sprite(id: String) -> bool:
	return str(get_def(id).get("builder", "")) == "sprite"


static func has(id: String) -> bool:
	return ROSTER.has(id)


static func get_def(id: String) -> Dictionary:
	return ROSTER.get(id, ROSTER.stickman)


## Rig for a character: the shared RIG with the character's overrides applied.
static func rig(id: String) -> Dictionary:
	var r := RIG.duplicate(true)
	var o: Dictionary = get_def(id).get("rig", {})
	for k in o:
		r[k] = o[k]
	# Everyone is drawn lean (stick-figure golf): bodies and arms slimmed, bodies a bit taller.
	var rr: Array = r.r
	r.r = [float(rr[0]) * SLIM, float(rr[1]) * SLIM, float(rr[2]) * SLIM]
	r.arm_w = float(r.arm_w) * ARM_SLIM
	r.body = float(r.body) * 1.12
	r.feet = float(r.feet) * 0.8
	return r


static func color(def: Dictionary, key: String, fallback: String = "#ff00ff") -> Color:
	return Color(str((def.get("colors", {}) as Dictionary).get(key, fallback)))


static func accepts(id: String, slot: String) -> bool:
	return slot in (get_def(id).get("compat", []) as Array)


## Ids that existing player profiles may hold. They must always resolve (tests check this).
const LEGACY_IDS := ["stickman", "ace", "nana", "brick", "bolt", "skipper", "frost"]


## Returns a list of problems with the definitions (empty when everything is valid).
static func validate() -> PackedStringArray:
	var errs := PackedStringArray()
	for id: String in ROSTER:
		var d: Dictionary = ROSTER[id]
		var tag := "character '%s'" % id
		if not id.is_valid_identifier() or id.to_lower() != id or id.length() > 32:
			errs.append("%s: id must be lowercase [a-z0-9_] (max 32)" % tag)
		for key in ["name", "tagline", "kind", "builder", "rarity", "unlock", "scale", "rig", "colors", "compat", "motion", "ball", "trail"]:
			if not d.has(key):
				errs.append("%s: missing '%s'" % [tag, key])
		if errs.size() > 0 and errs[errs.size() - 1].begins_with(tag + ": missing"):
			continue
		if str(d.kind) not in KINDS:
			errs.append("%s: unknown kind '%s'" % [tag, d.kind])
		if str(d.rarity) not in RARITIES:
			errs.append("%s: unknown rarity '%s'" % [tag, d.rarity])
		if str(d.builder) == "sprite":
			if not SpriteCharacter.exists(id):
				errs.append("%s: sprite character has no exported sheets (run tools/sprites/build_character.py %s)" % [tag, id])
		elif not ToonCharacters.has_builder(str(d.builder)):
			errs.append("%s: no builder '%s' in ToonCharacters" % [tag, d.builder])
		if str((d.motion as Dictionary).get("walk", "step")) not in WALKS:
			errs.append("%s: unknown walk style" % tag)
		var u: Dictionary = d.unlock
		if str(u.get("type", "")) not in ["default", "level"]:
			errs.append("%s: unlock type must be default or level" % tag)
		elif str(u.type) == "level" and int(u.get("level", 0)) < 1:
			errs.append("%s: level unlock needs level >= 1" % tag)
		if float(d.scale) < 0.7 or float(d.scale) > 1.3:
			errs.append("%s: scale %.2f outside 0.7-1.3" % [tag, d.scale])
		for slot in d.compat:
			if str(slot) not in SLOTS:
				errs.append("%s: unknown compat slot '%s'" % [tag, slot])
		for hex in [d.ball, d.trail]:
			if not _is_hex(hex):
				errs.append("%s: bad colour %s" % [tag, hex])
		for k in d.colors:
			if not _is_hex(d.colors[k]):
				errs.append("%s: colour '%s' is not #rrggbb" % [tag, k])
		var r := rig(id)
		for k in RIG:
			if typeof(r[k]) != typeof(RIG[k]):
				errs.append("%s: rig.%s has the wrong type" % [tag, k])
		if (r.r as Array).size() != 3:
			errs.append("%s: rig.r needs 3 radii" % tag)
		if float(r.head_r) < 8.0 or float(r.head_r) > 20.0:
			errs.append("%s: head_r out of range" % tag)
		if float(r.reach) + float(r.club) < 25.0:
			errs.append("%s: arm reach + club too short to reach the ball" % tag)
	return errs


static func _is_hex(v: Variant) -> bool:
	var s := str(v)
	return s.length() == 7 and s.begins_with("#") and s.substr(1).is_valid_hex_number()
