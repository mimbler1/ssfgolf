extends Node2D
## Gameplay scene used by both offline practice and online matches.
## Router.params:
##   practice: {mode: "practice", course: String, hole: int, lab: bool}
##   online:   {mode: "online", host, port, token, matchId, queueMode: "quick"|"private", roomCode}

const AIM_DEADZONE := 14.0
const GOLFER_SCALE := 1.3
const EMOTE_COOLDOWN := 1.5   ## Mirrors the server's cooldown so spam never looks like lost input.
const PLACE_TEXT := ["1ST!", "2ND!", "3RD!", "4TH"]
const PLACE_COLORS := [Color("ffd166"), Color("d9e2f2"), Color("f4a261"), Color("aab3e0")]

var view: MatchView
var params: Dictionary
var world: Node2D
var backdrop: Backdrop
var terrain_view: TerrainView
var golfer_layer: Node2D
var ball_layer: Node2D
var fx: FxLayer
var trajectory: TrajectoryView
var camera: Camera2D
var hud: GameHud
var hud_layer: CanvasLayer
var overlay_layer: CanvasLayer

var balls: Dictionary = {}      ## slot -> BallView
var golfers: Dictionary = {}    ## slot -> Golfer
var _golfer_state: Dictionary = {}  ## slot -> {shown: bool, swing_until: float, pos: Vector2}
var _bubbles: Dictionary = {}   ## slot -> {node: Control, until: float}
var _wheel: EmoteWheel
var _last_emote := -10.0

## Shot input for both control styles (Blitz drag / Classic meter); see ShotController.
var shot := ShotController.new()
var aim_view: AimView
## True while the aim arrow is up (Blitz: dragging; Classic: the ball is ready to aim).
var _aiming := false
## In-flight spin key currently held (-1, 0, +1).
var _spin_held := 0
## Which page of balls the number keys select (pages of six).
var _ability_page := 0
## Practice-only debug overlay of the flight path (never available online).
var _debug_traj := false
var _queued_shot: Dictionary = {}
var _selected := "standard"
var _last_local_swing := -10.0
var _user_zoom := 1.0
var _cam_zoom := 1.0
var _shake := 0.0
var _last_countdown := -1
var _overlay: Control
var _menu_open := false
var _match_over := false
var _clock := 0.0
var _spectate_slot := -1
var _pending_predict := false
var _last_predict_key := ""
var _backdrop_theme_key := "-"
var _results_overlay: Control
var _dev_aim: Vector2 = Vector2(-1, -1)  ## Developer screenshot hook: (angle, power)
var _dev_overview := OS.get_cmdline_user_args().has("--dev-overview")


func _ready() -> void:
	params = Router.params
	var dcs := OS.get_cmdline_user_args().find("--dev-controls")
	if dcs != -1 and dcs + 1 < OS.get_cmdline_user_args().size():
		Settings.values.gameplay.control_style = OS.get_cmdline_user_args()[dcs + 1]  # dev only, not saved
	RenderingServer.set_default_clear_color(Color("1b2040"))
	_build_layers()
	if str(params.get("mode", "practice")) == "online":
		var nv := NetMatchView.new()
		view = nv
		add_child(nv)
		nv.welcomed.connect(_on_welcomed)
		nv.connection_lost.connect(_on_connection_lost)
		_hook_view()
		_show_connecting()
		nv.connect_to(str(params.host), int(params.port), str(params.token), str(params.matchId))
	else:
		var lv := LocalMatchView.new()
		view = lv
		add_child(lv)
		_hook_view()
		var app := Appearance.normalize(_local_appearance())
		var pname := str(Backend.profile.get("displayName", "You"))
		var dbl := OS.get_cmdline_user_args().find("--dev-blitz")
		if dbl != -1 or params.has("dev_blitz"):
			var nb := int(params.dev_blitz) if params.has("dev_blitz") else int(OS.get_cmdline_user_args()[dbl + 1])
			lv.setup_local_blitz(str(params.get("course", GameData.POOL_ID)), nb, app, pname)
			var dpts := OS.get_cmdline_user_args().find("--dev-points")
			if dpts != -1:
				var vals := OS.get_cmdline_user_args()[dpts + 1].split(",")
				for i in mini(vals.size(), lv.sim.players.size()):
					lv.sim.players[i].points = int(vals[i])
		elif str(params.get("mode", "practice")) == "stroke":
			lv.setup_stroke(str(params.get("course", "golf_land")), int(params.get("hole", 0)), app, pname, bool(params.get("clean", false)))
		else:
			lv.setup_practice(str(params.get("course", "golf_land")), int(params.get("hole", 0)), app, pname)
		_on_welcomed()


func _local_appearance() -> Dictionary:
	var app: Dictionary = Backend.profile.get("appearance", Appearance.DEFAULT) if not Backend.profile.is_empty() else LocalStore.appearance()
	var args := OS.get_cmdline_user_args()
	var dc := args.find("--dev-character")
	if dc != -1 and dc + 1 < args.size():
		app = app.duplicate()
		app.character = args[dc + 1]
	return app


func _hook_view() -> void:
	view.game_event.connect(_on_event)
	view.hole_loaded.connect(_on_hole_loaded)
	view.impacts.connect(_on_impacts)


func _build_layers() -> void:
	backdrop = Backdrop.new()
	add_child(backdrop)
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	terrain_view = TerrainView.new()
	world.add_child(terrain_view)
	golfer_layer = Node2D.new()
	world.add_child(golfer_layer)
	ball_layer = Node2D.new()
	world.add_child(ball_layer)
	trajectory = TrajectoryView.new()
	world.add_child(trajectory)
	aim_view = AimView.new()
	aim_view.visible = false
	world.add_child(aim_view)
	fx = FxLayer.new()
	world.add_child(fx)
	camera = Camera2D.new()
	camera.zoom = Vector2(_cam_zoom, _cam_zoom)
	world.add_child(camera)
	camera.make_current()
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 20
	add_child(overlay_layer)


func _on_welcomed() -> void:
	_hide_overlay()
	var ctheme: Dictionary = view.course.get("theme", {})
	backdrop.setup(ctheme, hash(view.course_id))
	_backdrop_theme_key = str(ctheme.get("id", "")) + str(ctheme.get("art", ""))
	hud = GameHud.new()
	hud_layer.add_child(hud)
	hud.setup(view)
	hud.ability_clicked.connect(_select_ability)
	hud.menu_pressed.connect(_toggle_menu)
	for r in view.roster:
		var slot := int(r.slot)
		var app: Dictionary = r.appearance
		var g := Golfer.new()
		g.set_appearance(app)
		g.scale = Vector2(GOLFER_SCALE, GOLFER_SCALE)
		g.visible = false
		golfer_layer.add_child(g)
		golfers[slot] = g
		_golfer_state[slot] = {"shown": false, "swing_until": -1.0}
		var bv := BallView.new()
		bv.slot = slot
		bv.radius = float(GameData.balance.physics.ball_radius)
		bv.ball_color = Color(app.get("ballColor", "#ffffff"))
		bv.trail_color = Color(app.get("trailColor", "#ffd166"))
		bv.slot_color = UITheme.SLOT_COLORS[slot % UITheme.SLOT_COLORS.size()]
		bv.display_name = str(r.name)
		bv.is_local = slot == view.local_slot
		ball_layer.add_child(bv)
		balls[slot] = bv
	if view.terrain:
		_on_hole_loaded(view.hole_index, view.hole_number)
	if view.mode == "practice":
		_build_practice_panel()
	var args := OS.get_cmdline_user_args()
	var de := args.find("--dev-emote")
	if de != -1 and de + 1 < args.size():
		await get_tree().create_timer(1.6).timeout
		_send_emote(int(args[de + 1]))
	if args.has("--dev-wheel"):
		await get_tree().create_timer(1.6).timeout
		_open_emote_wheel()
		_wheel._update_hover(_wheel.center + Vector2(80, -40))
	var di := args.find("--dev-aim")
	if di != -1 and di + 1 < args.size():
		var parts := args[di + 1].split(",")
		_dev_aim = Vector2(float(parts[0]), float(parts[1]))
		var dab := args.find("--dev-ability")
		if dab != -1 and dab + 1 < args.size():
			_selected = args[dab + 1]
			hud.selected_ability = _selected
		var dsp := args.find("--dev-spin")
		if dsp != -1 and dsp + 1 < args.size():
			shot.spin = float(args[dsp + 1])
		await get_tree().create_timer(1.2).timeout
		shot.aiming = true


func _on_hole_loaded(index: int, number: int) -> void:
	var hole: Dictionary = view.course.holes[index]
	var theme := GameData.hole_theme(view.course, hole)
	terrain_view.build(view.terrain, hole, theme, (number if view.mode == "online" else index) + 1)
	# Pool matches change world between holes: rebuild the backdrop only when the theme changes.
	var tkey := str(theme.get("id", "")) + str(theme.get("art", ""))
	if tkey != _backdrop_theme_key:
		_backdrop_theme_key = tkey
		backdrop.setup(theme, hash(str(hole.get("course_id", view.course_id))))
	for slot: int in balls:
		balls[slot].terrain = view.terrain
		balls[slot].clear_trail()
	fx.clear_persistent()
	for slot: int in golfers:
		golfers[slot].visible = false
		_golfer_state[slot].shown = false
	_cancel_aim()
	var me0 := view.ball_state(view.local_slot)
	shot.reset_for_hole(view.terrain.cup_pos.x - (me0.get("pos", view.terrain.tee) as Vector2).x)
	var bd := view.terrain.bounds
	camera.limit_left = int(bd.position.x - 400)
	camera.limit_right = int(bd.end.x + 400)
	camera.limit_top = int(bd.position.y - 600)
	camera.limit_bottom = int(bd.end.y + 120)
	var label := ""
	if view.mode == "online":
		label = "First to %d" % view.target_points
	elif view.mode == "stroke":
		label = "Par %d" % int(hole.get("par", 3))
	if hud:
		hud.set_hole(number if view.mode == "online" else index, str(hole.get("name", "")), label)
	_spectate_slot = -1
	var bs := view.ball_state(view.local_slot)
	if not bs.is_empty():
		camera.position = bs.pos
		camera.reset_smoothing()
	_last_countdown = -1


# ---------------------------------------------------------------------------
# Frame update
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	if view == null or view.terrain == null or hud == null:
		return
	var ph := view.phase_state()
	_update_countdown(ph)
	var t0 := PerfStat.begin()
	for slot: int in balls:
		_update_ball(slot, delta)
	PerfStat.end("scene.update_balls", t0)
	t0 = PerfStat.begin()
	_update_camera(delta)
	_update_bubbles()
	_update_controls(delta)
	PerfStat.end("scene.camera_controls", t0)
	if not _queued_shot.is_empty():
		if view.local_shot_block() == "":
			view.shoot(_queued_shot.angle, _queued_shot.power, _queued_shot.ability, _queued_shot.spin)
			_after_local_shot(_queued_shot.power)
			_queued_shot = {}
		elif _clock > float(_queued_shot.expires):
			_queued_shot = {}
	t0 = PerfStat.begin()
	backdrop.follow(camera.get_screen_center_position(), camera.zoom.x)
	PerfStat.end("scene.backdrop", t0)


func _update_countdown(ph: Dictionary) -> void:
	if int(ph.phase) == MatchSim.Phase.COUNTDOWN and view.mode == "online":
		var n := int(ceil(float(ph.timer)))
		if n != _last_countdown and n > 0 and n <= 3:
			_last_countdown = n
			hud.announce(str(n), UITheme.PAPER, 150, 0.35)
			Sfx.play("countdown_tick")


func _update_ball(slot: int, _delta: float) -> void:
	var bv: BallView = balls[slot]
	var s := view.ball_state(slot)
	if s.is_empty():
		return
	bv.position = s.pos
	bv.rot = float(s.rot)
	bv.ability = str(s.ability)
	bv.visible_ball = bool(s.active) and not bool(s.finished)
	bv.finished = bool(s.finished)
	bv.disconnected = bool(s.forfeited)
	# Hide name tags while balls are bunched up (the tee); the HUD panels identify players there.
	var crowded := false
	for other: int in balls:
		if other != slot and balls[other].visible_ball and (balls[other].position as Vector2).distance_to(s.pos) < 46.0:
			crowded = true
			break
	bv.show_name = not crowded or (s.vel as Vector2).length() > 120.0
	bv.shield = bool(s.get("shield", false))
	bv.iced = bool(s.get("ice", false))
	bv.anti_grav = bool(s.get("anti_grav", false))
	bv.magnet = bool(s.get("magnet", false))
	var speed: float = s.vel.length()
	bv.moving = speed > 40.0 and bool(s.active)
	if slot == view.local_slot:
		var ps := view.player_state(slot)
		var cd := float(ps.get("cooldown", 0.0))
		bv.cooldown_frac = clampf(cd / float(GameData.balance.shot.cooldown), 0.0, 1.0)
		bv.ready_to_shoot = view.local_shot_block() == ""
	_update_golfer(slot, s, speed)


func _update_golfer(slot: int, s: Dictionary, speed: float) -> void:
	var g: Golfer = golfers[slot]
	var st: Dictionary = _golfer_state[slot]
	var swinging := _clock < float(st.swing_until)
	if swinging:
		return
	var settled := bool(s.active) and not bool(s.finished) and (bool(s.at_rest) or (bool(s.grounded) and speed < 35.0))
	var on_floor := true
	var ground := Vector2.ZERO
	if settled:
		var facing := 1.0
		if slot == view.local_slot and _aiming:
			facing = 1.0 if cos(shot.angle) >= 0.0 else -1.0
		else:
			facing = 1.0 if view.terrain.cup_pos.x >= s.pos.x else -1.0
		var gx: float = s.pos.x - facing * Golfer.BALL_OFFSET * GOLFER_SCALE
		var hit := view.terrain.raycast(Vector2(gx, s.pos.y - 70.0), Vector2.DOWN, 160.0)
		on_floor = hit.hit and hit.normal.y < -0.5 and not bool(s.stuck)
		if on_floor:
			ground = hit.pos
			g.facing = facing
	if settled and on_floor:
		if not st.shown:
			st.shown = true
			g.visible = true
			g.position = ground
			g.modulate.a = 0.0
			create_tween().tween_property(g, "modulate:a", 1.0, 0.18)
			fx.poof(ground + Vector2(0, -30))
		else:
			g.position = g.position.lerp(ground, 0.5)
		if slot == view.local_slot and _aiming:
			g.aim_power = shot.shot_power()
			g.play("aim")
		elif not g.is_performing():
			g.play("idle")
	elif st.shown and g.anim != "celebrate":
		st.shown = false
		var tw := create_tween()
		tw.tween_property(g, "modulate:a", 0.0, 0.2)
		tw.tween_callback(func() -> void: g.visible = false)


func _update_camera(delta: float) -> void:
	var target := camera.position
	var follow := view.local_slot
	var me := view.ball_state(view.local_slot)
	if me.get("finished", false) or me.get("forfeited", false):
		follow = _pick_spectate()
	var s := view.ball_state(follow)
	if not s.is_empty():
		var vel: Vector2 = s.vel
		target = s.pos + (vel * 0.22).limit_length(320.0) + Vector2(0, -150)
		if not s.active and view.terrain.has_cup and s.finished:
			target = view.terrain.cup_pos
	var want_zoom := _user_zoom
	if _aiming:
		target += Vector2.from_angle(shot.angle) * shot.shot_power() * 260.0
		want_zoom = _user_zoom * lerpf(1.0, 0.82, shot.shot_power())
	if Input.is_action_pressed("camera_overview") or _dev_overview:
		var bd := view.terrain.bounds
		var vs := get_viewport().get_visible_rect().size
		target = bd.get_center() + Vector2(0, bd.size.y * 0.12)
		want_zoom = clampf(minf(vs.x / (bd.size.x + 200.0), vs.y / (bd.size.y * 0.75)), 0.25, 1.0)
	var k := 1.0 - exp(-delta * 5.0)
	camera.position = camera.position.lerp(target, k)
	_cam_zoom = lerpf(_cam_zoom, want_zoom, 1.0 - exp(-delta * 4.0))
	camera.zoom = Vector2(_cam_zoom, _cam_zoom)
	if _shake > 0.0:
		var amt := _shake * 14.0 * float(Settings.get_value("gameplay", "screen_shake"))
		camera.offset = Vector2(randf_range(-amt, amt), randf_range(-amt, amt))
		_shake = maxf(0.0, _shake - delta * 2.5)
	else:
		camera.offset = Vector2.ZERO


func _pick_spectate() -> int:
	if _spectate_slot >= 0:
		var s := view.ball_state(_spectate_slot)
		if not s.is_empty() and s.active and not s.finished:
			return _spectate_slot
	for r in view.roster:
		var slot := int(r.slot)
		var s2 := view.ball_state(slot)
		if slot != view.local_slot and not s2.is_empty() and s2.active and not s2.finished:
			_spectate_slot = slot
			return slot
	return view.local_slot


# ---------------------------------------------------------------------------
# Input & aiming
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if view == null or view.terrain == null or _menu_open:
		if event.is_action_pressed("pause_menu"):
			_toggle_menu()
		return
	var classic := shot.style == "classic"
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not classic:
			if mb.pressed:
				_begin_aim(mb.position)
			elif shot.aiming:
				_release_aim()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_user_zoom = clampf(_user_zoom * 1.1, 0.4, 1.5)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_user_zoom = clampf(_user_zoom / 1.1, 0.4, 1.5)
	var cancellable := (shot.aiming and not classic) or shot.meter_on
	if event.is_action_pressed("cancel_aim") and cancellable:
		_cancel_aim()
		Sfx.play("ui_back", -6.0)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause_menu"):
		if _wheel:
			_wheel.cancel()
		elif cancellable:
			_cancel_aim()
		else:
			_toggle_menu()
		return
	# Swing (classic) and the mid-flight ability share a key: the swing wins while the ball can
	# be hit, the ability while it is flying.
	if classic and event.is_action_pressed("swing") and not event.is_echo() and _classic_swing():
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("activate_ability") and not event.is_echo():
		var s := view.ball_state(view.local_slot)
		if s.get("manual", false):
			view.activate()
	elif event.is_action_pressed("reset_ball"):
		view.reset_ball()
	elif event.is_action_pressed("zoom_in"):
		_user_zoom = clampf(_user_zoom * 1.15, 0.4, 1.5)
	elif event.is_action_pressed("zoom_out"):
		_user_zoom = clampf(_user_zoom / 1.15, 0.4, 1.5)
	elif event.is_action_pressed("camera_recenter"):
		_user_zoom = 1.0
		_spectate_slot = -1
	elif event.is_action_pressed("scoreboard"):
		_show_scoreboard(true)
	elif event.is_action_released("scoreboard"):
		_show_scoreboard(false)
	elif event.is_action_pressed("ability_page") and not event.is_echo():
		var pages := maxi(1, ceili(_ability_order().size() / 6.0))
		_ability_page = (_ability_page + 1) % pages
		hud.set_page(_ability_page)
		Sfx.play("ui_select", -8.0)
	# Spin: before the shot the keys set launch spin; in flight, holding them spins the ball.
	for pair: Array in [["spin_top", 1], ["spin_back", -1]]:
		if event.is_action_pressed(pair[0]) and not event.is_echo():
			if _local_airborne():
				_spin_held = pair[1]
				view.spin(pair[1])
			else:
				shot.adjust_spin(pair[1])
				Sfx.play("ui_select", -10.0, 1.0 + shot.spin * 0.2)
		elif event.is_action_released(pair[0]) and _spin_held == int(pair[1]):
			_spin_held = 0
			view.spin(0)
	for i in 6:
		if event.is_action_pressed("ability_%d" % (i + 1)):
			var ids := _ability_order()
			var idx := _ability_page * 6 + i
			if idx < ids.size():
				_select_ability(ids[idx])
	for i in Emotes.count():
		if event.is_action_pressed("emote_%d" % (i + 1)):
			_send_emote(i)
	if event.is_action_pressed("emote_wheel") and not event.is_echo():
		_open_emote_wheel()
	elif event.is_action_released("emote_wheel") and _wheel:
		_wheel.confirm()


func _open_emote_wheel() -> void:
	if _wheel or _match_over:
		return
	if shot.aiming or shot.meter_on:
		_cancel_aim()
	_wheel = EmoteWheel.new()
	_wheel.appearance = Appearance.normalize(_local_appearance())
	hud_layer.add_child(_wheel)
	_wheel.open_at(get_viewport().get_mouse_position())
	_wheel.chosen.connect(_send_emote)
	_wheel.closed.connect(func() -> void: _wheel = null)


func _send_emote(index: int) -> void:
	if _clock - _last_emote < EMOTE_COOLDOWN:
		return
	_last_emote = _clock
	view.emote(index)


func _ability_order() -> Array[String]:
	var out: Array[String] = []
	for a: Dictionary in GameData.abilities:
		if view.allowed_abilities.has(a.id):
			out.append(str(a.id))
	return out


func _select_ability(id: String) -> void:
	var def := GameData.ability(id)
	if def.is_empty():
		return
	if id != "standard" and _selected != id:
		var ps := view.player_state(view.local_slot)
		if view.mode == "stroke":
			if int((ps.get("charges", {}) as Dictionary).get(id, 0)) <= 0:
				hud.toast("No %s left this round" % def.name, UITheme.CORAL)
				Sfx.play("ui_deny", -4.0)
				return
		elif float(ps.get("energy", 0.0)) + 0.0001 < float(def.cost):
			hud.toast("Not enough energy for %s" % def.name, UITheme.CORAL)
			Sfx.play("ui_deny", -4.0)
			return
	_selected = id if _selected != id else "standard"
	hud.selected_ability = _selected
	Sfx.play("ui_select", -6.0, 1.0 + GameData.ability_index(_selected) * 0.03)
	_pending_predict = true


func _local_airborne() -> bool:
	var s := view.ball_state(view.local_slot)
	return not s.is_empty() and bool(s.get("active", false)) and not bool(s.get("grounded", true)) and not bool(s.get("finished", false))


## The local ball can be aimed: on the ground, in play, not finished.
func _local_ready_to_aim() -> bool:
	var block := view.local_shot_block()
	return block in ["", "cooldown"] and not _match_over and not _menu_open and _wheel == null


func _begin_aim(screen_pos: Vector2) -> void:
	var block := view.local_shot_block()
	if block in ["finished", "not_playing"] or _match_over:
		return
	shot.begin_drag(screen_pos)
	Sfx.play("aim_start", -10.0)


## Classic Swing key: first press starts the meter, the second hits. Returns true if handled.
func _classic_swing() -> bool:
	if not shot.meter_on:
		if not _local_ready_to_aim():
			return false
		shot.start_meter()
		Sfx.play("aim_start", -8.0)
		return true
	var power := shot.shot_power()
	shot.meter_on = false
	_fire(shot.angle, power)
	return true


## Per-frame control update: aim keys, the meter, putting profile, arrow and laser guide.
func _update_controls(delta: float) -> void:
	var style := str(Settings.get_value("gameplay", "control_style"))
	if style != shot.style:
		_cancel_aim()
		shot.style = style if style in ["blitz", "classic"] else "blitz"
	var s := view.ball_state(view.local_slot)
	var ready := not s.is_empty() and bool(s.get("active", false)) and _local_ready_to_aim()
	# Putting: on the ground, close to the cup and roughly level with it.
	var cup := view.terrain.cup_pos
	var bpos: Vector2 = s.get("pos", Vector2.ZERO)
	shot.putting = view.terrain.has_cup and ready and absf(cup.x - bpos.x) < ShotController.PUTT_RANGE and absf(cup.y - bpos.y) < 150.0
	var changed := false
	if _dev_aim.y >= 0.0:
		shot.angle = _dev_aim.x
		shot.power = _dev_aim.y
		changed = true
	elif shot.style == "classic":
		shot.aiming = ready or shot.meter_on
		if shot.aiming:
			changed = shot.classic_aim(delta, Input.is_action_pressed("aim_left"), Input.is_action_pressed("aim_right"),
				Input.is_action_just_pressed("aim_left"), Input.is_action_just_pressed("aim_right"))
			shot.classic_meter(delta)
			changed = changed or shot.meter_on
	elif shot.aiming:
		var dist := float(Settings.get_value("gameplay", "aim_distance"))
		var pull := str(Settings.get_value("gameplay", "aim_mode")) == "pull"
		changed = shot.update_drag(get_viewport().get_mouse_position(), dist, pull)
	_aiming = shot.aiming
	# Arrow.
	var show_arrow := shot.aiming and not s.is_empty() and bool(s.get("active", false))
	if shot.style == "blitz" and not shot.drag_long_enough(get_viewport().get_mouse_position()) and _dev_aim.y < 0.0:
		show_arrow = false
	aim_view.visible = show_arrow
	if show_arrow:
		aim_view.ball_pos = bpos
		aim_view.ball_radius = float(GameData.balance.physics.ball_radius)
		aim_view.angle = shot.angle
		aim_view.power = shot.power
		aim_view.shot_power = shot.shot_power()
		aim_view.spin = shot.spin
		aim_view.putting = shot.putting
		aim_view.meter = shot.meter_on
		aim_view.classic = shot.style == "classic"
		aim_view.color = Color(GameData.ability(_selected).get("color", "#ffffff"))
		aim_view.blocked = view.local_shot_block() != ""
	# Flight-path guide: Laser Ball only (or the practice debug overlay).
	var guide := _guide_style()
	if show_arrow and guide != "" and (changed or _pending_predict or guide + _selected + str(shot.spin) != _last_predict_key):
		_pending_predict = false
		_last_predict_key = guide + _selected + str(shot.spin)
		_predict(guide)
	elif not show_arrow or guide == "":
		trajectory.clear()
		_last_predict_key = ""


## "laser" when the selected ball grants the aiming guide, "debug" for the practice overlay, else "".
func _guide_style() -> String:
	if str(GameData.ability(_selected).get("assist", "")) == "trajectory":
		return "laser"
	if _debug_traj and view.mode == "practice":
		return "debug"
	return ""


func _predict(guide: String) -> void:
	var s := view.ball_state(view.local_slot)
	if s.is_empty() or not s.active:
		trajectory.clear()
		return
	var bal := view.balance if not view.balance.is_empty() else GameData.balance
	var def := GameData.ability(_selected)
	var speed := MatchSim.launch_speed(bal, shot.shot_power())
	if _selected == "super":
		speed *= float(def.params.power_scale)
	var vel := Vector2.from_angle(shot.angle) * speed
	var r := float(bal.physics.ball_radius)
	var params: Dictionary = def.get("params", {})
	var max_t := float(params.get("guide_time", 3.0)) if guide == "laser" else 6.0
	var after := float(params.get("after_contact", 0.25)) if guide == "laser" else 1.2
	var res := SimPhysics.predict(view.terrain, bal.physics, GameData.materials, s.pos, vel, r, 1.0, max_t, after, 2,
		MatchSim.launch_spin(bal, vel, shot.spin, r), func(b: SimBall) -> void: MatchSim.apply_ability(b, def), view.terrain.cup_pos)
	trajectory.set_path(res.points, res.contact_index, shot.shot_power(), Color(def.get("color", "#ffffff")), res.hazard, guide)


func _release_aim() -> void:
	var long_enough := shot.drag_long_enough(get_viewport().get_mouse_position())
	var power := shot.shot_power()
	var angle := shot.angle
	_cancel_aim()
	if not long_enough or power <= 0.01:
		return
	_fire(angle, power)


## Sends a shot (or queues it if the cooldown is about to end). Shared by both control styles.
func _fire(angle: float, power: float) -> void:
	var block := view.local_shot_block()
	if block == "":
		view.shoot(angle, power, _selected, shot.spin)
		_after_local_shot(power)
	elif block == "cooldown":
		var cd := float(view.player_state(view.local_slot).get("cooldown", 0.0))
		if cd < 0.4:
			_queued_shot = {"angle": angle, "power": power, "ability": _selected, "spin": shot.spin, "expires": _clock + 0.6}
			shot.after_shot()
		else:
			hud.toast("Recharging…", UITheme.MUTED)
			Sfx.play("ui_deny", -8.0)
	elif block == "airborne":
		hud.toast("Wait until your ball lands", UITheme.MUTED)
		Sfx.play("ui_deny", -8.0)


func _after_local_shot(power: float) -> void:
	var g: Golfer = golfers.get(view.local_slot)
	if g and g.visible:
		g.swing(power, "watch")
		_golfer_state[view.local_slot].swing_until = _clock + 0.55
	_last_local_swing = _clock
	shot.after_shot()
	if _selected != "standard":
		_selected = "standard"
		hud.selected_ability = _selected
	hud.hide_hint()


func _cancel_aim() -> void:
	shot.cancel()
	_aiming = shot.aiming
	aim_view.visible = false
	trajectory.clear()
	_last_predict_key = ""


# ---------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------

func _on_event(ev: Dictionary) -> void:
	if hud == null:
		return
	var slot := int(ev.get("slot", -1))
	var is_me := slot == view.local_slot
	match str(ev.type):
		"intro":
			hud.announce(str(view.course.get("name", "")).to_upper(), UITheme.SUN, 96, 1.6)
			Sfx.play("whoosh")
		"go":
			if view.mode == "online":
				hud.announce("GO!", Color("80ed99"), 170, 0.35)
				Sfx.play("countdown_go")
		"shot":
			var power := float(ev.get("power", 0.5))
			var vel: Vector2 = ev.vel
			Sfx.play("swing", -6.0 + power * 4.0, randf_range(0.95, 1.08))
			Sfx.play("hit", -4.0 + power * 5.0, lerpf(1.15, 0.9, power))
			fx.shot_burst(ev.pos, vel.normalized(), power)
			if balls.has(slot):
				balls[slot].clear_trail()
			if not is_me or _clock - _last_local_swing > 0.8:
				var g: Golfer = golfers.get(slot)
				if g and g.visible:
					g.facing = 1.0 if vel.x >= 0.0 else -1.0
					g.swing(power, "watch")
					_golfer_state[slot].swing_until = _clock + 0.55
		"ability":
			var ab := str(ev.ability)
			if ab == "nitro":
				fx.nitro_burst(ev.pos, (ev.vel as Vector2).normalized())
				balls[slot].boosted = 0.7
				Sfx.play("nitro")
				_shake = maxf(_shake, 0.15)
			elif ab == "air_brake":
				fx.brake_puff(ev.pos)
				balls[slot].braked = 1.1
				Sfx.play("air_brake")
			elif ab == "zig_zag":
				fx.impact_ring(ev.pos, Color("c77dff"), 30.0)
				fx.sparkle(ev.pos, Color("c77dff"), 8)
				Sfx.play("whoosh", -4.0, 1.3)
			elif ab == "mulligan":
				fx.poof(ev.get("from", ev.pos))
				fx.poof(ev.pos)
				Sfx.play("whoosh", -2.0, 0.8)
				if balls.has(slot):
					balls[slot].clear_trail()
				if is_me:
					hud.toast("Mulligan! Take it again", Color("c9a227"))
		"freeze":
			fx.ice_patch(ev.pos)
			Sfx.play("clink_ice")
		"shield_block":
			fx.splash(ev.pos)
			fx.impact_ring(ev.pos, Color("5aa9ff"), 40.0)
			Sfx.play("boing", -4.0)
			if is_me:
				hud.toast("Shield saved you!", Color("5aa9ff"))
		"explode":
			fx.explosion(ev.pos, float(ev.radius))
			Sfx.play("explosion")
			var me := view.ball_state(view.local_slot)
			var d := (me.get("pos", Vector2.ZERO) as Vector2).distance_to(ev.pos)
			_shake = maxf(_shake, clampf(1.0 - d / 900.0, 0.15, 0.9))
			if is_me and (ev.hits as Array).size() > 1:
				hud.toast("Boom! Hit %d" % ((ev.hits as Array).size() - 1), Color("80ed99"))
		"stick":
			fx.goo(ev.pos)
			Sfx.play("squish")
		"hazard":
			var kind := str(ev.kind)
			if kind == "water":
				fx.splash(ev.pos)
				Sfx.play("splash")
			elif kind == "lava":
				fx.lava_splash(ev.pos)
				Sfx.play("sizzle")
			else:
				fx.poof(ev.pos)
				Sfx.play("whoosh", -6.0)
			if is_me:
				hud.toast({"water": "Splash! Back to your last spot", "lava": "Toasty! Back to your last spot", "oob": "Out of bounds!"}.get(kind, "Hazard!"), Color("4cc9f0"))
		"respawn":
			fx.poof(ev.pos)
			if balls.has(slot):
				balls[slot].clear_trail()
		"holed":
			var place := int(ev.place)
			fx.confetti(view.terrain.cup_pos + Vector2(0, -10), 80 if place == 1 else 40)
			Sfx.play("cup")
			_shake = maxf(_shake, 0.12)
			var g2: Golfer = golfers.get(slot)
			if g2:
				var facing := -1.0 if view.terrain.cup_pos.x > view.terrain.bounds.get_center().x else 1.0
				var gp := view.terrain.cup_pos + Vector2(facing * -60.0, 0)
				var hit := view.terrain.raycast(gp + Vector2(0, -120), Vector2.DOWN, 300.0)
				if hit.hit:
					g2.position = hit.pos + Vector2(float(slot) * 18.0 * facing, 0)
				g2.facing = -facing
				g2.visible = true
				g2.modulate.a = 1.0
				g2.play("celebrate")
				_golfer_state[slot].shown = true
			if is_me:
				if view.mode == "online":
					hud.announce(PLACE_TEXT[clampi(place - 1, 0, 3)], PLACE_COLORS[clampi(place - 1, 0, 3)], 150, 1.0)
				elif view.mode == "stroke":
					var par := int(view.course.holes[view.hole_index].get("par", 3))
					var strokes := int(ev.get("strokes", ev.get("shots", 0)))
					hud.announce(_score_name(strokes, par), UITheme.SUN if strokes <= par else UITheme.PAPER, 110, 1.0)
					if bool(ev.get("swish", false)):
						hud.toast("SWISH! Straight in without a bounce", Color("80ed99"))
				else:
					var shots := int(ev.get("shots", 0))
					hud.announce("HOLED IN %d!" % shots if shots > 1 else "HOLE IN ONE!", UITheme.SUN, 110, 1.0)
					if bool(ev.get("swish", false)):
						hud.toast("SWISH!", Color("80ed99"))
				Sfx.play("fanfare")
			else:
				hud.toast("%s finished %s" % [_name(slot), _ordinal(place)], UITheme.SLOT_COLORS[slot % UITheme.SLOT_COLORS.size()])
		"hole_timer":
			hud.toast("%d seconds to finish!" % int(ev.remaining), UITheme.CORAL)
			Sfx.play("alert")
		"hole_end":
			if view.mode == "online":
				_show_hole_results(ev)
		"match_end":
			_match_over = true
			if view.mode == "stroke":
				_show_scorecard(ev)
			else:
				_show_match_end(ev)
		"player_left":
			hud.toast("%s disconnected" % _name(slot), UITheme.MUTED)
		"player_rejoined":
			hud.toast("%s reconnected" % _name(slot), UITheme.MUTED)
		"player_forfeit":
			hud.toast("%s left the match" % _name(slot), UITheme.MUTED)
		"emote":
			_show_emote(slot, int(ev.emote))
		"rejected":
			_on_rejected(str(ev.error))


## Golf name for a hole score relative to par.
static func _score_name(strokes: int, par: int) -> String:
	if strokes == 1:
		return "HOLE IN ONE!"
	match strokes - par:
		-3: return "ALBATROSS!"
		-2: return "EAGLE!"
		-1: return "BIRDIE!"
		0: return "PAR"
		1: return "BOGEY"
		2: return "DOUBLE BOGEY"
	return "+%d" % (strokes - par) if strokes > par else "%d UNDER" % (par - strokes)


## End of a stroke-play round: the scorecard, records and medal.
func _show_scorecard(ev: Dictionary) -> void:
	_cancel_aim()
	var standings: Array = ev.get("standings", [])
	var card: Array = standings[0].get("scorecard", []) if not standings.is_empty() else []
	var clean := bool(params.get("clean", false))
	var res := Records.record_round(view.course, card, clean)
	var panel := _overlay_panel(Vector2(980, 0))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var diff := int(res.total) - int(res.par)
	vb.add_child(UITheme.styled_label("%s COMPLETE" % str(view.course.name).to_upper(), 54, UITheme.SUN, 10))
	vb.add_child(UITheme.styled_label("%d strokes · %s" % [int(res.total), "Even par" if diff == 0 else ("%+d" % diff)], 34, UITheme.PAPER, 8))
	var grid := GridContainer.new()
	grid.columns = card.size() + 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	vb.add_child(grid)
	var rows := [["Hole"], ["Par"], ["Score"]]
	var par_total := 0
	for i in card.size():
		var row: Dictionary = card[i]
		rows[0].append(str(i + 1))
		rows[1].append(str(int(row.par)))
		rows[2].append(str(int(row.strokes)) + ("*" if bool(row.get("ace", false)) else ""))
		par_total += int(row.par)
	rows[0].append("Total")
	rows[1].append(str(par_total))
	rows[2].append(str(int(res.total)))
	for r in 3:
		for c in rows[r].size():
			var l := Label.new()
			l.text = str(rows[r][c])
			l.custom_minimum_size = Vector2(62 if c > 0 else 80, 34)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.add_theme_font_override("font", UITheme.heading_font() if r != 1 else UITheme.body_bold_font())
			l.add_theme_font_size_override("font_size", 22)
			var col := UITheme.PAPER
			if r == 2 and c > 0 and c <= card.size():
				var d := int(card[c - 1].strokes) - int(card[c - 1].par)
				col = Color("80ed99") if d < 0 else (UITheme.PAPER if d == 0 else UITheme.CORAL)
			l.add_theme_color_override("font_color", col if r != 0 else UITheme.MUTED)
			grid.add_child(l)
	var notes: PackedStringArray = []
	if str(res.medal) != "":
		notes.append("%s MEDAL" % str(res.medal).to_upper())
	if bool(res.new_best):
		notes.append("NEW PERSONAL BEST")
	if int(res.aces) > 0:
		notes.append("%d hole-in-one%s" % [int(res.aces), "s" if int(res.aces) > 1 else ""])
	if int(res.swishes) > 0:
		notes.append("%d swish%s" % [int(res.swishes), "es" if int(res.swishes) > 1 else ""])
	if clean:
		notes.append("Clean Ball")
	if not notes.is_empty():
		vb.add_child(UITheme.styled_label("  ·  ".join(notes), 26, Color("80ed99"), 7))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	vb.add_child(buttons)
	var again := GameButton.make("Play Again", "PrimaryButton", Vector2(240, 64))
	again.pressed.connect(func() -> void: Router.goto(Router.GAME, {"mode": "stroke", "course": view.course_id, "hole": 0, "clean": clean}))
	buttons.add_child(again)
	var courses := GameButton.make("Courses", "", Vector2(220, 64))
	courses.pressed.connect(func() -> void: Router.goto(Router.COURSES))
	buttons.add_child(courses)
	Sfx.play("results")


func _on_rejected(err: String) -> void:
	var text := {"energy": "Not enough energy", "cooldown": "Recharging…", "airborne": "Wait until your ball lands",
		"no_charges": "None of those left this round", "mode": "That ball isn't allowed in this mode",
		"not_owned": "You don't have that ball yet", "resetting": "", "unavailable": "", "not_playing": ""}.get(err, "Action not allowed")
	if text != "":
		hud.toast(text, UITheme.CORAL)
		Sfx.play("ui_deny", -8.0)


func _on_impacts(list: Array) -> void:
	for imp: Dictionary in list:
		var speed := float(imp.speed)
		var pos: Vector2 = imp.pos
		var dist := pos.distance_to(camera.get_screen_center_position())
		var vol := clampf(-28.0 + speed / 40.0, -30.0, 0.0) - clampf(dist / 120.0, 0.0, 18.0)
		var mat := int(imp.mat)
		if mat == 255 or mat < 0:
			Sfx.play("ball_clack", vol + 2.0, randf_range(0.92, 1.08), 80)
			fx.impact_ring(pos, Color(1, 1, 1, 0.7), 18.0)
			continue
		var mname := view.terrain.material_names[mat] if mat < view.terrain.material_names.size() else "grass"
		var sound := str(GameData.materials.get(mname, {}).get("sound", "thud_grass"))
		Sfx.play(sound, vol, randf_range(0.94, 1.06), 80)
		if speed > 260.0:
			var col := Color("e9dcc6")
			if mname == "sand":
				col = Color("f4d58d")
			elif mname == "ice":
				col = Color("e6fbff")
			elif mname in ["grass", "rough"]:
				col = Color(view.course.get("theme", {}).get("grass_light", "#9be36b"))
			fx.dust(pos, Vector2.UP, speed, col)
		if mname == "bouncy" and speed > 100.0:
			fx.impact_ring(pos, Color("ff4d6d"), 30.0)


func _name(slot: int) -> String:
	for r in view.roster:
		if int(r.slot) == slot:
			return str(r.name)
	return "Player"


static func _ordinal(n: int) -> String:
	match n:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
		_: return "%dth" % n


func _show_emote(slot: int, id: int) -> void:
	if id < 0 or id >= Emotes.count() or not balls.has(slot):
		return
	var e: Dictionary = Emotes.LIST[id]
	if _bubbles.has(slot):
		_bubbles[slot].node.queue_free()
	var bubble := _SpeechBubble.new()
	bubble.text = str(e.bubble)
	bubble.accent = UITheme.SLOT_COLORS[slot % UITheme.SLOT_COLORS.size()]
	world.add_child(bubble)
	_bubbles[slot] = {"node": bubble, "until": _clock + maxf(2.2, float(e.duration) + 0.4)}
	Sfx.play("pop", -6.0, 1.0 + id * 0.02)
	var g: Golfer = golfers.get(slot)
	if g and g.visible and not (slot == view.local_slot and shot.aiming):
		g.emote(str(e.id))


func _update_bubbles() -> void:
	for slot: int in _bubbles.keys():
		var b: Dictionary = _bubbles[slot]
		var node: Node2D = b.node
		if _clock > float(b.until):
			node.queue_free()
			_bubbles.erase(slot)
			continue
		var anchor: Vector2 = balls[slot].position + Vector2(0, -26)
		if golfers.has(slot) and golfers[slot].visible:
			anchor = golfers[slot].position + Vector2(0, -112 * GOLFER_SCALE)
		node.position = anchor


# ---------------------------------------------------------------------------
# Overlays
# ---------------------------------------------------------------------------

func _overlay_panel(min_size: Vector2) -> PanelContainer:
	_hide_overlay()
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.1, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.theme = UITheme.get_theme()
	overlay_layer.add_child(dim)
	_overlay = dim
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	center.add_child(panel)
	dim.modulate.a = 0.0
	create_tween().tween_property(dim, "modulate:a", 1.0, 0.2)
	panel.scale = Vector2(0.9, 0.9)
	panel.pivot_offset = min_size * 0.5
	create_tween().tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return panel


func _hide_overlay() -> void:
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_menu_open = false


func _show_connecting() -> void:
	var panel := _overlay_panel(Vector2(560, 220))
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)
	var t := Label.new()
	t.theme_type_variation = "TitleLabel"
	t.text = "Joining match…"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var m := Label.new()
	m.theme_type_variation = "MutedLabel"
	m.text = "Connecting to %s:%d" % [params.get("host", "?"), int(params.get("port", 0))]
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(m)
	var cancel := GameButton.make("Cancel", "GhostButton", Vector2(200, 56))
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.pressed.connect(_leave_to_menu)
	vb.add_child(cancel)


func _on_connection_lost(reason: String) -> void:
	if _match_over:
		return
	var panel := _overlay_panel(Vector2(620, 260))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	panel.add_child(vb)
	var t := Label.new()
	t.theme_type_variation = "TitleLabel"
	t.text = "Disconnected"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var m := Label.new()
	m.text = reason
	m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(m)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 14)
	vb.add_child(hb)
	if view is NetMatchView and not _match_over:
		var rejoin := GameButton.make("Reconnect", "PrimaryButton", Vector2(220, 60))
		rejoin.pressed.connect(func() -> void: Router.goto(Router.GAME, params))
		hb.add_child(rejoin)
	var back := GameButton.make("Main Menu", "", Vector2(220, 60))
	back.pressed.connect(_leave_to_menu)
	hb.add_child(back)


func _toggle_menu() -> void:
	if _menu_open:
		_hide_overlay()
		return
	if _match_over:
		return
	var panel := _overlay_panel(Vector2(520, 0))
	_menu_open = true
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	var t := Label.new()
	t.theme_type_variation = "HeadingLabel"
	t.text = "Paused" if view.mode == "practice" else "Menu"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	if view.mode == "online":
		var note := Label.new()
		note.theme_type_variation = "MutedLabel"
		note.text = "The match keeps running while this menu is open."
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(note)
	var resume := GameButton.make("Resume", "PrimaryButton", Vector2(0, 66))
	resume.pressed.connect(_hide_overlay)
	vb.add_child(resume)
	var emotes := GameButton.make("Emotes  (hold %s)" % Settings.binding_label("emote_wheel"), "GhostButton", Vector2(0, 56))
	emotes.pressed.connect(func() -> void:
		_hide_overlay()
		_open_emote_wheel())
	vb.add_child(emotes)
	var settings := GameButton.make("Settings", "", Vector2(0, 60))
	settings.pressed.connect(func() -> void:
		_hide_overlay()
		var sp := SettingsPanel.new()
		overlay_layer.add_child(sp)
		sp.closed.connect(sp.queue_free))
	vb.add_child(settings)
	if view.mode == "stroke":
		var restart := GameButton.make("Restart Round", "", Vector2(0, 56))
		restart.pressed.connect(func() -> void: Router.goto(Router.GAME, {"mode": "stroke", "course": view.course_id, "hole": 0, "clean": bool(params.get("clean", false))}))
		vb.add_child(restart)
	var leave := GameButton.make("Leave Match" if view.mode == "online" else ("Quit Round" if view.mode == "stroke" else "Exit Practice"), "DangerButton", Vector2(0, 60))

	leave.pressed.connect(func() -> void:
		if view.mode == "online":
			_confirm_leave()
		else:
			_leave_to_menu())
	vb.add_child(leave)


func _confirm_leave() -> void:
	var panel := _overlay_panel(Vector2(600, 0))
	_menu_open = true
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)
	var t := Label.new()
	t.theme_type_variation = "TitleLabel"
	t.text = "Leave this match?"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var m := Label.new()
	m.text = "You'll be placed last%s." % (" and lose trophies" if str(params.get("queueMode", "quick")) == "quick" else "")
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(m)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 14)
	vb.add_child(hb)
	var stay := GameButton.make("Stay", "PrimaryButton", Vector2(200, 60))
	stay.pressed.connect(_hide_overlay)
	hb.add_child(stay)
	var go := GameButton.make("Leave", "DangerButton", Vector2(200, 60))
	go.pressed.connect(_leave_to_menu)
	hb.add_child(go)


func _leave_to_menu() -> void:
	if view:
		view.leave()
	Router.goto(Router.MAIN_MENU)


func _show_scoreboard(on: bool) -> void:
	if not on:
		if _results_overlay and is_instance_valid(_results_overlay) and _results_overlay.get_meta("scoreboard", false):
			_results_overlay.queue_free()
		return
	if _overlay != null or view.mode != "online":
		return
	var rows: Array[Dictionary] = []
	for r in view.roster:
		var ps := view.player_state(int(r.slot))
		rows.append({"slot": int(r.slot), "name": str(r.name), "points": int(ps.points), "gained": -1, "place": 0})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.points > b.points)
	_results_overlay = _results_card("Scoreboard", rows, "First to %d points" % view.target_points)
	_results_overlay.set_meta("scoreboard", true)


func _results_card(title: String, rows: Array[Dictionary], subtitle: String) -> Control:
	var root := CenterContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.get_theme()
	overlay_layer.add_child(root)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var t := Label.new()
	t.theme_type_variation = "HeadingLabel"
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	if subtitle != "":
		var st := Label.new()
		st.theme_type_variation = "MutedLabel"
		st.text = subtitle
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(st)
	for i in rows.size():
		var r := rows[i]
		var row := PanelContainer.new()
		row.theme_type_variation = "CardPanel"
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 14)
		row.add_child(hb)
		var place := Label.new()
		var p := int(r.get("place", i + 1))
		place.text = _ordinal(p) if p > 0 else "—"
		place.custom_minimum_size = Vector2(64, 0)
		place.add_theme_font_override("font", UITheme.heading_font())
		place.add_theme_font_size_override("font_size", 28)
		place.add_theme_color_override("font_color", PLACE_COLORS[clampi(p - 1, 0, 3)] if p > 0 else UITheme.MUTED)
		hb.add_child(place)
		var chip := ColorRect.new()
		chip.custom_minimum_size = Vector2(12, 34)
		chip.color = UITheme.SLOT_COLORS[int(r.slot) % UITheme.SLOT_COLORS.size()]
		hb.add_child(chip)
		var n := Label.new()
		n.text = str(r.name) + ("  (you)" if int(r.slot) == view.local_slot else "")
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.add_theme_font_override("font", UITheme.body_bold_font())
		hb.add_child(n)
		if int(r.get("gained", -1)) >= 0:
			var g := Label.new()
			g.text = "+%d" % int(r.gained)
			g.add_theme_font_override("font", UITheme.heading_font())
			g.add_theme_color_override("font_color", Color("80ed99") if int(r.gained) > 0 else UITheme.MUTED)
			hb.add_child(g)
		var pts := Label.new()
		pts.text = "%d pts" % int(r.points)
		pts.custom_minimum_size = Vector2(90, 0)
		pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pts.add_theme_font_override("font", UITheme.heading_font())
		pts.add_theme_color_override("font_color", UITheme.SUN)
		hb.add_child(pts)
		vb.add_child(row)
		row.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.08 * i)
		tw.tween_property(row, "modulate:a", 1.0, 0.2)
	return root


func _show_hole_results(ev: Dictionary) -> void:
	var rows: Array[Dictionary] = []
	for r: Dictionary in ev.results:
		rows.append({"slot": int(r.slot), "name": _name(int(r.slot)), "points": int(r.total), "gained": int(r.gained), "place": int(r.place)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa: int = a.place if a.place > 0 else 99
		var pb: int = b.place if b.place > 0 else 99
		return pa < pb if pa != pb else a.points > b.points)
	var card := _results_card("Hole %d complete" % (view.hole_number + 1), rows, "First to %d points" % view.target_points)
	var dur := float(ev.get("next_in", 5.0))
	var tw := create_tween()
	tw.tween_interval(maxf(1.0, dur - 0.6))
	tw.tween_property(card, "modulate:a", 0.0, 0.3)
	tw.tween_callback(card.queue_free)
	Sfx.play("results")


func _show_match_end(ev: Dictionary) -> void:
	_cancel_aim()
	var standings: Array = ev.get("standings", [])
	var my_place := 0
	for s: Dictionary in standings:
		if int(s.slot) == view.local_slot:
			my_place = int(s.placement)
	var panel := _overlay_panel(Vector2(760, 0))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	var title := UITheme.styled_label("VICTORY!" if my_place == 1 else ("%s PLACE" % _ordinal(my_place).to_upper()), 72,
		UITheme.SUN if my_place == 1 else UITheme.PAPER, 12)
	vb.add_child(title)
	if str(ev.get("reason", "")) == "aborted":
		var ab := Label.new()
		ab.text = "Match ended early — no trophies were changed."
		ab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ab.theme_type_variation = "MutedLabel"
		vb.add_child(ab)
	for s: Dictionary in standings:
		var row := PanelContainer.new()
		row.theme_type_variation = "CardPanel"
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 14)
		row.add_child(hb)
		var p := Label.new()
		p.text = _ordinal(int(s.placement))
		p.custom_minimum_size = Vector2(64, 0)
		p.add_theme_font_override("font", UITheme.heading_font())
		p.add_theme_font_size_override("font_size", 28)
		p.add_theme_color_override("font_color", PLACE_COLORS[clampi(int(s.placement) - 1, 0, 3)])
		hb.add_child(p)
		var n := Label.new()
		n.text = str(s.name) + ("  (you)" if int(s.slot) == view.local_slot else "") + ("  — left" if s.get("disconnected", false) else "")
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.add_theme_font_override("font", UITheme.body_bold_font())
		hb.add_child(n)
		var pts := Label.new()
		pts.text = "%d pts" % int(s.points)
		pts.add_theme_font_override("font", UITheme.heading_font())
		pts.add_theme_color_override("font_color", UITheme.SUN)
		hb.add_child(pts)
		vb.add_child(row)
	var rewards := VBoxContainer.new()
	rewards.add_theme_constant_override("separation", 6)
	vb.add_child(rewards)
	var status := Label.new()
	status.theme_type_variation = "MutedLabel"
	status.text = "Saving results…"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rewards.add_child(status)
	var hb2 := HBoxContainer.new()
	hb2.alignment = BoxContainer.ALIGNMENT_CENTER
	hb2.add_theme_constant_override("separation", 14)
	vb.add_child(hb2)
	if str(params.get("queueMode", "quick")) == "quick":
		var again := GameButton.make("Play Again", "PrimaryButton", Vector2(240, 64))
		again.pressed.connect(func() -> void:
			view.leave()
			Router.goto(Router.MAIN_MENU, {"autoQueue": true}))
		hb2.add_child(again)
	else:
		var room := GameButton.make("Back to Room", "PrimaryButton", Vector2(240, 64))
		room.pressed.connect(func() -> void:
			view.leave()
			Router.goto(Router.MAIN_MENU, {"room": params.get("roomCode", "")}))
		hb2.add_child(room)
	var menu := GameButton.make("Main Menu", "", Vector2(240, 64))
	menu.pressed.connect(_leave_to_menu)
	hb2.add_child(menu)
	if my_place == 1:
		Sfx.play("victory")
		fx.confetti(camera.get_screen_center_position() + Vector2(0, 200), 140)
	else:
		Sfx.play("results")
	for slot: int in golfers:
		var place := 4
		for s: Dictionary in standings:
			if int(s.slot) == slot:
				place = int(s.placement)
		var g: Golfer = golfers[slot]
		if g.visible:
			g.play("dance" if place == 1 else "sad")
	_load_rewards(rewards, status)


func _load_rewards(box: VBoxContainer, status: Label) -> void:
	if not view is NetMatchView:
		status.text = ""
		return
	var match_id := (view as NetMatchView).match_id
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline and is_instance_valid(box):
		var res := await Backend.get_json("/v1/matches/%s" % match_id)
		if not is_instance_valid(box):
			return
		if res.ok:
			var r: Dictionary = res.data.get("myRewards", {})
			status.text = ""
			var line := HBoxContainer.new()
			line.alignment = BoxContainer.ALIGNMENT_CENTER
			line.add_theme_constant_override("separation", 30)
			box.add_child(line)
			var td := int(r.get("trophyDelta", 0))
			_reward_chip(line, "🏆", ("+%d" % td) if td >= 0 else str(td), UITheme.TROPHY if td >= 0 else UITheme.CORAL)
			_reward_chip(line, "XP", "+%d" % int(r.get("xpGained", 0)), Color("80ed99"))
			_reward_chip(line, "🪙", "+%d" % int(r.get("coinsGained", 0)), UITheme.SUN)
			if int(r.get("levelAfter", 0)) > int(r.get("levelBefore", 0)):
				var lv := UITheme.styled_label("LEVEL UP!  Level %d" % int(r.levelAfter), 36, Color("80ed99"), 8)
				box.add_child(lv)
				Sfx.play("level_up")
			Backend.refresh_profile()
			return
		if res.status != 404 and res.status != 0:
			break
		await get_tree().create_timer(1.0).timeout
	if is_instance_valid(status):
		status.text = "Results are still being processed. Check your profile shortly."


func _reward_chip(parent: Control, icon: String, value: String, color: Color) -> void:
	var l := UITheme.styled_label("%s %s" % [icon, value], 34, color, 8)
	parent.add_child(l)
	l.scale = Vector2(0.5, 0.5)
	l.pivot_offset = Vector2(60, 20)
	create_tween().tween_property(l, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------------------
# Practice tools
# ---------------------------------------------------------------------------

func _build_practice_panel() -> void:
	var lv := view as LocalMatchView
	var root := PanelContainer.new()
	root.theme = UITheme.get_theme()
	var sb := UITheme.box(Color(UITheme.INK, 0.85), 18, UITheme.INK_LINE, 0, 8)
	root.add_theme_stylebox_override("panel", sb)
	root.custom_minimum_size = Vector2(430, 0)
	hud.add_child(root)
	UITheme.pin(root, 1, 0, Vector2(-24, 100), -1, 1)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	root.add_child(vb)
	var title := Label.new()
	title.theme_type_variation = "TitleLabel"
	title.text = "Practice · %s" % view.course.get("name", "")
	vb.add_child(title)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	vb.add_child(hb)
	var holes: Array = view.course.holes
	var prev := GameButton.make("◀", "GhostButton", Vector2(56, 52))
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UITheme.body_bold_font())
	var next := GameButton.make("▶", "GhostButton", Vector2(56, 52))
	var restart := GameButton.make("Restart", "", Vector2(130, 52))
	var refresh := func() -> void:
		label.text = "Hole %d / %d" % [view.hole_index + 1, holes.size()]
	prev.pressed.connect(func() -> void:
		lv.set_hole(posmod(view.hole_index - 1, holes.size()))
		refresh.call())
	next.pressed.connect(func() -> void:
		lv.set_hole(posmod(view.hole_index + 1, holes.size()))
		refresh.call())
	restart.pressed.connect(func() -> void: lv.set_hole(view.hole_index))
	hb.add_child(prev)
	hb.add_child(label)
	hb.add_child(next)
	hb.add_child(restart)
	refresh.call()
	view.hole_loaded.connect(func(_i: int, _n: int) -> void: refresh.call())

	var other := "physics_lab" if view.course_id != "physics_lab" else "golf_land"
	var switch := GameButton.make("Open %s" % GameData.course(other).get("name", other), "GhostButton", Vector2(0, 50))
	switch.pressed.connect(func() -> void: Router.goto(Router.GAME, {"mode": "practice", "course": other, "hole": 0, "lab": other == "physics_lab"}))
	vb.add_child(switch)
	var dbg := CheckButton.new()
	dbg.text = "Debug: show flight path"
	dbg.tooltip_text = "Practice only. Draws the predicted flight for every ball. Never available online."
	dbg.toggled.connect(func(on: bool) -> void:
		_debug_traj = on
		_pending_predict = true)
	vb.add_child(dbg)
	var lab_toggle := CheckButton.new()
	lab_toggle.text = "Physics Lab (tuning)"
	vb.add_child(lab_toggle)
	var lab := VBoxContainer.new()
	lab.visible = bool(params.get("lab", false))
	lab_toggle.button_pressed = lab.visible
	lab_toggle.toggled.connect(func(on: bool) -> void: lab.visible = on)
	vb.add_child(lab)
	var specs := [
		["physics", "gravity", "Gravity", 400.0, 3000.0],
		["physics", "air_drag", "Air drag", 0.0, 1.0],
		["physics", "ball_restitution", "Ball-ball bounce", 0.0, 1.2],
		["physics", "rest_speed", "Rest speed", 5.0, 80.0],
		["shot", "max_speed", "Max shot speed", 600.0, 3000.0],
		["shot", "min_speed", "Min shot speed", 50.0, 600.0],
		["shot", "cooldown", "Shot cooldown (s)", 0.0, 5.0],
		["energy", "regen_per_second", "Energy regen /s", 0.0, 3.0],
	]
	for sp in specs:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.custom_minimum_size = Vector2(190, 0)
		l.add_theme_font_size_override("font_size", 18)
		row.add_child(l)
		var s := HSlider.new()
		s.min_value = sp[3]
		s.max_value = sp[4]
		s.step = (float(sp[4]) - float(sp[3])) / 200.0
		s.value = float(lv.balance[sp[0]][sp[1]])
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.custom_minimum_size = Vector2(180, 30)
		var upd := func(v: float) -> void:
			l.text = "%s: %s" % [sp[2], str(snappedf(v, 0.01))]
			lv.apply_tuning(sp[0], sp[1], v)
		s.value_changed.connect(upd)
		upd.call(s.value)
		row.add_child(s)
		lab.add_child(row)
	var note := Label.new()
	note.theme_type_variation = "MutedLabel"
	note.text = "Lab changes affect this practice session only.\nMaterial values live in data/materials.json."
	note.add_theme_font_size_override("font_size", 16)
	lab.add_child(note)
	var energy := GameButton.make("Refill energy", "GhostButton", Vector2(0, 48))
	energy.pressed.connect(func() -> void: lv.sim.players[0].energy = float(lv.balance.energy.max))
	lab.add_child(energy)


## Rounded speech bubble with a tail, anchored at its tail tip. Pops in with a springy scale.
class _SpeechBubble extends Node2D:
	var text := ""
	var accent := UITheme.SUN
	var _t := 0.0
	var _label: Label

	func _ready() -> void:
		z_index = 50
		_label = UITheme.styled_label(text, 26, UITheme.INK, 0)
		add_child(_label)
		_label.reset_size()
		scale = Vector2(0.2, 0.2)
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var sz := _label.size + Vector2(30, 10)
		var r := Rect2(Vector2(-sz.x * 0.5, -sz.y - 14.0), sz)
		_label.position = r.position + Vector2(15, 5)
		var tail := PackedVector2Array([Vector2(-9, r.end.y - 2), Vector2(9, r.end.y - 2), Vector2(0, 0)])
		var ink := UITheme.INK_LINE
		_round_rect(r.grow(3.0), 17.0, ink)
		draw_colored_polygon(PackedVector2Array([tail[0] + Vector2(-3, 0), tail[1] + Vector2(3, 0), Vector2(0, 4)]), ink)
		_round_rect(r, 14.0, UITheme.PAPER)
		draw_colored_polygon(tail, UITheme.PAPER)
		draw_line(r.position + Vector2(14, 3), Vector2(r.end.x - 14, r.position.y + 3), accent, 4.0, true)

	func _round_rect(r: Rect2, rad: float, col: Color) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(int(rad))
		sb.anti_aliasing = true
		draw_style_box(sb, r)
