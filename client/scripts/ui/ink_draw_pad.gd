class_name InkDrawPad
extends Control
## Freehand drawing on a garment template (docs/INK_ART_SPEC.md §8). The pad shows one pant leg
## (or the shirt) laid flat; strokes are smoothed, resampled and stored in the garment's (u, v)
## space (InkDrawing format), so on the golfer they bend and flutter with the cloth.
## Tools: pen, marker, line, eraser. Undo/redo, clear and mirror operate on whole strokes.

signal changed(drawing: Dictionary)

var target := "pants"                ## pants | top
var look: Dictionary = InkLook.DEFAULT
var drawing: Dictionary = {"v": 1, "legs": "both", "strokes": []}
var tool := "pen"                    ## pen | marker | line | eraser
var color := Color("1c1714")
var width := 2.4                     ## template units (see InkDrawing)
var opacity := 1.0
var smoothing := 0.5                 ## 0 = raw mouse path, 1 = very smooth

var _undo: Array = []
var _redo: Array = []
var _cur := PackedVector2Array()
var _active := false
var _line_start := Vector2.ZERO
var _hover := Vector2(-1, -1)
var _cv := InkCanvas.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	resized.connect(queue_redraw)
	mouse_exited.connect(func() -> void:
		_hover = Vector2(-1, -1)
		queue_redraw())


func set_drawing(d: Dictionary) -> void:
	drawing = InkDrawing.normalize(d) if not d.is_empty() else {"v": 1, "legs": "both", "strokes": []}
	queue_redraw()


func set_look(l: Dictionary) -> void:
	look = l
	queue_redraw()


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func stroke_count() -> int:
	return (drawing.strokes as Array).size()


func points_left() -> int:
	return InkDrawing.MAX_POINTS - InkDrawing.point_count(drawing)


# ---------------------------------------------------------------------------
# Template geometry
# ---------------------------------------------------------------------------

func _area() -> Rect2:
	return Rect2(Vector2(16, 14), size - Vector2(32, 28))


## Garment half-width at u (rig units).
func _hw_units(u: float) -> float:
	if target == "top":
		var dims: Array = InkBody.TOP_SHAPES.get(str(look.top), InkBody.TOP_SHAPES.tee)
		if u < 0.3:
			return lerpf(float(dims[0]), float(dims[1]), smoothstep(0.0, 0.3, u))
		return lerpf(float(dims[1]), float(dims[2]), (u - 0.3) / 0.7)
	var sh := InkLook.cut_shape(look)
	return lerpf(float(sh.waist), float(sh.cuff), pow(u, float(sh.pow))) + float(sh.bag) * sin(PI * u) * (1.0 - u * 0.25)


func _max_units() -> float:
	var m := 0.1
	for k in 21:
		m = maxf(m, _hw_units(k / 20.0))
	return m


func _scale() -> float:
	var r := _area()
	var length_units := (InkRig.TORSO if target == "top" else InkRig.THIGH + InkRig.SHIN + 2.0)
	return minf(r.size.y / length_units, r.size.x * 0.5 / _max_units())


func to_screen(u: float, v: float) -> Vector2:
	var r := _area()
	var k := _scale()
	var length_units := (InkRig.TORSO if target == "top" else InkRig.THIGH + InkRig.SHIN + 2.0)
	var top := r.position.y + (r.size.y - length_units * k) * 0.5
	return Vector2(r.get_center().x + v * _hw_units(u) * k, top + u * length_units * k)


func to_template(p: Vector2) -> Vector2:
	var r := _area()
	var k := _scale()
	var length_units := (InkRig.TORSO if target == "top" else InkRig.THIGH + InkRig.SHIN + 2.0)
	var top := r.position.y + (r.size.y - length_units * k) * 0.5
	var u := clampf((p.y - top) / (length_units * k), 0.0, 1.0)
	var v := clampf((p.x - r.get_center().x) / maxf(_hw_units(u) * k, 0.001), -1.0, 1.0)
	return Vector2(v, u)


## On-screen width for a stroke of template width `w` (matches InkDrawing.draw on the golfer).
func _px_width(w: float) -> float:
	var avg := (_hw_units(0.0) + _hw_units(0.5) + _hw_units(1.0)) / 3.0
	var k := avg / 5.0 if target == "pants" else 0.9
	return w * k * _scale()


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_active = true
			_cur = PackedVector2Array([event.position])
			_line_start = event.position
			if tool == "eraser":
				_snapshot()
				_erase_at(event.position)
		else:
			if _active and tool != "eraser":
				_commit()
			_active = false
			_cur.clear()
		accept_event()
		queue_redraw()
	elif event is InputEventMouseMotion:
		_hover = event.position
		if _active:
			if tool == "eraser":
				_erase_at(event.position)
			elif tool == "line":
				_cur = PackedVector2Array([_line_start, event.position])
			elif _cur.is_empty() or _cur[_cur.size() - 1].distance_to(event.position) >= 2.0:
				_cur.append(event.position)
			accept_event()
		queue_redraw()


func _snapshot() -> void:
	_undo.append((drawing.strokes as Array).duplicate(true))
	if _undo.size() > 60:
		_undo.remove_at(0)
	_redo.clear()


func _commit() -> void:
	var line := _cur
	if line.size() == 1:
		line = PackedVector2Array([line[0], line[0] + Vector2(0.5, 0.5)])
	if tool == "line":
		line = InkCanvas.resample(line, 6.0)
	else:
		line = _smooth(line)
	if (drawing.strokes as Array).size() >= InkDrawing.MAX_STROKES or points_left() < line.size():
		return
	var p: Array = []
	for q in line:
		var tv := to_template(q)
		p.append(int(round((tv.x + 1.0) * 500.0)))
		p.append(int(round(tv.y * 1000.0)))
	_snapshot()
	var w := width * (2.2 if tool == "marker" else 1.0)
	var a := opacity * (0.55 if tool == "marker" else 1.0)
	(drawing.strokes as Array).append({"c": "#" + color.to_html(false), "w": snappedf(clampf(w, InkDrawing.MIN_W, InkDrawing.MAX_W), 0.1), "a": snappedf(a, 0.01), "p": p})
	changed.emit(drawing)


## Moving-average smoothing (strength from `smoothing`), then even resampling.
func _smooth(line: PackedVector2Array) -> PackedVector2Array:
	var passes := int(round(smoothing * 4.0))
	var pts := line
	for _i in passes:
		if pts.size() < 3:
			break
		var out := PackedVector2Array([pts[0]])
		for i in range(1, pts.size() - 1):
			out.append(pts[i - 1] * 0.25 + pts[i] * 0.5 + pts[i + 1] * 0.25)
		out.append(pts[pts.size() - 1])
		pts = out
	return InkCanvas.resample(pts, lerpf(3.0, 6.0, smoothing))


func _erase_at(p: Vector2) -> void:
	var strokes: Array = drawing.strokes
	var r := maxf(10.0, _px_width(width) * 1.5)
	var i := strokes.size() - 1
	var hit := false
	while i >= 0:
		var pp: Array = strokes[i].p
		for k in range(0, pp.size() - 1, 2):
			var q := to_screen(float(pp[k + 1]) / 1000.0, float(pp[k]) / 500.0 - 1.0)
			if q.distance_to(p) < r:
				strokes.remove_at(i)
				hit = true
				break
		i -= 1
	if hit:
		changed.emit(drawing)
		queue_redraw()


func undo() -> void:
	if _undo.is_empty():
		return
	_redo.append((drawing.strokes as Array).duplicate(true))
	drawing.strokes = _undo.pop_back()
	changed.emit(drawing)
	queue_redraw()


func redo() -> void:
	if _redo.is_empty():
		return
	_undo.append((drawing.strokes as Array).duplicate(true))
	drawing.strokes = _redo.pop_back()
	changed.emit(drawing)
	queue_redraw()


func clear_all() -> void:
	if (drawing.strokes as Array).is_empty():
		return
	_snapshot()
	drawing.strokes = []
	changed.emit(drawing)
	queue_redraw()


## Mirrors every stroke across the garment's centre line.
func mirror() -> void:
	if (drawing.strokes as Array).is_empty():
		return
	_snapshot()
	for s: Dictionary in drawing.strokes:
		var p: Array = s.p
		for k in range(0, p.size() - 1, 2):
			p[k] = 1000 - int(p[k])
	changed.emit(drawing)
	queue_redraw()


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	var cv := _cv
	var r := Rect2(Vector2.ZERO, size)
	cv.fill(InkStyleBox.outline_pts(r, 16.0, 1.0, 5.0), Color("fffdf8"))
	# Faint paper grid helps placing designs.
	var step := 28.0
	var x := step
	while x < size.x:
		cv.stroke(PackedVector2Array([Vector2(x, 6), Vector2(x, size.y - 6)]), 1.0, Color(0.1, 0.2, 0.5, 0.06), 0.0, 0.0)
		x += step
	# Garment template.
	var col := Color(str(look.topColor if target == "top" else look.pantsColor))
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for k in 25:
		var u := k / 24.0
		left.append(to_screen(u, -1.0))
		right.append(to_screen(u, 1.0))
	right.reverse()
	var shape := left + right
	cv.fill(shape, col)
	var mapper := func(u: float, v: float) -> Vector2: return to_screen(u, v)
	var k_w := _px_width(1.0)
	InkDrawing.draw(cv, drawing, mapper, k_w)
	if _active and _cur.size() >= 1 and tool != "eraser":
		var preview := _cur if tool == "line" else _cur
		var w := _px_width(width * (2.2 if tool == "marker" else 1.0))
		var a := opacity * (0.55 if tool == "marker" else 1.0)
		if preview.size() == 1:
			cv.dot(preview[0], w * 0.5, Color(color, a))
		else:
			cv.stroke(preview, w, Color(color, a), 0.08, 0.08, 1.0, 0.08, 0.0, 0.6)
	cv.outline(shape, 3.0, InkCanvas.INK, 2.0)
	# Labels for orientation.
	if _hover.x >= 0.0:
		var hr := _px_width(width * (2.2 if tool == "marker" else 1.0)) * 0.5
		if tool == "eraser":
			hr = maxf(10.0, _px_width(width) * 1.5)
		cv.ink_circle(_hover, Vector2(hr, hr), 1.4, Color(InkCanvas.INK, 0.6), 1.0, 0.0, 0.1, 0.0)
	cv.outline(InkStyleBox.outline_pts(r, 16.0, 1.0, 5.0), 2.6, InkCanvas.INK, 9.0)
	cv.flush(get_canvas_item())
	var f := UITheme.body_font()
	var top_label := "WAIST" if target == "pants" else "COLLAR"
	var bottom_label := "CUFF" if target == "pants" else "HEM"
	draw_string(f, Vector2(0, 30), top_label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, UITheme.MUTED)
	draw_string(f, Vector2(0, size.y - 14), bottom_label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, UITheme.MUTED)
