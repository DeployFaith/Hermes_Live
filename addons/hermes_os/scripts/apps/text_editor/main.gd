extends "res://addons/hermes_os/scripts/ui/hermes_ui/runtime/hermes_app_controller.gd"

var ready_called: bool = false
var input_events: Array[String] = []
var last_event = null

func _app_ready() -> void:
	ready_called = true
	if state == null:
		return
	state.set_many({
		"current_path": "",
		"path_label": "No file opened",
		"content": "",
		"dirty": false,
		"dirty_label": "Clean",
		"dirty_variant": "success",
		"can_save": false,
		"status": "Open a text file from Files or Desktop."
	})
	state.watch("dirty", Callable(self, "_on_dirty_changed"))
	state.watch("current_path", Callable(self, "_on_path_changed"))

func focus_editor() -> bool:
	if ui != null:
		return ui.focus("text-editor-content")
	return false

func get_current_path() -> String:
	return state.get_string("current_path", "") if state != null else ""

func is_dirty() -> bool:
	return state.get_bool("dirty", false) if state != null else false

func get_editor_state() -> Dictionary:
	if state == null:
		return {"current_path": "", "dirty": false, "content": ""}
	return {
		"current_path": state.get_string("current_path", ""),
		"dirty": state.get_bool("dirty", false),
		"content": state.get_string("content", "")
	}

func restore_editor_state(saved_state: Dictionary) -> void:
	if state == null:
		return
	var path: String = str(saved_state.get("current_path", "")).strip_edges()
	if path != "" and _file_is_file(path):
		open_file(path)
		return
	var content_value: String = str(saved_state.get("content", ""))
	var dirty_value: bool = bool(saved_state.get("dirty", false))
	state.set_many({
		"current_path": path,
		"content": content_value,
		"dirty": dirty_value,
		"status": "Restored unsaved text." if dirty_value else "Restored text."
	})
	_update_derived_state()

func open_file(path: String) -> Dictionary:
	if state == null:
		return {"ok": false, "error": "State unavailable"}
	var target_path: String = _normalize_path(path)
	if target_path == "":
		_set_status("No file selected", true)
		return {"ok": false, "error": "No file selected"}
	if _has_file_bridge() and not _file_is_file(target_path):
		_set_status("File not found: " + target_path, true)
		return {"ok": false, "error": "File not found: " + target_path}
	var read_result: Dictionary = _read_file(target_path)
	if not bool(read_result.get("ok", false)):
		var error_text: String = _error_message(read_result, "Could not read file")
		_set_status(error_text, true)
		return {"ok": false, "error": error_text}
	state.set_many({
		"current_path": target_path,
		"content": str(read_result.get("content", "")),
		"dirty": false,
		"status": "Opened " + target_path.get_file()
	})
	_update_derived_state()
	return {"ok": true, "path": target_path}

func save_file(event = null) -> Dictionary:
	last_event = event
	if state == null:
		return {"ok": false, "error": "State unavailable"}
	var target_path: String = state.get_string("current_path", "")
	if target_path == "":
		_set_status("No file selected", true)
		return {"ok": false, "error": "No file selected"}
	var result: Dictionary = _write_file(target_path, state.get_string("content", ""))
	var ok: bool = bool(result.get("ok", false))
	if ok:
		state.set_many({"dirty": false, "status": "Saved"})
	else:
		_set_status(_error_message(result, "Could not save file"), true)
	_update_derived_state()
	return {"ok": ok, "error": "" if ok else _error_message(result, "Could not save file"), "path": target_path}

func handle_content_input(event) -> void:
	last_event = event
	input_events.append(str(event.value))
	if state == null:
		return
	state.set("dirty", true)
	_update_derived_state()

func _on_dirty_changed(_value) -> void:
	_update_derived_state()

func _on_path_changed(_value) -> void:
	_update_derived_state()

func _update_derived_state() -> void:
	if state == null:
		return
	var current_path: String = state.get_string("current_path", "")
	var dirty: bool = state.get_bool("dirty", false)
	state.set_many({
		"path_label": current_path if current_path != "" else "No file opened",
		"dirty_label": "Unsaved" if dirty else "Clean",
		"dirty_variant": "warning" if dirty else "success",
		"can_save": current_path != ""
	})

func _set_status(message: String, is_error: bool = false) -> void:
	if state != null:
		state.set_many({
			"status": message,
			"dirty_variant": "danger" if is_error else ("warning" if state.get_bool("dirty", false) else "success")
		})

func _has_file_bridge() -> bool:
	return os != null and os.files != null

func _normalize_path(path: String) -> String:
	if _has_file_bridge() and os.files.has_method("normalize"):
		return str(os.files.normalize(path))
	return path

func _file_is_file(path: String) -> bool:
	if _has_file_bridge() and os.files.has_method("is_file"):
		return bool(os.files.is_file(path))
	return true

func _read_file(path: String) -> Dictionary:
	if _has_file_bridge() and os.files.has_method("read"):
		var value = os.files.read(path)
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {"ok": false, "error": {"message": "Filesystem unavailable"}}

func _write_file(path: String, content: String) -> Dictionary:
	if _has_file_bridge() and os.files.has_method("write"):
		var value = os.files.write(path, content)
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {"ok": false, "error": {"message": "Filesystem unavailable"}}

func _error_message(result: Dictionary, fallback: String) -> String:
	var error_value = result.get("error", null)
	if error_value is Dictionary:
		var message: String = str((error_value as Dictionary).get("message", "")).strip_edges()
		if message != "":
			return message
	elif str(error_value).strip_edges() != "":
		return str(error_value)
	return fallback
