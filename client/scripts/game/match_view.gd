class_name MatchView
extends Node
## Read-only view of a match for rendering plus a command interface.
## Implemented by LocalMatchView (offline practice) and NetMatchView (online, server-authoritative).

signal game_event(ev: Dictionary)
signal hole_loaded(hole_index: int, hole_number: int)
signal connection_lost(reason: String)
signal impacts(list: Array)

var course: Dictionary = {}
var course_id: String = ""
var terrain: SimTerrain
var hole_index: int = -1
var hole_number: int = 0
var local_slot: int = 0
var target_points: int = 9
var mode: String = "practice"
## Static roster: Array of {slot, playerId, name, appearance, trophies}
var roster: Array[Dictionary] = []
var allowed_abilities: PackedStringArray = PackedStringArray()
## Balance data used for the aim preview (matches the authoritative simulation).
var balance: Dictionary = {}


func player_count() -> int:
	return roster.size()


## Interpolated render state for a ball. Keys: pos, vel, rot, active, at_rest, stuck,
## grounded, finished, connected, forfeited, manual, ability (String), hazard, grenade,
## shield, ice, anti_grav, magnet, brake, boost.
func ball_state(_slot: int) -> Dictionary:
	return {}


## Latest known player state. Keys: energy, cooldown, points, hole_shots
## (stroke play also: strokes, penalties, charges).
func player_state(_slot: int) -> Dictionary:
	return {}


## Keys: phase (MatchSim.Phase), timer, hole_time, deadline.
func phase_state() -> Dictionary:
	return {}


## Predicted reason the local player cannot shoot ("" if they can).
func local_shot_block() -> String:
	return "not_ready"


func shoot(_angle: float, _power: float, _ability: String, _spin: float = 0.0) -> void:
	pass


## In-flight spin input: -1 backspin, 0 release, +1 topspin.
func spin(_dir: int) -> void:
	pass


func activate() -> void:
	pass


func reset_ball() -> void:
	pass


func emote(_id: int) -> void:
	pass


func leave() -> void:
	pass


func _load_hole(index: int, number: int) -> void:
	hole_index = index
	hole_number = number
	terrain = SimTerrain.new()
	terrain.build(course.holes[index])
	hole_loaded.emit(index, number)
