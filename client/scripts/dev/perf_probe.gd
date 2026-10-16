class_name PerfProbe
extends Node
## Scripted Golfer Studio benchmark (docs/PERFORMANCE_REPORT.md).
##   godot --path client -- --perf-studio out.json [--perf-cycles 3]
##
## Drives the real studio through the directive's test sequence (scroll the roster, switch
## between 30 characters, equip/remove headwear, preview every animation, save, return to the
## menu, reopen) and records per-phase frame times, stalls and memory.
## It presses Save, so it refuses to run on the player's default local profile: pass --profile perf.
## VSync and the FPS cap are disabled so frame time measures the work, not the display.

var out_path := ""
var cycles := 3
var _frames: PackedFloat32Array = PackedFloat32Array()
var _last_us := 0
var _phase := ""
var _report: Dictionary = {"phases": [], "memory": []}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -1000
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_run.call_deferred()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _phase != "" and _last_us > 0:
		_frames.append((now - _last_us) / 1000.0)
	_last_us = now


func _begin(phase: String) -> void:
	_phase = phase
	_frames = PackedFloat32Array()
	_last_us = 0


func _end() -> void:
	var f := Array(_frames)
	f.sort()
	var n := f.size()
	var sum := 0.0
	var over33 := 0
	for v: float in f:
		sum += v
		if v > 33.3:
			over33 += 1
	var row := {
		"phase": _phase, "frames": n,
		"avg_ms": snappedf(sum / maxf(1, n), 0.01),
		"p95_ms": snappedf(float(f[mini(n - 1, int(n * 0.95))]) if n > 0 else 0.0, 0.01),
		"max_ms": snappedf(float(f[n - 1]) if n > 0 else 0.0, 0.01),
		"stalls_over_33ms": over33,
	}
	_report.phases.append(row)
	print("[perf] %-28s frames %4d  avg %6.2f  p95 %6.2f  max %7.2f  >33ms %3d" % [
		row.phase, n, row.avg_ms, row.p95_ms, row.max_ms, over33])
	_phase = ""


func _mem(label: String) -> void:
	var row := {
		"at": label,
		"static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.01),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"video_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.01),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
	}
	_report.memory.append(row)
	print("[perf] mem %-20s static %.1f MB  objects %d  nodes %d  orphans %d  video %.1f MB  draws %d" % [
		label, row.static_mb, row.objects, row.nodes, row.orphans, row.video_mb, row.draw_calls])


func _wait(sec: float) -> void:
	var until := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _frames_wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _studio() -> Node:
	return get_tree().current_scene


func _buttons(root: Node, pred: Callable) -> Array[Button]:
	var out: Array[Button] = []
	for n in root.find_children("*", "Button", true, false):
		var b := n as Button
		if b.is_visible_in_tree() and not b.disabled and pred.call(b):
			out.append(b)
	return out


func _run() -> void:
	await _wait(1.0)
	_mem("menu start")
	for c in cycles:
		_begin("c%d open studio" % c)
		while Router._busy:
			await get_tree().process_frame
		Router.goto(Router.CUSTOMIZE)
		await _wait(1.6)
		while _studio() == null or _studio().get("_scroll") == null:
			await get_tree().process_frame
		_end()
		var s := _studio()
		_mem("c%d studio open" % c)

		_begin("c%d idle" % c)
		await _wait(1.5)
		_end()

		_begin("c%d scroll roster" % c)
		var scroll: ScrollContainer = s.get("_scroll")
		var vmax := int(scroll.get_v_scroll_bar().max_value)
		for i in 90:
			scroll.scroll_vertical = int(vmax * (0.5 - 0.5 * cos(float(i) / 90.0 * TAU)))
			await get_tree().process_frame
		_end()

		_begin("c%d switch 30 characters" % c)
		for i in 30:
			var cards := _buttons(s.get("_options"), func(b: Button) -> bool: return b.tooltip_text.contains(" - "))
			if cards.is_empty():
				break
			cards[(i * 7 + 3) % cards.size()].pressed.emit()
			await _frames_wait(4)
		_end()

		_begin("c%d headwear equip x20" % c)
		var stick: Array[Button] = _buttons(s.get("_options"), func(b: Button) -> bool: return b.tooltip_text.begins_with("Stickman"))
		if not stick.is_empty():
			stick[0].pressed.emit()
			await _frames_wait(4)
		var cat: Dictionary = s.get("_cat_buttons")
		if not cat.Headwear.disabled:
			cat.Headwear.pressed.emit()
			await _frames_wait(4)
			for i in 20:
				var thumbs := _buttons(s.get("_options"), func(b: Button) -> bool: return b.theme_type_variation == "GhostButton" and b.get_child_count() > 0)
				if thumbs.is_empty():
					break
				thumbs[(i * 3) % thumbs.size()].pressed.emit()
				await _frames_wait(4)
		_end()

		_begin("c%d colour swatches x20" % c)
		if not cat.Body.disabled:
			cat.Body.pressed.emit()
			await _frames_wait(4)
			for i in 20:
				var sw := _buttons(s.get("_options"), func(b: Button) -> bool: return b.tooltip_text.begins_with("#"))
				if sw.is_empty():
					break
				sw[(i * 5) % sw.size()].pressed.emit()
				await _frames_wait(4)
		_end()

		_begin("c%d preview all anims" % c)
		var anims: Dictionary = s.get("_anim_buttons")
		for id: String in anims:
			(anims[id] as Button).pressed.emit()
			await _wait(0.35)
		_end()

		_begin("c%d character tab" % c)
		cat.Character.pressed.emit()
		await _wait(0.8)
		_end()

		_begin("c%d save" % c)
		var save_btn: Button = s.get("_save_btn")
		if not save_btn.disabled:
			save_btn.pressed.emit()
		await _wait(0.8)
		_end()
		_mem("c%d before leave" % c)

		_begin("c%d back to menu" % c)
		while Router._busy:
			await get_tree().process_frame
		Router.goto(Router.MAIN_MENU)
		await _wait(1.6)
		_end()
		_mem("c%d menu" % c)

	_report["engine"] = Engine.get_version_info().string
	_report["gpu"] = RenderingServer.get_video_adapter_name()
	_report["cpu"] = OS.get_processor_name()
	_report["window"] = [get_window().size.x, get_window().size.y]
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(_report, "  "))
	f.close()
	print("[perf] report written: ", out_path)
	get_tree().quit()
