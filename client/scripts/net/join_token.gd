class_name JoinToken
extends RefCounted
## Verifies backend-issued join tokens (docs/API.md §3):
##   base64url(payloadJson) + "." + base64url(HMAC-SHA256(secret, base64url(payloadJson)))


static func b64url_encode(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").replace("=", "")


static func b64url_decode(text: String) -> PackedByteArray:
	var s := text.replace("-", "+").replace("_", "/")
	while s.length() % 4 != 0:
		s += "="
	return Marshalls.base64_to_raw(s)


static func hmac_sha256(secret: String, message: String) -> PackedByteArray:
	var ctx := HMACContext.new()
	ctx.start(HashingContext.HASH_SHA256, secret.to_utf8_buffer())
	ctx.update(message.to_utf8_buffer())
	return ctx.finish()


static func sign(secret: String, payload: Dictionary) -> String:
	var encoded := b64url_encode(JSON.stringify(payload).to_utf8_buffer())
	return encoded + "." + b64url_encode(hmac_sha256(secret, encoded))


## Returns {ok: true, matchId, playerId, exp} or {ok: false, reason}.
static func verify(secret: String, token: String, now_unix: int) -> Dictionary:
	if token.length() > 2048:
		return {"ok": false, "reason": "malformed"}
	var parts := token.split(".")
	if parts.size() != 2 or parts[0] == "" or parts[1] == "":
		return {"ok": false, "reason": "malformed"}
	var expected := b64url_encode(hmac_sha256(secret, parts[0]))
	if not _const_eq(expected, parts[1]):
		return {"ok": false, "reason": "bad_signature"}
	var parsed: Variant = JSON.parse_string(b64url_decode(parts[0]).get_string_from_utf8())
	if not parsed is Dictionary:
		return {"ok": false, "reason": "malformed"}
	var p: Dictionary = parsed
	if not (p.get("m") is String and p.get("p") is String and (p.get("exp") is float or p.get("exp") is int)):
		return {"ok": false, "reason": "malformed"}
	if now_unix >= int(p.exp):
		return {"ok": false, "reason": "expired"}
	return {"ok": true, "matchId": str(p.m), "playerId": str(p.p), "exp": int(p.exp)}


static func _const_eq(a: String, b: String) -> bool:
	if a.length() != b.length():
		return false
	var diff := 0
	for i in a.length():
		diff |= a.unicode_at(i) ^ b.unicode_at(i)
	return diff == 0
