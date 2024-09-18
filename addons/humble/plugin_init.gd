@tool
extends EditorPlugin

const _HB_RMSV_SINGLNAME := "HRemoteServer"
const _HB_RMEV_SINGLNAME := "HRemoteEvent"

func _enter_tree() -> void:
	add_autoload_singleton(_HB_RMSV_SINGLNAME, "_src/_singleton/remote_server.gd")
	add_autoload_singleton(_HB_RMEV_SINGLNAME, "_src/_singleton/remote_event.gd")


func _exit_tree() -> void:
	remove_autoload_singleton(_HB_RMEV_SINGLNAME)
	remove_autoload_singleton(_HB_RMSV_SINGLNAME)
