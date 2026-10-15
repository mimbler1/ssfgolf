class_name UITheme
extends RefCounted
## Central art-direction tokens and the generated Godot Theme for all menus.
## See /docs/ART_DIRECTION.md for the rules these values encode.

const INK := Color("1c1630")          ## Primary dark (panels, outlines)
const INK_SOFT := Color("2e2548")
const INK_LINE := Color("20141e")     ## Same ink as sprite outlines (ART_STYLE_GUIDE §3)
const PAPER := Color("fff8ec")        ## Light text / highlights
const MUTED := Color("aab3e0")
const SUN := Color("ffd166")          ## Accent / currency
const GRASS := Color("3ec46d")        ## Primary action
const GRASS_DARK := Color("23914b")
const SKY := Color("4c8df6")          ## Secondary action
const SKY_DARK := Color("2f5fc4")
const CORAL := Color("ef476f")        ## Danger / leave
const CORAL_DARK := Color("b02a4d")
const TROPHY := Color("ffb703")

## Arcade panels (v3): tight corners, thick ink rims, slanted silhouettes.
const RADIUS := 7
const RADIUS_SMALL := 5
const SLANT := 0.16                   ## horizontal skew of slanted panels
const BORDER_BOTTOM := 6

## Rarity presentation (colour is never the only signal: names + icons too).
const RARITY := {
	"common": {"name": "Common", "color": Color("c9d1e8"), "icon": "●"},
	"uncommon": {"name": "Uncommon", "color": Color("5fd068"), "icon": "◆"},
	"rare": {"name": "Rare", "color": Color("3fa2ff"), "icon": "★"},
	"epic": {"name": "Epic", "color": Color("b65cff"), "icon": "✦"},
	"legendary": {"name": "Legendary", "color": Color("ffc23d"), "icon": "♛"},
	"mythic": {"name": "Mythic", "color": Color("ff5ea8"), "icon": "✷"},
}

## Distinct colours for the four player slots (used for names, trails, markers).
const SLOT_COLORS := [Color("ffd166"), Color("4cc9f0"), Color("ef476f"), Color("80ed99")]

static var _theme: Theme
static var _heading: FontVariation
static var _body: FontVariation
static var _body_bold: FontVariation


static func _tag(name: String) -> int:
	return TextServerManager.get_primary_interface().name_to_tag(name)


static func heading_font() -> FontVariation:
	if _heading == null:
		_heading = FontVariation.new()
		# Heavy display face, slanted like arcade title type.
		_heading.base_font = load("res://assets/fonts/LilitaOne-Regular.ttf")
		_heading.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.14, 1), Vector2.ZERO)
		_heading.spacing_glyph = 1
	return _heading


static func body_font() -> FontVariation:
	if _body == null:
		_body = FontVariation.new()
		_body.base_font = load("res://assets/fonts/Nunito.ttf")
		_body.variation_opentype = {_tag("wght"): 650}
	return _body


static func body_bold_font() -> FontVariation:
	if _body_bold == null:
		_body_bold = FontVariation.new()
		_body_bold.base_font = load("res://assets/fonts/Nunito.ttf")
		_body_bold.variation_opentype = {_tag("wght"): 850}
	return _body_bold


static func box(bg: Color, radius: int = RADIUS, border_color: Color = Color.TRANSPARENT, bottom: int = 0, shadow: int = 0, border: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(mini(radius, RADIUS))
	s.corner_detail = 10
	s.anti_aliasing = true
	if border > 0 or bottom > 0:
		s.border_color = border_color
		s.set_border_width_all(border)
		s.border_width_bottom = bottom + border
	if shadow > 0:
		s.shadow_color = Color(0, 0, 0, 0.28)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, shadow * 0.5)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10 + bottom
	return s


## Arcade panel: slanted parallelogram, thick ink rim, heavier bottom lip in `lip` colour.
static func arcade_box(fill: Color, lip: Color = INK_LINE, slant: float = SLANT, rim: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(4)
	s.corner_detail = 3
	s.anti_aliasing = false
	s.border_color = INK_LINE
	s.set_border_width_all(rim)
	s.border_width_bottom = rim + 4
	s.skew = Vector2(slant, 0)
	s.expand_margin_bottom = 0
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 12
	if lip != INK_LINE:
		s.border_color = lip
	return s


static func panel_box() -> StyleBoxFlat:
	var s := box(Color(INK, 0.95), RADIUS, INK_LINE, 0, 0, 0)
	s.border_color = INK_LINE
	s.set_border_width_all(4)
	s.border_width_top = 4
	s.border_width_bottom = 9
	s.skew = Vector2(SLANT * 0.5, 0)
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 24
	s.content_margin_bottom = 24
	return s


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 22

	# Buttons: chunky "candy" buttons with a darker bottom edge.
	_button_styles(t, "Button", SKY, SKY_DARK)
	t.set_color("font_color", "Button", PAPER)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", PAPER)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(PAPER, 0.45))
	t.set_font("font", "Button", heading_font())
	t.set_font_size("font_size", "Button", 26)
	t.set_constant("outline_size", "Button", 0)

	# Variations.
	for v in [["PrimaryButton", GRASS, GRASS_DARK], ["DangerButton", CORAL, CORAL_DARK],
			["GhostButton", Color(1, 1, 1, 0.08), Color(0, 0, 0, 0.25)], ["SunButton", SUN, Color("d99a1e")]]:
		t.set_type_variation(v[0], "Button")
		_button_styles(t, v[0], v[1], v[2])
	# Toggled ghost buttons (tabs, categories) show a clear selected state.
	var ghost_on := box(Color(SUN, 0.22), RADIUS, SUN, 0, 0, 3)
	t.set_stylebox("pressed", "GhostButton", ghost_on)
	t.set_stylebox("hover_pressed", "GhostButton", ghost_on)
	t.set_color("font_color", "SunButton", INK)
	t.set_color("font_hover_color", "SunButton", INK)
	t.set_color("font_pressed_color", "SunButton", INK)

	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_stylebox("panel", "Panel", panel_box())
	t.set_type_variation("CardPanel", "PanelContainer")
	var card := box(Color(1, 1, 1, 0.06), RADIUS, Color(0, 0, 0, 0.0), 0, 0, 0)
	card.content_margin_left = 16; card.content_margin_right = 16
	t.set_stylebox("panel", "CardPanel", card)

	t.set_color("font_color", "Label", PAPER)
	t.set_type_variation("HeadingLabel", "Label")
	t.set_font("font", "HeadingLabel", heading_font())
	t.set_font_size("font_size", "HeadingLabel", 40)
	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", heading_font())
	t.set_font_size("font_size", "TitleLabel", 30)
	t.set_type_variation("MutedLabel", "Label")
	t.set_color("font_color", "MutedLabel", MUTED)
	t.set_font_size("font_size", "MutedLabel", 19)

	var le := box(Color(0, 0, 0, 0.3), RADIUS_SMALL, Color(1, 1, 1, 0.12), 0, 0, 2)
	t.set_stylebox("normal", "LineEdit", le)
	var le_f := box(Color(0, 0, 0, 0.36), RADIUS_SMALL, SUN, 0, 0, 2)
	t.set_stylebox("focus", "LineEdit", le_f)
	t.set_color("font_color", "LineEdit", PAPER)
	t.set_color("caret_color", "LineEdit", SUN)
	t.set_color("font_placeholder_color", "LineEdit", Color(MUTED, 0.6))
	t.set_font_size("font_size", "LineEdit", 24)

	# Sliders
	var track := box(Color(0, 0, 0, 0.35), 8)
	track.content_margin_top = 4; track.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", track)
	var fill := box(SUN, 8)
	fill.content_margin_top = 4; fill.content_margin_bottom = 4
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _circle_tex(26, PAPER, INK_LINE))
	t.set_icon("grabber_highlight", "HSlider", _circle_tex(28, Color.WHITE, INK_LINE))

	# Option buttons & popups
	_button_styles(t, "OptionButton", Color(1, 1, 1, 0.1), Color(0, 0, 0, 0.25))
	t.set_font("font", "OptionButton", body_bold_font())
	t.set_font_size("font_size", "OptionButton", 22)
	t.set_color("font_color", "OptionButton", PAPER)
	var pop := box(INK_SOFT, RADIUS_SMALL, INK_LINE, 0, 10, 0)
	t.set_stylebox("panel", "PopupMenu", pop)
	t.set_color("font_color", "PopupMenu", PAPER)
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_stylebox("hover", "PopupMenu", box(SUN, 8))
	t.set_font_size("font_size", "PopupMenu", 22)

	# Check buttons
	t.set_color("font_color", "CheckButton", PAPER)
	t.set_color("font_hover_color", "CheckButton", Color.WHITE)
	t.set_color("font_pressed_color", "CheckButton", PAPER)
	t.set_color("font_hover_pressed_color", "CheckButton", Color.WHITE)
	t.set_font_size("font_size", "CheckButton", 22)
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		t.set_stylebox(st, "CheckButton", StyleBoxEmpty.new())

	# Scrollbars
	var sb := box(Color(1, 1, 1, 0.06), 6)
	sb.content_margin_left = 6; sb.content_margin_right = 6
	t.set_stylebox("scroll", "VScrollBar", sb)
	var grab := box(Color(1, 1, 1, 0.28), 6)
	grab.content_margin_left = 6; grab.content_margin_right = 6
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", box(Color(1, 1, 1, 0.4), 6))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(SUN, 6))

	t.set_stylebox("panel", "TooltipPanel", box(INK_SOFT, 10, INK_LINE, 0, 6, 0))
	t.set_color("font_color", "TooltipLabel", PAPER)
	t.set_font_size("font_size", "TooltipLabel", 19)

	_theme = t
	return t


static func _button_styles(t: Theme, type: String, base: Color, edge: Color) -> void:
	var normal := box(base, RADIUS, edge, BORDER_BOTTOM, 0, 0)
	var hover := box(base.lightened(0.12), RADIUS, edge, BORDER_BOTTOM, 0, 0)
	var pressed := box(base.darkened(0.06), RADIUS, edge, 2, 0, 0)
	pressed.content_margin_top = 14
	var disabled := box(Color(base, 0.35), RADIUS, Color(edge, 0.35), BORDER_BOTTOM, 0, 0)
	var focus := box(Color.TRANSPARENT, RADIUS, SUN, 0, 0, 3)
	focus.draw_center = false
	t.set_stylebox("normal", type, normal)
	t.set_stylebox("hover", type, hover)
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("hover_pressed", type, pressed)
	t.set_stylebox("disabled", type, disabled)
	t.set_stylebox("focus", type, focus)


static func _circle_tex(size: int, fill: Color, line: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var r := size * 0.5 - 1.0
			var a := clampf(r - d + 0.5, 0.0, 1.0)
			var inner := clampf(r - 3.0 - d + 0.5, 0.0, 1.0)
			var col := line.lerp(fill, inner)
			col.a = a
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## Pins a control to an anchor point of its parent (ax, ay in 0..1) plus a pixel offset.
## gx/gy choose the growth direction from that point: -1 = left/up, 0 = both, 1 = right/down.
## The control sizes itself from its minimum size.
static func pin(c: Control, ax: float, ay: float, offset: Vector2, gx: int = 1, gy: int = 1) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = offset.x
	c.offset_right = offset.x
	c.offset_top = offset.y
	c.offset_bottom = offset.y
	var dirs := [Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END]
	c.grow_horizontal = dirs[gx + 1]
	c.grow_vertical = dirs[gy + 1]


## Draws text with a thick outline and drop shadow (used for big game announcements).
static func styled_label(text: String, size: int, color: Color = PAPER, outline: int = 10) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = heading_font()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = INK_LINE
	ls.shadow_size = 0
	ls.shadow_color = Color(0, 0, 0, 0.35)
	ls.shadow_offset = Vector2(0, outline * 0.6)
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l
