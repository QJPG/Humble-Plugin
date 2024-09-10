extends Object

class_name room_manager

enum rmstate {
	limbo,
	open,
	closed
}

enum authmessage {
	hello_except_others,
	hello_except_peer,
	bye_except_peer,
}

static var __rmcd_length : int
static var __rmcd_wchars : String


class auth extends Object:
	var has_authority : bool

class remotenode extends Object:
	enum updatemode {
		always, always_fast
	}
	
	var authority_peer : int
	var attributes_peer : Dictionary
	var visible_peers : PackedInt32Array
	var node_path : NodePath

signal auth_joinned(_auth : auth)
signal auth_removed(_auth : auth, _reason : Variant)
signal auth_authority_changed(_auth : auth)
signal rmnd_created(_rmnd : remotenode)
signal rmnd_removed(_rmnd : remotenode)
signal rmnd_authority_changed(_rmnd : remotenode)
signal rmnd_visibility_changed(_rmnd : remotenode)

var state : rmstate

var auths : Dictionary
var rmnds : Dictionary

var code : StringName
var ownr : int

var max_auths : int
var is_privte : bool
var auth_msgs : Dictionary

static func _static_init() -> void:
	__rmcd_length = 4
	__rmcd_wchars = "abcdefghijklmnopqrstuvwxyz0123456789"

static func _get_string_code(length : int, _wchars : String) -> StringName:
	var _code := String("")
	
	for i in range(length):
		_code += ""
		_code[i] = _wchars[randi_range(0, _wchars.length() - 1)]
	
	return StringName(_code)

func _init() -> void:
	state = rmstate.limbo
	
	max_auths = 5
	is_privte = true
	
	code = _get_string_code(__rmcd_length, __rmcd_wchars)
	ownr = 1
	
	max_auths = 5
	is_privte = true
	auth_msgs[authmessage.hello_except_others] = null
	auth_msgs[authmessage.hello_except_peer] = null
	auth_msgs[authmessage.bye_except_peer] = null

func create_auth(peer : int) -> void:
	if auths.has(peer):
		return
	
	var _auth := auth.new()
	
	auths[peer] = _auth
	
	auth_joinned.emit(auth)

func remove_auth(peer : int, reason : Variant) -> void:
	if not auths.has(peer):
		return
	
	var _auth := auths[peer] as auth
	
	for _nd_alias in rmnds:
		var rmnd := rmnds[_nd_alias] as remotenode
		
		if rmnd.authority_peer == peer:
			remove_remote_node(_nd_alias)
	
	auth_removed.emit(_auth, reason)
	
	_auth.free()
	auths.erase(peer)

func create_remote_node(alias : StringName, node_path : NodePath, attributes : Dictionary, authority_peer : int) -> void:
	if rmnds.has(alias):
		return
	
	if attributes.size() < 1:
		return
	
	for _attr_alias in attributes:
		if _attr_alias is String and attributes[_attr_alias] is remotenode.updatemode:
			continue
		else:
			return
	
	var rmnd := remotenode.new()
	rmnd.authority_peer = authority_peer
	rmnd.attributes_peer = attributes
	rmnd.node_path = node_path
	
	rmnd_created.emit(rmnd)
	
	rmnds[alias] = rmnd

func remove_remote_node(alias : StringName) -> void:
	if not rmnds.has(alias):
		return
	
	var _rmnd := rmnds[alias] as remotenode
	
	rmnd_removed.emit(_rmnd)

	_rmnd.free()
	rmnds.erase(alias)

func set_auth_authority(peer : int, has : bool) -> void:
	if not auths.has(peer):
		return
	
	var _auth := auths[peer] as auth
	
	_auth.has_authority = has
	
	auth_authority_changed.emit(_auth)

func set_remote_node_authority(alias : StringName, peer : int) -> void:
	if not rmnds.has(alias):
		return
	
	var _rmnd := rmnds[alias] as remotenode
	
	_rmnd.authority_peer = peer
	
	rmnd_authority_changed.emit(_rmnd)

func set_remote_node_visibility(alias : StringName, peers : PackedInt32Array, visible : bool) -> void:
	if not rmnds.has(alias):
		return
	
	var _rmnd := rmnds[alias] as remotenode
	
	for _auth_id in peers:
		if visible:
			if not _rmnd.visible_peers.has(_auth_id):
				_rmnd.visible_peers.append(_auth_id)
		else:
			var _index := _rmnd.visible_peers.find(_auth_id)
			
			if _index > -1:
				_rmnd.visible_peers.remove_at(_index)
	
	rmnd_visibility_changed.emit(_rmnd)

func set_room_state(closed : bool) -> void:
	state = rmstate.open if not closed else rmstate.closed

func set_room_privacy(private : bool) -> void:
	is_privte = true if private else false
