class_name InkThemes
extends RefCounted
## Hand-drawn world palettes (docs/INK_ART_SPEC.md §3, §9). A course theme picks one with
## `"ink": "<id>"` (falling back to its `"id"`). Each palette fully defines terrain, material
## strips, water and the backdrop layer stack, so a new course only needs layout data.

const BASE := {
	"ink": "#1c1714",
	"sky_top": "#bfdcec", "sky_bottom": "#f4efe3", "grain": 0.05, "swirl": "#e7e0d2",
	"far": "#b5c7d4", "far_line": "#9db1c1", "far_snow": "#f2f4f3",
	"cloud": "#fdfbf6", "cloud_line": "#a9bccb",
	"mid": "#a7cd94", "mid_line": "#86b375", "mid_tree": "#8dbd7a",
	"near": "#7fbc66", "near_line": "#5e9c4c", "near_tree": "#6aac56", "near_tree_dark": "#4f8f41",
	"soil_top": "#c08d5a", "soil_deep": "#7c5136", "soil_line": "#8e623f", "soil_mark": "#6d4730", "pebble": "#d8c3a2",
	"grass": "#5db244", "grass_light": "#96d468", "grass_dark": "#3c8c33",
	"flowers": ["#ffffff", "#f7d24a", "#ef7aa0", "#b28be8"],
	"water": "#62bde8", "water_deep": "#3b8dc8", "water_line": "#245e8e",
	"sand": "#f0d48f", "sand_dark": "#cfa95f",
	"ice": "#cdeefb", "ice_light": "#ffffff", "ice_dark": "#8ccbe6",
	"snow": "#fbfdff", "snow_shadow": "#b9d3ea",
	"sticky": "#b462e8", "sticky_dark": "#7a35b8",
	"bouncy": "#ef4d63", "bouncy_light": "#fff2f2",
	"rock": "#a3a9b4", "rock_dark": "#6b7180",
	"wood": "#c48a55", "wood_dark": "#8a5a33",
	"metal": "#a9b4c2", "metal_dark": "#5f6b7c",
	"layers": ["mountains", "clouds", "hills", "trees"],
	"decor_tint": "#000000",
}

const THEMES := {
	"meadow": {},
	"beach": {
		"sky_top": "#a9dcef", "sky_bottom": "#fbf1dc", "far": "#9fc9da", "far_line": "#86b3c6",
		"mid": "#7ec7c4", "mid_line": "#5eaaa8", "near": "#e9cf93", "near_line": "#c8aa6b", "near_tree": "#58a35a", "near_tree_dark": "#3f8044",
		"soil_top": "#e8c98b", "soil_deep": "#b88c55", "soil_line": "#c9a26a", "soil_mark": "#a07c4a", "pebble": "#fff3d9",
		"grass": "#79bf4f", "grass_light": "#a8db78", "grass_dark": "#4f9a3a",
		"layers": ["sea", "clouds", "dunes", "palms"],
	},
	"sticky": {
		"sky_top": "#e4d4ef", "sky_bottom": "#f6efe8", "far": "#c9b5dc", "far_line": "#ae97c6",
		"mid": "#b7a2d4", "mid_line": "#977fbd", "near": "#9b84c4", "near_line": "#7a62a8", "near_tree": "#8a6fc0", "near_tree_dark": "#6b519e",
		"soil_top": "#8f6aa8", "soil_deep": "#4f3466", "soil_line": "#6f4f88", "soil_mark": "#3f2850", "pebble": "#c4a9da",
		"grass": "#72b04f", "grass_light": "#a2d374", "grass_dark": "#4a8a39",
		"layers": ["mountains", "clouds", "hills", "trees"],
	},
	"snow": {
		"ink": "#1b2233",
		"sky_top": "#c5d9ea", "sky_bottom": "#f2f4f6", "far": "#c8d6e4", "far_line": "#a9bdd1", "far_snow": "#ffffff",
		"mid": "#dce7f1", "mid_line": "#b4c8da", "mid_tree": "#8fa8b8", "near": "#eef3f8", "near_line": "#bccfe0", "near_tree": "#5f8a78", "near_tree_dark": "#46705f",
		"soil_top": "#9aa7b8", "soil_deep": "#5c6678", "soil_line": "#7e8b9d", "soil_mark": "#4d5767", "pebble": "#c9d2de",
		"grass": "#fbfdff", "grass_light": "#ffffff", "grass_dark": "#b9d3ea",
		"layers": ["peaks", "clouds", "snowhills", "pines"],
	},
	"lab": {
		"ink": "#16182a",
		"sky_top": "#d4dbf2", "sky_bottom": "#f3f1f8", "swirl": "#e2dff0", "far": "#bcc3e2", "far_line": "#a0a8cf",
		"mid": "#b3bde0", "mid_line": "#929dc9", "near": "#9fa9d6", "near_line": "#7f8abb", "near_tree": "#8e99cc", "near_tree_dark": "#6f79ab",
		"soil_top": "#8d93ad", "soil_deep": "#4a4f66", "soil_line": "#6d7390", "soil_mark": "#3e4258", "pebble": "#c3c8dc",
		"grass": "#61c3a8", "grass_light": "#93e0c9", "grass_dark": "#3c9a82",
		"layers": ["towers", "clouds", "hills", "machines"],
	},
	"spin": {
		"sky_top": "#f3d9c4", "sky_bottom": "#f8f1e6", "far": "#e3c3b5", "far_line": "#cfa697",
		"mid": "#e6b98f", "mid_line": "#c9996f", "near": "#d9a46e", "near_line": "#b9844f", "near_tree": "#b7c46a", "near_tree_dark": "#8d9a48",
		"soil_top": "#d29665", "soil_deep": "#8a5634", "soil_line": "#a86f45", "soil_mark": "#7a4a2b", "pebble": "#f0d3b2",
		"grass": "#93b84a", "grass_light": "#bfd879", "grass_dark": "#6b8f33",
		"layers": ["mesas", "clouds", "hills", "swirls"],
	},
}


static func get_palette(theme: Dictionary) -> Dictionary:
	var id := str(theme.get("ink", theme.get("id", "meadow")))
	var out := BASE.duplicate(true)
	var t: Dictionary = THEMES.get(id, {})
	for k in t:
		out[k] = t[k]
	out.id = id
	return out


static func col(p: Dictionary, key: String) -> Color:
	return Color(str(p.get(key, BASE.get(key, "#ff00ff"))))
