class_name WindowManager
extends RefCounted

const OSWindow = preload("res://addons/hermes_os/scripts/os/os_window.gd")
const OSEventBus = preload("res://addons/hermes_os/scripts/os/core/os_event_bus.gd")
const Tokens = preload("res://addons/hermes_os/scripts/os/design_tokens.gd")
const UIAnimator = preload("res://addons/hermes_os/scripts/os/ui_animator.gd")

signal window_opened(window: OSWindow, window_id: int)
signal window_closed(window_id: int, app_id: String)
signal window_focused(window: OSWindow, window_id: int)
signal window_minimized(window: OSWindow, window_id: int)
signal window_restored(window: OSWindow, window_id: int)
signal tiling_changed(enabled: bool, layout: String)
signal window_tiling_changed(window: OSWindow, window_id: int, tiled: bool)

var _window_layer: Control
var _event_bus: OSEventBus
var _windows_by_id: Dictionary = {}
var _window_ids_by_app: Dictionary = {}
var _focused_window_id: int = 0
var _next_window_id: int = 1

const TILE_GAP := 10.0
const TILE_MASTER_RATIO := 0.56

var _tiling_enabled: bool = false
var _tiling_layout: String = "tall"
var _tile_order: Array[int] = []
var _floating_window_ids: Dictionary = {}
var _snap_assist_enabled: bool = true
var _snap_overlay: PanelContainer
var _snap_overlay_grid: GridContainer
var _snap_overlay_window_id: int = 0
var _snap_zone_rects: Dictionary = {}
var _snap_zone_by_window_id: Dictionary = {}

const SNAP_ZONE_LABELS := {
	"full": "Full",
	"left_half": "Left 1/2",
	"right_half": "Right 1/2",
	"top_left": "Top Left",
	"top_right": "Top Right",
	"bottom_left": "Bottom Left",
	"bottom_right": "Bottom Right",
	"left_third": "Left 1/3",
	"center_third": "Center 1/3",
	"right_third": "Right 1/3",
	"top_half": "Top 1/2",
	"bottom_half": "Bottom 1/2"
}

func setup(window_layer: Control, event_bus: OSEventBus) -> void:
	_window_layer = window_layer
	_event_bus = event_bus

func create_window(app_id: StringName, title: String, content: Control, options: Dictionary = {}) -> OSWindow:
	if _window_layer == null:
		push_warning("WindowManager cannot create a window without a window layer")
		return null
	var window_id := _next_window_id
	_next_window_id += 1
	var window := OSWindow.new()
	_window_layer.add_child(window)
	window.setup(str(app_id), title, content)
	window.set_meta("window_id", window_id)
	var size: Vector2 = options.get("size", Vector2(560, 380))
	window.set_window_size(size)
	if options.has("position") and options["position"] is Vector2:
		window.position = options["position"]
	else:
		window.position = _center_window_position(window)
	clamp_window_to_layer(window)
	window.close_requested.connect(_on_window_close_requested)
	window.minimize_requested.connect(_on_window_minimize_requested)
	window.focused.connect(_on_window_focused)
	window.float_requested.connect(_on_window_float_requested)
	window.snap_assist_requested.connect(_on_window_snap_assist_requested)
	window.snap_assist_released.connect(_on_window_snap_assist_released)
	window.snap_assist_cancelled.connect(_on_window_snap_assist_cancelled)
	_windows_by_id[window_id] = window
	_register_window_for_tiling(window_id)
	if not _window_ids_by_app.has(str(app_id)):
		_window_ids_by_app[str(app_id)] = []
	var app_window_ids: Array = _window_ids_by_app[str(app_id)]
	app_window_ids.append(window_id)
	_window_ids_by_app[str(app_id)] = app_window_ids
	if DisplayServer.get_name() != "headless":
		var animator := UIAnimator.new()
		animator.scale_in(window, Tokens.TIME["normal"])
	focus_window(window_id)
	_emit_window_event(OSEventBus.WINDOW_OPENED, window, {"title": title})
	window_opened.emit(window, window_id)
	return window

func close_window(window_id: int) -> void:
	var window := get_window(window_id)
	if window == null:
		return
	var app_id := window.app_id
	var legacy_window_id := _public_window_id(window)
	if not _content_allows_close(window):
		return
	_prepare_window_content_for_close(window)
	if _focused_window_id == window_id:
		_focused_window_id = 0
	_forget_window_tiling_state(window_id)
	_windows_by_id.erase(window_id)
	if _window_ids_by_app.has(app_id):
		var app_window_ids: Array = _window_ids_by_app[app_id]
		app_window_ids.erase(window_id)
		if app_window_ids.is_empty():
			_window_ids_by_app.erase(app_id)
		else:
			_window_ids_by_app[app_id] = app_window_ids
	window.visible = false
	_emit_window_event_by_id(OSEventBus.WINDOW_CLOSED, window_id, app_id, legacy_window_id)
	window_closed.emit(window_id, app_id)
	if app_id == "browser":
		_queue_browser_close_poll(window, Time.get_ticks_msec() + 1800)
	else:
		var tree := window.get_tree()
		if tree == null:
			window.queue_free()
			return
		var close_timer := tree.create_timer(0.12)
		close_timer.timeout.connect(func() -> void:
			if is_instance_valid(window):
				_prepare_window_content_for_close(window)
				window.queue_free()
		)

func focus_window(window_id: int) -> void:
	var window := get_window(window_id)
	if window == null:
		return
	_focused_window_id = window_id
	for id in _windows_by_id.keys():
		var other := _windows_by_id[id] as OSWindow
		if is_instance_valid(other):
			other.set_active(int(id) == window_id)
	window.visible = true
	window.move_to_front()
	_emit_window_event(OSEventBus.WINDOW_FOCUSED, window)
	window_focused.emit(window, window_id)
	reflow_tiled_windows()

func minimize_window(window_id: int) -> void:
	var window := get_window(window_id)
	if window == null:
		return
	if _focused_window_id == window_id:
		_focused_window_id = 0
	window.visible = false
	_emit_window_event(OSEventBus.WINDOW_MINIMIZED, window)
	window_minimized.emit(window, window_id)
	reflow_tiled_windows()

func restore_window(window_id: int) -> void:
	var window := get_window(window_id)
	if window == null:
		return
	window.visible = true
	focus_window(window_id)
	_emit_window_event(OSEventBus.WINDOW_RESTORED, window)
	window_restored.emit(window, window_id)
	reflow_tiled_windows()

func get_window(window_id: int) -> OSWindow:
	var window := _windows_by_id.get(window_id, null) as OSWindow
	if window != null and is_instance_valid(window):
		return window
	return null

func get_window_for_app(app_id: StringName) -> OSWindow:
	var ids := get_window_ids_for_app(app_id)
	if ids.is_empty():
		return null
	return get_window(int(ids[ids.size() - 1]))

func get_window_ids_for_app(app_id: StringName) -> Array[int]:
	var result: Array[int] = []
	var ids_variant: Variant = _window_ids_by_app.get(str(app_id), [])
	if not (ids_variant is Array):
		return result
	for id_variant in ids_variant:
		var window_id := int(id_variant)
		if get_window(window_id) != null:
			result.append(window_id)
	return result

func get_window_id(window: OSWindow) -> int:
	if window == null or not is_instance_valid(window):
		return 0
	return int(window.get_meta("window_id", 0))

func get_windows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in _windows_by_id.keys():
		var window := _windows_by_id[id] as OSWindow
		if not is_instance_valid(window):
			continue
		result.append({
			"window_id": int(id),
			"app_id": window.app_id,
			"title": window.app_title,
			"focused": int(id) == _focused_window_id,
			"visible": window.visible,
			"tiled": is_window_tiled(int(id)),
			"floating": is_window_floating(int(id)),
			"tileable": window.can_tile() if window.has_method("can_tile") else true,
			"tiling_layout": _tiling_layout if is_window_tiled(int(id)) else ""
		})
	return result

func get_open_windows_by_app() -> Dictionary:
	var result: Dictionary = {}
	for app_id in _window_ids_by_app.keys():
		var window := get_window_for_app(StringName(str(app_id)))
		if window != null:
			result[str(app_id)] = window
	return result

func get_focused_window_id() -> int:
	return _focused_window_id

func get_focused_window() -> OSWindow:
	return get_window(_focused_window_id)

func clamp_window_to_layer(window: OSWindow) -> void:
	if _window_layer == null or window == null or not is_instance_valid(window):
		return
	var max_x := maxf(_window_layer.size.x - window.size.x, 0.0)
	var max_y := maxf(_window_layer.size.y - window.size.y, 0.0)
	window.position = Vector2(clampf(window.position.x, 0.0, max_x), clampf(window.position.y, 0.0, max_y))

func clamp_all_windows() -> void:
	if _tiling_enabled:
		reflow_tiled_windows()
		return
	for id in _windows_by_id.keys():
		var window := _windows_by_id[id] as OSWindow
		if is_instance_valid(window) and window.visible:
			clamp_window_to_layer(window)

func close_all(emit_events: bool = false) -> void:
	if emit_events:
		var ids := _windows_by_id.keys().duplicate()
		for id in ids:
			close_window(int(id))
		_windows_by_id.clear()
		_window_ids_by_app.clear()
		_focused_window_id = 0
		return
	for id in _windows_by_id.keys():
		var window := _windows_by_id[id] as OSWindow
		if is_instance_valid(window):
			_prepare_window_content_for_close(window)
			window.queue_free()
	_windows_by_id.clear()
	_window_ids_by_app.clear()
	_tile_order.clear()
	_floating_window_ids.clear()
	_snap_zone_by_window_id.clear()
	_focused_window_id = 0

func set_snap_assist_enabled(enabled: bool) -> void:
	_snap_assist_enabled = enabled
	if not _snap_assist_enabled:
		_hide_snap_overlay()

func is_snap_assist_enabled() -> bool:
	return _snap_assist_enabled

func get_snap_zone_for_window(window_id: int) -> String:
	return str(_snap_zone_by_window_id.get(window_id, ""))

func apply_snap_zone(window_id: int, zone_id: String) -> void:
	var window := get_window(window_id)
	if window == null or not _snap_zone_labels().has(zone_id):
		return
	var rects := _compute_snap_zone_rects(_tile_area())
	if not rects.has(zone_id):
		return
	_floating_window_ids[window_id] = true
	_snap_zone_by_window_id[window_id] = zone_id
	if window.has_method("set_snap_bounds"):
		window.call("set_snap_bounds", zone_id, rects[zone_id])
	focus_window(window_id)
	_hide_snap_overlay()

func snap_focused_window(direction: String) -> void:
	if _focused_window_id <= 0:
		return
	var current := get_snap_zone_for_window(_focused_window_id)
	var next_zone := _next_snap_zone(current, direction)
	if next_zone != "":
		apply_snap_zone(_focused_window_id, next_zone)

func _next_snap_zone(current: String, direction: String) -> String:
	match direction:
		"left":
			match current:
				"top_right": return "top_left"
				"bottom_right": return "bottom_left"
				"right_half": return "left_half"
				"center_third": return "left_third"
				"right_third": return "center_third"
				_: return "left_half"
		"right":
			match current:
				"top_left": return "top_right"
				"bottom_left": return "bottom_right"
				"left_half": return "right_half"
				"left_third": return "center_third"
				"center_third": return "right_third"
				_: return "right_half"
		"down":
			match current:
				"top_right": return "right_half"
				"right_half": return "bottom_right"
				"top_left": return "left_half"
				"left_half": return "bottom_left"
				"top_half": return "full"
				"full": return "bottom_half"
				_: return "bottom_half"
		"up":
			match current:
				"bottom_right": return "right_half"
				"right_half": return "top_right"
				"bottom_left": return "left_half"
				"left_half": return "top_left"
				"bottom_half": return "full"
				"full": return "top_half"
				_: return "top_half"
	return ""

func _snap_zone_labels() -> Dictionary:
	return SNAP_ZONE_LABELS

func _compute_snap_zone_rects(area: Rect2) -> Dictionary:
	var w := area.size.x
	var h := area.size.y
	var x := area.position.x
	var y := area.position.y
	return {
		"full": _inset_rect(Rect2(Vector2(x, y), Vector2(w, h)), TILE_GAP),
		"left_half": _inset_rect(Rect2(Vector2(x, y), Vector2(w * 0.5, h)), TILE_GAP),
		"right_half": _inset_rect(Rect2(Vector2(x + w * 0.5, y), Vector2(w * 0.5, h)), TILE_GAP),
		"top_left": _inset_rect(Rect2(Vector2(x, y), Vector2(w * 0.5, h * 0.5)), TILE_GAP),
		"top_right": _inset_rect(Rect2(Vector2(x + w * 0.5, y), Vector2(w * 0.5, h * 0.5)), TILE_GAP),
		"bottom_left": _inset_rect(Rect2(Vector2(x, y + h * 0.5), Vector2(w * 0.5, h * 0.5)), TILE_GAP),
		"bottom_right": _inset_rect(Rect2(Vector2(x + w * 0.5, y + h * 0.5), Vector2(w * 0.5, h * 0.5)), TILE_GAP),
		"left_third": _inset_rect(Rect2(Vector2(x, y), Vector2(w / 3.0, h)), TILE_GAP),
		"center_third": _inset_rect(Rect2(Vector2(x + w / 3.0, y), Vector2(w / 3.0, h)), TILE_GAP),
		"right_third": _inset_rect(Rect2(Vector2(x + w * 2.0 / 3.0, y), Vector2(w / 3.0, h)), TILE_GAP),
		"top_half": _inset_rect(Rect2(Vector2(x, y), Vector2(w, h * 0.5)), TILE_GAP),
		"bottom_half": _inset_rect(Rect2(Vector2(x, y + h * 0.5), Vector2(w, h * 0.5)), TILE_GAP)
	}

func _show_snap_overlay(window_id: int) -> void:
	if not _snap_assist_enabled or _window_layer == null:
		return
	_ensure_snap_overlay()
	_snap_overlay_window_id = window_id
	_snap_zone_rects = _compute_snap_zone_rects(_tile_area())
	_snap_overlay.size = Vector2(minf(820.0, maxf(_window_layer.size.x - 48.0, 320.0)), 232.0)
	_snap_overlay.position = Vector2(maxf((_window_layer.size.x - _snap_overlay.size.x) * 0.5, 16.0), 18.0)
	_snap_overlay.visible = true
	_snap_overlay.move_to_front()

func _hide_snap_overlay() -> void:
	if _snap_overlay != null:
		_snap_overlay.visible = false
	_snap_overlay_window_id = 0

func _ensure_snap_overlay() -> void:
	if _snap_overlay != null and is_instance_valid(_snap_overlay):
		return
	_snap_overlay = PanelContainer.new()
	_snap_overlay.name = "SnapAssistOverlay"
	_snap_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_snap_overlay.z_index = 500
	_snap_overlay.size = Vector2(820, 232)
	_snap_overlay.add_theme_stylebox_override("panel", _snap_overlay_panel_style())
	var overlay_body := VBoxContainer.new()
	overlay_body.name = "SnapAssistOverlayBody"
	overlay_body.add_theme_constant_override("separation", 10)
	overlay_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_snap_overlay.add_child(overlay_body)
	var title_row := HBoxContainer.new()
	title_row.name = "SnapAssistOverlayHeader"
	title_row.add_theme_constant_override("separation", 10)
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_body.add_child(title_row)
	var title := Label.new()
	title.text = "Snap layout"
	title.add_theme_color_override("font_color", Tokens.TEXT)
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var hint := Label.new()
	hint.text = "Drop the window onto a zone"
	hint.add_theme_color_override("font_color", Tokens.TEXT_MUTED)
	hint.add_theme_font_size_override("font_size", 12)
	title_row.add_child(hint)
	_snap_overlay_grid = GridContainer.new()
	_snap_overlay_grid.columns = 4
	_snap_overlay_grid.add_theme_constant_override("h_separation", 10)
	_snap_overlay_grid.add_theme_constant_override("v_separation", 10)
	_snap_overlay_grid.mouse_filter = Control.MOUSE_FILTER_STOP
	_snap_overlay_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_snap_overlay_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_body.add_child(_snap_overlay_grid)
	_window_layer.add_child(_snap_overlay)
	for zone_id in ["full", "left_half", "right_half", "top_left", "top_right", "bottom_left", "bottom_right", "left_third", "center_third", "right_third", "top_half", "bottom_half"]:
		var button := Button.new()
		button.name = "SnapZone_" + zone_id
		button.text = _snap_zone_button_text(zone_id)
		button.tooltip_text = str(SNAP_ZONE_LABELS.get(zone_id, zone_id))
		button.custom_minimum_size = Vector2(184, 46)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_stylebox_override("normal", _snap_zone_button_style(false))
		button.add_theme_stylebox_override("hover", _snap_zone_button_style(true))
		button.add_theme_stylebox_override("pressed", _snap_zone_button_pressed_style())
		button.add_theme_color_override("font_color", Tokens.TEXT)
		button.add_theme_color_override("font_hover_color", Tokens.TEXT)
		button.add_theme_color_override("font_pressed_color", Tokens.TEXT)
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(func() -> void:
			if _snap_overlay_window_id > 0:
				apply_snap_zone(_snap_overlay_window_id, zone_id)
		)
		_snap_overlay_grid.add_child(button)
	_snap_overlay.visible = false

func _snap_overlay_panel_style() -> StyleBoxFlat:
	var style := StyleFactory.build(Tokens.alpha(Tokens.PANEL, 0.96), Tokens.alpha(Tokens.ACCENT, 0.28), 1, 18)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 18
	return style

func _snap_zone_button_style(hovered: bool) -> StyleBoxFlat:
	var bg := Tokens.alpha(Tokens.ACCENT, 0.14) if hovered else Tokens.alpha(Tokens.SURFACE, 0.94)
	var border := Tokens.alpha(Tokens.ACCENT, 0.42) if hovered else Tokens.alpha(Tokens.BORDER_ACTIVE, 0.42)
	var style := StyleFactory.build(bg, border, 1, 12)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _snap_zone_button_pressed_style() -> StyleBoxFlat:
	var style := StyleFactory.build(Tokens.alpha(Tokens.ACCENT, 0.26), Tokens.alpha(Tokens.ACCENT, 0.68), 1, 12)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _snap_zone_button_text(zone_id: String) -> String:
	return "%s  %s" % [_snap_zone_icon(zone_id), str(SNAP_ZONE_LABELS.get(zone_id, zone_id))]

func _snap_zone_icon(zone_id: String) -> String:
	match zone_id:
		"full": return "▦"
		"left_half": return "◧"
		"right_half": return "◨"
		"top_left": return "◰"
		"top_right": return "◳"
		"bottom_left": return "◱"
		"bottom_right": return "◲"
		"left_third": return "▏"
		"center_third": return "▥"
		"right_third": return "▕"
		"top_half": return "▔"
		"bottom_half": return "▁"
		_: return "□"

func _zone_id_at_overlay_point(point: Vector2) -> String:
	if _snap_overlay_grid == null or not _snap_overlay.visible:
		return ""
	var global_point := _window_layer.global_position + point if _window_layer != null else point
	for child in _snap_overlay_grid.get_children():
		if child is Control and (child as Control).get_global_rect().has_point(global_point):
			var name_text := str(child.name)
			if name_text.begins_with("SnapZone_"):
				return name_text.trim_prefix("SnapZone_")
	return ""

func _on_window_snap_assist_requested(window: OSWindow, _local_mouse: Vector2) -> void:
	_show_snap_overlay(get_window_id(window))

func _on_window_snap_assist_released(window: OSWindow, local_mouse: Vector2) -> void:
	var window_id := get_window_id(window)
	var zone_id := _zone_id_at_overlay_point(local_mouse)
	if zone_id == "" and _snap_overlay != null and _snap_overlay.visible:
		zone_id = "full"
	if zone_id != "":
		apply_snap_zone(window_id, zone_id)
	else:
		_hide_snap_overlay()

func _on_window_snap_assist_cancelled(_window: OSWindow) -> void:
	_hide_snap_overlay()

func is_tiling_enabled() -> bool:
	return _tiling_enabled

func get_tiling_layout() -> String:
	return _tiling_layout

func is_window_tiled(window_id: int) -> bool:
	var window := get_window(window_id)
	if window == null or not window.has_method("is_tiled"):
		return false
	return bool(window.call("is_tiled"))

func is_window_floating(window_id: int) -> bool:
	return _floating_window_ids.has(window_id) or not is_window_tiled(window_id)

func get_tiling_state() -> Dictionary:
	return {
		"enabled": _tiling_enabled,
		"layout": _tiling_layout,
		"tile_order": _tile_order.duplicate(),
		"tiled_window_ids": _visible_tileable_window_ids(),
		"floating_window_ids": _floating_window_ids.keys()
	}

func set_tiling_enabled(enabled: bool) -> void:
	if _tiling_enabled == enabled:
		if enabled:
			reflow_tiled_windows()
		return
	_tiling_enabled = enabled
	if _tiling_enabled:
		reflow_tiled_windows()
	else:
		_restore_all_tiled_windows()
	tiling_changed.emit(_tiling_enabled, _tiling_layout)

func toggle_tiling() -> bool:
	set_tiling_enabled(not _tiling_enabled)
	return _tiling_enabled

func set_tiling_layout(layout: String) -> void:
	var clean := layout.strip_edges().to_lower()
	if clean == "":
		clean = "tall"
	if clean != "tall":
		push_warning("Unsupported tiling layout: %s" % layout)
		return
	_tiling_layout = clean
	reflow_tiled_windows()
	tiling_changed.emit(_tiling_enabled, _tiling_layout)

func tile_window(window_id: int) -> void:
	var window := get_window(window_id)
	if window == null:
		return
	_register_window_for_tiling(window_id)
	_floating_window_ids.erase(window_id)
	_snap_zone_by_window_id.erase(window_id)
	reflow_tiled_windows()
	window_tiling_changed.emit(window, window_id, is_window_tiled(window_id))

func float_window(window_id: int) -> void:
	var window := get_window(window_id)
	if window == null:
		return
	_floating_window_ids[window_id] = true
	if window.has_method("restore_from_tiling"):
		window.call("restore_from_tiling")
	window_tiling_changed.emit(window, window_id, false)
	reflow_tiled_windows()

func focus_next_tiled_window(direction: int = 1) -> void:
	var ids := _visible_tileable_window_ids()
	if ids.is_empty():
		return
	var current_index := ids.find(_focused_window_id)
	if current_index < 0:
		current_index = 0
	else:
		current_index = wrapi(current_index + direction, 0, ids.size())
	focus_window(int(ids[current_index]))

func toggle_focused_window_floating() -> void:
	if _focused_window_id <= 0:
		return
	if _floating_window_ids.has(_focused_window_id) or not is_window_tiled(_focused_window_id):
		tile_window(_focused_window_id)
	else:
		float_window(_focused_window_id)

func reflow_tiled_windows() -> void:
	if not _tiling_enabled or _window_layer == null:
		return
	var ids := _visible_tileable_window_ids()
	var rects := _compute_tall_layout(ids, _tile_area())
	for id in ids:
		var window := get_window(id)
		if window == null or not rects.has(id):
			continue
		if window.has_method("set_tiled_bounds"):
			window.call("set_tiled_bounds", rects[id])
		window_tiling_changed.emit(window, id, true)

func _register_window_for_tiling(window_id: int) -> void:
	if not _tile_order.has(window_id):
		_tile_order.append(window_id)

func _forget_window_tiling_state(window_id: int) -> void:
	_tile_order.erase(window_id)
	_floating_window_ids.erase(window_id)

func _visible_tileable_window_ids() -> Array[int]:
	var result: Array[int] = []
	for id in _tile_order:
		var window := get_window(int(id))
		if window == null or not window.visible:
			continue
		if _floating_window_ids.has(int(id)):
			continue
		if window.has_method("can_tile") and not bool(window.call("can_tile")):
			continue
		result.append(int(id))
	return result

func _restore_all_tiled_windows() -> void:
	for id in _tile_order:
		var window := get_window(int(id))
		if window != null and window.has_method("restore_from_tiling"):
			window.call("restore_from_tiling")
			window_tiling_changed.emit(window, int(id), false)

func _tile_area() -> Rect2:
	if _window_layer == null:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	return Rect2(Vector2.ZERO, _window_layer.size)

func _compute_tall_layout(ids: Array[int], area: Rect2) -> Dictionary:
	var rects: Dictionary = {}
	var count := ids.size()
	if count <= 0:
		return rects
	if count == 1:
		rects[ids[0]] = _inset_rect(area, TILE_GAP)
		return rects
	if count == 2:
		var half_width := area.size.x * 0.5
		rects[ids[0]] = _inset_rect(Rect2(area.position, Vector2(half_width, area.size.y)), TILE_GAP)
		rects[ids[1]] = _inset_rect(Rect2(area.position + Vector2(half_width, 0), Vector2(area.size.x - half_width, area.size.y)), TILE_GAP)
		return rects
	var master_index := ids.find(_focused_window_id)
	if master_index < 0:
		master_index = 0
	var ordered := ids.duplicate()
	var master_id := int(ordered[master_index])
	ordered.remove_at(master_index)
	var master_width := area.size.x * TILE_MASTER_RATIO
	rects[master_id] = _inset_rect(Rect2(area.position, Vector2(master_width, area.size.y)), TILE_GAP)
	var stack_count := ordered.size()
	var stack_width := area.size.x - master_width
	var stack_height := area.size.y / float(stack_count)
	for index in range(stack_count):
		var id := int(ordered[index])
		rects[id] = _inset_rect(Rect2(area.position + Vector2(master_width, stack_height * index), Vector2(stack_width, stack_height)), TILE_GAP)
	return rects

func _inset_rect(rect: Rect2, gap: float) -> Rect2:
	var half_gap := gap * 0.5
	var pos := rect.position + Vector2(half_gap, half_gap)
	var size_value := rect.size - Vector2(gap, gap)
	return Rect2(pos, Vector2(maxf(size_value.x, 1.0), maxf(size_value.y, 1.0)))

func _center_window_position(window: OSWindow) -> Vector2:
	if _window_layer == null:
		return Vector2.ZERO
	return Vector2(maxf((_window_layer.size.x - window.size.x) * 0.5, 0.0), maxf((_window_layer.size.y - window.size.y) * 0.5, 0.0))

func _on_window_close_requested(window: OSWindow) -> void:
	close_window(get_window_id(window))

func _on_window_minimize_requested(window: OSWindow) -> void:
	minimize_window(get_window_id(window))

func _on_window_focused(window: OSWindow) -> void:
	focus_window(get_window_id(window))

func _on_window_float_requested(window: OSWindow) -> void:
	var window_id := get_window_id(window)
	float_window(window_id)
	_snap_zone_by_window_id.erase(window_id)

func _emit_window_event(event_name: StringName, window: OSWindow, extra: Dictionary = {}) -> void:
	if _event_bus == null or window == null:
		return
	var manager_window_id := get_window_id(window)
	var payload := extra.duplicate(true)
	payload["window_id"] = _public_window_id(window)
	payload["manager_window_id"] = manager_window_id
	payload["app_id"] = window.app_id
	_event_bus.emit_event(event_name, payload)

func _emit_window_event_by_id(event_name: StringName, manager_window_id: int, app_id: String, legacy_window_id: String = "") -> void:
	if _event_bus != null:
		_event_bus.emit_event(event_name, {"window_id": legacy_window_id if legacy_window_id != "" else str(manager_window_id), "manager_window_id": manager_window_id, "app_id": app_id})

func _public_window_id(window: OSWindow) -> String:
	if window == null or not is_instance_valid(window):
		return ""
	return "win_%s" % str(window.get_instance_id())

func _queue_browser_close_poll(window: OSWindow, deadline_msec: int) -> void:
	if window == null or not is_instance_valid(window):
		return
	var tree := window.get_tree()
	if tree == null:
		window.queue_free()
		return
	var poll := tree.create_timer(0.05)
	poll.timeout.connect(func() -> void:
		if not is_instance_valid(window):
			return
		_prepare_window_content_for_close(window)
		if _window_content_ready_for_close(window) or Time.get_ticks_msec() >= deadline_msec:
			window.queue_free()
		else:
			_queue_browser_close_poll(window, deadline_msec)
	)

func _window_content_ready_for_close(root: Node) -> bool:
	if root == null or not is_instance_valid(root):
		return true
	var ready := true
	if root.has_method("is_native_teardown_complete"):
		ready = bool(root.call("is_native_teardown_complete"))
	for child in root.get_children():
		ready = ready and _window_content_ready_for_close(child)
	return ready

func _content_allows_close(root: Node) -> bool:
	if root == null or not is_instance_valid(root):
		return true
	if root.has_method("os_app_close_requested"):
		var result: Variant = root.call("os_app_close_requested")
		if result is bool and not bool(result):
			return false
	for child in root.get_children():
		if not _content_allows_close(child):
			return false
	return true

func _prepare_window_content_for_close(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	if root.has_method("prepare_for_close"):
		root.call("prepare_for_close")
	for child in root.get_children():
		_prepare_window_content_for_close(child)
