extends Node
## Main menu: profile chip, play modes, and panels for queue, private rooms,
## leaderboard, profile and first-run naming. Every action talks to the real backend;
## anything unavailable offline is disabled with an explanation.

var backdrop: MenuBackdrop
var ui: Control
var _chip: PanelContainer
var _chip_name: Label
var _chip_level: Label
var _chip_xp: ProgressBar
var _chip_trophies: Label
var _chip_coins: Label
var _status: Label
var _online_buttons: Array[Button] = []
var _panel_root: Control
var _poll_token := 0
var _online := false


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("1b2040"))
	backdrop = MenuBackdrop.new()
	add_child(backdrop)
	backdrop.setup(GameData.theme_for("sunny_meadows"), _appearance())
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	ui = Control.new()
	ui.theme = UITheme.get_theme()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	_build()
	Backend.profile_changed.connect(_on_profile)
	_connect_backend()


func _appearance() -> Dictionary:
	return Appearance.normalize(Backend.profile.get("appearance")) if not Backend.profile.is_empty() else LocalStore.appearance()


func _build() -> void:
	# Logo.
	var logo := VBoxContainer.new()
	logo.add_theme_constant_override("separation", -26)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(logo)
	UITheme.pin(logo, 0, 0, Vector2(70, 50), 1, 1)
	var l1 := UITheme.styled_label("FAIRWAY", 128, UITheme.PAPER, 18)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	logo.add_child(l1)
	var l2 := UITheme.styled_label("FRENZY", 128, UITheme.SUN, 18)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	logo.add_child(l2)
	var tag := UITheme.styled_label("Real-time stickman golf racing", 30, Color("cfe9ff"), 7)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	logo.add_child(tag)
	logo.rotation = -0.03

	# Menu column.
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(460, 0)
	col.add_theme_constant_override("separation", 14)
	ui.add_child(col)
	UITheme.pin(col, 1, 0.5, Vector2(-80, 40), -1, 0)
	var play := GameButton.make("PLAY ONLINE", "PrimaryButton", Vector2(460, 96))
	play.add_theme_font_size_override("font_size", 40)
	play.pressed.connect(_quick_play)
	col.add_child(play)
	_online_buttons.append(play)
	var private := GameButton.make("Private Match", "", Vector2(460, 70))
	private.pressed.connect(func() -> void: _open_room_entry())
	col.add_child(private)
	_online_buttons.append(private)
	var practice := GameButton.make("Practice", "", Vector2(460, 70))
	practice.pressed.connect(func() -> void: Router.goto(Router.GAME, {"mode": "practice", "course": "sunny_meadows", "hole": 0}))
	col.add_child(practice)
	var studio := GameButton.make("Golfer Studio", "SunButton", Vector2(460, 70))
	studio.pressed.connect(func() -> void: Router.goto(Router.CUSTOMIZE))
	col.add_child(studio)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	var lb := GameButton.make("Leaderboard", "GhostButton", Vector2(223, 62))
	lb.pressed.connect(_open_leaderboard)
	row.add_child(lb)
	_online_buttons.append(lb)
	var settings := GameButton.make("Settings", "GhostButton", Vector2(223, 62))
	settings.pressed.connect(func() -> void:
		var sp := SettingsPanel.new()
		ui.add_child(sp))
	row.add_child(settings)
	var quit := GameButton.make("Quit", "GhostButton", Vector2(460, 56))
	quit.pressed.connect(func() -> void: get_tree().quit())
	col.add_child(quit)

	# Profile chip (top-right).
	_chip = PanelContainer.new()
	var sb := UITheme.box(Color(UITheme.INK, 0.9), 22, UITheme.INK_LINE, 0, 10)
	sb.content_margin_left = 16; sb.content_margin_right = 20; sb.content_margin_top = 10; sb.content_margin_bottom = 10
	_chip.add_theme_stylebox_override("panel", sb)
	_chip.mouse_filter = Control.MOUSE_FILTER_STOP
	_chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_chip.tooltip_text = "View profile"
	_chip.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and _online:
			_open_profile())
	ui.add_child(_chip)
	UITheme.pin(_chip, 1, 0, Vector2(-30, 26), -1, 1)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	_chip.add_child(hb)
	var lvl := PanelContainer.new()
	var lsb := UITheme.box(UITheme.SKY, 26, UITheme.SKY_DARK, 0, 0, 3)
	lsb.content_margin_left = 0; lsb.content_margin_right = 0; lsb.content_margin_top = 0; lsb.content_margin_bottom = 0
	lvl.add_theme_stylebox_override("panel", lsb)
	lvl.custom_minimum_size = Vector2(56, 56)
	_chip_level = UITheme.styled_label("-", 28, UITheme.PAPER, 6)
	lvl.add_child(_chip_level)
	hb.add_child(lvl)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	hb.add_child(info)
	_chip_name = Label.new()
	_chip_name.text = "Connecting…"
	_chip_name.add_theme_font_override("font", UITheme.heading_font())
	_chip_name.add_theme_font_size_override("font_size", 26)
	info.add_child(_chip_name)
	_chip_xp = ProgressBar.new()
	_chip_xp.custom_minimum_size = Vector2(220, 12)
	_chip_xp.show_percentage = false
	_chip_xp.add_theme_stylebox_override("background", UITheme.box(Color(0, 0, 0, 0.4), 6))
	_chip_xp.add_theme_stylebox_override("fill", UITheme.box(Color("80ed99"), 6))
	info.add_child(_chip_xp)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	hb.add_child(stats)
	stats.add_child(Icon.make("trophy", 34))
	_chip_trophies = _stat_label("-", UITheme.TROPHY)
	stats.add_child(_chip_trophies)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(8, 0)
	stats.add_child(sp)
	stats.add_child(Icon.make("coin", 30))
	_chip_coins = _stat_label("-", UITheme.SUN)
	stats.add_child(_chip_coins)

	_status = Label.new()
	_status.theme_type_variation = "MutedLabel"
	_status.add_theme_color_override("font_outline_color", UITheme.INK_LINE)
	_status.add_theme_constant_override("outline_size", 6)
	ui.add_child(_status)
	UITheme.pin(_status, 1, 0, Vector2(-34, 130), -1, 1)

	var ver := Label.new()
	ver.theme_type_variation = "MutedLabel"
	ver.text = "Project Fairway Frenzy (working title) · v%s" % GameData.VERSION
	ver.add_theme_color_override("font_outline_color", UITheme.INK_LINE)
	ver.add_theme_constant_override("outline_size", 6)
	ui.add_child(ver)
	UITheme.pin(ver, 0, 1, Vector2(28, -22), 1, -1)
	_set_online(false)


func _stat_label(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UITheme.heading_font())
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", color)
	return l


func _set_online(on: bool) -> void:
	_online = on
	for b in _online_buttons:
		b.disabled = not on
		b.tooltip_text = "" if on else "Requires a connection to the game servers."


# ---------------------------------------------------------------------------
# Backend connection & profile
# ---------------------------------------------------------------------------

func _connect_backend() -> void:
	_status.text = ""
	if not Backend.has_saved_identity() and not Backend.is_logged_in():
		_open_welcome()
		return
	_chip_name.text = "Connecting…"
	var ok := await Backend.ensure_session(false)
	if ok:
		_set_online(true)
		await Backend.refresh_profile()
		_on_profile(Backend.profile)
		_after_connect()
	else:
		_show_offline()


func _after_connect() -> void:
	var p := Router.params
	if p.get("autoQueue", false):
		Router.params = {}
		_quick_play()
	elif str(p.get("room", "")) != "":
		Router.params = {}
		_open_room(str(p.room))


func _show_offline() -> void:
	_set_online(false)
	_chip_name.text = "Offline"
	_chip_level.text = "-"
	_status.text = "Can't reach the game servers (%s). Practice still works." % Backend.base_url()
	var retry := GameButton.make("Retry", "GhostButton", Vector2(140, 50))
	retry.pressed.connect(func() -> void:
		retry.queue_free()
		_connect_backend())
	ui.add_child(retry)
	UITheme.pin(retry, 1, 0, Vector2(-34, 170), -1, 1)


func _on_profile(p: Dictionary) -> void:
	if p.is_empty():
		return
	_chip_name.text = str(p.get("displayName", "Golfer"))
	_chip_level.text = str(int(p.get("level", 1)))
	_chip_xp.max_value = maxf(1.0, float(p.get("xpForNextLevel", 100)))
	_chip_xp.value = float(p.get("xpIntoLevel", 0))
	_chip_xp.tooltip_text = "%d / %d XP to level %d" % [int(p.get("xpIntoLevel", 0)), int(p.get("xpForNextLevel", 100)), int(p.get("level", 1)) + 1]
	_chip_trophies.text = str(int(p.get("trophies", 0)))
	_chip_coins.text = str(int(p.get("coins", 0)))
	backdrop.set_appearance(Appearance.normalize(p.get("appearance")))


# ---------------------------------------------------------------------------
# Panels
# ---------------------------------------------------------------------------

func _open_panel(width: float, title: String) -> VBoxContainer:
	_close_panel()
	_poll_token += 1
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.1, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)
	_panel_root = dim
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)
	if title != "":
		var t := Label.new()
		t.theme_type_variation = "HeadingLabel"
		t.text = title
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(t)
	dim.modulate.a = 0.0
	create_tween().tween_property(dim, "modulate:a", 1.0, 0.15)
	panel.pivot_offset = Vector2(width * 0.5, 200)
	panel.scale = Vector2(0.92, 0.92)
	create_tween().tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return vb


func _close_panel() -> void:
	_poll_token += 1
	if _panel_root and is_instance_valid(_panel_root):
		_panel_root.queue_free()
	_panel_root = null


func _muted(text: String) -> Label:
	var l := Label.new()
	l.theme_type_variation = "MutedLabel"
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _error(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color("ff8fa3"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


# --- First run --------------------------------------------------------------

func _open_welcome() -> void:
	var vb := _open_panel(700, "Welcome, golfer!")
	vb.add_child(_muted("Pick a display name. A guest account is created on this PC; you can rename yourself later."))
	var le := LineEdit.new()
	le.placeholder_text = "Display name (3-16 letters, numbers, _ or space)"
	le.max_length = 16
	le.custom_minimum_size = Vector2(0, 60)
	vb.add_child(le)
	var err := _error("")
	vb.add_child(err)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 14)
	vb.add_child(hb)
	var offline := GameButton.make("Play Offline", "GhostButton", Vector2(240, 64))
	offline.pressed.connect(func() -> void:
		_close_panel()
		_show_offline())
	hb.add_child(offline)
	var go := GameButton.make("Let's Go!", "PrimaryButton", Vector2(240, 64))
	hb.add_child(go)
	var submit := func() -> void:
		var name := le.text.strip_edges()
		var rx := RegEx.create_from_string("^[A-Za-z0-9_ ]{3,16}$")
		if rx.search(name) == null:
			err.text = "Names need 3-16 letters, numbers, spaces or underscores."
			return
		go.disabled = true
		err.text = ""
		var ok := await Backend.ensure_session(true, name)
		go.disabled = false
		if ok:
			_close_panel()
			_set_online(true)
			# Upload any appearance designed offline before the account existed.
			await Backend.update_profile({"appearance": LocalStore.appearance()})
			_on_profile(Backend.profile)
		else:
			err.text = "Couldn't reach the game servers. You can play offline and connect later."
	go.pressed.connect(submit)
	le.text_submitted.connect(func(_t: String) -> void: submit.call())
	le.grab_focus()
	# Developer automation hook for UI screenshots/tests.
	var args := OS.get_cmdline_user_args()
	var di := args.find("--dev-autoname")
	if di != -1 and di + 1 < args.size():
		le.text = args[di + 1]
		submit.call()


# --- Quick play -------------------------------------------------------------

func _quick_play() -> void:
	var vb := _open_panel(620, "Finding players…")
	var token := _poll_token
	var spinner := _Spinner.new()
	spinner.custom_minimum_size = Vector2(120, 120)
	spinner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(spinner)
	var mode := _muted("Quick Play · Ranked · 2-4 players · First to 9")
	vb.add_child(mode)
	var elapsed := UITheme.styled_label("0:00", 44, UITheme.PAPER, 8)
	vb.add_child(elapsed)
	var err := _error("")
	vb.add_child(err)
	var cancel := GameButton.make("Cancel", "DangerButton", Vector2(220, 62))
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(cancel)
	var cancelled := [false]
	cancel.pressed.connect(func() -> void:
		cancelled[0] = true
		await Backend.send_json(HTTPClient.METHOD_DELETE, "/v1/matchmaking/queue", null)
		_close_panel())
	var res := await Backend.send_json(HTTPClient.METHOD_POST, "/v1/matchmaking/queue", {"mode": "quick"})
	if token != _poll_token:
		return
	if not res.ok and res.status != 409:
		err.text = Backend.friendly_error(res)
		return
	while token == _poll_token and not cancelled[0]:
		var st := await Backend.get_json("/v1/matchmaking/status")
		if token != _poll_token or cancelled[0]:
			return
		if not st.ok:
			err.text = Backend.friendly_error(st)
		else:
			var d: Dictionary = st.data
			var secs := int(float(d.get("elapsedMs", 0)) / 1000.0)
			elapsed.text = "%d:%02d" % [secs / 60, secs % 60]
			if str(d.status) == "matched" and d.get("match") is Dictionary:
				var m: Dictionary = d.match
				mode.text = "Match found!"
				Sfx.play("countdown_go")
				await get_tree().create_timer(0.6).timeout
				Router.goto(Router.GAME, {"mode": "online", "host": str(m.serverHost), "port": int(m.serverPort),
					"token": str(m.joinToken), "matchId": str(m.matchId), "queueMode": "quick"})
				return
			if str(d.status) == "idle":
				err.text = "The search was cancelled."
				return
			err.text = ""
		await get_tree().create_timer(1.0).timeout


# --- Private rooms ----------------------------------------------------------

func _open_room_entry() -> void:
	var vb := _open_panel(680, "Private Match")
	vb.add_child(_muted("Create a room and share the code, or join a friend's room. Private matches don't change trophies."))
	var create := GameButton.make("Create Room", "PrimaryButton", Vector2(0, 70))
	vb.add_child(create)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	vb.add_child(hb)
	var code := LineEdit.new()
	code.placeholder_text = "Room code"
	code.max_length = 6
	code.custom_minimum_size = Vector2(0, 64)
	code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code.add_theme_font_override("font", UITheme.heading_font())
	code.add_theme_font_size_override("font_size", 30)
	hb.add_child(code)
	var join := GameButton.make("Join", "", Vector2(160, 64))
	hb.add_child(join)
	var err := _error("")
	vb.add_child(err)
	var back := GameButton.make("Back", "GhostButton", Vector2(200, 56))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_close_panel)
	vb.add_child(back)
	create.pressed.connect(func() -> void:
		create.disabled = true
		var res := await Backend.send_json(HTTPClient.METHOD_POST, "/v1/rooms", {"maxPlayers": 4, "targetPoints": 9})
		create.disabled = false
		if res.ok:
			_open_room(str(res.data.code))
		else:
			err.text = Backend.friendly_error(res))
	var do_join := func() -> void:
		var c := code.text.strip_edges().to_upper()
		if c.length() != 6:
			err.text = "Room codes are 6 characters."
			return
		var res := await Backend.send_json(HTTPClient.METHOD_POST, "/v1/rooms/%s/join" % c, {})
		if res.ok:
			_open_room(c)
		else:
			err.text = "Room not found." if res.status == 404 else Backend.friendly_error(res)
	join.pressed.connect(do_join)
	code.text_submitted.connect(func(_t: String) -> void: do_join.call())
	code.text_changed.connect(func(t: String) -> void:
		var up := t.to_upper()
		if up != t:
			var caret := code.caret_column
			code.text = up
			code.caret_column = caret)


func _open_room(code: String) -> void:
	var vb := _open_panel(820, "")
	var token := _poll_token
	var head := HBoxContainer.new()
	vb.add_child(head)
	var t := Label.new()
	t.theme_type_variation = "HeadingLabel"
	t.text = "Room"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var code_l := UITheme.styled_label(code, 52, UITheme.SUN, 9)
	head.add_child(code_l)
	var copy := GameButton.make("Copy", "GhostButton", Vector2(110, 56))
	copy.tooltip_text = "Copy the room code"
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(code)
		copy.text = "Copied!")
	head.add_child(copy)
	vb.add_child(_muted("Share this code with friends. Everyone except the host must be Ready."))
	var members := VBoxContainer.new()
	members.add_theme_constant_override("separation", 8)
	vb.add_child(members)
	var settings := HBoxContainer.new()
	settings.add_theme_constant_override("separation", 16)
	vb.add_child(settings)
	var target_l := Label.new()
	target_l.text = "First to"
	settings.add_child(target_l)
	var target := OptionButton.new()
	for v in [5, 7, 9, 12, 15]:
		target.add_item("%d points" % v, v)
	settings.add_child(target)
	var max_l := Label.new()
	max_l.text = "Max players"
	settings.add_child(max_l)
	var maxp := OptionButton.new()
	for v in [2, 3, 4]:
		maxp.add_item(str(v), v)
	settings.add_child(maxp)
	var err := _error("")
	vb.add_child(err)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	vb.add_child(buttons)
	var leave := GameButton.make("Leave", "DangerButton", Vector2(200, 64))
	buttons.add_child(leave)
	var ready := GameButton.make("Ready", "", Vector2(220, 64))
	ready.toggle_mode = true
	buttons.add_child(ready)
	var start := GameButton.make("Start Match", "PrimaryButton", Vector2(260, 64))
	buttons.add_child(start)
	var state := {"room": {}, "updating": false}

	leave.pressed.connect(func() -> void:
		await Backend.send_json(HTTPClient.METHOD_POST, "/v1/rooms/%s/leave" % code, {})
		_close_panel())
	ready.toggled.connect(func(on: bool) -> void:
		if state.updating:
			return
		var res := await Backend.send_json(HTTPClient.METHOD_POST, "/v1/rooms/%s/ready" % code, {"ready": on})
		if not res.ok:
			err.text = Backend.friendly_error(res))
	start.pressed.connect(func() -> void:
		start.disabled = true
		var res := await Backend.send_json(HTTPClient.METHOD_POST, "/v1/rooms/%s/start" % code, {})
		if not res.ok:
			err.text = Backend.friendly_error(res)
			start.disabled = false)
	target.item_selected.connect(func(i: int) -> void:
		if not state.updating:
			Backend.send_json(HTTPClient.METHOD_PATCH, "/v1/rooms/%s" % code, {"targetPoints": target.get_item_id(i)}))
	maxp.item_selected.connect(func(i: int) -> void:
		if state.updating:
			return
		var res := await Backend.send_json(HTTPClient.METHOD_PATCH, "/v1/rooms/%s" % code, {"maxPlayers": maxp.get_item_id(i)})
		if not res.ok:
			err.text = Backend.friendly_error(res))

	while token == _poll_token:
		var res := await Backend.get_json("/v1/rooms/%s" % code)
		if token != _poll_token:
			return
		if not res.ok:
			if res.status == 404 or res.status == 403:
				err.text = "This room no longer exists."
				ready.disabled = true
				start.disabled = true
				return
			err.text = Backend.friendly_error(res)
		else:
			var room: Dictionary = res.data
			state.room = room
			state.updating = true
			var am_host := str(room.hostId) == Backend.player_id
			for c in members.get_children():
				c.queue_free()
			var all_ready := true
			var my_ready := false
			for m: Dictionary in room.members:
				var row := PanelContainer.new()
				row.theme_type_variation = "CardPanel"
				var hb := HBoxContainer.new()
				hb.add_theme_constant_override("separation", 12)
				row.add_child(hb)
				hb.add_child(Icon.make("crown" if m.isHost else "user", 30, UITheme.PAPER))
				var n := Label.new()
				n.text = str(m.displayName) + ("  (you)" if str(m.playerId) == Backend.player_id else "")
				n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				n.add_theme_font_override("font", UITheme.body_bold_font())
				hb.add_child(n)
				var st := Label.new()
				st.text = "Host" if m.isHost else ("Ready" if m.ready else "Not ready")
				st.add_theme_color_override("font_color", UITheme.SUN if m.isHost else (Color("80ed99") if m.ready else UITheme.MUTED))
				hb.add_child(st)
				members.add_child(row)
				if not m.isHost and not m.ready:
					all_ready = false
				if str(m.playerId) == Backend.player_id:
					my_ready = bool(m.ready)
			var s: Dictionary = room.settings
			for i in target.item_count:
				if target.get_item_id(i) == int(s.targetPoints):
					target.select(i)
			for i in maxp.item_count:
				if maxp.get_item_id(i) == int(s.maxPlayers):
					maxp.select(i)
			target.disabled = not am_host or str(room.status) != "open"
			maxp.disabled = target.disabled
			ready.visible = not am_host
			ready.button_pressed = my_ready
			ready.text = "Ready!" if my_ready else "Ready"
			start.visible = am_host
			start.disabled = not (all_ready and room.members.size() >= 2 and str(room.status) == "open")
			start.tooltip_text = "" if not start.disabled else "Needs at least 2 golfers, all Ready."
			state.updating = false
			if room.get("match") is Dictionary:
				var m2: Dictionary = room.match
				Sfx.play("countdown_go")
				Router.goto(Router.GAME, {"mode": "online", "host": str(m2.serverHost), "port": int(m2.serverPort),
					"token": str(m2.joinToken), "matchId": str(m2.matchId), "queueMode": "private", "roomCode": code})
				return
			err.text = ""
		await get_tree().create_timer(1.0).timeout


# --- Leaderboard & profile --------------------------------------------------

func _open_leaderboard() -> void:
	var vb := _open_panel(760, "Leaderboard")
	var token := _poll_token
	vb.add_child(_muted("Top golfers by trophies"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var close := GameButton.make("Close", "GhostButton", Vector2(200, 56))
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_close_panel)
	vb.add_child(close)
	var res := await Backend.get_json("/v1/leaderboard?limit=50")
	if token != _poll_token:
		return
	if not res.ok:
		list.add_child(_error(Backend.friendly_error(res)))
		return
	var entries: Array = res.data.get("entries", [])
	if entries.is_empty():
		list.add_child(_muted("No ranked matches have been played yet. Be the first!"))
	for e: Dictionary in entries:
		var row := PanelContainer.new()
		row.theme_type_variation = "CardPanel"
		if str(e.playerId) == Backend.player_id:
			row.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.SUN, 0.18), 16, UITheme.SUN, 0, 0, 2))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 14)
		row.add_child(hb)
		var rank := Label.new()
		rank.text = "#%d" % int(e.rank)
		rank.custom_minimum_size = Vector2(70, 0)
		rank.add_theme_font_override("font", UITheme.heading_font())
		rank.add_theme_color_override("font_color", [UITheme.SUN, Color("d9e2f2"), Color("f4a261")][int(e.rank) - 1] if int(e.rank) <= 3 else UITheme.MUTED)
		hb.add_child(rank)
		var n := Label.new()
		n.text = str(e.displayName)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.add_theme_font_override("font", UITheme.body_bold_font())
		hb.add_child(n)
		var lv := Label.new()
		lv.text = "Lv %d" % int(e.level)
		lv.theme_type_variation = "MutedLabel"
		hb.add_child(lv)
		hb.add_child(Icon.make("trophy", 28))
		var tr := _stat_label(str(int(e.trophies)), UITheme.TROPHY)
		tr.custom_minimum_size = Vector2(80, 0)
		hb.add_child(tr)
		list.add_child(row)


func _open_profile() -> void:
	var vb := _open_panel(820, "")
	var token := _poll_token
	var res := await Backend.refresh_profile()
	if token != _poll_token:
		return
	var p := Backend.profile
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	vb.add_child(head)
	var name_edit := LineEdit.new()
	name_edit.text = str(p.get("displayName", ""))
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(380, 62)
	name_edit.add_theme_font_override("font", UITheme.heading_font())
	name_edit.add_theme_font_size_override("font_size", 32)
	head.add_child(name_edit)
	var save := GameButton.make("Rename", "GhostButton", Vector2(150, 62))
	head.add_child(save)
	var err := _error("" if res.ok else Backend.friendly_error(res))
	save.pressed.connect(func() -> void:
		var r := await Backend.update_profile({"displayName": name_edit.text.strip_edges()})
		err.text = "" if r.ok else Backend.friendly_error(r)
		if r.ok:
			save.text = "Saved!")
	var st: Dictionary = p.get("stats", {})
	var matches := int(st.get("matches", 0))
	var wins := int(st.get("wins", 0))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	vb.add_child(grid)
	var cells := [
		["Level", str(int(p.get("level", 1)))], ["Trophies", str(int(p.get("trophies", 0)))], ["Best trophies", str(int(p.get("highestTrophies", 0)))],
		["Matches", str(matches)], ["Wins", str(wins)], ["Win rate", ("%d%%" % roundi(100.0 * wins / matches)) if matches > 0 else "-"],
		["Holes played", str(int(st.get("holesPlayed", 0)))], ["Holes won", str(int(st.get("holeWins", 0)))], ["Shots", str(int(st.get("shots", 0)))],
		["Abilities used", str(int(st.get("abilitiesUsed", 0)))], ["Favourite ball", str(GameData.ability(str(st.get("favoriteAbility", ""))).get("name", "-")) if st.get("favoriteAbility") != null else "-"],
		["Best win streak", str(int(st.get("longestWinStreak", 0)))],
	]
	for c in cells:
		var cell := PanelContainer.new()
		cell.theme_type_variation = "CardPanel"
		cell.custom_minimum_size = Vector2(240, 0)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 0)
		cell.add_child(cv)
		var k := Label.new()
		k.theme_type_variation = "MutedLabel"
		k.text = c[0]
		cv.add_child(k)
		var v := Label.new()
		v.text = c[1]
		v.add_theme_font_override("font", UITheme.heading_font())
		v.add_theme_font_size_override("font_size", 32)
		cv.add_child(v)
		grid.add_child(cell)
	vb.add_child(err)
	var hist_title := Label.new()
	hist_title.theme_type_variation = "TitleLabel"
	hist_title.text = "Recent matches"
	vb.add_child(hist_title)
	var hist := VBoxContainer.new()
	hist.add_theme_constant_override("separation", 6)
	vb.add_child(hist)
	var close := GameButton.make("Close", "GhostButton", Vector2(200, 56))
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_close_panel)
	vb.add_child(close)
	var h := await Backend.get_json("/v1/me/matches?limit=5")
	if token != _poll_token:
		return
	if h.ok:
		var list: Array = h.data.get("matches", [])
		if list.is_empty():
			hist.add_child(_muted("No matches yet."))
		for m: Dictionary in list:
			var r: Dictionary = m.get("myRewards", {})
			var l := Label.new()
			var td := int(r.get("trophyDelta", 0))
			l.text = "%s  ·  %s of %d  ·  %s  ·  %s" % [str(m.get("endedAt", "")).left(10), _ordinal(int(m.get("placement", 0))), int(m.get("playerCount", 0)),
				"Ranked" if m.get("ranked", false) else "Friendly", ("%+d trophies" % td) if m.get("ranked", false) else "+%d XP" % int(r.get("xpGained", 0))]
			hist.add_child(l)


static func _ordinal(n: int) -> String:
	match n:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
		_: return "%dth" % n


class _Spinner extends Control:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		for i in 8:
			var a := _t * 4.0 + TAU * float(i) / 8.0
			var k := float(i) / 8.0
			draw_circle(c + Vector2.from_angle(a) * 40.0, 6.0 + k * 6.0, Color(1, 1, 1, 0.2 + k * 0.8), true, -1.0, true)
		draw_circle(c, 20.0, Color("1b2040"), true, -1.0, true)
		draw_circle(c, 17.0, Color.WHITE, true, -1.0, true)
		draw_circle(c + Vector2(-5, -6), 5.0, Color(1, 1, 1, 0.9), true, -1.0, true)
