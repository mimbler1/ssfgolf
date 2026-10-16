class_name MenuBackdrop
extends Node2D
## Living illustrated meadow behind the menus: parallax sky, a foreground hill with a
## flag, trees, and a big animated golfer who occasionally takes a swing.

signal golfer_clicked

var golfer: Golfer
var backdrop: Backdrop
var _terrain: SimTerrain
var _view: TerrainView
var _fx: FxLayer
var _t := 0.0
var _next_swing := 4.0
var _ball: _MenuBall
var _cam := Vector2.ZERO

const HILL := {
	"id": "menu_hill",
	"bounds": {"x": -1400, "y": -1200, "w": 2800, "h": 1800},
	"tee": {"x": -420, "y": 0},
	"terrain": [{"material": "grass", "smooth": true, "points": [
		[-1500, 40, {"c": true}], [-900, -10], [-560, -40], [-260, -30], [40, 30], [380, 70], [760, 40], [1100, -30], [1500, -60, {"c": true}],
		[1500, 900, {"c": true}], [-1500, 900, {"c": true}]]}],
	"zones": [],
	"decor": [
		{"type": "tree", "x": -880, "y": -10, "scale": 1.4},
		{"type": "bush", "x": -150, "y": -30, "scale": 1.3},
		{"type": "flowers", "x": -660, "y": -40, "scale": 1.2},
		{"type": "tree", "x": 980, "y": -20, "scale": 1.1},
		{"type": "flowers", "x": 560, "y": 60, "scale": 1.0},
		{"type": "bush", "x": 1250, "y": -50, "scale": 1.1},
	],
}


var with_golfer := true


func setup(theme: Dictionary, appearance: Dictionary, p_with_golfer: bool = true) -> void:
	with_golfer = p_with_golfer
	backdrop = Backdrop.new()
	add_child(backdrop)
	backdrop.setup(theme, 77)
	_terrain = SimTerrain.new()
	_terrain.build(HILL)
	_view = TerrainView.new()
	add_child(_view)
	_view.build(_terrain, HILL, theme, 1)
	# Hide the flag/cup from the decorative hill; it has no cup in view anyway.
	golfer = Golfer.new()
	golfer.set_appearance(appearance)
	golfer.scale = Vector2(3.0, 3.0)
	var hit := _terrain.raycast(Vector2(-470, -400), Vector2.DOWN, 1000)
	golfer.position = hit.pos if hit.hit else Vector2(-470, -30)
	add_child(golfer)
	_ball = _MenuBall.new()
	_ball.color = Color(appearance.get("ballColor", "#ffffff"))
	_ball.trail = Color(appearance.get("trailColor", "#ffd166"))
	add_child(_ball)
	_reset_ball()
	_fx = FxLayer.new()
	add_child(_fx)
	if not with_golfer:
		golfer.visible = false
		_ball.visible = false
		set_process_unhandled_input(false)


func set_appearance(a: Dictionary) -> void:
	golfer.set_appearance(a)
	_ball.color = Color(a.get("ballColor", "#ffffff"))
	_ball.trail = Color(a.get("trailColor", "#ffd166"))


func _reset_ball() -> void:
	var bx := golfer.position.x + golfer.ball_offset() * 3.0
	var hit := _terrain.raycast(Vector2(bx, golfer.position.y - 300), Vector2.DOWN, 800)
	_ball.pos = (hit.pos if hit.hit else Vector2(bx, golfer.position.y)) + Vector2(0, -21)
	_ball.vel = Vector2.ZERO
	_ball.flying = false
	_ball.trail_pts.clear()


func _process(delta: float) -> void:
	_t += delta
	var vs := get_viewport().get_visible_rect().size
	# Gentle camera drift; world origin sits slightly right of screen centre.
	_cam = Vector2(sin(_t * 0.05) * 220.0 + 80.0, -290 + sin(_t * 0.09) * 20.0)
	position = vs * 0.5 - _cam
	scale = Vector2.ONE * clampf(vs.y / 1080.0, 0.7, 2.0)
	backdrop.follow(_cam + Vector2(_t * 30.0, 0), 1.0)
	_next_swing -= delta
	if with_golfer and _next_swing <= 0.0 and golfer.anim in ["idle", "watch"]:
		_next_swing = randf_range(7.0, 11.0)
		_swing()
	if _ball.flying:
		_ball.vel.y += 900.0 * delta
		_ball.pos += _ball.vel * delta
		_ball.trail_pts.append(_ball.pos)
		if _ball.trail_pts.size() > 22:
			_ball.trail_pts.remove_at(0)
		if _ball.pos.y > 600.0 or _ball.pos.x > 2400.0:
			_ball.visible = false
			_ball.flying = false
			await get_tree().create_timer(1.2).timeout
			_reset_ball()
			_ball.visible = true
			_fx.poof(_ball.pos)
			golfer.play("idle")
	_ball.queue_redraw()


func _swing() -> void:
	golfer.aim_power = 0.0
	golfer.play("aim")
	var tw := create_tween()
	tw.tween_property(golfer, "aim_power", 0.9, 0.7).set_trans(Tween.TRANS_SINE)
	await tw.finished
	await get_tree().create_timer(0.25).timeout
	golfer.swing(0.9, "watch")
	await get_tree().create_timer(0.085).timeout
	Sfx.play("swing", -10.0)
	Sfx.play("hit", -8.0)
	_fx.shot_burst(_ball.pos, Vector2(1, -0.7).normalized(), 0.8)
	_ball.vel = Vector2(randf_range(900, 1150), randf_range(-900, -760))
	_ball.flying = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local := to_local(get_global_mouse_position())
		if local.distance_to(golfer.position + Vector2(0, -110)) < 120.0:
			golfer.play(["celebrate", "wave", "dance"][randi() % 3])
			Sfx.play("pop", -6.0)
			golfer_clicked.emit()
			await get_tree().create_timer(2.2).timeout
			golfer.play("idle")


class _MenuBall extends Node2D:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var flying := false
	var color := Color.WHITE
	var trail := Color.YELLOW
	var trail_pts: PackedVector2Array = PackedVector2Array()

	var _cv := InkCanvas.new()

	func _draw() -> void:
		var r := 21.0
		if trail_pts.size() > 3:
			_cv.stroke(InkCanvas.spline(trail_pts, 2), r * 1.6, Color(trail, 0.6), 0.95, 0.02, 1.0, 0.0, 0.0, 0.0)
		_cv.ellipse(pos, Vector2(r, r), color)
		_cv.crescent(pos, r * 0.97, Vector2(-r * 0.26, -r * 0.24), color.darkened(0.16))
		for k in 3:
			var a := pos.x * 0.05 + TAU * k / 3.0
			_cv.stroke(InkCanvas.arc_pts(pos + Vector2(cos(a), sin(a)) * r * 0.52, r * 0.16, a + 1.2, a + 2.6, 4), 2.2, color.darkened(0.32), 0.2, 0.2)
		_cv.ink_circle(pos, Vector2(r, r), 4.6, InkCanvas.INK, 2.0)
		_cv.flush(get_canvas_item())
