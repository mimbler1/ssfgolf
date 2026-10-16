extends Node2D
## Developer gallery for ink art review screenshots (tools/shot.sh ... res://scenes/dev/gallery.tscn).
##   (no args) | --ink-poses [outfit] [scale]   one golfer frozen through the key poses
##   --ink-outfits [scale]                      every themed outfit in idle
##   --ink-sizes [outfit]                       one golfer at thumbnail, gameplay, card and studio size
##   --ink-live [outfit] [scale]                live (unfrozen) row: idle, aim, swing loop, walk, run, dance
##   --ink-looks                                customisation sampler (hair, pants, hats, tops)

const POSES := [
	["idle", 0.0], ["aim", 0.5], ["aim", 1.0], ["swing", 0.045], ["swing", 0.13], ["swing", 0.32], ["watch", 0.5],
	["walk", 0.0], ["walk", 0.21], ["run", 0.0], ["run", 0.13], ["jump", 0.16], ["jump", 0.45], ["land", 0.1],
	["celebrate", 0.3], ["victory", 0.3], ["sad", 0.5], ["disappointed", 0.6], ["lookaround", 1.0], ["wave", 0.15],
	["laugh", 0.1], ["clap", 0.16], ["dance", 0.0], ["dance", 0.4], ["flex", 0.6], ["facepalm", 1.0], ["wow", 0.5], ["thumbs_up", 0.6],
]


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("f1ebe0"))
	var args := OS.get_cmdline_user_args()
	if args.has("--ink-outfits"):
		_outfits(args)
	elif args.has("--ink-sizes"):
		_sizes(args)
	elif args.has("--ink-live"):
		_live(args)
	elif args.has("--ink-looks"):
		_looks()
	else:
		_poses(args)


static func _arg(args: PackedStringArray, key: String, i: int, fallback: String) -> String:
	var k := args.find(key)
	return args[k + i] if k != -1 and k + i < args.size() and not args[k + i].begins_with("--") else fallback


func _golfer(app: Dictionary, pos: Vector2, sc: float) -> Golfer:
	var g := Golfer.new()
	g.set_appearance(app)
	g.position = pos
	g.scale = Vector2(sc, sc)
	add_child(g)
	return g


func _freeze(g: Golfer, anim: String, t: float) -> void:
	g.frozen_time = true
	if anim == "aim":
		g.play("aim")
		g.aim_power = t
		g.set_time(0.0, 0.0)
	elif anim == "swing":
		g.swing(1.0, "swing")
		g.set_time(t, t)
	elif Emotes.is_emote(anim):
		g.emote(anim)
		g.set_time(t, t)
	else:
		g.play(anim)
		g.set_time(t, t)


func _label(text: String, pos: Vector2, size: int = 18) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_override("font", UITheme.body_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("1c1714"))
	add_child(l)


func _poses(args: PackedStringArray) -> void:
	var id := _arg(args, "--ink-poses", 1, "stickman")
	var sc := float(_arg(args, "--ink-poses", 2, "2.2"))
	var app := Appearance.for_outfit({}, id)
	var cols := 7
	var dx := 270.0
	var dy := 265.0
	for i in POSES.size():
		var pose: Array = POSES[i]
		var pos := Vector2(140 + (i % cols) * dx, 225 + (i / cols) * dy)
		var g := _golfer(app, pos, sc)
		_freeze(g, pose[0], pose[1])
		_label("%s %.2f" % [pose[0], pose[1]], pos + Vector2(-60, 12), 17)
		var ball := _Ball.new()
		ball.position = pos + Vector2(InkRig.BALL_OFFSET * sc, -9.0 * sc / 1.3)
		ball.r = 9.0 * sc / 1.3
		add_child(ball)


func _outfits(args: PackedStringArray) -> void:
	var sc := float(_arg(args, "--ink-outfits", 1, "2.4"))
	var ids := InkLook.outfit_ids(true)
	var cols := 6
	for i in ids.size():
		var pos := Vector2(170 + (i % cols) * 300, 290 + (i / cols) * 330)
		var g := _golfer(Appearance.for_outfit({}, ids[i]), pos, sc)
		_freeze(g, "idle", 0.0)
		_label(str(InkLook.outfit(ids[i]).name), pos + Vector2(-50, 14), 22)


func _sizes(args: PackedStringArray) -> void:
	var id := _arg(args, "--ink-sizes", 1, "stickman")
	var app := Appearance.for_outfit({}, id)
	var x := 80.0
	for sc: float in [0.7, 1.0, 1.3, 2.0, 3.0, 5.5]:
		var g := _golfer(app, Vector2(x + 30.0 * sc, 900), sc)
		_freeze(g, "idle", 0.0)
		_label("%.1fx" % sc, Vector2(x, 920), 20)
		x += 60.0 * sc + 70.0


func _live(args: PackedStringArray) -> void:
	var id := _arg(args, "--ink-live", 1, "stickman")
	var sc := float(_arg(args, "--ink-live", 2, "3.0"))
	var app := Appearance.for_outfit({}, id)
	var anims := ["idle", "walk", "run", "dance", "victory", "celebrate"]
	for i in anims.size():
		var g := _golfer(app, Vector2(170 + i * 300, 520), sc)
		g.play(anims[i])


## A spread of customisation options on the base stickman.
func _looks() -> void:
	var rows := [
		["hair", ["spikes", "swept", "messy", "mohawk", "curly", "afro", "bob", "long", "ponytail", "pigtails", "bun", "braid", "buzz", "quiff", "fringe", "none"]],
		["pantsCut", ["flare", "bell", "baggy", "straight", "skinny", "shorts", "capri", "harem"]],
		["pantsPattern", ["solid", "stripes", "pinstripe", "hoops", "twotone", "dots", "checks", "zigzag", "stars", "flames", "split"]],
		["hat", ["cap", "cap_back", "beanie", "bucket", "tophat", "cowboy", "crown", "headband", "wizard", "viking", "halo", "bandana", "pirate", "dino", "antenna", "helmet", "helm"]],
		["top", ["tee", "polo", "tank", "hoodie", "jacket", "sweater", "vest", "coat", "robe", "jersey"]],
	]
	var y := 190.0
	var hair_cols := ["#1c1714", "#e0702a", "", "#7a3fcf", "#f2b630", "#4a2c1d", "#d6304a", "#3c6fe0"]
	for r: Array in rows:
		var key: String = r[0]
		var vals: Array = r[1]
		var sc := 1.9 if vals.size() <= 11 else 1.45
		var dx := 1840.0 / vals.size()
		for i in vals.size():
			var app := Appearance.normalize({})
			app.ink[key] = vals[i]
			if key == "hair":
				app.ink.hairColor = hair_cols[i % hair_cols.size()]
			if key == "pantsPattern":
				app.ink.pantsColor2 = "#ffd166"
			if key == "top":
				app.ink.topColor = InkLook.PALETTE[(i * 5 + 3) % InkLook.PALETTE.size()]
			if key == "hat":
				app.ink.hatColor = InkLook.PALETTE[(i * 7 + 4) % InkLook.PALETTE.size()]
			var g := _golfer(app, Vector2(60 + dx * (i + 0.5), y), sc)
			_freeze(g, "idle", 0.0)
		_label(key, Vector2(10, y - 150), 18)
		y += 212.0


class _Ball extends Node2D:
	var r := 9.0

	func _draw() -> void:
		var cv := InkCanvas.new()
		cv.ellipse(Vector2.ZERO, Vector2(r, r), Color.WHITE)
		cv.ink_circle(Vector2.ZERO, Vector2(r, r), 2.4, InkCanvas.INK, 3.0)
		cv.flush(get_canvas_item())
