class_name NotesApp
extends Control

const HermesUIRuntime = preload("res://addons/hermes_os/scripts/ui/hermes_ui/runtime/hermes_ui_runtime.gd")

const MANIFEST_PATH := "res://addons/hermes_os/scripts/apps/notes/manifest.json"

var _shell: Node
var _fs: Object
var _runtime = null
var _instance = null
var _mounted: Control = null
var _initial_state: Dictionary = {}

func os_app_init(context: Dictionary) -> void:
	_shell = context.get("shell", null) as Node
	_fs = context.get("filesystem", null) as Object
	if _fs == null and _shell != null:
		_fs = _shell._fs
	_initial_state = context.get("state", {}) if context.get("state", {}) is Dictionary else {}
	_build()
	if not _initial_state.is_empty():
		os_app_restore_state(_initial_state)

func os_app_focus() -> void:
	var controller = _controller()
	if controller != null and controller.has_method("focus_editor"):
		controller.call("focus_editor")

func os_app_close_requested() -> bool:
	# Preserve existing behavior: closing Notes never prompts or blocks.
	return true

func os_app_get_state() -> Dictionary:
	var controller = _controller()
	if controller != null and controller.has_method("get_notes_state"):
		var value = controller.call("get_notes_state")
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {"active_note_id": "", "open_notes": [], "current_path": "", "dirty": false, "content": ""}

func os_app_restore_state(state: Dictionary) -> void:
	var controller = _controller()
	if controller != null and controller.has_method("restore_notes_state"):
		controller.call("restore_notes_state", state)

func open_note(note_id_or_path: String) -> Dictionary:
	var controller = _controller()
	if controller != null and controller.has_method("open_note"):
		var result = controller.call("open_note", note_id_or_path)
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
	return {"ok": false, "error": "Notes controller unavailable"}

func open_file(path: String) -> Dictionary:
	var controller = _controller()
	if controller != null and controller.has_method("open_file"):
		var result = controller.call("open_file", path)
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
	return {"ok": false, "error": "Notes controller unavailable"}

func create_note(title: String = "Untitled", content: String = "") -> Dictionary:
	var controller = _controller()
	if controller != null and controller.has_method("create_note"):
		var result = controller.call("create_note", title, content)
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
	return {"ok": false, "error": "Notes controller unavailable"}

func save_note() -> Dictionary:
	var controller = _controller()
	if controller != null and controller.has_method("save_note"):
		var result = controller.call("save_note", null)
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
	return {"ok": false, "error": "Notes controller unavailable"}

func save_file() -> Dictionary:
	return save_note()

func delete_note() -> Dictionary:
	var controller = _controller()
	if controller != null and controller.has_method("delete_note"):
		var result = controller.call("delete_note", null)
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
	return {"ok": false, "error": "Notes controller unavailable"}

func set_note_content(content: String, dirty: bool = false) -> void:
	var controller = _controller()
	if controller != null and controller.has_method("set_note_content"):
		controller.call("set_note_content", content, dirty)

func get_current_path() -> String:
	var controller = _controller()
	if controller != null and controller.has_method("get_current_path"):
		return str(controller.call("get_current_path"))
	return ""

func get_active_note_id() -> String:
	var controller = _controller()
	if controller != null and controller.has_method("get_active_note_id"):
		return str(controller.call("get_active_note_id"))
	return ""

func is_dirty() -> bool:
	var controller = _controller()
	if controller != null and controller.has_method("is_dirty"):
		return bool(controller.call("is_dirty"))
	return false

func _build() -> void:
	for child in get_children():
		child.queue_free()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	set_meta("window_min_size", Vector2(700, 430))

	_runtime = HermesUIRuntime.new()
	_runtime.set_os_context({
		"shell": _shell,
		"filesystem": _fs,
		"event_bus": _shell.get("_event_bus") if _shell != null else null,
		"window_manager": _shell.get("_window_manager") if _shell != null else null,
		"app_registry": _shell.get("_app_registry") if _shell != null else null,
		"notification_center": _shell.get("_notification_center") if _shell != null else null
	})
	_instance = _runtime.create_app_instance(MANIFEST_PATH)
	set_meta("hermes_ui_runtime", _runtime)
	set_meta("hermes_ui_instance", _instance)
	if _instance == null:
		add_child(_error_label("Notes manifest failed to load."))
		return
	_mounted = _runtime.mount_instance(_instance, self)
	if _mounted == null:
		add_child(_error_label("Notes runtime failed to mount."))
	tree_exiting.connect(func() -> void:
		if _runtime != null and _instance != null:
			_runtime.unmount_instance(_instance)
	)

func _controller():
	if _instance == null:
		return null
	return _instance.controller

func _error_label(message: String) -> Label:
	var label := Label.new()
	label.name = "NotesRuntimeError"
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label
