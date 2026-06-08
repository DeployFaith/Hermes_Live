extends "res://addons/hermes_os/scripts/ui/hermes_ui/runtime/hermes_app_controller.gd"

const HermesShellContext = preload("res://addons/hermes_os/scripts/os/hermes_shell/hermes_shell_context.gd")
const HermesLauncherViewModel = preload("res://addons/hermes_os/scripts/os/hermes_shell/chrome/launcher/hermes_launcher_view_model.gd")
const Tokens = preload("res://addons/hermes_os/scripts/os/design_tokens.gd")

const DEBUG_LAUNCHER_TIMING := false

var _context: HermesShellContext = HermesShellContext.new().setup({})
var _shell: Node = null
var _view_model: HermesLauncherViewModel = null
var _filesystem: RefCounted = null
var _search_filter: String = ""
var _category_filter: String = "all"
var _selected_app_id: String = ""

func _launcher_row_style(fill: Color, border: Color, radius: int = 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.border_width_left = 1
	box.border_width_right = 1
	box.border_width_top = 1
	box.border_width_bottom = 1
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	return box

func _style_active_category(button: Button) -> void:
	if button == null:
		return
	var accent: Color = Tokens.ACCENT
	var accent_hover: Color = Tokens.ACCENT_HOVER
	var accent_pressed: Color = Tokens.ACCENT_PRESSED
	# Subtle active category marker: very low-alpha cue + thin left edge (not full-row highlight)
	# Hover/pressed remain canonical accent-based per requirements; if hovered, full hover treatment.
	var normal_fill: Color = Tokens.alpha(accent, 0.06)
	var normal_border: Color = Color(0, 0, 0, 0)
	var left_border_color: Color = Tokens.alpha(accent, 0.65)
	var hover_fill: Color = Tokens.alpha(accent, 0.2)
	var hover_border: Color = Tokens.alpha(accent_hover, 0.7)
	var pressed_fill: Color = Tokens.alpha(accent_pressed, 0.28)
	var pressed_border: Color = Tokens.alpha(accent_pressed, 0.8)
	var normal_box := _launcher_row_style(normal_fill, normal_border)
	normal_box.border_width_left = 3
	normal_box.border_width_right = 0
	normal_box.border_width_top = 0
	normal_box.border_width_bottom = 0
	normal_box.border_color = left_border_color
	button.add_theme_stylebox_override("normal", normal_box)
	button.add_theme_stylebox_override("hover", _launcher_row_style(hover_fill, hover_border))
	button.add_theme_stylebox_override("pressed", _launcher_row_style(pressed_fill, pressed_border))
	button.add_theme_stylebox_override("focus", _launcher_row_style(hover_fill, hover_border))
	button.add_theme_stylebox_override("disabled", _launcher_row_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	# Subtle accent text/icon cue for active category
	button.add_theme_color_override("font_color", accent)
	button.add_theme_color_override("font_hover_color", accent)
	button.add_theme_color_override("font_pressed_color", accent)

func _style_launcher_row(button: Button, selected: bool) -> void:
	if button == null:
		return
	var accent: Color = Tokens.ACCENT
	var accent_hover: Color = Tokens.ACCENT_HOVER
	var accent_pressed: Color = Tokens.ACCENT_PRESSED
	var normal_fill: Color = Tokens.alpha(accent, 0.15) if selected else Color(0, 0, 0, 0)
	var normal_border: Color = Tokens.alpha(accent, 0.5) if selected else Color(0, 0, 0, 0)
	var hover_fill: Color = Tokens.alpha(accent, 0.2) if selected else Tokens.alpha(accent, 0.12)
	var hover_border: Color = Tokens.alpha(accent_hover, 0.7) if selected else Tokens.alpha(accent, 0.45)
	var pressed_fill: Color = Tokens.alpha(accent_pressed, 0.28)
	var pressed_border: Color = Tokens.alpha(accent_pressed, 0.8)
	button.add_theme_stylebox_override("normal", _launcher_row_style(normal_fill, normal_border))
	button.add_theme_stylebox_override("hover", _launcher_row_style(hover_fill, hover_border))
	button.add_theme_stylebox_override("pressed", _launcher_row_style(pressed_fill, pressed_border))
	button.add_theme_stylebox_override("focus", _launcher_row_style(hover_fill, hover_border))
	button.add_theme_stylebox_override("disabled", _launcher_row_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))

func _app_ready() -> void:
	if state == null:
		return
	state.set_many({
		"user_label": "user  ~",
		"search": "",
		"section_title": "Applications",
		"categories": [],
		"apps": [],
		"empty_visible": false
	})

func configure_shell_context(context: Dictionary) -> void:
	_shell = context.get("shell", null) as Node
	var context_value: Variant = context.get("hermes_shell_context", null)
	if context_value is HermesShellContext:
		_context = context_value as HermesShellContext
	else:
		_context = HermesShellContext.new().setup(context)
	_filesystem = _context.value(&"filesystem", null) as RefCounted
	_view_model = _context.value(&"launcher_view_model", null) as HermesLauncherViewModel
	if _view_model == null:
		_view_model = HermesLauncherViewModel.new().setup(_context.value(&"app_registry", null) as RefCounted)
	_search_filter = str(_context.value(&"launcher_search", _search_filter))
	_category_filter = str(_context.value(&"launcher_category", _category_filter)).strip_edges()
	if _category_filter == "":
		_category_filter = "all"
	_selected_app_id = str(_context.value(&"launcher_selected_app_id", _selected_app_id)).strip_edges()
	refresh_launcher(true)

func refresh_launcher(restore_search_focus: bool = false) -> void:
	if state == null:
		return
	if _view_model == null:
		state.set_many({"categories": [], "apps": [], "empty_visible": true})
		return
	var apps: Array[Dictionary] = _view_model.project_apps(_search_filter, _category_filter, _selected_app_id)
	# NOTE: removed first-app default selection binding to suppress persistent mouse-mode highlight on Files (and any first app row).
	# Only explicit _selected_app_id (set via keyboard nav or launch) will cause selected=true via view_model.
	# This distinguishes default mouse mode (no app row highlighted) from keyboard selection.
	var categories: Array[Dictionary] = _view_model.project_categories(_category_filter)
	state.set_many({
		"user_label": _user_label(),
		"search": _search_filter,
		"section_title": "Favorites" if _normalized_category(_category_filter) == "favorites" else "Applications",
		"categories": categories,
		"apps": apps,
		"empty_visible": apps.is_empty()
	})
	_decorate_launcher_controls()
	if restore_search_focus:
		call_deferred("focus_search")

func set_selected_app(app_id: String) -> void:
	_selected_app_id = app_id
	_context.call_action(&"launcher_set_selected_app", [app_id])
	refresh_launcher(false)

func focus_search() -> void:
	var search: LineEdit = _find_control_by_id(root_control, "launcher-search") as LineEdit
	if search != null:
		search.set_meta("hermes_text_input", true)
		search.grab_focus()
		search.caret_column = search.text.length()

func handle_search(event) -> void:
	_search_filter = str(event.value)
	_context.call_action(&"launcher_set_search", [_search_filter])
	refresh_launcher(true)

func submit_search(_event = null) -> void:
	# Submitting the search field should keep the query and editing focus intact.
	call_deferred("focus_search")

func select_category(event) -> void:
	_category_filter = str(event.value).strip_edges()
	if _category_filter == "":
		_category_filter = "all"
	_context.call_action(&"launcher_set_category", [_category_filter])
	refresh_launcher(true)

func launch_app(event) -> void:
	var timing_start: int = Time.get_ticks_usec()
	var app_id: String = str(event.value).strip_edges()
	if app_id == "":
		return
	_selected_app_id = app_id
	_context.call_action(&"launcher_set_selected_app", [app_id])
	_context.call_action(&"launcher_hide", [])
	_trace_timing("app_click_to_hide " + app_id, timing_start)
	await _defer_one_frame_for_launcher_hide()
	var launch_start: int = Time.get_ticks_usec()
	_invoke_launch_app(app_id)
	_trace_timing("launch_app_call " + app_id, launch_start)

func _defer_one_frame_for_launcher_hide() -> void:
	if root_control != null and root_control.is_inside_tree():
		await root_control.get_tree().process_frame

func _invoke_launch_app(app_id: String) -> void:
	if _context.has_value(&"launcher_launch_app"):
		_context.call_action(&"launcher_launch_app", [app_id])
	elif _shell != null and _shell.has_method("launch_app"):
		_shell.call("launch_app", app_id)

func open_account(_event = null) -> void:
	if _context.has_value(&"launcher_open_account"):
		_context.call_action(&"launcher_open_account", [])
	elif _shell != null and _shell.has_method("_open_account_settings"):
		_shell.call("_open_account_settings")

func lock_session(_event = null) -> void:
	_context.call_action(&"launcher_hide", [])
	if _context.has_value(&"launcher_lock_session"):
		_context.call_action(&"launcher_lock_session", [])
	elif _shell != null and _shell.has_method("_power_action"):
		_shell.call("_power_action", "lock")

func show_power_menu(_event = null) -> void:
	_context.call_action(&"launcher_hide", [])
	if _context.has_value(&"launcher_toggle_session_menu"):
		_context.call_action(&"launcher_toggle_session_menu", [])
	elif _shell != null and _shell.has_method("_toggle_session_menu"):
		_shell.call("_toggle_session_menu")

func _contains_app(apps: Array[Dictionary], app_id: String) -> bool:
	for app in apps:
		if str(app.get("app_id", app.get("id", ""))) == app_id:
			return true
	return false

func _user_label() -> String:
	if _filesystem == null:
		return "user  ~"
	var user_name: String = "user"
	var home: String = "~"
	if _filesystem.has_method("current_user"):
		user_name = str(_filesystem.call("current_user"))
	if _filesystem.has_method("home_path"):
		home = str(_filesystem.call("home_path"))
	return "%s  %s" % [user_name, home]

func _decorate_launcher_controls() -> void:
	if root_control == null:
		return
	var search: LineEdit = _find_control_by_id(root_control, "launcher-search") as LineEdit
	if search != null:
		search.set_meta("hermes_text_input", true)
		search.tooltip_text = "Search installed apps"
	for app in (_view_model.project_apps("", "all", _selected_app_id) if _view_model != null else []):
		var app_data: Dictionary = app as Dictionary
		var app_id: String = str((app as Dictionary).get("app_id", (app as Dictionary).get("id", "")))
		var button: Button = _find_control_by_id(root_control, "launcher-app-" + app_id) as Button
		if button == null:
			continue
		button.tooltip_text = "Open " + str(app_data.get("title", app_id))
		_style_launcher_row(button, bool(app_data.get("selected", false)))
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if _shell != null and _shell.has_method("_app_icon"):
			var icon_value: Variant = _shell.call("_app_icon", app_id)
			if icon_value is Texture2D:
				button.icon = icon_value
		button.expand_icon = false
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_constant_override("icon_max_width", 22)
	for category in (_view_model.project_categories(_category_filter) if _view_model != null else []):
		var category_data: Dictionary = category as Dictionary
		var category_id: String = str((category as Dictionary).get("id", ""))
		var category_button: Button = _find_control_by_id(root_control, "launcher-category-" + category_id) as Button
		if category_button == null:
			continue
		var is_active_category: bool = bool(category_data.get("selected", false))
		if is_active_category:
			_style_active_category(category_button)
		else:
			_style_launcher_row(category_button, false)
		if _shell != null and _shell.has_method("_category_icon"):
			var category_icon: Variant = _shell.call("_category_icon", category_id)
			if category_icon is Texture2D:
				category_button.icon = category_icon
		category_button.expand_icon = false
		category_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		category_button.add_theme_constant_override("icon_max_width", 18)

func _normalized_category(value: String) -> String:
	var clean: String = value.strip_edges().to_lower()
	if clean == "":
		return "all"
	return clean.replace(" ", "_")

func _trace_timing(label: String, start_usec: int) -> void:
	if DEBUG_LAUNCHER_TIMING:
		print("[LauncherTiming] %s %dus" % [label, Time.get_ticks_usec() - start_usec])

func _find_control_by_id(node: Node, target_id: String) -> Control:
	if node == null:
		return null
	if node is Control and node.has_meta("hermes_id") and str(node.get_meta("hermes_id", "")) == target_id:
		return node as Control
	for child in node.get_children():
		var found: Control = _find_control_by_id(child, target_id)
		if found != null:
			return found
	return null
