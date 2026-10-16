extends Node
## Collection: every cosmetic in the catalog (sprite characters, ball colours, trail colours),
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
	RenderingServer.set_default_clear_color(Color("1b2040"))
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
	dim.color = Color(0.06, 0.07, 0.16, 0.6)
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
		if str(it.kind) == "character" and not CharacterDefs.ids().has(str(it.value)):
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
	var sb := UITheme.box(Color(UITheme.INK, 0.94), UITheme.RADIUS, col if have else Color(col, 0.35), 0, 0, 3)
	sb.content_margin_left = 8; sb.content_margin_right = 8; sb.content_margin_top = 8; sb.content_margin_bottom = 8
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
	shade.color = Color(0.03, 0.03, 0.08, 0.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(shade)
	_overlay = shade
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

## Draws a collectible: framed portrait (golfer), sprite ball tinted (ball), streak + ball (trail).
class ItemArt extends Control:
	var item: Dictionary = {}
	var locked := false
	var _portrait: Portrait

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if str(item.get("kind", "")) == "character":
			_portrait = Portrait.new()
			_portrait.framed = true
			_portrait.size = Vector2(128, 128)
			add_child(_portrait)
			_portrait.position = ((size - _portrait.size) * 0.5).floor()
			_portrait.set_look({"character": str(item.value)})
			resized.connect(func() -> void: _portrait.position = ((size - _portrait.size) * 0.5).floor())
		if locked:
			modulate = Color(0.45, 0.45, 0.55)

	func _draw() -> void:
		var kind := str(item.get("kind", ""))
		var col := Color(str(item.get("value", "#ffffff"))) if kind != "character" else Color.WHITE
		var c := size * 0.5
		var strip := UIArt.tex("ball/ball_tint_spin.png")
		if kind == "trail":
			for i in 14:
				var k := float(i) / 14.0
				var p := c + Vector2(-70 + i * 9.0, 22 - sin(k * 2.6) * 30.0)
				draw_rect(Rect2((p - Vector2(5, 5) * (1.0 - k * 0.5)).floor(), (Vector2(10, 10) * (1.0 - k * 0.5)).floor()), Color(col, 0.25 + k * 0.7))
			if strip:
				var fw := strip.get_width() / 8
				draw_texture_rect_region(strip, Rect2(c + Vector2(56, -34) - Vector2(18, 18), Vector2(36, 36)), Rect2(0, 0, fw, strip.get_height()), Color.WHITE)
		elif kind == "ball" and strip:
			var fw2 := strip.get_width() / 8
			draw_texture_rect_region(strip, Rect2((c - Vector2(36, 36)).floor(), Vector2(72, 72)), Rect2(0, 0, fw2, strip.get_height()), col)
		if locked:
			var f := UITheme.heading_font()
			draw_string_outline(f, c + Vector2(-9, 60), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, UITheme.INK_LINE)
			draw_string(f, c + Vector2(-9, 60), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UITheme.PAPER)


## One card in a pack reveal: shows its back, then flips to the item.
class RevealCard extends Control:
	var item: Dictionary = {}
	var is_new := false
	var refund := 0
	var _shown := false
	var _art: ItemArt
	var _glow := 0.0

	func _ready() -> void:
		pivot_offset = custom_minimum_size * 0.5
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

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
		_art.position = Vector2(20, 40)
		_art.size = Vector2(size.x - 40, 160)
		add_child(_art)
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var col := Cosmetics.rarity_color(str(item.get("rarity", "common")))
		if not _shown:
			draw_style_box(UITheme.box(Color("2b2148"), UITheme.RADIUS, UITheme.SUN, 0, 0, 4), r)
			var f0 := UITheme.heading_font()
			draw_string(f0, Vector2(0, size.y * 0.5 + 24), "?", HORIZONTAL_ALIGNMENT_CENTER, size.x, 72, Color(UITheme.SUN, 0.8))
			return
		if _glow > 0.0:
			draw_style_box(UITheme.box(Color(col, 0.0), UITheme.RADIUS + 10, Color(col, _glow * 0.6), 0, 0, int(10 * _glow)), r.grow(10))
		draw_style_box(UITheme.box(Color(UITheme.INK, 0.97), UITheme.RADIUS, col, 0, 0, 4), r)
		var f := UITheme.heading_font()
		draw_string(f, Vector2(0, 30), str(item.get("rarity", "")).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, col)
		draw_string(f, Vector2(0, size.y - 56), str(item.get("name", "")), HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, UITheme.PAPER)
		var tag := "NEW!" if is_new else "+%d coins" % refund
		draw_string(f, Vector2(0, size.y - 22), tag, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color("80ed99") if is_new else UITheme.SUN)
