extends Node
## Persistent player settings and remappable input actions.

signal changed

const PATH := "user://settings.cfg"

## Remappable actions: id -> {label, default: Array of InputEvent descriptors}
## Descriptor: {"key": Key} or {"mouse": MouseButton}
const ACTIONS := {
	"ability_1": {"label": "Select Standard ball", "default": [{"key": KEY_1}]},
	"ability_2": {"label": "Select ability 2", "default": [{"key": KEY_2}]},
	"ability_3": {"label": "Select ability 3", "default": [{"key": KEY_3}]},
	"ability_4": {"label": "Select ability 4", "default": [{"key": KEY_4}]},
	"ability_5": {"label": "Select ability 5", "default": [{"key": KEY_5}]},
	"ability_6": {"label": "Select ability 6", "default": [{"key": KEY_6}]},
	"ability_page": {"label": "Next page of balls", "default": [{"key": KEY_Q}]},
	"activate_ability": {"label": "Trigger ability mid-flight", "default": [{"key": KEY_SPACE}]},
	"swing": {"label": "Classic: start / stop the power meter", "default": [{"key": KEY_SPACE}]},
	"aim_left": {"label": "Classic: turn aim left", "default": [{"key": KEY_A}, {"key": KEY_LEFT}]},
	"aim_right": {"label": "Classic: turn aim right", "default": [{"key": KEY_D}, {"key": KEY_RIGHT}]},
	"spin_top": {"label": "Topspin (before the shot) / spin forward in flight", "default": [{"key": KEY_W}, {"key": KEY_UP}]},
	"spin_back": {"label": "Backspin (before the shot) / spin back in flight", "default": [{"key": KEY_S}, {"key": KEY_DOWN}]},
	"cancel_aim": {"label": "Cancel aim", "default": [{"mouse": MOUSE_BUTTON_RIGHT}, {"key": KEY_X}]},
	"reset_ball": {"label": "Return ball to last shot", "default": [{"key": KEY_R}]},
	"camera_recenter": {"label": "Re-centre camera", "default": [{"key": KEY_C}]},
	"camera_overview": {"label": "Hold for hole overview", "default": [{"key": KEY_SHIFT}]},
	"zoom_in": {"label": "Zoom in", "default": [{"key": KEY_EQUAL}]},
	"zoom_out": {"label": "Zoom out", "default": [{"key": KEY_MINUS}]},
	"scoreboard": {"label": "Show scoreboard", "default": [{"key": KEY_TAB}]},
	"emote_1": {"label": "Emote: Wave", "default": [{"key": KEY_F1}]},
	"emote_2": {"label": "Emote: Laugh", "default": [{"key": KEY_F2}]},
	"emote_3": {"label": "Emote: Wow", "default": [{"key": KEY_F3}]},
	"emote_4": {"label": "Emote: Good Game", "default": [{"key": KEY_F4}]},
	"emote_5": {"label": "Emote: Clap", "default": [{"key": KEY_F5}]},
	"emote_6": {"label": "Emote: Facepalm", "default": [{"key": KEY_F6}]},
	"emote_7": {"label": "Emote: Flex", "default": [{"key": KEY_F7}]},
	"emote_8": {"label": "Emote: Dance", "default": [{"key": KEY_F8}]},
	"emote_wheel": {"label": "Hold for emote wheel", "default": [{"key": KEY_T}]},
	"pause_menu": {"label": "Menu", "default": [{"key": KEY_ESCAPE}]},
}

var values: Dictionary = {
	"display": {"window_mode": "windowed", "vsync": true, "max_fps": 0},
	"audio": {"master": 0.8, "sfx": 0.9, "music": 0.6},
	"gameplay": {"control_style": "blitz", "aim_mode": "pull", "aim_distance": 280.0, "screen_shake": 1.0},
	"network": {"backend_url": "http://127.0.0.1:8080"},
}
var bindings: Dictionary = {}  ## action -> Array of descriptors


func _ready() -> void:
	_load()
	_ensure_buses()
	_apply_bindings()
	if DisplayServer.get_name() != "headless":
		apply_display()
	apply_audio()


func get_value(section: String, key: String) -> Variant:
	return values.get(section, {}).get(key)


func set_value(section: String, key: String, value: Variant) -> void:
	if not values.has(section):
		values[section] = {}
	values[section][key] = value
	if section == "display":
		apply_display()
	elif section == "audio":
		apply_audio()
	save()
	changed.emit()


func save() -> void:
	var cfg := ConfigFile.new()
	for section: String in values:
		for key: String in values[section]:
			cfg.set_value(section, key, values[section][key])
	for action: String in bindings:
		cfg.set_value("bindings", action, bindings[action])
	cfg.save(PATH)


func _load() -> void:
	for action: String in ACTIONS:
		bindings[action] = ACTIONS[action].default.duplicate(true)
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for section: String in values:
		for key: String in values[section]:
			if cfg.has_section_key(section, key):
				var v: Variant = cfg.get_value(section, key)
				if typeof(v) == typeof(values[section][key]) or (v is float and values[section][key] is int) or (v is int and values[section][key] is float):
					values[section][key] = v
	if cfg.has_section("bindings"):
		for action in cfg.get_section_keys("bindings"):
			if ACTIONS.has(action):
				var v: Variant = cfg.get_value("bindings", action)
				if v is Array:
					bindings[action] = v


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _apply_bindings() -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for d: Dictionary in bindings[action]:
			var ev := descriptor_to_event(d)
			if ev:
				InputMap.action_add_event(action, ev)


func rebind(action: String, descriptor: Dictionary) -> void:
	# Remove the input from any other action first, so one key never does two things.
	for other: String in bindings:
		var list: Array = bindings[other]
		for i in range(list.size() - 1, -1, -1):
			if list[i] == descriptor:
				list.remove_at(i)
	bindings[action] = [descriptor]
	_apply_bindings()
	save()
	changed.emit()


func reset_bindings() -> void:
	for action: String in ACTIONS:
		bindings[action] = ACTIONS[action].default.duplicate(true)
	_apply_bindings()
	save()
	changed.emit()


static func descriptor_to_event(d: Dictionary) -> InputEvent:
	if d.has("key"):
		var k := InputEventKey.new()
		k.physical_keycode = int(d.key) as Key
		return k
	if d.has("mouse"):
		var m := InputEventMouseButton.new()
		m.button_index = int(d.mouse) as MouseButton
		return m
	return null


static func event_to_descriptor(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		var code: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		return {"key": code}
	if ev is InputEventMouseButton:
		return {"mouse": ev.button_index}
	return {}


func binding_label(action: String) -> String:
	var parts: PackedStringArray = []
	for d: Dictionary in bindings.get(action, []):
		if d.has("key"):
			parts.append(OS.get_keycode_string(int(d.key)))
		elif d.has("mouse"):
			match int(d.mouse):
				MOUSE_BUTTON_LEFT: parts.append("Left Mouse")
				MOUSE_BUTTON_RIGHT: parts.append("Right Mouse")
				MOUSE_BUTTON_MIDDLE: parts.append("Middle Mouse")
				_: parts.append("Mouse %d" % int(d.mouse))
	return " / ".join(parts) if not parts.is_empty() else "Unbound"


# ---------------------------------------------------------------------------
# Display & audio
# ---------------------------------------------------------------------------

func apply_display() -> void:
	var d: Dictionary = values.display
	match str(d.window_mode):
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(d.vsync) else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(d.max_fps)


func _ensure_buses() -> void:
	for bus_name in ["SFX", "Music"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func apply_audio() -> void:
	var a: Dictionary = values.audio
	_set_bus_linear("Master", float(a.master))
	_set_bus_linear("SFX", float(a.sfx))
	_set_bus_linear("Music", float(a.music))


func _set_bus_linear(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(idx, v <= 0.001)
