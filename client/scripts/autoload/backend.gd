extends Node
## HTTP client for the Fairway backend (accounts, profile, matchmaking, rooms).
## All calls are async: `var res := await Backend.get_json("/v1/me")`.
## Result shape: {ok: bool, status: int, data: Variant, code: String, message: String}

signal profile_changed(profile: Dictionary)
signal session_changed

const TIMEOUT := 8.0

var session_token: String = ""
var player_id: String = ""
var profile: Dictionary = {}
var last_error: String = ""
## Local identity slot. Launch with `-- --profile NAME` to run several test clients on one PC.
var local_profile: String = "default"
var _logging_in := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--profile")
	if i != -1 and i + 1 < args.size():
		local_profile = args[i + 1].validate_filename()


func base_url() -> String:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--backend")
	if i != -1 and i + 1 < args.size():
		return args[i + 1].trim_suffix("/")
	return str(Settings.get_value("network", "backend_url")).trim_suffix("/")


func is_logged_in() -> bool:
	return session_token != ""


# ---------------------------------------------------------------------------
# Credentials (recoverable local guest identity)
# ---------------------------------------------------------------------------

func _cred_path() -> String:
	return "user://profiles/%s/account.dat" % local_profile


func _cred_pass() -> String:
	return "fairway-%s" % OS.get_unique_id()


func has_saved_identity() -> bool:
	return FileAccess.file_exists(_cred_path())


func _load_creds() -> Dictionary:
	if not FileAccess.file_exists(_cred_path()):
		return {}
	var f := FileAccess.open_encrypted_with_pass(_cred_path(), FileAccess.READ, _cred_pass())
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


func _save_creds(device_id: String, device_secret: String) -> void:
	DirAccess.make_dir_recursive_absolute(_cred_path().get_base_dir())
	var f := FileAccess.open_encrypted_with_pass(_cred_path(), FileAccess.WRITE, _cred_pass())
	if f:
		f.store_string(JSON.stringify({"deviceId": device_id, "deviceSecret": device_secret, "backend": base_url()}))


func forget_identity() -> void:
	if FileAccess.file_exists(_cred_path()):
		DirAccess.remove_absolute(_cred_path())
	session_token = ""
	player_id = ""
	profile = {}
	session_changed.emit()


# ---------------------------------------------------------------------------
# Session
# ---------------------------------------------------------------------------

## Logs in with the saved guest identity, or creates one. Returns true on success.
func ensure_session(create_if_missing: bool = true, display_name: String = "") -> bool:
	if session_token != "":
		return true
	while _logging_in:
		await get_tree().process_frame
	if session_token != "":
		return true
	_logging_in = true
	var creds := _load_creds()
	var body := {}
	if creds.has("deviceId"):
		body = {"deviceId": creds.deviceId, "deviceSecret": creds.deviceSecret}
	elif not create_if_missing:
		_logging_in = false
		return false
	elif display_name != "":
		body = {"displayName": display_name}
	var res := await _request(HTTPClient.METHOD_POST, "/v1/auth/guest", body, false)
	_logging_in = false
	if not res.ok:
		last_error = res.code
		return false
	var d: Dictionary = res.data
	if d.has("deviceSecret"):
		_save_creds(str(d.deviceId), str(d.deviceSecret))
	session_token = str(d.sessionToken)
	player_id = str(d.playerId)
	_set_profile(d.get("profile", {}))
	session_changed.emit()
	return true


func logout() -> void:
	if session_token != "":
		await _request(HTTPClient.METHOD_POST, "/v1/auth/logout", null, true)
	session_token = ""
	session_changed.emit()


func _set_profile(p: Dictionary) -> void:
	profile = p
	profile_changed.emit(profile)


func refresh_profile() -> Dictionary:
	var res := await get_json("/v1/me")
	if res.ok:
		_set_profile(res.data)
	return res


func update_profile(patch: Dictionary) -> Dictionary:
	var res := await send_json(HTTPClient.METHOD_PATCH, "/v1/me", patch)
	if res.ok:
		_set_profile(res.data)
	return res


# ---------------------------------------------------------------------------
# Requests
# ---------------------------------------------------------------------------

func get_json(path: String) -> Dictionary:
	return await _authed(HTTPClient.METHOD_GET, path, null)


func send_json(method: HTTPClient.Method, path: String, body: Variant = {}) -> Dictionary:
	return await _authed(method, path, body)


func _authed(method: HTTPClient.Method, path: String, body: Variant) -> Dictionary:
	if not await ensure_session():
		return {"ok": false, "status": 0, "data": null, "code": last_error if last_error != "" else "offline", "message": "Not signed in"}
	var res := await _request(method, path, body, true)
	if res.status == 401:
		# Session expired or revoked: log in again once and retry.
		session_token = ""
		if await ensure_session(false):
			res = await _request(method, path, body, true)
	return res


func _request(method: HTTPClient.Method, path: String, body: Variant, auth: bool) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	http.use_threads = false
	add_child(http)
	var headers := PackedStringArray(["Accept: application/json"])
	var payload := ""
	if body != null:
		headers.append("Content-Type: application/json")
		payload = JSON.stringify(body)
	if auth and session_token != "":
		headers.append("Authorization: Bearer %s" % session_token)
	var err := http.request(base_url() + path, headers, method, payload)
	if err != OK:
		http.queue_free()
		return {"ok": false, "status": 0, "data": null, "code": "offline", "message": "Could not reach the game servers."}
	var out: Array = await http.request_completed
	http.queue_free()
	var result: int = out[0]
	var status: int = out[1]
	var raw: PackedByteArray = out[3]
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status": 0, "data": null, "code": "offline", "message": "Could not reach the game servers."}
	var data: Variant = null
	if raw.size() > 0:
		data = JSON.parse_string(raw.get_string_from_utf8())
	var ok := status >= 200 and status < 300
	var code := ""
	var message := ""
	if not ok:
		if data is Dictionary and data.has("error"):
			code = str(data.error.get("code", "error"))
			message = str(data.error.get("message", ""))
		else:
			code = "http_%d" % status
	return {"ok": ok, "status": status, "data": data, "code": code, "message": message}


static func friendly_error(res: Dictionary) -> String:
	match str(res.get("code", "")):
		"offline":
			return "Can't reach the game servers. Check your connection or try again shortly."
		"no_server":
			return "All game servers are busy right now. Please try again in a moment."
		"conflict":
			return str(res.get("message", "You're already in a queue, room or match."))
		"not_found":
			return str(res.get("message", "Not found."))
		"rate_limited":
			return "Slow down a little and try again."
		_:
			var m := str(res.get("message", ""))
			return m if m != "" else "Something went wrong (%s)." % str(res.get("code", "error"))
