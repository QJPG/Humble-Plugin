extends Node

class_name HumbleNetManager

enum DefaultReasons {
	OCORRED_ERROR,
	ROOM_OWNER_LEFT,
}

class RoomState extends RefCounted:
	enum RoomConfigs {
		HELLO,		#SEND TO NEW PEER
		BYE,		#SEND TO ALL PEERS
		JOINNED,	#SEND RO ALL PEERS
	}
	
	var room_code : String
	var room_owner : int
	var room_timer : SceneTreeTimer
	var room_is_private : bool
	var room_config : Dictionary
	var room_players : PackedInt32Array
	var room_max_players : int
	var room_player_authorities : PackedInt32Array
	var room_closed : bool
	
	func generate_unique_room_code(length := 4) -> void:
		var _chars := "abcdefghijklmnopqrstuvwxyz0123456789"
		
		while room_code.length() < length:
			room_code += _chars[randi_range(0, _chars.length() - 1)]
	
	func _init() -> void:
		generate_unique_room_code()
	
	func add_authority(peer : int) -> void:
		if room_players.has(peer) and not room_player_authorities.has(peer):
			room_player_authorities.append(peer)
			
			#region network
			HumbleNetManagerService.get_multiplayer_ext().rpc(
				peer, HumbleNetRemoteEventService, "_rpc_room_player_authority_changed", [true])
			#endregion
	
	func remove_authority(peer : int, notify_peer : bool = true) -> void:
		if room_players.has(peer) and room_player_authorities.has(peer):
			var find_peer := room_player_authorities.find(peer)
			
			if find_peer > -1:
				room_player_authorities.remove_at(find_peer)
				
				#region network
				if notify_peer:
					HumbleNetManagerService.get_multiplayer_ext().rpc(
						peer, HumbleNetRemoteEventService, "_rpc_room_player_authority_changed", [false])
				#region
	
	func add_player(peer : int) -> void:
		var find_proxy := HumbleNetAuthService.get_proxy_auth(peer)
		
		if find_proxy:
			if find_proxy.proxy_is_in_room == false:
				room_players.append(peer)
				
				#region network
				#NOTIFY PEER
				HumbleNetManagerService.get_multiplayer_ext().rpc(
					peer, HumbleNetRemoteEventService, "_rpc_room_entered", [room_config.get_or_add(RoomConfigs.HELLO, null)])
				
				#NOTIFY ALL PEERS
				for i in room_players.size():
					var peer_id := room_players[i]
					
					if peer_id == peer:
						continue
					
					HumbleNetManagerService.get_multiplayer_ext().rpc(
						peer_id, HumbleNetRemoteEventService, "_rpc_room_player_entered", [
								peer, room_config.get_or_add(RoomConfigs.JOINNED, null)
							])
				#endregion
				
				find_proxy.proxy_is_in_room = true
				find_proxy.proxy_in_room_code = room_code
	
	func remove_player(peer : int, reason : Variant = null, notify_peer : bool = true) -> void:
		var find_proxy := HumbleNetAuthService.get_proxy_auth(peer)
		
		if find_proxy:
			if find_proxy.proxy_is_in_room == true:
				if find_proxy.proxy_in_room_code == room_code:
					remove_authority(peer, notify_peer)
					room_players.remove_at(room_players.find(peer))
					
					#region network
					#NOTIFY PEER
					if notify_peer:
						HumbleNetManagerService.get_multiplayer_ext().rpc(
							peer, HumbleNetRemoteEventService, "_rpc_room_exited", [reason])
					else:
						pass
					
					#NOTIFY ALL PEERS
					for i in room_players.size():
						var peer_id := room_players[i]
						
						if peer_id == peer:
							continue
						
						HumbleNetManagerService.get_multiplayer_ext().rpc(
							peer_id, HumbleNetRemoteEventService, "_rpc_room_player_exited", [peer, reason])
					#endregion
					
					find_proxy.proxy_is_in_room = false
					find_proxy.proxy_in_room_code = String()
	
	func remove_players(reason : Variant = null, notify_owner : bool = true) -> void:
		var _index := 0
		var _length := room_players.size()
		
		while _index < _length:
			var id := room_players[0]
			var _notify := true
			
			if id == room_owner:
				_notify = notify_owner
			
			remove_player(id, reason, _notify)
			_index += 1
	
	func send_event(peer : int, data : Variant, targets := PackedInt32Array([])) -> void:
		if targets.size() > 0:
			for i in targets.size():
				if room_players.has(targets[i]):
					HumbleNetManagerService.get_multiplayer_ext().rpc(
						targets[i], HumbleNetRemoteEventService, "_rpc_room_event", [peer, data])
		else:
			for i in room_players.size():
				HumbleNetManagerService.get_multiplayer_ext().rpc(
					room_players[i], HumbleNetRemoteEventService, "_rpc_room_event", [peer, data])

var rooms : Array[RoomState]

func get_multiplayer_ext() -> HumbleMultiplayerExt:
	if multiplayer is HumbleMultiplayerExt:
		return multiplayer
	return null

func network_listen_connections(port : int, max_connections := 4095, max_channels := 0, in_bandwidth := 0, out_bandwidth := 0) -> void:
	var enet_network := ENetMultiplayerPeer.new()
	if enet_network.create_server(port, max_connections, max_channels, in_bandwidth, out_bandwidth) == OK:
		var multiplayer_ext := HumbleMultiplayerExt.new()
		multiplayer_ext._base_api.server_relay = false
		multiplayer_ext.multiplayer_config.debug_enabled = true
		
		get_tree().set_multiplayer(multiplayer_ext, get_path())
		
		if not get_multiplayer_ext():
			printerr("HumbleNetManagerService:: Error on get MultiplayerExt object.")
			return
		
		get_multiplayer_ext()._base_api.root_path = get_tree().root.get_path()
		get_multiplayer_ext().multiplayer_peer = enet_network
		
		HumbleNetAuthService.lock_proxy_auths(max_connections)
		
		get_multiplayer_ext().peer_connected.connect(
			func(peer : int) -> void:
				HumbleNetAuthService.create_proxy_auth(peer)
		)
		
		get_multiplayer_ext().peer_disconnected.connect(
			func(peer : int) -> void:
				var find_proxy := HumbleNetAuthService.get_proxy_auth(peer)
				
				if find_proxy:
					if find_proxy.proxy_is_in_room:
						var find_room := get_room(find_proxy.proxy_in_room_code)
						
						if find_room:
							if find_room.room_owner == peer:
								find_room.remove_players(DefaultReasons.ROOM_OWNER_LEFT, false)
							else:
								find_room.remove_player(peer, null, false)
				
				HumbleNetAuthService.remove_proxy_auth(peer)
		)

func _enter_tree() -> void:
	multiplayer.multiplayer_peer = null

func _exit_tree() -> void:
	multiplayer.multiplayer_peer = null

var _poll_delta := 0.0

func _process(delta: float) -> void:
	if not get_multiplayer_ext():
		return
	
	if _poll_delta < 1000.0:
		var _index := 0
		var _rooms_count := rooms.size()
		
		while _index < _rooms_count:
			var room := rooms[0]
			
			if room.room_players.size() < 1:
				if room.room_timer == null:
					if get_multiplayer_ext().is_debug_enabled():
						printerr("Start room timeout to destroy.")
					
					room.room_timer = get_tree().create_timer(5.0)
					room.room_timer.timeout.connect(
						func() -> void:
							if room.room_players.size() < 1:
								var code := room.room_code
								rooms.erase(room)
								
								if get_multiplayer_ext().is_debug_enabled():
									printerr("Room (%s) was erased by limbo state." % code)
							else:
								room.room_timer = null
					)
			_index += 1
		
		_poll_delta += 5000.0
	else:
		_poll_delta -= 60.0
	
	

func get_room(code : String) -> RoomState:
	for i in rooms.size():
		if rooms[i].room_code == code:
			return rooms[i]
	return null

@rpc("any_peer", "call_remote", "reliable")
func _rpc_create_room(is_private : bool, max_players : int = 10, config := {}) -> void:
	if not multiplayer.is_server():
		return
	
	if max_players < 1:
		return
	
	if config is not Dictionary:
		return
	
	for key in config.keys():
		if not RoomState.RoomConfigs.values().has(key):
			return
	
	var client_owner := multiplayer.get_remote_sender_id()
	var find_proxy := HumbleNetAuthService.get_proxy_auth(client_owner)
	
	if find_proxy:
		if find_proxy.proxy_is_in_room == false:
			var room := RoomState.new()
			room.room_owner = client_owner
			room.room_config = config
			room.room_is_private = is_private
			room.room_max_players = max_players
			
			rooms.append(room)
			
			get_multiplayer_ext().rpc(client_owner, HumbleNetRemoteEventService, "_rpc_room_created", [
				room.room_code
			])
		else:
			return
	else:
		return

@rpc("any_peer", "call_remote", "reliable")
func _rpc_remove_room(data : Variant = null) -> void:
	if not multiplayer.is_server():
		return
	
	var client_owner := multiplayer.get_remote_sender_id()
	var find_proxy := HumbleNetAuthService.get_proxy_auth(client_owner)
	
	if find_proxy:
		if find_proxy.proxy_is_in_room:
			var find_room := get_room(find_proxy.proxy_in_room_code)
			
			if find_room:
				if find_room.room_owner == client_owner:
					find_room.remove_players(data)
					rooms.erase(find_room)
				else:
					return
			else:
				return
		else:
			return
	else:
		return
		

@rpc("any_peer", "call_remote", "reliable")
func _rpc_join_room(code : String) -> void:
	if not multiplayer.is_server():
		return
	
	var joinned_client := multiplayer.get_remote_sender_id()
	var find_proxy := HumbleNetAuthService.get_proxy_auth(joinned_client)
	
	var connected_success := false
	var join_error : HumbleNetRemoteEvent.ConnectionErrors
	
	if find_proxy:
		if find_proxy.proxy_is_in_room == false:
			var find_room := get_room(code)
			
			if find_room:
				if find_room.room_closed == false:
					if find_room.room_players.size() >= find_room.room_max_players:
						join_error = HumbleNetRemoteEvent.ConnectionErrors.IS_FULL
					else:
						find_room.add_player(joinned_client)
						connected_success = true
				else:
					join_error = HumbleNetRemoteEvent.ConnectionErrors.REFUSED
			else:
				join_error = HumbleNetRemoteEvent.ConnectionErrors.NOT_FOUND
		else:
			join_error = HumbleNetRemoteEvent.ConnectionErrors.IS_IN_OTHER_ROOM
	
		if connected_success == false:
			multiplayer.rpc(joinned_client, HumbleNetRemoteEventService, "_rpc_join_room_error", [join_error])

@rpc("any_peer", "call_remote", "reliable")
func _rpc_exit_room() -> void:
	if not multiplayer.is_server():
		return
	
	var exited_client := multiplayer.get_remote_sender_id()
	var find_proxy := HumbleNetAuthService.get_proxy_auth(exited_client)
	
	if find_proxy:
		if find_proxy.proxy_is_in_room:
			var find_room := get_room(find_proxy.proxy_in_room_code)
			
			if find_room:
				if find_room.room_owner == exited_client:
					find_room.remove_players(DefaultReasons.ROOM_OWNER_LEFT, true)
				else:
					find_room.remove_player(exited_client, find_room.room_config.get_or_add(RoomState.RoomConfigs.BYE, null))
			else:
				return
		else:
			return
	else:
		return


@rpc("any_peer", "call_remote", "reliable")
func _rpc_kick_player(peer : int, reason : Variant = null) -> void:
	if not multiplayer.is_server():
		return
	
	var client_owner := multiplayer.get_remote_sender_id()
	var find_proxy := HumbleNetAuthService.get_proxy_auth(client_owner)
	
	if find_proxy:
		if find_proxy.proxy_is_in_room:
			var find_room := get_room(find_proxy.proxy_in_room_code)
			
			if find_room:
				if find_room.room_owner == client_owner:
					find_room.remove_player(peer, reason)
				else:
					return
			else:
				return
		else:
			return
	else:
		return

@rpc("any_peer", "call_remote", "reliable")
func _rpc_send_room(data : Variant, targets := PackedInt32Array([])) -> void:
	if not multiplayer.is_server():
		return
	
	var client_owner := multiplayer.get_remote_sender_id()
	var find_proxy := HumbleNetAuthService.get_proxy_auth(client_owner)
	
	if find_proxy:
		if find_proxy.proxy_is_in_room:
			var find_room := get_room(find_proxy.proxy_in_room_code)
			
			if find_room:
				if find_room.room_owner == client_owner or find_room.room_player_authorities.has(client_owner):
					find_room.send_event(client_owner, data, targets)
				else:
					return
			else:
				return
		else:
			return
	else:
		return

@rpc("any_peer", "call_remote", "reliable")
func _rpc_set_player_authority(peer : int, has : bool) -> void:
	if not multiplayer.is_server():
		return
	
	var client_owner := multiplayer.get_remote_sender_id()
	var find_proxy := HumbleNetAuthService.get_proxy_auth(client_owner)
	
	if find_proxy:
		if find_proxy.proxy_is_in_room:
			var find_room := get_room(find_proxy.proxy_in_room_code)
			
			if find_room:
				if find_room.room_owner == client_owner:
					if has:
						find_room.add_authority(peer)
					else:
						find_room.remove_authority(peer)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_set_room_config(config : RoomState.RoomConfigs, value : Variant) -> void:
	if not multiplayer.is_server():
		return
	
	var client_owner := multiplayer.get_remote_sender_id()
	var find_proxy := HumbleNetAuthService.get_proxy_auth(client_owner)
	
	if find_proxy:
		if find_proxy.proxy_is_in_room:
			var find_room := get_room(find_proxy.proxy_in_room_code)
			
			if find_room:
				if find_room.room_owner == client_owner:
					if config is RoomState.RoomConfigs:
						find_room.room_config[config] = value

@rpc("any_peer", "call_remote", "reliable")
func _rpc_set_room_closed(closed : bool) -> void:
	if not multiplayer.is_server():
		return
	
	var client_owner := multiplayer.get_remote_sender_id()
	var find_proxy := HumbleNetAuthService.get_proxy_auth(client_owner)
	
	if find_proxy:
		if find_proxy.proxy_is_in_room:
			var find_room := get_room(find_proxy.proxy_in_room_code)
			
			if find_room:
				if find_room.room_owner == client_owner:
					find_room.room_closed = closed
				else:
					return
			else:
				return
		else:
			return
	else:
		return
