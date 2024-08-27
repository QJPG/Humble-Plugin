#WARNING: Multiplayer Extension for Server & Client to Humble Multiplayers

extends MultiplayerAPIExtension

class_name HumbleMultiplayerExt

class MultiplayerConfig extends RefCounted:
	var debug_enabled : bool
	
	func _init() -> void:
		return

signal peer_auth_failed(peer : int)
signal peer_auth_waiting(peer : int)

var multiplayer_config : MultiplayerConfig = null
var _base_api : SceneMultiplayer = null
var packet_received_callback : Callable
var peer_auth_callback : Callable

func is_debug_enabled() -> bool:
	return multiplayer_config and multiplayer_config.debug_enabled

func send_bytes(peer : int, bytes : PackedByteArray, mode : MultiplayerPeer.TransferMode, channel : int = 0) -> void:
	_base_api.send_bytes(bytes, peer, mode, channel)

func send_auth(peer : int, data : PackedByteArray) -> void:
	_base_api.send_auth(peer, data)

func accept_peer_auth(peer : int) -> Error:
	return _base_api.complete_auth(peer)

func _init() -> void:
	multiplayer_config = MultiplayerConfig.new()
	_base_api = SceneMultiplayer.new()
	
	_base_api.auth_callback = peer_auth_callback
	
	if packet_received_callback:
		_base_api.peer_packet.connect(
			func(peer : int, packet : PackedByteArray):
				if is_debug_enabled():
					print_debug("[PEER::PACKET] @%s (length: %s)" % [
						peer, packet.size()
					])
				
				packet_received_callback.call(peer, packet)
		)
	
	_base_api.peer_authentication_failed.connect(
		func(peer : int):
			peer_auth_failed.emit(peer)
			
			if is_debug_enabled():
				print_debug("[PEER::AUTH] Failed! @%s" % peer)
	)
	
	_base_api.peer_authenticating.connect(
		func(peer : int) -> void:
			peer_auth_waiting.emit(peer)
			
			if is_debug_enabled():
				print_debug("[PEER::AUTH] Waiting authentication... -> @%s" % peer)
	)
	
	_base_api.connected_to_server.connect(
		func():
			connected_to_server.emit()
			
			if is_debug_enabled():
				print_debug("[NETWORK::CLIENT_CONNECTION::STATUS] Connected!")
	)
	
	_base_api.server_disconnected.connect(
		func():
			server_disconnected.emit()
			
			if is_debug_enabled():
				print_debug("[NETWORK::CLIENT_CONNECTION::STATUS] Disconnected!")
	)
	
	_base_api.connection_failed.connect(
		func():
			connection_failed.emit()
			
			if is_debug_enabled():
				print_debug("[NETWORK::CLIENT_CONNECTION::STATUS] Connection failed!")
	)
	
	_base_api.peer_connected.connect(
		func(peer : int):
			peer_connected.emit(peer)
			
			if is_debug_enabled():
				print_debug("[NETWORK::PEER_CONNECTION::STATUS] (->)Connected! @%s" % peer)
	)
	
	_base_api.peer_disconnected.connect(
		func(peer : int):
			peer_disconnected.emit(peer)
			
			if is_debug_enabled():
				print_debug("[NETWORK::PEER_CONNECTION::STATUS] (<-)Disconnected! @%s" % peer)
	)


func _poll() -> Error:
	return _base_api.poll()

func _rpc(peer: int, object: Object, method: StringName, args: Array) -> Error:
	if not peer in _base_api.get_peers():
		printerr("PEER IS UNKNOWN: %s" % peer)
	
	return _base_api.rpc(peer, object, method, args)

func _get_multiplayer_peer() -> MultiplayerPeer:
	return _base_api.multiplayer_peer

func _get_peer_ids() -> PackedInt32Array:
	return _base_api.get_peers()

func _get_remote_sender_id() -> int:
	return _base_api.get_remote_sender_id()

func _get_unique_id() -> int:
	return _base_api.get_unique_id()

func _object_configuration_add(object: Object, configuration: Variant) -> Error:
	return _base_api.object_configuration_add(object, configuration)

func _object_configuration_remove(object: Object, configuration: Variant) -> Error:
	return _base_api.object_configuration_remove(object, configuration)

func get_queue_peers() -> PackedInt32Array:
	return _base_api.get_authenticating_peers()

func disconnect_peer(peer : int, reason : PackedByteArray = PackedByteArray([])) -> void:
	if reason.size() > 0:
		send_bytes(peer, reason, MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	
	_base_api.disconnect_peer(peer)
	
	if is_debug_enabled():
		print_debug("[PEER::CONNECTION] Disconnecting peer -> @%s! (reason length: %s)" % [
			peer, reason.size()
		])

func _set_multiplayer_peer(multiplayer_peer: MultiplayerPeer) -> void:
	_base_api.multiplayer_peer = multiplayer_peer
