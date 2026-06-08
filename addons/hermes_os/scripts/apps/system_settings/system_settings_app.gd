class_name SystemSettingsApp
extends Control

const HermesUIRuntime = preload("res://addons/hermes_os/scripts/ui/hermes_ui/runtime/hermes_ui_runtime.gd")

const MANIFEST_PATH := "res://addons/hermes_os/scripts/apps/system_settings/manifest.json"

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
	if controller != null and controller.has_method("refresh_settings"):
		controller.call("refresh_settings")

func os_app_close_requested() -> bool:
	return true

func os_app_get_state() -> Dictionary:
	var controller = _controller()
	if controller != null and controller.has_method("get_settings_state"):
		var value = controller.call("get_settings_state")
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {}

func os_app_restore_state(state: Dictionary) -> void:
	var controller = _controller()
	if controller != null and controller.has_method("restore_settings_state"):
		controller.call("restore_settings_state", state)

func _build() -> void:
	for child in get_children():
		child.queue_free()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(780, 500)
	set_meta("window_min_size", Vector2(700, 440))

	_runtime = HermesUIRuntime.new()
	_runtime.set_os_context({
		"shell": _shell,
		"filesystem": _fs,
		"event_bus": _shell.get("_event_bus") if _shell != null else null,
		"window_manager": _shell.get("_window_manager") if _shell != null else null,
		"app_registry": _shell.get("_app_registry") if _shell != null else null,
		"notification_center": _shell.get("_notification_center") if _shell != null else null,
		"hermes_agent_service": _shell.get("_hermes_agent_service") if _shell != null else null
	})
	_instance = _runtime.create_app_instance(MANIFEST_PATH)
	set_meta("hermes_ui_runtime", _runtime)
	set_meta("hermes_ui_instance", _instance)
	if _instance == null:
		add_child(_error_label("System Settings manifest failed to load."))
		return
	_mounted = _runtime.mount_instance(_instance, self)
	if _mounted == null:
		add_child(_error_label("System Settings runtime failed to mount."))
	if not tree_exiting.is_connected(Callable(self, "_on_tree_exiting")):
		tree_exiting.connect(_on_tree_exiting)

func _on_tree_exiting() -> void:
	if _runtime != null and _instance != null:
		_runtime.unmount_instance(_instance)

func _controller():
	if _instance == null:
		return null
	return _instance.controller

func _error_label(message: String) -> Label:
	var label := Label.new()
	label.name = "SystemSettingsRuntimeError"
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label
