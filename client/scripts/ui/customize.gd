extends Node
## Golfer Studio: character select and customisation.
## Left: categories. Centre: the big animated preview on a podium, with move/emote buttons.
## Right: the category's options (character cards, presets, parts, colours, saved looks).
##
## Every golfer on this screen (cards, thumbnails, the big preview) is the same Golfer node and
## renderer at a different scale, framed from its measured artwork bounds (GolferView).
## The layout is proportional, so it works from 1024x576 up to ultrawide.
##
## The equipped look is saved locally and to the online profile (when signed in), so opponents
## see it in matches. Named looks are stored on this PC.
##
## Dev args: --dev-character ID, --studio-tab NAME, --studio-anim ANIM

const CATEGORIES := ["Character", "Presets", "Body", "Face", "Headwear", "Shirt", "Ball & Trail", "Saved Looks"]
## Category -> customisation slot a character must accept (CharacterDefs.SLOTS).
const CATEGORY_SLOT := {"Body": "body_color", "Face": "face", "Headwear": "hat", "Shirt": "shirt", "Presets": "body_color"}
const MOVES := [["Idle", "idle"], ["Swing", "swing"], ["Walk", "walk"], ["Celebrate", "celebrate"], ["Victory", "victory"], ["Sad", "sad"]]
const RIGHT_FRACTION := 0.42        ## share of the screen width used by the options panel
const CARD_MIN_W := 214.0
const CARD_H := 332.0

var current: Dictionary
var saved: Dictionary
var ui: Control
var preview: Golfer
var _podium: _Podium
var _ball: _BallPreview
var _cat_buttons: Dictionary = {}
var _anim_buttons: Dictionary = {}  ## anim id -> Button
var _options: VBoxContainer
var _scroll: ScrollContainer
var _category := "Character"
var _save_btn: Button
var _status: Label
var _unsaved: Label
var _name_plate: Label
var _tag_plate: Label
var _rarity_plate: Label
var _thumbs: Array[Dictionary] = []   ## {view: GolferView, patch: Dictionary}
var _grids: Array[GridContainer] = []
var _glow: Array[StyleBoxFlat] = []
## Cards whose highlight follows the current look: {kind, node, ...}. Picking an option restyles
## these in place instead of rebuilding the category (which re-created every card and golfer).
var _cards: Array[Dictionary] = []
var _thumbs_dirty := false
var _swing_seq := 0
var _t := 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("1b2040"))
	current = Appearance.normalize(Backend.profile.get("appearance")) if not Backend.profile.is_empty() else LocalStore.appearance()
	saved = current.duplicate(true)
	var args := OS.get_cmdline_user_args()
	var dc := args.find("--dev-character")
	if dc != -1 and dc + 1 < args.size():
		current.character = args[dc + 1]
		current = Appearance.normalize(current)
	var bg := MenuBackdrop.new()
	add_child(bg)
	bg.setup(GameData.theme_for("sunny_meadows"), current, false)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	ui = Control.new()
	ui.theme = UITheme.get_theme()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui)
	_build()
	var st := args.find("--studio-tab")
	_show_category(args[st + 1] if st != -1 and st + 1 < args.size() and args[st + 1] in CATEGORIES else "Character")
	_refresh()
	var sa := args.find("--studio-anim")
	if sa != -1 and sa + 1 < args.size():
		_preview_anim.call_deferred(args[sa + 1])


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.07, 0.16, 0.42)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(dim)

	var title := UITheme.styled_label("GOLFER STUDIO", 60, UITheme.SUN, 12)
	ui.add_child(title)
	UITheme.pin(title, 0, 0, Vector2(48, 26), 1, 1)

	# Left: categories.
	var left := PanelContainer.new()
	ui.add_child(left)
	left.anchor_bottom = 1.0
	left.offset_left = 40
	left.offset_right = 300
	left.offset_top = 128
	left.offset_bottom = -124
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 10)
	left.add_child(lv)
	for c: String in CATEGORIES:
		var b := GameButton.make(c, "GhostButton", Vector2(0, 60))
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(_show_category.bind(c))
		lv.add_child(b)
		_cat_buttons[c] = b

	# Right: options panel (a fixed share of the width, so wide screens get more columns).
	var right := PanelContainer.new()
	ui.add_child(right)
	right.anchor_left = 1.0 - RIGHT_FRACTION
	right.anchor_right = 1.0
	right.anchor_bottom = 1.0
	right.offset_right = -40
	right.offset_top = 128
	right.offset_bottom = -124
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 8)
	_scroll.add_child(margin)
	_options = VBoxContainer.new()
	_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options.add_theme_constant_override("separation", 14)
	margin.add_child(_options)
	_options.resized.connect(_reflow_grids)

	# Centre: name plate, podium + golfer, move and emote buttons.
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(stage)
	stage.anchor_right = 1.0 - RIGHT_FRACTION
	stage.anchor_bottom = 1.0
	stage.offset_left = 320
	stage.offset_right = -20
	stage.offset_top = 118
	stage.offset_bottom = -124
	var plate_bg := PanelContainer.new()
	var pb := UITheme.box(Color(UITheme.INK, 0.72), UITheme.RADIUS)
	pb.content_margin_left = 26
	pb.content_margin_right = 26
	pb.content_margin_top = 4
	pb.content_margin_bottom = 8
	plate_bg.add_theme_stylebox_override("panel", pb)
	plate_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(plate_bg)
	UITheme.pin(plate_bg, 0.5, 0, Vector2(0, 6), 0, 1)
	var plate := VBoxContainer.new()
	plate.alignment = BoxContainer.ALIGNMENT_CENTER
	plate.add_theme_constant_override("separation", 0)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate_bg.add_child(plate)
	_name_plate = UITheme.styled_label("", 44, UITheme.PAPER, 10)
	_name_plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(_name_plate)
	_rarity_plate = Label.new()
	_rarity_plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rarity_plate.add_theme_font_override("font", UITheme.body_bold_font())
	_rarity_plate.add_theme_font_size_override("font_size", 20)
	plate.add_child(_rarity_plate)
	_tag_plate = Label.new()
	_tag_plate.theme_type_variation = "MutedLabel"
	_tag_plate.add_theme_color_override("font_color", UITheme.PAPER.darkened(0.08))
	_tag_plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(_tag_plate)

	_podium = _Podium.new()
	_podium.anchor_right = 1.0
	_podium.anchor_bottom = 1.0
	_podium.offset_top = 130
	_podium.offset_bottom = -132
	_podium.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_podium)
	preview = Golfer.new()
	_podium.add_child(preview)
	_podium.golfer = preview
	_ball = _BallPreview.new()
	_podium.add_child(_ball)
	_podium.ball = _ball

	# Move and emote buttons wrap within the stage width, so they never spill into the panels.
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	rows.alignment = BoxContainer.ALIGNMENT_END
	rows.anchor_top = 1.0
	rows.anchor_right = 1.0
	rows.anchor_bottom = 1.0
	rows.offset_top = -132
	rows.grow_vertical = Control.GROW_DIRECTION_BEGIN
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(rows)
	rows.add_child(_anim_row("MOVES", MOVES))
	var emotes: Array = []
	for e: Dictionary in Emotes.LIST:
		emotes.append([str(e.name), str(e.id)])
	rows.add_child(_anim_row("EMOTES", emotes))

	# Bottom bar.
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 14)
	ui.add_child(bar)
	UITheme.pin(bar, 1, 1, Vector2(-40, -30), -1, -1)
	_status = Label.new()
	_status.theme_type_variation = "MutedLabel"
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_status)
	_unsaved = UITheme.styled_label("Unsaved changes", 24, UITheme.SUN, 6)
	_unsaved.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_unsaved)
	var revert := GameButton.make("Revert", "GhostButton", Vector2(170, 66))
	revert.pressed.connect(func() -> void:
		current = saved.duplicate(true)
		_refresh()
		_show_category(_category))
	bar.add_child(revert)
	_save_btn = GameButton.make("Save & Equip", "PrimaryButton", Vector2(260, 66))
	_save_btn.pressed.connect(_save)
	bar.add_child(_save_btn)
	var back := GameButton.make("Back", "", Vector2(170, 66))
	back.pressed.connect(_back)
	ui.add_child(back)
	UITheme.pin(back, 0, 1, Vector2(40, -30), 1, -1)


func _anim_row(label: String, items: Array) -> Control:
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = label
	l.theme_type_variation = "MutedLabel"
	l.add_theme_font_size_override("font_size", 15)
	l.custom_minimum_size = Vector2(62, 44)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	for it: Array in items:
		var b := GameButton.make(str(it[0]), "GhostButton", Vector2(0, 44))
		b.add_theme_font_size_override("font_size", 18)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_preview_anim.bind(str(it[1])))
		if Emotes.is_emote(str(it[1])):
			b.tooltip_text = "In matches: hold %s for the emote wheel" % Settings.binding_label("emote_wheel")
		row.add_child(b)
		_anim_buttons[str(it[1])] = b
	return row


func _process(delta: float) -> void:
	_t += delta
	if _thumbs_dirty:
		_thumbs_dirty = false
		_refresh_thumbs()
	# Keep the move/emote buttons in sync with what the preview is actually doing.
	var a := preview.anim
	if a in ["aim", "watch"]:
		a = "swing"
	for id: String in _anim_buttons:
		var b: Button = _anim_buttons[id]
		if b.button_pressed != (id == a):
			b.set_pressed_no_signal(id == a)
	var pulse := 0.5 + 0.5 * sin(_t * 3.2)
	for g in _glow:
		g.shadow_color = Color(UITheme.SUN, 0.18 + 0.22 * pulse)


func _preview_anim(a: String) -> void:
	_swing_seq += 1
	var seq := _swing_seq
	_ball.reset()
	if a == "swing":
		preview.aim_power = 0.0
		preview.play("aim")
		var tw := create_tween()
		tw.tween_property(preview, "aim_power", 0.9, 0.55).set_trans(Tween.TRANS_SINE)
		await tw.finished
		if seq != _swing_seq:
			return
		preview.swing(0.9, "watch")
		Sfx.play("swing", -8.0)
		# The ball leaves on the impact frame.
		await get_tree().create_timer(Golfer.IMPACT).timeout
		if seq != _swing_seq:
			return
		Sfx.play("hit", -6.0)
		_ball.launch()
		await get_tree().create_timer(2.2).timeout
		if seq == _swing_seq and preview.anim == "watch":
			preview.play("idle")
	elif Emotes.is_emote(a):
		preview.emote(a)
	else:
		preview.play(a)


func _refresh() -> void:
	preview.set_appearance(current)
	_podium.fit()
	var id := str(current.character)
	var d := CharacterDefs.get_def(id)
	_name_plate.text = str(d.name)
	_tag_plate.text = str(d.tagline)
	var rar: Dictionary = UITheme.RARITY.get(str(d.rarity), UITheme.RARITY.common)
	_rarity_plate.text = "%s %s" % [rar.icon, str(rar.name).to_upper()]
	_rarity_plate.add_theme_color_override("font_color", rar.color)
	for c: String in CATEGORY_SLOT:
		var b: Button = _cat_buttons[c]
		var ok := CharacterDefs.accepts(id, CATEGORY_SLOT[c])
		b.disabled = not ok
		b.tooltip_text = "" if ok else "%s wears a signature look. Pick the Stickman to customise this." % d.name
	_ball.ball_color = Color(current.ballColor)
	_ball.trail_color = Color(current.trailColor)
	# Thumbnails follow the look at most once per frame (slider drags fire many changes a frame).
	_thumbs_dirty = true
	var dirty := JSON.stringify(current) != JSON.stringify(saved)
	_unsaved.visible = dirty
	_save_btn.disabled = not dirty


func _refresh_thumbs() -> void:
	for t in _thumbs:
		if is_instance_valid(t.view):
			var a := current.duplicate(true)
			for k in t.patch:
				a[k] = t.patch[k]
			(t.view as GolferView).set_look(Appearance.normalize(a), "")


func _set_part(key: String, value: Variant) -> void:
	current[key] = value
	current = Appearance.normalize(current)
	_refresh()


# ---------------------------------------------------------------------------
# Category content
# ---------------------------------------------------------------------------

func _show_category(c: String) -> void:
	if _cat_buttons[c].disabled:
		c = "Character"
	_category = c
	for k: String in _cat_buttons:
		_cat_buttons[k].set_pressed_no_signal(k == c)
	for child in _options.get_children():
		child.queue_free()
	_thumbs.clear()
	_grids.clear()
	_glow.clear()
	_cards.clear()
	var head := Label.new()
	head.theme_type_variation = "HeadingLabel"
	head.text = c
	_options.add_child(head)
	var scroll_to: Control = null
	match c:
		"Character":
			_muted("Pick who you play as. Every golfer hits exactly the same; the Stickman is fully customisable.")
			var ids: Array = CharacterDefs.ids()
			var looks: Array = []
			for id: String in ids:
				looks.append(_look_for(id))
			var frame := GolferView.shared_frame(looks)
			var cg := _grid(CARD_MIN_W)
			for i in ids.size():
				var card := _character_card(str(ids[i]), looks[i], frame)
				cg.add_child(card)
				if str(ids[i]) == str(current.character):
					scroll_to = card
		"Presets":
			_muted("Starting points for the Stickman. Pick one, then fine-tune anything.")
			var grid := _grid(190)
			for p: Dictionary in Appearance.PRESETS:
				var look := Appearance.with_preset(current, p.data)
				grid.add_child(_thumb_card(p.name, look, {}, func() -> void:
					current = Appearance.with_preset(current, p.data)
					_refresh(), true))
		"Body":
			_section("Body colour")
			_swatches("bodyColor")
			_section("Outline colour")
			_swatches("outlineColor")
			_section("Head shape")
			var g := _grid(140)
			for id: String in Appearance.HEAD_SHAPES:
				g.add_child(_thumb_card(Appearance.HEAD_SHAPES[id], {}, {"headShape": id}, _set_part.bind("headShape", id)))
			_section("Proportions")
			_slider("Head size", "headScale", 0.8, 1.3)
			_slider("Limb thickness", "limbThickness", 0.7, 1.5)
			_muted("Cosmetics never change your ball's hitbox or physics.")
		"Face":
			_section("Eyes")
			var g2 := _grid(140)
			for id: String in Appearance.EYES:
				g2.add_child(_thumb_card(Appearance.EYES[id], {}, {"eyes": id}, _set_part.bind("eyes", id)))
			_section("Mouth")
			var g3 := _grid(140)
			for id: String in Appearance.MOUTHS:
				g3.add_child(_thumb_card(Appearance.MOUTHS[id], {}, {"mouth": id}, _set_part.bind("mouth", id)))
		"Headwear":
			var g4 := _grid(140)
			for id: String in Appearance.HATS:
				var v: Variant = id if id != "" else null
				g4.add_child(_thumb_card(Appearance.HATS[id], {}, {"hat": v}, _set_part.bind("hat", v)))
			_section("Hat colour")
			_swatches("hatColor")
		"Shirt":
			var g5 := _grid(170)
			for id: String in Appearance.SHIRTS:
				var v2: Variant = id if id != "" else null
				g5.add_child(_thumb_card(Appearance.SHIRTS[id], {}, {"shirt": v2}, _set_part.bind("shirt", v2)))
			_section("Shirt colour")
			_swatches("shirtColor")
		"Ball & Trail":
			_muted("Your ball and trail are what opponents see racing past them.")
			_section("Ball colour")
			_swatches("ballColor")
			_section("Trail colour")
			_swatches("trailColor")
			var test := GameButton.make("Test shot", "GhostButton", Vector2(220, 56))
			test.pressed.connect(_preview_anim.bind("swing"))
			_options.add_child(test)
		"Saved Looks":
			_saved_looks()
	_update_selection()
	_scroll.scroll_vertical = 0
	_reflow_grids.call_deferred()
	if scroll_to:
		_scroll_into_view.call_deferred(scroll_to)


## Scrolls so the whole control is visible, once layout has settled.
func _scroll_into_view(c: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(c):
		_scroll.ensure_control_visible(c)


func _look_for(id: String) -> Dictionary:
	var look := current.duplicate(true)
	look.character = id
	return Appearance.normalize(look)


## Character card: big normalised preview, name, tagline, rarity and state.
func _character_card(id: String, look: Dictionary, frame: Rect2) -> Control:
	var d := CharacterDefs.get_def(id)
	var rar: Dictionary = UITheme.RARITY.get(str(d.rarity), UITheme.RARITY.common)
	var card := Button.new()
	card.custom_minimum_size = Vector2(CARD_MIN_W, CARD_H)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.tooltip_text = "%s - %s" % [d.name, d.tagline]
	var focus_box := UITheme.box(Color.TRANSPARENT, UITheme.RADIUS, Color(1, 1, 1, 0.5), 0, 0, 2)
	focus_box.draw_center = false
	card.add_theme_stylebox_override("focus", focus_box)

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 10
	vb.offset_right = -10
	vb.offset_top = 10
	vb.offset_bottom = -10
	vb.add_theme_constant_override("separation", 4)
	card.add_child(vb)
	var view := GolferView.new()
	view.frame = frame
	view.background = Color(rar.color, 0.13)
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.custom_minimum_size = Vector2(0, 200)
	view.pad = Vector2(8, 10)
	vb.add_child(view)
	view.set_look(look)
	var name_l := Label.new()
	name_l.text = str(d.name)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_override("font", UITheme.heading_font())
	name_l.add_theme_font_size_override("font_size", 26)
	name_l.add_theme_color_override("font_color", UITheme.PAPER)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(name_l)
	var tag := Label.new()
	tag.text = str(d.tagline)
	tag.theme_type_variation = "MutedLabel"
	tag.add_theme_font_size_override("font_size", 15)
	tag.add_theme_constant_override("line_spacing", -3)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.custom_minimum_size = Vector2(0, 38)
	tag.max_lines_visible = 2
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(tag)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 8)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(foot)
	foot.add_child(_chip("%s %s" % [rar.icon, str(rar.name).to_upper()], rar.color, Color(0, 0, 0, 0.3)))
	var state := _chip("", UITheme.INK, UITheme.SUN)
	foot.add_child(state)
	_cards.append({"kind": "character", "node": card, "id": id, "state": state})
	# Only the hovered card animates; every other card is a single static frame.
	card.mouse_entered.connect(func() -> void:
		view.set_animated(true)
		view.golfer.emote("wave"))
	card.mouse_exited.connect(view.set_animated.bind(false))
	card.pressed.connect(func() -> void:
		Sfx.play("ui_select", -6.0)
		if str(current.character) != id:
			current.character = id
			if id != "stickman":
				# Each character comes with a signature ball and trail (changeable in Ball & Trail).
				current.ballColor = str(d.ball)
				current.trailColor = str(d.trail)
			current = Appearance.normalize(current)
			_refresh()
			preview.emote("wave")
			_update_selection())
	return card


## Restyles every option card to match `current` / `saved` without rebuilding anything.
func _update_selection() -> void:
	_glow.clear()
	for c in _cards:
		if not is_instance_valid(c.node):
			continue
		match str(c.kind):
			"character":
				_style_character_card(c.node, str(c.id), c.state)
			"thumb":
				var selected := true
				for k in c.patch:
					if current.get(k) != c.patch[k]:
						selected = false
				var btn: Button = c.node
				if selected:
					var sb := UITheme.box(Color(UITheme.SUN, 0.14), UITheme.RADIUS, UITheme.SUN, 0, 0, 3)
					btn.add_theme_stylebox_override("normal", sb)
					btn.add_theme_stylebox_override("hover", sb)
				else:
					btn.remove_theme_stylebox_override("normal")
					btn.remove_theme_stylebox_override("hover")
			"swatch":
				var hex := str(c.hex)
				var sel: bool = str(current[c.key]).to_lower() == hex
				(c.node as Button).add_theme_stylebox_override("normal", UITheme.box(Color(hex), 12, UITheme.SUN if sel else Color(0, 0, 0, 0.5), 0, 0, 4 if sel else 2))


func _style_character_card(card: Button, id: String, state: PanelContainer) -> void:
	var selected := str(current.character) == id
	var equipped := str(saved.character) == id
	var base := UITheme.box(Color(1, 1, 1, 0.05), UITheme.RADIUS, Color(1, 1, 1, 0.1), 0, 0, 2)
	var hover := UITheme.box(Color(1, 1, 1, 0.1), UITheme.RADIUS, Color(1, 1, 1, 0.32), 0, 0, 2)
	if selected:
		base = UITheme.box(Color(UITheme.SUN, 0.1), UITheme.RADIUS, UITheme.SUN, 0, 0, 3)
		base.shadow_color = Color(UITheme.SUN, 0.3)
		base.shadow_size = 12
		base.shadow_offset = Vector2.ZERO
		hover = base
		_glow.append(base)
	for st in ["normal", "pressed", "hover_pressed"]:
		card.add_theme_stylebox_override(st, base)
	card.add_theme_stylebox_override("hover", hover)
	state.visible = equipped or selected
	var l: Label = state.get_child(0)
	l.text = "EQUIPPED" if equipped else "SELECTED"
	state.add_theme_stylebox_override("panel", _chip_box(UITheme.SUN if equipped else UITheme.PAPER))


func _chip_box(bg: Color) -> StyleBoxFlat:
	var sb := UITheme.box(bg, 10)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 1
	sb.content_margin_bottom = 2
	return sb


func _chip(text: String, fg: Color, bg: Color) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _chip_box(bg))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UITheme.body_bold_font())
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", fg)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p


func _muted(text: String) -> void:
	var l := Label.new()
	l.theme_type_variation = "MutedLabel"
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_options.add_child(l)


func _section(text: String) -> void:
	var l := Label.new()
	l.theme_type_variation = "TitleLabel"
	l.text = text
	_options.add_child(l)


## A grid whose column count follows the panel width (cards never shrink below min_w).
func _grid(min_w: float) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.set_meta("min_w", min_w)
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	_options.add_child(g)
	_grids.append(g)
	return g


func _reflow_grids() -> void:
	var w := _options.size.x
	if w <= 0.0:
		return
	for g in _grids:
		if not is_instance_valid(g):
			continue
		var mw := float(g.get_meta("min_w"))
		var cols := maxi(1, int(floor((w + 12.0) / (mw + 12.0))))
		if g.columns != cols:
			g.columns = cols


## A clickable card with a live mini golfer showing `patch` applied to the current look.
func _thumb_card(label: String, full_look: Dictionary, patch: Dictionary, on_pick: Callable, use_full: bool = false) -> Control:
	var card := Button.new()
	var small := patch.size() > 0
	card.custom_minimum_size = Vector2(0, 176 if small else 236)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.theme_type_variation = "GhostButton"
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 8
	vb.offset_right = -8
	vb.offset_top = 8
	vb.offset_bottom = -12
	card.add_child(vb)
	var view := GolferView.new()
	view.focus = "head" if (patch.has("eyes") or patch.has("mouth") or patch.has("headShape") or patch.has("hat")) else "full"
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.background = Color(0, 0, 0, 0.16)
	view.radius = 12
	vb.add_child(view)
	var look := full_look if use_full else current.duplicate(true)
	for k in patch:
		look[k] = patch[k]
	view.set_look(Appearance.normalize(look))
	if not use_full:
		_thumbs.append({"view": view, "patch": patch})
	var name_l := Label.new()
	name_l.text = label
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_override("font", UITheme.body_bold_font())
	name_l.add_theme_font_size_override("font_size", 18)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(name_l)
	if not patch.is_empty():
		_cards.append({"kind": "thumb", "node": card, "patch": patch})
	card.mouse_entered.connect(view.set_animated.bind(true))
	card.mouse_exited.connect(view.set_animated.bind(false))
	card.pressed.connect(func() -> void:
		Sfx.play("ui_select", -6.0)
		on_pick.call()
		_update_selection())
	return card


func _swatches(key: String) -> void:
	var g := _grid(56)
	for hex: String in Appearance.PALETTE:
		var b := Button.new()
		b.custom_minimum_size = Vector2(56, 50)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_cards.append({"kind": "swatch", "node": b, "key": key, "hex": hex})
		b.add_theme_stylebox_override("hover", UITheme.box(Color(hex).lightened(0.12), 12, UITheme.PAPER, 0, 0, 3))
		b.add_theme_stylebox_override("pressed", UITheme.box(Color(hex), 12, UITheme.SUN, 0, 0, 4))
		b.tooltip_text = hex
		b.pressed.connect(func() -> void:
			Sfx.play("ui_select", -8.0)
			_set_part(key, hex)
			_update_selection())
		g.add_child(b)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = "Custom colour"
	row.add_child(l)
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(120, 48)
	picker.color = Color(current[key])
	picker.edit_alpha = false
	picker.color_changed.connect(func(c: Color) -> void: _set_part(key, "#" + c.to_html(false)))
	row.add_child(picker)
	_options.add_child(row)


func _slider(label: String, key: String, lo: float, hi: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(200, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = float(current[key])
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(0, 32)
	s.value_changed.connect(func(v: float) -> void: _set_part(key, v))
	row.add_child(s)
	_options.add_child(row)


# ---------------------------------------------------------------------------
# Saved looks (local presets)
# ---------------------------------------------------------------------------

func _saved_looks() -> void:
	_muted("Save complete looks and switch between them anytime. Saved looks are stored on this PC; your equipped look is synced to your profile.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Name this look"
	name_edit.max_length = 24
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.custom_minimum_size = Vector2(0, 56)
	row.add_child(name_edit)
	var save := GameButton.make("Save look", "PrimaryButton", Vector2(180, 56))
	row.add_child(save)
	_options.add_child(row)
	var list := LocalStore.presets()
	save.pressed.connect(func() -> void:
		var n := name_edit.text.strip_edges()
		if n == "":
			n = "Look %d" % (list.size() + 1)
		if list.size() >= 30:
			_status.text = "You can keep up to 30 saved looks."
			return
		list.append({"name": n, "appearance": current.duplicate(true), "savedAt": int(Time.get_unix_time_from_system())})
		LocalStore.save_presets(list)
		_show_category("Saved Looks"))
	if list.is_empty():
		_muted("No saved looks yet.")
		return
	var g := _grid(300)
	for i in list.size():
		var entry: Dictionary = list[i]
		var look := Appearance.normalize(entry.get("appearance"))
		var card := PanelContainer.new()
		card.theme_type_variation = "CardPanel"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var vb := VBoxContainer.new()
		card.add_child(vb)
		var view := GolferView.new()
		view.custom_minimum_size = Vector2(0, 180)
		view.background = Color(0, 0, 0, 0.16)
		vb.add_child(view)
		view.set_look(look)
		var n := Label.new()
		n.text = str(entry.get("name", "Look"))
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.add_theme_font_override("font", UITheme.heading_font())
		vb.add_child(n)
		var actions := HBoxContainer.new()
		actions.alignment = BoxContainer.ALIGNMENT_CENTER
		actions.add_theme_constant_override("separation", 6)
		vb.add_child(actions)
		var use := GameButton.make("Wear", "PrimaryButton", Vector2(0, 46))
		use.add_theme_font_size_override("font_size", 18)
		use.pressed.connect(func() -> void:
			current = look.duplicate(true)
			_refresh()
			_status.text = "Loaded '%s' - Save & Equip to wear it online." % entry.name)
		actions.add_child(use)
		var dup := GameButton.make("Copy", "GhostButton", Vector2(0, 46))
		dup.add_theme_font_size_override("font_size", 18)
		dup.pressed.connect(func() -> void:
			if list.size() >= 30:
				return
			list.insert(i + 1, {"name": "%s copy" % entry.name, "appearance": look.duplicate(true), "savedAt": int(Time.get_unix_time_from_system())})
			LocalStore.save_presets(list)
			_show_category("Saved Looks"))
		actions.add_child(dup)
		var upd := GameButton.make("Update", "GhostButton", Vector2(0, 46))
		upd.add_theme_font_size_override("font_size", 18)
		upd.tooltip_text = "Overwrite with the look you're editing"
		upd.pressed.connect(func() -> void:
			list[i]["appearance"] = current.duplicate(true)
			if name_edit.text.strip_edges() != "":
				list[i]["name"] = name_edit.text.strip_edges()
			LocalStore.save_presets(list)
			_show_category("Saved Looks"))
		actions.add_child(upd)
		var del := GameButton.make("Delete", "DangerButton", Vector2(0, 46))
		del.add_theme_font_size_override("font_size", 18)
		del.pressed.connect(func() -> void:
			if del.text != "Sure?":
				del.text = "Sure?"
				return
			list.remove_at(i)
			LocalStore.save_presets(list)
			_show_category("Saved Looks"))
		actions.add_child(del)
		g.add_child(card)


# ---------------------------------------------------------------------------
# Save / back
# ---------------------------------------------------------------------------

func _save() -> void:
	_save_btn.disabled = true
	LocalStore.save_appearance(current)
	if Backend.is_logged_in():
		_status.text = "Saving…"
		var res := await Backend.update_profile({"appearance": current})
		if res.ok:
			_status.text = "Saved! Opponents will see this look."
			saved = current.duplicate(true)
			Sfx.play("results", -4.0)
		else:
			_status.text = "Saved on this PC, but not online: %s" % Backend.friendly_error(res)
			saved = current.duplicate(true)
	else:
		saved = current.duplicate(true)
		_status.text = "Saved on this PC. It will sync when you're online."
	_refresh()
	_update_selection()


func _back() -> void:
	if JSON.stringify(current) != JSON.stringify(saved) and _unsaved.text != "Leave without saving? Click Back again.":
		_unsaved.text = "Leave without saving? Click Back again."
		return
	Router.goto(Router.MAIN_MENU)


# ---------------------------------------------------------------------------

## The big preview: a grass podium with the golfer standing on it and a ball at address.
## The golfer is scaled from the standard character height (so a small character still looks
## small) but never beyond what fits the stage, and the golfer + ball group is centred.
class _Podium extends Control:
	var golfer: Golfer
	var ball: _BallPreview
	var _t := 0.0
	var _scale := 4.0
	var _ground := Vector2.ZERO

	func _ready() -> void:
		resized.connect(fit)

	func fit() -> void:
		if golfer == null or size.y <= 0.0:
			return
		var b := Golfer.idle_bounds(golfer.appearance)
		# Headroom for swings and jumps above the idle pose.
		var by := maxf(b.size.y, 78.0) * 1.3
		var group_l := minf(b.position.x, -20.0)
		var group_r := Golfer.BALL_OFFSET + 8.0
		_scale = minf(size.y * 0.86 / by, size.x * 0.8 / (group_r - group_l))
		_ground = Vector2(size.x * 0.5 - (group_l + group_r) * 0.5 * _scale, size.y * 0.86)
		golfer.scale = Vector2(_scale, _scale)
		golfer.position = _ground
		if ball:
			ball.radius = 9.0 / 1.3 * _scale
			ball.home = _ground + Vector2(Golfer.BALL_OFFSET * _scale, -ball.radius)
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, _ground.y)
		var w := minf(size.x * 0.46, 70.0 * _scale)
		var glow := 0.5 + 0.5 * sin(_t * 1.5)
		for i in 6:
			var r := w * 1.15 - i * w * 0.16
			draw_circle(c + Vector2(0, -w * 0.9), r, Color(1, 0.95, 0.75, 0.025 + glow * 0.01), true, -1.0, true)
		draw_colored_polygon(ToonCanvas.ellipse_pts(c + Vector2(0, w * 0.07), Vector2(w * 1.04, w * 0.2), 0.0, 48), Color(0, 0, 0, 0.25))
		var top := ToonCanvas.ellipse_pts(c, Vector2(w, w * 0.17), 0.0, 48)
		var rim := ToonCanvas.ellipse_pts(c + Vector2(0, w * 0.05), Vector2(w, w * 0.17), 0.0, 48)
		draw_colored_polygon(rim, Color("2e8a3e"))
		draw_colored_polygon(top, Color("3ec46d"))
		draw_colored_polygon(ToonCanvas.ellipse_pts(c + Vector2(0, -w * 0.015), Vector2(w * 0.83, w * 0.12), 0.0, 48), Color("6ccf4a"))
		var outline := rim.duplicate()
		outline.append(rim[0])
		draw_polyline(outline, Color("1b2040"), 4.0, true)
		var outline2 := top.duplicate()
		outline2.append(top[0])
		draw_polyline(outline2, Color("1b2040"), 3.0, true)


class _BallPreview extends Node2D:
	var home := Vector2.ZERO
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var flying := false
	var ball_color := Color.WHITE
	var trail_color := Color.YELLOW
	var radius := 30.0
	var trail: PackedVector2Array = PackedVector2Array()
	var _wait := 0.0

	func reset() -> void:
		flying = false
		_wait = 0.0
		trail.clear()

	func launch() -> void:
		flying = true
		pos = home
		vel = Vector2(1500, -1700) * (radius / 30.0)
		trail.clear()

	func _process(delta: float) -> void:
		if flying:
			vel.y += 2600.0 * (radius / 30.0) * delta
			pos += vel * delta
			trail.append(pos)
			if trail.size() > 24:
				trail.remove_at(0)
			if pos.y > home.y + 900:
				flying = false
				_wait = 0.7
		else:
			if _wait > 0.0:
				_wait -= delta
				if trail.size() > 0:
					trail.remove_at(0)
			pos = home
		queue_redraw()

	func _draw() -> void:
		var n := trail.size()
		for i in range(1, n):
			var k := float(i) / float(n)
			draw_line(trail[i - 1], trail[i], Color(trail_color, k * 0.85), radius * 0.9 * k + 2.0, true)
		if not flying and _wait > 0.0:
			return
		var r := radius
		draw_circle(pos, r + maxf(3.0, r * 0.14), Color("1b2040"), true, -1.0, true)
		draw_circle(pos, r, ball_color, true, -1.0, true)
		draw_circle(pos + Vector2(r * 0.18, r * 0.2), r * 0.72, ball_color.darkened(0.12), true, -1.0, true)
		draw_circle(pos + Vector2(-r * 0.05, -r * 0.05), r * 0.78, ball_color, true, -1.0, true)
		draw_circle(pos + Vector2(-r * 0.35, -r * 0.38), r * 0.24, Color(1, 1, 1, 0.8), true, -1.0, true)
