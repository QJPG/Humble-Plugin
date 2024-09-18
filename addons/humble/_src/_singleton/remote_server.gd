extends Node

class_name _HRemoteServer_

enum NetworkReasons {
	FAILED_AUTH,
	PARTY_FULL,
	DISCONNECTED,
	IN_OTHER_PARTY,
	PARTY_NOT_FOUND,
}

enum NetworkEventTypes {
	MANAGE_CONNECTIONS,
	KICK_CONNECTION,
	SEND_MESSAGE,
}

class RemoteObject extends RefCounted:
	enum PropertyUpdateModes {
		ALWAYS,
		ON_CHANGE
	}
	
	var object_authority : int
	var object_properties : Dictionary
	var object_visible_peer : int

class PartyStream extends RefCounted:
	#Events
	signal connection_accepted(connection_id : int)
	signal connection_refused(connection_id : int, reason : NetworkReasons)
	signal connection_removed(connection_id : int, reason : NetworkReasons)
	
	var _id : int
	
	#Configurations
	var refuse_new_connections : bool			#only server
	var connection_peers : PackedInt32Array		#only server
	var max_connections : int					#only server
	var authority_peer : int					#only server
	var is_public : bool						#only authority
	var filters : Dictionary					#only server
	
	var remote_objects : Dictionary				#only authority

static var _busy_connection_peers : PackedInt32Array
static var _party_streams : Array[PartyStream]

signal party_configuration_created(party : PartyStream)
signal party_configuration_removed(party : PartyStream)
signal party_connection_accepted(party : PartyStream, peer : int)
signal party_connection_removed(party : PartyStream, peer : int, reason : NetworkReasons)

var _preconfig_party_callback : Callable	#returns bool
var _connection_auth_callback : Callable	#returns bool

func open_server(port : int, max_connections : int = 4095) -> void:
	var _enet := ENetMultiplayerPeer.new()
	
	if _enet.create_server(port, max_connections) == OK:
		var _scn_mlt := SceneMultiplayer.new()
		
		get_tree().set_multiplayer(_scn_mlt, get_path())
		
		multiplayer.multiplayer_peer = _enet
		multiplayer.server_relay = false
		multiplayer.root_path = get_tree().root.get_path()
		
		multiplayer.peer_disconnected.connect(func(peer : int) -> void:
			if _busy_connection_peers.has(peer):
				for _party in _party_streams:
					if _party.connection_peers.has(peer):
						_remove_connection_peer_from_party(_party, peer, NetworkReasons.DISCONNECTED)
						return)

func close_server() -> void:
	if multiplayer and multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

func _call_client_task(_peer : int, _event : HRemoteEvent.NetworkEvents, _data : Array) -> void:
	if not multiplayer.get_peers().has(_peer):
		return
	
	var _args := [_event]
	if _data.size() > 1:
		_args.append(_data)
	else:
		_args.append_array(_data)
	
	multiplayer.rpc(_peer, HRemoteEvent, "_task_server_event", _args)

func _create_party_configuration(party : PartyStream, custom_options := {}) -> void:
	if _preconfig_party_callback.is_valid():
		if _preconfig_party_callback.call(party, custom_options) == false:
			return
	
	_party_streams.append(party)
	
	party.connection_accepted.connect(
		func(peer : int):
			_call_client_task(peer, HRemoteEvent.NetworkEvents.CONNECTED_PARTY, [null])
			#HRemoteEvent._task_server_event.rpc_id(peer, HRemoteEvent.NetworkEvents.CONNECTED_PARTY, null)
			
			for _other_peer in party.connection_peers:
				if _other_peer == peer:
					continue
				
				#HRemoteEvent._task_server_event.rpc_id(_other_peer, HRemoteEvent.NetworkEvents.CONNECTION_CONNECTED, 
				#	peer)
				_call_client_task(_other_peer, HRemoteEvent.NetworkEvents.CONNECTION_CONNECTED, [peer]))
	
	party.connection_refused.connect(
		func(peer : int, reason : NetworkReasons):
			#HRemoteEvent._task_server_event.rpc_id(peer, HRemoteEvent.NetworkEvents.CONNECTION_ERR, reason)
			_call_client_task(peer, HRemoteEvent.NetworkEvents.CONNECTION_ERR, [reason]))
	
	party.connection_removed.connect(
		func(peer : int, reason : NetworkReasons):
			#HRemoteEvent._task_server_event.rpc_id(peer, HRemoteEvent.NetworkEvents.DISCONNECTED_PARTY, reason)
			_call_client_task(peer, HRemoteEvent.NetworkEvents.DISCONNECTED_PARTY, [reason])
			
			for _other_peer in party.connection_peers:
				if _other_peer == peer:
					continue
				
				#HRemoteEvent._task_server_event.rpc_id(_other_peer, HRemoteEvent.NetworkEvents.CONNECTION_DISCONNECTED, [
				#	peer, reason])
				_call_client_task(_other_peer, HRemoteEvent.NetworkEvents.CONNECTION_DISCONNECTED, [peer, reason]))
	
	party_configuration_created.emit(party)
	
	_call_client_task(party.authority_peer, HRemoteEvent.NetworkEvents.PARTY_CREATED, [party._id])

func _remove_party_configuration(party : PartyStream) -> void:
	if _party_streams.has(party):
		_party_streams.remove_at(_party_streams.find(party))
		
		for _peer in party.connection_peers:
			_remove_connection_peer_from_party(party, _peer, NetworkReasons.DISCONNECTED)
		
		party_configuration_removed.emit(party)

func _insert_connection_peer_to_party(party : PartyStream, peer : int, data_auth : Variant) -> void:
	if _busy_connection_peers.has(peer):
		party.connection_refused.emit(peer, NetworkReasons.IN_OTHER_PARTY)
		return
	
	if party.refuse_new_connections:
		party.connection_refused.emit(peer, NetworkReasons.DISCONNECTED)
		return
	
	if party.max_connections > 0 and party.connection_peers.size() >= party.max_connections:
		party.connection_refused.emit(peer, NetworkReasons.PARTY_FULL)
		return
	
	if _connection_auth_callback.is_valid() and _connection_auth_callback.call(party, peer, data_auth) == false:
		party.connection_refused.emit(peer, NetworkReasons.FAILED_AUTH)
		return
	
	_busy_connection_peers.append(peer)
	
	party_connection_accepted.emit(party, peer)
	
	party.connection_peers.append(peer)
	party.connection_accepted.emit(peer)

func _remove_connection_peer_from_party(party : PartyStream, peer : int, reason : NetworkReasons) -> void:
	if party.connection_peers.has(peer):
		for _rmobj_alias in party.remote_objects:
			for _rmobj in party.remote_objects[_rmobj_alias]:
				if (_rmobj as RemoteObject).object_visible_peer == peer:
					party.remote_objects[_rmobj_alias].erase(_rmobj)
		
		party.connection_peers.remove_at(party.connection_peers.find(peer))
		party.connection_removed.emit(peer, reason)
	
		if _busy_connection_peers.has(peer):
			_busy_connection_peers.remove_at(_busy_connection_peers.find(peer))
	
		party_connection_removed.emit(party, peer, reason)
	
		if peer == party.authority_peer:
			_remove_party_configuration(party)

func _get_party_stream(id : int) -> PartyStream:
	for _party_inter in _party_streams:
		if _party_inter._id == id:
			return _party_inter
	return null

func spawn_remote_object(party : PartyStream, alias : StringName, sync_properties : Dictionary, to : PackedInt32Array) -> void:
	if not party.remote_objects.has(alias):
		var _arr : Array[RemoteObject]
		party.remote_objects[alias] = _arr
	
	for _peer in to:
		if not party.connection_peers.has(_peer):
			continue
		
		var _rmobj := RemoteObject.new()
		_rmobj.object_authority = party.authority_peer
		_rmobj.object_properties = sync_properties
		_rmobj.object_visible_peer = _peer
	
		party.remote_objects[alias].append(_rmobj)
		
		#notify this _peer
		_call_client_task(_peer, HRemoteEvent.NetworkEvents.REMOTE_OBJECT_SPAWNNED, [alias])

func despawn_remote_object(party : PartyStream, alias : StringName, to : PackedInt32Array) -> void:
	if not party.remote_objects.has(alias):
		return
	
	var _rmobj_array := party.remote_objects[alias] as Array[RemoteObject]
	
	for _rmobj in _rmobj_array:
		for _peer in to:
			if _rmobj.object_visible_peer == _peer:
				_rmobj_array.erase(_rmobj)
				
				#notify this _peer
				_call_client_task(_peer, HRemoteEvent.NetworkEvents.REMOTE_OBJECT_DESPAWNNED, [alias])

func update_remote_object_property(party : PartyStream, alias : StringName, property : String, value : Variant) -> void:
	if not party.remote_objects.has(alias):
		return
	
	var _rmobj_array := party.remote_objects[alias] as Array[RemoteObject]
	
	for _rmobj in _rmobj_array:
		if _rmobj.object_properties.has(property) and _rmobj.object_properties[property] is RemoteObject.PropertyUpdateModes:
			match _rmobj.object_properties[property]:
				RemoteObject.PropertyUpdateModes.ALWAYS:
					if not _rmobj.object_visible_peer == _rmobj.object_authority:
						multiplayer.rpc(_rmobj.object_visible_peer,
							HRemoteEvent, "_task_update_remote_object_property_always", [alias, property, value])
				
				RemoteObject.PropertyUpdateModes.ON_CHANGE:
					if not _rmobj.object_visible_peer == _rmobj.object_authority:
						multiplayer.rpc(_rmobj.object_visible_peer,
							HRemoteEvent, "_task_update_remote_object_property_on_change", [alias, property, value])

@rpc("any_peer", "call_remote", "reliable")
func _task_create_party_configuration(_is_public : bool, _custom_options : Dictionary) -> void:
	var _peer := multiplayer.get_remote_sender_id()
	
	if _busy_connection_peers.has(_peer):
		return
	
	var _party := PartyStream.new()
	_party.authority_peer = _peer
	_party._id = randi()
	_party.is_public = _is_public
	
	_create_party_configuration(_party, _custom_options)

@rpc("any_peer", "call_remote", "reliable")
func _task_join_party(_party_id : int, _data_auth : Variant) -> void:
	var _peer := multiplayer.get_remote_sender_id()
	
	var _party := _get_party_stream(_party_id)
	
	if _party:
		_insert_connection_peer_to_party(_party, _peer, _data_auth)
	else:
		_party.connection_refused.emit(_peer, NetworkReasons.PARTY_NOT_FOUND)

@rpc("any_peer", "call_remote", "reliable")
func _task_quit_party(_party_id : int) -> void:
	var _peer := multiplayer.get_remote_sender_id()
	
	var _party := _get_party_stream(_party_id)
	
	if _party:
		_remove_connection_peer_from_party(_party, _peer, NetworkReasons.DISCONNECTED)

@rpc("any_peer", "call_remote", "reliable")
func _task_request_informations() -> void:
	var _peer := multiplayer.get_remote_sender_id()
	
	var _infos := {}
	
	for _party in _party_streams:
		if _party.is_public and not _party.refuse_new_connections:
			_infos[_party._id] = {
				"connections": _party.connection_peers.size(),
				"max_connections": _party.max_connections,
				"filters": _party.filters
			}
	
	#HRemoteEvent._task_server_event.rpc_id(_peer, HRemoteEvent.NetworkEvents.AVAILABLE_INFORMATIONS, _infos)
	_call_client_task(_peer, HRemoteEvent.NetworkEvents.AVAILABLE_INFORMATIONS, [_infos])

@rpc("any_peer", "call_remote", "reliable")
func _task_spawn_remote_object(_alias : StringName, _sync_properties : Dictionary, _to : PackedInt32Array) -> void:
	var _peer := multiplayer.get_remote_sender_id()
	
	for _party in _party_streams:
		if _party.authority_peer == _peer:
			spawn_remote_object(_party, _alias, _sync_properties, _to)
			return

@rpc("any_peer", "call_remote", "reliable")
func _task_despawn_remote_object(_alias : StringName, _to : PackedInt32Array) -> void:
	var _peer := multiplayer.get_remote_sender_id()
	
	for _party in _party_streams:
		if _party.authority_peer == _peer:
			despawn_remote_object(_party, _alias, _to)
			return

@rpc("any_peer", "call_remote", "reliable")
func _task_update_remote_object_property(_alias : StringName, _property : String, _value : Variant) -> void:
	var _peer := multiplayer.get_remote_sender_id()
	
	for _party in _party_streams:
		if _party.connection_peers.has(_peer):
			if _party.remote_objects.has(_alias):
				for _rmobj in _party.remote_objects[_alias]:
					if (_rmobj as RemoteObject).object_authority == _peer:
						update_remote_object_property(_party, _alias, _property, _value)
						return

@rpc("any_peer", "call_remote", "reliable")
func _task_set_remote_object_authority(_alias : StringName, _authority : int) -> void:
	var _peer := multiplayer.get_remote_sender_id()
	
	for _party in _party_streams:
		if _party.authority_peer == _peer:
			if _party.remote_objects.has(_alias):
				for _rmobj in _party.remote_objects[_alias]:
					(_rmobj as RemoteObject).object_authority = _authority

@rpc("any_peer", "call_remote", "reliable")
func _task_send_event(_event : Variant) -> void:
	var _peer := multiplayer.get_remote_sender_id()
	
	for _party in _party_streams:
		if _party.authority_peer == _peer:
			if _event is Dictionary:
				if _event.has("type") and _event.type is NetworkEventTypes:
					match _event.type:
						NetworkEventTypes.MANAGE_CONNECTIONS:
							if _event.has("refuse") and _event.refuse is bool:
								_party.refuse_new_connections = _event.refuse
								return
						
						NetworkEventTypes.KICK_CONNECTION:
							if _event.has("target") and _event.target is int and _party.connection_peers.has(_event.target) and _event.target != _peer:
								_remove_connection_peer_from_party(_party, _event.target, NetworkReasons.DISCONNECTED)
								return
						
						NetworkEventTypes.SEND_MESSAGE:
							if _event.has("target") and _event.target is int and _party.connection_peers.has(_event.target) and _event.target != _peer:
								if _event.has("message"):
									_call_client_task(_event.target, HRemoteEvent.NetworkEvents.PARTY_EVENT, [_peer, _event.message])
									return
			
			for _idpeer in _party.connection_peers:
				if _idpeer == _peer:
					continue
				
				_call_client_task(_idpeer, HRemoteEvent.NetworkEvents.PARTY_EVENT, [_peer, _event])
