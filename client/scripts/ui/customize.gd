extends Node
## Golfer Studio (docs/INK_ART_SPEC.md §6, §8, §12): customise the hand-drawn stick figure.
##   left   categories
##   centre one large animated golfer on a hand-drawn platform, with animation previews
##   right  option grids (static InkThumb previews, cached), colour swatches, sliders, the
##          clothing drawing editor and saved looks
## Performance: only the big preview animates. Option cards are still drawings that render once.
##
## Dev flags: --studio-tab <Category>  --studio-anim <anim>  --studio-demo (applies a sample
## customisation: new hair, recoloured and reshaped pants, a hat and a pants drawing).

const CATEGORIES := [
	["Outfits", "star"], ["Hair", "brush"], ["Face", "user"], ["Pants", "studio"], ["Tops", "cards"],
	["Hats", "crown"], ["Eyewear", "target"], ["Neck & Back", "flag"], ["Hands & Feet", "check"],
	["Club", "trophy"], ["Buddy", "star"], ["Ball", "standard"], ["Draw", "brush"], ["Saved Looks", "copy"],
]
const MOVES := [["Idle", "idle"], ["Swing", "swing"], ["Walk", "walk"], ["Run", "run"], ["Jump", "jump"],
	["Victory", "victory"], ["Celebrate", "celebrate"], ["Dance", "dance"], ["Wave", "wave"], ["Laugh", "laugh"],
	["Clap", "clap"], ["Flex", "flex"], ["Wow", "wow"], ["Sad", "sad"]]

var current: Dictionary
var saved: Dictionary
var ui: Control
var preview: Golfer
var _stage: _Stage
var _cat_buttons: Dictionary = {}
var _options: VBoxContainer
var _scroll: ScrollContainer
var _right: PanelContainer
var _category := "Outfits"
var _save_btn: Button
var _status: Label
var _unsaved: Label
var _name_plate: Label
var _tag_plate: Label
var _pad: InkDrawPad
var _swing_seq := 0
## Animation preview buttons by anim id (also driven by the studio benchmark, PerfProbe).
var _anim_buttons: Dictionary = {}


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("f1ebe0"))
	Cosmetics.ensure_loaded()
	current = Appearance.normalize(Backend.profile.get("appearance")) if not Backend.profile.is_empty() else LocalStore.appearance()
	var args := OS.get_cmdline_user_args()
	var dc := args.find("--dev-character")
	if dc != -1 and dc + 1 < args.size():
		current = Appearance.for_outfit(current, args[dc + 1])
	saved = current.duplicate(true)
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
	if args.has("--studio-demo"):
		_demo()
	var st := args.find("--studio-tab")
	var tab := args[st + 1] if st != -1 and st + 1 < args.size() else "Outfits"
	_show_category(tab if _has_category(tab) else "Outfits")
	_refresh()
	var sa := args.find("--studio-anim")
	if sa != -1 and sa + 1 < args.size():
		_preview_anim.call_deferred(args[sa + 1])
	# Ownership (Collection): refresh from the backend, then re-show locks.
	if await Cosmetics.refresh():
		_show_category(_category)


func _has_category(c: String) -> bool:
	for e: Array in CATEGORIES:
		if e[0] == c:
			return true
	return false


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	ui.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	# Header.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	root.add_child(header)
	var back := GameButton.make("Back", "GhostButton", Vector2(140, 58))
	back.pressed.connect(_back)
	header.add_child(back)
	var title := UITheme.styled_label("Golfer Studio", 54, UITheme.PAPER, 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_unsaved = Label.new()
	_unsaved.add_theme_color_override("font_color", UITheme.CORAL_DARK)
	_unsaved.add_theme_font_override("font", UITheme.body_bold_font())
	header.add_child(_unsaved)
	_save_btn = GameButton.make("Save & Equip", "PrimaryButton", Vector2(230, 58))
	_save_btn.pressed.connect(_save)
	header.add_child(_save_btn)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	# Left: categories.
	var left := PanelContainer.new()
	left.custom_minimum_size = Vector2(250, 0)
	body.add_child(left)
	var lscroll := ScrollContainer.new()
	lscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(lscroll)
	var cats := VBoxContainer.new()
	cats.add_theme_constant_override("separation", 6)
	cats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lscroll.add_child(cats)
	for e: Array in CATEGORIES:
		var b := _CategoryButton.new()
		b.text = e[0]
		b.icon_kind = e[1]
		b.toggle_mode = true
		b.theme_type_variation = "GhostButton"
		b.custom_minimum_size = Vector2(0, 50)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 23)
		b.pressed.connect(_show_category.bind(e[0]))
		cats.add_child(b)
		_cat_buttons[e[0]] = b

	# Centre: stage.
	var centre := VBoxContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_stretch_ratio = 1.0
	centre.add_theme_constant_override("separation", 6)
	body.add_child(centre)
	_name_plate = UITheme.styled_label("", 40, UITheme.PAPER, 10)
	centre.add_child(_name_plate)
	_tag_plate = UITheme.styled_label("", 22, UITheme.SUN, 7)
	centre.add_child(_tag_plate)
	_stage = _Stage.new()
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(_stage)
	preview = Golfer.new()
	preview.shadow = false
	_stage.golfer = preview
	_stage.add_child(preview)
	var moves := HFlowContainer.new()
	moves.alignment = FlowContainer.ALIGNMENT_CENTER
	moves.add_theme_constant_override("h_separation", 6)
	moves.add_theme_constant_override("v_separation", 6)
	centre.add_child(moves)
	for m: Array in MOVES:
		var b := GameButton.make(m[0], "GhostButton", Vector2(0, 44))
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(_preview_anim.bind(m[1]))
		moves.add_child(b)
		_anim_buttons[m[1]] = b

	# Right: options.
	_right = PanelContainer.new()
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.size_flags_stretch_ratio = 0.95
	body.add_child(_right)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_right.add_child(_scroll)
	_options = VBoxContainer.new()
	_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options.add_theme_constant_override("separation", 10)
	_scroll.add_child(_options)

	_status = Label.new()
	_status.theme_type_variation = "MutedLabel"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var status_bg := PanelContainer.new()
	status_bg.theme_type_variation = "CardPanel"
	status_bg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	status_bg.add_child(_status)
	status_bg.visible = false
	_status.draw.connect(func() -> void: status_bg.visible = _status.text != "")
	root.add_child(status_bg)


func _process(_delta: float) -> void:
	_stage.queue_layout()


# ---------------------------------------------------------------------------
# Preview
# ---------------------------------------------------------------------------

func _preview_anim(a: String) -> void:
	_swing_seq += 1
	var seq := _swing_seq
	_stage.ball_reset()
	if a == "swing":
		preview.aim_power = 0.0
		preview.play("aim")
		var tw := create_tween()
		tw.tween_property(preview, "aim_power", 0.95, 0.6).set_trans(Tween.TRANS_SINE)
		await tw.finished
		await get_tree().create_timer(0.18).timeout
		if seq != _swing_seq:
			return
		preview.swing(0.95, "watch")
		await get_tree().create_timer(Golfer.IMPACT).timeout
		Sfx.play("swing", -10.0)
		Sfx.play("hit", -6.0)
		_stage.ball_launch()
		await get_tree().create_timer(1.6).timeout
		if seq == _swing_seq:
			preview.play("idle")
		return
	if Emotes.is_emote(a):
		preview.emote(a)
	else:
		preview.play(a)


func _refresh() -> void:
	preview.set_appearance(current)
	_stage.ball_color = Color(current.ballColor)
	_stage.trail_color = Color(current.trailColor)
	var o := InkLook.outfit(str(current.character))
	var custom := JSON.stringify(current.ink) != JSON.stringify(InkLook.outfit_look(str(current.character)))
	_name_plate.text = str(o.name) + (" (custom)" if custom else "")
	_tag_plate.text = str(o.tagline)
	var dirty := JSON.stringify(current) != JSON.stringify(saved)
	_unsaved.text = "Unsaved changes" if dirty else ""
	_save_btn.disabled = not dirty
	for c: String in _cat_buttons:
		(_cat_buttons[c] as Button).set_pressed_no_signal(c == _category)


func _set_ink(key: String, value: Variant, rebuild: bool = true) -> void:
	current.ink[key] = value
	current = Appearance.normalize(current)
	Sfx.play("ui_select", -10.0)
	_refresh()
	if rebuild:
		_show_category(_category)


# ---------------------------------------------------------------------------
# Categories
# ---------------------------------------------------------------------------

func _clear_options() -> void:
	for c in _options.get_children():
		c.queue_free()
	_pad = null


func _show_category(c: String) -> void:
	_category = c
	var keep := _scroll.scroll_vertical
	_clear_options()
	var heading := Label.new()
	heading.theme_type_variation = "HeadingLabel"
	heading.text = c
	_options.add_child(heading)
	var ink: Dictionary = current.ink
	match c:
		"Outfits":
			_muted("Themed looks for the same stick figure. Pick one, then make it yours in the other tabs.")
			var g := _grid(150)
			for id: String in InkLook.outfit_ids():
				var o := InkLook.outfit(id)
				var look := Appearance.for_outfit(current, id)
				var locked := not Cosmetics.owns("character", id)
				var card := _card(str(o.name), look, "", "stand", str(current.character) == id, func() -> void:
					if locked:
						Sfx.play("ui_deny", -8.0)
						_status.text = "%s is locked: open card packs in Collection to unlock." % o.name
						return
					current = Appearance.for_outfit(current, id)
					Sfx.play("ui_select", -8.0)
					_refresh()
					_show_category("Outfits"), 196.0, str(o.get("rarity", "common")), locked)
				card.tooltip_text = "%s - %s%s" % [o.name, o.tagline, "  (locked: card packs)" if locked else ""]
				g.add_child(card)
		"Hair":
			_option_grid("Style", "hair", InkLook.HAIR, "head")
			_section("Colour")
			_swatches("hairColor", true)
		"Face":
			_option_grid("Eyes", "eyes", InkLook.EYES, "head")
			_option_grid("Brows", "brows", InkLook.BROWS, "head")
			_option_grid("Mouth", "mouth", InkLook.MOUTHS, "head")
			_option_grid("Marks", "mark", InkLook.MARKS, "head")
			_option_grid("Head", "headFill", InkLook.HEAD_FILL, "head")
		"Pants":
			_option_grid("Cut", "pantsCut", InkLook.PANTS_CUTS, "legs", "stride")
			_section("Colour")
			_swatches("pantsColor")
			_option_grid("Pattern", "pantsPattern", InkLook.PATTERNS, "legs", "stride")
			_section("Pattern colour")
			_swatches("pantsColor2")
			_option_grid("Cuffs", "pantsCuff", InkLook.CUFFS, "legs", "stride")
			_section("Shape")
			_slider("Length", "pantsLength", 0.45, 1.0)
			_slider("Flare", "pantsFlare", 0.6, 1.8)
			_slider("Waist height", "pantsWaist", -4.0, 4.0)
		"Tops":
			_option_grid("Top", "top", InkLook.TOPS, "torso")
			_section("Colour")
			_swatches("topColor")
			_section("Trim colour")
			_swatches("topColor2")
		"Hats":
			_option_grid("Headwear", "hat", InkLook.HATS, "head")
			_section("Colour")
			_swatches("hatColor")
		"Eyewear":
			_option_grid("Eyewear", "eyewear", InkLook.EYEWEAR, "head")
			_section("Colour")
			_swatches("eyewearColor")
		"Neck & Back":
			_option_grid("Neck", "neck", InkLook.NECK, "")
			_swatches("neckColor")
			_option_grid("Back", "back", InkLook.BACK, "")
			_swatches("backColor")
		"Hands & Feet":
			_option_grid("Gloves", "gloves", InkLook.GLOVES, "")
			_swatches("glovesColor")
			_option_grid("Shoes", "shoes", InkLook.SHOES, "legs", "stride")
			_swatches("shoesColor")
		"Club":
			_option_grid("Club", "club", InkLook.CLUBS, "club", "idle")
		"Buddy":
			_muted("A little companion that floats behind your golfer.")
			_option_grid("Companion", "companion", InkLook.COMPANIONS, "")
		"Ball":
			_section("Ball colour")
			_swatches_v1("ballColor")
			_section("Trail colour")
			_swatches_v1("trailColor")
		"Draw":
			_draw_tab()
		"Saved Looks":
			_saved_looks()
	_refresh()
	await get_tree().process_frame
	_scroll.scroll_vertical = keep
	ink = ink


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


func _grid(min_w: float) -> GridContainer:
	var g := GridContainer.new()
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	var avail := maxf(300.0, _right.size.x - 70.0)
	g.columns = maxi(2, int(avail / (min_w + 10.0)))
	_options.add_child(g)
	return g


func _option_grid(title: String, key: String, table: Dictionary, part: String, pose: String = "stand") -> void:
	_section(title)
	var g := _grid(118 if part == "head" else 132)
	for id: String in table:
		var look := current.duplicate(true)
		look.ink[key] = id
		var h := 118.0 if part == "head" else 150.0
		var need := InkLook.signature_outfit(key, id)
		var locked := need != "" and not Cosmetics.owns("character", need) and str(current.ink.get(key, "")) != id
		var pick := _set_ink.bind(key, id)
		if locked:
			var oname := str(InkLook.outfit(need).name)
			pick = func() -> void:
				Sfx.play("ui_deny", -8.0)
				_status.text = "%s comes with %s: unlock it in card packs (Collection)." % [table[id], oname]
		var card := _card(str(table[id]), look, part, pose, str(current.ink.get(key, "")) == id, pick, h, "", locked)
		card.tooltip_text = str(table[id]) + ("  (comes with %s)" % InkLook.outfit(need).name if need != "" else "")
		g.add_child(card)


func _card(label: String, look: Dictionary, part: String, pose: String, selected: bool, on_pick: Callable, h: float, rarity: String = "", locked: bool = false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := InkStyleBox.make(UITheme.PAPER if not selected else UITheme.SUN.lerp(UITheme.PAPER, 0.55), 3.6 if selected else 2.4, 12.0, 3.0, 2.0)
	if selected:
		normal.hatch = 10.0
		normal.hatch_color = Color(UITheme.SUN.darkened(0.35), 0.25)
	var hover := normal.copy()
	hover.ink_width = normal.ink_width + 0.8
	hover.fill = normal.fill.lightened(0.05)
	for st in ["normal", "focus"]:
		b.add_theme_stylebox_override(st, normal)
	for st in ["hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, hover)
	b.pressed.connect(on_pick)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 6
	vb.offset_right = -6
	vb.offset_top = 4
	vb.offset_bottom = -6
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 0)
	b.add_child(vb)
	var thumb := InkThumb.new()
	thumb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	thumb.set_look(look, part, pose)
	vb.add_child(thumb)
	var l := Label.new()
	l.text = label
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 19)
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(l)
	if locked:
		thumb.modulate = Color(1, 1, 1, 0.45)
		var lock := Icon.make("lock", 26)
		lock.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		lock.position = Vector2(-34, 6)
		b.add_child(lock)
	if rarity != "" and UITheme.RARITY.has(rarity):
		var r: Dictionary = UITheme.RARITY[rarity]
		var rl := Label.new()
		rl.text = "%s %s" % [r.icon, r.name]
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rl.add_theme_font_size_override("font_size", 16)
		rl.add_theme_color_override("font_color", (r.color as Color).darkened(0.25))
		rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(rl)
	return b


func _swatches(key: String, allow_none: bool = false) -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	_options.add_child(flow)
	var cur := str(current.ink.get(key, ""))
	if allow_none:
		flow.add_child(_swatch(Color(0, 0, 0, 0), cur == "", _set_ink.bind(key, ""), "Ink only"))
	for hex: String in InkLook.PALETTE:
		flow.add_child(_swatch(Color(hex), cur == hex, _set_ink.bind(key, hex)))
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(46, 46)
	picker.tooltip_text = "Custom colour"
	picker.color = Color(cur) if InkLook.is_hex(cur) else Color.WHITE
	picker.edit_alpha = false
	picker.popup_closed.connect(func() -> void: _set_ink(key, "#" + picker.color.to_html(false)))
	flow.add_child(picker)


## Ball and trail colours are collectibles (Collection): locked ones show a lock and explain.
func _swatches_v1(key: String) -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	_options.add_child(flow)
	var kind: String = {"ballColor": "ball", "trailColor": "trail"}.get(key, "")
	for hex: String in Appearance.PALETTE:
		var locked := kind != "" and not Cosmetics.owns(kind, hex)
		var it := Cosmetics.item_for(kind, hex) if kind != "" else {}
		var sw := _swatch(Color(hex), str(current[key]).to_lower() == hex, func() -> void:
			if locked:
				Sfx.play("ui_deny", -8.0)
				_status.text = "%s is locked: open card packs in Collection to unlock." % str(it.get("name", hex))
				return
			current[key] = hex
			_refresh()
			_show_category(_category), (str(it.name) if not it.is_empty() else hex) + ("  (locked: card packs)" if locked else ""))
		if locked:
			sw.modulate = Color(1, 1, 1, 0.45)
			var lock := Icon.make("lock", 18)
			lock.position = Vector2(14, 14)
			sw.add_child(lock)
		flow.add_child(sw)


func _swatch(col: Color, selected: bool, on_pick: Callable, tip: String = "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(46, 46)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip if tip != "" else "#" + col.to_html(false)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sb := InkStyleBox.make(col if col.a > 0.0 else UITheme.PAPER, 4.2 if selected else 2.2, 23.0)
	if col.a == 0.0:
		sb.hatch = 6.0
		sb.hatch_color = Color(UITheme.INK, 0.4)
	if selected:
		sb.ink = UITheme.INK
	var hover := sb.copy()
	hover.ink_width = sb.ink_width + 1.0
	for st in ["normal", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	for st in ["hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, hover)
	b.pressed.connect(on_pick)
	return b


func _slider(label: String, key: String, lo: float, hi: float) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(150, 0)
	hb.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = float(current.ink.get(key, lo))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(func(v: float) -> void: _set_ink(key, v, false))
	s.drag_ended.connect(func(_c: bool) -> void: _show_category(_category))
	hb.add_child(s)
	_options.add_child(hb)


# ---------------------------------------------------------------------------
# Drawing editor
# ---------------------------------------------------------------------------

var _draw_target := "pants"
var _draw_state := {"tool": "pen", "color": Color("1c1714"), "width": 2.4, "opacity": 1.0, "smoothing": 0.5}


func _draw_tab() -> void:
	_muted("Draw straight onto your clothes. Designs bend and flutter with the cloth. Other players see drawings only if they turn on \"Show other players' custom drawings\" in Settings.")
	var targets := HBoxContainer.new()
	targets.add_theme_constant_override("separation", 8)
	_options.add_child(targets)
	for t: Array in [["pants", "Pants"], ["top", "Top"]]:
		var b := GameButton.make(t[1], "GhostButton", Vector2(120, 46))
		b.toggle_mode = true
		b.button_pressed = _draw_target == t[0]
		b.pressed.connect(func() -> void:
			_draw_target = t[0]
			_show_category("Draw"))
		targets.add_child(b)
	if _draw_target == "top" and str(current.ink.top) == "none":
		_muted("Pick a top in the Tops tab first to draw on it.")
		return
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	_options.add_child(body)
	_pad = InkDrawPad.new()
	_pad.target = _draw_target
	_pad.custom_minimum_size = Vector2(300, 470)
	_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pad.set_look(current.ink)
	_pad.set_drawing((current.ink.drawings as Dictionary).get(_draw_target, {}))
	for k: String in _draw_state:
		_pad.set(k, _draw_state[k])
	_pad.changed.connect(_on_drawing_changed)
	body.add_child(_pad)
	var tools := VBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	tools.custom_minimum_size = Vector2(190, 0)
	body.add_child(tools)
	var tool_grid := GridContainer.new()
	tool_grid.columns = 2
	tool_grid.add_theme_constant_override("h_separation", 6)
	tool_grid.add_theme_constant_override("v_separation", 6)
	tools.add_child(tool_grid)
	for t: Array in [["pen", "Ink pen"], ["marker", "Marker"], ["line", "Line"], ["eraser", "Eraser"]]:
		var b := GameButton.make(t[1], "GhostButton", Vector2(92, 44))
		b.add_theme_font_size_override("font_size", 18)
		b.toggle_mode = true
		b.button_pressed = _draw_state.tool == t[0]
		b.pressed.connect(func() -> void:
			_draw_state.tool = t[0]
			_show_category("Draw"))
		tool_grid.add_child(b)
	for row: Array in [["Size", "width", 0.6, 8.0], ["Opacity", "opacity", 0.15, 1.0], ["Smoothing", "smoothing", 0.0, 1.0]]:
		var l := Label.new()
		l.text = row[0]
		l.add_theme_font_size_override("font_size", 19)
		tools.add_child(l)
		var s := HSlider.new()
		s.min_value = row[2]
		s.max_value = row[3]
		s.step = 0.05
		s.value = float(_draw_state[row[1]])
		var k2: String = row[1]
		s.value_changed.connect(func(v: float) -> void:
			_draw_state[k2] = v
			if _pad:
				_pad.set(k2, v))
		tools.add_child(s)
	var actions := GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 6)
	actions.add_theme_constant_override("v_separation", 6)
	tools.add_child(actions)
	for a: Array in [["Undo", func() -> void: _pad.undo()], ["Redo", func() -> void: _pad.redo()],
			["Mirror", func() -> void: _pad.mirror()], ["Clear", func() -> void: _pad.clear_all()]]:
		var b := GameButton.make(a[0], "GhostButton" if a[0] != "Clear" else "DangerButton", Vector2(92, 44))
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(a[1])
		actions.add_child(b)
	if _draw_target == "pants":
		var legs := CheckButton.new()
		legs.text = "Both legs"
		legs.button_pressed = str((current.ink.drawings as Dictionary).get("pants", {}).get("legs", "both")) == "both"
		legs.toggled.connect(func(on: bool) -> void:
			_pad.drawing.legs = "both" if on else "front"
			_on_drawing_changed(_pad.drawing))
		tools.add_child(legs)
	_section("Ink colour")
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	_options.add_child(flow)
	for hex: String in InkLook.PALETTE:
		flow.add_child(_swatch(Color(hex), Color(hex).is_equal_approx(_draw_state.color), func() -> void:
			_draw_state.color = Color(hex)
			_show_category("Draw")))
	var left := Label.new()
	left.theme_type_variation = "MutedLabel"
	left.text = "%d / %d strokes · %d points left" % [_pad.stroke_count(), InkDrawing.MAX_STROKES, _pad.points_left()]
	_options.add_child(left)


func _on_drawing_changed(d: Dictionary) -> void:
	var all: Dictionary = (current.ink.drawings as Dictionary).duplicate(true)
	if (d.strokes as Array).is_empty():
		all.erase(_draw_target)
	else:
		all[_draw_target] = d.duplicate(true)
	current.ink.drawings = all
	current = Appearance.normalize(current)
	preview.set_appearance(current)
	_refresh()


# ---------------------------------------------------------------------------
# Saved looks
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
	var g := _grid(260)
	for i in list.size():
		var entry: Dictionary = list[i]
		var look := Appearance.normalize(entry.get("appearance"))
		var card := PanelContainer.new()
		card.theme_type_variation = "CardPanel"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var vb := VBoxContainer.new()
		card.add_child(vb)
		var thumb := InkThumb.new()
		thumb.custom_minimum_size = Vector2(0, 170)
		thumb.set_look(look, "", "stand")
		vb.add_child(thumb)
		var n := Label.new()
		n.text = str(entry.get("name", "Look"))
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.add_theme_font_override("font", UITheme.heading_font())
		vb.add_child(n)
		var actions := HFlowContainer.new()
		actions.alignment = FlowContainer.ALIGNMENT_CENTER
		actions.add_theme_constant_override("h_separation", 6)
		vb.add_child(actions)
		var use := GameButton.make("Wear", "PrimaryButton", Vector2(0, 44))
		use.add_theme_font_size_override("font_size", 18)
		use.pressed.connect(func() -> void:
			current = look.duplicate(true)
			_refresh()
			_status.text = "Loaded '%s' - Save & Equip to wear it online." % entry.name)
		actions.add_child(use)
		var dup := GameButton.make("Copy", "GhostButton", Vector2(0, 44))
		dup.add_theme_font_size_override("font_size", 18)
		dup.pressed.connect(func() -> void:
			if list.size() >= 30:
				return
			list.insert(i + 1, {"name": "%s copy" % entry.name, "appearance": look.duplicate(true), "savedAt": int(Time.get_unix_time_from_system())})
			LocalStore.save_presets(list)
			_show_category("Saved Looks"))
		actions.add_child(dup)
		var upd := GameButton.make("Update", "GhostButton", Vector2(0, 44))
		upd.add_theme_font_size_override("font_size", 18)
		upd.tooltip_text = "Overwrite with the look you're editing"
		upd.pressed.connect(func() -> void:
			list[i]["appearance"] = current.duplicate(true)
			if name_edit.text.strip_edges() != "":
				list[i]["name"] = name_edit.text.strip_edges()
			LocalStore.save_presets(list)
			_show_category("Saved Looks"))
		actions.add_child(upd)
		var del := GameButton.make("Delete", "DangerButton", Vector2(0, 44))
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
		_status.text = "Saving..."
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
	_show_category(_category)


func _back() -> void:
	if JSON.stringify(current) != JSON.stringify(saved) and _unsaved.text != "Leave without saving? Click Back again.":
		_unsaved.text = "Leave without saving? Click Back again."
		return
	Router.goto(Router.MAIN_MENU)


## Developer demo for review screenshots: new hair, recoloured + reshaped pants, a hat and a
## pants drawing (a lightning bolt and stars) on the base stickman.
func _demo() -> void:
	current = Appearance.for_outfit(current, "stickman")
	var ink: Dictionary = current.ink
	ink.hair = "swept"
	ink.hairColor = "#e0702a"
	ink.pantsColor = "#1fb5a3"
	ink.pantsCut = "bell"
	ink.pantsCuff = "rolled"
	ink.hat = "cap"
	ink.hatColor = "#d6304a"
	ink.top = "tee"
	ink.topColor = "#fbf6ec"
	ink.drawings = {"pants": {"v": 1, "legs": "both", "strokes": [
		{"c": "#ffd166", "w": 3.4, "a": 1.0, "p": [620, 300, 420, 470, 560, 490, 380, 700]},
		{"c": "#1c1714", "w": 1.6, "a": 1.0, "p": [300, 820, 360, 860, 420, 820, 360, 790, 300, 820]},
		{"c": "#fbf6ec", "w": 2.2, "a": 1.0, "p": [640, 760, 700, 760]},
	]}}
	current = Appearance.normalize(current)


# ---------------------------------------------------------------------------

## The stage: a hand-drawn grassy mound with the golfer on it and a ball at address.
class _Stage extends Control:
	var golfer: Golfer
	var ball_color := Color.WHITE
	var trail_color := Color("ffd166")
	var _scale := 4.0
	var _ground := Vector2.ZERO
	var _ball := Vector2.ZERO
	var _ball_v := Vector2.ZERO
	var _flying := false
	var _trail := PackedVector2Array()
	var _cv := InkCanvas.new()
	var _mound: InkCanvas
	var _mound_w := -1.0

	func queue_layout() -> void:
		if golfer == null:
			return
		var s := size
		_scale = clampf(minf(s.y / 125.0, s.x / 95.0), 1.5, 7.0)
		_ground = Vector2(s.x * 0.44, s.y * 0.86)
		golfer.position = _ground
		golfer.scale = Vector2(_scale, _scale)
		if _flying:
			var dt := get_process_delta_time()
			_ball_v.y += 900.0 * dt
			_ball += _ball_v * dt
			_trail.append(_ball)
			if _trail.size() > 22:
				_trail.remove_at(0)
			if _ball.y > size.y + 100.0 or _ball.x > size.x + 300.0:
				_flying = false
				ball_reset()
		elif not _trail.is_empty():
			_trail.remove_at(0)
		queue_redraw()

	func ball_reset() -> void:
		_flying = false
		_ball = _ground + Vector2(Golfer.BALL_OFFSET * _scale, -9.0 / 1.3 * _scale)
		_trail.clear()

	func ball_launch() -> void:
		_flying = true
		_ball = _ground + Vector2(Golfer.BALL_OFFSET * _scale, -9.0 / 1.3 * _scale)
		_ball_v = Vector2(randf_range(900, 1150), randf_range(-950, -800)) * _scale / 4.0

	func _draw() -> void:
		var w := size.x * 0.42
		if _mound == null or absf(_mound_w - w) > 1.0:
			_mound_w = w
			_mound = InkCanvas.new()
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			# A floating grassy island: gentle arched top, rounded hanging underside.
			var top := InkCanvas.cubic_bez(Vector2(-w, 0), Vector2(-w * 0.5, -w * 0.09), Vector2(w * 0.5, -w * 0.09), Vector2(w, 0), 24)
			var under := InkCanvas.cubic_bez(Vector2(w, 0), Vector2(w * 0.95, w * 0.22), Vector2(w * 0.3, w * 0.36), Vector2(-w * 0.05, w * 0.34), 14)
			var under2 := InkCanvas.cubic_bez(Vector2(-w * 0.05, w * 0.34), Vector2(-w * 0.45, w * 0.32), Vector2(-w * 0.95, w * 0.2), Vector2(-w, 0), 14)
			var soil := top + under.slice(1) + under2.slice(1, under2.size() - 1)
			_mound.fill(InkCanvas.ellipse_pts(Vector2(0, w * 0.5), Vector2(w * 0.7, w * 0.05), 0.0, 32), Color(0.1, 0.07, 0.05, 0.12))
			var cols := PackedColorArray()
			for v in soil:
				cols.append(Color("c08d5a").lerp(Color("8a5c3a"), clampf(v.y / (w * 0.34), 0.0, 1.0)))
			_mound.fill_colored(soil, cols)
			for inset in Geometry2D.offset_polygon(soil, -w * 0.07, Geometry2D.JOIN_ROUND):
				var c2 := PackedColorArray()
				for v in inset:
					c2.append(Color("b07e4f").lerp(Color("7a5032"), clampf(v.y / (w * 0.34), 0.0, 1.0)))
				_mound.fill_colored(inset, c2)
			for k in 16:
				var p := Vector2(rng.randf_range(-w * 0.7, w * 0.7), rng.randf_range(w * 0.06, w * 0.24))
				if not Geometry2D.is_point_in_polygon(p, soil):
					continue
				_mound.ellipse(p, Vector2(4.5, 3.2), Color("d8c3a2"))
				_mound.ink_circle(p, Vector2(4.5, 3.2), 1.3, Color("6d4730"), float(k))
			for k in 10:
				var p2 := Vector2(rng.randf_range(-w * 0.6, w * 0.6), rng.randf_range(w * 0.08, w * 0.26))
				if Geometry2D.is_point_in_polygon(p2, soil):
					_mound.stroke(InkCanvas.quad_bez(p2, p2 + Vector2(6, -2), p2 + Vector2(12, 0), 4), 1.6, Color(0.42, 0.28, 0.19, 0.7), 0.3, 0.3)
			# Grass band with a jagged hanging fringe, then the ink outline and blade tufts.
			for k in 60:
				var u := float(k) / 59.0
				var a := InkCanvas.cubic_bez(Vector2(-w, 0), Vector2(-w * 0.5, -w * 0.09), Vector2(w * 0.5, -w * 0.09), Vector2(w, 0), 59)[k]
				_mound.stroke(PackedVector2Array([a + Vector2(0, 14), a + Vector2(rng.randf_range(-1.5, 1.5), 14 + rng.randf_range(4, 10))]), rng.randf_range(3.0, 4.6), Color("3c8c33"), 0.05, 0.9)
				u = u
			_mound.caps = false
			_mound.stroke(InkCanvas.offset_line(top, 8.5), 17.0, Color("3c8c33"), 0.0001, 0.0001, 0.0, 0.0)
			_mound.stroke(InkCanvas.offset_line(top, 6.5), 12.0, Color("5db244"), 0.0001, 0.0001, 0.0, 0.0)
			_mound.stroke(InkCanvas.offset_line(top, 1.6), 3.0, Color("96d468"), 0.0001, 0.0001)
			_mound.caps = true
			_mound.outline(soil, 3.4, InkCanvas.INK, 1.0)
			for k in 40:
				var base := top[rng.randi_range(1, top.size() - 2)]
				_mound.stroke(InkCanvas.quad_bez(base, base + Vector2(0, -6), base + Vector2(rng.randf_range(-4, 4), -rng.randf_range(7, 13)), 4), 2.0, Color("3c8c33"), 0.05, 0.85)
			for k in 5:
				var fb := top[rng.randi_range(2, top.size() - 3)]
				var tip := fb + Vector2(rng.randf_range(-3, 3), -rng.randf_range(12, 18))
				_mound.stroke(PackedVector2Array([fb, tip]), 1.6, Color("3c8c33"), 0.05, 0.2)
				for q in 5:
					_mound.dot(tip + Vector2.from_angle(TAU * q / 5.0) * 3.0, 2.3, Color(["#ffffff", "#f7d24a", "#ef7aa0", "#b28be8"][k % 4]))
				_mound.dot(tip, 1.6, Color("f2b630"))
		var moved := PackedVector2Array()
		moved.resize(_mound.pts.size())
		var off := _ground + Vector2(golfer.position.x - _ground.x + Golfer.BALL_OFFSET * _scale * 0.4, 2.0)
		for i in _mound.pts.size():
			moved[i] = _mound.pts[i] + off
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _mound.idx, moved, _mound.cols)
		var r := 9.0 / 1.3 * _scale
		if _trail.size() > 3:
			_cv.stroke(InkCanvas.spline(_trail, 2), r * 1.7, Color(trail_color, 0.6), 0.95, 0.02, 1.0, 0.0, 0.0, 0.0)
		if not _flying:
			_ball = _ground + Vector2(Golfer.BALL_OFFSET * _scale, -r)
		_cv.ellipse(_ball, Vector2(r, r), ball_color)
		_cv.crescent(_ball, r * 0.97, Vector2(-r * 0.26, -r * 0.24), ball_color.darkened(0.16))
		_cv.ink_circle(_ball, Vector2(r, r), 3.0, InkCanvas.INK, 2.0)
		_cv.flush(get_canvas_item())


class _CategoryButton extends Button:
	var icon_kind := "star"
	var _cv := InkCanvas.new()

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_theme_constant_override("h_separation", 0)
		text = "      " + text

	func _draw() -> void:
		InkIcons.draw(_cv, icon_kind, Vector2(28, size.y * 0.5), 30.0)
		_cv.flush(get_canvas_item())
