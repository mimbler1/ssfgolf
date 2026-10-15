extends Node2D
## Developer gallery for art review screenshots.
##   (no args)                 classic presets x animations
##   --gallery-zoom            close-up subset
##   --gallery-emotes [k]      presets frozen k (0..1) through each emote
##   --gallery-skins [ids|all] [poses] [scale] [bg]
##                             roster characters frozen in poses; bg = sky|dark|grass
##   --gallery-scales [ids]    each character at gameplay, card and preview scale side by side

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("cfeefe"))
	var args := OS.get_cmdline_user_args()
	var si := args.find("--gallery-skins")
	if si != -1:
		_skins(args, si)
		return
	var sc_i := args.find("--gallery-scales")
	if sc_i != -1:
		_scales(args, sc_i)
		return
	var zoom := args.has("--gallery-zoom")
	var anims := ["idle", "aim", "swing", "watch", "celebrate", "sad", "walk", "dance", "wave", "victory"]
	var presets := Appearance.PRESETS
	var sc := 1.35
	var dx := 180.0
	var dy := 120.0
	var freeze := -1.0
	var fi := args.find("--gallery-emotes")
	if fi != -1:
		anims = []
		for e: Dictionary in Emotes.LIST:
			anims.append(e.id)
		freeze = float(args[fi + 1]) if fi + 1 < args.size() and args[fi + 1].is_valid_float() else 0.5
		presets = presets.slice(0, 4)
		sc = 2.0
		dx = 225.0
		dy = 220.0
	elif zoom:
		anims = ["idle", "aim", "celebrate", "sad", "wave"]
		presets = presets.slice(0, 3)
		sc = 3.0
		dx = 340.0
		dy = 300.0
	for i in presets.size():
		for j in anims.size():
			var g := Golfer.new()
			g.set_appearance(Appearance.with_preset({}, presets[i].data))
			g.position = Vector2(150 + j * dx, (280 if zoom or freeze >= 0.0 else 140) + i * dy)
			g.scale = Vector2(sc, sc)
			g.aim_power = 0.8
			add_child(g)
			if anims[j] == "swing":
				g.swing(0.9, "swing")
			elif freeze >= 0.0:
				g.emote(anims[j])
				g.frozen_time = true
				g.set_time(freeze * Emotes.duration(anims[j]), freeze * Emotes.duration(anims[j]))
			else:
				g.play(anims[j])


func _bg(args: PackedStringArray) -> void:
	if args.has("dark"):
		RenderingServer.set_default_clear_color(Color("1b2040"))
	elif args.has("grass"):
		RenderingServer.set_default_clear_color(Color("6ccf4a"))


func _skins(args: PackedStringArray, si: int) -> void:
	_bg(args)
	var ids: Array = CharacterDefs.ids()
	var poses: Array = ["idle", "aim", "swing", "watch", "celebrate", "victory", "laugh", "sad"]
	var sc := 2.0
	if si + 1 < args.size() and not args[si + 1].begins_with("--") and args[si + 1] != "all":
		ids = Array(args[si + 1].split(","))
	if si + 2 < args.size() and not args[si + 2].begins_with("--") and args[si + 2] != "all":
		poses = Array(args[si + 2].split(","))
	if si + 3 < args.size() and args[si + 3].is_valid_float():
		sc = float(args[si + 3])
	var vs := Vector2(1920, 1080)
	var dx := vs.x / float(poses.size())
	var dy := vs.y / float(ids.size())
	for i in ids.size():
		for j in poses.size():
			var g := Golfer.new()
			var app := Appearance.DEFAULT.duplicate()
			app.character = str(ids[i])
			g.set_appearance(app)
			g.position = Vector2(dx * (j + 0.5) - 10.0 * sc, dy * (i + 1) - 10.0)
			g.scale = Vector2(sc, sc)
			g.frozen_time = true
			_pose(g, str(poses[j]))
			add_child(g)


## Freezes a golfer at a representative moment of an animation.
## Pose names may carry a time: "swing@0.12".
static func _pose(g: Golfer, pose: String) -> void:
	var at := -1.0
	if "@" in pose:
		at = float(pose.get_slice("@", 1))
		pose = pose.get_slice("@", 0)
	g.aim_power = 0.85
	if pose == "swing":
		g.swing(0.85, "swing")
		var s := 0.16 if at < 0.0 else at
		g.set_time(s, s)
	elif pose == "address":
		g.play("aim")
		g.aim_power = 0.0
		g.set_time(0.0, 0.0)
	elif Emotes.is_emote(pose):
		g.emote(pose)
		var s2 := Emotes.duration(pose) * 0.45 if at < 0.0 else at
		g.set_time(s2, s2)
	else:
		g.play(pose)
		var s3 := 0.4 if at < 0.0 else at
		g.set_time(s3, s3)


func _scales(args: PackedStringArray, si: int) -> void:
	_bg(args)
	var ids: Array = CharacterDefs.ids()
	if si + 1 < args.size() and not args[si + 1].begins_with("--") and args[si + 1] != "all":
		ids = Array(args[si + 1].split(","))
	var x := 60.0
	for id: String in ids:
		for sc: float in [1.3, 2.4, 5.0]:
			var g := Golfer.new()
			var app := Appearance.DEFAULT.duplicate()
			app.character = id
			g.set_appearance(app)
			g.scale = Vector2(sc, sc)
			g.frozen_time = true
			g.position = Vector2(x + 20.0 * sc, 900)
			_pose(g, "idle")
			add_child(g)
			x += 75.0 * sc
		x += 40.0
