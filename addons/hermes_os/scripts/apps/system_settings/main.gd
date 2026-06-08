extends "res://addons/hermes_os/scripts/ui/hermes_ui/runtime/hermes_app_controller.gd"

const OSFileSystem = preload("res://addons/hermes_os/scripts/os/os_file_system.gd")
const GATEWAY_TEST_TIMEOUT_MS := 900
const MCP_TEST_TIMEOUT_MS := 700
const WALLPAPER_DIR := "res://addons/hermes_os/assets/wallpapers"

var _shell: Node
var _fs: Object
var _selected_wallpaper_index: int = 0
var _wallpaper_files: Array[String] = []
var _wallpaper_tiles: Array[PanelContainer] = []
var _accent_picker: ColorPicker
var _accent_preset_buttons: Array[Button] = []

func _app_ready() -> void:
	_shell = os.context.get("shell", null) as Node if os != null else null
	_fs = os.context.get("filesystem", null) as Object if os != null else null
	if _fs == null and _shell != null:
		_fs = _shell.get("_fs") as Object
	_initialize_state()
	refresh_settings()
	_build_accent_controls()
	_build_wallpaper_grid()

func refresh_settings() -> void:
	_refresh_page_visibility()
	_refresh_gateway_mcp_status()
	_refresh_appearance_state()
	_refresh_system_info()

func get_settings_state() -> Dictionary:
	if state == null:
		return {}
	return {
		"theme_mode": _theme_mode(),
		"wallpaper_index": _wallpaper_index(),
		"desktop_highlight_color": [_desktop_highlight_color().r, _desktop_highlight_color().g, _desktop_highlight_color().b, _desktop_highlight_color().a],
		"gateway": _gateway_state(),
		"mcp": _mcp_state(),
		"active_tab": state.get_string("active_tab", "system"),
		"snap_assist_enabled": _snap_assist_enabled()
	}

func restore_settings_state(saved_state: Dictionary) -> void:
	if state == null:
		return
	var active: String = str(saved_state.get("active_tab", state.get_string("active_tab", "system")))
	if active != "system" and active != "appearance" and active != "window_management":
		active = "system"
	state.set("active_tab", active)
	_refresh_page_visibility()
	refresh_settings()

func select_section(event) -> void:
	if state == null:
		return
	var selected_id: String = str(event.value if event != null else "")
	if selected_id != "system" and selected_id != "appearance" and selected_id != "window_management":
		return
	state.set("active_tab", selected_id)
	_refresh_page_visibility()
	_refresh_system_info()

func snap_assist_changed(event) -> void:
	var enabled: bool = bool(event.value if event != null else true)
	if _shell != null and _shell.has_method("set_snap_assist_enabled"):
		_shell.call("set_snap_assist_enabled", enabled)
	if state != null:
		state.set("snap_assist_enabled", enabled)
	_set_status("Snap Assist enabled" if enabled else "Snap Assist disabled", false)
	_refresh_system_info()

func theme_mode_changed(event) -> void:
	var selected_id: String = str(event.value if event != null else "")
	if selected_id != "dark" and selected_id != "light":
		return
	_apply_theme_mode(selected_id, true)
	if state != null:
		state.set("theme_mode", _theme_mode())
	_set_desktop_context_status("Light mode enabled" if _theme_mode() == "light" else "Dark mode enabled")
	_refresh_system_info()

func highlight_preset_changed(event) -> void:
	var selected_label: String = str(event.value if event != null else "")
	for preset in _desktop_highlight_presets():
		if str(preset.get("label", "")) == selected_label:
			var color: Color = preset.get("color", _desktop_highlight_color())
			var current: Color = _desktop_highlight_color()
			_set_desktop_highlight_color(Color(color.r, color.g, color.b, current.a))
			_update_system_accent(color)
			_set_desktop_context_status("Desktop highlight color updated")
			_refresh_appearance_state()
			_refresh_system_info()
			return

func highlight_alpha_changed(event) -> void:
	var value: float = str(event.value if event != null else _desktop_highlight_color().a).to_float()
	var current: Color = _desktop_highlight_color()
	_set_desktop_highlight_color(Color(current.r, current.g, current.b, value))
	_refresh_appearance_state()

func cycle_wallpaper(_event = null) -> void:
	_cycle_wallpaper()
	_set_status("Wallpaper cycled", false)
	_refresh_system_info()

func set_wallpaper(event) -> void:
	var idx: int = 0
	if event != null:
		idx = int(str(event.value))
	_select_wallpaper_index(idx)

func _scan_wallpaper_files() -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(WALLPAPER_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var ext: String = file_name.get_extension().to_lower()
			if ext in ["jpg", "jpeg", "png", "webp"]:
				result.append(WALLPAPER_DIR.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result

func _select_wallpaper_index(idx: int) -> void:
	if _wallpaper_files.is_empty():
		_wallpaper_files = _scan_wallpaper_files()
	if idx < 0 or idx >= _wallpaper_files.size():
		_set_status("Wallpaper selection unavailable", true)
		return
	_selected_wallpaper_index = idx
	if _shell != null:
		if _shell.has_method("_set_wallpaper_image"):
			_shell.call("_set_wallpaper_image", _wallpaper_files[idx])
		else:
			_shell.set("_current_wallpaper_image", _wallpaper_files[idx])
			if _shell.has_method("_apply_wallpaper"):
				_shell.call("_apply_wallpaper")
	_refresh_wallpaper_grid_selection()
	_refresh_accent_controls()
	_set_status("Wallpaper updated", false)
	_refresh_system_info()

func _build_wallpaper_grid() -> void:
	if root_control == null:
		return
	var grid: Control = _find_control_by_hermes_id(root_control, "WallpaperGrid")
	if grid == null:
		call_deferred("_build_wallpaper_grid")
		return
	for child in grid.get_children():
		child.queue_free()
	_wallpaper_tiles.clear()
	_wallpaper_files = _scan_wallpaper_files()
	if _shell != null:
		var current_path: String = str(_shell.get("_current_wallpaper_image"))
		var current_index: int = _wallpaper_files.find(current_path)
		if current_index >= 0:
			_selected_wallpaper_index = current_index
	for i in range(_wallpaper_files.size()):
		var tile := PanelContainer.new()
		tile.name = "WallpaperTile%d" % i
		tile.custom_minimum_size = Vector2(150, 84)
		tile.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var button := TextureButton.new()
		button.name = "WallpaperPreview%d" % i
		button.custom_minimum_size = Vector2(142, 76)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
		button.ignore_texture_size = true
		button.tooltip_text = _wallpaper_files[i].get_file().get_basename()
		button.focus_mode = Control.FOCUS_ALL
		var tex: Texture2D = load(_wallpaper_files[i]) as Texture2D
		if tex != null:
			button.texture_normal = tex
			button.texture_hover = tex
			button.texture_pressed = tex
			button.texture_focused = tex
		button.pressed.connect(_select_wallpaper_index.bind(i))
		tile.add_child(button)
		grid.add_child(tile)
		_wallpaper_tiles.append(tile)
	_refresh_wallpaper_grid_selection()
	_refresh_accent_controls()

func _refresh_wallpaper_grid_selection() -> void:
	var index: int = 0
	for tile in _wallpaper_tiles:
		if tile == null:
			index += 1
			continue
		var selected: bool = index == _selected_wallpaper_index
		tile.add_theme_stylebox_override("panel", _wallpaper_tile_style(selected))
		index += 1

func _wallpaper_tile_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.content_margin_left = 4
	style.content_margin_top = 4
	style.content_margin_right = 4
	style.content_margin_bottom = 4
	if selected:
		var accent: Color = _desktop_highlight_color()
		style.border_color = Color(accent.r, accent.g, accent.b, maxf(accent.a, 0.72))
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
	else:
		style.border_color = Color.TRANSPARENT
	return style

func _find_control_by_hermes_id(root: Node, target_id: String) -> Control:
	if root == null:
		return null
	if root is Control and root.has_meta("hermes_id") and str(root.get_meta("hermes_id")) == target_id:
		return root as Control
	for child in root.get_children():
		var found: Control = _find_control_by_hermes_id(child, target_id)
		if found != null:
			return found
	return null

func _build_accent_controls() -> void:
	if root_control == null:
		return
	var picker_host: Control = _find_control_by_hermes_id(root_control, "AccentColorPickerHost")
	var preset_grid: Control = _find_control_by_hermes_id(root_control, "AccentPresetGrid")
	if picker_host == null or preset_grid == null:
		call_deferred("_build_accent_controls")
		return
	for child in picker_host.get_children():
		child.queue_free()
	for child in preset_grid.get_children():
		child.queue_free()
	_accent_preset_buttons.clear()
	_accent_picker = ColorPicker.new()
	_accent_picker.name = "AccentColorPicker"
	_accent_picker.custom_minimum_size = Vector2(320, 220)
	_accent_picker.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_accent_picker.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_accent_picker.edit_alpha = false
	_accent_picker.color = Color(_desktop_highlight_color().r, _desktop_highlight_color().g, _desktop_highlight_color().b, 1.0)
	_accent_picker.color_changed.connect(_accent_color_changed)
	picker_host.add_child(_accent_picker)
	for preset in _desktop_highlight_presets():
		var button := Button.new()
		button.text = ""
		button.tooltip_text = str(preset.get("label", "Preset"))
		button.custom_minimum_size = Vector2(34, 34)
		button.focus_mode = Control.FOCUS_ALL
		var preset_color: Color = preset.get("color", Color.WHITE)
		button.pressed.connect(_apply_accent_color.bind(preset_color, str(preset.get("label", "Preset"))))
		preset_grid.add_child(button)
		_accent_preset_buttons.append(button)
	_refresh_accent_controls()

func _accent_color_changed(color: Color) -> void:
	_apply_accent_color(Color(color.r, color.g, color.b, 1.0), "Custom")

func _apply_accent_color(color: Color, label: String = "Custom") -> void:
	var current: Color = _desktop_highlight_color()
	_set_desktop_highlight_color(Color(color.r, color.g, color.b, current.a))
	_update_system_accent(color)
	_set_desktop_context_status("Desktop accent updated")
	_set_status("Accent set to " + label, false)
	_refresh_appearance_state()
	_refresh_system_info()

func _refresh_accent_controls() -> void:
	var current: Color = Color(_desktop_highlight_color().r, _desktop_highlight_color().g, _desktop_highlight_color().b, 1.0)
	if _accent_picker != null and not _accent_picker.color.is_equal_approx(current):
		_accent_picker.color = current
	for i in range(_accent_preset_buttons.size()):
		var button: Button = _accent_preset_buttons[i]
		if button == null:
			continue
		var preset_color: Color = _desktop_highlight_presets()[i].get("color", Color.WHITE)
		button.add_theme_stylebox_override("normal", _accent_swatch_style(preset_color, preset_color.is_equal_approx(current)))
		button.add_theme_stylebox_override("hover", _accent_swatch_style(preset_color, true))
		button.add_theme_stylebox_override("pressed", _accent_swatch_style(preset_color, true))
		button.add_theme_stylebox_override("focus", _accent_swatch_style(preset_color, true))

func _accent_swatch_style(color: Color, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 17
	style.corner_radius_top_right = 17
	style.corner_radius_bottom_left = 17
	style.corner_radius_bottom_right = 17
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	if selected:
		var accent: Color = _desktop_highlight_color()
		style.border_color = Color(accent.r, accent.g, accent.b, 1.0)
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
	else:
		style.border_color = Color.TRANSPARENT
	return style

func reset_icon_layout(_event = null) -> void:
	if _shell != null:
		var positions: Variant = _shell.get("_desktop_icon_positions")
		if positions is Dictionary:
			(positions as Dictionary).clear()
	_refresh_desktop_icons()
	_set_desktop_context_status("Desktop icon layout reset")
	_set_status("Desktop icon layout reset", false)
	_refresh_system_info()

func reset_highlight(_event = null) -> void:
	_set_desktop_highlight_color(Color(0.34, 0.45, 0.62, 0.32))
	_update_system_accent(Color(0.435, 0.659, 0.969))
	_set_desktop_context_status("Desktop highlight color reset")
	_set_status("Desktop highlight color reset", false)
	_refresh_appearance_state()
	_refresh_system_info()

func test_gateway(_event = null) -> void:
	_set_status("Testing Hermes Gateway status…", false)
	var gateway_state: Dictionary = _gateway_state()
	var endpoint: String = str(gateway_state.get("endpoint", "http://127.0.0.1:8643/v1/chat/completions")).strip_edges()
	var host_port: Dictionary = _endpoint_host_port(endpoint, str(gateway_state.get("host", "127.0.0.1")), int(gateway_state.get("port", 8643)))
	var host: String = str(host_port.get("host", "127.0.0.1"))
	var port: int = int(host_port.get("port", 8643))
	var probe: Dictionary = _probe_tcp(host, port, GATEWAY_TEST_TIMEOUT_MS)
	if state != null:
		state.set_many({
			"gateway_label": "Online" if bool(probe.get("ok", false)) else "Offline",
			"gateway_toolbar_label": "Gateway: " + ("Online" if bool(probe.get("ok", false)) else "Offline")
		})
	if bool(probe.get("ok", false)):
		_set_status("Gateway reachable at %s" % endpoint, false)
	else:
		_set_status("Gateway unavailable at %s (%s)" % [endpoint, str(probe.get("error", "connect_failed"))], true)
	_refresh_system_info()

func reload_gateway_config(_event = null) -> void:
	if _shell == null or _shell.get("_hermes_agent_service") == null:
		_set_status("Hermes agent service unavailable", true)
		return
	if not _shell.has_method("_hermes_gateway_config"):
		_set_status("Gateway config loader unavailable", true)
		return
	var config: Dictionary = _shell.call("_hermes_gateway_config") as Dictionary
	var service: Object = _shell.get("_hermes_agent_service")
	var gateway_client: Variant = service.get("_gateway_client") if service != null else null
	if gateway_client == null or not gateway_client.has_method("configure"):
		_set_status("Gateway client unavailable", true)
		return
	gateway_client.call("configure", config)
	_set_status("Gateway config reloaded", false)
	_refresh_gateway_mcp_status()

func test_mcp(_event = null) -> void:
	_set_status("Testing MCP endpoint…", false)
	var mcp_result: Dictionary = {"kind": "checking", "label": "checking", "endpoint": "127.0.0.1:9090", "ok": false}
	var probe: Dictionary = _probe_tcp("127.0.0.1", 9090, MCP_TEST_TIMEOUT_MS)
	if not bool(probe.get("ok", false)):
		mcp_result["kind"] = "unavailable"
		mcp_result["label"] = "unavailable"
		mcp_result["error"] = str(probe.get("error", "connect_failed"))
		_set_status("MCP endpoint unavailable (%s)" % str(mcp_result.get("error", "connect_failed")), true)
	else:
		var peer: StreamPeerTCP = probe.get("peer", null) as StreamPeerTCP
		mcp_result["tcp_reachable"] = true
		var protocol_probe: Dictionary = _probe_mcp_protocol(peer)
		var has_response: bool = bool(protocol_probe.get("response_seen", false))
		var protocol_verified: bool = bool(protocol_probe.get("ok", false))
		if peer != null:
			peer.disconnect_from_host()
		mcp_result["protocol_verified"] = protocol_verified
		mcp_result["response_seen"] = has_response
		if protocol_verified:
			mcp_result["kind"] = "success"
			mcp_result["label"] = "available"
			mcp_result["ok"] = true
			_set_status("MCP available (os_ping verified)", false)
		else:
			mcp_result["kind"] = "warning"
			mcp_result["label"] = "port reachable, protocol unverified"
			mcp_result["ok"] = false
			mcp_result["error"] = str(protocol_probe.get("error", "protocol_not_verified"))
			_set_status("MCP port reachable, protocol not verified", false, "warning")
	if state != null:
		state.set("mcp", mcp_result)
	_refresh_gateway_mcp_status()

func _probe_mcp_protocol(peer: StreamPeerTCP) -> Dictionary:
	if peer == null:
		return {"ok": false, "response_seen": false, "error": "missing_peer"}
	var put_result: int = peer.put_data((JSON.stringify({"command": "os_ping", "params": {}}) + "\n").to_utf8_buffer())
	if put_result != OK:
		return {"ok": false, "response_seen": false, "error": "write_failed_%d" % put_result}
	var buffer: String = ""
	var started_msec: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_msec < 450:
		peer.poll()
		var available: int = peer.get_available_bytes()
		if available > 0:
			var data: Array = peer.get_data(available)
			if data.size() >= 2 and int(data[0]) == OK:
				var bytes: PackedByteArray = data[1]
				buffer += bytes.get_string_from_utf8()
				var newline_pos: int = buffer.find("\n")
				if newline_pos >= 0:
					var line: String = buffer.substr(0, newline_pos).strip_edges()
					var json := JSON.new()
					if json.parse(line) != OK:
						return {"ok": false, "response_seen": true, "error": "invalid_json_response"}
					var response: Variant = json.data
					if response is Dictionary and bool((response as Dictionary).get("success", false)) and bool((response as Dictionary).get("pong", false)):
						var server: Variant = (response as Dictionary).get("server", {})
						if server is Dictionary and str((server as Dictionary).get("name", "")) == "McpInteractionServer":
							return {"ok": true, "response_seen": true}
					return {"ok": false, "response_seen": true, "error": "unexpected_protocol_response"}
		OS.delay_msec(10)
	return {"ok": false, "response_seen": buffer.strip_edges() != "", "error": "protocol_timeout"}

func _endpoint_host_port(endpoint: String, fallback_host: String, fallback_port: int) -> Dictionary:
	var text: String = endpoint.strip_edges()
	if text == "":
		return {"host": fallback_host, "port": fallback_port}
	if text.begins_with("http://"):
		text = text.trim_prefix("http://")
	elif text.begins_with("https://"):
		text = text.trim_prefix("https://")
	text = text.split("/", false, 1)[0]
	var host: String = fallback_host
	var port: int = fallback_port
	if text.find(":") >= 0:
		var parts: PackedStringArray = text.split(":", false, 1)
		host = parts[0] if parts.size() > 0 and parts[0] != "" else fallback_host
		port = int(parts[1]) if parts.size() > 1 and str(parts[1]).is_valid_int() else fallback_port
	elif text != "":
		host = text
	return {"host": host, "port": port}

func _probe_tcp(host: String, port: int, timeout_ms: int) -> Dictionary:
	var peer := StreamPeerTCP.new()
	var err: int = peer.connect_to_host(host, port)
	if err != OK:
		return {"ok": false, "error": "connect_start_failed_%d" % err}
	var started_msec: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_msec < timeout_ms:
		peer.poll()
		var status: int = peer.get_status()
		if status == StreamPeerTCP.STATUS_CONNECTED:
			return {"ok": true, "peer": peer}
		if status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
			peer.disconnect_from_host()
			return {"ok": false, "error": "connect_failed"}
		OS.delay_msec(10)
	peer.disconnect_from_host()
	return {"ok": false, "error": "timeout"}

func _initialize_state() -> void:
	if state == null:
		return
	state.set_many({
		"active_tab": "system",
		"system_visible": true,
		"appearance_visible": false,
		"window_management_visible": false,
		"snap_assist_enabled": _snap_assist_enabled(),
		"system_info": "Loading system information…",
		"status": "System settings ready.",
		"status_variant": "info",
		"gateway_label": "Checking",
		"gateway_toolbar_label": "Gateway: Checking",
		"gateway_variant": "busy",
		"gateway_model": "Unknown",
		"gateway_source": "runtime/hermes_gateway/compose.env",
		"mcp_label": "Checking",
		"mcp_toolbar_label": "MCP: Checking",
		"mcp_variant": "busy",
		"mcp_endpoint": "127.0.0.1:9090",
		"theme_mode": _theme_mode(),
		"highlight_preset": _current_highlight_preset(),
		"highlight_alpha": _desktop_highlight_color().a,
		"highlight_alpha_label": _alpha_label(_desktop_highlight_color().a),
		"mcp": _mcp_state()
	})

func _refresh_page_visibility() -> void:
	if state == null:
		return
	var active: String = state.get_string("active_tab", "system")
	state.set_many({
		"system_visible": active == "system",
		"appearance_visible": active == "appearance",
		"window_management_visible": active == "window_management"
	})

func _refresh_appearance_state() -> void:
	if state == null:
		return
	var highlight: Color = _desktop_highlight_color()
	state.set_many({
		"theme_mode": _theme_mode(),
		"highlight_preset": _current_highlight_preset(),
		"highlight_alpha": highlight.a,
		"highlight_alpha_label": _alpha_label(highlight.a),
		"snap_assist_enabled": _snap_assist_enabled()
	})
	_refresh_wallpaper_grid_selection()
	_refresh_accent_controls()

func _refresh_gateway_mcp_status() -> void:
	if state == null:
		return
	var gateway_state: Dictionary = _gateway_state()
	var gateway_kind: String = _gateway_kind(gateway_state)
	var gateway_label: String = _gateway_label(gateway_kind).capitalize()
	var display_model: String = _display_model_name(gateway_state)
	var mcp_state: Dictionary = _mcp_state()
	var mcp_kind: String = str(mcp_state.get("kind", "unavailable"))
	var mcp_label: String = str(mcp_state.get("label", "unavailable")).capitalize()
	state.set_many({
		"gateway_label": gateway_label,
		"gateway_toolbar_label": "Gateway: " + gateway_label,
		"gateway_variant": gateway_kind,
		"gateway_model": display_model if display_model != "" else "Unknown",
		"gateway_source": _gateway_source_path(gateway_state),
		"mcp_label": mcp_label,
		"mcp_toolbar_label": "MCP: " + mcp_label,
		"mcp_variant": mcp_kind,
		"mcp_endpoint": str(mcp_state.get("endpoint", "127.0.0.1:9090"))
	})
	_refresh_system_info()

func _snap_assist_enabled() -> bool:
	if _shell != null and _shell.has_method("is_snap_assist_enabled"):
		return bool(_shell.call("is_snap_assist_enabled"))
	return true

func _refresh_system_info() -> void:
	if state == null or _shell == null or _fs == null:
		return
	var viewport_size: Vector2 = _shell.get_viewport_rect().size if _shell != null else Vector2.ZERO
	var window_size: Vector2i = DisplayServer.window_get_size()
	var mode: int = DisplayServer.window_get_mode()
	var gateway: Dictionary = _gateway_state()
	var gateway_kind: String = _gateway_kind(gateway)
	var mcp_state: Dictionary = _mcp_state()
	state.set("system_info", "Viewport: %s\nGame window: %s\nWindow mode: %s\nCurrent user: %s\nHome: %s\nUsers: %s\nFilesystem save: %s\nApps: %s\nOpen windows: %s\nGateway status: %s\nGateway endpoint: %s\nGateway model: %s\nMCP status: %s\nMCP endpoint: %s
Snap Assist: %s" % [
		str(viewport_size),
		str(window_size),
		str(mode),
		str(_fs.call("current_user")),
		str(_fs.call("home_path")),
		", ".join(_fs.call("get_users")),
		OSFileSystem.SAVE_PATH,
		_app_ids_text(),
		_windows_text(),
		_gateway_label(gateway_kind),
		str(gateway.get("endpoint", "http://127.0.0.1:8643/v1/chat/completions")),
		(_display_model_name(gateway) if _display_model_name(gateway) != "" else "Unknown"),
		str(mcp_state.get("label", "unavailable")),
		str(mcp_state.get("endpoint", "127.0.0.1:9090")),
		"enabled" if _snap_assist_enabled() else "disabled"
	])

func _theme_mode() -> String:
	if _shell != null:
		return str(_shell.get("_theme_mode"))
	return "dark"

func _wallpaper_index() -> int:
	if _shell != null:
		return int(_shell.get("_wallpaper_index"))
	return 0

func _desktop_highlight_color() -> Color:
	if _shell != null:
		var value: Variant = _shell.get("_desktop_highlight_color")
		if value is Color:
			return value as Color
	return Color(0.34, 0.45, 0.62, 0.32)

func _desktop_highlight_presets() -> Array[Dictionary]:
	return [
		{"label": "Ocean", "color": Color(0.34, 0.45, 0.62, 1.0)},
		{"label": "Sky", "color": Color(0.28, 0.57, 0.92, 1.0)},
		{"label": "Cyan", "color": Color(0.18, 0.75, 0.85, 1.0)},
		{"label": "Mint", "color": Color(0.35, 0.63, 0.46, 1.0)},
		{"label": "Lime", "color": Color(0.55, 0.78, 0.30, 1.0)},
		{"label": "Amber", "color": Color(0.73, 0.53, 0.27, 1.0)},
		{"label": "Orange", "color": Color(0.86, 0.39, 0.18, 1.0)},
		{"label": "Rose", "color": Color(0.71, 0.39, 0.54, 1.0)},
		{"label": "Violet", "color": Color(0.55, 0.43, 0.86, 1.0)},
		{"label": "Magenta", "color": Color(0.82, 0.31, 0.74, 1.0)}
	]

func _current_highlight_preset() -> String:
	var current: Color = Color(_desktop_highlight_color().r, _desktop_highlight_color().g, _desktop_highlight_color().b, 1.0)
	for preset in _desktop_highlight_presets():
		var preset_color: Color = preset.get("color", Color.WHITE)
		if preset_color.is_equal_approx(current):
			return str(preset.get("label", "Ocean"))
	return "Custom"

func _alpha_label(value: float) -> String:
	return "%d%%" % int(round(value * 100.0))

func _gateway_state() -> Dictionary:
	var fallback: Dictionary = {
		"configured": true,
		"busy": false,
		"endpoint": "http://127.0.0.1:8643/v1/chat/completions",
		"host": "127.0.0.1",
		"port": 8643,
		"path": "/v1/chat/completions",
		"model": "",
		"profile_hint": "hermesos",
		"api_key_present": false,
		"last_error": {},
		"last_response": {}
	}
	if _shell == null:
		return fallback
	var service: Variant = _shell.get("_hermes_agent_service")
	if service != null and service.has_method("get_status"):
		var status: Variant = service.call("get_status")
		if status is Dictionary:
			var gateway: Variant = (status as Dictionary).get("gateway", {})
			if gateway is Dictionary:
				var snapshot: Dictionary = (gateway as Dictionary).duplicate(true)
				snapshot["source_path"] = _gateway_source_path(snapshot)
				if str(snapshot.get("endpoint", "")).strip_edges() == "":
					snapshot["endpoint"] = fallback["endpoint"]
				if str(snapshot.get("model", "")).strip_edges() == "":
					snapshot["model"] = fallback["model"]
				return snapshot
	return fallback

func _gateway_source_path(gateway_state: Dictionary) -> String:
	var direct: String = str(gateway_state.get("source_path", "")).strip_edges()
	if direct != "":
		return direct
	if _shell != null and _shell.has_method("_hermes_gateway_config"):
		var config: Variant = _shell.call("_hermes_gateway_config")
		if config is Dictionary:
			var path_text: String = str((config as Dictionary).get("gateway_config_path", "")).strip_edges()
			if path_text != "":
				if path_text.begins_with("res://"):
					return path_text.trim_prefix("res://")
				return path_text
	return "runtime/hermes_gateway/compose.env"

func _gateway_kind(gateway_state: Dictionary) -> String:
	if bool(gateway_state.get("busy", false)):
		return "busy"
	var last_error: Dictionary = gateway_state.get("last_error", {}) if gateway_state.get("last_error", {}) is Dictionary else {}
	var error_code: String = str(last_error.get("code", "")).strip_edges()
	if error_code == "GATEWAY_UNAUTHORIZED":
		return "warning"
	if error_code != "":
		return "danger"
	if bool(gateway_state.get("configured", false)):
		return "success" if bool(gateway_state.get("api_key_present", false)) else "warning"
	return "muted"

func _gateway_label(kind: String) -> String:
	match kind:
		"success": return "online"
		"warning": return "unauthorized"
		"danger": return "error"
		"busy": return "checking"
		_: return "offline"

func _display_model_name(gateway_state: Dictionary) -> String:
	var model_name: String = str(gateway_state.get("model", "")).strip_edges()
	if model_name.to_lower() == "hermesos":
		return ""
	return model_name

func _mcp_state() -> Dictionary:
	if state != null:
		var cached: Variant = state.get_value("mcp", {})
		if cached is Dictionary and not (cached as Dictionary).is_empty():
			var snap: Dictionary = (cached as Dictionary).duplicate(true)
			if str(snap.get("endpoint", "")).strip_edges() == "":
				snap["endpoint"] = "127.0.0.1:9090"
			if str(snap.get("label", "")).strip_edges() == "":
				snap["label"] = "checking"
			if str(snap.get("kind", "")).strip_edges() == "":
				snap["kind"] = "checking"
			return snap
	return {"kind": "checking", "label": "checking", "endpoint": "127.0.0.1:9090", "ok": false}

func _set_status(message: String, is_error: bool = false, variant: String = "") -> void:
	if state != null:
		state.set_many({
			"status": message,
			"status_variant": (variant if variant != "" else ("danger" if is_error else "info"))
		})

func _apply_theme_mode(mode: String, refresh_ui: bool = true) -> void:
	if _shell != null and _shell.has_method("_apply_theme_mode"):
		_shell.call("_apply_theme_mode", mode, refresh_ui)

func _cycle_wallpaper() -> void:
	if _shell != null and _shell.has_method("_cycle_wallpaper"):
		_shell.call("_cycle_wallpaper")

func _set_desktop_highlight_color(color: Color) -> void:
	if _shell != null and _shell.has_method("_set_desktop_highlight_color"):
		_shell.call("_set_desktop_highlight_color", color)

func _update_system_accent(color: Color) -> void:
	if _shell != null and _shell.has_method("_update_system_accent"):
		_shell.call("_update_system_accent", color, true)

func _refresh_desktop_icons() -> void:
	if _shell != null and _shell.has_method("_refresh_desktop_icons"):
		_shell.call("_refresh_desktop_icons")

func _set_desktop_context_status(message: String, is_error: bool = false) -> void:
	if _shell != null and _shell.has_method("_set_desktop_context_status"):
		_shell.call("_set_desktop_context_status", message, is_error)

func _app_ids_text() -> String:
	if _shell != null and _shell.has_method("_app_ids_text"):
		return str(_shell.call("_app_ids_text"))
	return ""

func _windows_text() -> String:
	if _shell != null and _shell.has_method("_windows_text"):
		return str(_shell.call("_windows_text"))
	return "none"
