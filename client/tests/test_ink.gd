extends SceneTree
## Hand-drawn art checks (docs/INK_ART_SPEC.md): every outfit and catalog golfer renders, every
## clip solves to finite poses with the club attached to the hands, looks round-trip through
## Appearance, v1 profiles migrate, drawings are bounded, and still renders stay in sane bounds.
##   godot --headless --path client --script res://tests/test_ink.gd

var _fails := 0
var _checks := 0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  FAIL ", what)


func _finite(v: Vector2) -> bool:
	return is_finite(v.x) and is_finite(v.y)


func _initialize() -> void:
	print("Ink art")
	# Outfits: every collectible character id is a themed outfit; looks normalise cleanly.
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	for it: Dictionary in (catalog as Dictionary).get("items", []):
		if str(it.kind) == "character":
			_check(InkLook.has_outfit(str(it.value)), "catalog golfer '%s' is an outfit" % it.value)
	for id: String in InkLook.outfit_ids(true):
		var a := Appearance.for_outfit({}, id)
		_check(str(a.character) == id, "%s: outfit id kept" % id)
		var again := Appearance.normalize(JSON.parse_string(JSON.stringify(a)))
		_check(JSON.stringify(again) == JSON.stringify(a), "%s: look survives a JSON round trip" % id)
		var cv := InkCanvas.new()
		Golfer.draw_still(cv, a, "stand")
		_check(cv.vertex_count() > 200, "%s: still render has geometry" % id)
		var b := cv.bounds
		_check(b.size.y > 60.0 and b.size.y < 160.0 and b.size.x < 120.0, "%s: bounds %s are sane" % [id, b])
	# v1 migration: a roster character becomes its outfit; a customised v1 stickman keeps colours.
	var v1 := {"v": 1, "character": "frost", "bodyColor": "#2b2d42"}
	_check(str(Appearance.normalize(v1).ink.hat) == "beanie", "v1 'frost' migrates to the Frost outfit")
	var v1b := {"v": 1, "character": "stickman", "bodyColor": "#e63946", "hat": "cap", "shirt": "hoodie"}
	var m: Dictionary = Appearance.normalize(v1b).ink
	_check(str(m.pantsColor) == "#e63946" and str(m.hat) == "cap" and str(m.top) == "hoodie", "v1 stickman keeps colour, hat and shirt")
	# Every clip solves to finite poses; when gripped, the club starts at the hands.
	var clips: Array = InkAnims.CLIPS.keys() + ["aim"]
	for name: String in clips:
		var c := InkAnims.clip(name)
		var steps := 12
		for k in steps + 1:
			var t := float(c.len) * k / steps
			var s := InkRig.solve(InkRig.aim_params(float(k) / steps)) if name == "aim" else InkRig.evaluate(name, t)
			var ok := true
			for key: String in ["hip", "neck", "head", "shoulder", "hb", "hf", "fb", "ff", "grip", "hosel"]:
				ok = ok and _finite(s[key])
			_check(ok, "%s t=%.2f: finite pose" % [name, t])
			if bool(s.grip_mode):
				_check((s.hf as Vector2).distance_to(s.grip) < 8.0, "%s t=%.2f: club in the hands" % [name, t])
			var reach := (s.shoulder as Vector2).distance_to(s.hf)
			_check(reach <= InkRig.UPPER + InkRig.FORE + 1.0, "%s t=%.2f: arm length respected (%.1f)" % [name, reach, t])
	# Address: the club sole reaches the ground just behind the ball.
	var addr := InkRig.evaluate("idle", 0.0)
	_check(absf((addr.hosel as Vector2).y - InkRig.HOSEL_TARGET.y) < 1.5 and (addr.hosel as Vector2).x < InkRig.BALL_OFFSET - 6.0, "address grounds the club behind the ball")
	# Golfer node: plays every clip and emote without errors.
	var g := Golfer.new()
	g.set_appearance(Appearance.for_outfit({}, "knight"))
	get_root().add_child(g)
	for name: String in InkAnims.CLIPS:
		g.play(name)
		g.set_time(0.3, 0.3)
	for e: Dictionary in Emotes.LIST:
		g.emote(str(e.id))
		g.set_time(0.5, 0.5)
	g.swing(0.8)
	g.set_time(Golfer.IMPACT, Golfer.IMPACT)
	_check(g.head_height() > 60.0, "head height reported (%.1f)" % g.head_height())
	g.free()
	# Drawings: limits and sanitising.
	var big := {"v": 1, "legs": "both", "strokes": []}
	for i in 60:
		big.strokes.append({"c": "#ff0000", "w": 50.0, "a": 3.0, "p": [0, 0, 2000, -5, 500, 500]})
	var n := InkDrawing.normalize(big)
	_check((n.strokes as Array).size() == InkDrawing.MAX_STROKES, "drawings keep at most %d strokes" % InkDrawing.MAX_STROKES)
	var s0: Dictionary = n.strokes[0]
	_check(float(s0.w) <= InkDrawing.MAX_W and float(s0.a) <= 1.0 and int(s0.p[2]) == 1000 and int(s0.p[3]) == 0, "drawing values are clamped")
	_check(InkDrawing.point_count(n) <= InkDrawing.MAX_POINTS, "drawing point budget respected")
	# Signature parts name real outfits.
	for key: String in InkLook.SIGNATURE:
		for v: String in InkLook.SIGNATURE[key]:
			_check(InkLook.has_outfit(InkLook.signature_outfit(key, v)), "signature %s=%s names an outfit" % [key, v])
			_check((InkLook.OPTIONS[key] as Dictionary).has(v), "signature %s=%s is a real option" % [key, v])
	print("ink: %d checks, %d failures" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
