extends Node
## Entry point. Routes to the dedicated server, a developer shortcut, or the main menu.
##
## Command-line (after `--`):
##   --server [--port 7777] ...          run as a headless dedicated game server (see game_server.gd)
##   --practice [--course id] [--hole n] jump straight into practice
##   --connect host:port --dev-name NAME developer direct-connect to a server started with --insecure-dev
##   --profile NAME                      use a separate local identity (multiple test clients on one PC)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--server") or OS.has_feature("dedicated_server"):
		get_tree().change_scene_to_file.call_deferred("res://scenes/server.tscn")
		return
	get_window().min_size = Vector2i(1024, 576)
	if args.has("--studio"):
		Router.goto(Router.CUSTOMIZE)
	elif args.has("--courses"):
		Router.goto(Router.COURSES)
	elif args.has("--collection"):
		Router.goto(Router.COLLECTION)
	elif args.has("--stroke"):
		Router.goto(Router.GAME, {"mode": "stroke", "course": _arg(args, "--course", "golf_land"), "hole": int(_arg(args, "--hole", "0"))})
	elif args.has("--practice"):
		Router.goto(Router.GAME, {"mode": "practice", "course": _arg(args, "--course", "golf_land"),
			"hole": int(_arg(args, "--hole", "0")), "lab": args.has("--lab")})
	elif args.has("--connect"):
		var hp := _arg(args, "--connect", "127.0.0.1:7777").split(":")
		Router.goto(Router.GAME, {"mode": "online", "host": hp[0], "port": int(hp[1]) if hp.size() > 1 else 7777,
			"token": "dev:" + _arg(args, "--dev-name", "Dev%d" % (randi() % 1000)), "matchId": "dev", "queueMode": "private"})
	else:
		Router.goto(Router.MAIN_MENU)


static func _arg(args: PackedStringArray, key: String, fallback: String) -> String:
	var i := args.find(key)
	return args[i + 1] if i != -1 and i + 1 < args.size() else fallback
