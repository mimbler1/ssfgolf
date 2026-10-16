class_name Cosmetics
extends RefCounted
## The cosmetic collection on the client (API.md §1.7): the catalog and what this player owns.
## Online it is fetched from the backend (authoritative); offline the bundled data/catalog.json
## (kept identical to backend/data/catalog.json by tests) is used and only default items are owned.
## Cosmetics never change gameplay.

static var catalog: Dictionary = {}
static var owned: Dictionary = {}     ## item id -> copies
static var online := false


static func ensure_loaded() -> void:
	if catalog.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
		catalog = parsed if parsed is Dictionary else {"items": [], "packs": [], "rarities": {}}
		_reset_defaults()


static func _reset_defaults() -> void:
	owned.clear()
	for i: Dictionary in catalog.get("items", []):
		if bool(i.get("default", false)):
			owned[str(i.id)] = 1


## Fetch the catalog and collection from the backend (keeps the offline data if it fails).
static func refresh() -> bool:
	ensure_loaded()
	if not Backend.is_logged_in():
		online = false
		return false
	var cat := await Backend.get_json("/v1/catalog")
	if cat.ok and cat.data is Dictionary:
		catalog = cat.data
	var col := await Backend.get_json("/v1/collection")
	if not col.ok:
		return false
	owned.clear()
	for o: Dictionary in col.data.get("owned", []):
		owned[str(o.itemId)] = int(o.copies)
	online = true
	return true


static func items(kind: String = "") -> Array[Dictionary]:
	ensure_loaded()
	var out: Array[Dictionary] = []
	for i: Dictionary in catalog.get("items", []):
		if kind == "" or str(i.kind) == kind:
			out.append(i)
	return out


static func item_for(kind: String, value: String) -> Dictionary:
	for i in items(kind):
		if str(i.value).to_lower() == value.to_lower():
			return i
	return {}


## True when the value is not a collectible (free) or is owned.
static func owns(kind: String, value: String) -> bool:
	var it := item_for(kind, value)
	return it.is_empty() or owned.has(str(it.id))


static func packs() -> Array:
	ensure_loaded()
	return catalog.get("packs", [])


static func rarity_color(r: String) -> Color:
	return {"common": Color("d9e2f2"), "rare": Color("4cc9f0"), "epic": Color("c77dff"), "legendary": Color("ffd166")}.get(r, UITheme.MUTED)
