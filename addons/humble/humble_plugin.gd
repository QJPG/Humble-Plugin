@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_autoload_singleton("HumbleNetAuthService", "scripts/singletons/net_auth.gd")
	add_autoload_singleton("HumbleNetManagerService", "scripts/singletons/net_manager.gd")
	add_autoload_singleton("HumbleNetRemoteEventService", "scripts/singletons/net_remote_event.gd")

func _exit_tree() -> void:
	remove_autoload_singleton("HumbleNetAuthService")
	remove_autoload_singleton("HumbleNetManagerService")
	remove_autoload_singleton("HumbleNetRemoteEventService")
