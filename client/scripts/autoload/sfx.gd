extends Node
## Lightweight pooled sound-effect playback.

const DIR := "res://assets/audio/sfx"
const POOL_SIZE := 24

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played: Dictionary = {}  ## name -> msec, throttles spammy sounds
var enabled := true


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		enabled = false
		return
	var dir := DirAccess.open(DIR)
	if dir:
		for f in dir.get_files():
			var base := f.trim_suffix(".import")
			if base.ends_with(".wav") and not _streams.has(base.get_basename()):
				var s: Resource = load(DIR.path_join(base))
				if s is AudioStream:
					_streams[base.get_basename()] = s
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)


func has(sound: String) -> bool:
	return _streams.has(sound)


## Plays a sound. `min_interval_ms` prevents the same sound stacking every frame.
func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0, min_interval_ms: int = 30) -> void:
	if not enabled or not _streams.has(sound):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -100000)) < min_interval_ms:
		return
	_last_played[sound] = now
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.play()


func play_varied(sound: String, volume_db: float = 0.0, spread: float = 0.08) -> void:
	play(sound, volume_db, 1.0 + randf_range(-spread, spread))
