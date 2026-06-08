class_name CommandPaletteApp
extends Control

const HermesUIRuntime = preload("res://addons/hermes_os/scripts/ui/hermes_ui/runtime/hermes_ui_runtime.gd")

const MANIFEST_PATH := "res://addons/hermes_os/scripts/apps/command_palette/manifest.json"

var _shell: Node
var _fs: Object
var _runtime = null
var _instance = null
var _mounted: Control = null

func os_app_init(context: Dictionary) -> void:
	_shell = context.get("shell", null) as Node
	_fs = context.get("filesystem", null) as Object
	if _fs == null and _shell != null:
		_fs = _shell._fs
	_build()

func os_app_focus() -> void:
	if _instance == null or _instance.controller == null:
		return
	if _instance.controller.has_method("focus_primary"):
		_instance.controller.call("focus_primary")

func os_app_close_requested() -> bool:
	return true

func _build() -> void:
	for child in get_children():
		child.queue_free()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(620, 420)
	set_meta("window_min_size", Vector2(620, 420))

	_runtime = HermesUIRuntime.new()
	_runtime.set_os_context({
		"shell": _shell,
		"filesystem": _fs,
		"event_bus": _shell.get("_event_bus") if _shell != null else null,
		"window_manager": _shell.get("_window_manager") if _shell != null else null,
		"app_registry": _shell.get("_app_registry") if _shell != null else null,
		"notification_center": _shell.get("_notification_center") if _shell != null else null,
		"agent_service": _shell.get("_hermes_agent_service") if _shell != null else null
	})
	_instance = _runtime.create_app_instance(MANIFEST_PATH)
	set_meta("hermes_ui_runtime", _runtime)
	set_meta("hermes_ui_instance", _instance)
	if _instance == null:
		add_child(_error_label("Command Palette manifest failed to load."))
		return
	_mounted = _runtime.mount_instance(_instance, self)
	if _mounted == null:
		add_child(_error_label("Command Palette runtime failed to mount."))
	_configure_controller()
	if not tree_exiting.is_connected(Callable(self, "_on_tree_exiting")):
		tree_exiting.connect(_on_tree_exiting)

func _on_tree_exiting() -> void:
	if _runtime != null and _instance != null:
		_runtime.unmount_instance(_instance)

func _configure_controller() -> void:
	if _instance == null or _instance.controller == null:
		return
	var action_registry: Variant = null
	if _shell != null and _shell.has_method("command_action_registry"):
		action_registry = _shell.call("command_action_registry")
	if _instance.controller.has_method("configure_app_context"):
		_instance.controller.call("configure_app_context", {
			"shell": _shell,
			"filesystem": _fs,
			"action_registry": action_registry
		})

func _error_label(message: String) -> Label:
	var label := Label.new()
	label.name = "CommandPaletteRuntimeError"
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label
