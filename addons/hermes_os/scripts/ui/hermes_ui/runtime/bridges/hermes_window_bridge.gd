class_name HermesWindowBridge
extends RefCounted

var _shell: Node = null
var _window_manager = null
var _current_window = null

func setup(context: Dictionary) -> HermesWindowBridge:
	_shell = context.get("shell", null) as Node
	_window_manager = context.get("window_manager", null)
	_current_window = context.get("current_window", null)
	return self

func close_current() -> Dictionary:
	var window = _focused_window()
	if window == null:
		return _fail("WINDOW_UNAVAILABLE", "No current window is available")
	var id: int = _window_id(window)
	if _window_manager != null and id != 0 and _window_manager.has_method("close_window"):
		_window_manager.call("close_window", id)
		return {"ok": true, "window_id": id}
	if window.has_signal("close_requested"):
		window.emit_signal("close_requested", window)
		return {"ok": true, "window_id": id}
	return _fail("WINDOW_CLOSE_UNAVAILABLE", "Current window cannot be closed through the bridge")

func minimize_current() -> Dictionary:
	return _call_current_window_manager("minimize_window", "WINDOW_MINIMIZE_UNAVAILABLE")

func maximize_current() -> Dictionary:
	var window = _focused_window()
	if window == null:
		return _fail("WINDOW_UNAVAILABLE", "No current window is available")
	if window.has_method("toggle_maximize"):
		if not bool(window.get("_maximized")):
			window.call("toggle_maximize")
		return {"ok": true, "window": _window_summary(window)}
	return _fail("WINDOW_MAXIMIZE_UNAVAILABLE", "Current window cannot be maximized through the bridge")

func restore_current() -> Dictionary:
	var window = _focused_window()
	if window == null:
		return _fail("WINDOW_UNAVAILABLE", "No current window is available")
	var id: int = _window_id(window)
	if _window_manager != null and id != 0 and _window_manager.has_method("restore_window"):
		_window_manager.call("restore_window", id)
		return {"ok": true, "window": _window_summary(window)}
	if window.has_method("toggle_maximize") and bool(window.get("_maximized")):
		window.call("toggle_maximize")
		return {"ok": true, "window": _window_summary(window)}
	if window is CanvasItem:
		(window as CanvasItem).visible = true
		return {"ok": true, "window": _window_summary(window)}
	return _fail("WINDOW_RESTORE_UNAVAILABLE", "Current window cannot be restored through the bridge")

func focus(app_id: String) -> Dictionary:
	if _window_manager != null:
		if _window_manager.has_method("get_window_for_app") and _window_manager.has_method("focus_window") and _window_manager.has_method("get_window_id"):
			var window = _window_manager.call("get_window_for_app", StringName(app_id))
			if window != null:
				var id: int = int(_window_manager.call("get_window_id", window))
				_window_manager.call("focus_window", id)
				return {"ok": true, "window": _window_summary(window)}
	if _shell != null and _shell.has_method("launch_app"):
		var launched: Variant = _shell.call("launch_app", app_id)
		return {"ok": launched != null, "window": _window_summary(launched) if launched != null else {}, "error": {} if launched != null else {"code": "WINDOW_FOCUS_FAILED", "message": "Window could not be focused", "details": {}}}
	return _fail("WINDOW_FOCUS_UNAVAILABLE", "Window focus service is unavailable")

func get_current() -> Dictionary:
	var window = _focused_window()
	if window == null:
		return {}
	return _window_summary(window)

func _call_current_window_manager(method_name: String, error_code: String) -> Dictionary:
	var window = _focused_window()
	if window == null:
		return _fail("WINDOW_UNAVAILABLE", "No current window is available")
	var id: int = _window_id(window)
	if _window_manager != null and id != 0 and _window_manager.has_method(method_name):
		_window_manager.call(method_name, id)
		return {"ok": true, "window": _window_summary(window)}
	return _fail(error_code, "Window manager method is unavailable: " + method_name)

func _focused_window():
	if _current_window != null and is_instance_valid(_current_window):
		return _current_window
	if _window_manager != null and _window_manager.has_method("get_focused_window"):
		var window = _window_manager.call("get_focused_window")
		if window != null:
			return window
	return null

func _window_id(window) -> int:
	if window == null:
		return 0
	if _window_manager != null and _window_manager.has_method("get_window_id"):
		return int(_window_manager.call("get_window_id", window))
	if window is Object:
		return int((window as Object).get_meta("window_id", 0))
	return 0

func _window_summary(window) -> Dictionary:
	if window == null:
		return {}
	return {
		"window_id": _window_id(window),
		"app_id": str(window.get("app_id")) if window is Object else "",
		"title": str(window.get("app_title")) if window is Object else "",
		"visible": bool(window.get("visible")) if window is Object else true,
		"maximized": bool(window.get("_maximized")) if window is Object else false
	}

func _fail(code: String, message: String) -> Dictionary:
	return {"ok": false, "error": {"code": code, "message": message, "details": {}}}
