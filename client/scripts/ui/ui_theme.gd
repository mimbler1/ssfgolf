class_name UITheme
extends RefCounted
## Art-direction tokens and the generated Godot Theme for every menu and HUD element
## (docs/INK_ART_SPEC.md §10): paper panels and colour buttons with hand-drawn ink rims
## (InkStyleBox), hand-lettered type (Kalam headings, Patrick Hand body; both OFL).

const INK := Color("1c1714")          ## Lines and text on paper
const INK_SOFT := Color("3b312a")     ## Dark panels (rare: over-world overlays)
const INK_LINE := Color("1c1714")
const PAPER := Color("fbf6ec")        ## Panel fill / light text over the world
const PAPER_DEEP := Color("f1e6d1")   ## Inset wells, rows, cards
const MUTED := Color("7a6c5f")        ## Secondary text on paper
const SUN := Color("f2b630")          ## Accent / currency
const GRASS := Color("6cbf4a")        ## Primary action
const GRASS_DARK := Color("4b9a33")
const SKY := Color("63aee6")          ## Secondary action
const SKY_DARK := Color("3f86c2")
const CORAL := Color("ef6a5a")        ## Danger / leave
const CORAL_DARK := Color("c44a3c")
const TROPHY := Color("e8a317")
const ENERGY := Color("8a5cf0")

const RADIUS := 14
const RADIUS_SMALL := 9
const SLANT := 0.0
const BORDER_BOTTOM := 5

## Rarity presentation (colour is never the only signal: names + icons too).
const RARITY := {
	"common": {"name": "Common", "color": Color("b7ad9f"), "icon": "●"},
	"uncommon": {"name": "Uncommon", "color": Color("5fb04a"), "icon": "◆"},
	"rare": {"name": "Rare", "color": Color("3f8fe0"), "icon": "★"},
	"epic": {"name": "Epic", "color": Color("9b5ce0"), "icon": "✦"},
	"legendary": {"name": "Legendary", "color": Color("e8a317"), "icon": "♛"},
	"mythic": {"name": "Mythic", "color": Color("e85a9a"), "icon": "✷"},
}

## Distinct colours for the six player slots (names, trails, markers, HUD frames).
const SLOT_COLORS := [Color("f2b630"), Color("3fa3e8"), Color("ef5a5a"), Color("3dbf7f"), Color("9b6be8"), Color("f28c38")]

static var _theme: Theme
static var _heading: FontVariation
static var _body: FontVariation
static var _body_bold: FontVariation


static func slot_color(slot: int) -> Color:
	return SLOT_COLORS[posmod(slot, SLOT_COLORS.size())]


static func heading_font() -> FontVariation:
	if _heading == null:
		_heading = FontVariation.new()
		_heading.base_font = load("res://assets/fonts/Kalam-Bold.ttf")
		_heading.spacing_glyph = 1
	return _heading


static func body_font() -> FontVariation:
	if _body == null:
		_body = FontVariation.new()
		_body.base_font = load("res://assets/fonts/PatrickHand-Regular.ttf")
	return _body


static func body_bold_font() -> FontVariation:
	if _body_bold == null:
		_body_bold = FontVariation.new()
		_body_bold.base_font = load("res://assets/fonts/Kalam-Bold.ttf")
	return _body_bold


## Hand-drawn box. Kept compatible with the old flat-box signature:
## bg fill, corner radius, border colour, bottom lip (button depth), drop shadow, border width.
static func box(bg: Color, radius: int = RADIUS, border_color: Color = Color.TRANSPARENT, bottom: int = 0, shadow: int = 0, border: int = 0) -> InkStyleBox:
	var s := InkStyleBox.make(bg, 3.0, float(radius), float(bottom), float(shadow) * 0.5)
	if border > 0:
		s.ink = border_color
		s.ink_width = float(border)
	elif bg.a < 0.5:
		s.ink_width = 0.0
	if bottom > 0:
		s.lip_color = bg.darkened(0.22) if border_color == Color.TRANSPARENT else border_color
	return s


## Paper card used for HUD plates and ability cards (`rim` = ink weight).
static func arcade_box(fill: Color, lip: Color = INK_LINE, _slant: float = SLANT, rim: int = 3) -> InkStyleBox:
	var s := InkStyleBox.make(fill, float(rim), 12.0, 4.0, 3.0)
	s.lip_color = lip if lip != INK_LINE else fill.darkened(0.14)
	s.content_margin_top = 8
	s.content_margin_bottom = 12
	return s


static func panel_box() -> InkStyleBox:
	var s := InkStyleBox.make(PAPER, 3.4, 18.0, 0.0, 7.0)
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 22
	s.content_margin_bottom = 24
	return s


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 24

	_button_styles(t, "Button", SKY)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(INK, 0.4))
	t.set_font("font", "Button", heading_font())
	t.set_font_size("font_size", "Button", 27)
	t.set_constant("outline_size", "Button", 0)
	for v in [["PrimaryButton", GRASS], ["DangerButton", CORAL], ["SunButton", SUN], ["GhostButton", PAPER]]:
		t.set_type_variation(v[0], "Button")
		_button_styles(t, v[0], v[1])
	var ghost_on := InkStyleBox.make(SUN.lightened(0.45), 3.0, 12.0, 0.0, 0.0)
	ghost_on.hatch = 9.0
	ghost_on.hatch_color = Color(SUN.darkened(0.3), 0.35)
	t.set_stylebox("pressed", "GhostButton", ghost_on)
	t.set_stylebox("hover_pressed", "GhostButton", ghost_on)

	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_stylebox("panel", "Panel", panel_box())
	t.set_type_variation("CardPanel", "PanelContainer")
	var card := InkStyleBox.make(PAPER_DEEP, 2.2, 12.0)
	t.set_stylebox("panel", "CardPanel", card)

	t.set_color("font_color", "Label", INK)
	t.set_type_variation("HeadingLabel", "Label")
	t.set_font("font", "HeadingLabel", heading_font())
	t.set_font_size("font_size", "HeadingLabel", 42)
	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", heading_font())
	t.set_font_size("font_size", "TitleLabel", 31)
	t.set_type_variation("MutedLabel", "Label")
	t.set_color("font_color", "MutedLabel", MUTED)
	t.set_font_size("font_size", "MutedLabel", 21)

	var le := InkStyleBox.make(Color("fffdf8"), 2.4, 9.0)
	le.content_margin_top = 8
	le.content_margin_bottom = 8
	t.set_stylebox("normal", "LineEdit", le)
	var le_f := le.copy()
	le_f.ink = SKY_DARK
	le_f.ink_width = 3.2
	t.set_stylebox("focus", "LineEdit", le_f)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("caret_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", Color(MUTED, 0.75))
	t.set_font_size("font_size", "LineEdit", 25)

	var track := InkStyleBox.make(PAPER_DEEP, 2.0, 7.0)
	track.set_content_margin_all(4)
	t.set_stylebox("slider", "HSlider", track)
	var fill := InkStyleBox.make(SUN, 2.0, 7.0)
	fill.set_content_margin_all(4)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _circle_tex(26, PAPER, INK))
	t.set_icon("grabber_highlight", "HSlider", _circle_tex(28, Color.WHITE, INK))

	_button_styles(t, "OptionButton", PAPER)
	t.set_font("font", "OptionButton", body_bold_font())
	t.set_font_size("font_size", "OptionButton", 23)
	t.set_color("font_color", "OptionButton", INK)
	t.set_color("font_hover_color", "OptionButton", INK)
	var pop := InkStyleBox.make(PAPER, 2.6, 10.0, 0.0, 5.0)
	t.set_stylebox("panel", "PopupMenu", pop)
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_stylebox("hover", "PopupMenu", InkStyleBox.make(SUN.lightened(0.3), 0.0, 8.0))
	t.set_font_size("font_size", "PopupMenu", 23)

	t.set_color("font_color", "CheckButton", INK)
	t.set_color("font_hover_color", "CheckButton", INK)
	t.set_color("font_pressed_color", "CheckButton", INK)
	t.set_color("font_hover_pressed_color", "CheckButton", INK)
	t.set_font_size("font_size", "CheckButton", 23)
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		t.set_stylebox(st, "CheckButton", StyleBoxEmpty.new())
	t.set_icon("checked", "CheckButton", _toggle_tex(true))
	t.set_icon("unchecked", "CheckButton", _toggle_tex(false))

	var sb := InkStyleBox.make(Color(INK, 0.06), 0.0, 6.0)
	sb.set_content_margin_all(5)
	t.set_stylebox("scroll", "VScrollBar", sb)
	var grab := InkStyleBox.make(Color("d8ccb6"), 1.8, 6.0)
	grab.set_content_margin_all(5)
	t.set_stylebox("grabber", "VScrollBar", grab)
	var grab_h := grab.copy()
	grab_h.fill = Color("c9b99c")
	t.set_stylebox("grabber_highlight", "VScrollBar", grab_h)
	var grab_p := grab.copy()
	grab_p.fill = SUN
	t.set_stylebox("grabber_pressed", "VScrollBar", grab_p)

	t.set_stylebox("panel", "TooltipPanel", InkStyleBox.make(PAPER, 2.2, 9.0, 0.0, 4.0))
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_font_size("font_size", "TooltipLabel", 21)

	var pb_bg := InkStyleBox.make(PAPER_DEEP, 2.0, 7.0)
	pb_bg.set_content_margin_all(0)
	var pb_fill := InkStyleBox.make(SUN, 0.0, 7.0)
	pb_fill.set_content_margin_all(0)
	pb_fill.wobble = 0.6
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fill)
	t.set_color("font_color", "ProgressBar", INK)

	_theme = t
	return t


static func _button_styles(t: Theme, type: String, base: Color) -> void:
	var normal := InkStyleBox.make(base, 3.0, 14.0, BORDER_BOTTOM, 3.0)
	normal.lip_color = base.darkened(0.2)
	var hover := normal.copy()
	hover.fill = base.lightened(0.12)
	hover.ink_width = 3.8
	var pressed := normal.copy()
	pressed.fill = base.darkened(0.06)
	pressed.lip = 1.0
	pressed.shadow = 1.0
	pressed.content_margin_top = normal.content_margin_top + 3
	var disabled := normal.copy()
	disabled.fill = Color(base.lerp(PAPER, 0.55), 0.85)
	disabled.ink = Color(INK, 0.35)
	disabled.lip_color = Color(base, 0.2)
	var focus := InkStyleBox.make(Color.TRANSPARENT, 2.6, 16.0)
	focus.ink = SKY_DARK
	focus.wobble = 2.4
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


static func _toggle_tex(on: bool) -> ImageTexture:
	var w := 58
	var h := 32
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track := GRASS if on else Color("d9cdb8")
	var knob_x := w - h * 0.5 if on else h * 0.5
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var q := Vector2(clampf(p.x, h * 0.5, w - h * 0.5), h * 0.5)
			var d := p.distance_to(q)
			var r := h * 0.5 - 1.0
			var a := clampf(r - d + 0.5, 0.0, 1.0)
			var col := INK.lerp(track, clampf(r - 2.5 - d + 0.5, 0.0, 1.0))
			var kd := p.distance_to(Vector2(knob_x, h * 0.5))
			var kr := h * 0.5 - 6.0
			if kd < kr + 2.0:
				col = col.lerp(INK, clampf(kr + 2.0 - kd, 0.0, 1.0))
			if kd < kr:
				col = col.lerp(PAPER, clampf(kr - kd, 0.0, 1.0))
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


## Hand-lettered announcement text: paper letters with a thick ink outline (over the world).
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
	ls.shadow_color = Color(0, 0, 0, 0.25)
	ls.shadow_offset = Vector2(2, outline * 0.4)
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l
