class_name GameButton
extends Button
## Button with springy hover/press feedback and UI sounds.

var _tw: Tween


static func make(label: String, variation: String = "", min_size: Vector2 = Vector2(0, 64)) -> GameButton:
	var b := GameButton.new()
	b.text = label
	if variation != "":
		b.theme_type_variation = variation
	b.custom_minimum_size = min_size
	return b


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	button_down.connect(_on_down)
	pressed.connect(func() -> void: Sfx.play("ui_click", -4.0))
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	pivot_offset = size * 0.5


func _on_hover(on: bool) -> void:
	if disabled:
		return
	if on:
		Sfx.play("ui_hover", -14.0, randf_range(0.95, 1.05), 40)
	_animate(1.04 if on else 1.0, 0.12)


func _on_down() -> void:
	_animate(0.96, 0.05)
	await get_tree().create_timer(0.06).timeout
	if is_inside_tree():
		_animate(1.04 if is_hovered() else 1.0, 0.18)


func _animate(target: float, dur: float) -> void:
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "scale", Vector2(target, target), dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
