class_name AgentOperationRouter
extends RefCounted

const OSEventBus = preload("res://addons/hermes_os/scripts/os/core/os_event_bus.gd")
const HermesProtocol = preload("res://addons/hermes_os/scripts/hermes/hermes_protocol.gd")
const AgentCapabilityRegistry = preload("res://addons/hermes_os/scripts/os/agent/agent_capability_registry.gd")

var _shell: Node
var _event_bus: OSEventBus
var _filesystem: RefCounted
var _window_manager: RefCounted
var _app_registry: RefCounted
var _notification_center: RefCounted
var _capability_registry: AgentCapabilityRegistry
var _initialized: bool = false

func agent_router_init(context: Dictionary) -> void:
	_shell = context.get("shell", null) as Node
	_event_bus = context.get("event_bus", null) as OSEventBus
	_filesystem = context.get("filesystem", null) as RefCounted
	_window_manager = context.get("window_manager", null) as RefCounted
	_app_registry = context.get("app_registry", null) as RefCounted
	_notification_center = context.get("notification_center", null) as RefCounted
	_capability_registry = AgentCapabilityRegistry.new()
	_capability_registry.capability_registry_init()
	_initialized = true

func is_initialized() -> bool:
	return _initialized

func execute_operation(op: String, args: Dictionary = {}) -> Dictionary:
	var normalized: Dictionary = _normalize_operation(op, args)
	var operation: String = str(normalized.get("op", "")).strip_edges()
	var operation_args: Dictionary = normalized.get("args", {}) if normalized.get("args", {}) is Dictionary else {}
	if operation == "":
		var missing: Dictionary = _make_error("", "MISSING_OPERATION", "Operation name is required")
		_emit_operation_event(OSEventBus.AGENT_OPERATION_FAILED, missing)
		return missing

	_emit_operation_event(OSEventBus.AGENT_OPERATION_REQUESTED, {
		"operation": operation,
		"args": operation_args.duplicate(true)
	})
	var routed: Dictionary = _route_operation(operation, operation_args)
	var shaped: Dictionary = _shape_result(operation, routed)
	if bool(shaped.get("ok", false)):
		_emit_operation_event(OSEventBus.AGENT_OPERATION_COMPLETED, shaped)
	else:
		_emit_operation_event(OSEventBus.AGENT_OPERATION_FAILED, shaped)
	return shaped

func get_supported_operations() -> Array[String]:
	if _capability_registry != null:
		return _capability_registry.get_supported_operations()
	return [
		"files.list_dir",
		"files.read_file",
		"files.write_file",
		"windows.list",
		"windows.open_app",
		"windows.focus",
		"notifications.create",
		"system.get_state"
	]

func get_operation_metadata(operation: String) -> Dictionary:
	var normalized: Dictionary = _normalize_operation(operation, {})
	var clean_operation: String = str(normalized.get("op", operation)).strip_edges()
	if _capability_registry != null:
		return _capability_registry.get_metadata(clean_operation)
	return {
		"operation": clean_operation,
		"capability": "legacy.compat",
		"risk": "medium",
		"mutates_state": false,
		"description": "Legacy or unknown operation routed through compatibility dispatch",
		"requires_approval": false
	}

func describe_operation(operation: String) -> Dictionary:
	return get_operation_metadata(operation)

func _route_operation(operation: String, args: Dictionary) -> Dictionary:
	if operation == "hermes.propose_operation":
		return _route_proposed_operation(args)
	match operation:
		"files.list_dir", "files.list_directory":
			return _route_files_list_dir(operation, args)
		"files.read_file":
			return _route_files_read_file(operation, args)
		"files.write_file":
			return _route_files_write_file(operation, args)
		"files.mkdir", "files.create_folder":
			return _route_files_mkdir(operation, args)
		"files.delete":
			return _route_files_delete(operation, args)
		"files.move":
			return _route_files_move(operation, args)
		"files.copy":
			return _route_files_copy(operation, args)
		"windows.list":
			return _route_windows_list(operation, args)
		"windows.open_app":
			return _route_windows_open_app(operation, args)
		"windows.focus", "windows.focus_window":
			return _route_windows_focus(operation, args)
		"windows.tiling.get_state":
			return _route_windows_tiling_get_state(operation, args)
		"windows.tiling.toggle":
			return _route_windows_tiling_toggle(operation, args)
		"windows.tiling.set_enabled":
			return _route_windows_tiling_set_enabled(operation, args)
		"windows.tiling.float_window":
			return _route_windows_tiling_float_window(operation, args)
		"windows.tiling.tile_window":
			return _route_windows_tiling_tile_window(operation, args)
		"windows.tiling.set_layout":
			return _route_windows_tiling_set_layout(operation, args)
		"browser.get_state":
			return _route_browser_operation(operation, args, "agent_browser_get_state", false)
		"browser.navigate":
			return _route_browser_operation(operation, args, "agent_browser_navigate", true)
		"browser.back":
			return _route_browser_operation(operation, args, "agent_browser_back", true)
		"browser.forward":
			return _route_browser_operation(operation, args, "agent_browser_forward", true)
		"browser.reload":
			return _route_browser_operation(operation, args, "agent_browser_reload", true)
		"browser.list_links":
			return _route_browser_operation(operation, args, "agent_browser_list_links", true)
		"browser.activate_link":
			return _route_browser_operation(operation, args, "agent_browser_activate_link", true)
		"browser.test_click":
			return _route_browser_operation(operation, args, "agent_browser_test_click", true)
		"browser.test_type_text":
			return _route_browser_operation(operation, args, "agent_browser_test_type_text", true)
		"browser.test_press_key":
			return _route_browser_operation(operation, args, "agent_browser_test_press_key", true)
		"browser.test_scroll":
			return _route_browser_operation(operation, args, "agent_browser_test_scroll", true)
		"notifications.create", "desktop.show_notification":
			return _route_notifications_create(operation, args)
		"system.get_state":
			return _route_system_get_state(operation, args)
		"home.light_on":
			return _route_home_device("ceiling_light", "on", operation)
		"home.light_off":
			return _route_home_device("ceiling_light", "off", operation)
		"home.light_toggle":
			return _route_home_device("ceiling_light", "toggle", operation)
		"home.light_color":
			return _route_home_color(operation, args)
		"home.light_status":
			return _route_home_status(operation)
		"home.device_list":
			return _route_home_device_list(operation)
		_:
			return _route_legacy_shell(operation, args)

func _route_proposed_operation(args: Dictionary) -> Dictionary:
	var proposed_op: String = str(args.get("op", "")).strip_edges()
	var proposed_args: Dictionary = {}
	var proposed_args_value: Variant = args.get("args", {})
	if proposed_args_value is Dictionary:
		proposed_args = (proposed_args_value as Dictionary).duplicate(true)
	if proposed_op == "":
		return _make_error("hermes.propose_operation", "MISSING_ARG", "hermes.propose_operation requires op")
	if proposed_op == "hermes.propose_operation":
		return _make_error("hermes.propose_operation", "INVALID_PROPOSAL", "Nested hermes.propose_operation is not allowed")
	var normalized: Dictionary = _normalize_operation(proposed_op, proposed_args)
	proposed_op = str(normalized.get("op", "")).strip_edges()
	proposed_args = normalized.get("args", {}) if normalized.get("args", {}) is Dictionary else {}
	if _shell != null and _shell.has_method("_append_hermes_terminal_output"):
		_shell.call("_append_hermes_terminal_output", "Executing proposed operation: %s" % proposed_op, str(args.get("source", "Hermes")))
	return execute_operation(proposed_op, proposed_args)

func _route_files_list_dir(operation: String, args: Dictionary) -> Dictionary:
	if _filesystem == null:
		return _make_error(operation, "FILESYSTEM_UNAVAILABLE", "Filesystem service is unavailable")
	var list_path: String = _normalize_path(str(args.get("path", _home_path())))
	if not bool(_filesystem.call("is_dir", list_path)):
		return _make_error(operation, "DIR_NOT_FOUND", "Directory not found: " + list_path)
	return _make_result(operation, {"path": list_path, "entries": _filesystem.call("list_dir", list_path)})

func _route_files_read_file(operation: String, args: Dictionary) -> Dictionary:
	if _filesystem == null:
		return _make_error(operation, "FILESYSTEM_UNAVAILABLE", "Filesystem service is unavailable")
	var read_path: String = _normalize_path(str(args.get("path", "")))
	if read_path == "":
		return _make_error(operation, "MISSING_ARG", "files.read_file requires path")
	var read_result: Dictionary = _filesystem.call("read_file_result", read_path)
	if not bool(read_result.get("ok", false)):
		return _make_error(operation, "READ_FAILED", str(read_result.get("error", "Could not read file")))
	return _make_result(operation, {"path": read_path, "content": str(read_result.get("content", ""))})

func _route_files_write_file(operation: String, args: Dictionary) -> Dictionary:
	if _filesystem == null:
		return _make_error(operation, "FILESYSTEM_UNAVAILABLE", "Filesystem service is unavailable")
	var write_path: String = _normalize_path(str(args.get("path", "")))
	if write_path == "":
		return _make_error(operation, "MISSING_ARG", "files.write_file requires path")
	var had_file: bool = bool(_filesystem.call("exists", write_path))
	var write_message: String = str(_filesystem.call("write_file", write_path, str(args.get("content", ""))))
	if write_message != "":
		return _make_error(operation, "WRITE_FAILED", write_message)
	_emit_shell_event("file.updated" if had_file else "file.created", {"path": write_path})
	return _make_result(operation, {"path": write_path, "saved": true})

func _route_files_mkdir(operation: String, args: Dictionary) -> Dictionary:
	if _filesystem == null:
		return _make_error(operation, "FILESYSTEM_UNAVAILABLE", "Filesystem service is unavailable")
	var dir_path: String = _normalize_path(str(args.get("path", args.get("directory", args.get("dir", "")))))
	if dir_path == "":
		return _make_error(operation, "MISSING_ARG", "files.mkdir requires path")
	var mkdir_message: String = str(_filesystem.call("make_dir", dir_path))
	if mkdir_message != "":
		return _make_error(operation, "MKDIR_FAILED", mkdir_message)
	_emit_shell_event("file.created", {"path": dir_path, "type": "dir"})
	return _make_result(operation, {"path": dir_path, "created": true, "type": "dir"})

func _route_files_delete(operation: String, args: Dictionary) -> Dictionary:
	if _filesystem == null:
		return _make_error(operation, "FILESYSTEM_UNAVAILABLE", "Filesystem service is unavailable")
	var delete_path: String = _normalize_path(str(args.get("path", args.get("target", ""))))
	if delete_path == "":
		return _make_error(operation, "MISSING_ARG", "files.delete requires path")
	var delete_message: String = str(_filesystem.call("delete_path", delete_path))
	if delete_message != "":
		return _make_error(operation, "DELETE_FAILED", delete_message)
	_emit_shell_event("file.deleted", {"path": delete_path})
	return _make_result(operation, {"path": delete_path, "deleted": true})

func _route_files_move(operation: String, args: Dictionary) -> Dictionary:
	if _filesystem == null:
		return _make_error(operation, "FILESYSTEM_UNAVAILABLE", "Filesystem service is unavailable")
	var source_path: String = _normalize_path(str(args.get("source", args.get("src", args.get("from", "")))))
	var destination_path: String = _normalize_path(str(args.get("destination", args.get("dest", args.get("to", "")))))
	if source_path == "" or destination_path == "":
		return _make_error(operation, "MISSING_ARG", "files.move requires source and destination")
	var move_message: String = str(_filesystem.call("move_path", source_path, destination_path))
	if move_message != "":
		return _make_error(operation, "MOVE_FAILED", move_message)
	_emit_shell_event("file.moved", {"source": source_path, "destination": destination_path})
	return _make_result(operation, {"source": source_path, "destination": destination_path, "moved": true})

func _route_files_copy(operation: String, args: Dictionary) -> Dictionary:
	if _filesystem == null:
		return _make_error(operation, "FILESYSTEM_UNAVAILABLE", "Filesystem service is unavailable")
	var source_path: String = _normalize_path(str(args.get("source", args.get("src", args.get("from", "")))))
	var destination_path: String = _normalize_path(str(args.get("destination", args.get("dest", args.get("to", "")))))
	if source_path == "" or destination_path == "":
		return _make_error(operation, "MISSING_ARG", "files.copy requires source and destination")
	var copy_message: String = str(_filesystem.call("copy_path", source_path, destination_path))
	if copy_message != "":
		return _make_error(operation, "COPY_FAILED", copy_message)
	_emit_shell_event("file.copied", {"source": source_path, "destination": destination_path})
	return _make_result(operation, {"source": source_path, "destination": destination_path, "copied": true})

func _route_windows_list(operation: String, _args: Dictionary) -> Dictionary:
	if _window_manager != null and _window_manager.has_method("get_windows"):
		var windows_value: Variant = _window_manager.call("get_windows")
		var windows: Array = windows_value.duplicate(true) if windows_value is Array else []
		return _make_result(operation, {"windows": windows})
	if _shell != null and _shell.has_method("hermes_get_state"):
		var state: Variant = _shell.call("hermes_get_state", {"include_apps": false, "include_windows": true, "include_filesystem": false})
		if state is Dictionary:
			return _make_result(operation, {"windows": (state as Dictionary).get("windows", [])})
	return _make_result(operation, {"windows": []})

func _route_windows_open_app(operation: String, args: Dictionary) -> Dictionary:
	if _shell == null or not _shell.has_method("launch_app"):
		return _make_error(operation, "SHELL_UNAVAILABLE", "Shell launch_app boundary is unavailable")
	var app_id: String = str(args.get("app_id", ""))
	if app_id == "":
		return _make_error(operation, "MISSING_ARG", "windows.open_app requires app_id")
	var window: Variant = _shell.call("launch_app", app_id)
	if window == null:
		return _make_error(operation, "OPEN_FAILED", "Could not open app: " + app_id)
	return _make_result(operation, {"window_id": _window_id_for(window), "app_id": app_id})

func _route_windows_focus(operation: String, args: Dictionary) -> Dictionary:
	if _shell == null:
		return _make_error(operation, "SHELL_UNAVAILABLE", "Shell focus boundary is unavailable")
	var focus_window_id: String = str(args.get("window_id", ""))
	var focus_app_id: String = str(args.get("app_id", ""))
	var target_window: Variant = null
	if focus_window_id != "" and _shell.has_method("_find_window_by_id"):
		target_window = _shell.call("_find_window_by_id", focus_window_id)
	if target_window == null and focus_app_id != "" and _window_manager != null and _window_manager.has_method("get_window_for_app"):
		target_window = _window_manager.call("get_window_for_app", StringName(focus_app_id))
	if target_window == null:
		return _make_error(operation, "WINDOW_NOT_FOUND", "Window not found")
	_focus_window_object(target_window)
	return _make_result(operation, {"window_id": _window_id_for(target_window), "app_id": str(target_window.get("app_id")) if target_window is Object else focus_app_id})

func _route_windows_tiling_get_state(operation: String, _args: Dictionary) -> Dictionary:
	if _window_manager == null or not _window_manager.has_method("get_tiling_state"):
		return _make_error(operation, "WINDOW_MANAGER_UNAVAILABLE", "Window manager tiling state is unavailable")
	return _make_result(operation, {"tiling": _window_manager.call("get_tiling_state")})

func _route_windows_tiling_toggle(operation: String, _args: Dictionary) -> Dictionary:
	if _window_manager == null or not _window_manager.has_method("toggle_tiling"):
		return _make_error(operation, "WINDOW_MANAGER_UNAVAILABLE", "Window manager tiling toggle is unavailable")
	_window_manager.call("toggle_tiling")
	return _route_windows_tiling_get_state(operation, {})

func _route_windows_tiling_set_enabled(operation: String, args: Dictionary) -> Dictionary:
	if _window_manager == null or not _window_manager.has_method("set_tiling_enabled"):
		return _make_error(operation, "WINDOW_MANAGER_UNAVAILABLE", "Window manager tiling set_enabled is unavailable")
	_window_manager.call("set_tiling_enabled", bool(args.get("enabled", false)))
	return _route_windows_tiling_get_state(operation, {})

func _route_windows_tiling_float_window(operation: String, args: Dictionary) -> Dictionary:
	if _window_manager == null or not _window_manager.has_method("float_window"):
		return _make_error(operation, "WINDOW_MANAGER_UNAVAILABLE", "Window manager tiling float_window is unavailable")
	var window_id := int(args.get("window_id", 0))
	if window_id <= 0:
		return _make_error(operation, "MISSING_ARG", "windows.tiling.float_window requires numeric window_id")
	_window_manager.call("float_window", window_id)
	return _route_windows_tiling_get_state(operation, {})

func _route_windows_tiling_tile_window(operation: String, args: Dictionary) -> Dictionary:
	if _window_manager == null or not _window_manager.has_method("tile_window"):
		return _make_error(operation, "WINDOW_MANAGER_UNAVAILABLE", "Window manager tiling tile_window is unavailable")
	var window_id := int(args.get("window_id", 0))
	if window_id <= 0:
		return _make_error(operation, "MISSING_ARG", "windows.tiling.tile_window requires numeric window_id")
	_window_manager.call("tile_window", window_id)
	return _route_windows_tiling_get_state(operation, {})

func _route_windows_tiling_set_layout(operation: String, args: Dictionary) -> Dictionary:
	if _window_manager == null or not _window_manager.has_method("set_tiling_layout"):
		return _make_error(operation, "WINDOW_MANAGER_UNAVAILABLE", "Window manager tiling set_layout is unavailable")
	_window_manager.call("set_tiling_layout", str(args.get("layout", "tall")))
	return _route_windows_tiling_get_state(operation, {})

func _route_browser_operation(operation: String, args: Dictionary, method_name: String, open_if_missing: bool) -> Dictionary:
	var target := _ensure_browser_operation_target(operation, open_if_missing)
	if not bool(target.get("ok", false)):
		return target
	var browser: Object = target.get("browser", null) as Object
	if browser == null or not browser.has_method(method_name):
		return _make_error(operation, "BROWSER_OPERATION_UNAVAILABLE", "Browser operation is unavailable: " + operation)
	var result_value: Variant = browser.call(method_name, args.duplicate(true))
	if not (result_value is Dictionary):
		return _make_error(operation, "BAD_RESULT", "Browser operation returned a non-dictionary result")
	var result: Dictionary = (result_value as Dictionary).duplicate(true)
	result["operation"] = operation
	if bool(result.get("success", false)):
		return _make_result(operation, result)
	var code := str(result.get("code", "BROWSER_OPERATION_FAILED"))
	var message := str(result.get("error", "Browser operation failed: " + operation))
	return _make_error(operation, code, message, result)

func _ensure_browser_operation_target(operation: String, open_if_missing: bool) -> Dictionary:
	var window: Variant = null
	if _window_manager != null and _window_manager.has_method("get_window_for_app"):
		window = _window_manager.call("get_window_for_app", StringName("browser"))
	if window == null and open_if_missing:
		if _shell == null or not _shell.has_method("launch_app"):
			return _make_error(operation, "SHELL_UNAVAILABLE", "Shell launch_app boundary is unavailable")
		window = _shell.call("launch_app", "browser")
	if window == null:
		return _make_error(operation, "BROWSER_NOT_OPEN", "Browser is not open")
	_focus_window_object(window)
	var browser := _find_browser_operation_node(window as Node)
	if browser == null:
		return _make_error(operation, "BROWSER_SURFACE_UNAVAILABLE", "Browser app node is unavailable")
	return {"ok": true, "browser": browser, "window": window}

func _focus_window_object(window: Variant) -> void:
	if window == null:
		return
	if _shell != null and _shell.has_method("_focus_window"):
		_shell.call("_focus_window", window)
		return
	if _window_manager != null and _window_manager.has_method("get_window_id") and _window_manager.has_method("focus_window"):
		_window_manager.call("focus_window", int(_window_manager.call("get_window_id", window)))

func _find_browser_operation_node(root: Node) -> Object:
	if root == null or not is_instance_valid(root):
		return null
	if root.has_method("agent_browser_navigate"):
		return root
	for child in root.get_children():
		var found := _find_browser_operation_node(child)
		if found != null:
			return found
	return null

func _route_notifications_create(operation: String, args: Dictionary) -> Dictionary:
	if _shell == null or not _shell.has_method("notify"):
		return _make_error(operation, "SHELL_UNAVAILABLE", "Shell notify boundary is unavailable")
	var title: String = str(args.get("title", "Hermes"))
	var body: String = str(args.get("body", ""))
	var level: String = str(args.get("level", "info"))
	var notification_id: String = str(_shell.call("notify", {"title": title, "body": body, "level": level, "app_id": str(args.get("app_id", "hermes"))}))
	return _make_result(operation, {"displayed": true, "notification_id": notification_id})

func _route_system_get_state(operation: String, args: Dictionary) -> Dictionary:
	if _shell == null or not _shell.has_method("hermes_get_state"):
		return _make_error(operation, "SHELL_UNAVAILABLE", "Shell state boundary is unavailable")
	var state_options: Dictionary = {
		"include_apps": bool(args.get("include_apps", true)),
		"include_windows": bool(args.get("include_windows", true)),
		"include_filesystem": bool(args.get("include_filesystem", false))
	}
	var state: Variant = _shell.call("hermes_get_state", state_options)
	if not (state is Dictionary):
		return _make_error(operation, "STATE_UNAVAILABLE", "HermesOS state snapshot unavailable")
	return _make_result(operation, (state as Dictionary).duplicate(true))

func _route_legacy_shell(operation: String, args: Dictionary) -> Dictionary:
	if _shell != null and _shell.has_method("_hermes_execute_operation_legacy_dispatch"):
		var legacy_result: Variant = _shell.call("_hermes_execute_operation_legacy_dispatch", operation, args.duplicate(true))
		if legacy_result is Dictionary:
			return legacy_result as Dictionary
	return _make_error(operation, "UNKNOWN_OPERATION", "No registered operation: " + operation)

func _route_home_device(device_id: String, command: String, operation: String) -> Dictionary:
	var controller = _get_home_device_controller()
	if controller == null:
		return _make_error(operation, "HOME_DEVICE_UNAVAILABLE", "HomeDeviceController is not available")
	var result: Dictionary = controller.call("execute_command", device_id, command)
	if bool(result.get("ok", false)):
		return _make_result(operation, {"message": str(result.get("message", "Done.")), "device": device_id, "command": command, "state": result.get("state", {})})
	return _make_error(operation, "DEVICE_COMMAND_FAILED", str(result.get("message", "Command failed")))

func _route_home_color(operation: String, args: Dictionary) -> Dictionary:
	var controller = _get_home_device_controller()
	if controller == null:
		return _make_error(operation, "HOME_DEVICE_UNAVAILABLE", "HomeDeviceController is not available")
	var color_name: String = str(args.get("color", "")).strip_edges().to_lower()
	if color_name == "":
		return _make_error(operation, "MISSING_COLOR", "Specify a color name (e.g. purple, blue, red)")
	var result: Dictionary = controller.call("execute_command", "ceiling_light", "color", {"color": color_name})
	if bool(result.get("ok", false)):
		return _make_result(operation, {"message": str(result.get("message", "Done.")), "device": "ceiling_light", "color": color_name, "state": result.get("state", {})})
	return _make_error(operation, "COLOR_FAILED", str(result.get("message", "Color change failed")))

func _route_home_status(operation: String) -> Dictionary:
	var controller = _get_home_device_controller()
	if controller == null:
		return _make_error(operation, "HOME_DEVICE_UNAVAILABLE", "HomeDeviceController is not available")
	var state: Dictionary = controller.call("get_device_state", "ceiling_light")
	var is_on: bool = bool(state.get("is_on", false))
	return _make_result(operation, {"device": "ceiling_light", "is_on": is_on, "status": "on" if is_on else "off"})

func _route_home_device_list(operation: String) -> Dictionary:
	var controller = _get_home_device_controller()
	if controller == null:
		return _make_error(operation, "HOME_DEVICE_UNAVAILABLE", "HomeDeviceController is not available")
	var devices: Dictionary = controller.call("get_all_devices")
	return _make_result(operation, {"devices": devices})

func _get_home_device_controller():
	if _shell != null and is_instance_valid(_shell):
		var controller = _shell.get_node_or_null("/root/HomeDeviceController")
		if controller != null:
			return controller
	# Fallback: try scene tree directly
	var tree = Engine.get_main_loop()
	if tree != null and tree is SceneTree:
		var controller = tree.root.get_node_or_null("HomeDeviceController")
		if controller != null:
			return controller
	return null

func _normalize_operation(op: String, args: Dictionary) -> Dictionary:
	if _shell != null and _shell.has_method("_normalize_v1_operation"):
		var normalized: Variant = _shell.call("_normalize_v1_operation", op, args.duplicate(true))
		if normalized is Dictionary:
			return normalized as Dictionary
	return {"op": op.strip_edges(), "args": args.duplicate(true)}

func _shape_result(operation: String, response: Dictionary) -> Dictionary:
	var ok: bool = bool(response.get("ok", false))
	var result_value: Variant = response.get("result", {})
	var result: Dictionary = result_value.duplicate(true) if result_value is Dictionary else {"value": result_value}
	var error_value: Variant = response.get("error", {})
	var error: Dictionary = error_value.duplicate(true) if error_value is Dictionary else {}
	if not ok and error.is_empty():
		error = HermesProtocol.make_error("OPERATION_FAILED", "Operation failed: " + operation)
	return {
		"ok": ok,
		"error": {} if ok else error,
		"result": result,
		"operation": str(response.get("operation", operation))
	}

func _make_result(operation: String, result: Dictionary = {}) -> Dictionary:
	return {"ok": true, "error": {}, "result": result.duplicate(true), "operation": operation}

func _make_error(operation: String, code: String, message: String, details: Dictionary = {}) -> Dictionary:
	return {"ok": false, "error": HermesProtocol.make_error(code, message, details), "result": {}, "operation": operation}

func _emit_operation_event(event_name: StringName, payload: Dictionary) -> void:
	var safe_payload: Dictionary = payload.duplicate(true)
	if _event_bus != null:
		_event_bus.emit_event(event_name, safe_payload)
		return
	_emit_shell_event(str(event_name), safe_payload)

func _emit_shell_event(event_name: String, payload: Dictionary = {}) -> void:
	if _shell != null and _shell.has_method("_emit_hermes_event"):
		_shell.call("_emit_hermes_event", event_name, payload.duplicate(true))

func _normalize_path(path: String) -> String:
	if _filesystem != null and _filesystem.has_method("normalize_path"):
		return str(_filesystem.call("normalize_path", path))
	return path

func _home_path() -> String:
	if _filesystem != null and _filesystem.has_method("home_path"):
		return str(_filesystem.call("home_path"))
	return "/home/player"

func _window_id_for(window: Variant) -> String:
	if window == null:
		return ""
	if _shell != null and _shell.has_method("_window_id"):
		return str(_shell.call("_window_id", window))
	if _window_manager != null and _window_manager.has_method("get_window_id"):
		return str(_window_manager.call("get_window_id", window))
	if window is Object:
		return "win_%s" % str((window as Object).get_instance_id())
	return ""
