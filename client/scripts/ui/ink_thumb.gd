class_name InkThumb
extends Control
## A still, hand-drawn golfer preview for selection grids. It draws once (no per-frame cost) and
## caches its geometry by look + framing, so opening a studio tab with dozens of options is
## cheap. `part` frames the head, the legs, the torso or the club; `pose` is a still pose.

var look: Dictionary = {}
var part := ""          ## "" full body | head | legs | torso | club
var pose := "stand"
var pad := 6.0

static var _cache: Dictionary = {}   ## key -> {cv: InkCanvas, bounds: Rect2}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func set_look(a: Dictionary, p_part: String = "", p_pose: String = "stand") -> void:
	look = a
	part = p_part
	pose = p_pose
	queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)


static func _built(a: Dictionary, p_part: String, p_pose: String, lw: float = 2.3) -> Dictionary:
	var key := "%s|%s|%.2f|%s" % [p_part, p_pose, lw, JSON.stringify(a.get("ink", {}))]
	if _cache.has(key):
		return _cache[key]
	var cv := InkCanvas.new()
	var draw_part := "head" if p_part == "head" else ("club" if p_part == "club" else "")
	var s := Golfer.draw_still(cv, a, p_pose if p_part != "club" else "idle", lw, draw_part)
	var b := cv.bounds
	match p_part:
		"legs":
			var hip: Vector2 = s.hip
			b = Rect2(Vector2(b.position.x, hip.y - 6.0), Vector2(b.size.x, -hip.y + 7.0))
		"torso":
			var neck: Vector2 = s.neck
			var hip2: Vector2 = s.hip
			b = Rect2(Vector2(neck.x - 18.0, neck.y - 4.0), Vector2(36.0, hip2.y - neck.y + 14.0))
	if _cache.size() > 400:
		_cache.clear()
	var out := {"cv": cv, "bounds": b}
	_cache[key] = out
	return out


func _draw() -> void:
	if look.is_empty() or size.x < 4.0:
		return
	var d := _built(look, part, pose)
	var b: Rect2 = d.bounds
	var avail := size - Vector2(pad, pad) * 2.0
	var k := minf(avail.x / maxf(b.size.x, 1.0), avail.y / maxf(b.size.y, 1.0))
	# Keep the ink about 2.6 px on screen whatever the zoom (rebuild at a matching weight).
	var lw := snappedf(clampf(2.6 / k, 0.35, 2.6), 0.05)
	if absf(lw - 2.3) > 0.06:
		d = _built(look, part, pose, lw)
		b = d.bounds
		k = minf(avail.x / maxf(b.size.x, 1.0), avail.y / maxf(b.size.y, 1.0))
	var off := size * 0.5 - b.get_center() * k
	var src: InkCanvas = d.cv
	var moved := PackedVector2Array()
	moved.resize(src.pts.size())
	for i in src.pts.size():
		moved[i] = src.pts[i] * k + off
	if src.idx.size() >= 3:
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), src.idx, moved, src.cols)
