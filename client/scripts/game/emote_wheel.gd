class_name EmoteWheel
extends Control
## Radial emote picker. Hold the emote key (or click the HUD button) to open it around the cursor,
## point at an emote, and release/click to send it. Each slot previews the player's own golfer
## frozen mid-emote.

signal chosen(index: int)
signal closed

const RADIUS := 168.0
const SLOT_R := 58.0
const DEADZONE := 46.0

var appearance: Dictionary = {}
var center := Vector2.ZERO
var hovered := -1
var _slots: Array[Dictionary] = []   ## {pos: Vector2, golfer: Golfer}
var _open_t := 0.0
var _label: Label
var _hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var n := Emotes.count()
	for i in n:
		var a := -PI * 0.5 + TAU * float(i) / float(n)
		var e: Dictionary = Emotes.LIST[i]
		var g := Golfer.new()
		g.set_appearance(appearance)
		g.emote(str(e.id))
		g.frozen_time = true
		var d := float(e.duration)
		g.set_time(d * 0.42, d * 0.42)
		g.scale = Vector2(0.95, 0.95)
		add_child(g)
		_slots.append({"dir": Vector2.from_angle(a), "golfer": g})
	_label = UITheme.styled_label("", 30, UITheme.PAPER, 8)
	_label.custom_minimum_size = Vector2(240, 40)
	add_child(_label)
	_hint = Label.new()
	_hint.theme_type_variation = "MutedLabel"
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.custom_minimum_size = Vector2(240, 0)
	add_child(_hint)
	Sfx.play("ui_select", -10.0, 1.1)


func open_at(p: Vector2) -> void:
	var vs := get_viewport_rect().size
	var m := RADIUS + SLOT_R + 12.0
	center = Vector2(clampf(p.x, m, vs.x - m), clampf(p.y, m, vs.y - m))
	_layout()


func _layout() -> void:
	for i in _slots.size():
		var s: Dictionary = _slots[i]
		var pos: Vector2 = center + s.dir * RADIUS
		s.pos = pos
		var g: Golfer = s.golfer
		g.position = pos + Vector2(0, 40)
	_label.position = center - Vector2(120, 34)
	_hint.position = center + Vector2(-120, 6)


func _process(delta: float) -> void:
	_open_t = minf(1.0, _open_t + delta * 7.0)
	var k := ease(_open_t, -2.2)
	scale = Vector2.ONE
	modulate.a = k
	for i in _slots.size():
		var g: Golfer = _slots[i].golfer
		var target := 1.25 if i == hovered else 1.05
		g.scale = g.scale.lerp(Vector2(target, target), 1.0 - exp(-delta * 18.0))
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_update_hover(mb.position)
			confirm()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			cancel()
		accept_event()


func _update_hover(p: Vector2) -> void:
	var d := p - center
	var prev := hovered
	if d.length() < DEADZONE:
		hovered = -1
	else:
		var n := _slots.size()
		var a := fposmod(d.angle() + PI * 0.5 + PI / float(n), TAU)
		hovered = int(a / (TAU / float(n))) % n
	if hovered != prev:
		if hovered >= 0:
			Sfx.play("ui_hover", -12.0, 1.0 + hovered * 0.03, 20)
		var e: Dictionary = Emotes.LIST[hovered] if hovered >= 0 else {}
		_label.text = str(e.get("name", ""))
		_hint.text = "" if hovered < 0 else Settings.binding_label("emote_%d" % (hovered + 1))


## Sends the hovered emote (if any) and closes.
func confirm() -> void:
	if hovered >= 0:
		chosen.emit(hovered)
	cancel()


func cancel() -> void:
	closed.emit()
	queue_free()


func _draw() -> void:
	var k := ease(_open_t, -2.2)
	# Backing ring.
	draw_circle(center, (RADIUS + SLOT_R + 10.0) * k, Color(UITheme.INK, 0.55), true, -1.0, true)
	draw_circle(center, DEADZONE + 4.0, Color(UITheme.INK, 0.85), true, -1.0, true)
	for i in _slots.size():
		var s: Dictionary = _slots[i]
		var pos: Vector2 = center + (s.pos - center) * k
		var hot := i == hovered
		draw_circle(pos, SLOT_R + 3.0, UITheme.INK_LINE, true, -1.0, true)
		draw_circle(pos, SLOT_R, UITheme.SUN if hot else Color("dfe6ff"), true, -1.0, true)
		draw_circle(pos + Vector2(-4, -8), SLOT_R - 12.0, Color(1, 1, 1, 0.35 if hot else 0.4), true, -1.0, true)
		var g: Golfer = s.golfer
		g.position = pos + Vector2(0, 40)
	if hovered >= 0:
		var dir: Vector2 = _slots[hovered].dir
		draw_arc(center, DEADZONE + 4.0, dir.angle() - 0.45, dir.angle() + 0.45, 16, UITheme.SUN, 6.0, true)
