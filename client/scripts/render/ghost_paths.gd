class_name GhostPaths
extends Node2D
## Practice only: faint replays of the local player's last few shots (the path the ball actually
## took, recorded from the authoritative state, never a prediction), so angle and power changes
## can be compared shot to shot.

const KEEP := 3
const COLORS := [Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.32), Color(1, 1, 1, 0.18)]

var _paths: Array[PackedVector2Array] = []   ## newest first
var _recording := PackedVector2Array()
var _active := false


func begin_shot(from: Vector2) -> void:
	if _active and _recording.size() > 1:
		_push(_recording)
	_recording = PackedVector2Array([from])
	_active = true


func record(pos: Vector2, resting: bool) -> void:
	if not _active:
		return
	if _recording.is_empty() or _recording[_recording.size() - 1].distance_squared_to(pos) > 36.0:
		_recording.append(pos)
		queue_redraw()
	if resting:
		_push(_recording)
		_recording = PackedVector2Array()
		_active = false


func clear() -> void:
	_paths.clear()
	_recording = PackedVector2Array()
	_active = false
	queue_redraw()


func _push(p: PackedVector2Array) -> void:
	_paths.push_front(p)
	while _paths.size() > KEEP:
		_paths.pop_back()
	queue_redraw()


var _cv := InkCanvas.new()


## Faint pencil lines of the last shots (newest darkest).
func _draw() -> void:
	for i in range(_paths.size() - 1, -1, -1):
		var p := _paths[i]
		if p.size() > 1:
			_cv.stroke(InkCanvas.resample(p, 6.0), 3.0 - i * 0.6, Color(InkCanvas.INK, COLORS[i].a * 0.8), 0.05, 0.3, float(i), 0.15, 0.4, 0.4)
	if _recording.size() > 1:
		_cv.stroke(_recording, 2.0, Color(InkCanvas.INK, 0.3), 0.05, 0.05, 9.0, 0.1, 0.0, 0.5)
	_cv.flush(get_canvas_item())
