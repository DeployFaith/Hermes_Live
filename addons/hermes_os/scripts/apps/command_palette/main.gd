extends "res://addons/hermes_os/scripts/ui/hermes_ui/runtime/hermes_app_controller.gd"

var _shell: Node = null
var _action_registry: RefCounted = null
var _all_actions: Array[Dictionary] = []

func configure_app_context(context: Dictionary) -> void:
	_shell = context.get("shell", null) as Node
	var registry_value: Variant = context.get("action_registry", null)
	if registry_value is RefCounted:
		_action_registry = registry_value as RefCounted
	if state != null:
		_reload_actions()

func _app_ready() -> void:
	if state == null:
		return
	state.set_many({
		"query": "",
		"filtered_actions": [],
		"active_action_id": "",
		"selected_label": "Selected: none",
		"results_label": "0 actions",
		"empty_label": "No actions match this query.",
		"has_results": false,
		"can_invoke": false,
		"status": "Ready"
	})
	_reload_actions()

func focus_primary() -> bool:
	if ui != null:
		return ui.focus("command-palette-search")
	return false

func refresh_actions(event = null) -> void:
	_reload_actions()

func handle_query_input(event = null) -> void:
	_apply_filter(false)

func select_action(event) -> void:
	if state == null:
		return
	var action_id: String = str(event.value).strip_edges()
	if action_id == "":
		return
	state.set("active_action_id", action_id)
	_update_selected_label(action_id)
	_update_derived_state()
	_invoke_action(action_id)

func invoke_selected(event = null) -> void:
	if state == null:
		return
	var action_id: String = state.get_string("active_action_id", "").strip_edges()
	if action_id == "":
		var filtered: Array = state.get_value("filtered_actions", [])
		if filtered.is_empty():
			state.set("status", "No action selected")
			_update_derived_state()
			return
		var first = filtered[0]
		if first is Dictionary:
			action_id = str((first as Dictionary).get("id", "")).strip_edges()
	if action_id == "":
		state.set("status", "No action selected")
		_update_derived_state()
		return
	state.set("active_action_id", action_id)
	_update_selected_label(action_id)
	_update_derived_state()
	_invoke_action(action_id)

func _reload_actions() -> void:
	_all_actions.clear()
	var loaded: Array = []
	if _action_registry != null and _action_registry.has_method("refresh"):
		_action_registry.call("refresh")
	if _action_registry != null and _action_registry.has_method("list_actions"):
		var value: Variant = _action_registry.call("list_actions", "")
		if value is Array:
			loaded = (value as Array).duplicate(true)
	elif _shell != null and _shell.has_method("list_command_actions"):
		var shell_value: Variant = _shell.call("list_command_actions", "")
		if shell_value is Array:
			loaded = (shell_value as Array).duplicate(true)
	for item in loaded:
		if not (item is Dictionary):
			continue
		_all_actions.append((item as Dictionary).duplicate(true))
	_apply_filter(true)

func _apply_filter(reset_selection: bool) -> void:
	if state == null:
		return
	var query: String = state.get_string("query", "").strip_edges().to_lower()
	var filtered: Array[Dictionary] = []
	for action in _all_actions:
		if not _matches_query(action, query):
			continue
		filtered.append(_to_view_action(action))
	var active_action_id: String = state.get_string("active_action_id", "")
	if reset_selection or active_action_id == "" or not _contains_action(filtered, active_action_id):
		active_action_id = str(filtered[0].get("id", "")) if not filtered.is_empty() else ""
	state.set_many({
		"filtered_actions": filtered,
		"active_action_id": active_action_id,
		"results_label": "%d action%s" % [filtered.size(), "" if filtered.size() == 1 else "s"],
		"has_results": not filtered.is_empty()
	})
	_update_selected_label(active_action_id)
	_update_derived_state()

func _invoke_action(action_id: String) -> void:
	if action_id == "":
		return
	var result: Dictionary = {}
	if _action_registry != null and _action_registry.has_method("invoke"):
		var value: Variant = _action_registry.call("invoke", action_id)
		if value is Dictionary:
			result = (value as Dictionary).duplicate(true)
	elif _shell != null and _shell.has_method("invoke_command_action"):
		var shell_value: Variant = _shell.call("invoke_command_action", action_id)
		if shell_value is Dictionary:
			result = (shell_value as Dictionary).duplicate(true)
	if result.is_empty():
		state.set("status", "Action failed: unavailable")
		return
	if bool(result.get("ok", false)):
		state.set("status", "Ran: " + action_id)
		_reload_actions()
		return
	var error_value: Variant = result.get("error", {})
	var error_message: String = "Action failed"
	if error_value is Dictionary:
		error_message = str((error_value as Dictionary).get("message", error_message))
	elif str(error_value).strip_edges() != "":
		error_message = str(error_value)
	state.set("status", error_message)

func _update_selected_label(action_id: String) -> void:
	if state == null:
		return
	var label: String = "Selected: none"
	if action_id != "":
		for action in _all_actions:
			if str(action.get("id", "")) == action_id:
				label = "Selected: " + str(action.get("label", action_id))
				break
	state.set("selected_label", label)

func _update_derived_state() -> void:
	if state == null:
		return
	var filtered: Array = state.get_value("filtered_actions", [])
	var active_action_id: String = state.get_string("active_action_id", "")
	state.set_many({
		"has_results": not filtered.is_empty(),
		"can_invoke": active_action_id != ""
	})

func _matches_query(action: Dictionary, query: String) -> bool:
	if query == "":
		return true
	var parts: Array[String] = [
		str(action.get("id", "")),
		str(action.get("label", "")),
		str(action.get("description", "")),
		str(action.get("category", "")),
		str(action.get("source", ""))
	]
	var keywords_value: Variant = action.get("keywords", [])
	if keywords_value is Array:
		for keyword in keywords_value:
			parts.append(str(keyword))
	var haystack: String = " ".join(parts).to_lower()
	return haystack.find(query) != -1

func _contains_action(actions: Array[Dictionary], action_id: String) -> bool:
	for action in actions:
		if str(action.get("id", "")) == action_id:
			return true
	return false

func _to_view_action(action: Dictionary) -> Dictionary:
	var label: String = str(action.get("label", action.get("id", ""))).strip_edges()
	var description: String = str(action.get("description", "")).strip_edges()
	var source: String = str(action.get("source", "")).strip_edges()
	var category: String = str(action.get("category", "")).strip_edges()
	var row_label: String = label
	if description != "":
		row_label += " — " + description
	if source != "" or category != "":
		var meta_parts: Array[String] = []
		if source != "":
			meta_parts.append(source)
		if category != "":
			meta_parts.append(category)
		row_label += " [" + " · ".join(meta_parts) + "]"
	return {
		"id": str(action.get("id", "")),
		"row_id": _row_id(str(action.get("id", ""))),
		"label": label,
		"row_label": row_label,
		"source": source,
		"category": category,
		"enabled": bool(action.get("enabled", true))
	}

func _row_id(value: String) -> String:
	var clean: String = value
	for bad in ["/", "\\", ":", " ", ".", "#", "[", "]", "{", "}", "(", ")"]:
		clean = clean.replace(str(bad), "-")
	while clean.find("--") != -1:
		clean = clean.replace("--", "-")
	return clean.strip_edges()
