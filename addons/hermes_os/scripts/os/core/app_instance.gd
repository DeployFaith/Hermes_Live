class_name AppInstance
extends RefCounted

var instance_id: int = 0
var app_id: StringName = &""
var window_ids: Array[int] = []
var launch_args: Dictionary = {}
var state: Dictionary = {}
var created_at: int = 0
var last_active_at: int = 0

func add_window(window_id: int) -> void:
	if window_id <= 0 or window_ids.has(window_id):
		return
	window_ids.append(window_id)
	touch()

func remove_window(window_id: int) -> void:
	window_ids.erase(window_id)
	touch()

func touch() -> void:
	last_active_at = Time.get_ticks_msec()

func export_state() -> Dictionary:
	return {
		"instance_id": instance_id,
		"app_id": str(app_id),
		"window_ids": window_ids.duplicate(),
		"launch_args": launch_args.duplicate(true),
		"state": state.duplicate(true),
		"created_at": created_at,
		"last_active_at": last_active_at
	}
