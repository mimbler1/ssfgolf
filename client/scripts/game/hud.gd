class_name GameHud
extends Control
## In-game heads-up display. Reads the MatchView each frame; never mutates game state.

signal ability_clicked(id: String)
signal menu_pressed

var view: MatchView
var selected_ability: String = "standard"

var _panels: ScorePanels
var _banner_title: Label
var _banner_sub: Label
var _timer_pill: PanelContainer
var _timer_label: Label
var _energy: _EnergyBar
var _cards: Dictionary = {}           ## ability id -> {panel, icon, cost}
var _card_box: HBoxContainer
var _center: Label
var _center_tw: Tween
var _toast_box: VBoxContainer
var _hint: Control
var _shots_label: Label
var _emax: float = 10.0


func setup(p_view: MatchView) -> void:
	view = p_view
	theme = UITheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_emax = float(GameData.balance.energy.max)
	_build()


func _build() -> void:
	# SSF2-style player panels along the top (ScorePanels, HUD_SPEC.md).
	_panels = ScorePanels.new()
	add_child(_panels)
	_panels.setup(view)

	# Hole banner (top-centre).
	var banner := VBoxContainer.new()
	banner.custom_minimum_size = Vector2(360, 0)
	UITheme.pin(banner, 0.5, 0, Vector2(0, 10), 0, 1)
	banner.alignment = BoxContainer.ALIGNMENT_BEGIN
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_constant_override("separation", 0)
	add_child(banner)
	_banner_title = UITheme.styled_label("HOLE 1", 40, UITheme.PAPER, 10)
	banner.add_child(_banner_title)
	_banner_sub = UITheme.styled_label("", 21, UITheme.SUN, 7)
	_banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_sub.custom_minimum_size = Vector2(360, 0)
	banner.add_child(_banner_sub)
	_timer_pill = PanelContainer.new()
	var pill := UITheme.box(UITheme.CORAL, 20, UITheme.CORAL_DARK, 4)
	pill.content_margin_top = 4; pill.content_margin_bottom = 8
	_timer_pill.add_theme_stylebox_override("panel", pill)
	_timer_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_timer_label = UITheme.styled_label("0:25", 30, UITheme.PAPER, 0)
	_timer_pill.add_child(_timer_label)
	_timer_pill.visible = false
	banner.add_child(_timer_pill)

	# Menu button (bottom-right; the top edge belongs to the player panels).
	var menu := _MenuButton.new()
	menu.custom_minimum_size = Vector2(62, 62)
	UITheme.pin(menu, 1, 1, Vector2(-24, -24), -1, -1)
	menu.tooltip_text = "Menu (Esc)"
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	add_child(menu)

	# Bottom: energy bar above ability cards.
	var bottom := VBoxContainer.new()
	UITheme.pin(bottom, 0.5, 1, Vector2(0, -20), 0, -1)
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 10)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	_energy = _EnergyBar.new()
	_energy.custom_minimum_size = Vector2(560, 42)
	_energy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_energy.segments = int(_emax)
	bottom.add_child(_energy)
	_card_box = HBoxContainer.new()
	_card_box.add_theme_constant_override("separation", 12)
	_card_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_card_box)
	set_page(0)

	# Centre announcements.
	_center = UITheme.styled_label("", 120, UITheme.PAPER, 16)
	_center.custom_minimum_size = Vector2(1200, 220)
	UITheme.pin(_center, 0.5, 0.5, Vector2(0, -150), 0, 0)
	_center.pivot_offset = Vector2(600, 110)
	_center.modulate.a = 0.0
	add_child(_center)

	_toast_box = VBoxContainer.new()
	_toast_box.custom_minimum_size = Vector2(800, 0)
	UITheme.pin(_toast_box, 0.5, 0.5, Vector2(0, 0), 0, 1)
	_toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_box)

	_hint = _build_controls_card()
	UITheme.pin(_hint, 0, 1, Vector2(24, -24), 1, -1)
	add_child(_hint)

	_shots_label = UITheme.styled_label("", 26, UITheme.PAPER, 7)
	_shots_label.custom_minimum_size = Vector2(230, 40)
	UITheme.pin(_shots_label, 1, 1, Vector2(-104, -34), -1, -1)
	_shots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_shots_label)


## Compact "how to play" card in the bottom-left; keys follow the player's remapped bindings.
func _build_controls_card() -> Control:
	var panel := PanelContainer.new()
	var sb := InkStyleBox.make(Color(UITheme.PAPER, 0.92), 2.4, 12.0, 0.0, 4.0)
	sb.content_margin_left = 14; sb.content_margin_right = 16
	sb.content_margin_top = 8; sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	panel.add_child(grid)
	var classic := str(Settings.get_value("gameplay", "control_style")) == "classic"
	var rows := [
		["Drag", "Aim, release to shoot"],
		[_short_key("cancel_aim"), "Cancel the shot"],
	]
	if classic:
		rows = [
			["%s / %s" % [_short_key("aim_left"), _short_key("aim_right")], "Aim"],
			[_short_key("swing"), "Start / stop the power meter"],
		]
	rows.append(["%s / %s" % [_short_key("spin_top"), _short_key("spin_back")], "Spin (hold in flight)"])
	rows.append(["1 - 6, " + _short_key("ability_page"), "Pick a ball, next page"])
	rows.append([_short_key("activate_ability"), "Trigger it mid-flight"])
	rows.append([_short_key("reset_ball"), "Back to last spot"])
	rows.append(["Hold " + _short_key("emote_wheel"), "Emotes"])
	for row: Array in rows:
		var chip := PanelContainer.new()
		var cb := UITheme.box(UITheme.PAPER, 8, Color("c9c1b3"), 3)
		cb.content_margin_left = 8; cb.content_margin_right = 8
		cb.content_margin_top = 1; cb.content_margin_bottom = 2
		chip.add_theme_stylebox_override("panel", cb)
		chip.size_flags_horizontal = Control.SIZE_SHRINK_END
		var kl := Label.new()
		kl.text = str(row[0])
		kl.add_theme_font_override("font", UITheme.body_bold_font())
		kl.add_theme_font_size_override("font_size", 17)
		kl.add_theme_color_override("font_color", UITheme.INK)
		chip.add_child(kl)
		grid.add_child(chip)
		var tl := Label.new()
		tl.text = str(row[1])
		tl.add_theme_font_size_override("font_size", 19)
		tl.add_theme_color_override("font_color", UITheme.INK)
		grid.add_child(tl)
	return panel


## First binding of an action, shortened for a key chip ("Right Mouse" -> "R-Click").
static func _short_key(action: String) -> String:
	var label := Settings.binding_label(action).split(" / ")[0]
	return {"Right Mouse": "R-Click", "Left Mouse": "L-Click", "Middle Mouse": "M-Click"}.get(label, label)


func _add_card(a: Dictionary, index: int) -> void:
	var id := str(a.id)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(112, 140)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.tooltip_text = "%s — %s energy\n%s" % [a.name, int(a.cost), a.desc]
	panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			ability_clicked.emit(id)
			accept_event())
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vb)
	var key := Label.new()
	key.text = str(index)
	key.add_theme_font_override("font", UITheme.heading_font())
	key.add_theme_font_size_override("font_size", 18)
	key.add_theme_color_override("font_color", UITheme.MUTED)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(key)
	var icon := AbilityIcon.new()
	icon.ability = id
	icon.custom_minimum_size = Vector2(84, 66)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(icon)
	var name_l := Label.new()
	name_l.text = str(a.name)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_override("font", UITheme.body_bold_font())
	name_l.add_theme_font_size_override("font_size", 16)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(name_l)
	var cost := _CostPips.new()
	cost.cost = int(a.cost)
	cost.custom_minimum_size = Vector2(80, 14)
	cost.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(cost)
	_card_box.add_child(panel)
	_cards[id] = {"panel": panel, "icon": icon, "cost": cost, "def": a, "color": Color(a.color), "name": name_l}


func _process(_delta: float) -> void:
	if view == null:
		return
	# Finish window timer.
	var ph := view.phase_state()
	var dl: float = ph.get("deadline", INF)
	if int(ph.get("phase", 0)) == MatchSim.Phase.PLAYING and dl < 1e9 and view.mode == "online":
		var left := maxf(0.0, dl - float(ph.hole_time))
		var urgent := left <= float(GameData.balance.hole.finish_window) + 0.5
		_timer_pill.visible = urgent or left < 60.0
		_timer_label.text = "%d:%02d" % [int(left) / 60, int(left) % 60]
		_timer_pill.modulate = Color(1, 1, 1, 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.008)) if left < 10.0 else Color.WHITE
	else:
		_timer_pill.visible = false

	# Energy & cards.
	var me := view.player_state(view.local_slot)
	var energy := float(me.get("energy", 0.0))
	var stroke := view.mode == "stroke"
	_energy.visible = not stroke
	_energy.value = energy
	var charges: Dictionary = me.get("charges", {})
	for id: String in _cards:
		var c: Dictionary = _cards[id]
		var cost := float(c.def.cost)
		var affordable := energy + 0.0001 >= cost
		if stroke:
			# Stroke play spends limited charges per course instead of energy.
			affordable = id == "standard" or int(charges.get(id, 0)) > 0
			c.cost.cost = int(charges.get(id, 0)) if id != "standard" else 0
			c.cost.energy = 99.0
		var sel := id == selected_ability
		var col: Color = c.color
		c.icon.dimmed = not affordable
		c.cost.energy = energy
		var key := "%s%s" % [sel, affordable]
		if c.get("key", "") == key:
			continue
		c["key"] = key
		# Paper card: selected cards lift and take the ball's colour; unaffordable ones fade.
		var sb := InkStyleBox.make(col.lerp(UITheme.PAPER, 0.55) if sel else (UITheme.PAPER if affordable else UITheme.PAPER_DEEP), 3.8 if sel else 2.6, 12.0, 4.0, 4.0 if sel else 2.0)
		sb.lip_color = col.darkened(0.15) if sel else UITheme.PAPER_DEEP.darkened(0.08)
		sb.content_margin_top = 4; sb.content_margin_bottom = 10; sb.content_margin_left = 8; sb.content_margin_right = 8
		(c.name as Label).add_theme_color_override("font_color", UITheme.INK if affordable else UITheme.MUTED)
		c.panel.add_theme_stylebox_override("panel", sb)
		c.icon.dimmed = not affordable
		c.cost.energy = energy
		c.panel.position.y = -10.0 if sel else 0.0

	var bs_local := view.ball_state(view.local_slot)
	_shots_label.text = "Shots this hole: %d" % int(me.get("hole_shots", 0)) if view.mode == "online" and not bs_local.get("finished", false) else ""


## Shows one page of six balls (number keys 1-6 pick within the page; the page key flips).
func set_page(page: int) -> void:
	for c in _card_box.get_children():
		c.queue_free()
	_cards.clear()
	var allowed: Array[Dictionary] = []
	for a: Dictionary in GameData.abilities:
		if view.allowed_abilities.has(a.id):
			allowed.append(a)
	for i in range(page * 6, mini(allowed.size(), page * 6 + 6)):
		_add_card(allowed[i], i - page * 6 + 1)


func set_hole(number: int, hole_name: String, total_label: String) -> void:
	_banner_title.text = "HOLE %d" % (number + 1)
	_banner_sub.text = hole_name if total_label == "" else "%s · %s" % [hole_name, total_label]


func hide_hint() -> void:
	if _hint.modulate.a > 0.0:
		create_tween().tween_property(_hint, "modulate:a", 0.0, 1.5)


func announce(text: String, color: Color = UITheme.PAPER, size: int = 120, hold: float = 0.6) -> void:
	_center.text = text
	_center.label_settings.font_color = color
	_center.label_settings.font_size = size
	if _center_tw:
		_center_tw.kill()
	_center.scale = Vector2(0.4, 0.4)
	_center.modulate.a = 1.0
	_center_tw = create_tween()
	_center_tw.tween_property(_center, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_center_tw.tween_interval(hold)
	_center_tw.tween_property(_center, "modulate:a", 0.0, 0.25)


func toast(text: String, color: Color = UITheme.PAPER) -> void:
	var l := UITheme.styled_label(text, 32, color, 8)
	l.modulate.a = 0.0
	_toast_box.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)
	while _toast_box.get_child_count() > 3:
		_toast_box.get_child(0).queue_free()
		break


# ---------------------------------------------------------------------------

class _EnergyBar extends Control:
	var value: float = 0.0:
		set(v):
			if not is_equal_approx(v, value):
				value = v
				queue_redraw()
	var segments: int = 10
	var _cv := InkCanvas.new()

	func _draw() -> void:
		var cv := _cv
		var track := Rect2(Vector2(36, 4), size - Vector2(72, 8))
		var shape := InkStyleBox.outline_pts(track, track.size.y * 0.5, 1.2, 3.0)
		cv.fill(shape, Color(UITheme.PAPER, 0.95))
		var pad := 6.0
		var inner := track.grow(-pad)
		var gap := 4.0
		var w := (inner.size.x - gap * (segments - 1)) / segments
		for i in segments:
			var cell := Rect2(Vector2(inner.position.x + i * (w + gap), inner.position.y), Vector2(w, inner.size.y))
			var f := clampf(value - i, 0.0, 1.0)
			var oval := InkStyleBox.outline_pts(cell, cell.size.y * 0.45, 0.6, float(i))
			cv.fill(oval, Color(UITheme.ENERGY, 0.1))
			if f > 0.0:
				var part := Rect2(cell.position, Vector2(cell.size.x * f, cell.size.y))
				var fill_shape := InkStyleBox.outline_pts(part, minf(part.size.x, part.size.y) * 0.45, 0.6, float(i) + 0.5)
				cv.fill(fill_shape, UITheme.ENERGY if f >= 1.0 else UITheme.ENERGY.lerp(UITheme.PAPER, 0.4))
				if f >= 1.0:
					cv.stroke(PackedVector2Array([cell.position + Vector2(5, 5), cell.position + Vector2(cell.size.x - 5, 4.5)]), 2.0, Color(1, 1, 1, 0.55), 0.2, 0.2)
		cv.outline(shape, 2.8, InkCanvas.INK, 2.0)
		InkIcons.draw(cv, "energy", Vector2(size.x - 18, size.y * 0.5), 34.0)
		cv.flush(get_canvas_item())
		var f2 := UITheme.heading_font()
		var txt := "%d" % int(floor(value + 0.0001))
		draw_string_outline(f2, Vector2(0, size.y * 0.5 + 12), txt, HORIZONTAL_ALIGNMENT_CENTER, 32, 32, 7, InkCanvas.INK)
		draw_string(f2, Vector2(0, size.y * 0.5 + 12), txt, HORIZONTAL_ALIGNMENT_CENTER, 32, 32, UITheme.PAPER)


class _CostPips extends Control:
	var cost: int = 0
	var energy: float = 0.0:
		set(v):
			if not is_equal_approx(v, energy):
				energy = v
				queue_redraw()
	var _cv := InkCanvas.new()

	func _draw() -> void:
		if cost == 0:
			draw_string(UITheme.body_bold_font(), Vector2(0, 14), "FREE", HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, UITheme.MUTED)
			return
		var r := 5.0
		var total := cost * (r * 2 + 3) - 3
		var x0 := (size.x - total) * 0.5 + r
		for i in cost:
			var c := Vector2(x0 + i * (r * 2 + 3), size.y * 0.5)
			var lit := energy >= float(i + 1)
			_cv.ellipse(c, Vector2(r, r), UITheme.ENERGY if lit else Color(UITheme.PAPER_DEEP))
			_cv.ink_circle(c, Vector2(r, r), 1.6, InkCanvas.INK, float(i))
		_cv.flush(get_canvas_item())


class _MenuButton extends Button:
	var _cv := InkCanvas.new()

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		theme_type_variation = "GhostButton"
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		InkIcons.draw(_cv, "menu", size * 0.5, size.x * 0.75)
		_cv.flush(get_canvas_item())
