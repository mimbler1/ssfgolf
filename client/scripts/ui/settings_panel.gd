class_name SettingsPanel
extends Control
## Full-screen settings overlay: display, audio, gameplay, controls (remapping), network.

signal closed

var _tabs: Dictionary = {}
var _content: VBoxContainer
var _capture_action: String = ""
var _capture_button: Button


func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.1, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1100, 760)
	center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	panel.add_child(root)
	var head := HBoxContainer.new()
	root.add_child(head)
	var t := Label.new()
	t.theme_type_variation = "HeadingLabel"
	t.text = "Settings"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := GameButton.make("Done", "PrimaryButton", Vector2(160, 58))
	close.pressed.connect(_close)
	head.add_child(close)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	root.add_child(tabs)
	for name in ["Display", "Audio", "Gameplay", "Controls", "Network"]:
		var b := GameButton.make(name, "GhostButton", Vector2(150, 52))
		b.toggle_mode = true
		b.pressed.connect(_show_tab.bind(name))
		tabs.add_child(b)
		_tabs[name] = b
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 14)
	scroll.add_child(_content)
	_show_tab("Display")
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)


func _close() -> void:
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if _capture_action != "":
		var desc := {}
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				_capture_action = ""
				_show_tab("Controls")
				get_viewport().set_input_as_handled()
				return
			desc = Settings.event_to_descriptor(event)
		elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]:
			desc = Settings.event_to_descriptor(event)
		if not desc.is_empty():
			Settings.rebind(_capture_action, desc)
			_capture_action = ""
			get_viewport().set_input_as_handled()
			_show_tab("Controls")
		return
	if event.is_action_pressed("pause_menu"):
		get_viewport().set_input_as_handled()
		_close()


func _show_tab(name: String) -> void:
	for k: String in _tabs:
		_tabs[k].button_pressed = k == name
	for c in _content.get_children():
		c.queue_free()
	match name:
		"Display":
			_option("Window mode", ["windowed", "borderless", "fullscreen"], ["Windowed", "Borderless", "Fullscreen"], "display", "window_mode")
			_toggle("V-Sync", "display", "vsync")
			_option("Frame cap", [0, 60, 120, 144, 165, 240], ["Unlimited", "60", "120", "144", "165", "240"], "display", "max_fps")
			_note("The interface scales automatically for 1080p, 1440p, 4K and ultrawide displays.")
		"Audio":
			_slider("Master volume", "audio", "master", 0.0, 1.0)
			_slider("Sound effects", "audio", "sfx", 0.0, 1.0)
			_slider("Music", "audio", "music", 0.0, 1.0)
		"Gameplay":
			_option("Controls", ["blitz", "classic"], ["Blitz: drag and release", "Classic: arrow keys + power meter"], "gameplay", "control_style")
			_option("Drag direction (Blitz)", ["pull", "push"], ["Pull back (slingshot)", "Push toward target"], "gameplay", "aim_mode")
			_slider("Drag length for full power (Blitz)", "gameplay", "aim_distance", 140.0, 520.0)
			_toggle("Dotted aim guide (predicted flight path)", "gameplay", "aim_dots")
			_slider("Screen shake", "gameplay", "screen_shake", 0.0, 1.0)
			_toggle("Reduced motion (no shake, flyovers or score pops)", "gameplay", "reduced_motion")
		"Controls":
			_note("Click a binding, then press a key or mouse button. Esc cancels. Left-click is always aim/shoot.")
			for action: String in Settings.ACTIONS:
				var row := HBoxContainer.new()
				var l := Label.new()
				l.text = str(Settings.ACTIONS[action].label)
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(l)
				var b := GameButton.make(Settings.binding_label(action), "GhostButton", Vector2(280, 50))
				b.add_theme_font_size_override("font_size", 20)
				b.pressed.connect(func() -> void:
					_capture_action = action
					b.text = "Press a key…")
				row.add_child(b)
				_content.add_child(row)
			var reset := GameButton.make("Reset to defaults", "DangerButton", Vector2(280, 56))
			reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			reset.pressed.connect(func() -> void:
				Settings.reset_bindings()
				_show_tab("Controls"))
			_content.add_child(reset)
		"Network":
			var row2 := HBoxContainer.new()
			var l2 := Label.new()
			l2.text = "Game service URL"
			l2.custom_minimum_size = Vector2(300, 0)
			row2.add_child(l2)
			var le := LineEdit.new()
			le.text = str(Settings.get_value("network", "backend_url"))
			le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			le.text_submitted.connect(func(v: String) -> void: Settings.set_value("network", "backend_url", v.strip_edges()))
			le.focus_exited.connect(func() -> void: Settings.set_value("network", "backend_url", le.text.strip_edges()))
			row2.add_child(le)
			_content.add_child(row2)
			_note("Your guest identity is stored on this PC (profile '%s'). Changing the URL points the game at a different server; you'll get a separate account there." % Backend.local_profile)


func _note(text: String) -> void:
	var l := Label.new()
	l.theme_type_variation = "MutedLabel"
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(l)


func _row(label: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(380, 0)
	row.add_child(l)
	_content.add_child(row)
	return row


func _option(label: String, values: Array, names: Array, section: String, key: String) -> void:
	var row := _row(label)
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(340, 52)
	var cur: Variant = Settings.get_value(section, key)
	for i in values.size():
		ob.add_item(names[i], i)
		if values[i] == cur:
			ob.select(i)
	ob.item_selected.connect(func(i: int) -> void: Settings.set_value(section, key, values[i]))
	row.add_child(ob)


func _toggle(label: String, section: String, key: String) -> void:
	var row := _row(label)
	var cb := CheckButton.new()
	cb.button_pressed = bool(Settings.get_value(section, key))
	cb.toggled.connect(func(on: bool) -> void: Settings.set_value(section, key, on))
	row.add_child(cb)


func _slider(label: String, section: String, key: String, lo: float, hi: float) -> void:
	var row := _row(label)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = (hi - lo) / 100.0
	s.value = float(Settings.get_value(section, key))
	s.custom_minimum_size = Vector2(420, 32)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var val := Label.new()
	val.custom_minimum_size = Vector2(80, 0)
	var fmt := func(v: float) -> String: return "%d%%" % roundi((v - lo) / (hi - lo) * 100.0) if hi <= 1.0 else str(roundi(v))
	val.text = fmt.call(s.value)
	s.value_changed.connect(func(v: float) -> void:
		val.text = fmt.call(v)
		Settings.set_value(section, key, v))
	row.add_child(s)
	row.add_child(val)
