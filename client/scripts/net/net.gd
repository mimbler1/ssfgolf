extends Node
## RPC bridge shared by the dedicated server and the game client.
## The same script runs on both sides (Godot RPCs require matching node paths and
## signatures); it forwards calls to whichever handler is registered.
##
## Channel 0: reliable commands and events. Channel 1: unreliable snapshots.

const CH_SNAPSHOT := 1

## Server side: object implementing on_hello/on_shoot/on_activate/on_reset/on_emote/on_leave/on_ping.
var server_handler: Object = null
## Client side: object implementing on_welcome/on_reject/on_event/on_snapshot/on_pong/on_cmd_result.
var client_handler: Object = null


func is_server() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server() and server_handler != null


func host(port: int, max_clients: int) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_clients, 2)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func join(address: String, port: int) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port, 2)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


## Closes after a short delay so already-queued reliable messages (e.g. "leave") are sent.
func close_after(seconds: float) -> void:
	var peer := multiplayer.multiplayer_peer
	await get_tree().create_timer(seconds).timeout
	if multiplayer.multiplayer_peer == peer:
		close()


func close() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null


func _sender() -> int:
	return multiplayer.get_remote_sender_id()


# ---------------------------------------------------------------------------
# Client -> server
# ---------------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func c_hello(token: String, protocol: int, version: String) -> void:
	if server_handler:
		server_handler.on_hello(_sender(), token, protocol, version)


@rpc("any_peer", "call_remote", "reliable")
func c_shoot(seq: int, angle: float, power: float, ability: int) -> void:
	if server_handler:
		server_handler.on_shoot(_sender(), seq, angle, power, ability)


@rpc("any_peer", "call_remote", "reliable")
func c_activate(seq: int) -> void:
	if server_handler:
		server_handler.on_activate(_sender(), seq)


@rpc("any_peer", "call_remote", "reliable")
func c_reset(seq: int) -> void:
	if server_handler:
		server_handler.on_reset(_sender(), seq)


@rpc("any_peer", "call_remote", "reliable")
func c_emote(emote: int) -> void:
	if server_handler:
		server_handler.on_emote(_sender(), emote)


@rpc("any_peer", "call_remote", "reliable")
func c_leave() -> void:
	if server_handler:
		server_handler.on_leave(_sender())


@rpc("any_peer", "call_remote", "unreliable")
func c_ping(client_time: float) -> void:
	if server_handler:
		server_handler.on_ping(_sender(), client_time)


# ---------------------------------------------------------------------------
# Server -> client
# ---------------------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func s_welcome(data: Dictionary) -> void:
	if client_handler:
		client_handler.on_welcome(data)


@rpc("authority", "call_remote", "reliable")
func s_reject(reason: String) -> void:
	if client_handler:
		client_handler.on_reject(reason)


@rpc("authority", "call_remote", "reliable")
func s_event(ev: Dictionary) -> void:
	if client_handler:
		client_handler.on_event(ev)


@rpc("authority", "call_remote", "unreliable_ordered", CH_SNAPSHOT)
func s_snapshot(data: PackedByteArray) -> void:
	if client_handler:
		client_handler.on_snapshot(data)


@rpc("authority", "call_remote", "unreliable")
func s_pong(client_time: float, server_time: float) -> void:
	if client_handler:
		client_handler.on_pong(client_time, server_time)


@rpc("authority", "call_remote", "reliable")
func s_cmd_result(seq: int, error: String) -> void:
	if client_handler:
		client_handler.on_cmd_result(seq, error)
