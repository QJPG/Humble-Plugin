extends Node

class_name HumbleNetAuth

class INetAuthAPI extends RefCounted:
	func _init() -> void:
		return

class NetAuthConfig extends RefCounted:
	var auth_KEY : StringName
	var auth_API : INetAuthAPI
	
	func serialize() -> PackedByteArray:
		return PackedByteArray([])









class ProxyAuth extends RefCounted:
	const INVALID_PEER := -1
	
	var proxy_peer : int = INVALID_PEER
	var proxy_is_in_room : bool
	var proxy_in_room_code : String
	
	func reset() -> void:
		proxy_peer = INVALID_PEER
		proxy_is_in_room = false
		proxy_in_room_code = String()

var auth_config : NetAuthConfig = null #ALERT: NOT IMPLEMENTED YET
var proxy_auths : Array[ProxyAuth]

func lock_proxy_auths(capacity : int) -> void:
	proxy_auths.resize(capacity)
	
	for i in proxy_auths.size():
		proxy_auths[i] = ProxyAuth.new()
	
	proxy_auths.make_read_only()

func get_proxy_auth(peer : int) -> ProxyAuth:
	var _index := 0
	
	while _index < proxy_auths.size():
		if proxy_auths[_index].proxy_peer == peer:
			return proxy_auths[_index]
		_index += 1
	
	return null

func create_proxy_auth(peer : int) -> Error:
	if get_proxy_auth(peer):
		return ERR_ALREADY_EXISTS
	
	var _index := 0
	
	while _index < proxy_auths.size():
		if proxy_auths[_index].proxy_peer == ProxyAuth.INVALID_PEER:
			proxy_auths[_index].proxy_peer = peer
			return OK
		
		_index += 1
	
	return ERR_CANT_CREATE

func remove_proxy_auth(peer : int) -> Error:
	var find_proxy := get_proxy_auth(peer)
	
	if find_proxy:
		find_proxy.reset()
		return OK
	else:
		return ERR_DOES_NOT_EXIST
	
	return ERR_CANT_RESOLVE
