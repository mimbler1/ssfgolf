class_name OffscreenMarkers
extends Control
## Screen-edge markers for things the camera cannot see: every other player's ball (slot colour,
## pointing at it, with distance) and the cup. Read-only view of the match.

const INSET := 46.0

var view: MatchView
var camera: Camera2D
var _t := 0.0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if view == null or view.terrain == null or camera == null:
		return
	var xf := get_viewport().get_canvas_transform()
	# HUD space is the base canvas; the world canvas transform maps world -> same space.
	var rect := Rect2(Vector2.ZERO, size).grow(-INSET)
	var me: Dictionary = view.ball_state(view.local_slot)
	var my_pos: Vector2 = me.get("pos", Vector2.ZERO)
	for r in view.roster:
		var slot := int(r.slot)
		if slot == view.local_slot:
			continue
		var s := view.ball_state(slot)
		if s.is_empty() or not bool(s.get("active", false)) or bool(s.get("finished", false)):
			continue
		var p: Vector2 = xf * (s.pos as Vector2)
		if rect.grow(INSET * 0.6).has_point(p):
			continue
		var col: Color = UITheme.SLOT_COLORS[slot % UITheme.SLOT_COLORS.size()]
		_marker(rect, p, col, "%dm" % roundi(my_pos.distance_to(s.pos) / 40.0), str(r.name).left(1).to_upper())
	if view.terrain.has_cup:
		var cp: Vector2 = xf * view.terrain.cup_pos
		if not rect.grow(INSET * 0.6).has_point(cp):
			_marker(rect, cp, Color("ff4d6d"), "%dm" % roundi(my_pos.distance_to(view.terrain.cup_pos) / 40.0), "", true)


## A badge clamped to the screen edge with an arrow toward the target.
func _marker(rect: Rect2, target: Vector2, col: Color, label: String, letter: String, flag: bool = false) -> void:
	var center := rect.get_center()
	var dir := (target - center).normalized()
	# Intersect the ray from the centre with the inset rectangle.
	var tx := INF if absf(dir.x) < 0.0001 else ((rect.end.x if dir.x > 0.0 else rect.position.x) - center.x) / dir.x
	var ty := INF if absf(dir.y) < 0.0001 else ((rect.end.y if dir.y > 0.0 else rect.position.y) - center.y) / dir.y
	var at := center + dir * minf(tx, ty)
	var r := 20.0
	var tip := at + dir * (r + 12.0)
	var side := Vector2(-dir.y, dir.x)
	var arrow := PackedVector2Array([tip, at + dir * (r - 2.0) + side * 9.0, at + dir * (r - 2.0) - side * 9.0])
	draw_colored_polygon(Geometry2D.offset_polygon(arrow, 3.0)[0], UITheme.INK_LINE)
	draw_colored_polygon(arrow, col)
	draw_circle(at, r + 3.0, UITheme.INK_LINE)
	draw_circle(at, r, Color(UITheme.INK, 0.92))
	draw_arc(at, r - 2.0, 0, TAU, 24, col, 3.0)
	var f := UITheme.heading_font()
	if flag:
		draw_line(at + Vector2(-5, 9), at + Vector2(-5, -10), UITheme.PAPER, 3.0)
		draw_colored_polygon(PackedVector2Array([at + Vector2(-4, -10), at + Vector2(9, -5), at + Vector2(-4, 0)]), col)
	else:
		var w := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(f, at + Vector2(-w * 0.5, 7), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
	var lw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var lp := at - dir * (r + 14.0) + Vector2(-lw * 0.5, 5)
	draw_string_outline(f, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, UITheme.INK_LINE)
	draw_string(f, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UITheme.PAPER)
