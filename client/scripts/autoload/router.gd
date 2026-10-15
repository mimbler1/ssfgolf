extends Node
## Scene navigation with a short animated wipe transition.

const MAIN_MENU := "res://scenes/main_menu.tscn"
const GAME := "res://scenes/game.tscn"
const CUSTOMIZE := "res://scenes/customize.tscn"

var params: Dictionary = {}
var _layer: CanvasLayer
var _rect: ColorRect
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_rect = ColorRect.new()
	_rect.color = Color("1b2040")
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	_layer.add_child(_rect)
	_dev_screenshot_hook()


## Developer tool: `-- --screenshot out.png [--shot-delay 1.5]` saves the viewport and quits.
func _dev_screenshot_hook() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--screenshot")
	if i == -1 or i + 1 >= args.size():
		return
	var path := args[i + 1]
	var delay := 1.5
	var j := args.find("--shot-delay")
	if j != -1 and j + 1 < args.size():
		delay = float(args[j + 1])
	await get_tree().create_timer(delay, true, false, true).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("screenshot saved: ", path)
	get_tree().quit()


func goto(path: String, p_params: Dictionary = {}) -> void:
	if _busy:
		return
	_busy = true
	params = p_params
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_rect, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
	await tw.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_rect, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE)
	await tw2.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
