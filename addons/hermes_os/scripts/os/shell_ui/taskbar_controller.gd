extends "res://addons/hermes_os/scripts/ui/hermes_ui/runtime/hermes_app_controller.gd"

const StyleFactory = preload("res://addons/hermes_os/scripts/os/style_factory.gd")
const Tokens = preload("res://addons/hermes_os/scripts/os/design_tokens.gd")

var _shell: Node = null

func _app_ready() -> void:
	if state == null:
		return
	state.set("tasks", [])

func configure_shell_context(context: Dictionary) -> void:
	_shell = context.get("shell", null) as Node
	refresh_taskbar()

func refresh_taskbar() -> void:
	if state == null:
		return
	var tasks: Array = []
	if _shell != null:
		var windows: Array = []
		if _shell.has_method("_all_open_windows_in_app_order"):
			windows = _shell.call("_all_open_windows_in_app_order")
		var seen: Dictionary = {}
		for item in windows:
			var window: Node = item as Node
			if window == null or not is_instance_valid(window):
				continue
			var app_id: String = str(window.get("app_id"))
			if app_id == "" or seen.has(app_id):
				continue
			seen[app_id] = true
			var title: String = _app_title(app_id, window)
			var active_window: Variant = _shell.get("_active_window")
			tasks.append({
				"id": app_id,
				"title": title,
				"label": title,
				"active": active_window == window,
				"visible": bool(window.get("visible")),
				"minimized": not bool(window.get("visible"))
			})
	state.set("tasks", tasks)
	_decorate_taskbar_controls(tasks)
	_update_dynamic_taskbar_sizing(tasks)

func activate_task(event) -> void:
	if _shell == null:
		return
	var app_id: String = str(event.value).strip_edges()
	if app_id == "":
		return
	if _shell.has_method("_on_task_button_pressed"):
		_shell.call("_on_task_button_pressed", app_id)

func toggle_launcher(_event = null) -> void:
	if _shell != null and _shell.has_method("_toggle_launcher"):
		_shell.call("_toggle_launcher")

func toggle_notifications(_event = null) -> void:
	if _shell != null and _shell.has_method("_toggle_notification_history"):
		_shell.call("_toggle_notification_history")

func toggle_session_menu(_event = null) -> void:
	if _shell != null and _shell.has_method("_toggle_session_menu"):
		_shell.call("_toggle_session_menu")

func open_account_center(_event = null) -> void:
	if _shell != null and _shell.has_method("_open_account_settings"):
		_shell.call("_open_account_settings")

func configure_static_buttons() -> void:
	_decorate_static_button("taskbar-start", "start", "Start")

func _decorate_taskbar_controls(tasks: Array) -> void:
	if root_control == null or _shell == null:
		return
	configure_static_buttons()
	for task in tasks:
		if not (task is Dictionary):
			continue
		var app_id: String = str((task as Dictionary).get("id", ""))
		var button: Button = _find_control_by_id(root_control, "taskbar-window-" + app_id) as Button
		if button == null:
			continue
		button.text = ""
		button.tooltip_text = str((task as Dictionary).get("title", app_id))
		button.custom_minimum_size = Vector2(40, 40)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		_apply_icon_button_style(button, bool((task as Dictionary).get("active", false)))
		if _shell.has_method("_app_icon"):
			var icon_value: Variant = _shell.call("_app_icon", app_id)
			if icon_value is Texture2D:
				button.icon = icon_value
		_update_indicator(button, task as Dictionary)

func _decorate_static_button(control_id: String, icon_name: String, tooltip: String) -> void:
	if root_control == null or _shell == null:
		return
	var button: Button = _find_control_by_id(root_control, control_id) as Button
	if button == null:
		return
	button.text = ""
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(40, 40)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	if control_id == "taskbar-start":
		_apply_start_button_style(button)
	else:
		_apply_icon_button_style(button, false)
	if _shell.has_method("_start_menu_icon"):
		var icon_value: Variant = _shell.call("_start_menu_icon", icon_name)
		if icon_value is Texture2D:
			button.icon = icon_value

func refresh_start_button_accent() -> void:
	var button: Button = _find_control_by_id(root_control, "taskbar-start") as Button
	_apply_start_button_style(button)

func _apply_start_button_style(button: Button) -> void:
	if button == null:
		return
	button.add_theme_color_override("font_color", Tokens.MUTED)
	button.add_theme_stylebox_override("normal", StyleFactory.icon_button_normal(8))
	button.add_theme_stylebox_override("hover", StyleFactory.icon_button_normal(8))
	button.add_theme_stylebox_override("pressed", StyleFactory.icon_button_normal(8))
	button.add_theme_stylebox_override("focus", StyleFactory.icon_button_focus_clear(8))
	button.add_theme_stylebox_override("disabled", StyleFactory.icon_button_normal(8))
	# Accent tint on icon only (no background fill) — avoids backplate/slot artifact.
	# Reads live Tokens.ACCENT each call so accent changes propagate without restart.
	button.add_theme_color_override("icon_hover_color", Tokens.ACCENT)
	button.add_theme_color_override("icon_pressed_color", Tokens.ACCENT_HOVER)

func _apply_icon_button_style(button: Button, active: bool) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", StyleFactory.icon_button_normal(8))
	if active:
		button.add_theme_color_override("font_color", Tokens.TEXT)
	else:
		button.add_theme_color_override("font_color", Tokens.MUTED)
	button.add_theme_stylebox_override("hover", StyleFactory.icon_button_hover(8))
	button.add_theme_stylebox_override("pressed", StyleFactory.icon_button_pressed(8))
	# Dock icon buttons should not render a rectangular focus backplate/slot.
	button.add_theme_stylebox_override("focus", StyleFactory.icon_button_focus_clear(8))
	button.add_theme_stylebox_override("disabled", StyleFactory.icon_button_normal(8))

func _ensure_indicator(button: Button) -> void:
	if button.get_node_or_null("Indicator") != null:
		return
	var indicator := ColorRect.new()
	indicator.name = "Indicator"
	indicator.custom_minimum_size = Vector2(20, 3)
	indicator.size = Vector2(20, 3)
	indicator.anchor_left = 0.5
	indicator.anchor_right = 0.5
	indicator.anchor_top = 1.0
	indicator.anchor_bottom = 1.0
	indicator.offset_left = -10
	indicator.offset_right = 10
	indicator.offset_top = -4
	indicator.offset_bottom = -1
	indicator.color = Color.TRANSPARENT
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(indicator)

func _update_indicator(button: Button, task: Dictionary) -> void:
	if button == null:
		return
	_ensure_indicator(button)
	var indicator: ColorRect = button.get_node_or_null("Indicator") as ColorRect
	if indicator == null:
		return
	if bool(task.get("visible", false)):
		indicator.color = Tokens.ACCENT if bool(task.get("active", false)) else Color(Tokens.MUTED.r, Tokens.MUTED.g, Tokens.MUTED.b, 0.45)
	elif bool(task.get("minimized", false)):
		indicator.color = Color(Tokens.MUTED.r, Tokens.MUTED.g, Tokens.MUTED.b, 0.18)
	else:
		indicator.color = Color.TRANSPARENT

func _update_dynamic_taskbar_sizing(tasks: Array) -> void:
	# Dynamic content-driven sizing hook for horizontal compact mode
	# Called after decoration; actual dock width computed in os_shell.gd dock mount
	if root_control == null or _shell == null:
		return
	var task_count: int = tasks.size()
	# Hook for future content-driven adjustments (Start + tasks + gaps)
	# 40 (start) + 8 (divider) + task_count * 40 + task_count * 6 (gaps)
	var estimated_content_width: int = 48 + task_count * 46
	# Store for shell to query if needed
	if _shell.has_method("set_meta"):
		_shell.set_meta("taskbar_estimated_width", estimated_content_width)

func _app_title(app_id: String, window: Node) -> String:
	if _shell != null:
		var apps_value: Variant = _shell.get("_apps")
		if apps_value is Dictionary:
			var apps: Dictionary = apps_value
			if apps.has(app_id) and apps[app_id] is Dictionary:
				var app: Dictionary = apps[app_id]
				return str(app.get("title", app_id))
	var window_title: Variant = window.get("app_title")
	if str(window_title).strip_edges() != "":
		return str(window_title)
	return app_id

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
