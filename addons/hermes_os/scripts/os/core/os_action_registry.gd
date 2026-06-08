class_name OSActionRegistry
extends RefCounted

var _shell: Node = null
var _app_registry: RefCounted = null
var _actions: Array[Dictionary] = []
var _by_id: Dictionary = {}

func setup(context: Dictionary) -> OSActionRegistry:
	_shell = context.get("shell", null) as Node
	_app_registry = context.get("app_registry", null) as RefCounted
	refresh()
	return self

func refresh() -> void:
	_actions.clear()
	_by_id.clear()
	_append_app_actions()
	_append_safe_os_actions()

func list_actions(query: String = "") -> Array[Dictionary]:
	var clean_query: String = query.strip_edges().to_lower()
	if clean_query == "":
		return _duplicate_actions(_actions)
	var filtered: Array[Dictionary] = []
	for action in _actions:
		if _matches_query(action, clean_query):
			filtered.append(action.duplicate(true))
	return filtered

func get_action(action_id: String) -> Dictionary:
	if _by_id.has(action_id):
		return (_by_id[action_id] as Dictionary).duplicate(true)
	return {}

func invoke(action_id: String) -> Dictionary:
	if not _by_id.has(action_id):
		return {"ok": false, "action_id": action_id, "error": {"code": "ACTION_NOT_FOUND", "message": "Unknown action: " + action_id, "details": {}}}
	var action: Dictionary = _by_id[action_id] as Dictionary
	if not bool(action.get("enabled", true)):
		return {"ok": false, "action_id": action_id, "error": {"code": "ACTION_DISABLED", "message": "Action is disabled", "details": {}}}
	var invoke: Dictionary = action.get("invoke", {}) if action.get("invoke", {}) is Dictionary else {}
	var invoke_type: String = str(invoke.get("type", "")).strip_edges()
	match invoke_type:
		"open_app":
			return _invoke_open_app(action, invoke)
		"lock_session":
			return _invoke_lock_session(action)
		_:
			return {"ok": false, "action_id": action_id, "error": {"code": "ACTION_UNSUPPORTED", "message": "Unsupported action invoke route: " + invoke_type, "details": {}}}

func _append_app_actions() -> void:
	for app in _installed_apps():
		if not (app is Dictionary):
			continue
		var app_data: Dictionary = app
		var app_id: String = str(app_data.get("id", "")).strip_edges()
		if app_id == "":
			continue
		var title: String = str(app_data.get("title", app_data.get("name", app_id))).strip_edges()
		if title == "":
			title = app_id
		var description: String = str(app_data.get("description", app_data.get("subtitle", "Open app"))).strip_edges()
		var category: String = str(app_data.get("category", "Apps")).strip_edges()
		var keywords: Array[String] = _keywords_from(app_id, title, str(app_data.get("keywords", "")), category, "open launch app")
		var action_id: String = "app.open.%s" % app_id
		_append_action({
			"id": action_id,
			"label": "Open " + title,
			"description": description,
			"category": category,
			"keywords": keywords,
			"source": "app_registry",
			"icon": app_data.get("icon", ""),
			"enabled": true,
			"invoke": {
				"type": "open_app",
				"route": "shell.launch_app",
				"app_id": app_id
			}
		})

func _append_safe_os_actions() -> void:
	var can_lock: bool = _shell != null and _shell.has_method("lock_session")
	_append_action({
		"id": "os.session.lock",
		"label": "Lock session",
		"description": "Lock the current HermesOS session",
		"category": "System",
		"keywords": ["lock", "session", "security", "auth"],
		"source": "os",
		"icon": "",
		"enabled": can_lock,
		"invoke": {
			"type": "lock_session",
			"route": "shell.lock_session"
		}
	})

func _invoke_open_app(action: Dictionary, invoke: Dictionary) -> Dictionary:
	if _shell == null or not _shell.has_method("launch_app"):
		return {"ok": false, "action_id": str(action.get("id", "")), "error": {"code": "SHELL_UNAVAILABLE", "message": "Shell app launcher is unavailable", "details": {}}}
	var app_id: String = str(invoke.get("app_id", "")).strip_edges()
	if app_id == "":
		return {"ok": false, "action_id": str(action.get("id", "")), "error": {"code": "MISSING_APP_ID", "message": "Action missing app_id", "details": {}}}
	var window: Variant = _shell.call("launch_app", app_id)
	if window == null:
		return {"ok": false, "action_id": str(action.get("id", "")), "error": {"code": "APP_OPEN_FAILED", "message": "Could not open app: " + app_id, "details": {}}}
	return {"ok": true, "action_id": str(action.get("id", "")), "result": {"opened": true, "app_id": app_id}}

func _invoke_lock_session(action: Dictionary) -> Dictionary:
	if _shell == null or not _shell.has_method("lock_session"):
		return {"ok": false, "action_id": str(action.get("id", "")), "error": {"code": "SHELL_UNAVAILABLE", "message": "Shell lock_session is unavailable", "details": {}}}
	_shell.call("lock_session")
	return {"ok": true, "action_id": str(action.get("id", "")), "result": {"locked": true}}

func _installed_apps() -> Array:
	if _app_registry != null and _app_registry.has_method("get_launcher_apps"):
		var value: Variant = _app_registry.call("get_launcher_apps")
		if value is Array:
			return (value as Array).duplicate(true)
	if _shell != null:
		var apps_value: Variant = _shell.get("_apps")
		if apps_value is Dictionary:
			var output: Array = []
			for key in (apps_value as Dictionary).keys():
				var app_value: Variant = (apps_value as Dictionary)[key]
				if app_value is Dictionary:
					output.append((app_value as Dictionary).duplicate(true))
			return output
	return []

func _matches_query(action: Dictionary, clean_query: String) -> bool:
	var haystack_parts: Array[String] = [
		str(action.get("id", "")),
		str(action.get("label", "")),
		str(action.get("description", "")),
		str(action.get("category", "")),
		str(action.get("source", ""))
	]
	var keywords_value: Variant = action.get("keywords", [])
	if keywords_value is Array:
		for keyword in keywords_value:
			haystack_parts.append(str(keyword))
	var haystack: String = " ".join(haystack_parts).to_lower()
	return haystack.find(clean_query) != -1

func _append_action(action: Dictionary) -> void:
	var action_id: String = str(action.get("id", "")).strip_edges()
	if action_id == "":
		return
	action["id"] = action_id
	if not (action.get("keywords", []) is Array):
		action["keywords"] = []
	_actions.append(action)
	_by_id[action_id] = action

func _duplicate_actions(actions: Array[Dictionary]) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for action in actions:
		output.append(action.duplicate(true))
	return output

func _keywords_from(app_id: String, title: String, keywords_text: String, category: String, extra: String) -> Array[String]:
	var result: Array[String] = []
	var combined: String = "%s %s %s %s %s" % [app_id, title, keywords_text, category, extra]
	for token in combined.to_lower().split(" ", false):
		var clean: String = token.strip_edges()
		if clean == "" or result.has(clean):
			continue
		result.append(clean)
	return result
