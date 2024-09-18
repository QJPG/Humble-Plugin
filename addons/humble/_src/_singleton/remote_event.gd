extends Node

class_name _HRemoteEvent_

enum NetworkEvents {
	PARTY_CREATED,
	CONNECTED_PARTY,
	DISCONNECTED_PARTY,
	CONNECTION_ERR,
	CONNECTION_CONNECTED,
	CONNECTION_DISCONNECTED,
	AVAILABLE_INFORMATIONS,
	PARTY_EVENT,
	
	REMOTE_OBJECT_SPAWNNED,
	REMOTE_OBJECT_DESPAWNNED,
}

signal party_created(party_id : int)
signal party_connected()
signal party_disconnected(reason : HRemoteServer.NetworkReasons)
signal party_connection_error(reason : HRemoteServer.NetworkReasons)
signal party_other_connection_connected(peer : int)
signal party_other_connection_disconnected(peer : int, reason : HRemoteServer.NetworkReasons)
signal available_party_informations(informations : Dictionary)
signal party_remote_object_spawnned(alias : StringName)
signal party_remote_object_despawnned(alias : StringName)
signal party_received_event(peer : int, event : Variant)

var update_remote_objects : Dictionary

func join_server(address : String, port : int) -> void:
	var _enet := ENetMultiplayerPeer.new()
	
	if _enet.create_client(address, port) == OK:
		multiplayer.multiplayer_peer = _enet

func close_connection() -> void:
	if multiplayer and multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = null

func start_party(is_public : bool, options : Dictionary) -> void:
	#HRemoteServer._task_create_party_configuration.rpc_id(1, is_public, options)
	multiplayer.rpc(1, HRemoteServer, "_task_create_party_configuration", [is_public, options])

func connect_party(party_id : int, data : Variant = null) -> void:
	#HRemoteServer._task_join_party.rpc_id(1, party_id, data)
	multiplayer.rpc(1, HRemoteServer, "_task_join_party", [party_id, data])

func disconnect_party(party_id : int) -> void:
	#HRemoteServer._task_quit_party.rpc_id(1, party_id)
	multiplayer.rpc(1, HRemoteServer, "_task_quit_party", [party_id])

func get_available_party() -> void:
	#HRemoteServer._task_request_informations.rpc_id(1)
	multiplayer.rpc(1, HRemoteServer, "_task_request_informations", [])

func spawn_remote_object(alias : StringName, sync_properties : Dictionary, to : PackedInt32Array) -> void:
	multiplayer.rpc(1, HRemoteServer, "_task_spawn_remote_object", [alias, sync_properties, to])

func set_remote_object_authority(alias : StringName, authority : int) -> void:
	multiplayer.rpc(1, HRemoteServer, "_task_set_remote_object_authority", [alias, authority])

func update_remote_object_property(alias : StringName, property : String, value : Variant) -> void:
	multiplayer.rpc(1, HRemoteServer, "_task_update_remote_object_property", [alias, property, value])

func despawn_remote_object(alias : StringName, to : PackedInt32Array) -> void:
	multiplayer.rpc(1, HRemoteServer, "_task_despawn_remote_object", [alias, to])

func send_event(event : Variant) -> void:
	multiplayer.rpc(1, HRemoteServer, "_task_send_event", [event])

@rpc("authority", "call_remote", "reliable")
func _task_server_event(_event : NetworkEvents, _data = null) -> void:
	match _event:
		NetworkEvents.PARTY_CREATED:
			party_created.emit(_data)
		
		NetworkEvents.CONNECTION_ERR:
			party_connection_error.emit(_data)
		
		NetworkEvents.CONNECTED_PARTY:
			update_remote_objects.clear()
			party_connected.emit()
		
		NetworkEvents.DISCONNECTED_PARTY:
			update_remote_objects.clear()
			party_disconnected.emit(_data)
		
		NetworkEvents.CONNECTION_CONNECTED:
			party_other_connection_connected.emit(_data)
		
		NetworkEvents.CONNECTION_DISCONNECTED:
			party_other_connection_disconnected.emit(_data[0], _data[1])
		
		NetworkEvents.AVAILABLE_INFORMATIONS:
			available_party_informations.emit(_data)
		
		NetworkEvents.REMOTE_OBJECT_SPAWNNED:
			party_remote_object_spawnned.emit(_data)
		
		NetworkEvents.REMOTE_OBJECT_DESPAWNNED:
			party_remote_object_despawnned.emit(_data)
		
		NetworkEvents.PARTY_EVENT:
			party_received_event.emit(_data[0], _data[1])

@rpc("authority", "call_remote", "unreliable")
func _task_update_remote_object_property_always(_alias : StringName, _property : String, _value : Variant) -> void:
	if update_remote_objects.has(_alias):
		(update_remote_objects[_alias] as Object).set(_property, _value)

@rpc("authority", "call_remote", "reliable")
func _task_update_remote_object_property_on_change(_alias : StringName, _property : String, _value : Variant) -> void:
	if update_remote_objects.has(_alias):
		(update_remote_objects[_alias] as Object).set(_property, _value)
