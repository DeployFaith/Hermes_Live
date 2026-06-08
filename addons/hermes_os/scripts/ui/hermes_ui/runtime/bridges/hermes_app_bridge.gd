class_name HermesAppBridge
extends RefCounted

var _shell: Node = null
var _app_registry = null
var _window_manager = null

func setup(context: Dictionary) -> HermesAppBridge:
	_shell = context.get("shell", null) as Node
	_app_registry = context.get("app_registry", null)
	_window_manager = context.get("window_manager", null)
	return self

func open(app_id: String) -> Dictionary:
	if _shell != null and _shell.has_method("launch_app"):
		var window: Variant = _shell.call("launch_app", app_id)
		return {"ok": window != null, "app_id": app_id, "error": {} if window != null else _error("APP_OPEN_FAILED", "App could not be opened")}
	return {"ok": false, "app_id": app_id, "error": _error("APPS_UNAVAILABLE", "Hermes app launcher is unavailable")}

func close(app_id: String) -> Dictionary:
	if _shell != null and _shell.has_method("close_app"):
		_shell.call("close_app", app_id)
		return {"ok": true, "app_id": app_id}
	return {"ok": false, "app_id": app_id, "error": _error("APPS_UNAVAILABLE", "Hermes app closer is unavailable")}

func is_running(app_id: String) -> bool:
	for item in get_running():
		if item is Dictionary and str((item as Dictionary).get("app_id", (item as Dictionary).get("id", ""))) == app_id:
			return true
	return false

func get_installed() -> Array:
	if _app_registry != null:
		if _app_registry.has_method("get_launcher_apps"):
			return _duplicate_array(_app_registry.call("get_launcher_apps"))
		if _app_registry.has_method("export_legacy_apps"):
			var legacy: Variant = _app_registry.call("export_legacy_apps")
			if legacy is Dictionary:
				var apps: Array = []
				for key in (legacy as Dictionary).keys():
					var item: Variant = (legacy as Dictionary)[key]
					if item is Dictionary:
						apps.append((item as Dictionary).duplicate(true))
				return apps
	if _shell != null:
		var apps_value: Variant = _shell.get("_apps")
		if apps_value is Dictionary:
			var result: Array = []
			for key in (apps_value as Dictionary).keys():
				var app: Variant = (apps_value as Dictionary)[key]
				if app is Dictionary:
					result.append((app as Dictionary).duplicate(true))
			return result
	return []

func get_running() -> Array:
	if _window_manager != null and _window_manager.has_method("get_windows"):
		return _duplicate_array(_window_manager.call("get_windows"))
	if _shell != null:
		var windows_value: Variant = _shell.get("_open_windows")
		if windows_value is Dictionary:
			var result: Array = []
			for app_id in (windows_value as Dictionary).keys():
				var window: Variant = (windows_value as Dictionary)[app_id]
				if window != null:
					result.append({"app_id": str(app_id), "visible": bool(window.get("visible")) if window is Object else true})
			return result
	return []

func _duplicate_array(value) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			if item is Dictionary:
				result.append((item as Dictionary).duplicate(true))
			else:
				result.append(item)
	return result

func _error(code: String, message: String) -> Dictionary:
	return {"code": code, "message": message, "details": {}}
