class_name AgentContextBuilder
extends RefCounted

const OSEventBus = preload("res://addons/hermes_os/scripts/os/core/os_event_bus.gd")

var _shell: Node
var _event_bus: OSEventBus
var _filesystem: RefCounted
var _window_manager: RefCounted
var _app_registry: RefCounted
var _notification_center: RefCounted

func agent_context_init(context: Dictionary) -> void:
	_shell = context.get("shell", null) as Node
	_event_bus = context.get("event_bus", null) as OSEventBus
	_filesystem = context.get("filesystem", null) as RefCounted
	_window_manager = context.get("window_manager", null) as RefCounted
	_app_registry = context.get("app_registry", null) as RefCounted
	_notification_center = context.get("notification_center", null) as RefCounted

func build_context(options: Dictionary = {}) -> Dictionary:
	var cwd: String = str(options.get("cwd", _home_path()))
	if _filesystem != null and _filesystem.has_method("normalize_path"):
		cwd = str(_filesystem.call("normalize_path", cwd))
	return {
		"os": {
			"name": "HermesOS",
			"version": "dev",
			"current_user": _current_user(),
			"timestamp": _timestamp_text()
		},
		"agent": {
			"service": "HermesAgentService",
			"mode": str(options.get("mode", "terminal")),
			"capabilities": get_agent_capabilities_stub()
		},
		"apps": get_app_summary(),
		"windows": get_visible_windows(),
		"filesystem": get_filesystem_summary({
			"cwd": cwd,
			"max_visible_paths": int(options.get("max_visible_paths", 12))
		}),
		"terminal": _terminal_context_from_options(options, cwd),
		"bridge": _bridge_state(),
		"legacy_state": _legacy_state_summary()
	}

func build_terminal_context(prompt: String, terminal_context: Dictionary = {}) -> Dictionary:
	var options: Dictionary = terminal_context.duplicate(true)
	options["mode"] = "terminal"
	options["prompt"] = prompt.strip_edges()
	var context: Dictionary = build_context(options)
	context["terminal"] = {
		"prompt": prompt.strip_edges(),
		"cwd": str(options.get("cwd", _home_path())),
		"user": str(options.get("user", _current_user())),
		"source": str(options.get("source", "terminal")),
		"terminal_session_id": str(options.get("terminal_session_id", ""))
	}
	return context

func get_visible_windows() -> Array:
	var result: Array = []
	if _window_manager == null or not _window_manager.has_method("get_windows"):
		return result
	var windows_value: Variant = _window_manager.call("get_windows")
	if not (windows_value is Array):
		return result
	for window_value in windows_value:
		if not (window_value is Dictionary):
			continue
		var window: Dictionary = window_value
		result.append({
			"window_id": int(window.get("window_id", 0)),
			"app_id": str(window.get("app_id", "")),
			"title": str(window.get("title", "")),
			"focused": bool(window.get("focused", false)),
			"visible": bool(window.get("visible", false)),
			"tiled": bool(window.get("tiled", false)),
			"floating": bool(window.get("floating", true)),
			"tileable": bool(window.get("tileable", true)),
			"tiling_layout": str(window.get("tiling_layout", ""))
		})
	return result

func get_app_summary() -> Array:
	var result: Array = []
	if _app_registry == null or not _app_registry.has_method("get_launcher_apps"):
		return result
	var apps_value: Variant = _app_registry.call("get_launcher_apps")
	if not (apps_value is Array):
		return result
	for app_value in apps_value:
		if not (app_value is Dictionary):
			continue
		var app: Dictionary = app_value
		if not bool(app.get("agent_visible", true)):
			continue
		var actions_value: Variant = app.get("agent_actions", [])
		var actions: Array = actions_value.duplicate() if actions_value is Array else []
		result.append({
			"id": str(app.get("id", "")),
			"name": str(app.get("name", app.get("title", ""))),
			"title": str(app.get("title", app.get("name", ""))),
			"description": str(app.get("description", "")),
			"category": str(app.get("category", "Other")),
			"pinned": bool(app.get("pinned", false)),
			"single_instance": bool(app.get("single_instance", true)),
			"agent_actions": actions
		})
	return result

func get_filesystem_summary(options: Dictionary = {}) -> Dictionary:
	var home: String = _home_path()
	var cwd: String = str(options.get("cwd", home))
	if _filesystem != null and _filesystem.has_method("normalize_path"):
		cwd = str(_filesystem.call("normalize_path", cwd))
	var visible_paths: Array = []
	if _filesystem != null and _filesystem.has_method("is_dir") and _filesystem.has_method("list_dir") and bool(_filesystem.call("is_dir", cwd)):
		var entries_value: Variant = _filesystem.call("list_dir", cwd)
		if entries_value is Array:
			var max_paths: int = maxi(int(options.get("max_visible_paths", 12)), 0)
			var count: int = 0
			for entry_value in entries_value:
				if count >= max_paths:
					break
				if not (entry_value is Dictionary):
					continue
				var entry: Dictionary = entry_value
				visible_paths.append({
					"name": str(entry.get("name", "")),
					"path": str(entry.get("path", "")),
					"type": str(entry.get("type", "")),
					"size": int(entry.get("size", 0)),
					"owner": str(entry.get("owner", ""))
				})
				count += 1
	return {
		"cwd": cwd,
		"home": home,
		"current_user": _current_user(),
		"visible_paths": visible_paths
	}

func get_agent_capabilities_stub() -> Array:
	return []

func _terminal_context_from_options(options: Dictionary, cwd: String) -> Dictionary:
	return {
		"prompt": str(options.get("prompt", "")),
		"cwd": cwd,
		"user": str(options.get("user", _current_user())),
		"source": str(options.get("source", "terminal")),
		"terminal_session_id": str(options.get("terminal_session_id", ""))
	}

func _legacy_state_summary() -> Dictionary:
	if _shell == null or not _shell.has_method("hermes_get_state"):
		return {}
	var legacy_value: Variant = _shell.call("hermes_get_state", {
		"include_apps": true,
		"include_windows": true,
		"include_filesystem": false
	})
	if not (legacy_value is Dictionary):
		return {}
	var legacy: Dictionary = _sanitize_value(legacy_value, 5)
	if legacy.has("notifications") and legacy["notifications"] is Array:
		var notifications: Array = legacy["notifications"]
		legacy["notifications"] = notifications.slice(0, mini(notifications.size(), 5))
	if legacy.has("windows") and legacy["windows"] is Array:
		var windows: Array = legacy["windows"]
		legacy["windows"] = windows.slice(0, mini(windows.size(), 12))
	return legacy

func _bridge_state() -> Dictionary:
	if _shell != null and _shell.has_method("_kernel_bridge_state"):
		var state: Variant = _shell.call("_kernel_bridge_state")
		if state is Dictionary:
			return _sanitize_value(state, 4)
	return {
		"connected": false,
		"endpoint": "",
		"session_id": "",
		"last_message_at": 0,
		"last_error": {},
		"metrics": {}
	}

func _home_path() -> String:
	if _filesystem != null and _filesystem.has_method("home_path"):
		return str(_filesystem.call("home_path"))
	return "/home/player"

func _current_user() -> String:
	if _filesystem != null and _filesystem.has_method("current_user"):
		return str(_filesystem.call("current_user"))
	return "player"

func _timestamp_text() -> String:
	var now := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02dT%02d:%02d:%02d" % [now.year, now.month, now.day, now.hour, now.minute, now.second]

func _sanitize_value(value: Variant, depth: int = 4) -> Variant:
	if depth <= 0:
		return "..."
	if value is Object:
		return "<%s>" % (value as Object).get_class()
	match typeof(value):
		TYPE_DICTIONARY:
			var output: Dictionary = {}
			var dict_value: Dictionary = value
			for key in dict_value.keys():
				var key_text := str(key)
				if key_text == "builder":
					continue
				output[key_text] = _sanitize_value(dict_value[key], depth - 1)
			return output
		TYPE_ARRAY:
			var output_array: Array = []
			var array_value: Array = value
			for item in array_value:
				output_array.append(_sanitize_value(item, depth - 1))
			return output_array
		TYPE_CALLABLE:
			return "<Callable>"
		TYPE_SIGNAL:
			return "<Signal>"
		TYPE_VECTOR2:
			var vector2_value: Vector2 = value
			return [vector2_value.x, vector2_value.y]
		TYPE_VECTOR3:
			var vector3_value: Vector3 = value
			return [vector3_value.x, vector3_value.y, vector3_value.z]
		TYPE_COLOR:
			var color_value: Color = value
			return [color_value.r, color_value.g, color_value.b, color_value.a]
		_:
			return value
