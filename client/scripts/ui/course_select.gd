extends Node
## Course select (solo): the six courses as arcade cards. Each card shows a real render of the
## course's first hole, its theme and difficulty, hole count and par, and the player's progress
## (medal, best round). Play starts stroke play from hole 1; Practice opens any hole on repeat.
## "Clean Ball" plays the round with no abilities.

const CARD_W := 520.0
const CARD_H := 360.0
const PREVIEW_SIZE := Vector2i(480, 186)

var ui: Control
var _grid: GridContainer
var _previews: Array[Dictionary] = []   ## {viewport, course_id} built one per frame
var _clean := false
var _picker: Control


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("f1ebe0"))
	var bg := MenuBackdrop.new()
	add_child(bg)
	bg.setup(GameData.theme_for("golf_land"), LocalStore.appearance(), false)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	ui = Control.new()
	ui.theme = UITheme.get_theme()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui)
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.97, 0.94, 0.88, 0.25)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(dim)
	var title := UITheme.styled_label("SELECT COURSE", 64, UITheme.SUN, 12)
	ui.add_child(title)
	UITheme.pin(title, 0.5, 0, Vector2(0, 22), 0, 1)
	var totals: Dictionary = Records.load_all().totals
	var sub := UITheme.styled_label("Stroke play · 9 holes each · Holes-in-one: %d · Swishes: %d" % [int(totals.get("holes_in_one", 0)), int(totals.get("swishes", 0))], 22, UITheme.PAPER, 6)
	ui.add_child(sub)
	UITheme.pin(sub, 0.5, 0, Vector2(0, 104), 0, 1)

	# Daily challenge: one hole from all six courses, picked by today's date.
	var daily := GameData.daily_course()
	if not daily.is_empty():
		var dh: Dictionary = daily.holes[0]
		var best := Records.daily_best(str(daily.date))
		var dbtn := GameButton.make("DAILY CHALLENGE  ·  %s (%s) · Par %d%s" % [str(dh.get("name", "")), str(daily.source_course), int(dh.get("par", 3)),
			("  ·  Best %d" % best) if best > 0 else ""], "SunButton", Vector2(0, 56))
		dbtn.add_theme_font_size_override("font_size", 22)
		dbtn.pressed.connect(func() -> void: Router.goto(Router.GAME, {"mode": "stroke", "course": "daily", "hole": 0}))
		ui.add_child(dbtn)
		UITheme.pin(dbtn, 0.5, 1, Vector2(0, -30), 0, -1)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 40
	scroll.offset_right = -40
	scroll.offset_top = 150
	scroll.offset_bottom = -110
	ui.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 22)
	_grid.add_theme_constant_override("v_separation", 22)
	center.add_child(_grid)
	ui.resized.connect(_reflow)
	for cid in GameData.main_courses:
		_grid.add_child(_card(cid))
	_reflow.call_deferred()

	var back := GameButton.make("Back", "", Vector2(170, 66))
	back.pressed.connect(func() -> void: Router.goto(Router.MAIN_MENU))
	ui.add_child(back)
	UITheme.pin(back, 0, 1, Vector2(40, -26), 1, -1)
	var clean := CheckButton.new()
	clean.text = "Clean Ball (no abilities)"
	clean.add_theme_font_size_override("font_size", 22)
	clean.tooltip_text = "Play the round with the regular ball only. Clean rounds keep their own best score."
	clean.toggled.connect(func(on: bool) -> void: _clean = on)
	ui.add_child(clean)
	UITheme.pin(clean, 1, 1, Vector2(-40, -36), -1, -1)


func _reflow() -> void:
	var w := ui.size.x - 80.0
	_grid.columns = clampi(int((w + 22.0) / (CARD_W + 22.0)), 1, 3)


func _process(_delta: float) -> void:
	# Build hole previews one per frame so opening the screen never hitches.
	for p in _previews:
		if not p.built:
			p.built = true
			_build_preview(p)
			return


func _card(cid: String) -> Control:
	var c := GameData.course(cid)
	var rec := Records.course(cid)
	var par := Records.course_par(c)
	var theme: Dictionary = c.get("theme", {})
	var accent := Color(theme.get("grass", "#6ccf4a"))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	var sb := InkStyleBox.make(UITheme.PAPER, 3.2, 16.0, 6.0, 5.0)
	sb.lip_color = accent
	sb.content_margin_left = 16; sb.content_margin_right = 16; sb.content_margin_top = 12; sb.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	card.add_child(vb)
	var top := HBoxContainer.new()
	vb.add_child(top)
	var num := UITheme.styled_label("%d" % int(c.get("order", 0)), 34, accent, 8)
	top.add_child(num)
	var name_l := UITheme.styled_label(str(c.name), 36, UITheme.PAPER, 9)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_l)
	top.add_child(_badge(str(c.get("difficulty", "")).to_upper(), _difficulty_color(str(c.get("difficulty", "")))))
	# Preview: a real render of hole 1, drawn once.
	var holder := SubViewportContainer.new()
	holder.custom_minimum_size = Vector2(PREVIEW_SIZE)
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(holder)
	var vp := SubViewport.new()
	vp.size = PREVIEW_SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.transparent_bg = false
	holder.add_child(vp)
	_previews.append({"viewport": vp, "course_id": cid, "built": false})
	var mech := Label.new()
	mech.text = str(c.get("mechanic", ""))
	mech.theme_type_variation = "MutedLabel"
	mech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mech.add_theme_font_size_override("font_size", 17)
	vb.add_child(mech)
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 10)
	vb.add_child(info)
	var stats := Label.new()
	stats.text = "%d holes · Par %d" % [(c.holes as Array).size(), par]
	stats.add_theme_font_override("font", UITheme.body_bold_font())
	stats.add_theme_font_size_override("font_size", 19)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(stats)
	if rec.get("completed", false):
		var best := int(rec.best_total)
		var diff := best - par
		info.add_child(_badge("BEST %d (%s)" % [best, ("%+d" % diff) if diff != 0 else "E"], UITheme.INK))
		var medal := str(rec.get("medal", ""))
		if medal != "":
			info.add_child(_badge(medal.to_upper(), {"gold": Color("c98a0b"), "silver": Color("7d8794"), "bronze": Color("b06a32")}.get(medal, UITheme.MUTED)))
	else:
		info.add_child(_badge("NOT PLAYED", UITheme.MUTED))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	vb.add_child(buttons)
	var play := GameButton.make("Play", "PrimaryButton", Vector2(0, 54))
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.pressed.connect(func() -> void:
		Router.goto(Router.GAME, {"mode": "stroke", "course": cid, "hole": 0, "clean": _clean}))
	buttons.add_child(play)
	var practice := GameButton.make("Practice", "GhostButton", Vector2(150, 54))
	practice.pressed.connect(_open_hole_picker.bind(cid))
	buttons.add_child(practice)
	return card


func _build_preview(p: Dictionary) -> void:
	var vp: SubViewport = p.viewport
	var c := GameData.course(str(p.course_id))
	var hole: Dictionary = c.holes[0]
	var theme: Dictionary = c.theme
	var terrain := SimTerrain.new()
	terrain.build(hole)
	var bd := Backdrop.new()
	vp.add_child(bd)
	bd.setup(theme, hash(str(p.course_id)))
	var tv := TerrainView.new()
	vp.add_child(tv)
	tv.build(terrain, hole, theme, 1)
	var cam := Camera2D.new()
	var b := terrain.bounds
	var focus := Rect2(Vector2(b.position.x + 150.0, terrain.tee.y - 900.0), Vector2(b.size.x - 300.0, 1300.0))
	var z := minf(float(PREVIEW_SIZE.x) / focus.size.x, float(PREVIEW_SIZE.y) / focus.size.y)
	cam.zoom = Vector2(z, z)
	cam.position = focus.get_center()
	vp.add_child(cam)
	cam.make_current()
	bd.follow(cam.position, z)
	# Two updates (layout, then draw), after which the preview is a static texture.
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	if is_instance_valid(vp):
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _open_hole_picker(cid: String) -> void:
	if _picker:
		_picker.queue_free()
	var c := GameData.course(cid)
	var rec := Records.course(cid)
	var shade := ColorRect.new()
	shade.color = Color(0.12, 0.1, 0.08, 0.5)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(shade)
	_picker = shade
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	shade.add_child(panel)
	UITheme.pin(panel, 0.5, 0.5, Vector2.ZERO, 0, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	vb.add_child(UITheme.styled_label("PRACTICE · %s" % str(c.name).to_upper(), 40, UITheme.SUN, 8))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	vb.add_child(grid)
	for i in (c.holes as Array).size():
		var h: Dictionary = c.holes[i]
		var hr: Dictionary = (rec.get("holes", {}) as Dictionary).get(str(h.id), {})
		var label := "%d. %s\nPar %d%s" % [i + 1, h.get("name", ""), int(h.get("par", 3)), ("  ·  Best %d" % int(hr.best)) if int(hr.get("best", 0)) > 0 else ""]
		var b := GameButton.make(label, "GhostButton", Vector2(236, 76))
		b.add_theme_font_size_override("font_size", 17)
		b.tooltip_text = str(h.get("notes", ""))
		b.pressed.connect(func() -> void: Router.goto(Router.GAME, {"mode": "practice", "course": cid, "hole": i}))
		grid.add_child(b)
	var close := GameButton.make("Close", "", Vector2(0, 56))
	close.pressed.connect(func() -> void:
		_picker.queue_free()
		_picker = null)
	vb.add_child(close)


func _badge(text: String, col: Color) -> Control:
	var p := PanelContainer.new()
	var sb := UITheme.box(Color(col, 0.18), 6, col, 0, 0, 2)
	sb.content_margin_left = 8; sb.content_margin_right = 8; sb.content_margin_top = 1; sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UITheme.body_bold_font())
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", col)
	p.add_child(l)
	return p


static func _difficulty_color(d: String) -> Color:
	return {"Beginner": Color("4b9a33"), "Easy": Color("2f86d6"), "Medium": Color("d99a0b"), "Hard": Color("c44a3c")}.get(d, UITheme.MUTED)
