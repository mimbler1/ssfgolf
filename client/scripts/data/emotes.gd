class_name Emotes
extends RefCounted
## The in-match emote catalogue. The index is the wire id (Net.c_emote / "emote" events), so
## only ever append to this list. Each emote is a golfer animation plus a speech bubble.

const LIST := [
	{"id": "wave", "name": "Wave", "bubble": "HEY!", "duration": 1.8},
	{"id": "laugh", "name": "Laugh", "bubble": "HA HA!", "duration": 1.8},
	{"id": "wow", "name": "Wow", "bubble": "WOW!", "duration": 1.6},
	{"id": "thumbs_up", "name": "Good Game", "bubble": "GG!", "duration": 1.8},
	{"id": "clap", "name": "Clap", "bubble": "NICE!", "duration": 1.8},
	{"id": "facepalm", "name": "Facepalm", "bubble": "UGH...", "duration": 2.0},
	{"id": "flex", "name": "Flex", "bubble": "TOO EASY", "duration": 1.8},
	{"id": "dance", "name": "Dance", "bubble": "WOOO!", "duration": 2.4},
]


static func count() -> int:
	return LIST.size()


static func duration(anim: String) -> float:
	for e: Dictionary in LIST:
		if e.id == anim:
			return float(e.duration)
	return 0.0


static func is_emote(anim: String) -> bool:
	return duration(anim) > 0.0
