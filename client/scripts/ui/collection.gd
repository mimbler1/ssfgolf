extends Node
## Collection: every cosmetic in the catalog (themed golfer outfits, ball colours, trail colours),
## what you own, and card packs (API.md §1.7). Pack rolls happen on the server; this screen only
## shows the results. Cosmetics never change gameplay.

const TABS := [["All", ""], ["Golfers", "character"], ["Balls", "ball"], ["Trails", "trail"]]

var ui: Control
var _grid: GridContainer
var _search: LineEdit
var _tab := ""
var _owned_only := false
var _rarity := ""
var _coins: Label
var _status: Label
var _tab_buttons: Dictionary = {}
var _overlay: Control
var _scroll: ScrollContainer


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("f1ebe0"))
	var bg := MenuBackdrop.new()
	add_child(bg)
	bg.setup(GameData.theme_for("golf_land"), LocalStore.appearance(), false)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	ui = Control.new()
	ui.theme = UITheme.get_theme()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui)
	Cosmetics.ensure_loaded()
	_build()
	_fill()
	if OS.get_cmdline_user_args().has("--dev-reveal"):
		# Visual check of the reveal with sample items (no server roll, nothing is granted).
		_show_reveal({"refund": 25, "items": [
			{"itemId": "char_knight", "kind": "character", "value": "knight", "name": "Sir Putts", "rarity": "legendary", "isNew": true, "refund": 0},
			{"itemId": "ball_7209b7", "kind": "ball", "value": "#7209b7", "name": "Grape Ball", "rarity": "epic", "isNew": true, "refund": 0},
			{"itemId": "trail_4cc9f0", "kind": "trail", "value": "#4cc9f0", "name": "Sky Trail", "rarity": "common", "isNew": false, "refund": 10}]})
		return
	await Cosmetics.refresh()
	_update_coins()
	_fill()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.97, 0.94, 0.88, 0.3)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(dim)
	var title := UITheme.styled_label("COLLECTION", 60, UITheme.SUN, 12)
	ui.add_child(title)
	UITheme.pin(title, 0, 0, Vector2(48, 24), 1, 1)
	_coins = UITheme.styled_label("", 30, UITheme.SUN, 7)
	ui.add_child(_coins)
	UITheme.pin(_coins, 1, 0, Vector2(-48, 40), -1, 1)

	# Left: filters and packs.
	var left := PanelContainer.new()
	ui.add_child(left)
	left.anchor_bottom = 1.0
	left.offset_left = 40
	left.offset_right = 400
	left.clip_contents = true
	left.offset_top = 120
	left.offset_bottom = -110
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 10)
	left.add_child(lv)
	for t: Array in TABS:
		var b := GameButton.make(str(t[0]), "GhostButton", Vector2(0, 54))
		b.toggle_mode = true
		b.pressed.connect(func() -> void:
			_tab = str(t[1])
			_fill())
		lv.add_child(b)
		_tab_buttons[str(t[1])] = b
	_search = LineEdit.new()
	_search.placeholder_text = "Search"
	_search.custom_minimum_size = Vector2(0, 50)
	_search.text_changed.connect(func(_t: String) -> void: _fill())
	lv.add_child(_search)
	var own := CheckButton.new()
	own.text = "Owned only"
	own.toggled.connect(func(on: bool) -> void:
		_owned_only = on
		_fill())
	lv.add_child(own)
	var rar := OptionButton.new()
	for r in ["Any rarity", "common", "rare", "epic", "legendary"]:
		rar.add_item(r.capitalize())
	rar.item_selected.connect(func(i: int) -> void:
		_rarity = "" if i == 0 else ["common", "rare", "epic", "legendary"][i - 1]
		_fill())
	lv.add_child(rar)
	var sep := HSeparator.new()
	lv.add_child(sep)
	var ph := Label.new()
	ph.theme_type_variation = "TitleLabel"
	ph.text = "Card packs"
	lv.add_child(ph)
	for p: Dictionary in Cosmetics.packs():
		var pb := GameButton.make("%s · %d" % [p.name, int(p.cost)], "SunButton" if p.has("guarantee") else "PrimaryButton", Vector2(0, 60))
		pb.add_theme_font_size_override("font_size", 24)
		pb.tooltip_text = "%d items%s. Duplicates refund coins." % [int(p.items), (", first item %s or better" % str(p.guarantee)) if p.has("guarantee") else ""]
		pb.pressed.connect(_open_pack.bind(str(p.id)))
		lv.add_child(pb)
	_status = Label.new()
	_status.theme_type_variation = "MutedLabel"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.add_child(_status)

	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 424
	scroll.offset_right = -40
	scroll.offset_top = 120
	scroll.offset_bottom = -110
	ui.add_child(scroll)
	_grid = GridContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(_grid)
	scroll.resized.connect(_reflow)

	var back := GameButton.make("Back", "", Vector2(170, 66))
	back.pressed.connect(func() -> void: Router.goto(Router.MAIN_MENU))
	ui.add_child(back)
	UITheme.pin(back, 0, 1, Vector2(40, -26), 1, -1)
	_update_coins()


func _update_coins() -> void:
	if Cosmetics.online:
		_coins.text = "%d coins" % int(Backend.profile.get("coins", 0))
		_status.text = ""
	else:
		_coins.text = ""
		_status.text = "Offline: showing the starter collection. Sign in to open packs."


## Rebuilds the visible cards (only the cards matching the filters exist; the list is small).
func _fill() -> void:
	for k: String in _tab_buttons:
		_tab_buttons[k].set_pressed_no_signal(k == _tab)
	for c in _grid.get_children():
		c.queue_free()
	var q := _search.text.strip_edges().to_lower() if _search else ""
	var order := ["legendary", "epic", "rare", "common"]
	var list := Cosmetics.items(_tab)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var oa := Cosmetics.owned.has(str(a.id))
		var ob := Cosmetics.owned.has(str(b.id))
		if oa != ob:
			return oa
		return order.find(str(a.rarity)) < order.find(str(b.rarity)))
	var shown := 0
	var owned_n := 0
	for it in list:
		var have := Cosmetics.owned.has(str(it.id))
		if have:
			owned_n += 1
		if _owned_only and not have:
			continue
		if _rarity != "" and str(it.rarity) != _rarity:
			continue
		if q != "" and not str(it.name).to_lower().contains(q):
			continue
		if str(it.kind) == "character" and not InkLook.has_outfit(str(it.value)):
			continue
		_grid.add_child(_card(it, have))
		shown += 1
	if _status and Cosmetics.online:
		_status.text = "Owned %d / %d" % [owned_n, list.size()]
	_reflow.call_deferred()


func _reflow() -> void:
	if _scroll and _scroll.size.x > 0.0:
		_grid.columns = maxi(1, int((_scroll.size.x - 16.0 + 14.0) / (190.0 + 14.0)))


func _card(it: Dictionary, have: bool) -> Control:
	var col := Cosmetics.rarity_color(str(it.rarity))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(190, 236)
	var sb := InkStyleBox.make(UITheme.PAPER if have else UITheme.PAPER_DEEP, 3.4 if have else 2.4, 14.0, 4.0, 3.0)
	sb.ink = UITheme.INK if have else Color(UITheme.INK, 0.55)
	sb.lip_color = col if have else Color(col, 0.35)
	sb.content_margin_left = 8; sb.content_margin_right = 8; sb.content_margin_top = 8; sb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	card.add_child(vb)
	var art := ItemArt.new()
	art.item = it
	art.locked = not have
	art.custom_minimum_size = Vector2(0, 150)
	vb.add_child(art)
	var n := Label.new()
	n.text = str(it.name)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.add_theme_font_override("font", UITheme.body_bold_font())
	n.add_theme_font_size_override("font_size", 17)
	n.clip_text = true
	vb.add_child(n)
	var r := Label.new()
	var copies := int(Cosmetics.owned.get(str(it.id), 0))
	r.text = str(it.rarity).to_upper() + ("" if have else "  ·  LOCKED") + (("  ·  x%d" % copies) if copies > 1 else "")
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.add_theme_font_size_override("font_size", 14)
	r.add_theme_color_override("font_color", col if have else UITheme.MUTED)
	vb.add_child(r)
	return card


func _open_pack(pack_id: String) -> void:
	if not Backend.is_logged_in():
		_status.text = "Sign in (play online once) to open packs."
		return
	_status.text = "Opening…"
	var res := await Backend.send_json(HTTPClient.METHOD_POST, "/v1/packs/%s/open" % pack_id, {})
	if not res.ok:
		_status.text = Backend.friendly_error(res)
		Sfx.play("ui_deny", -4.0)
		return
	_status.text = ""
	var data: Dictionary = res.data
	Backend.profile["coins"] = int(data.coins)
	for it: Dictionary in data.items:
		Cosmetics.owned[str(it.itemId)] = int(Cosmetics.owned.get(str(it.itemId), 0)) + 1
	_update_coins()
	_show_reveal(data)
	_fill()


## Pack reveal: cards flip one by one; rarity glow, NEW badge or refund; Skip reveals all.
func _show_reveal(data: Dictionary) -> void:
	if _overlay:
		_overlay.queue_free()
	var shade := ColorRect.new()
	shade.color = Color(0.12, 0.1, 0.08, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(shade)
	_overlay = shade
	var reduced0 := bool(Settings.get_value("gameplay", "reduced_motion"))
	if not reduced0:
		# 1-4: the pack floats in, waits for a click (or opens itself), shakes and bursts.
		var best := "common"
		for it: Dictionary in data.items:
			if ["common", "rare", "epic", "legendary"].find(str(it.rarity)) > ["common", "rare", "epic", "legendary"].find(best):
				best = str(it.rarity)
		var stage := PackStage.new()
		stage.rarity = best
		stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.add_child(stage)
		await stage.opened
		if not is_instance_valid(shade):
			return
		stage.queue_free()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 24)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(vb)
	vb.add_child(UITheme.styled_label("PACK OPENED", 54, UITheme.SUN, 10))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	vb.add_child(row)
	var cards: Array[RevealCard] = []
	for it: Dictionary in data.items:
		var c := RevealCard.new()
		c.item = Cosmetics.item_for(str(it.kind), str(it.value))
		if c.item.is_empty():
			c.item = {"id": it.itemId, "kind": it.kind, "value": it.value, "name": it.name, "rarity": it.rarity}
		c.is_new = bool(it.isNew)
		c.refund = int(it.refund)
		c.custom_minimum_size = Vector2(220, 300)
		row.add_child(c)
		cards.append(c)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 16)
	vb.add_child(foot)
	var skip := GameButton.make("Skip", "GhostButton", Vector2(180, 60))
	foot.add_child(skip)
	var done := GameButton.make("Continue", "PrimaryButton", Vector2(220, 60))
	done.visible = false
	foot.add_child(done)
	done.pressed.connect(func() -> void:
		shade.queue_free()
		_overlay = null)
	var state := {"skip": false}
	skip.pressed.connect(func() -> void: state.skip = true)
	var reduced := bool(Settings.get_value("gameplay", "reduced_motion"))
	for c in cards:
		if not state.skip and not reduced:
			await get_tree().create_timer(0.45).timeout
		if not is_instance_valid(c):
			return
		c.reveal(not state.skip and not reduced)
		Sfx.play("pop" if c.item.get("rarity", "common") in ["common", "rare"] else "fanfare", -4.0)
	skip.visible = false
	done.visible = true
	if int(data.refund) > 0:
		vb.add_child(UITheme.styled_label("Duplicates refunded %d coins" % int(data.refund), 24, UITheme.PAPER, 6))


# ---------------------------------------------------------------------------

## Draws a collectible in ink: the outfit on the stick figure (golfer), the ball (ball), a
## trail streak behind a ball (trail).
class ItemArt extends Control:
	var item: Dictionary = {}
	var locked := false
	var _thumb: InkThumb
	var _cv := InkCanvas.new()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if str(item.get("kind", "")) == "character":
			_thumb = InkThumb.new()
			_thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			add_child(_thumb)
			_thumb.set_look(Appearance.for_outfit({}, str(item.value)), "", "stand")
		if locked:
			modulate = Color(1, 1, 1, 0.45)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var kind := str(item.get("kind", ""))
		var col := Color(str(item.get("value", "#ffffff"))) if kind != "character" else Color.WHITE
		var c := size * 0.5
		if kind == "trail":
			var line := PackedVector2Array()
			for i in 14:
				var k := float(i) / 13.0
				line.append(c + Vector2(-72 + i * 9.5, 24 - sin(k * 2.6) * 30.0))
			_cv.stroke(line, 18.0, Color(col, 0.75), 0.95, 0.05, 1.0, 0.0, 0.0, 0.0)
			_cv.stroke(InkCanvas.offset_line(line, 7.0), 1.6, Color(InkCanvas.INK, 0.45), 0.9, 0.1)
			_ball(c + Vector2(62, -36), 17.0, Color.WHITE)
		elif kind == "ball":
			_ball(c, 34.0, col)
		_cv.flush(get_canvas_item())
		if locked:
			var f := UITheme.heading_font()
			draw_string_outline(f, c + Vector2(-10, 62), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 8, UITheme.PAPER)
			draw_string(f, c + Vector2(-10, 62), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, UITheme.INK)

	func _ball(p: Vector2, r: float, col: Color) -> void:
		_cv.ellipse(p, Vector2(r, r), col)
		_cv.crescent(p, r * 0.97, Vector2(-r * 0.26, -r * 0.24), col.darkened(0.16))
		for k in 3:
			var a := 0.6 + TAU * k / 3.0
			_cv.stroke(InkCanvas.arc_pts(p + Vector2(cos(a), sin(a)) * r * 0.52, r * 0.16, a + 1.2, a + 2.6, 4), maxf(1.2, r * 0.08), col.darkened(0.32), 0.2, 0.2)
		_cv.ink_circle(p, Vector2(r, r), maxf(2.2, r * 0.1), InkCanvas.INK, r)


## The pack before it opens: a hand-drawn foil pack floating on the table. Click it (or wait) and
## it shakes, tears and bursts into ink sparks; then `opened` fires and the cards are revealed.
class PackStage extends Control:
	signal opened
	var rarity := "common"
	var _t := 0.0
	var _phase := 0           ## 0 float, 1 shake, 2 burst
	var _phase_t := 0.0
	var _sparks: Array[Dictionary] = []
	var _cv := InkCanvas.new()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var hint := UITheme.styled_label("Click the pack to open it", 34, UITheme.PAPER, 9)
		hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		hint.position.y -= 150
		add_child(hint)
		Sfx.play("pop", -10.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and _phase == 0:
			_start_shake()
			accept_event()

	func _start_shake() -> void:
		_phase = 1
		_phase_t = 0.0
		Sfx.play("swing", -8.0)

	func _process(delta: float) -> void:
		_t += delta
		_phase_t += delta
		if _phase == 0 and (_t > 2.6 and OS.get_cmdline_user_args().has("--dev-reveal")):
			_start_shake()
		if _phase == 1 and _phase_t > 0.45:
			_phase = 2
			_phase_t = 0.0
			Sfx.play("fanfare" if rarity in ["epic", "legendary"] else "pop", -4.0)
			var col := Cosmetics.rarity_color(rarity)
			for i in 34:
				var a := randf() * TAU
				_sparks.append({"p": size * 0.5, "v": Vector2.from_angle(a) * randf_range(250, 760), "c": [col, UITheme.SUN, UITheme.PAPER, InkCanvas.INK][i % 4],
					"r": randf_range(5, 12), "kind": i % 3})
		if _phase == 2:
			for sp in _sparks:
				sp.v = (sp.v as Vector2) * (1.0 - 2.2 * delta) + Vector2(0, 420 * delta)
				sp.p = (sp.p as Vector2) + (sp.v as Vector2) * delta
			if _phase_t > 0.55:
				_phase = 3
				opened.emit()
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var col := Cosmetics.rarity_color(rarity)
		if _phase <= 1:
			var bob := sin(_t * 2.0) * 10.0
			var shake := Vector2(sin(_phase_t * 70.0) * 9.0 * _phase_t * 2.0, 0) if _phase == 1 else Vector2.ZERO
			var rot := sin(_t * 1.3) * 0.05 + (sin(_phase_t * 55.0) * 0.08 if _phase == 1 else 0.0)
			_cv.xf = Transform2D(rot, c + Vector2(0, bob - 40) + shake)
			_pack(col)
			_cv.xf = Transform2D.IDENTITY
		else:
			var flash := clampf(1.0 - _phase_t * 3.0, 0.0, 1.0)
			if flash > 0.0:
				for i in 14:
					var a := TAU * i / 14.0
					_cv.stroke(PackedVector2Array([c + Vector2.from_angle(a) * 60.0, c + Vector2.from_angle(a) * (60.0 + 260.0 * (1.0 - flash))]), 8.0 * flash + 1.0, Color(col, flash), 0.1, 0.8)
			for sp in _sparks:
				var p: Vector2 = sp.p
				var r: float = sp.r
				match int(sp.kind):
					0:
						InkIcons._spark(_cv, p, r, sp.c)
					1:
						_cv.stroke(PackedVector2Array([p, p - (sp.v as Vector2) * 0.03]), 3.0, sp.c, 0.1, 0.8)
					_:
						_cv.ellipse(p, Vector2(r * 0.5, r * 0.5), sp.c)
						_cv.ink_circle(p, Vector2(r * 0.5, r * 0.5), 1.4, InkCanvas.INK, r)
		_cv.flush(get_canvas_item())

	func _pack(col: Color) -> void:
		var w := 140.0
		var h := 200.0
		var body := PackedVector2Array([Vector2(-w * 0.5, -h * 0.42), Vector2(-w * 0.42, -h * 0.5), Vector2(w * 0.42, -h * 0.5), Vector2(w * 0.5, -h * 0.42),
			Vector2(w * 0.5, h * 0.44), Vector2(w * 0.4, h * 0.5), Vector2(-w * 0.4, h * 0.5), Vector2(-w * 0.5, h * 0.44)])
		_cv.fill(body, UITheme.CORAL.lerp(col, 0.35))
		# Crimped foil edges top and bottom.
		for top: float in [-1.0, 1.0]:
			var y := h * 0.42 * top
			for i in 8:
				var x := -w * 0.45 + i * w * 0.9 / 7.0
				_cv.stroke(PackedVector2Array([Vector2(x, y), Vector2(x, y + 10.0 * top)]), 2.0, Color(InkCanvas.INK, 0.5), 0.1, 0.1)
		# Sticker label with a golf ball and a swirl.
		var label := InkStyleBox.outline_pts(Rect2(Vector2(-w * 0.36, -h * 0.22), Vector2(w * 0.72, h * 0.46)), 14.0, 1.2, 4.0)
		_cv.fill(label, UITheme.PAPER)
		_cv.outline(label, 2.4, InkCanvas.INK, 2.0)
		_cv.ellipse(Vector2(0, -6), Vector2(24, 24), Color.WHITE)
		_cv.crescent(Vector2(0, -6), 23.0, Vector2(-6, -6), Color("e3ddd2"))
		_cv.ink_circle(Vector2(0, -6), Vector2(24, 24), 2.6, InkCanvas.INK, 3.0)
		var swirl := PackedVector2Array()
		for k in 26:
			swirl.append(Vector2(0, -6) + Vector2.from_angle(k * 0.45) * (34.0 + k * 0.7))
		_cv.stroke(swirl, 3.0, col, 0.2, 0.7)
		var glow := 0.5 + 0.5 * sin(_t * 3.0)
		InkIcons._spark(_cv, Vector2(w * 0.3, -h * 0.34), 9.0 + glow * 3.0, UITheme.SUN)
		InkIcons._spark(_cv, Vector2(-w * 0.3, h * 0.33), 7.0 + glow * 2.0, UITheme.PAPER)
		_cv.outline(body, 3.4, InkCanvas.INK, 1.0)


## One card in a pack reveal: shows its back, then flips to the item.
class RevealCard extends Control:
	var item: Dictionary = {}
	var is_new := false
	var refund := 0
	var _shown := false
	var _art: ItemArt
	var _glow := 0.0
	var _cv := InkCanvas.new()

	func _ready() -> void:
		pivot_offset = custom_minimum_size * 0.5

	func reveal(animate: bool) -> void:
		if not animate:
			_flip()
			return
		var tw := create_tween()
		tw.tween_property(self, "scale:x", 0.0, 0.14).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(_flip)
		tw.tween_property(self, "scale:x", 1.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var tw2 := create_tween()
		tw2.tween_method(func(v: float) -> void:
			_glow = v
			queue_redraw(), 1.0, 0.25, 0.9)

	func _flip() -> void:
		_shown = true
		_art = ItemArt.new()
		_art.item = item
		_art.position = Vector2(20, 44)
		_art.size = Vector2(size.x - 40, 170)
		add_child(_art)
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var col := Cosmetics.rarity_color(str(item.get("rarity", "common")))
		var shape := InkStyleBox.outline_pts(r, 18.0, 1.6, size.x + float(str(item.get("name", "")).length()))
		if not _shown:
			_cv.fill(shape, Color("3b6fb8"))
			var inner := InkStyleBox.outline_pts(r.grow(-12.0), 12.0, 1.0, 3.0)
			_cv.outline(inner, 2.4, Color(UITheme.PAPER, 0.8), 2.0)
			var swirl := PackedVector2Array()
			for k in 40:
				swirl.append(r.get_center() + Vector2.from_angle(k * 0.42) * (6.0 + k * 1.9))
			_cv.stroke(swirl, 4.0, Color(UITheme.PAPER, 0.85), 0.2, 0.6)
			_cv.outline(shape, 3.4, InkCanvas.INK, 1.0)
			_cv.flush(get_canvas_item())
			return
		if _glow > 0.0:
			for i in 16:
				var a := TAU * i / 16.0 + _glow
				var c := r.get_center()
				_cv.stroke(PackedVector2Array([c + Vector2.from_angle(a) * size.y * 0.55, c + Vector2.from_angle(a) * size.y * (0.55 + 0.25 * _glow)]), 5.0 * _glow + 1.0, Color(col, _glow), 0.1, 0.7)
		_cv.fill(shape, UITheme.PAPER)
		var band := Geometry2D.intersect_polygons(shape, PackedVector2Array([Vector2(-4, -4), Vector2(size.x + 4, -4), Vector2(size.x + 4, 40), Vector2(-4, 40)]))
		for part in band:
			_cv.fill(part, col.lerp(UITheme.PAPER, 0.35))
		_cv.outline(shape, 3.6, InkCanvas.INK, 2.0)
		_cv.outline(InkStyleBox.outline_pts(r.grow(-7.0), 13.0, 1.0, 5.0), 2.2, col, 3.0)
		_cv.flush(get_canvas_item())
		var f := UITheme.heading_font()
		draw_string(f, Vector2(0, 31), str(item.get("rarity", "")).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 21, InkCanvas.INK)
		draw_string(f, Vector2(0, size.y - 52), str(item.get("name", "")), HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, InkCanvas.INK)
		var tag := "NEW!" if is_new else "+%d coins" % refund
		draw_string(f, Vector2(0, size.y - 20), tag, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, UITheme.GRASS_DARK if is_new else UITheme.TROPHY.darkened(0.25))
