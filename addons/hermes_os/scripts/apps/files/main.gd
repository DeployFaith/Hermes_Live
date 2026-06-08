extends "res://addons/hermes_os/scripts/ui/hermes_ui/runtime/hermes_app_controller.gd"

const DEBUG_FILES_TIMING := false
const CONTEXT_MENU_WIDTH := 220.0
const CONTEXT_MENU_MARGIN := 8.0

var ready_called: bool = false
var last_event = null

var _context_menu: Panel = null
var _context_menu_column: VBoxContainer = null
var _context_menu_mode: String = "files"
var _context_shortcut_path: String = ""
var _context_shortcut_label: String = ""
var _trash_confirm_overlay: Control = null
var _trash_confirm_dialog: Panel = null
var _shell: Node = null
var _os_event_bus = null
var _open_file_callback: Callable = Callable()
var _shortcuts_changed_callback: Callable = Callable()
var _state_save_callback: Callable = Callable()

func configure_app_context(context: Dictionary) -> void:
	_shell = context.get("shell", null) as Node
	_os_event_bus = context.get("event_bus", null)
	_subscribe_file_system_events()
	var open_value: Variant = context.get("open_file_callback", Callable())
	if open_value is Callable:
		_open_file_callback = open_value as Callable
	var shortcuts_value: Variant = context.get("shortcuts_changed_callback", Callable())
	if shortcuts_value is Callable:
		_shortcuts_changed_callback = shortcuts_value as Callable
	var save_value: Variant = context.get("state_save_callback", Callable())
	if save_value is Callable:
		_state_save_callback = save_value as Callable
	if state != null and context.has("shortcuts"):
		state.set("shortcuts", _sanitize_shortcuts(context.get("shortcuts", []), _home_path()))

func _app_ready() -> void:
	ready_called = true
	if state == null:
		return
	_ensure_trash_dirs()
	var home: String = _home_path()
	var seeded_shortcuts: Array = _default_shortcuts(home)
	var configured_shortcuts: Array = _sanitize_shortcuts(state.get_value("shortcuts", seeded_shortcuts), home)
	state.set_many({
		"current_path": home,
		"path_input": home,
		"breadcrumb": _breadcrumb(home),
		"entries": [],
		"has_entries": false,
		"selected_path": "",
		"selected_type": "",
		"selected_name": "",
		"selected_label": "Selected: none",
		"details_label": "",
		"create_name": "",
		"rename_name": "",
		"clipboard_path": "",
		"clipboard_mode": "",
		"clipboard_label": "clip: empty",
		"history": [home],
		"history_index": 0,
		"shortcuts": configured_shortcuts,
		"shortcut_selected_path": "",
		"show_shortcut_editor": false,
		"shortcut_editor_mode": "add",
		"shortcut_editor_title": "Add shortcut",
		"shortcut_editor_index": -1,
		"shortcut_edit_label": "",
		"shortcut_edit_path": home,
		"show_trash_confirm": false,
		"status": ""
	})
	_refresh(false, false)
	_update_derived_state()
	_build_context_menu()
	_build_trash_confirm_dialog()
	_connect_context_menu_input()

func app_unmounted() -> void:
	_unsubscribe_file_system_events()
	_hide_context_menu()
	_hide_trash_confirm_dialog()
	if _context_menu != null and is_instance_valid(_context_menu):
		_context_menu.queue_free()
	if _trash_confirm_overlay != null and is_instance_valid(_trash_confirm_overlay):
		_trash_confirm_overlay.queue_free()
	_context_menu = null
	_context_menu_column = null
	_trash_confirm_overlay = null
	_trash_confirm_dialog = null
	super.app_unmounted()

func _subscribe_file_system_events() -> void:
	if _os_event_bus == null or not _os_event_bus.has_method("subscribe"):
		return
	for event_name in [&"file.created", &"file.updated", &"file.deleted", &"file.moved", &"file.copied"]:
		_os_event_bus.subscribe(event_name, self, &"_on_file_system_event")

func _unsubscribe_file_system_events() -> void:
	if _os_event_bus == null or not _os_event_bus.has_method("unsubscribe"):
		_os_event_bus = null
		return
	for event_name in [&"file.created", &"file.updated", &"file.deleted", &"file.moved", &"file.copied"]:
		_os_event_bus.unsubscribe(event_name, self, &"_on_file_system_event")
	_os_event_bus = null

func _on_file_system_event(_event_name: StringName, payload: Dictionary) -> void:
	if state == null:
		return
	var current_path: String = _normalize_path(state.get_string("current_path", _home_path()))
	if _file_event_affects_directory(payload, current_path):
		_refresh(false, false)

func _file_event_affects_directory(payload: Dictionary, directory_path: String) -> bool:
	var dir_path: String = _normalize_path(directory_path)
	var affected_dirs: Array[String] = []
	for key in ["parent", "destination_parent"]:
		var value: String = str(payload.get(key, "")).strip_edges()
		if value != "":
			affected_dirs.append(_normalize_path(value))
	for key in ["path", "source", "destination", "trash_info_path"]:
		var path_value: String = str(payload.get(key, "")).strip_edges()
		if path_value != "":
			affected_dirs.append(_dirname(_normalize_path(path_value)))
	for affected in affected_dirs:
		if affected == dir_path:
			return true
	return false

func refresh_files() -> void:
	_refresh(true, false)

func get_files_state() -> Dictionary:
	if state == null:
		return {}
	return {
		"current_path": state.get_string("current_path", ""),
		"selected_path": state.get_string("selected_path", ""),
		"selected_type": state.get_string("selected_type", ""),
		"clipboard_path": state.get_string("clipboard_path", ""),
		"clipboard_mode": state.get_string("clipboard_mode", ""),
		"history": (state.get_value("history", []) as Array).duplicate(true),
		"history_index": int(state.get_value("history_index", 0)),
		"shortcuts": (state.get_value("shortcuts", []) as Array).duplicate(true),
		"shortcut_selected_path": state.get_string("shortcut_selected_path", ""),
		"create_name": state.get_string("create_name", ""),
		"rename_name": state.get_string("rename_name", ""),
		"path_input": state.get_string("path_input", "")
	}

func restore_files_state(saved_state: Dictionary) -> void:
	if state == null:
		return
	var home: String = _home_path()
	var shortcuts: Array = _sanitize_shortcuts(saved_state.get("shortcuts", state.get_value("shortcuts", [])), home)
	var current_path: String = _normalize_path(str(saved_state.get("current_path", home)))
	if not _is_dir(current_path):
		current_path = home
	var history_value: Variant = saved_state.get("history", [current_path])
	var history: Array = history_value if history_value is Array else [current_path]
	if history.is_empty():
		history = [current_path]
	var history_index: int = clampi(int(saved_state.get("history_index", history.size() - 1)), 0, history.size() - 1)
	state.set_many({
		"current_path": current_path,
		"path_input": current_path,
		"history": history,
		"history_index": history_index,
		"shortcuts": shortcuts,
		"shortcut_selected_path": str(saved_state.get("shortcut_selected_path", "")),
		"clipboard_path": str(saved_state.get("clipboard_path", "")),
		"clipboard_mode": str(saved_state.get("clipboard_mode", "")),
		"create_name": str(saved_state.get("create_name", "")),
		"rename_name": str(saved_state.get("rename_name", ""))
	})
	_refresh(false, false)
	var selected_path: String = _normalize_path(str(saved_state.get("selected_path", "")))
	if selected_path != "":
		select_path(selected_path)
	_update_derived_state()

func open_path(path: String) -> void:
	if state == null:
		return
	var target: String = _normalize_path(path)
	if _is_file(target):
		var parent_value: String = _dirname(target)
		state.set("path_input", parent_value)
		_refresh(false, true)
		select_path(target)
		return
	state.set("path_input", target)
	_refresh(false, true)

func select_path(path: String) -> bool:
	if state == null:
		return false
	var target: String = _normalize_path(path)
	var entries: Array = state.get_value("entries", [])
	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		if str(entry.get("path", "")) == target:
			_apply_selection(entry)
			return true
	return false

func get_current_path() -> String:
	return state.get_string("current_path", "") if state != null else ""

func get_selected_path() -> String:
	return state.get_string("selected_path", "") if state != null else ""

func get_visible_entries() -> Array:
	if state == null:
		return []
	return (state.get_value("entries", []) as Array).duplicate(true)

func open_selected(event = null) -> void:
	var timing_start: int = Time.get_ticks_usec()
	last_event = event
	if state == null:
		return
	var selected_path: String = state.get_string("selected_path", "")
	if selected_path == "":
		_set_status("Select an item first", true)
		return
	_open_entry_path(selected_path)
	_trace_timing("open_selected", timing_start)

func open_entry(event) -> void:
	var timing_start: int = Time.get_ticks_usec()
	last_event = event
	if state == null:
		return
	var target_path: String = _normalize_path(str(event.value))
	if target_path == "":
		return
	var entry: Dictionary = _entry_for_path(target_path)
	if not entry.is_empty():
		_apply_selection(entry)
	_open_entry_path(target_path)
	_trace_timing("open_entry", timing_start)

func handle_path_input(_event = null) -> void:
	_update_derived_state()

func go_path(event = null) -> void:
	last_event = event
	_refresh(true, true)

func refresh_current(event = null) -> void:
	last_event = event
	_refresh(true, false)

func open_in_terminal(event = null) -> void:
	last_event = event
	if _shell == null or not _shell.has_method("launch_app_with_context"):
		if _shell != null and _shell.has_method("launch_app"):
			_shell.call("launch_app", "console")
			_set_status("Opened Terminal", false)
		else:
			_set_status("Terminal unavailable", true)
		return
	var cwd: String = state.get_string("current_path", "") if state != null else ""
	if cwd == "":
		cwd = _home_path()
	_shell.call("launch_app_with_context", "console", {"initial_cwd": cwd})
	_set_status("Opened Terminal in " + cwd, false)
	_hide_context_menu()

func navigate_back(event = null) -> void:
	last_event = event
	_navigate_history(-1)

func navigate_forward(event = null) -> void:
	last_event = event
	_navigate_history(1)

func navigate_up(event = null) -> void:
	last_event = event
	if state == null:
		return
	state.set("path_input", _dirname(state.get_string("current_path", _home_path())))
	_refresh(true, true)

func go_home(event = null) -> void:
	last_event = event
	if state == null:
		return
	state.set("path_input", _home_path())
	_refresh(true, true)

func select_entry(event) -> void:
	var timing_start: int = Time.get_ticks_usec()
	last_event = event
	if state == null:
		return
	var selected_path: String = _normalize_path(str(event.value))
	var entry: Dictionary = _entry_for_path(selected_path)
	if not entry.is_empty():
		_apply_selection(entry)
		_trace_timing("select_entry", timing_start)

func create_folder(event = null) -> void:
	last_event = event
	if state == null:
		return
	var name: String = state.get_string("create_name", "").strip_edges()
	if name == "":
		_set_status("Enter a folder name", true)
		return
	var target: String = _join_path(state.get_string("current_path", _home_path()), name)
	var result: Dictionary = _make_dir(target)
	if bool(result.get("ok", false)):
		state.set("create_name", "")
		_set_status("Folder created", false)
		_refresh(false, false)
	else:
		_set_status(_error_message(result, "Could not create folder"), true)
	_update_derived_state()

func create_file(event = null) -> void:
	last_event = event
	if state == null:
		return
	var name: String = state.get_string("create_name", "").strip_edges()
	if name == "":
		_set_status("Enter a file name", true)
		return
	var target: String = _join_path(state.get_string("current_path", _home_path()), name)
	var result: Dictionary = _write_file(target, "")
	if bool(result.get("ok", false)):
		state.set("create_name", "")
		_set_status("File created", false)
		_refresh(false, false)
	else:
		_set_status(_error_message(result, "Could not create file"), true)
	_update_derived_state()

func rename_selected(event = null) -> void:
	last_event = event
	if state == null:
		return
	var selected_path: String = state.get_string("selected_path", "")
	if selected_path == "":
		_set_status("Select an item first", true)
		return
	var target_name: String = state.get_string("rename_name", "").strip_edges()
	if target_name == "":
		_set_status("Enter a new name", true)
		return
	var result: Dictionary = _rename_path(selected_path, target_name)
	if bool(result.get("ok", false)):
		state.set("rename_name", "")
		state.set("selected_path", "")
		state.set("selected_type", "")
		_set_status("Renamed", false)
		_refresh(false, false)
	else:
		_set_status(_error_message(result, "Could not rename item"), true)
	_update_derived_state()

func delete_selected(event = null) -> void:
	last_event = event
	if state == null:
		return
	var selected_path: String = state.get_string("selected_path", "")
	if selected_path == "":
		_set_status("Select an item first", true)
		return
	var result: Dictionary = _move_to_trash(selected_path)
	if bool(result.get("ok", false)):
		state.set("selected_path", "")
		state.set("selected_type", "")
		_set_status("Moved to Trash", false)
		_refresh(false, false)
	else:
		_set_status(_error_message(result, "Could not move item to Trash"), true)
	_update_derived_state()

func copy_selected(event = null) -> void:
	last_event = event
	if state == null:
		return
	var selected_path: String = state.get_string("selected_path", "")
	if selected_path == "":
		_set_status("Select an item first", true)
		return
	state.set_many({"clipboard_path": selected_path, "clipboard_mode": "copy"})
	_set_status("Copied to clipboard: " + selected_path, false)
	_update_derived_state()

func cut_selected(event = null) -> void:
	last_event = event
	if state == null:
		return
	var selected_path: String = state.get_string("selected_path", "")
	if selected_path == "":
		_set_status("Select an item first", true)
		return
	state.set_many({"clipboard_path": selected_path, "clipboard_mode": "move"})
	_set_status("Cut to clipboard: " + selected_path, false)
	_update_derived_state()

func paste_clipboard(event = null) -> void:
	last_event = event
	if state == null:
		return
	var clipboard_path: String = state.get_string("clipboard_path", "")
	var clipboard_mode: String = state.get_string("clipboard_mode", "")
	if clipboard_path == "" or clipboard_mode == "":
		_set_status("Clipboard is empty", true)
		return
	var destination: String = _paste_destination_path(clipboard_path, state.get_string("current_path", _home_path()))
	var result: Dictionary = _move_path(clipboard_path, destination) if clipboard_mode == "move" else _copy_path(clipboard_path, destination)
	if bool(result.get("ok", false)):
		if clipboard_mode == "move":
			state.set_many({"clipboard_path": "", "clipboard_mode": ""})
		_set_status(("Moved to " if clipboard_mode == "move" else "Copied to ") + destination, false)
		_refresh(false, false)
	else:
		_set_status(_error_message(result, "Paste failed"), true)
	_update_derived_state()

func handle_create_name_input(_event = null) -> void:
	_update_derived_state()

func handle_rename_name_input(_event = null) -> void:
	_update_derived_state()

func select_shortcut(event) -> void:
	last_event = event
	if state == null:
		return
	var shortcut_path: String = _normalize_path(str(event.value))
	state.set("shortcut_selected_path", shortcut_path)
	state.set("path_input", shortcut_path)
	_refresh(true, true)

func open_add_shortcut(event = null) -> void:
	last_event = event
	if state == null:
		return
	state.set_many({
		"show_shortcut_editor": true,
		"shortcut_editor_mode": "add",
		"shortcut_editor_title": "Add shortcut",
		"shortcut_editor_index": -1,
		"shortcut_edit_label": "",
		"shortcut_edit_path": state.get_string("current_path", _home_path())
	})
	_update_derived_state()

func open_edit_shortcut(event = null) -> void:
	last_event = event
	if state == null:
		return
	var selected_path: String = state.get_string("shortcut_selected_path", "")
	if selected_path == "":
		_set_status("Select a shortcut first", true)
		return
	var shortcuts: Array = state.get_value("shortcuts", [])
	for index in range(shortcuts.size()):
		var shortcut_value: Variant = shortcuts[index]
		if not (shortcut_value is Dictionary):
			continue
		var shortcut: Dictionary = shortcut_value
		if _normalize_path(str(shortcut.get("path", ""))) != selected_path:
			continue
		state.set_many({
			"show_shortcut_editor": true,
			"shortcut_editor_mode": "edit",
			"shortcut_editor_title": "Edit shortcut",
			"shortcut_editor_index": index,
			"shortcut_edit_label": str(shortcut.get("label", "")),
			"shortcut_edit_path": str(shortcut.get("path", ""))
		})
		_update_derived_state()
		return
	_set_status("Select a shortcut first", true)

func handle_shortcut_input(_event = null) -> void:
	_update_derived_state()

func save_shortcut_editor(event = null) -> void:
	last_event = event
	if state == null:
		return
	var label_value: String = state.get_string("shortcut_edit_label", "").strip_edges()
	var path_value: String = state.get_string("shortcut_edit_path", "").strip_edges()
	if label_value == "" or path_value == "":
		_set_status("Shortcut name and path are required", true)
		_update_derived_state()
		return
	var shortcuts: Array = _sanitize_shortcuts(state.get_value("shortcuts", []), _home_path())
	var clean_path: String = _normalize_path(path_value)
	var mode: String = state.get_string("shortcut_editor_mode", "add")
	if mode == "edit":
		var index: int = int(state.get_value("shortcut_editor_index", -1))
		if index < 0 or index >= shortcuts.size():
			_set_status("Select a shortcut first", true)
			return
		shortcuts[index] = {"label": label_value, "path": clean_path}
		_set_status("Shortcut updated", false)
	else:
		shortcuts.append({"label": label_value, "path": clean_path})
		_set_status("Shortcut added", false)
	state.set_many({
		"shortcuts": shortcuts,
		"shortcut_selected_path": clean_path,
		"show_shortcut_editor": false,
		"shortcut_editor_mode": "add",
		"shortcut_editor_title": "Add shortcut",
		"shortcut_editor_index": -1,
		"shortcut_edit_label": "",
		"shortcut_edit_path": state.get_string("current_path", _home_path())
	})
	_emit_shortcuts_changed()
	_queue_state_save()
	_update_derived_state()

func cancel_shortcut_editor(event = null) -> void:
	last_event = event
	if state == null:
		return
	state.set_many({
		"show_shortcut_editor": false,
		"shortcut_editor_mode": "add",
		"shortcut_editor_title": "Add shortcut",
		"shortcut_editor_index": -1,
		"shortcut_edit_label": "",
		"shortcut_edit_path": state.get_string("current_path", _home_path())
	})
	_update_derived_state()

func delete_shortcut(event = null) -> void:
	last_event = event
	if state == null:
		return
	var selected_path: String = state.get_string("shortcut_selected_path", "")
	if selected_path == "":
		_set_status("Select a shortcut first", true)
		return
	var shortcuts: Array = _sanitize_shortcuts(state.get_value("shortcuts", []), _home_path())
	for index in range(shortcuts.size() - 1, -1, -1):
		var shortcut_value: Variant = shortcuts[index]
		if not (shortcut_value is Dictionary):
			continue
		var shortcut: Dictionary = shortcut_value
		if _normalize_path(str(shortcut.get("path", ""))) != selected_path:
			continue
		shortcuts.remove_at(index)
		break
	state.set_many({
		"shortcuts": shortcuts,
		"shortcut_selected_path": ""
	})
	_set_status("Shortcut deleted", false)
	_emit_shortcuts_changed()
	_queue_state_save()
	_update_derived_state()

func move_shortcut_up(event = null) -> void:
	last_event = event
	_move_shortcut(-1)

func move_shortcut_down(event = null) -> void:
	last_event = event
	_move_shortcut(1)

func _move_shortcut(direction: int) -> void:
	if state == null:
		return
	var selected_path: String = state.get_string("shortcut_selected_path", "")
	if selected_path == "":
		_set_status("Select a shortcut first", true)
		return
	var shortcuts: Array = _sanitize_shortcuts(state.get_value("shortcuts", []), _home_path())
	var index: int = -1
	for i in range(shortcuts.size()):
		var shortcut_value: Variant = shortcuts[i]
		if not (shortcut_value is Dictionary):
			continue
		if _normalize_path(str((shortcut_value as Dictionary).get("path", ""))) == selected_path:
			index = i
			break
	if index < 0:
		_set_status("Select a shortcut first", true)
		return
	var target_index: int = index + direction
	if target_index < 0 or target_index >= shortcuts.size():
		return
	var moving: Variant = shortcuts[index]
	shortcuts.remove_at(index)
	shortcuts.insert(target_index, moving)
	state.set("shortcuts", shortcuts)
	_set_status("Shortcut order updated", false)
	_emit_shortcuts_changed()
	_queue_state_save()
	_update_derived_state()

func _build_context_menu() -> void:
	if root_control == null or not is_instance_valid(root_control):
		return
	if _context_menu != null and is_instance_valid(_context_menu):
		return
	_context_menu = Panel.new()
	_context_menu.name = "FilesContextMenu"
	_context_menu.visible = false
	_context_menu.size = Vector2(CONTEXT_MENU_WIDTH, 220)
	_context_menu.clip_contents = true
	_context_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_context_menu.z_index = 4096
	_context_menu.add_theme_stylebox_override("panel", StyleFactory.context_menu(12))
	root_control.add_child(_context_menu)

	_context_menu_column = VBoxContainer.new()
	_context_menu_column.set_anchors_preset(Control.PRESET_FULL_RECT)
	_context_menu_column.offset_left = 10
	_context_menu_column.offset_right = -10
	_context_menu_column.offset_top = 10
	_context_menu_column.offset_bottom = -10
	_context_menu_column.add_theme_constant_override("separation", 5)
	_context_menu.add_child(_context_menu_column)

func _build_trash_confirm_dialog() -> void:
	if root_control == null or not is_instance_valid(root_control):
		return
	if _trash_confirm_overlay != null and is_instance_valid(_trash_confirm_overlay):
		return
	_trash_confirm_overlay = Control.new()
	_trash_confirm_overlay.name = "FilesTrashConfirmOverlay"
	_trash_confirm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_trash_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_trash_confirm_overlay.z_index = 8192
	_trash_confirm_overlay.visible = false
	root_control.add_child(_trash_confirm_overlay)

	var dim := ColorRect.new()
	dim.name = "FilesTrashConfirmDim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_trash_confirm_overlay.add_child(dim)

	_trash_confirm_dialog = Panel.new()
	_trash_confirm_dialog.name = "FilesTrashConfirmDialog"
	_trash_confirm_dialog.size = Vector2(400, 156)
	_trash_confirm_dialog.custom_minimum_size = Vector2(400, 156)
	_trash_confirm_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_trash_confirm_dialog.z_index = 8193
	_trash_confirm_dialog.add_theme_stylebox_override("panel", StyleFactory.elevated_panel(2, 0.98, 14))
	_trash_confirm_overlay.add_child(_trash_confirm_dialog)

	var body := VBoxContainer.new()
	body.name = "FilesTrashConfirmBody"
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 20
	body.offset_right = -20
	body.offset_top = 18
	body.offset_bottom = -18
	body.add_theme_constant_override("separation", 12)
	_trash_confirm_dialog.add_child(body)

	var title := Label.new()
	title.name = "FilesTrashConfirmTitle"
	title.text = "Empty Trash?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	body.add_child(title)

	var warning := Label.new()
	warning.name = "FilesTrashConfirmText"
	warning.text = "Are you sure? This cannot be undone."
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(warning)

	var actions := HBoxContainer.new()
	actions.name = "FilesTrashConfirmActions"
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	body.add_child(actions)

	var confirm_button := Button.new()
	confirm_button.name = "FilesTrashConfirmYes"
	confirm_button.text = "Empty Trash"
	confirm_button.custom_minimum_size = Vector2(126, 34)
	confirm_button.pressed.connect(Callable(self, "confirm_empty_trash"))
	actions.add_child(confirm_button)

	var cancel_button := Button.new()
	cancel_button.name = "FilesTrashConfirmNo"
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(96, 34)
	cancel_button.pressed.connect(Callable(self, "cancel_empty_trash"))
	actions.add_child(cancel_button)

	if not root_control.resized.is_connected(Callable(self, "_center_trash_confirm_dialog")):
		root_control.resized.connect(Callable(self, "_center_trash_confirm_dialog"))
	_center_trash_confirm_dialog()

func _show_trash_confirm_dialog() -> void:
	if _trash_confirm_overlay == null or not is_instance_valid(_trash_confirm_overlay):
		_build_trash_confirm_dialog()
	if _trash_confirm_overlay == null or not is_instance_valid(_trash_confirm_overlay):
		return
	_center_trash_confirm_dialog()
	_trash_confirm_overlay.visible = true
	_trash_confirm_overlay.move_to_front()
	if _trash_confirm_dialog != null and is_instance_valid(_trash_confirm_dialog):
		_trash_confirm_dialog.move_to_front()

func _hide_trash_confirm_dialog() -> void:
	if _trash_confirm_overlay != null and is_instance_valid(_trash_confirm_overlay):
		_trash_confirm_overlay.visible = false

func _center_trash_confirm_dialog() -> void:
	if root_control == null or not is_instance_valid(root_control):
		return
	if _trash_confirm_overlay == null or not is_instance_valid(_trash_confirm_overlay):
		return
	_trash_confirm_overlay.size = root_control.size
	if _trash_confirm_dialog == null or not is_instance_valid(_trash_confirm_dialog):
		return
	var dialog_size: Vector2 = _trash_confirm_dialog.size
	if dialog_size.x <= 0.0 or dialog_size.y <= 0.0:
		dialog_size = _trash_confirm_dialog.custom_minimum_size
	_trash_confirm_dialog.position = Vector2(
		maxf((root_control.size.x - dialog_size.x) * 0.5, 0.0),
		maxf((root_control.size.y - dialog_size.y) * 0.5, 0.0)
	)

func _connect_context_menu_input() -> void:
	var callback := Callable(self, "_on_files_gui_input")
	var root_callback := Callable(self, "_on_files_root_gui_input")
	var controls: Array[Control] = []
	if root_control != null and is_instance_valid(root_control):
		controls.append(root_control)
	var content_control: Control = ui.by_id("files-content") if ui != null else null
	if content_control != null and is_instance_valid(content_control):
		controls.append(content_control)
	var list_control: Control = ui.by_id("files-list") if ui != null else null
	if list_control != null and is_instance_valid(list_control):
		controls.append(list_control)
		_collect_controls(list_control, controls)
	for control in controls:
		if control == null or not is_instance_valid(control):
			continue
		var callable: Callable = root_callback if control == root_control else callback
		if not control.gui_input.is_connected(callable):
			control.gui_input.connect(callable)
	_connect_shortcut_context_menu_input()

func _connect_shortcut_context_menu_input() -> void:
	if ui == null or state == null:
		return
	var shortcuts_list: Control = ui.by_id("files-shortcuts-list")
	if shortcuts_list == null or not is_instance_valid(shortcuts_list):
		return
	var shortcut_buttons: Array[Control] = []
	_collect_shortcut_buttons(shortcuts_list, shortcut_buttons)
	var shortcuts: Array = _sanitize_shortcuts(state.get_value("shortcuts", []), _home_path())
	var shortcut_index: int = 0
	for shortcut_button in shortcut_buttons:
		if shortcut_button == null or not is_instance_valid(shortcut_button):
			continue
		if shortcut_index >= shortcuts.size():
			break
		var shortcut_value: Variant = shortcuts[shortcut_index]
		shortcut_index += 1
		if not (shortcut_value is Dictionary):
			continue
		var shortcut: Dictionary = shortcut_value
		shortcut_button.set_meta("files_shortcut_path", _normalize_path(str(shortcut.get("path", ""))))
		shortcut_button.set_meta("files_shortcut_label", str(shortcut.get("label", "")))
		if bool(shortcut_button.get_meta("files_shortcut_context_connected", false)):
			continue
		var shortcut_callback := Callable(self, "_on_shortcut_gui_input").bind(shortcut_button)
		shortcut_button.gui_input.connect(shortcut_callback)
		shortcut_button.set_meta("files_shortcut_context_connected", true)

func _collect_shortcut_buttons(node: Node, output: Array[Control]) -> void:
	for child in node.get_children():
		if child is Button and str((child as Button).get_meta("hermes_tag", "")) == "ListItem":
			output.append(child as Control)
		_collect_shortcut_buttons(child, output)

func _collect_controls(node: Node, output: Array[Control]) -> void:
	for child in node.get_children():
		if child is Control:
			output.append(child as Control)
		_collect_controls(child, output)

func _on_files_gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_DELETE:
			delete_selected()
			return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_context_menu_mode = "files"
			_context_shortcut_path = ""
			_context_shortcut_label = ""
			_show_context_menu(_global_mouse_position())
			if root_control != null and is_instance_valid(root_control):
				root_control.get_viewport().set_input_as_handled()
			return
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_hide_context_menu_if_outside(_global_mouse_position())

func _on_files_root_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed:
			_hide_context_menu_if_outside(_global_mouse_position())

func _on_shortcut_gui_input(event: InputEvent, shortcut_control: Control) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_RIGHT:
		return
	if shortcut_control == null or not is_instance_valid(shortcut_control):
		return
	var shortcut_path: String = _normalize_path(str(shortcut_control.get_meta("files_shortcut_path", "")))
	if shortcut_path == "":
		return
	var shortcut_label: String = str(shortcut_control.get_meta("files_shortcut_label", shortcut_path))
	if state != null:
		state.set("shortcut_selected_path", shortcut_path)
	_show_shortcut_context_menu(shortcut_label, shortcut_path, _global_mouse_position())
	if root_control != null and is_instance_valid(root_control):
		root_control.get_viewport().set_input_as_handled()

func _global_mouse_position() -> Vector2:
	if root_control != null and is_instance_valid(root_control):
		return root_control.get_global_mouse_position()
	return Vector2.ZERO

func _show_context_menu(global_pos: Vector2) -> void:
	if _context_menu == null or not is_instance_valid(_context_menu):
		_build_context_menu()
	if _context_menu == null or _context_menu_column == null:
		return
	_rebuild_context_menu_items()
	var local_pos: Vector2 = global_pos
	if root_control != null and is_instance_valid(root_control):
		local_pos = root_control.get_global_transform().affine_inverse() * global_pos
		_context_menu.position = Vector2(
			clampf(local_pos.x, CONTEXT_MENU_MARGIN, maxf(root_control.size.x - _context_menu.size.x - CONTEXT_MENU_MARGIN, CONTEXT_MENU_MARGIN)),
			clampf(local_pos.y, CONTEXT_MENU_MARGIN, maxf(root_control.size.y - _context_menu.size.y - CONTEXT_MENU_MARGIN, CONTEXT_MENU_MARGIN))
		)
	else:
		_context_menu.global_position = global_pos
	_context_menu.visible = true
	_context_menu.move_to_front()

func _show_shortcut_context_menu(shortcut_label: String, shortcut_path: String, global_pos: Vector2) -> void:
	_context_menu_mode = "shortcut"
	_context_shortcut_label = shortcut_label
	_context_shortcut_path = _normalize_path(shortcut_path)
	_show_context_menu(global_pos)

func _hide_context_menu() -> void:
	if _context_menu != null and is_instance_valid(_context_menu):
		_context_menu.visible = false

func _hide_context_menu_if_outside(global_pos: Vector2) -> void:
	if _context_menu == null or not is_instance_valid(_context_menu) or not _context_menu.visible:
		return
	var menu_rect := Rect2(_context_menu.global_position, _context_menu.size)
	if not menu_rect.has_point(global_pos):
		_hide_context_menu()

func _rebuild_context_menu_items() -> void:
	if _context_menu_column == null or not is_instance_valid(_context_menu_column):
		return
	for child in _context_menu_column.get_children():
		child.queue_free()
	if _context_menu_mode == "shortcut":
		_rebuild_shortcut_context_menu_items()
		return
	var selected_path: String = state.get_string("selected_path", "") if state != null else ""
	var selected_type: String = state.get_string("selected_type", "") if state != null else ""
	var current_path: String = state.get_string("current_path", _home_path()) if state != null else _home_path()
	var has_selection: bool = selected_path != ""
	var has_clipboard: bool = state != null and state.get_string("clipboard_path", "") != "" and state.get_string("clipboard_mode", "") != ""
	if not has_selection:
		_add_context_menu_name_input()
		_add_context_menu_action("New file", Callable(self, "create_file"))
		_add_context_menu_action("New folder", Callable(self, "create_folder"))
		_add_context_menu_action("Paste", Callable(self, "paste_clipboard"), not has_clipboard)
		_add_context_menu_action("Open in Terminal", Callable(self, "open_in_terminal"))
		_add_context_menu_action("Refresh", Callable(self, "refresh_current"))
		if _is_trash_files_path(current_path):
			_add_context_menu_action("Empty Trash", Callable(self, "empty_trash"))
	else:
		_add_context_menu_action("Open", Callable(self, "open_selected"))
		_add_context_menu_rename_input()
		_add_context_menu_action("Rename", Callable(self, "rename_selected"))
		_add_context_menu_action("Copy", Callable(self, "copy_selected"))
		_add_context_menu_action("Cut", Callable(self, "cut_selected"))
		_add_context_menu_action("Delete", Callable(self, "delete_selected"))
		var terminal_action := Callable(self, "_open_selected_terminal_context") if selected_type == "dir" else Callable(self, "open_in_terminal")
		_add_context_menu_action("Open in Terminal", terminal_action)
	var item_count: int = _context_menu_column.get_child_count()
	_context_menu.size = Vector2(CONTEXT_MENU_WIDTH, maxf(44.0, float(item_count * 37 + 20)))

func _rebuild_shortcut_context_menu_items() -> void:
	var shortcut_path: String = _normalize_path(_context_shortcut_path)
	if shortcut_path == "":
		return
	_add_context_menu_action("Open", Callable(self, "_open_shortcut_context").bind(shortcut_path))
	_add_context_menu_action("Open in Terminal", Callable(self, "_open_shortcut_terminal_context").bind(shortcut_path))
	if _is_trash_files_path(shortcut_path):
		_add_context_menu_action("Empty Trash", Callable(self, "_empty_trash_from_shortcut_context").bind(shortcut_path))
	var item_count: int = _context_menu_column.get_child_count()
	_context_menu.size = Vector2(CONTEXT_MENU_WIDTH, maxf(44.0, float(item_count * 37 + 20)))

func _is_trash_files_path(path: String) -> bool:
	var current_path: String = _normalize_path(path)
	var trash_path: String = _normalize_path(_join_path(_home_path(), ".local/share/Trash/files"))
	return current_path == trash_path or current_path.contains("/Trash/files")

func _add_context_menu_action(text: String, action: Callable, disabled: bool = false) -> void:
	var button := _context_menu_button(text)
	button.disabled = disabled
	button.pressed.connect(func() -> void:
		_hide_context_menu()
		if action.is_valid():
			action.call()
	)
	_context_menu_column.add_child(button)

func _add_context_menu_name_input() -> void:
	var input := LineEdit.new()
	input.name = "ContextNameInput"
	input.placeholder_text = "New name..."
	input.custom_minimum_size = Vector2(0, 30)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.text = state.get_string("create_name", "") if state != null else ""
	input.text_changed.connect(func(value: String) -> void:
		if state != null:
			state.set("create_name", value)
	)
	input.text_submitted.connect(func(_value: String) -> void:
		_hide_context_menu()
		create_folder()
	)
	# Prevent context menu from hiding when clicking the input
	input.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			if _context_menu != null and is_instance_valid(_context_menu):
				_context_menu.get_viewport().set_input_as_handled()
	)
	_context_menu_column.add_child(input)
	# Grab focus after the menu is visible
	input.call_deferred("grab_focus")

func _add_context_menu_rename_input() -> void:
	var input := LineEdit.new()
	input.name = "ContextRenameInput"
	input.placeholder_text = "New name..."
	input.custom_minimum_size = Vector2(0, 30)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.text = state.get_string("rename_name", "") if state != null else ""
	input.text_changed.connect(func(value: String) -> void:
		if state != null:
			state.set("rename_name", value)
	)
	input.text_submitted.connect(func(_value: String) -> void:
		_hide_context_menu()
		rename_selected()
	)
	# Prevent context menu from hiding when clicking the input
	input.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			if _context_menu != null and is_instance_valid(_context_menu):
				_context_menu.get_viewport().set_input_as_handled()
	)
	_context_menu_column.add_child(input)
	# Grab focus after the menu is visible
	input.call_deferred("grab_focus")

func _context_menu_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 32)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 13)
	var normal := StyleFactory.button_normal(6)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	var hover := StyleFactory.button_hover(6)
	hover.content_margin_left = 10
	hover.content_margin_right = 10
	hover.content_margin_top = 4
	hover.content_margin_bottom = 4
	var pressed := StyleFactory.button_pressed(6)
	pressed.content_margin_left = 10
	pressed.content_margin_right = 10
	pressed.content_margin_top = 4
	pressed.content_margin_bottom = 4
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleFactory.button_focus(6))
	button.add_theme_stylebox_override("disabled", StyleFactory.button_disabled(6))
	return button

func _open_selected_terminal_context(event = null) -> void:
	last_event = event
	var selected_path: String = state.get_string("selected_path", "") if state != null else ""
	if selected_path == "":
		open_in_terminal(event)
		return
	if _shell == null:
		_set_status("Terminal unavailable", true)
		return
	if _shell.has_method("launch_app_with_context"):
		_shell.call("launch_app_with_context", "console", {"initial_cwd": selected_path})
		_set_status("Opened Terminal in " + selected_path, false)
		_hide_context_menu()
	else:
		open_in_terminal(event)

func _open_shortcut_context(shortcut_path: String) -> void:
	if state == null:
		return
	var target_path: String = _normalize_path(shortcut_path)
	state.set("shortcut_selected_path", target_path)
	state.set("path_input", target_path)
	_refresh(true, true)

func _empty_trash_from_shortcut_context(shortcut_path: String) -> void:
	var target_path: String = _normalize_path(shortcut_path)
	if state != null:
		state.set("shortcut_selected_path", target_path)
	empty_trash()

func _open_shortcut_terminal_context(shortcut_path: String) -> void:
	var target_path: String = _normalize_path(shortcut_path)
	if target_path == "":
		target_path = _home_path()
	if _shell == null:
		_set_status("Terminal unavailable", true)
		return
	if _shell.has_method("launch_app_with_context"):
		_shell.call("launch_app_with_context", "console", {"initial_cwd": target_path})
		_set_status("Opened Terminal in " + target_path, false)
		_hide_context_menu()
	elif _shell.has_method("launch_app"):
		_shell.call("launch_app", "console")
		_set_status("Opened Terminal", false)
		_hide_context_menu()
	else:
		_set_status("Terminal unavailable", true)

func _navigate_history(direction: int) -> void:
	if state == null:
		return
	var history_value: Variant = state.get_value("history", [])
	var history: Array = history_value if history_value is Array else []
	if history.is_empty():
		return
	var index: int = int(state.get_value("history_index", history.size() - 1))
	var target_index: int = clampi(index + direction, 0, history.size() - 1)
	if target_index == index:
		return
	state.set_many({"history_index": target_index, "path_input": str(history[target_index])})
	_refresh(false, false)

func _refresh(clear_status: bool, push_history: bool) -> void:
	var timing_start: int = Time.get_ticks_usec()
	if state == null:
		return
	var target_path: String = _resolve_path(state.get_string("path_input", state.get_string("current_path", _home_path())), state.get_string("current_path", _home_path()))
	if not _is_dir(target_path):
		_set_status("Folder not found: " + target_path, true)
		state.set("path_input", state.get_string("current_path", _home_path()))
		return
	var list_start: int = Time.get_ticks_usec()
	var entries_raw: Array = _list_dir(target_path)
	_trace_timing("list_dir " + target_path, list_start)
	var entries: Array = []
	for item in entries_raw:
		if not (item is Dictionary):
			continue
		var entry: Dictionary = item
		var entry_type: String = str(entry.get("type", "file"))
		var name_text: String = str(entry.get("name", ""))
		var path_text: String = str(entry.get("path", ""))
		if name_text == "" or path_text == "":
			continue
		entries.append({
			"name": name_text,
			"name_label": ("📁 " if entry_type == "dir" else "📄 ") + name_text,
			"type": entry_type,
			"path": path_text,
			"owner": str(entry.get("owner", "")),
			"group": str(entry.get("group", "")),
			"mode": str(entry.get("mode", "")),
			"size": int(entry.get("size", 0)),
			"modified_text": "—",
			"size_text": _size_label(entry)
		})
	var next_state: Dictionary = {
		"current_path": target_path,
		"path_input": target_path,
		"breadcrumb": _breadcrumb(target_path),
		"entries": entries,
		"has_entries": not entries.is_empty(),
		"selected_path": "",
		"selected_type": "",
		"selected_name": "",
		"selected_label": "Selected: none",
		"details_label": "",
		"has_selection": false,
		"can_rename": false
	}
	if clear_status:
		next_state["status"] = "This folder is empty." if entries.is_empty() else ""
	elif not entries.is_empty() and state.get_string("status", "") == "This folder is empty.":
		next_state["status"] = ""
	state.set_many(next_state)
	if push_history:
		_push_history(target_path)
	_update_derived_state()
	call_deferred("_connect_context_menu_input")
	_trace_timing("refresh " + target_path, timing_start)

func _apply_selection(entry: Dictionary) -> void:
	if state == null:
		return
	var path_value: String = str(entry.get("path", ""))
	var type_value: String = str(entry.get("type", ""))
	var name_value: String = str(entry.get("name", ""))
	state.set_many({
		"selected_path": path_value,
		"selected_type": type_value,
		"selected_name": name_value,
		"rename_name": name_value,
		"selected_label": "Selected: " + path_value,
		"details_label": "Type: %s   Owner: %s:%s   Mode: %s   Size: %s" % [
			type_value,
			str(entry.get("owner", "")),
			str(entry.get("group", "")),
			str(entry.get("mode", "")),
			str(entry.get("size_text", ""))
		],
		"status": "Folder selected. Use Open to enter." if type_value == "dir" else "",
		"has_selection": true,
		"can_rename": name_value.strip_edges() != ""
	})

func _open_entry_path(path: String) -> void:
	var target_path: String = _normalize_path(path)
	var entry: Dictionary = _entry_for_path(target_path)
	var type_value: String = str(entry.get("type", state.get_string("selected_type", "") if state != null else ""))
	if type_value == "dir" or _is_dir(target_path):
		open_path(target_path)
		return
	_open_text_file(target_path)
	_set_status("Opened in Text: " + _basename(target_path), false)

func _entry_for_path(path: String) -> Dictionary:
	if state == null:
		return {}
	var target_path: String = _normalize_path(path)
	var entries: Array = state.get_value("entries", [])
	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		if str(entry.get("path", "")) == target_path:
			return entry
	return {}

func _update_derived_state() -> void:
	if state == null:
		return
	var selected_path: String = state.get_string("selected_path", "")
	var has_selection: bool = selected_path != ""
	var create_name: String = state.get_string("create_name", "").strip_edges()
	var rename_name: String = state.get_string("rename_name", "").strip_edges()
	var clipboard_path: String = state.get_string("clipboard_path", "")
	var clipboard_mode: String = state.get_string("clipboard_mode", "")
	var history_value: Variant = state.get_value("history", [])
	var history: Array = history_value if history_value is Array else []
	var history_index: int = int(state.get_value("history_index", history.size() - 1))
	var shortcuts: Array = _sanitize_shortcuts(state.get_value("shortcuts", []), _home_path())
	var shortcut_selected_path: String = state.get_string("shortcut_selected_path", "")
	var selected_shortcut_index: int = _shortcut_index(shortcuts, shortcut_selected_path)
	var editor_label: String = state.get_string("shortcut_edit_label", "").strip_edges()
	var editor_path: String = state.get_string("shortcut_edit_path", "").strip_edges()
	state.set_many({
		"can_create": create_name != "",
		"has_selection": has_selection,
		"can_rename": has_selection and rename_name != "",
		"can_paste": clipboard_path != "" and clipboard_mode != "",
		"clipboard_label": "clip: empty" if clipboard_path == "" else ("clip: " + clipboard_mode + " " + clipboard_path),
		"can_back": history_index > 0,
		"can_forward": history_index >= 0 and history_index < history.size() - 1,
		"can_up": state.get_string("current_path", _home_path()) != "/",
		"shortcuts": shortcuts,
		"has_selected_shortcut": selected_shortcut_index >= 0,
		"can_move_shortcut_up": selected_shortcut_index > 0,
		"can_move_shortcut_down": selected_shortcut_index >= 0 and selected_shortcut_index < shortcuts.size() - 1,
		"can_save_shortcut": editor_label != "" and editor_path != ""
	})
	call_deferred("_connect_shortcut_context_menu_input")

func _push_history(path: String) -> void:
	if state == null:
		return
	var history_value: Variant = state.get_value("history", [])
	var history: Array = history_value if history_value is Array else []
	var index: int = int(state.get_value("history_index", history.size() - 1))
	if index < history.size() - 1:
		history = history.slice(0, index + 1)
	if history.is_empty() or str(history[history.size() - 1]) != path:
		history.append(path)
		index = history.size() - 1
	else:
		index = history.size() - 1
	state.set_many({"history": history, "history_index": index})

func _set_status(message: String, is_error: bool) -> void:
	if state == null:
		return
	state.set("status", message)
	if is_error and message != "":
		push_warning("Files controller: " + message)

func _emit_shortcuts_changed() -> void:
	if _shortcuts_changed_callback.is_valid() and state != null:
		_shortcuts_changed_callback.call((state.get_value("shortcuts", []) as Array).duplicate(true))

func _queue_state_save() -> void:
	if _state_save_callback.is_valid():
		_state_save_callback.call()
		return
	if _shell != null and _shell.has_method("_queue_state_save"):
		_shell.call("_queue_state_save")

func _open_text_file(path: String) -> void:
	if _open_file_callback.is_valid():
		_open_file_callback.call(path)
		return
	if _shell != null and _shell.has_method("_open_text_file"):
		_shell.call("_open_text_file", path)

func _default_shortcuts(home: String) -> Array:
	return [
		{"label": "Desktop", "path": _join_path(home, "Desktop")},
		{"label": "Documents", "path": _join_path(home, "Documents")},
		{"label": "Downloads", "path": _join_path(home, "Downloads")},
		{"label": "Music", "path": _join_path(home, "Music")},
		{"label": "Pictures", "path": _join_path(home, "Pictures")},
		{"label": "Videos", "path": _join_path(home, "Videos")},
		{"label": "Home", "path": home},
		{"label": "Trash", "path": _join_path(home, ".local/share/Trash/files")},
		{"label": "Networks", "path": home}
	]

func _sanitize_shortcuts(value, home: String) -> Array:
	var output: Array = []
	if value is Array:
		for item in value:
			if not (item is Dictionary):
				continue
			var shortcut: Dictionary = item
			var label: String = str(shortcut.get("label", "")).strip_edges()
			var path: String = str(shortcut.get("path", "")).strip_edges()
			if label == "" or path == "":
				continue
			output.append({"label": label, "path": _normalize_path(path)})
	if output.is_empty():
		output = _default_shortcuts(home)
	return output

func _shortcut_index(shortcuts: Array, selected_path: String) -> int:
	if selected_path == "":
		return -1
	for index in range(shortcuts.size()):
		var value: Variant = shortcuts[index]
		if value is Dictionary and _normalize_path(str((value as Dictionary).get("path", ""))) == selected_path:
			return index
	return -1

func _paste_destination_path(source_path: String, destination_dir: String) -> String:
	var clean_source: String = _normalize_path(source_path)
	var clean_destination_dir: String = _normalize_path(destination_dir)
	var base_name: String = _basename(clean_source)
	var stem: String = base_name.get_basename()
	var extension: String = base_name.get_extension()
	var candidate_name: String = base_name
	var index: int = 1
	while _exists(_join_path(clean_destination_dir, candidate_name)):
		if extension == "":
			candidate_name = "%s copy%s" % [stem, "" if index == 1 else " " + str(index)]
		else:
			candidate_name = "%s copy%s.%s" % [stem, "" if index == 1 else " " + str(index), extension]
		index += 1
	return _join_path(clean_destination_dir, candidate_name)

func _breadcrumb(path: String) -> String:
	return _normalize_path(path)

func _trace_timing(label: String, start_usec: int) -> void:
	if DEBUG_FILES_TIMING:
		print("[FilesTiming] %s %dus" % [label, Time.get_ticks_usec() - start_usec])

func _size_label(entry: Dictionary) -> String:
	if str(entry.get("type", "")) == "dir":
		return "Folder"
	var size_bytes: int = int(entry.get("size", 0))
	if size_bytes < 1024:
		return "%d B" % size_bytes
	var size_kb: float = float(size_bytes) / 1024.0
	if size_kb < 1024.0:
		return "%.1f KB" % size_kb
	var size_mb: float = size_kb / 1024.0
	if size_mb < 1024.0:
		return "%.1f MB" % size_mb
	return "%.1f GB" % (size_mb / 1024.0)

func _has_file_bridge() -> bool:
	return os != null and os.files != null

func _home_path() -> String:
	if _has_file_bridge() and os.files.has_method("home_path"):
		return str(os.files.home_path())
	return "/home/user"

func _normalize_path(path: String) -> String:
	if _has_file_bridge() and os.files.has_method("normalize"):
		return str(os.files.normalize(path))
	return path

func _resolve_path(path: String, base_path: String) -> String:
	if _has_file_bridge() and os.files.has_method("resolve"):
		return str(os.files.resolve(path, base_path))
	return _normalize_path(path)

func _dirname(path: String) -> String:
	if _has_file_bridge() and os.files.has_method("dirname"):
		return str(os.files.dirname(path))
	return _normalize_path(path.get_base_dir())

func _basename(path: String) -> String:
	if _has_file_bridge() and os.files.has_method("basename"):
		return str(os.files.basename(path))
	return _normalize_path(path).get_file()

func _join_path(base: String, child: String) -> String:
	if _has_file_bridge() and os.files.has_method("join_path"):
		return str(os.files.join_path(base, child))
	return base.rstrip("/") + "/" + child.lstrip("/")

func _is_dir(path: String) -> bool:
	if _has_file_bridge() and os.files.has_method("is_dir"):
		return bool(os.files.is_dir(path))
	return false

func _is_file(path: String) -> bool:
	if _has_file_bridge() and os.files.has_method("is_file"):
		return bool(os.files.is_file(path))
	return false

func _exists(path: String) -> bool:
	if _has_file_bridge() and os.files.has_method("exists"):
		return bool(os.files.exists(path))
	return false

func _list_dir(path: String) -> Array:
	if _has_file_bridge() and os.files.has_method("list_dir"):
		var entries: Variant = os.files.list_dir(path)
		if entries is Array:
			return (entries as Array).duplicate(true)
	return []

func _make_dir(path: String) -> Dictionary:
	if _has_file_bridge() and os.files.has_method("make_dir"):
		var value: Variant = os.files.make_dir(path)
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
		var message: String = str(value)
		if message == "":
			return {"ok": true, "path": _normalize_path(path)}
		return {"ok": false, "error": {"message": message}, "path": _normalize_path(path)}
	return {"ok": false, "error": {"message": "Filesystem mkdir unavailable"}, "path": _normalize_path(path)}

func _write_file(path: String, content: String) -> Dictionary:
	if _has_file_bridge() and os.files.has_method("write"):
		var value: Variant = os.files.write(path, content)
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {"ok": false, "error": {"message": "Filesystem write unavailable"}}

func _rename_path(path: String, new_name: String) -> Dictionary:
	if _has_file_bridge() and os.files.has_method("rename"):
		var value: Variant = os.files.rename(path, new_name)
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {"ok": false, "error": {"message": "Filesystem rename unavailable"}}

func _copy_path(source: String, destination: String) -> Dictionary:
	if _has_file_bridge() and os.files.has_method("copy"):
		var value: Variant = os.files.copy(source, destination)
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {"ok": false, "error": {"message": "Filesystem copy unavailable"}}

func _move_path(source: String, destination: String) -> Dictionary:
	if _has_file_bridge() and os.files.has_method("move"):
		var value: Variant = os.files.move(source, destination)
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {"ok": false, "error": {"message": "Filesystem move unavailable"}}

func _delete_path(path: String) -> Dictionary:
	if _has_file_bridge() and os.files.has_method("delete"):
		var value: Variant = os.files.delete(path)
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {"ok": false, "error": {"message": "Filesystem delete unavailable"}}

func _move_to_trash(path: String) -> Dictionary:
	if _has_file_bridge() and os.files.has_method("trash_path"):
		var value: Variant = os.files.trash_path(path)
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return _delete_path(path)

func _ensure_trash_dirs() -> void:
	if not _has_file_bridge() or not os.files.has_method("make_dir") or not os.files.has_method("is_dir"):
		print("Files controller: trash dir ensure skipped; file bridge is missing required methods")
		return
	var home: String = _home_path()
	var local_dir: String = _join_path(home, ".local")
	var share_dir: String = _join_path(local_dir, "share")
	var trash_base: String = _join_path(share_dir, "Trash")
	var trash_files: String = _join_path(trash_base, "files")
	var trash_info: String = _join_path(trash_base, "info")
	var dir_paths: Array = [local_dir, share_dir, trash_base, trash_files, trash_info]
	print("Files controller: ensuring trash directory tree: " + ", ".join(dir_paths))
	for dir_path_value in dir_paths:
		var dir_path: String = str(dir_path_value)
		if bool(os.files.is_dir(dir_path)):
			print("Files controller: trash dir already exists: " + dir_path)
			continue
		print("Files controller: creating trash dir: " + dir_path)
		var result: Dictionary = _make_dir(dir_path)
		if bool(result.get("ok", false)):
			print("Files controller: created trash dir: " + dir_path)
			continue
		var message: String = _error_message(result, "Could not create trash folder")
		push_warning("Files controller: " + message + " (" + dir_path + ")")
		return

func empty_trash(event = null) -> void:
	last_event = event
	if _has_file_bridge() and os.files.has_method("trash_item_count"):
		var count: int = int(os.files.trash_item_count())
		if count == 0:
			_set_status("Trash is already empty", false)
			return
	if state != null:
		state.set("show_trash_confirm", true)
	_show_trash_confirm_dialog()
	_set_status("Confirm: Empty Trash? This cannot be undone.", false)

func confirm_empty_trash(event = null) -> void:
	last_event = event
	if state != null:
		state.set("show_trash_confirm", false)
	_hide_trash_confirm_dialog()
	if _has_file_bridge() and os.files.has_method("empty_trash"):
		var result: Variant = os.files.empty_trash()
		if result is Dictionary and bool((result as Dictionary).get("ok", false)):
			var count: int = int((result as Dictionary).get("deleted_count", 0))
			_set_status("Trash emptied: " + str(count) + " items permanently deleted", false)
			_refresh(false, false)
		else:
			_set_status("Failed to empty trash", true)
	else:
		_set_status("Trash system unavailable", true)

func cancel_empty_trash(event = null) -> void:
	last_event = event
	if state != null:
		state.set("show_trash_confirm", false)
	_hide_trash_confirm_dialog()
	_set_status("", false)

func _error_message(result: Dictionary, fallback: String) -> String:
	var error_value: Variant = result.get("error", null)
	if error_value is Dictionary:
		var message: String = str((error_value as Dictionary).get("message", "")).strip_edges()
		if message != "":
			return message
	elif str(error_value).strip_edges() != "":
		return str(error_value)
	return fallback
