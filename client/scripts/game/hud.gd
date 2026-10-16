class_name GameHud
extends Control
## In-game heads-up display. Reads the MatchView each frame; never mutates game state.

signal ability_clicked(id: String)
signal menu_pressed

var view: MatchView
var selected_ability: String = "standard"

var _players_box: VBoxContainer
var _player_rows: Dictionary = {}     ## slot -> {panel, name, pts}
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
	# Player list (top-left).
	_players_box = VBoxContainer.new()
	UITheme.pin(_players_box, 0, 0, Vector2(24, 22), 1, 1)
	_players_box.add_theme_constant_override("separation", 8)
	_players_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_players_box)
	for r in view.roster:
		_add_player_row(r)

	# Hole banner (top-centre).
	var banner := VBoxContainer.new()
	banner.custom_minimum_size = Vector2(600, 0)
	UITheme.pin(banner, 0.5, 0, Vector2(0, 10), 0, 1)
	banner.alignment = BoxContainer.ALIGNMENT_BEGIN
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_constant_override("separation", 0)
	add_child(banner)
	_banner_title = UITheme.styled_label("HOLE 1", 44, UITheme.PAPER, 10)
	banner.add_child(_banner_title)
	_banner_sub = UITheme.styled_label("", 24, UITheme.SUN, 7)
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

	# Menu button (top-right).
	var menu := GameButton.make("☰", "GhostButton", Vector2(64, 64))
	UITheme.pin(menu, 1, 0, Vector2(-24, 22), -1, 1)
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
	_energy.custom_minimum_size = Vector2(560, 34)
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
	UITheme.pin(_shots_label, 1, 1, Vector2(-28, -24), -1, -1)
	_shots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_shots_label)


## Compact "how to play" card in the bottom-left; keys follow the player's remapped bindings.
func _build_controls_card() -> Control:
	var panel := PanelContainer.new()
	var sb := UITheme.box(Color(UITheme.INK, 0.72), UITheme.RADIUS_SMALL)
	sb.content_margin_left = 14; sb.content_margin_right = 16
	sb.content_margin_top = 10; sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	panel.add_child(grid)
	var rows := [
		["Drag", "Aim, release to shoot"],
		[_short_key("cancel_aim"), "Cancel the shot"],
		["1 - 6", "Pick a ball"],
		[_short_key("activate_ability"), "Trigger it mid-flight"],
		[_short_key("reset_ball"), "Back to last spot"],
	]
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
		tl.add_theme_color_override("font_color", UITheme.PAPER)
		grid.add_child(tl)
	return panel


## First binding of an action, shortened for a key chip ("Right Mouse" -> "R-Click").
static func _short_key(action: String) -> String:
	var label := Settings.binding_label(action).split(" / ")[0]
	return {"Right Mouse": "R-Click", "Left Mouse": "L-Click", "Middle Mouse": "M-Click"}.get(label, label)


func _add_player_row(r: Dictionary) -> void:
	var slot := int(r.slot)
	var panel := PanelContainer.new()
	var is_local := slot == view.local_slot
	var sb := UITheme.arcade_box(Color(UITheme.INK, 0.92), UITheme.SLOT_COLORS[slot % UITheme.SLOT_COLORS.size()] if is_local else UITheme.INK_LINE)
	sb.content_margin_top = 5; sb.content_margin_bottom = 9; sb.content_margin_left = 16; sb.content_margin_right = 18
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	panel.add_child(hb)
	var chip := ColorRect.new()
	chip.custom_minimum_size = Vector2(14, 14)
	chip.color = UITheme.SLOT_COLORS[slot % UITheme.SLOT_COLORS.size()]
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(chip)
	var name_l := Label.new()
	name_l.text = str(r.name)
	name_l.custom_minimum_size = Vector2(170, 0)
	name_l.add_theme_font_override("font", UITheme.body_bold_font())
	name_l.add_theme_font_size_override("font_size", 21)
	name_l.clip_text = true
	hb.add_child(name_l)
	var pts := Label.new()
	pts.add_theme_font_override("font", UITheme.heading_font())
	pts.add_theme_font_size_override("font_size", 24)
	pts.add_theme_color_override("font_color", UITheme.SUN)
	pts.custom_minimum_size = Vector2(70, 0)
	pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(pts)
	_players_box.add_child(panel)
	_player_rows[slot] = {"panel": panel, "name": name_l, "pts": pts}


func _add_card(a: Dictionary, index: int) -> void:
	var id := str(a.id)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(112, 132)
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
	icon.custom_minimum_size = Vector2(80, 62)
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
	_cards[id] = {"panel": panel, "icon": icon, "cost": cost, "def": a, "color": Color(a.color)}


func _process(_delta: float) -> void:
	if view == null:
		return
	# Players & points.
	for slot: int in _player_rows:
		var row: Dictionary = _player_rows[slot]
		var ps := view.player_state(slot)
		var bs := view.ball_state(slot)
		if view.mode == "practice":
			row.pts.text = "%d shots" % int(ps.get("hole_shots", 0))
			row.pts.custom_minimum_size.x = 110
		elif view.mode == "stroke":
			row.pts.text = "%d strokes" % int(ps.get("strokes", 0))
			row.pts.custom_minimum_size.x = 130
		else:
			row.pts.text = "%d / %d" % [int(ps.get("points", 0)), view.target_points]
		var dim: bool = bs.get("forfeited", false) or not bs.get("connected", true)
		row.panel.modulate.a = 0.45 if dim else 1.0
		row.name.text = str(view.roster[slot].name) + ("  ⛳" if bs.get("finished", false) else "") + ("  (left)" if bs.get("forfeited", false) else ("  (reconnecting)" if not bs.get("connected", true) else ""))

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
		var sb := UITheme.arcade_box(Color(UITheme.INK, 0.94) if not sel else Color(col.darkened(0.45), 0.97),
			col if sel else UITheme.INK_LINE, UITheme.SLANT * 0.6, 4 if sel else 3)
		sb.content_margin_top = 6; sb.content_margin_bottom = 10; sb.content_margin_left = 10; sb.content_margin_right = 10
		c.panel.add_theme_stylebox_override("panel", sb)
		c.icon.dimmed = not affordable
		c.cost.energy = energy
		c.panel.position.y = -10.0 if sel else 0.0

	var bs_local := view.ball_state(view.local_slot)
	_shots_label.text = "Shots: %d" % int(me.get("hole_shots", 0)) if view.mode == "online" and not bs_local.get("finished", false) else ""


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

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(UITheme.arcade_box(Color(UITheme.INK, 0.94)), r)
		var pad := 7.0
		var inner := Rect2(r.position + Vector2(pad + 4, pad), r.size - Vector2(pad * 2 + 8, pad * 2 + 4))
		var gap := 5.0
		var w := (inner.size.x - gap * (segments - 1)) / segments
		var sl := inner.size.y * 0.35   # parallelogram cells, slanted like the panels
		for i in segments:
			var x := inner.position.x + i * (w + gap)
			var y0 := inner.position.y
			var y1 := inner.end.y
			var cell := PackedVector2Array([Vector2(x + sl, y0), Vector2(x + w + sl, y0), Vector2(x + w - sl, y1), Vector2(x - sl, y1)])
			draw_colored_polygon(cell, Color(1, 1, 1, 0.07))
			var fill := clampf(value - i, 0.0, 1.0)
			if fill > 0.0:
				var fw := w * fill
				var fc := PackedVector2Array([Vector2(x + sl, y0), Vector2(x + fw + sl, y0), Vector2(x + fw - sl, y1), Vector2(x - sl, y1)])
				var full := fill >= 1.0
				draw_colored_polygon(fc, Color("b65cff") if full else Color("6a2bb0"))
				if full:
					var hl := PackedVector2Array([Vector2(x + sl, y0), Vector2(x + w + sl, y0), Vector2(x + w + sl * 0.6, y0 + 5), Vector2(x + sl * 0.6, y0 + 5)])
					draw_colored_polygon(hl, Color("e9c8ff"))
		var f := UITheme.heading_font()
		var txt := "%d" % int(floor(value + 0.0001))
		draw_string_outline(f, Vector2(-34, size.y * 0.5 + 9), txt, HORIZONTAL_ALIGNMENT_RIGHT, 28, 26, 6, UITheme.INK_LINE)
		draw_string(f, Vector2(-34, size.y * 0.5 + 9), txt, HORIZONTAL_ALIGNMENT_RIGHT, 28, 26, Color("e0b3ff"))
		# Lightning glyph.
		var bolt := PackedVector2Array([Vector2(size.x + 14, 4), Vector2(size.x + 6, 18), Vector2(size.x + 13, 18), Vector2(size.x + 8, 31), Vector2(size.x + 22, 13), Vector2(size.x + 15, 13), Vector2(size.x + 20, 4)])
		draw_colored_polygon(bolt, Color("e0b3ff"))
		draw_polyline(bolt + PackedVector2Array([bolt[0]]), UITheme.INK_LINE, 2.0, true)


class _CostPips extends Control:
	var cost: int = 0
	var energy: float = 0.0:
		set(v):
			if not is_equal_approx(v, energy):
				energy = v
				queue_redraw()

	func _draw() -> void:
		if cost == 0:
			var f := UITheme.body_bold_font()
			draw_string(f, Vector2(0, 12), "FREE", HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, UITheme.MUTED)
			return
		var r := 5.0
		var total := cost * (r * 2 + 3) - 3
		var x0 := (size.x - total) * 0.5 + r
		for i in cost:
			var c := Vector2(x0 + i * (r * 2 + 3), size.y * 0.5)
			var lit := energy >= float(i + 1)
			draw_circle(c, r + 1.5, UITheme.INK_LINE, true, -1.0, true)
			draw_circle(c, r, Color("b65cff") if lit else Color(1, 1, 1, 0.15), true, -1.0, true)
