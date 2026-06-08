class_name BrowserApp
extends Control

const HermesUIRuntime = preload("res://addons/hermes_os/scripts/ui/hermes_ui/runtime/hermes_ui_runtime.gd")

const MANIFEST_PATH := "res://addons/hermes_os/scripts/apps/browser/manifest.json"

var _shell: Node = null
var _fs: Object = null
var _runtime = null
var _instance = null
var _mounted: Control = null
var _built: bool = false

func _ready() -> void:
	if not _built:
		_build()

func os_app_init(context: Dictionary) -> void:
	_shell = context.get("shell", null) as Node
	_fs = context.get("filesystem", null) as Object
	_build()

func _exit_tree() -> void:
	prepare_for_close()
	if _runtime != null and _instance != null:
		_runtime.unmount_instance(_instance)

func prepare_for_close() -> void:
	var surface = get_browser_surface()
	if surface != null and surface.has_method("prepare_for_close"):
		surface.call("prepare_for_close")

func is_native_teardown_complete() -> bool:
	var surface = get_browser_surface()
	if surface != null and surface.has_method("is_native_teardown_complete"):
		return bool(surface.call("is_native_teardown_complete"))
	return true

func set_shell_overlay_occluded(active: bool) -> void:
	var surface = get_browser_surface()
	if surface != null and surface.has_method("set_shell_overlay_occluded"):
		surface.call("set_shell_overlay_occluded", active)

func set_browser_content_occluded(active: bool) -> void:
	set_browser_chrome_popup_occluded(active)

func set_browser_chrome_popup_occluded(active: bool) -> void:
	var surface = get_browser_surface()
	if surface != null and surface.has_method("set_browser_chrome_popup_occluded"):
		surface.call("set_browser_chrome_popup_occluded", active)
	elif surface != null and surface.has_method("set_browser_content_occluded"):
		surface.call("set_browser_content_occluded", active)

func open_url(input_url: String) -> void:
	var surface = get_browser_surface()
	if surface != null and surface.has_method("open_url"):
		surface.call("open_url", input_url)
	_sync_controller_from_surface()

func search(query: String) -> void:
	var surface = get_browser_surface()
	if surface != null and surface.has_method("search"):
		surface.call("search", query)
	_sync_controller_from_surface()

func go_back() -> void:
	var surface = get_browser_surface()
	if surface != null and surface.has_method("go_back"):
		surface.call("go_back")
	_sync_controller_from_surface()

func go_forward() -> void:
	var surface = get_browser_surface()
	if surface != null and surface.has_method("go_forward"):
		surface.call("go_forward")
	_sync_controller_from_surface()

func reload() -> void:
	var surface = get_browser_surface()
	if surface != null and surface.has_method("reload"):
		surface.call("reload")
	_sync_controller_from_surface()

func open_home() -> void:
	var surface = get_browser_surface()
	if surface != null and surface.has_method("open_home"):
		surface.call("open_home")
	_sync_controller_from_surface()

func agent_browser_get_state(args: Dictionary = {}) -> Dictionary:
	return _call_surface_agent_method("agent_get_state", args, "browser.get_state")

func agent_browser_navigate(args: Dictionary = {}) -> Dictionary:
	return _call_surface_agent_method("agent_navigate", args, "browser.navigate")

func agent_browser_back(args: Dictionary = {}) -> Dictionary:
	return _call_surface_agent_method("agent_back", args, "browser.back")

func agent_browser_forward(args: Dictionary = {}) -> Dictionary:
	return _call_surface_agent_method("agent_forward", args, "browser.forward")

func agent_browser_reload(args: Dictionary = {}) -> Dictionary:
	return _call_surface_agent_method("agent_reload", args, "browser.reload")

func agent_browser_list_links(args: Dictionary = {}) -> Dictionary:
	return _call_surface_agent_method("agent_list_links", args, "browser.list_links")

func agent_browser_activate_link(args: Dictionary = {}) -> Dictionary:
	return _call_surface_agent_method("agent_activate_link", args, "browser.activate_link")

func agent_browser_test_press_key(args: Dictionary = {}) -> Dictionary:
	return _call_surface_agent_method("agent_browser_test_press_key", args, "browser.test_press_key")

func agent_browser_test_type_text(args: Dictionary = {}) -> Dictionary:
	return _call_surface_agent_method("agent_browser_test_type_text", args, "browser.test_type_text")

func agent_browser_test_click(args: Dictionary = {}) -> Dictionary:
	return _call_surface_agent_method("agent_browser_test_click", args, "browser.test_click")

func agent_browser_test_scroll(args: Dictionary = {}) -> Dictionary:
	return _call_surface_agent_method("agent_browser_test_scroll", args, "browser.test_scroll")

func _call_surface_agent_method(method_name: String, args: Dictionary, operation: String) -> Dictionary:
	var surface = get_browser_surface()
	if surface == null or not surface.has_method(method_name):
		return {"success": false, "operation": operation, "code": "BROWSER_SURFACE_UNAVAILABLE", "error": "Browser surface is unavailable"}
	var result: Variant = surface.call(method_name, args)
	_sync_controller_from_surface()
	if result is Dictionary:
		var response := (result as Dictionary).duplicate(true)
		if not response.has("operation"):
			response["operation"] = operation
		return response
	return {"success": false, "operation": operation, "code": "BAD_RESULT", "error": "Browser operation returned a non-dictionary result"}

func stop_loading() -> void:
	var surface = get_browser_surface()
	if surface != null and surface.has_method("stop_loading"):
		surface.call("stop_loading")
	_sync_controller_from_surface()

func get_current_url() -> String:
	var surface = get_browser_surface()
	if surface != null and surface.has_method("get_current_url"):
		return str(surface.call("get_current_url"))
	return "about:newtab"

func get_current_title() -> String:
	var surface = get_browser_surface()
	if surface != null and surface.has_method("get_current_title"):
		return str(surface.call("get_current_title"))
	return "Browser"

func debug_get_state() -> Dictionary:
	var surface = get_browser_surface()
	if surface != null and surface.has_method("debug_get_state"):
		var value: Variant = surface.call("debug_get_state")
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {"url": get_current_url(), "title": get_current_title(), "loading": false}

func debug_apply_settings(values: Dictionary) -> void:
	var surface = get_browser_surface()
	if surface != null and surface.has_method("debug_apply_settings"):
		surface.call("debug_apply_settings", values)

func debug_trigger_shortcut(name: String) -> void:
	var surface = get_browser_surface()
	if surface != null and surface.has_method("debug_trigger_shortcut"):
		surface.call("debug_trigger_shortcut", name)
	_sync_controller_from_surface()

func get_browser_surface() -> Control:
	var controller = _controller()
	if controller != null and controller.has_method("get_browser_surface"):
		var value: Variant = controller.call("get_browser_surface")
		if value is Control and is_instance_valid(value):
			return value as Control
	var found := find_child("HermesRenderBrowserSurface", true, false)
	if found is Control:
		return found as Control
	return null

func _build() -> void:
	_built = true
	for child in get_children():
		child.queue_free()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(760, 520)
	set_meta("window_min_size", Vector2(760, 520))
	set_meta("window_default_size", Vector2(980, 640))

	_runtime = HermesUIRuntime.new()
	_runtime.set_os_context({
		"shell": _shell,
		"filesystem": _fs,
		"event_bus": _shell.get("_event_bus") if _shell != null else null,
		"window_manager": _shell.get("_window_manager") if _shell != null else null,
		"app_registry": _shell.get("_app_registry") if _shell != null else null,
		"notification_center": _shell.get("_notification_center") if _shell != null else null,
		"agent_service": _shell.get("_hermes_agent_service") if _shell != null else null
	})
	_instance = _runtime.create_app_instance(MANIFEST_PATH)
	set_meta("hermes_ui_runtime", _runtime)
	set_meta("hermes_ui_instance", _instance)
	if _instance == null:
		add_child(_error_label("Browser manifest failed to load."))
		return
	_mounted = _runtime.mount_instance(_instance, self)
	if _mounted == null:
		add_child(_error_label("Browser runtime failed to mount."))
	_configure_controller()

func _configure_controller() -> void:
	var controller = _controller()
	if controller != null and controller.has_method("configure_app_context"):
		controller.call("configure_app_context", {"shell": _shell, "filesystem": _fs, "browser_app": self})

func _controller():
	if _instance == null:
		return null
	return _instance.controller

func _sync_controller_from_surface() -> void:
	var controller = _controller()
	if controller != null and controller.has_method("sync_from_surface"):
		controller.call("sync_from_surface")

func _error_label(message: String) -> Label:
	var label := Label.new()
	label.name = "BrowserRuntimeError"
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label
