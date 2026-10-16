extends Node
## Scene navigation with a short animated wipe transition.

const MAIN_MENU := "res://scenes/main_menu.tscn"
const GAME := "res://scenes/game.tscn"
const CUSTOMIZE := "res://scenes/customize.tscn"
const COURSES := "res://scenes/course_select.tscn"
const COLLECTION := "res://scenes/collection.tscn"

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
	if OS.get_cmdline_user_args().has("--offscreen"):
		# Automated captures (tools/shot.sh, tools/perf.sh): keep the window off every monitor
		# and never take focus, so art reviews don't interrupt whoever is using the PC.
		get_window().set_flag(Window.FLAG_NO_FOCUS, true)
		get_window().position = Vector2i(-20000, -20000)
	_dev_screenshot_hook()
	_dev_perf_hook()
	_dev_perf_log_hook()


## Developer tool: `-- --perf-log SECONDS [--perf-warmup S]` records frame times after a
## warm-up and prints mean / p95 / p99 / worst frame (ms) and the peak draw-call count, then
## quits unless a screenshot is also pending (tools/perf.sh).
func _dev_perf_log_hook() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--perf-log")
	if i == -1 or i + 1 >= args.size():
		return
	var secs := float(args[i + 1])
	var warm := 2.0
	var j := args.find("--perf-warmup")
	if j != -1 and j + 1 < args.size():
		warm = float(args[j + 1])
	await get_tree().create_timer(warm, true, false, true).timeout
	var times: PackedFloat32Array = []
	var draws := 0
	var start := Time.get_ticks_usec()
	var last := start
	while Time.get_ticks_usec() - start < int(secs * 1e6):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append(float(now - last) / 1000.0)
		last = now
		draws = maxi(draws, int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	times.sort()
	var sum := 0.0
	for t in times:
		sum += t
	var n := times.size()
	print("perf: frames=%d mean=%.2fms p95=%.2fms p99=%.2fms worst=%.2fms fps=%.1f draws=%d" % [
		n, sum / n, times[int(n * 0.95)], times[int(n * 0.99)], times[n - 1], 1000.0 * n / sum, draws])
	if not args.has("--screenshot"):
		get_tree().quit()


## Developer tool: `-- --profile perf --perf-studio out.json [--perf-cycles 3]` runs the studio benchmark.
func _dev_perf_hook() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--perf-studio")
	var gi := args.find("--perf-game")
	if gi != -1 and gi + 1 < args.size():
		i = gi
	if i == -1 or i + 1 >= args.size():
		return
	if args.find("--profile") == -1:
		push_error("--perf-studio saves looks: run it with --profile perf so real player data is untouched")
		get_tree().quit(1)
		return
	var probe := PerfProbe.new()
	probe.out_path = args[i + 1]
	probe.mode = "game" if gi != -1 else "studio"
	var c := args.find("--perf-cycles")
	if c != -1 and c + 1 < args.size():
		probe.cycles = int(args[c + 1])
	add_child(probe)


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
