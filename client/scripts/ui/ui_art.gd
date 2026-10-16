class_name UIArt
extends RefCounted
## Pixel-art UI assets (docs/UI_ART.md): cached textures and crisp nine-slice frames.
## Pixel art is always shown at an integer scale with nearest filtering. Nine-slice frames are
## built from an integer-upscaled copy of the source so the stretched rim stays pixel-sharp.

const ROOT := "res://assets/ui/"

static var _tex: Dictionary = {}
static var _scaled: Dictionary = {}


static func tex(rel: String) -> Texture2D:
	if _tex.has(rel):
		return _tex[rel]
	var t: Texture2D = load(ROOT + rel) as Texture2D if ResourceLoader.exists(ROOT + rel) else null
	_tex[rel] = t
	return t


static func ability_icon(id: String) -> Texture2D:
	return tex("abilities/%s.png" % id)


## Nearest-neighbour upscale of a texture (cached).
static func scaled(rel: String, k: int) -> Texture2D:
	var key := "%s@%d" % [rel, k]
	if _scaled.has(key):
		return _scaled[key]
	var t := tex(rel)
	var out: Texture2D = null
	if t:
		var img := t.get_image()
		img.decompress()
		img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
		out = ImageTexture.create_from_image(img)
	_scaled[key] = out
	return out


## A StyleBoxTexture nine-slice of `rel` at integer scale `k`. margins = [left, top, right, bottom] in art px.
static func nine(rel: String, margins: Array, k: int = 2, content_pad: float = 0.0) -> StyleBoxTexture:
	var t := scaled(rel, k)
	if t == null:
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = t
	sb.texture_margin_left = float(margins[0]) * k
	sb.texture_margin_top = float(margins[1]) * k
	sb.texture_margin_right = float(margins[2]) * k
	sb.texture_margin_bottom = float(margins[3]) * k
	sb.content_margin_left = float(margins[0]) * k * 0.5 + content_pad
	sb.content_margin_right = float(margins[2]) * k * 0.5 + content_pad
	sb.content_margin_top = float(margins[1]) * k * 0.5 + content_pad
	sb.content_margin_bottom = float(margins[3]) * k * 0.5 + content_pad
	return sb
