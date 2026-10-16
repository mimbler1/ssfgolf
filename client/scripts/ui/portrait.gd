class_name Portrait
extends Control
## A character portrait for HUD panels, results and cards (HUD_SPEC.md, Portraits).
##
## Source, in order:
##  1. the character's authored portrait (res://assets/characters/<id>/portrait.png);
##  2. a head-and-shoulders crop of the first idle sprite frame (cached per character);
##  3. legacy toon characters: a static head-framed GolferView (drawn once, no per-frame cost).
## Textures are cached, so a HUD never regenerates portraits during play.

static var _cache: Dictionary = {}   ## character id -> Texture2D (or null = use the golfer view)

var mirror := false                  ## face left (right-hand HUD panels look inward)
## Draw the pixel-art portrait frame (assets/ui/hud/portrait_frame.png, 9-slice) over the edge.
var framed := false
var _tex: Texture2D
var _view: GolferView


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true


func set_look(appearance: Dictionary) -> void:
	var app := Appearance.normalize(appearance)
	_tex = texture_for(str(app.character))
	if _view:
		_view.queue_free()
		_view = null
	if _tex == null:
		_view = GolferView.new()
		_view.focus = "head"
		_view.pad = Vector2(2, 2)
		_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_view)
		_view.set_look(app)
		if mirror:
			_view.golfer.facing = -1.0
	queue_redraw()


static func texture_for(char_id: String) -> Texture2D:
	if _cache.has(char_id):
		return _cache[char_id]
	var tex: Texture2D = null
	var authored := (SpriteCharacter.ROOT % char_id) + "portrait.png"
	if ResourceLoader.exists(authored):
		tex = load(authored) as Texture2D
	else:
		var sc := SpriteCharacter.load_for(char_id)
		if sc:
			tex = _crop_head(sc)
	_cache[char_id] = tex
	return tex


## Head and shoulders from the first idle frame: the top of the opaque area, as wide as tall.
static func _crop_head(sc: SpriteCharacter) -> Texture2D:
	var img := (sc.frame("idle", 0).tex as AtlasTexture).get_image()
	if img == null:
		return null
	img.decompress()
	var used := img.get_used_rect()
	if used.size.x <= 0:
		return null
	var h := mini(used.size.y, int(round(used.size.y * 0.45)))
	var w := maxi(h, mini(used.size.x, h + 6))
	var cx := used.position.x + used.size.x / 2
	var rect := Rect2i(clampi(cx - w / 2, 0, img.get_width() - w), used.position.y, w, h)
	return ImageTexture.create_from_image(img.get_region(rect))


func _draw() -> void:
	if _tex == null:
		_draw_frame()
		return
	var ts := _tex.get_size()
	var s := floorf(minf(size.x / ts.x, size.y / ts.y))
	if s < 1.0:
		s = minf(size.x / ts.x, size.y / ts.y)
	var dst := Rect2((size - ts * s) * 0.5, ts * s)
	dst.position.y = size.y - dst.size.y   # sit on the bottom edge, like a bust
	if mirror:
		draw_set_transform(Vector2(size.x, 0), 0.0, Vector2(-1, 1))
	draw_texture_rect(_tex, dst, false)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_frame()


func _draw_frame() -> void:
	if not framed:
		return
	var sb := UIArt.nine("hud/portrait_frame.png", [16, 16, 16, 16], 2 if size.x >= 64.0 else 1)
	if sb:
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
