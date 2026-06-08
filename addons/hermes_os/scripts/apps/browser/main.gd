extends "res://addons/hermes_os/scripts/ui/hermes_ui/runtime/hermes_app_controller.gd"

const DEFAULT_URL := "http://home.hermes/"
const NEW_TAB_URL := DEFAULT_URL
const SEARCH_URL_TEMPLATE := "http://pythia.com/?q=%s"

var _shell: Node = null
var _fs: Object = null
var _browser_app: Object = null
var _surface: Control = null
var _address_input: LineEdit = null
var _address_context_menu: PopupMenu = null
var _address_context_menu_occluding := false

const ADDRESS_MENU_CUT := 1001
const ADDRESS_MENU_COPY := 1002
const ADDRESS_MENU_PASTE := 1003
const ADDRESS_MENU_SELECT_ALL := 1004
const ADDRESS_MENU_CLEAR := 1005

const DesignTokens = preload("res://addons/hermes_os/scripts/os/design_tokens.gd")

func configure_app_context(context: Dictionary) -> void:
	_shell = context.get("shell", null) as Node
	_fs = context.get("filesystem", null) as Object
	var browser_value: Variant = context.get("browser_app", null)
	if browser_value is Object:
		_browser_app = browser_value as Object
	_setup_address_context_menu()
	_setup_surface()
	sync_from_surface()

func _app_ready() -> void:
	if state != null:
		state.set_many({
			"address": DEFAULT_URL,
			"current_url": DEFAULT_URL,
			"title": "Browser",
			"status": "initializing",
			"loading": false,
			"back_disabled": true,
			"forward_disabled": true
		})
	_setup_surface()
	_setup_address_context_menu()
	sync_from_surface()

func get_browser_surface() -> Control:
	_setup_surface()
	return _surface

func handle_address_input(event) -> void:
	if state != null:
		state.set("address", str(event.value))

func load_address(event = null) -> void:
	_setup_surface()
	var value: String = _event_or_address(event).strip_edges()
	if value == "":
		value = DEFAULT_URL
	if _surface == null:
		_set_status("browser surface unavailable")
		return
	if _should_search_address(value) and _surface.has_method("open_url"):
		_surface.call("open_url", _search_url_for(value))
	elif _surface.has_method("open_url"):
		_surface.call("open_url", value)
	sync_from_surface()

func _search_url_for(query: String) -> String:
	return SEARCH_URL_TEMPLATE % query.uri_encode()

func _should_search_address(value: String) -> bool:
	var clean := value.strip_edges()
	if clean == "":
		return false
	if _contains_whitespace(clean):
		return true
	var lower := clean.to_lower()
	if lower.begins_with("about:") or lower.begins_with("browser://") or lower.begins_with("hermes://"):
		return false
	if clean.contains("://"):
		return false
	if clean.contains("."):
		return false
	if clean.contains("/"):
		return false
	return true

func _contains_whitespace(value: String) -> bool:
	for ch in value:
		if ch in [" ", "	", "\n", "\r"]:
			return true
	return false

func go_back(_event = null) -> void:
	_setup_surface()
	if _surface != null and _surface.has_method("go_back"):
		_surface.call("go_back")
	sync_from_surface()

func go_forward(_event = null) -> void:
	_setup_surface()
	if _surface != null and _surface.has_method("go_forward"):
		_surface.call("go_forward")
	sync_from_surface()

func reload_page(_event = null) -> void:
	_setup_surface()
	if _surface != null and _surface.has_method("reload"):
		_surface.call("reload")
	sync_from_surface()

func open_home(_event = null) -> void:
	_setup_surface()
	if _surface != null and _surface.has_method("open_home"):
		_surface.call("open_home")
	elif _surface != null and _surface.has_method("open_url"):
		_surface.call("open_url", DEFAULT_URL)
	sync_from_surface()

func new_tab(_event = null) -> void:
	_setup_surface()
	if _surface != null and _surface.has_method("new_tab"):
		_surface.call("new_tab", NEW_TAB_URL)
	sync_from_surface()

func show_settings(_event = null) -> void:
	_setup_surface()
	if _surface != null and _surface.has_method("show_settings"):
		_surface.call("show_settings")
	sync_from_surface()

func sync_from_surface() -> void:
	_setup_surface()
	if _surface == null or state == null:
		return
	var current_url: String = DEFAULT_URL
	var title: String = "Browser"
	if _surface.has_method("get_current_url"):
		current_url = str(_surface.call("get_current_url"))
	if _surface.has_method("get_current_title"):
		title = str(_surface.call("get_current_title"))
	var snapshot: Dictionary = {}
	if _surface.has_method("debug_get_state"):
		var value: Variant = _surface.call("debug_get_state")
		if value is Dictionary:
			snapshot = (value as Dictionary).duplicate(true)
	var loading: bool = bool(snapshot.get("loading", false))
	var load_state: String = str(snapshot.get("load_state", "ready"))
	var status_text: String = load_state if load_state != "" else "ready"
	if current_url != "":
		status_text += " — " + current_url
	state.set_many({
		"current_url": current_url,
		"address": current_url,
		"title": title,
		"status": status_text,
		"loading": loading,
		"back_disabled": not _surface_can("can_go_back"),
		"forward_disabled": not _surface_can("can_go_forward")
	})
	if ui != null:
		ui.set_value("browser-address", current_url)

func _setup_surface() -> void:
	if _surface != null and is_instance_valid(_surface):
		return
	if ui == null:
		return
	_surface = ui.by_id("browser-surface")
	if _surface != null:
		if _surface.has_signal("navigation_state_changed"):
			var sync_callable := Callable(self, "sync_from_surface")
			if not _surface.is_connected("navigation_state_changed", sync_callable):
				_surface.connect("navigation_state_changed", sync_callable)
		if _surface.has_signal("browser_overlay_menu_action"):
			var overlay_action_callable := Callable(self, "_on_browser_overlay_menu_action")
			if not _surface.is_connected("browser_overlay_menu_action", overlay_action_callable):
				_surface.connect("browser_overlay_menu_action", overlay_action_callable)
		if _surface.has_method("set_chrome_visible"):
			_surface.call("set_chrome_visible", false)

func _setup_address_context_menu() -> void:
	if _address_context_menu != null and is_instance_valid(_address_context_menu):
		return
	if ui == null and _address_input == null:
		return
	if _address_input == null or not is_instance_valid(_address_input):
		if ui != null:
			var node_value: Variant = ui.by_id("browser-address")
			if not (node_value is LineEdit):
				return
			_address_input = node_value as LineEdit
		else:
			return
	if "context_menu_enabled" in _address_input:
		_address_input.set("context_menu_enabled", false)
	var popup := PopupMenu.new()
	popup.name = "BrowserAddressContextMenu"
	popup.add_item("Cut", ADDRESS_MENU_CUT)
	popup.add_item("Copy", ADDRESS_MENU_COPY)
	popup.add_item("Paste", ADDRESS_MENU_PASTE)
	popup.add_separator()
	popup.add_item("Select All", ADDRESS_MENU_SELECT_ALL)
	popup.add_item("Clear", ADDRESS_MENU_CLEAR)
	_style_address_context_menu(popup)
	popup.id_pressed.connect(_on_address_context_id_pressed)
	popup.popup_hide.connect(_on_address_context_popup_hide)
	if _address_input.get_parent() != null:
		_address_input.get_parent().add_child(popup)
	_address_context_menu = popup
	var input_cb := Callable(self, "_on_address_input_gui_input")
	if not _address_input.gui_input.is_connected(input_cb):
		_address_input.gui_input.connect(input_cb)

func _style_address_context_menu(popup: PopupMenu) -> void:
	if popup == null:
		return
	var panel := StyleBoxFlat.new()
	panel.bg_color = DesignTokens.ELEVATED_CARD
	panel.border_color = DesignTokens.BORDER
	panel.border_width_left = 1
	panel.border_width_top = 1
	panel.border_width_right = 1
	panel.border_width_bottom = 1
	panel.corner_radius_top_left = 8
	panel.corner_radius_top_right = 8
	panel.corner_radius_bottom_left = 8
	panel.corner_radius_bottom_right = 8
	panel.content_margin_left = 8
	panel.content_margin_top = 6
	panel.content_margin_right = 8
	panel.content_margin_bottom = 6
	popup.add_theme_stylebox_override("panel", panel)

	popup.add_theme_color_override("font_color", DesignTokens.TEXT)
	popup.add_theme_color_override("font_hover_color", DesignTokens.TEXT)
	popup.add_theme_color_override("font_disabled_color", DesignTokens.TEXT_MUTED)
	popup.add_theme_color_override("font_separator_color", DesignTokens.TEXT_FAINT)
	popup.add_theme_color_override("font_accelerator_color", DesignTokens.TEXT_MUTED)
	popup.add_theme_color_override("font_hover_accelerator_color", DesignTokens.TEXT)
	popup.add_theme_constant_override("item_start_padding", 12)
	popup.add_theme_constant_override("item_end_padding", 12)
	popup.add_theme_constant_override("v_separation", 4)
	var hover := StyleBoxFlat.new()
	hover.bg_color = DesignTokens.alpha(DesignTokens.ACCENT, 0.2)
	hover.corner_radius_top_left = 6
	hover.corner_radius_top_right = 6
	hover.corner_radius_bottom_left = 6
	hover.corner_radius_bottom_right = 6
	popup.add_theme_stylebox_override("hover", hover)

func _on_address_input_gui_input(event: InputEvent) -> void:
	if _address_input == null or _address_context_menu == null:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			_show_address_context_menu(mouse_event.global_position)
			if not _address_input.has_focus():
				_address_input.grab_focus()
			var viewport := _address_input.get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()

func _show_address_context_menu(global_position: Vector2) -> void:
	if _address_input == null or _address_context_menu == null or not is_instance_valid(_address_context_menu):
		_setup_address_context_menu()
		if _address_context_menu == null:
			return
	var has_text: bool = _address_input.text != ""
	var has_selection: bool = _address_input.has_selection()
	var can_edit: bool = _address_input.editable
	var clipboard_available: bool = _clipboard_is_available()
	var can_paste: bool = can_edit and clipboard_available and DisplayServer.clipboard_get() != ""
	_address_context_menu.set_item_disabled(_address_context_menu.get_item_index(ADDRESS_MENU_CUT), (not can_edit) or (not clipboard_available) or (not has_selection))
	_address_context_menu.set_item_disabled(_address_context_menu.get_item_index(ADDRESS_MENU_COPY), (not clipboard_available) or (not has_selection))
	_address_context_menu.set_item_disabled(_address_context_menu.get_item_index(ADDRESS_MENU_PASTE), not can_paste)
	_address_context_menu.set_item_disabled(_address_context_menu.get_item_index(ADDRESS_MENU_SELECT_ALL), not has_text)
	_address_context_menu.set_item_disabled(_address_context_menu.get_item_index(ADDRESS_MENU_CLEAR), (not can_edit) or (not has_text))
	if _try_show_address_context_menu_portal(global_position, has_selection, can_paste, has_text, can_edit):
		return
	var pos := Vector2i(int(global_position.x), int(global_position.y))
	_address_context_menu.position = pos
	# Explicit Rect2 forces reliable content-based sizing and layout (fixes only-Cut menu)
	_address_context_menu.popup(Rect2(pos, Vector2(220, 0)))

func _on_address_context_id_pressed(id: int) -> void:
	if _address_input == null:
		_set_address_context_content_occluded(false)
		return
	_perform_address_context_action_id(id)
	if _address_context_menu != null and is_instance_valid(_address_context_menu) and _address_context_menu.visible:
		_address_context_menu.hide()
	_set_address_context_content_occluded(false)

func _perform_address_context_action_id(id: int) -> void:
	if _address_input == null:
		return
	match id:
		ADDRESS_MENU_CUT:
			_cut_address_selection()
		ADDRESS_MENU_COPY:
			_copy_address_selection()
		ADDRESS_MENU_PASTE:
			_paste_into_address()
		ADDRESS_MENU_SELECT_ALL:
			_address_input.select_all()
		ADDRESS_MENU_CLEAR:
			_address_input.clear()
	if state != null:
		state.set("address", _address_input.text)

func _on_address_context_popup_hide() -> void:
	_set_address_context_content_occluded(false)

func _try_show_address_context_menu_portal(global_position: Vector2, has_selection: bool, can_paste: bool, has_text: bool, can_edit: bool) -> bool:
	_setup_surface()
	if _surface == null or not _surface.has_method("show_browser_overlay_menu"):
		return false
	if _surface.has_method("can_show_browser_overlay_menu") and not bool(_surface.call("can_show_browser_overlay_menu")):
		return false
	var spec := {
		"menu_id": "address_context_menu",
		"global_position": {"x": global_position.x, "y": global_position.y},
		"items": [
			{"id": "cut", "action": "cut", "label": "Cut", "enabled": can_edit and has_selection},
			{"id": "copy", "action": "copy", "label": "Copy", "enabled": has_selection},
			{"id": "paste", "action": "paste", "label": "Paste", "enabled": can_paste},
			{"separator": true},
			{"id": "select_all", "action": "select_all", "label": "Select All", "enabled": has_text},
			{"id": "clear", "action": "clear", "label": "Clear", "enabled": can_edit and has_text}
		]
	}
	return bool(_surface.call("show_browser_overlay_menu", spec))

func _on_browser_overlay_menu_action(menu_id: String, action: String) -> void:
	if menu_id != "address_context_menu":
		return
	var id := _address_action_id_from_string(action)
	if id == 0:
		return
	_perform_address_context_action_id(id)

func _address_action_id_from_string(action: String) -> int:
	match action:
		"cut", "Cut":
			return ADDRESS_MENU_CUT
		"copy", "Copy":
			return ADDRESS_MENU_COPY
		"paste", "Paste":
			return ADDRESS_MENU_PASTE
		"select_all", "Select All":
			return ADDRESS_MENU_SELECT_ALL
		"clear", "Clear":
			return ADDRESS_MENU_CLEAR
	return 0

func _set_address_context_content_occluded(active: bool) -> void:
	if _address_context_menu_occluding == active:
		return
	_address_context_menu_occluding = active
	_setup_surface()
	if _surface != null and _surface.has_method("set_browser_chrome_popup_occluded"):
		_surface.call("set_browser_chrome_popup_occluded", active)
	elif _surface != null and _surface.has_method("set_browser_content_occluded"):
		_surface.call("set_browser_content_occluded", active)
	elif _browser_app != null and _browser_app.has_method("set_browser_chrome_popup_occluded"):
		_browser_app.call("set_browser_chrome_popup_occluded", active)
	elif _browser_app != null and _browser_app.has_method("set_browser_content_occluded"):
		_browser_app.call("set_browser_content_occluded", active)

func _copy_address_selection() -> bool:
	if _address_input == null or not _address_input.has_selection() or not _clipboard_is_available():
		return false
	DisplayServer.clipboard_set(_address_input.get_selected_text())
	return true

func _cut_address_selection() -> bool:
	if _address_input == null or not _address_input.editable or not _address_input.has_selection():
		return false
	if not _copy_address_selection():
		return false
	_delete_address_selection()
	return true

func _paste_into_address() -> bool:
	if _address_input == null or not _address_input.editable or not _clipboard_is_available():
		return false
	var clipboard_text: String = DisplayServer.clipboard_get()
	if clipboard_text == "":
		return false
	if _address_input.has_selection():
		_delete_address_selection()
	_address_input.insert_text_at_caret(clipboard_text)
	return true

func _delete_address_selection() -> void:
	if _address_input == null or not _address_input.has_selection():
		return
	var from_column: int = _address_input.get_selection_from_column()
	var to_column: int = _address_input.get_selection_to_column()
	if from_column > to_column:
		var swap_column: int = from_column
		from_column = to_column
		to_column = swap_column
	_address_input.delete_text(from_column, to_column)
	_address_input.caret_column = from_column

func debug_perform_address_context_action(action: String) -> void:
	var id := _address_action_id_from_string(action)
	if id != 0:
		_on_address_context_id_pressed(id)

func _clipboard_is_available() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD)

func debug_get_address_context_actions() -> Array[String]:
	if _address_context_menu == null:
		return []
	var labels: Array[String] = []
	for index in _address_context_menu.item_count:
		if _address_context_menu.is_item_separator(index):
			continue
		labels.append(_address_context_menu.get_item_text(index))
	return labels

func _event_or_address(event) -> String:
	if event != null and "value" in event and "target_id" in event and str(event.target_id) == "browser-address":
		var event_value: String = str(event.value).strip_edges()
		if event_value != "":
			return event_value
	if ui != null:
		var ui_value: Variant = ui.get_value("browser-address")
		if ui_value != null:
			return str(ui_value)
	if state != null:
		return str(state.get_value("address", DEFAULT_URL))
	return DEFAULT_URL

func _surface_can(method_name: String) -> bool:
	if _surface != null and _surface.has_method(method_name):
		return bool(_surface.call(method_name))
	return false

func _set_status(text: String) -> void:
	if state != null:
		state.set("status", text)
