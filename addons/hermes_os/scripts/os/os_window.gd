class_name OSWindow
extends Panel

signal close_requested(window: OSWindow)
signal minimize_requested(window: OSWindow)
signal focused(window: OSWindow)
signal float_requested(window: OSWindow)
signal snap_assist_requested(window: OSWindow, local_mouse: Vector2)
signal snap_assist_released(window: OSWindow, local_mouse: Vector2)
signal snap_assist_cancelled(window: OSWindow)

var app_id: String = ""
var app_title: String = ""

var _title_bar: Panel
var _title_label: Label
var _body_host: MarginContainer
var _maximize_button: Button
var _resize_handle: ColorRect

var _dragging: bool = false
var _resizing: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _resize_start_mouse: Vector2 = Vector2.ZERO
var _resize_start_size: Vector2 = Vector2.ZERO
var _restore_position: Vector2 = Vector2.ZERO
var _restore_size: Vector2 = Vector2.ZERO
var _maximized: bool = false
var _minimum_window_size: Vector2 = Vector2.ZERO
var _snapped: bool = false
var _snap_direction: String = ""
var _snap_restore_position: Vector2 = Vector2.ZERO
var _snap_restore_size: Vector2 = Vector2.ZERO
var _tiled: bool = false
var _tile_restore_position: Vector2 = Vector2.ZERO
var _tile_restore_size: Vector2 = Vector2.ZERO
var _has_tile_restore_bounds: bool = false
var _floating_custom_minimum_size: Vector2 = Vector2.ZERO
var _pending_tiled_rect: Rect2 = Rect2()
var _tile_rect_reapply_queued: bool = false
var _snap_zone_id: String = ""

const MIN_SIZE := Vector2(420, 280)
const SNAP_THRESHOLD := 16.0
const TITLE_HEIGHT := 42.0

const Tokens = preload("res://addons/hermes_os/scripts/os/design_tokens.gd")
const StyleFactory = preload("res://addons/hermes_os/scripts/os/style_factory.gd")
const UIAnimator = preload("res://addons/hermes_os/scripts/os/ui_animator.gd")

func setup(id: String, title: String, content: Control) -> void:
	app_id = id
	app_title = title
	name = "Window_%s" % id
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build(content)
	_minimum_window_size = _calculate_minimum_window_size(content)
	custom_minimum_size = _minimum_window_size
	size = _minimum_window_size
	var animator := UIAnimator.new()
	animator.window_open(self, Tokens.TIME["normal"])
	set_active(false)

func minimum_window_size() -> Vector2:
	return _minimum_window_size if _minimum_window_size != Vector2.ZERO else MIN_SIZE

func set_window_size(requested_size: Vector2) -> void:
	var min_size := minimum_window_size()
	size = Vector2(maxf(requested_size.x, min_size.x), maxf(requested_size.y, min_size.y))

func is_tiled() -> bool:
	return _tiled

func is_floating() -> bool:
	return not _tiled

func can_tile() -> bool:
	return true

func set_snap_bounds(zone_id: String, rect: Rect2) -> void:
	_save_snap_state()
	_tiled = false
	_maximized = false
	_snapped = true
	_snap_direction = zone_id
	_snap_zone_id = zone_id
	custom_minimum_size = Vector2.ZERO
	position = rect.position
	size = rect.size
	if _maximize_button:
		_maximize_button.text = "□"
	if _resize_handle:
		_resize_handle.visible = false

func get_snap_zone_id() -> String:
	return _snap_zone_id

func restore_from_snap() -> void:
	if _snapped:
		position = _snap_restore_position
		set_window_size(_snap_restore_size)
	_snapped = false
	_snap_direction = ""
	_snap_zone_id = ""
	custom_minimum_size = _minimum_window_size
	if _resize_handle and not _maximized:
		_resize_handle.visible = true

func set_tiled_bounds(rect: Rect2) -> void:
	if not _tiled:
		_tile_restore_position = position
		_tile_restore_size = size
		_floating_custom_minimum_size = custom_minimum_size
		_has_tile_restore_bounds = true
	_tiled = true
	custom_minimum_size = Vector2.ZERO
	_maximized = false
	_snapped = false
	_snap_direction = ""
	_snap_zone_id = ""
	_pending_tiled_rect = rect
	_apply_tiled_rect(rect)
	_queue_tiled_rect_reapply()
	if _maximize_button:
		_maximize_button.text = "□"
	if _resize_handle:
		_resize_handle.visible = false

func _apply_tiled_rect(rect: Rect2) -> void:
	position = rect.position
	size = rect.size

func _queue_tiled_rect_reapply() -> void:
	if _tile_rect_reapply_queued or not is_inside_tree():
		return
	_tile_rect_reapply_queued = true
	var tree := get_tree()
	if tree == null:
		_tile_rect_reapply_queued = false
		return
	var timer := tree.create_timer(0.18)
	timer.timeout.connect(func() -> void:
		_tile_rect_reapply_queued = false
		if _tiled and is_instance_valid(self):
			_apply_tiled_rect(_pending_tiled_rect)
	)

func restore_from_tiling() -> void:
	if _has_tile_restore_bounds:
		custom_minimum_size = _floating_custom_minimum_size
		position = _tile_restore_position
		set_window_size(_tile_restore_size)
	else:
		custom_minimum_size = _minimum_window_size
	_tiled = false
	_tile_rect_reapply_queued = false
	_snap_zone_id = ""
	if _resize_handle and not _maximized:
		_resize_handle.visible = true

func mark_floating_from_user_action() -> void:
	if not _tiled:
		return
	float_requested.emit(self)
	if _tiled:
		restore_from_tiling()

func set_active(active: bool) -> void:
	var border: Color = Tokens.BORDER_ACTIVE if active else Tokens.BORDER
	add_theme_stylebox_override("panel", _window_style(border, active))
	if _title_bar:
				_title_bar.add_theme_stylebox_override("panel", StyleFactory.title_bar(active, 12))
	if _title_label:
		_title_label.add_theme_color_override("font_color", Tokens.TEXT if active else Tokens.TEXT_MUTED)

func set_app_title(title: String) -> void:
	app_title = title.strip_edges()
	if app_title == "":
		app_title = "App"
	if _title_label:
		_title_label.text = app_title

func toggle_maximize() -> void:
	if _tiled:
		mark_floating_from_user_action()
		return
	var parent_control := get_parent() as Control
	if parent_control == null:
		return

	_snapped = false
	_snap_direction = ""

	if _maximized:
		position = _restore_position
		set_window_size(_restore_size)
		_maximized = false
		_maximize_button.text = "□"
		_resize_handle.visible = true
	else:
		_restore_position = position
		_restore_size = size
		position = Vector2.ZERO
		size = parent_control.size
		_maximized = true
		_maximize_button.text = "❐"
		_resize_handle.visible = false

func _build(content: Control) -> void:
	var frame := VBoxContainer.new()
	frame.name = "Frame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 1
	frame.offset_top = 1
	frame.offset_right = -1
	frame.offset_bottom = -1
	frame.clip_contents = true
	frame.add_theme_constant_override("separation", 0)
	add_child(frame)

	_title_bar = Panel.new()
	_title_bar.name = "TitleBar"
	_title_bar.custom_minimum_size = Vector2(0, TITLE_HEIGHT)
	_title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_bar.gui_input.connect(_on_title_bar_gui_input)
	frame.add_child(_title_bar)

	var title_row := HBoxContainer.new()
	title_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_row.offset_left = 14
	title_row.offset_right = -10
	title_row.offset_top = 7
	title_row.offset_bottom = -7
	title_row.add_theme_constant_override("separation", 4)
	_title_bar.add_child(title_row)

	_title_label = Label.new()
	_title_label.text = app_title
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.add_theme_color_override("font_color", Tokens.TEXT)
	title_row.add_child(_title_label)

	var minimize_button := _title_button("−", false)
	minimize_button.tooltip_text = "Minimize"
	minimize_button.pressed.connect(func() -> void: minimize_requested.emit(self))
	title_row.add_child(minimize_button)

	var maximize_button := _title_button("□", false)
	_maximize_button = maximize_button
	maximize_button.tooltip_text = "Maximize / restore"
	maximize_button.pressed.connect(toggle_maximize)
	title_row.add_child(maximize_button)

	var close_button := _title_button("×", true)
	close_button.tooltip_text = "Close"
	close_button.pressed.connect(func() -> void: close_requested.emit(self))
	title_row.add_child(close_button)

	_body_host = MarginContainer.new()
	_body_host.name = "Body"
	_body_host.clip_contents = true
	_body_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_host.add_theme_constant_override("margin_left", 10)
	_body_host.add_theme_constant_override("margin_right", 10)
	_body_host.add_theme_constant_override("margin_top", 10)
	_body_host.add_theme_constant_override("margin_bottom", 10)
	frame.add_child(_body_host)

	var body_panel := PanelContainer.new()
	body_panel.name = "BodyPanel"
	body_panel.clip_contents = true
	body_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_panel.add_theme_stylebox_override("panel", _body_style())
	_body_host.add_child(body_panel)
	body_panel.add_child(content)

	_minimum_window_size = _calculate_minimum_window_size(content)
	custom_minimum_size = _minimum_window_size

	_resize_handle = ColorRect.new()
	_resize_handle.name = "ResizeHandle"
	_resize_handle.color = Color("6e7889")
	_resize_handle.anchor_left = 1.0
	_resize_handle.anchor_top = 1.0
	_resize_handle.anchor_right = 1.0
	_resize_handle.anchor_bottom = 1.0
	_resize_handle.offset_left = -12
	_resize_handle.offset_top = -12
	_resize_handle.offset_right = -4
	_resize_handle.offset_bottom = -4
	_resize_handle.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	_resize_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	_resize_handle.gui_input.connect(_on_resize_handle_gui_input)
	add_child(_resize_handle)

func _title_button(text_value: String, destructive := false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(30, 30)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Tokens.TEXT)
	button.add_theme_stylebox_override("normal", StyleFactory.window_control(text_value, destructive, "normal"))
	button.add_theme_stylebox_override("hover", StyleFactory.window_control(text_value, destructive, "hover"))
	button.add_theme_stylebox_override("pressed", StyleFactory.window_control(text_value, destructive, "pressed"))
	button.add_theme_stylebox_override("focus", StyleFactory.window_control(text_value, destructive, "focused"))
	return button

func _on_title_bar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			toggle_maximize()
			return
		if event.pressed:
			if _tiled:
				mark_floating_from_user_action()
			_dragging = true
			_drag_offset = get_global_mouse_position() - global_position
			if _snapped:
				_unsnap_for_drag()
			focused.emit(self)
			move_to_front()
		else:
			if _dragging:
				_dragging = false
				var parent_control := get_parent() as Control
				if parent_control:
					var local_mouse := get_global_mouse_position() - parent_control.global_position
					snap_assist_released.emit(self, local_mouse)
	elif event is InputEventMouseMotion and _dragging and not _maximized:
		var parent_control := get_parent() as Control
		var target := get_global_mouse_position() - _drag_offset
		if parent_control:
			var local_target := target - parent_control.global_position
			var max_x: float = maxf(parent_control.size.x - 80.0, 0.0)
			var max_y: float = maxf(parent_control.size.y - TITLE_HEIGHT, 0.0)
			position = Vector2(clampf(local_target.x, 0.0, max_x), clampf(local_target.y, 0.0, max_y))
			var local_mouse := get_global_mouse_position() - parent_control.global_position
			if local_mouse.y < SNAP_THRESHOLD:
				snap_assist_requested.emit(self, local_mouse)
		else:
			global_position = target

func _on_resize_handle_gui_input(event: InputEvent) -> void:
	if _maximized:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _tiled:
				mark_floating_from_user_action()
			_resizing = true
			_resize_start_mouse = get_global_mouse_position()
			_resize_start_size = size
			focused.emit(self)
		else:
			_resizing = false
	elif event is InputEventMouseMotion and _resizing:
		var delta := get_global_mouse_position() - _resize_start_mouse
		var target_size := _resize_start_size + delta
		var parent_control := get_parent() as Control
		var max_size := Vector2(4096, 4096)
		if parent_control:
			max_size = parent_control.size - position
		var min_size := minimum_window_size()
		max_size = Vector2(maxf(max_size.x, min_size.x), maxf(max_size.y, min_size.y))
		size = Vector2(
			clampf(target_size.x, min_size.x, max_size.x),
			clampf(target_size.y, min_size.y, max_size.y)
		)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _should_focus_from_pointer(event.position):
			focused.emit(self)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		focused.emit(self)

func _should_focus_from_pointer(viewport_position: Vector2) -> bool:
	if not visible or not is_inside_tree():
		return false
	if not Rect2(global_position, size).has_point(viewport_position):
		return false
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered != null and hovered != self and not is_ancestor_of(hovered):
		return false
	var parent_control := get_parent() as Control
	if parent_control == null:
		return true
	var siblings := parent_control.get_children()
	for index in range(siblings.size() - 1, -1, -1):
		var sibling := siblings[index]
		if sibling == self:
			return true
		if sibling is OSWindow:
			var other := sibling as OSWindow
			if other.visible and Rect2(other.global_position, other.size).has_point(viewport_position):
				return false
	return true

func _calculate_minimum_window_size(content: Control) -> Vector2:
	if content.has_meta("window_min_size"):
		var override_value: Variant = content.get_meta("window_min_size")
		if override_value is Vector2:
			return override_value
	var content_min := content.get_combined_minimum_size()
	var margin_width := 64.0
	var margin_height := 64.0
	var title_width := 260.0
	var base_min := _base_minimum_size(content)
	return Vector2(
		maxf(base_min.x, maxf(content_min.x + margin_width, title_width)),
		maxf(base_min.y, TITLE_HEIGHT + content_min.y + margin_height)
	)

func _base_minimum_size(content: Control) -> Vector2:
	if content.has_meta("window_min_size"):
		var value: Variant = content.get_meta("window_min_size")
		if value is Vector2:
			return value
	return MIN_SIZE

func _unsnap_for_drag() -> void:
	snap_assist_cancelled.emit(self)
	_snapped = false
	_snap_direction = ""
	_snap_zone_id = ""
	custom_minimum_size = _minimum_window_size
	var mouse_global := get_global_mouse_position()
	var new_pos := mouse_global - _snap_restore_size / 2.0
	var parent_control := get_parent() as Control
	if parent_control:
		new_pos -= parent_control.global_position
		new_pos.x = clampf(new_pos.x, 0.0, maxf(parent_control.size.x - _snap_restore_size.x, 0.0))
		new_pos.y = clampf(new_pos.y, 0.0, maxf(parent_control.size.y - _snap_restore_size.y, 0.0))
	position = new_pos
	size = _snap_restore_size
	_drag_offset = _snap_restore_size / 2.0

func _try_snap(local_mouse: Vector2, parent_size: Vector2) -> void:
	if local_mouse.y < SNAP_THRESHOLD:
		_snap_maximize()
	elif local_mouse.x < SNAP_THRESHOLD:
		_snap_left(parent_size)
	elif local_mouse.x > parent_size.x - SNAP_THRESHOLD:
		_snap_right(parent_size)

func _save_snap_state() -> void:
	if not _snapped:
		_snap_restore_position = position
		_snap_restore_size = size

func _snap_maximize() -> void:
	toggle_maximize()

func _snap_left(parent_size: Vector2) -> void:
	if _maximized:
		toggle_maximize()
	_save_snap_state()
	_snapped = true
	_snap_direction = "left"
	position = Vector2.ZERO
	size = Vector2(parent_size.x / 2.0, parent_size.y)

func _snap_right(parent_size: Vector2) -> void:
	if _maximized:
		toggle_maximize()
	_save_snap_state()
	_snapped = true
	_snap_direction = "right"
	position = Vector2(parent_size.x / 2.0, 0.0)
	size = Vector2(parent_size.x / 2.0, parent_size.y)

func _window_style(border: Color, active: bool) -> StyleBoxFlat:
	if active:
		return StyleFactory.window_active(12)
	return StyleFactory.window_inactive(12)

func _body_style() -> StyleBoxFlat:
	return StyleFactory.body_panel(true, 12)

func _button_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	return StyleFactory.build(bg, border, border_width, 6)

func _style(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	return StyleFactory.build(bg, border, border_width, radius)

func _style_corners(bg: Color, border: Color, border_width: int, top_left: int, top_right: int, bottom_left: int, bottom_right: int) -> StyleBoxFlat:
	var style := StyleFactory.build(bg, border, border_width, top_left)
	style.corner_radius_top_left = top_left
	style.corner_radius_top_right = top_right
	style.corner_radius_bottom_left = bottom_left
	style.corner_radius_bottom_right = bottom_right
	return style
