extends SceneTree
## Character validation: definitions, legacy ids, and every character x animation builds a sane
## pose (club held in a hand, no NaNs, bounds within limits). Exit code 1 on failure.
##   Godot --headless --path client --script res://tests/test_characters.gd

var _fail := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fail += 1
		print("FAIL: ", msg)


func _initialize() -> void:
	for e in CharacterDefs.validate():
		_check(false, e)
	for id: String in CharacterDefs.LEGACY_IDS:
		_check(CharacterDefs.has(id), "legacy id '%s' must stay defined" % id)
		var a := Appearance.normalize({"character": id})
		_check(str(a.character) == id, "normalize keeps '%s'" % id)
	_check(str(Appearance.normalize({"character": "nope"}).character) == str(Appearance.DEFAULT.character), "unknown id falls back to the default character")
	var anims := ["idle", "aim", "swing", "watch", "celebrate", "victory", "sad", "walk", "dance"]
	for e: Dictionary in Emotes.LIST:
		anims.append(str(e.id))
	var count := 0
	for id: String in CharacterDefs.ids():
		var g := Golfer.new()
		g.set_appearance({"character": id})
		for an: String in anims:
			for t: float in [0.0, 0.04, 0.2, 0.9]:
				g.aim_power = 0.8
				if an == "swing":
					g.swing(0.8, "swing")
				elif Emotes.is_emote(an):
					g.emote(an)
				else:
					g.play(an)
				g.set_time(t, t)
				var p := g.solved_pose()
				var tag := "%s/%s@%.2f" % [id, an, t]
				_check((p.head as Vector2).is_finite() and (p.grip as Vector2).is_finite(), tag + " has NaN")
				if p.club and p.club_mode == "hands":
					var d := minf((p.hf as Vector2).distance_to(p.grip), (p.hb as Vector2).distance_to(p.grip))
					_check(d < 6.0, tag + " club detached from hands (%.1f)" % d)
				elif p.club and p.club_mode in ["front", "back"]:
					var h: Vector2 = p.hf if p.club_mode == "front" else p.hb
					_check(h.distance_to(p.grip) < 6.0, tag + " one-hand club detached")
				var b := g.visual_bounds(an, t)
				# v4 sprite golfers are ~84 art px tall at 2 world px per art px (tall hats reach ~105 px)
				var lim := 200.0 if CharacterDefs.is_sprite(id) else 160.0
				_check(b.size.y > 30.0 and b.size.y < lim and b.size.x < lim, tag + " bounds %s" % b)
				count += 1
		var ib := Golfer.idle_bounds({"character": id})
		_check(ib.end.y > -1.0 and ib.end.y < 8.0, "%s stands on the ground (bottom %.1f)" % [id, ib.end.y])
		g.free()
	# Hand-authored sprite characters: sheets load, every game animation resolves to a real
	# frame, and the art stands on the ground at the pivot.
	for id: String in CharacterDefs.ROSTER:
		if not CharacterDefs.is_sprite(id):
			continue
		var sc := SpriteCharacter.load_for(id)
		_check(sc != null, "%s: sprite sheets load" % id)
		if sc == null:
			continue
		var g := Golfer.new()
		g.set_appearance({"character": id})
		_check(str(g.appearance.character) == id, "%s: appearance keeps sprite id" % id)
		for an: String in anims:
			g.play(an)
			g.set_time(0.3, 0.3)
			var f := g.sprite_frame()
			_check(sc.anims.has(f[0]) and int(f[1]) >= 0 and int(f[1]) < (sc.anims[f[0]].frames as Array).size(), "%s/%s resolves to a frame" % [id, an])
			count += 1
		var ib := sc.idle_bounds()
		_check(absf(ib.end.y) < 0.01, "%s: sprite feet on the ground (bottom %.2f)" % [id, ib.end.y])
		_check(not CharacterDefs.ids().has(id) or not bool(CharacterDefs.ROSTER[id].get("hidden", false)), "%s: hidden ids stay out of the roster" % id)
		g.free()
	print("characters: %d poses checked, %d failures" % [count, _fail])
	quit(1 if _fail > 0 else 0)
