extends Node

class_name HumbleNetRemoteEvent

enum JoinErrors {
	IS_IN_OTHER_ROOM,
	IS_FULL,
	REFUSED,
	NOT_FOUND,
}

var room_created_callback : Callable
var room_event_callback : Callable
var room_entered_callback : Callable
var room_exited_callback : Callable
var room_player_entered_callback : Callable
var room_player_exited_callback : Callable
var room_player_authority_changed_callback : Callable
var room_joinned_room_error_callback : Callable

func _enter_tree() -> void:
	get_tree().set_multiplayer(HumbleMultiplayerExt.new())

func _exit_tree() -> void:
	multiplayer.multiplayer_peer = null

func connect_to_server(address : String, port : int) -> void:
	var enet_network := ENetMultiplayerPeer.new()
	enet_network.create_client(address, port)
	multiplayer.multiplayer_peer = enet_network

func create_room(is_private : bool, capacity : int, config := {}) -> void:
	multiplayer.rpc(1, HumbleNetManagerService, "_rpc_create_room", [is_private, capacity, config])

func join_room(code : String) -> void:
	multiplayer.rpc(1, HumbleNetManagerService, "_rpc_join_room", [code])

func exit_room() -> void:
	multiplayer.rpc(1, HumbleNetManagerService, "_rpc_exit_room", [])

func remove_room(data : Variant = null) -> void:
	multiplayer.rpc(1, HumbleNetManagerService, "_rpc_remove_room", [data])

func kick_player(peer : int, data : Variant = null) -> void:
	multiplayer.rpc(1, HumbleNetManagerService, "_rpc_kick_player", [peer, data])

func send_room(data : Variant, target := PackedInt32Array([])) -> void:
	multiplayer.rpc(1, HumbleNetManagerService, "_rpc_send_room", [data, target])

func add_authority(peer : int) -> void:
	multiplayer.rpc(1, HumbleNetManagerService, "_rpc_set_player_authority", [peer, true])

func revoke_authority(peer : int) -> void:
	multiplayer.rpc(1, HumbleNetManagerService, "_rpc_set_player_authority", [peer, false])

func set_room_config(config : HumbleNetManager.RoomState.RoomConfigs, value : Variant) -> void:
	multiplayer.rpc(1, HumbleNetManagerService, "_rpc_set_room_config", [config, value])

func set_room_closed(closed : bool) -> void:
	multiplayer.rpc(1, HumbleNetManagerService, "_rpc_set_room_closed", [closed])

@rpc("authority", "call_remote", "reliable")
func _rpc_room_created(code : String) -> void:
	if room_created_callback:
		room_created_callback.call(code)

@rpc("authority", "call_remote", "reliable")
func _rpc_room_event(what : Variant) -> void:
	if room_event_callback:
		room_event_callback.call(what)

@rpc("authority", "call_remote", "reliable")
func _rpc_room_entered(data : Variant = null) -> void:
	if room_entered_callback:
		room_entered_callback.call(data)

@rpc("authority", "call_remote", "reliable")
func _rpc_room_exited(data : Variant = null) -> void:
	if room_exited_callback:
		room_exited_callback.call(data)

@rpc("authority", "call_remote", "reliable")
func _rpc_room_player_entered(peer : int, data : Variant = null) -> void:
	if room_player_entered_callback:
		room_player_entered_callback.call(peer, data)

@rpc("authority", "call_remote", "reliable")
func _rpc_room_player_exited(peer : int, data : Variant = null) -> void:
	if room_player_exited_callback:
		room_player_exited_callback.call(peer, data)

@rpc("authority", "call_remote", "reliable")
func _rpc_room_player_authority_changed(has : bool) -> void:
	if room_player_authority_changed_callback:
		room_player_authority_changed_callback.call(has)

@rpc("authority", "call_remote", "reliable")
func _rpc_join_room_error(reason : JoinErrors) -> void:
	if room_joinned_room_error_callback:
		room_joinned_room_error_callback.call(reason)
