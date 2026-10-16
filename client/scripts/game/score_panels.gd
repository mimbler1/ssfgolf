class_name ScorePanels
extends Control
## SSF2-inspired player panels along the top of the screen (docs/HUD_SPEC.md).
##
## One panel per player: big character portrait, big score number, name, player colour, a
## placement badge and the hole status. The score is the match points in Blitz, strokes relative
## to par in stroke play and shots in practice; a caption under the number always names which.
##
## Layout adapts to the player count and the window: panels split into a left and a right group
## around the hole banner, sized large (1-2 players), medium (3-4) or compact (5-6). A group that
## does not fit on one row wraps to two rows instead of shrinking text; only as a last resort does
## it drop one size. The game draws a 1920x1080 canvas scaled to the window, so on small windows
## panels are enlarged by up to 1.5x to keep text at a readable physical size (names >= ~14 px,
## captions >= ~11 px on screen) and wrap to two rows instead.

const MARGIN := 18.0
const GAP := 10.0
## name -> [width, height, portrait, score font, name font]
const SIZES := {
	"L": [360.0, 116.0, 100.0, 64, 22],
	"M": [292.0, 100.0, 86.0, 54, 19],
	"S": [236.0, 88.0, 74.0, 46, 17],
	"XS": [200.0, 80.0, 64.0, 40, 15],
}

var view: MatchView
var banner_width := 360.0
var _panels: Array[_Panel] = []
var _last_layout := Vector2.ZERO
var _last_root := Vector2i.ZERO


func setup(p_view: MatchView) -> void:
	view = p_view
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for r in view.roster:
		var p := _Panel.new()
		p.slot = int(r.slot)
		p.is_local = p.slot == view.local_slot
		p.player_name = str(r.name)
		p.appearance = r.appearance
		p.color = UITheme.SLOT_COLORS[p.slot % UITheme.SLOT_COLORS.size()]
		add_child(p)
		_panels.append(p)
	resized.connect(layout)
	layout()


## Size class for the player count, then wrap / shrink until each side fits.
func layout() -> void:
	if _panels.is_empty() or size.x <= 0.0:
		return
	_last_layout = size
	_last_root = get_tree().root.size
	var n := _panels.size()
	var order := ["L", "M", "S", "XS"]
	var start := 0 if n <= 2 else (1 if n <= 4 else 2)
	var left_count := ceili(n / 2.0) if n > 1 else 1
	var right_count := n - left_count
	# Physical-size compensation for scaled-down windows (see header).
	var screen_scale := float(get_tree().root.size.y) / maxf(get_viewport_rect().size.y, 1.0)
	var grow := clampf(0.85 / maxf(screen_scale, 0.01), 1.0, 1.5)
	var avail := (size.x - banner_width - MARGIN * 2.0 - GAP * 4.0) * 0.5
	var chosen := "XS"
	var rows := 2
	for i in range(start, order.size()):
		var w: float = SIZES[order[i]][0] * grow
		for r in [1, 2]:
			var cols := ceili(float(maxi(left_count, right_count)) / float(r))
			if cols * w + (cols - 1) * GAP <= avail:
				chosen = order[i]
				rows = r
				break
		if chosen == order[i]:
			break
	var base: Array = SIZES[chosen]
	var spec: Array = [base[0] * grow, base[1] * grow, base[2] * grow, roundi(base[3] * grow), roundi(base[4] * grow)]
	var pw: float = spec[0]
	var ph: float = spec[1]
	for i in n:
		var p := _panels[i]
		p.apply_size(spec)
		var left := i < left_count
		var k := i if left else i - left_count
		var count := left_count if left else right_count
		var cols := ceili(float(count) / float(rows))
		var col := k % cols
		var row := k / cols
		var x := MARGIN + col * (pw + GAP)
		if not left:
			# Right group fills from the right edge inward, so slot order still reads left to right.
			x = size.x - MARGIN - (cols - col) * (pw + GAP) + GAP
		p.position = Vector2(x, MARGIN + row * (ph + GAP))
		p.size = Vector2(pw, ph)
		p.mirror = not left and n > 1


func _process(_delta: float) -> void:
	if view == null:
		return
	if size != _last_layout or get_tree().root.size != _last_root:
		layout()
	var ranks := _ranks()
	for p in _panels:
		var ps := view.player_state(p.slot)
		var bs := view.ball_state(p.slot)
		var value := ""
		var caption := ""
		match view.mode:
			"online":
				value = str(int(ps.get("points", 0)))
				caption = "PTS / %d" % view.target_points
			"stroke":
				var par := int(view.course.holes[view.hole_index].get("par", 3)) if view.hole_index >= 0 else 0
				var strokes := int(ps.get("strokes", 0))
				value = str(strokes)
				caption = "STROKES · PAR %d" % par
			_:
				value = str(int(ps.get("hole_shots", 0)))
				caption = "SHOTS"
		var status := ""
		if bool(bs.get("forfeited", false)):
			status = "LEFT"
		elif not bool(bs.get("connected", true)):
			status = "RECONNECTING"
		elif bool(bs.get("finished", false)):
			status = "HOLED"
		p.set_state(value, caption, ranks.get(p.slot, 0) if view.mode == "online" else 0, status,
			bool(bs.get("forfeited", false)) or not bool(bs.get("connected", true)))


## Match placement by points (ties share a place), in-play players only.
func _ranks() -> Dictionary:
	var pts: Array = []
	for p in _panels:
		if not bool(view.ball_state(p.slot).get("forfeited", false)):
			pts.append([p.slot, int(view.player_state(p.slot).get("points", 0))])
	var out := {}
	for a: Array in pts:
		var better := 0
		for b: Array in pts:
			if int(b[1]) > int(a[1]):
				better += 1
		out[int(a[0])] = better + 1
	return out


# ---------------------------------------------------------------------------

class _Panel extends Control:
	var slot := 0
	var is_local := false
	var player_name := ""
	var appearance: Dictionary = {}
	var color := Color.WHITE
	var mirror := false:
		set(v):
			if v != mirror:
				mirror = v
				_arrange()
	var _portrait: Portrait
	var _score: Label
	var _caption: Label
	var _name: Label
	var _status: Label
	var _place := 0
	var _value := ""
	var _flash := 0.0
	var _spec: Array = []
	var _dim := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		_portrait = Portrait.new()
		add_child(_portrait)
		_portrait.set_look(appearance)
		_score = _label(UITheme.heading_font(), 48, UITheme.PAPER, 10)
		_caption = _label(UITheme.body_bold_font(), 13, UITheme.MUTED, 4)
		_name = _label(UITheme.body_bold_font(), 18, UITheme.PAPER, 6)
		_name.clip_text = true
		_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_name.text = player_name + ("  (YOU)" if is_local and player_name.to_lower() != "you" else "")
		_status = _label(UITheme.heading_font(), 15, color, 5)
		resized.connect(_arrange)

	func _label(font: Font, fs: int, col: Color, outline: int) -> Label:
		var l := Label.new()
		var ls := LabelSettings.new()
		ls.font = font
		ls.font_size = fs
		ls.font_color = col
		ls.outline_size = outline
		ls.outline_color = UITheme.INK_LINE
		l.label_settings = ls
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		return l

	func apply_size(spec: Array) -> void:
		_spec = spec
		if _score == null:
			return
		_score.label_settings.font_size = int(spec[3])
		_name.label_settings.font_size = int(spec[4])
		_caption.label_settings.font_size = maxi(12, int(spec[4]) - 4)
		_status.label_settings.font_size = maxi(13, int(spec[4]) - 3)
		_arrange()

	func _arrange() -> void:
		if _spec.is_empty() or _score == null:
			return
		var pr: float = _spec[2]
		var pad := 8.0
		var px := size.x - pr - pad if mirror else pad
		_portrait.mirror = mirror
		_portrait.position = Vector2(px, size.y - pr - 4.0)
		_portrait.size = Vector2(pr, pr)
		_portrait.queue_redraw()
		var tx := pad if mirror else pr + pad * 2.0
		var tw := size.x - pr - pad * 3.0
		var align := HORIZONTAL_ALIGNMENT_RIGHT if mirror else HORIZONTAL_ALIGNMENT_LEFT
		for l: Label in [_score, _caption, _name, _status]:
			l.horizontal_alignment = align
			l.position.x = tx
			l.size.x = tw
		var fs := float(_score.label_settings.font_size)
		_name.position.y = 4.0
		_score.position.y = size.y * 0.5 - fs * 0.62
		_caption.position.y = size.y - float(_caption.label_settings.font_size) - 12.0
		_status.position.y = _caption.position.y - float(_status.label_settings.font_size) - 2.0
		queue_redraw()

	func set_state(value: String, caption: String, place: int, status: String, dim: bool) -> void:
		if value != _value:
			if _value != "":
				_pop()
			_value = value
			_score.text = value
		_caption.text = caption
		_status.text = status
		_status.visible = status != ""
		_caption.visible = status == "" or size.y > 96.0
		if place != _place or dim != _dim:
			_place = place
			_dim = dim
			modulate.a = 0.5 if dim else 1.0
			queue_redraw()

	## Score change: the number pops and the panel flashes; gameplay is never blocked.
	func _pop() -> void:
		_flash = 1.0
		_score.pivot_offset = _score.size * Vector2(1.0 if mirror else 0.0, 0.5)
		_score.scale = Vector2(1.45, 1.45)
		var tw := create_tween()
		tw.tween_property(_score, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var tw2 := create_tween()
		tw2.tween_method(func(v: float) -> void:
			_flash = v
			queue_redraw(), 1.0, 0.0, 0.6)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var sl := size.y * 0.22
		var s := -1.0 if mirror else 1.0
		# Slanted panel: ink rim, dark body, player-colour edge and bottom bar.
		var body := PackedVector2Array([Vector2(sl if s > 0 else 0, 0), Vector2(size.x - (0 if s > 0 else sl), 0),
			Vector2(size.x - (sl if s > 0 else 0), size.y), Vector2(0 if s > 0 else sl, size.y)])
		var rim := Geometry2D.offset_polygon(body, 3.0, Geometry2D.JOIN_MITER)
		if not rim.is_empty():
			draw_colored_polygon(rim[0], UITheme.INK_LINE)
		draw_colored_polygon(body, Color(UITheme.INK, 0.93).lerp(color, 0.25 * _flash))
		var bar_h := 6.0
		draw_colored_polygon(PackedVector2Array([body[3] + Vector2(0, -bar_h), body[2] + Vector2(0, -bar_h), body[2], body[3]]), color)
		# Local player: a brighter frame.
		if is_local:
			draw_polyline(body + PackedVector2Array([body[0]]), Color(color, 0.95), 3.0)
		# Portrait well.
		var pr: float = _spec[2] if not _spec.is_empty() else 64.0
		var pw := Rect2(_portrait.position - Vector2(3, 3), Vector2(pr, pr) + Vector2(6, 6)) if _portrait else Rect2()
		draw_rect(pw, Color(color.darkened(0.55), 0.95))
		draw_rect(Rect2(pw.position, Vector2(pw.size.x, 3)), Color(color, 0.7))
		# Placement badge in the outer top corner.
		if _place > 0:
			var txt: String = ["", "1ST", "2ND", "3RD", "4TH", "5TH", "6TH"][clampi(_place, 0, 6)]
			var bc: Color = [UITheme.MUTED, Color("ffd166"), Color("d9e2f2"), Color("f4a261"), Color("aab3e0"), Color("aab3e0"), Color("aab3e0")][clampi(_place, 0, 6)]
			var f := UITheme.heading_font()
			var fs := 16
			var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12.0
			var bx := size.x - w - 6.0 if s > 0 else 6.0
			draw_rect(Rect2(bx - 2, -10, w + 4, 24), UITheme.INK_LINE)
			draw_rect(Rect2(bx, -8, w, 20), bc)
			draw_string(f, Vector2(bx + 6, 8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.INK)
