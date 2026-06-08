extends "res://addons/hermes_os/scripts/ui/hermes_ui/runtime/hermes_app_controller.gd"

var ready_called: bool = false
var last_event = null

func _app_ready() -> void:
	ready_called = true
	if state == null:
		return
	state.set_many({
		"notes": [],
		"active_note_id": "",
		"current_path": "",
		"path_label": "No note selected",
		"content": "",
		"dirty": false,
		"dirty_label": "Clean",
		"dirty_variant": "success",
		"can_save": false,
		"can_delete": false,
		"status": "Notes stored in " + _notes_directory_path()
	})
	state.watch("dirty", Callable(self, "_on_dirty_changed"))
	state.watch("current_path", Callable(self, "_on_path_changed"))
	state.watch("active_note_id", Callable(self, "_on_active_note_changed"))
	load_notes()
	_update_derived_state()

func focus_editor() -> bool:
	if ui != null:
		return ui.focus("notes-content")
	return false

func get_current_path() -> String:
	return state.get_string("current_path", "") if state != null else ""

func get_active_note_id() -> String:
	return state.get_string("active_note_id", "") if state != null else ""

func is_dirty() -> bool:
	return state.get_bool("dirty", false) if state != null else false

func get_notes_state() -> Dictionary:
	if state == null:
		return {"active_note_id": "", "open_notes": [], "current_path": "", "dirty": false, "content": ""}
	return {
		"active_note_id": state.get_string("active_note_id", ""),
		"open_notes": _open_note_ids(),
		"current_path": state.get_string("current_path", ""),
		"dirty": state.get_bool("dirty", false),
		"content": state.get_string("content", "")
	}

func restore_notes_state(saved_state: Dictionary) -> void:
	if state == null:
		return
	load_notes()
	var path: String = str(saved_state.get("current_path", "")).strip_edges()
	if path != "" and _file_is_file(path):
		open_file(path)
		return
	var note_id: String = str(saved_state.get("active_note_id", "")).strip_edges()
	if note_id != "" and _file_is_file(_note_path_from_id(note_id)):
		open_note(note_id)
		return
	state.set_many({
		"active_note_id": note_id,
		"current_path": path,
		"content": str(saved_state.get("content", "")),
		"dirty": bool(saved_state.get("dirty", false)),
		"status": "Restored unsaved note." if bool(saved_state.get("dirty", false)) else "Restored notes."
	})
	_update_derived_state()

func load_notes() -> Array:
	_ensure_notes_directory()
	var items: Array = []
	if _has_file_bridge():
		for entry in os.files.list_dir(_notes_directory_path()):
			if not (entry is Dictionary):
				continue
			var data: Dictionary = entry
			if str(data.get("type", "file")) != "file":
				continue
			var note_id: String = str(data.get("name", data.get("path", ""))).strip_edges()
			if note_id == "":
				continue
			if not note_id.ends_with(".txt"):
				continue
			var path: String = str(data.get("path", _note_path_from_id(note_id)))
			items.append({
				"id": note_id,
				"title": note_id,
				"path": path,
				"subtitle": _size_label(int(data.get("size", 0)))
			})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("title", "")) < str(b.get("title", "")))
	if state != null:
		state.set("notes", items)
	return items

func select_note(event) -> Dictionary:
	last_event = event
	return open_note(str(event.value))

func open_note(note_id_or_path: String) -> Dictionary:
	return open_file(_note_path_from_id(note_id_or_path))

func open_file(path: String) -> Dictionary:
	if state == null:
		return {"ok": false, "error": "State unavailable"}
	var target_path: String = _normalize_path(path)
	if target_path == "":
		_set_status("No note selected", true)
		return {"ok": false, "error": "No note selected"}
	if _has_file_bridge() and not _file_is_file(target_path):
		_set_status("Note not found: " + target_path, true)
		return {"ok": false, "error": "Note not found: " + target_path}
	var read_result: Dictionary = _read_file(target_path)
	if not bool(read_result.get("ok", false)):
		var error_text: String = _error_message(read_result, "Could not read note")
		_set_status(error_text, true)
		return {"ok": false, "error": error_text}
	var note_id: String = target_path.get_file()
	state.set_many({
		"active_note_id": note_id,
		"current_path": target_path,
		"content": str(read_result.get("content", "")),
		"dirty": false,
		"status": "Opened " + note_id
	})
	load_notes()
	_update_derived_state()
	return {"ok": true, "path": target_path, "note_id": note_id}

func new_note(event = null) -> Dictionary:
	last_event = event
	return create_note("Untitled", "")

func create_note(title: String = "Untitled", content: String = "") -> Dictionary:
	if state == null:
		return {"ok": false, "error": "State unavailable"}
	var ensure_result: Dictionary = _ensure_notes_directory()
	if not bool(ensure_result.get("ok", false)):
		var ensure_error: String = _error_message(ensure_result, "Could not create notes folder")
		_set_status(ensure_error, true)
		return {"ok": false, "error": ensure_error}
	var target_path: String = _create_unique_note_path(title)
	var write_result: Dictionary = _write_file(target_path, content)
	if not bool(write_result.get("ok", false)):
		var write_error: String = _error_message(write_result, "Could not create note")
		_set_status(write_error, true)
		return {"ok": false, "error": write_error}
	load_notes()
	var opened: Dictionary = open_file(target_path)
	if bool(opened.get("ok", false)):
		state.set_many({"content": content, "dirty": false, "status": "Created " + target_path.get_file()})
		_update_derived_state()
	return {"ok": bool(opened.get("ok", false)), "path": target_path, "note_id": target_path.get_file(), "error": opened.get("error", "")}

func save_note(event = null) -> Dictionary:
	last_event = event
	if state == null:
		return {"ok": false, "error": "State unavailable"}
	var target_path: String = state.get_string("current_path", "")
	if target_path == "":
		_set_status("No note selected", true)
		return {"ok": false, "error": "No note selected"}
	var result: Dictionary = _write_file(target_path, state.get_string("content", ""))
	var ok: bool = bool(result.get("ok", false))
	if ok:
		state.set_many({"dirty": false, "status": "Saved " + target_path.get_file()})
		load_notes()
	else:
		_set_status(_error_message(result, "Could not save note"), true)
	_update_derived_state()
	return {"ok": ok, "error": "" if ok else _error_message(result, "Could not save note"), "path": target_path, "note_id": target_path.get_file()}

func save_file() -> Dictionary:
	return save_note(null)

func delete_note(event = null) -> Dictionary:
	last_event = event
	if state == null:
		return {"ok": false, "error": "State unavailable"}
	var target_path: String = state.get_string("current_path", "")
	if target_path == "":
		_set_status("No note selected", true)
		return {"ok": false, "error": "No note selected"}
	var result: Dictionary = _delete_path(target_path)
	var ok: bool = bool(result.get("ok", false))
	if not ok:
		_set_status(_error_message(result, "Could not delete note"), true)
		return {"ok": false, "error": _error_message(result, "Could not delete note"), "path": target_path}
	state.set_many({
		"active_note_id": "",
		"current_path": "",
		"content": "",
		"dirty": false,
		"status": "Deleted " + target_path.get_file()
	})
	var items: Array = load_notes()
	if not items.is_empty():
		var first: Dictionary = items[0]
		open_note(str(first.get("id", "")))
	_update_derived_state()
	return {"ok": true, "path": target_path, "note_id": target_path.get_file()}

func set_note_content(content: String, dirty: bool = false) -> void:
	if state == null:
		return
	state.set_many({"content": content, "dirty": dirty})
	_update_derived_state()

func handle_content_input(event) -> void:
	last_event = event
	if state == null:
		return
	state.set("dirty", true)
	_update_derived_state()

func _on_dirty_changed(_value) -> void:
	_update_derived_state()

func _on_path_changed(_value) -> void:
	_update_derived_state()

func _on_active_note_changed(_value) -> void:
	_update_derived_state()

func _update_derived_state() -> void:
	if state == null:
		return
	var current_path: String = state.get_string("current_path", "")
	var dirty: bool = state.get_bool("dirty", false)
	var active_note_id: String = state.get_string("active_note_id", "")
	state.set_many({
		"path_label": current_path if current_path != "" else "No note selected",
		"dirty_label": "Unsaved" if dirty else "Clean",
		"dirty_variant": "warning" if dirty else "success",
		"can_save": current_path != "",
		"can_delete": active_note_id != "" and current_path != ""
	})

func _open_note_ids() -> Array:
	var ids: Array = []
	if state == null:
		return ids
	for item in state.get_value("notes", []):
		if item is Dictionary:
			ids.append(str((item as Dictionary).get("id", "")))
	return ids

func _ensure_notes_directory() -> Dictionary:
	if not _has_file_bridge():
		return {"ok": false, "error": {"message": "Filesystem unavailable"}}
	var path: String = _notes_directory_path()
	if os.files.has_method("is_dir") and os.files.is_dir(path):
		return {"ok": true, "path": path}
	if os.files.has_method("make_dir"):
		return os.files.make_dir(path)
	return {"ok": false, "error": {"message": "Filesystem mkdir unavailable"}}

func _notes_directory_path() -> String:
	if _has_file_bridge():
		return os.files.join_path(os.files.home_path(), "notes")
	return "/notes"

func _note_path_from_id(note_id_or_path: String) -> String:
	var clean: String = note_id_or_path.strip_edges()
	if clean == "":
		clean = "untitled"
	if clean.begins_with("/") or clean.begins_with("~/"):
		return _normalize_path(clean)
	if not clean.ends_with(".txt"):
		clean += ".txt"
	if _has_file_bridge():
		return os.files.join_path(_notes_directory_path(), clean)
	return _notes_directory_path().rstrip("/") + "/" + clean

func _create_unique_note_path(title: String) -> String:
	var slug: String = _slug(title)
	if slug == "":
		slug = "untitled"
	var candidate: String = _note_path_from_id(slug)
	var suffix: int = 2
	while _path_exists(candidate):
		candidate = _note_path_from_id("%s-%d" % [slug, suffix])
		suffix += 1
	return candidate

func _slug(title: String) -> String:
	var clean: String = title.strip_edges().to_lower()
	if clean == "":
		clean = "untitled"
	for bad in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		clean = clean.replace(str(bad), "-")
	while clean.find("  ") != -1:
		clean = clean.replace("  ", " ")
	clean = clean.replace(" ", "-")
	while clean.find("--") != -1:
		clean = clean.replace("--", "-")
	return clean.strip_edges()

func _size_label(size: int) -> String:
	if size <= 0:
		return "Empty"
	return "%d bytes" % size

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

func _path_exists(path: String) -> bool:
	if _has_file_bridge() and os.files.has_method("exists"):
		return bool(os.files.exists(path))
	return _file_is_file(path)

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

func _delete_path(path: String) -> Dictionary:
	if _has_file_bridge() and os.files.has_method("delete"):
		var value = os.files.delete(path)
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {"ok": false, "error": {"message": "Filesystem delete unavailable"}}

func _error_message(result: Dictionary, fallback: String) -> String:
	var error_value = result.get("error", null)
	if error_value is Dictionary:
		var message: String = str((error_value as Dictionary).get("message", "")).strip_edges()
		if message != "":
			return message
	elif str(error_value).strip_edges() != "":
		return str(error_value)
	return fallback
