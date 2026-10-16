extends Node
## Sprite baker: renders every roster character (CharacterSkin over the Golfer rig) through every
## animation into a packed sprite sheet: assets/characters/<id>.png + <id>.json (format in
## CharacterSheet). Needs a real renderer, so run it windowed: tools/bake_sprites.ps1
##
##   Godot --path client res://scenes/dev/sprite_baker.tscn [-- --only ace,nana]
##
## Each frame is drawn at 2x into a supersampled viewport (with MSAA), then composited at 1x by
## sprite_outline.gdshader (box downsample + thick silhouette outline), trimmed and packed.

const BAKE := 3.0                     ## sheet pixels per rig unit
const SS := 2                         ## supersampling factor
const CELL := Vector2i(420, 480)      ## output cell size (px)
const ORIGIN := Vector2(210, 420)     ## golfer origin inside the cell (px)
const OUTLINE := 2.1                  ## outer outline width in rig units
const PAD := 6                        ## atlas padding (keeps mipmaps from bleeding)
const ATLAS_W := 4096

## name -> {kind: loop|once|power, fps, len (s) or frames (power)}.
## Loop lengths match the rig's periods (BREATH = 3 s cycles) so loops are seamless.
const ANIMS := {
	"idle": {"kind": "loop", "fps": 8.0, "len": 3.0},
	"aim": {"kind": "power", "frames": 11},
	"swing": {"kind": "once", "fps": 30.0, "len": 0.75},
	"watch": {"kind": "loop", "fps": 8.0, "len": 3.0},
	"celebrate": {"kind": "loop", "fps": 20.0, "len": 0.45},
	"victory": {"kind": "loop", "fps": 8.0, "len": 3.0},
	"sad": {"kind": "loop", "fps": 8.0, "len": 3.0},
	"walk": {"kind": "loop", "fps": 20.0, "len": 0.7},
	"dance": {"kind": "loop", "fps": 15.0, "len": 1.0},
	"wave": {"kind": "once", "fps": 15.0, "len": 1.8},
	"laugh": {"kind": "once", "fps": 24.0, "len": 1.8},
	"wow": {"kind": "once", "fps": 15.0, "len": 1.6},
	"thumbs_up": {"kind": "once", "fps": 12.0, "len": 1.8},
	"clap": {"kind": "once", "fps": 20.0, "len": 1.8},
	"facepalm": {"kind": "once", "fps": 12.0, "len": 2.0},
	"flex": {"kind": "once", "fps": 15.0, "len": 1.8},
}

var _vp_src: SubViewport
var _vp_out: SubViewport
var _golfer: Golfer


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_window().size = Vector2i(CELL.x * 2, CELL.y)
	_build()
	var ids: Array = CharacterSkin.ids()
	var args := OS.get_cmdline_user_args()
	var oi := args.find("--only")
	if oi != -1 and oi + 1 < args.size():
		ids = Array(args[oi + 1].split(","))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CharacterSheet.DIR))
	for id: String in ids:
		await _bake(id)
	print("sprite baker: done")
	get_tree().quit()


func _build() -> void:
	_vp_src = SubViewport.new()
	_vp_src.size = CELL * SS
	_vp_src.transparent_bg = true
	_vp_src.msaa_2d = Viewport.MSAA_4X
	_vp_src.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp_src)
	_vp_out = SubViewport.new()
	_vp_out.size = CELL
	_vp_out.transparent_bg = true
	_vp_out.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp_out)
	var spr := Sprite2D.new()
	spr.centered = false
	spr.texture = _vp_src.get_texture()
	spr.scale = Vector2.ONE / float(SS)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/sprite_outline.gdshader")
	mat.set_shader_parameter("width_px", OUTLINE * BAKE * SS)
	mat.set_shader_parameter("line_color", CharacterSkin.INK)
	spr.material = mat
	_vp_out.add_child(spr)
	# Show both on screen so progress is visible.
	var view := TextureRect.new()
	view.texture = _vp_out.get_texture()
	add_child(view)


func _bake(id: String) -> void:
	if _golfer:
		_golfer.queue_free()
	_golfer = Golfer.new()
	_golfer.live_skin = id
	_golfer.frozen_time = true
	var app := Appearance.DEFAULT.duplicate()
	app.character = id
	_golfer.appearance = app
	_golfer.position = ORIGIN * float(SS)
	_golfer.scale = Vector2.ONE * BAKE * float(SS)
	_vp_src.add_child(_golfer)
	var frames: Array[Dictionary] = []   ## {anim, img, ox, oy}
	var meta := {}
	for name: String in ANIMS:
		var spec: Dictionary = ANIMS[name]
		var times: Array[float] = []
		match str(spec.kind):
			"power":
				for i in int(spec.frames):
					times.append(float(i) / float(int(spec.frames) - 1))
			_:
				var n := maxi(1, roundi(float(spec.len) * float(spec.fps)))
				for i in n:
					times.append(float(i) / float(spec.fps))
		var start := frames.size()
		for v in times:
			_pose(name, str(spec.kind), v)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img := _vp_out.get_texture().get_image()
			var used := img.get_used_rect()
			if used.size.x <= 0:
				used = Rect2i(int(ORIGIN.x), int(ORIGIN.y) - 1, 1, 1)
			frames.append({"anim": name, "img": img.get_region(used), "ox": used.position.x - int(ORIGIN.x), "oy": used.position.y - int(ORIGIN.y)})
		meta[name] = {
			"fps": float(spec.get("fps", 0.0)),
			"loop": str(spec.kind) == "loop",
			"mode": "power" if str(spec.kind) == "power" else "time",
			"range": [start, frames.size()],
		}
	_write_sheet(id, frames, meta)


## Poses the golfer for anim `name` at time (or aim power) `v`.
func _pose(name: String, kind: String, v: float) -> void:
	if kind == "power":
		_golfer.aim_power = v
		_golfer.play("aim")
		_golfer.set_time(0.0, 0.0)
	elif name == "swing":
		_golfer.swing(0.85, "swing")
		_golfer.set_time(v, v)
	elif Emotes.is_emote(name) and name != "dance":
		_golfer.emote(name)
		_golfer.set_time(v, v)
	else:
		_golfer.play(name)
		_golfer.set_time(v, v)


func _write_sheet(id: String, frames: Array[Dictionary], meta: Dictionary) -> void:
	# Identical frames (held poses, clamped follow-throughs) share one atlas rect.
	var first_of := {}     ## content key -> first frame index
	var alias: Array[int] = []
	for i in frames.size():
		var im0: Image = frames[i].img
		var key := "%d,%d,%d,%d:%d" % [frames[i].ox, frames[i].oy, im0.get_width(), im0.get_height(), hash(im0.get_data())]
		if first_of.has(key):
			alias.append(int(first_of[key]))
		else:
			first_of[key] = i
			alias.append(i)
	# Shelf-pack unique frames, tallest first.
	var order: Array = []
	for i in frames.size():
		if alias[i] == i:
			order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return frames[a].img.get_height() > frames[b].img.get_height())
	var rects: Array = []
	rects.resize(frames.size())
	var x := PAD
	var y := PAD
	var shelf := 0
	for i: int in order:
		var im: Image = frames[i].img
		if x + im.get_width() + PAD > ATLAS_W:
			x = PAD
			y += shelf + PAD
			shelf = 0
		rects[i] = Rect2i(x, y, im.get_width(), im.get_height())
		x += im.get_width() + PAD
		shelf = maxi(shelf, im.get_height())
	var h := y + shelf + PAD
	var atlas := Image.create_empty(ATLAS_W, h, false, Image.FORMAT_RGBA8)
	for i: int in order:
		var im2: Image = frames[i].img
		atlas.blit_rect(im2, Rect2i(Vector2i.ZERO, im2.get_size()), rects[i].position)
	var anims := {}
	for name: String in meta:
		var m: Dictionary = meta[name]
		var list: Array = []
		for i in range(int(m.range[0]), int(m.range[1])):
			var r: Rect2i = rects[alias[i]]
			list.append([r.position.x, r.position.y, r.size.x, r.size.y, frames[i].ox, frames[i].oy])
		anims[name] = {"fps": m.fps, "loop": m.loop, "mode": m.mode, "frames": list}
	var base := ProjectSettings.globalize_path(CharacterSheet.DIR.path_join(id))
	atlas.save_png(base + ".png")
	var f := FileAccess.open(base + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"bake_scale": BAKE, "anims": anims}))
	f.close()
	print("baked %s: %d frames (%d unique), atlas %dx%d" % [id, frames.size(), order.size(), ATLAS_W, h])
