
![icon](https://github.com/user-attachments/assets/0caf6d11-d4a5-4c33-b479-e32620ea48d5)

# Humble-Plugin
High level Networking Plugin for Godot.

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

#Add a player to room authorities. (only owner)
func add_authority(peer : int) -> void:

#Remove a player authority from room. (only owner)
func revoke_authority(peer : int) -> void:


```
