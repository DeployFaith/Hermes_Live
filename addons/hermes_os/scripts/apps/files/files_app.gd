class_name FilesApp
extends Control

const HermesUIRuntime = preload("res://addons/hermes_os/scripts/ui/hermes_ui/runtime/hermes_ui_runtime.gd")

const MANIFEST_PATH := "res://addons/hermes_os/scripts/apps/files/manifest.json"

var _shell: Node
var _fs: Object
var _runtime = null
var _instance = null
var _mounted: Control = null
var _initial_state: Dictionary = {}
var _shortcuts: Array = []
var _open_file_callback: Callable = Callable()
var _shortcuts_changed_callback: Callable = Callable()
var _state_save_callback: Callable = Callable()

func os_app_init(context: Dictionary) -> void:
	_shell = context.get("shell", null) as Node
	_fs = context.get("filesystem", null) as Object
	if _fs == null and _shell != null:
		_fs = _shell._fs
	_initial_state = context.get("state", {}) if context.get("state", {}) is Dictionary else {}
	_shortcuts = (context.get("shortcuts", []) as Array).duplicate(true) if context.get("shortcuts", []) is Array else []
	var open_value: Variant = context.get("open_file_callback", Callable())
	if open_value is Callable:
		_open_file_callback = open_value as Callable
	var shortcuts_value: Variant = context.get("shortcuts_changed_callback", Callable())
	if shortcuts_value is Callable:
		_shortcuts_changed_callback = shortcuts_value as Callable
	var save_value: Variant = context.get("state_save_callback", Callable())
	if save_value is Callable:
		_state_save_callback = save_value as Callable
	_build()
	if not _initial_state.is_empty():
		os_app_restore_state(_initial_state)

func os_app_focus() -> void:
	if _instance == null or _instance.controller == null:
		return
	if _instance.controller.has_method("focus_primary"):
		_instance.controller.call("focus_primary")

func os_app_close_requested() -> bool:
	return true

func os_app_get_state() -> Dictionary:
	if _instance != null and _instance.controller != null and _instance.controller.has_method("get_files_state"):
		var value: Variant = _instance.controller.call("get_files_state")
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {}

func os_app_restore_state(state: Dictionary) -> void:
	if _instance != null and _instance.controller != null and _instance.controller.has_method("restore_files_state"):
		_instance.controller.call("restore_files_state", state)

func open_path(path: String) -> void:
	if _instance != null and _instance.controller != null and _instance.controller.has_method("open_path"):
		_instance.controller.call("open_path", path)

func select_path(path: String) -> bool:
	if _instance != null and _instance.controller != null and _instance.controller.has_method("select_path"):
		return bool(_instance.controller.call("select_path", path))
	return false

func get_current_path() -> String:
	if _instance != null and _instance.controller != null and _instance.controller.has_method("get_current_path"):
		return str(_instance.controller.call("get_current_path"))
	return ""

func get_selected_path() -> String:
	if _instance != null and _instance.controller != null and _instance.controller.has_method("get_selected_path"):
		return str(_instance.controller.call("get_selected_path"))
	return ""

func get_visible_entries() -> Array:
	if _instance != null and _instance.controller != null and _instance.controller.has_method("get_visible_entries"):
		var value: Variant = _instance.controller.call("get_visible_entries")
		if value is Array:
			return (value as Array).duplicate(true)
	return []

func open_selected() -> void:
	if _instance != null and _instance.controller != null and _instance.controller.has_method("open_selected"):
		_instance.controller.call("open_selected")

func refresh(clear_status := true, _push_history := true) -> void:
	if _instance != null and _instance.controller != null and _instance.controller.has_method("refresh_files"):
		_instance.controller.call("refresh_files")
	if not clear_status and _instance != null and _instance.controller != null and _instance.controller.has_method("_set_status"):
		_instance.controller.call("_set_status", "", false)

func _build() -> void:
	for child in get_children():
		child.queue_free()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(860, 500)
	set_meta("window_min_size", Vector2(860, 500))

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
		add_child(_error_label("Files manifest failed to load."))
		return
	_mounted = _runtime.mount_instance(_instance, self)
	if _mounted == null:
		add_child(_error_label("Files runtime failed to mount."))
	_configure_controller()
	if not tree_exiting.is_connected(Callable(self, "_on_tree_exiting")):
		tree_exiting.connect(_on_tree_exiting)

func _on_tree_exiting() -> void:
	if _runtime != null and _instance != null:
		_runtime.unmount_instance(_instance)

func _configure_controller() -> void:
	if _instance == null or _instance.controller == null:
		return
	if _instance.controller.has_method("configure_app_context"):
		_instance.controller.call("configure_app_context", {
			"shell": _shell,
			"filesystem": _fs,
			"event_bus": _shell.get("_event_bus") if _shell != null else null,
			"shortcuts": _shortcuts,
			"open_file_callback": _open_file_callback,
			"shortcuts_changed_callback": _shortcuts_changed_callback,
			"state_save_callback": _state_save_callback
		})

func _error_label(message: String) -> Label:
	var label := Label.new()
	label.name = "FilesRuntimeError"
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label
