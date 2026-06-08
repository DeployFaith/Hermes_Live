class_name TerminalApp
extends Control

const HermesUIRuntime = preload("res://addons/hermes_os/scripts/ui/hermes_ui/runtime/hermes_ui_runtime.gd")

const MANIFEST_PATH := "res://addons/hermes_os/scripts/apps/terminal/manifest.json"

var _shell: Node
var _fs: Object
var _state: Dictionary = {}
var _session_id: String = ""

var _runtime = null
var _instance = null
var _mounted: Control = null

# Compatibility fields kept for existing terminal v2 validation access.
var _view = null
var _buffer = null
var _backend = null
var _output: TextEdit
var _input: LineEdit
var _history_cursor: int = -1

func os_app_init(context: Dictionary) -> void:
	_shell = context.get("shell", null) as Node
	_fs = context.get("filesystem", null) as Object
	if _fs == null and _shell != null:
		_fs = _shell.get("_fs") as Object
	_state = context.get("state", {}) if context.get("state", {}) is Dictionary else {}
	if _state.is_empty():
		_state = {"cwd": _home_path(), "history": []}
	if not _state.has("cwd"):
		_state["cwd"] = _home_path()
	if not _state.has("history"):
		_state["history"] = []
	_session_id = str(context.get("session_id", _state.get("session_id", "")))
	if _session_id == "":
		_session_id = "terminal_%d" % int(Time.get_ticks_usec())
	_state["session_id"] = _session_id
	_build()
	_register_terminal_session()

func os_app_focus() -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	var controller = _controller()
	if controller != null and controller.has_method("focus_terminal_input"):
		controller.call("focus_terminal_input")

func os_app_get_state() -> Dictionary:
	var controller = _controller()
	if controller != null and controller.has_method("export_terminal_state"):
		var value: Variant = controller.call("export_terminal_state")
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return _state.duplicate(true)

func os_app_restore_state(state: Dictionary) -> void:
	_state = state.duplicate(true)
	if _state.is_empty():
		_state = {"cwd": _home_path(), "history": []}
	if not _state.has("cwd"):
		_state["cwd"] = _home_path()
	if not _state.has("history"):
		_state["history"] = []
	_state["session_id"] = _session_id
	var controller = _controller()
	if controller != null and controller.has_method("restore_terminal_state"):
		controller.call("restore_terminal_state", _state)

func append_external_output(text: String, source: String = "Hermes") -> void:
	var controller = _controller()
	if controller != null and controller.has_method("append_external_output"):
		controller.call("append_external_output", text, source)
		return
	if _buffer == null:
		return
	var clean_source: String = source.strip_edges()
	if clean_source == "":
		clean_source = "Hermes"
	_buffer.append_prompt_command("[" + clean_source + "]", "")
	_buffer.append_output(text if text.strip_edges() != "" else "(no output)")
	if _view != null and _view.has_method("render_text"):
		_view.call("render_text", _buffer.get_text())

func get_terminal_session_id() -> String:
	return _session_id

func request_terminal_close() -> void:
	var node: Node = self
	while node != null:
		if node is OSWindow:
			var window := node as OSWindow
			window.close_requested.emit(window)
			return
		node = node.get_parent()
	if _shell != null and _shell.has_method("close_app"):
		_shell.call("close_app", "console")

func _exit_tree() -> void:
	_unregister_terminal_session()
	if _runtime != null and _instance != null:
		_runtime.unmount_instance(_instance)

func _build() -> void:
	for child in get_children():
		child.queue_free()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(720, 460)
	set_meta("window_min_size", Vector2(720, 460))

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
		add_child(_error_label("Terminal manifest failed to load."))
		return
	_mounted = _runtime.mount_instance(_instance, self)
	if _mounted == null:
		add_child(_error_label("Terminal runtime failed to mount."))
	_configure_controller()

func _configure_controller() -> void:
	var controller = _controller()
	if controller == null:
		return
	if controller.has_method("configure_app_context"):
		controller.call("configure_app_context", {
			"shell": _shell,
			"filesystem": _fs,
			"state": _state,
			"session_id": _session_id,
			"terminal_app": self
		})

func _controller():
	if _instance == null:
		return null
	return _instance.controller

func _sync_terminal_runtime(view, buffer, backend, output: TextEdit, input: LineEdit, history_cursor: int, exported_state: Dictionary) -> void:
	_view = view
	_buffer = buffer
	_backend = backend
	_output = output
	_input = input
	_history_cursor = history_cursor
	_state = exported_state.duplicate(true)
	if _state.is_empty():
		_state = {"cwd": _home_path(), "history": [], "session_id": _session_id}
	if not _state.has("session_id"):
		_state["session_id"] = _session_id

func _register_terminal_session() -> void:
	if _shell != null and _shell.has_method("_register_terminal_instance"):
		_shell.call("_register_terminal_instance", _session_id, self)

func _unregister_terminal_session() -> void:
	if _shell != null and _shell.has_method("_unregister_terminal_instance"):
		_shell.call("_unregister_terminal_instance", _session_id, self)

func _home_path() -> String:
	if _fs != null and _fs.has_method("home_path"):
		return str(_fs.call("home_path"))
	return "/root"

func _error_label(message: String) -> Label:
	var label := Label.new()
	label.name = "TerminalRuntimeError"
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label
