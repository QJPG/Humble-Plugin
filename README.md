
![icon](https://github.com/user-attachments/assets/0caf6d11-d4a5-4c33-b479-e32620ea48d5)

# Humble-Plugin
High level Networking Plugin for Godot.

Humble allows the server to create and manage rooms for separate game sessions. For each room, Humble allows the creation of "Remote Nodes" that store and synchronize information for all players in the same room.

## Hello, Humble!

### Starting the Server and Client!
```gdscript
extends Button

func _pressed() -> void:
	Application.is_host = true

	#STARTING SERVER
	HumbleNetManagerService.network_listen_connections(22023)

	#STARTING CLIENT
	HumbleNetRemoteEventService.connect_to_server("127.0.0.1", 22023)
	
	await HumbleNetRemoteEventService.multiplayer.connected_to_server
	
	HumbleNetRemoteEventService.create_room(false, 5, {
		HumbleNetManager.RoomState.RoomConfigs.HELLO: "This is a private hello data.",
		HumbleNetManager.RoomState.RoomConfigs.BYE: "This is a public 'Adios' data.",
		HumbleNetManager.RoomState.RoomConfigs.JOINNED: "This is a public hello data.",
	})
	HumbleNetRemoteEventService.room_created.connect(func(code : String) -> void:
		HumbleNetRemoteEventService.join_room(code))
	
	HumbleNetRemoteEventService.room_entered.connect(func(data : Variant) -> void:
		get_tree().change_scene_to_file("res://assets/scenes/main_game.tscn"))

```

### Starting Game Manager!

```gdscript
extends Node

class_name GameManager

var players : Array[int]

func create_player_controller(alias : StringName, is_local : bool) -> CharacterBody2D:
	var player := preload("res://assets/scenes/player_controller.tscn").instantiate()
	player.name = alias
	player.is_local = is_local
	
	HumbleNetRemoteEventService.spawn_nodes[alias] = player
	
	add_child(player)
	
	return player

func remove_player_controller(alias : StringName) -> void:
	if HumbleNetRemoteEventService.spawn_nodes.has(alias):
		HumbleNetRemoteEventService.spawn_nodes[alias].queue_free()
		HumbleNetRemoteEventService.spawn_nodes.erase(alias)

func _player_entered(peer : int, data : Variant) -> void:
	players.append(peer)

func _player_exited(peer : int, data : Variant) -> void:
	players.erase(peer)

func _authority_changed(has_authority : bool) -> void:
	print("You has authority? %s" % has_authority)

func _exited(data : Variant) -> void:
	print("Exited from room: Reason: %s" % data)
	get_tree().change_scene_to_file("res://assets/scenes/main_menu.tscn")

func _node_spawned(node_path : NodePath, alias : StringName, is_local : bool) -> void:
	create_player_controller(alias, is_local)
	
	print('Spawned node: %s %s is local: %s' % [node_path, alias, is_local])

func _node_despawned(node_path : NodePath, alias : StringName) -> void:
	remove_player_controller(alias)
	
	print('Despawned node: %s %s' % [node_path, alias])

#ONLY ROOM OWNER
func start() -> void:
	var all_players := Array([multiplayer.get_unique_id()])
	all_players.append_array(players)
	
	for i in all_players.size():
		HumbleNetRemoteEventService.add_room_node_remote(
			get_path(),		#ROOT PATH FROM NODE (Replace with NodePath("") if you don't need it.)
			str(all_players[i]),	#AN ALIAS FOR THE NODE
			all_players[i],		#PLAYER WHO HAS AUTHORITY OVER THE NODE
			{
				"position": HumbleNetRemoteEvent.NodeRemoteUpdatePropertyModes.UPDATE_ALWAYS	#PROPERTY TO SYNC.
			}
		)

		#Enter which players will receive updates about this Node. (You don't need to add the authoritative player here.)
		HumbleNetRemoteEventService.set_room_node_remote_visibility(all_players, str(all_players[i]), true)

func _enter_tree() -> void:
	get_parent().get_node("Quit").button_down.connect(func(): HumbleNetRemoteEventService.exit_room())
	get_parent().get_node("Start").button_down.connect(func(): start())
	
	HumbleNetRemoteEventService.room_exited.connect(_exited)
	HumbleNetRemoteEventService.room_authority_changed.connect(_authority_changed)
	HumbleNetRemoteEventService.room_player_entered.connect(_player_entered)
	HumbleNetRemoteEventService.room_player_exited.connect(_player_exited)
	HumbleNetRemoteEventService.room_node_remote_spawned.connect(_node_spawned)
	HumbleNetRemoteEventService.room_node_remote_despawned.connect(_node_despawned)
	
	HumbleNetRemoteEventService.multiplayer.server_disconnected.connect(func(): get_tree().change_scene_to_file("res://assets/scenes/main_menu.tscn"))

func _exit_tree() -> void:
	return

func _ready() -> void:
	return

func _physics_process(delta: float) -> void:
	return

func _process(delta: float) -> void:
	get_parent().get_node("Start").visible = Application.is_host

```

## Basic Usage
"Humble" works with the room system where each room has a single owner to manage it.
Rooms can be created by any user (peer) on the network. Here's how:

### "HumbleNetRemoteEventService" is the main singleton for communicating with a "Humble" server.

```gdscript

#This connects to a humble server.
func connect_to_server(address : String, port : int) -> void:

#Requires the creation of a room.
func create_room(is_private : bool, capacity : int, config := {}) -> void:

#Requires joining a room (or the room created).
func join_room(code : String) -> void:

#Quit from room. (If the player is the owner of the room, the room will be closed, expelling everyone from it).
func exit_room() -> void:

#Forces a room to close. (only owner)
func remove_room(data : Variant = null) -> void:

#Forces a player to be removed. (only owner)
func kick_player(peer : int, data : Variant = null) -> void:

#Sends an event to all or some players. (only owner or authorities)
func send_room(data : Variant, target := PackedInt32Array([])) -> void:

#Enables a player as room authority. (only owner) (default is false)
func set_room_authority(peer : int, enabled : bool) -> void:


```

### If the rooms are in limbo state (without any players in it), it will have a timer of a few seconds and will close itself.
A room can be configured with response values.
```gdscript
HumbleNetRemoteEventService.create_room(false, 5, {
		HumbleNetManager.RoomState.RoomConfigs.HELLO: "This is a private hello data when a client joins.", #send to new peer
		HumbleNetManager.RoomState.RoomConfigs.BYE: "This is a public 'Adios' data when player exited.",  #send to all in a room
		HumbleNetManager.RoomState.RoomConfigs.JOINNED: "This is a public hello data when player joinned." #send to all in a room
	})
```
It is also possible to change these settings even after the room has been created.
```gdscript
HumbleNetRemoteEventService.set_room_config(HumbleNetManager.RoomState.RoomConfigs.BYE, "A player just left the game!")
```
Communication in a room is done by events. These events are calls (in "reliable" transfer mode) that are transmitted only by the room owner or authorities.
```gdscript
HumbleNetRemoteEventService.room_event_callback = func(peer : int, data):
	prints('Event by: %s -> %s' % [peer, data])
```
### If the player has already entered the room, but has not yet defined the "callback" for the events, they will be accumulated by default, so that when the callback is defined, these missed events will be passed on.

To disable this accumulation do this:
```gdscript
HumbleNetRemoteEventService.can_accumulate = false
```
### To sync nodes to a specific room, you can utilize some "Remote Node" control functions!

```gdscript
HumbleNetRemoteEventService.add_room_node_remote(node.get_path(), "Node Alias", multiplayer.get_unique_id(), {})
```
This function allows you to register a node of any type in the room. The first argument informs the path of the node (can be empty). The second argument provides a unique name for this node in the room. The third argument defines the id of the player in the room who will have authority over this node.
The last argument defines which properties can be updated and how they are updated.
```gdscript
#Example:
{
	"position": HumbleNetRemoteEvent.NodeRemoteUpdatePropertyModes.UPDATE_ALWAYS
}
```

Now that the Node has been registered in the room, it is necessary to inform which players will receive updates about this node:
```gdscript
HumbleNetRemoteEventService.set_room_node_remote_visibility(<PackedInt32Array: Players ID's in room>, <String: Node Alias>, <true/false>)
```
(There is no need to provide the authoritative player id here.)

In order for everyone to receive updates from the Node, it is necessary to instantiate the Node of the same type manually.
```gdscript
HumbleNetRemoteEventService.spawn_nodes[<String: Node Alias>] = instanced_node
```

To update a Node property, the authoritative player on the node must call this function:
```gdscript
HumbleNetRemoteEventService.update_room_node_remote_property(alias : String, property : String, value : Variant)
```

To remove the node from the room, the host must call this function:
```gdscript
HumbleNetRemoteEventService.remove_room_node_remote(alias : StringName)
```
