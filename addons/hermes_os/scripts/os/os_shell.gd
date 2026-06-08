class_name OSShell
extends Control

const OSWindow = preload("res://addons/hermes_os/scripts/os/os_window.gd")
const OSFileSystem = preload("res://addons/hermes_os/scripts/os/os_file_system.gd")
const OSEventBus = preload("res://addons/hermes_os/scripts/os/core/os_event_bus.gd")
const NotificationCenter = preload("res://addons/hermes_os/scripts/os/core/notification_center.gd")
const AppRegistry = preload("res://addons/hermes_os/scripts/os/core/app_registry.gd")
const OSActionRegistry = preload("res://addons/hermes_os/scripts/os/core/os_action_registry.gd")
const AppInstance = preload("res://addons/hermes_os/scripts/os/core/app_instance.gd")
const WindowManager = preload("res://addons/hermes_os/scripts/os/core/window_manager.gd")
const FilesApp = preload("res://addons/hermes_os/scripts/apps/files/files_app.gd")
const FilesAppManifest = preload("res://addons/hermes_os/scripts/apps/files/files_app_manifest.gd")
const TerminalApp = preload("res://addons/hermes_os/scripts/apps/terminal/terminal_app.gd")
const TerminalAppManifest = preload("res://addons/hermes_os/scripts/apps/terminal/terminal_app_manifest.gd")
const TerminalShellBackend = preload("res://addons/hermes_os/scripts/apps/terminal/terminal_shell_backend.gd")
const TextEditorApp = preload("res://addons/hermes_os/scripts/apps/text_editor/text_editor_app.gd")
const TextEditorAppManifest = preload("res://addons/hermes_os/scripts/apps/text_editor/text_editor_app_manifest.gd")
const NotesApp = preload("res://addons/hermes_os/scripts/apps/notes/notes_app.gd")
const NotesAppManifest = preload("res://addons/hermes_os/scripts/apps/notes/notes_app_manifest.gd")
const SystemSettingsApp = preload("res://addons/hermes_os/scripts/apps/system_settings/system_settings_app.gd")
const SystemSettingsAppManifest = preload("res://addons/hermes_os/scripts/apps/system_settings/system_settings_app_manifest.gd")
const HermesChatManifest = preload("res://addons/hermes_os/scripts/apps/hermes_chat/hermes_chat_app_manifest.gd")
const HermesUIRuntime = preload("res://addons/hermes_os/scripts/ui/hermes_ui/runtime/hermes_ui_runtime.gd")
const HermesShellContext = preload("res://addons/hermes_os/scripts/os/hermes_shell/hermes_shell_context.gd")
const HermesShellFragmentRuntime = preload("res://addons/hermes_os/scripts/os/hermes_shell/runtime/hermes_shell_fragment_runtime.gd")
const HermesShellInputGuard = preload("res://addons/hermes_os/scripts/os/hermes_shell/input/hermes_shell_input_guard.gd")
const HermesLauncherViewModel = preload("res://addons/hermes_os/scripts/os/hermes_shell/chrome/launcher/hermes_launcher_view_model.gd")
const AccountCenterApp = preload("res://addons/hermes_os/scripts/apps/account_center/account_center_app.gd")
const AccountCenterAppManifest = preload("res://addons/hermes_os/scripts/apps/account_center/account_center_app_manifest.gd")
const CommandPaletteApp = preload("res://addons/hermes_os/scripts/apps/command_palette/command_palette_app.gd")
const CommandPaletteAppManifest = preload("res://addons/hermes_os/scripts/apps/command_palette/command_palette_app_manifest.gd")
const CalculatorApp = preload("res://addons/hermes_os/scripts/apps/calculator/calculator_app.gd")
const CalculatorAppManifest = preload("res://addons/hermes_os/scripts/apps/calculator/calculator_app_manifest.gd")
const MediaPlayerApp = preload("res://addons/hermes_os/scripts/apps/media_player/media_player_app.gd")
const MediaPlayerAppManifest = preload("res://addons/hermes_os/scripts/apps/media_player/media_player_app_manifest.gd")
const HermesProtocol = preload("res://addons/hermes_os/scripts/hermes/hermes_protocol.gd")
const HermesAgentService = preload("res://addons/hermes_os/scripts/os/agent/hermes_agent_service.gd")
const AgentOperationRouter = preload("res://addons/hermes_os/scripts/os/agent/agent_operation_router.gd")
const BrowserApp = preload("res://addons/hermes_os/scripts/apps/browser_app.gd")

signal notification_created(notification_id: String)
signal notification_clicked(notification_id: String)
signal notification_dismissed(notification_id: String)
signal hermes_event(event_name: String, payload: Dictionary)

var _apps: Dictionary = {}
var _app_order: Array[String] = []
var _app_registry: AppRegistry
var _os_action_registry: OSActionRegistry
var _app_instances: Dictionary = {}
var _app_instances_by_app: Dictionary = {}
var _app_instance_by_app: Dictionary = {} # TODO(redesign): compatibility mirror; stores most recent instance id per app.
var _window_to_app_instance: Dictionary = {}
var _next_app_instance_id: int = 1
var _open_windows: Dictionary = {}
var _task_buttons: Dictionary = {}
var _active_window: OSWindow
var _shell_overlay_content_occluded: bool = false
var _window_cascade: int = 0
var _event_bus: OSEventBus
var _notification_center: NotificationCenter
var _window_manager: WindowManager
var _hermes_agent_service: HermesAgentService
var _agent_operation_router: AgentOperationRouter
var _fs: OSFileSystem

var _desktop_bg: ColorRect
var _desktop_wallpaper: TextureRect
var _desktop_layer: Control
var _desktop_icons: Control
var _desktop_context_menu: Panel
var _desktop_status_label: Label
var _desktop_actions_separator: HSeparator
var _desktop_rename_input: LineEdit
var _desktop_rename_button: Button
var _desktop_delete_button: Button
var _desktop_general_actions: Array[Control] = []
var _desktop_selected_path: String = ""
var _desktop_selected_paths: Dictionary = {}
var _desktop_icon_positions: Dictionary = {}
var _desktop_file_icon: Texture2D
var _desktop_folder_icon: Texture2D
var _desktop_drag_rect: ColorRect
var _desktop_drag_selecting: bool = false
var _desktop_drag_start: Vector2 = Vector2.ZERO
var _desktop_drag_current: Vector2 = Vector2.ZERO
var _desktop_dragging_icon: Button
var _desktop_drag_icon_offset: Vector2 = Vector2.ZERO
var _desktop_drag_icon_moved: bool = false
var _desktop_highlight_color: Color = Tokens.alpha(Tokens.ACCENT, 0.25)
var _user_accent_color: Color = Tokens.ACCENT
var _window_layer: Control
var _taskbar_windows: Control
var _top_panel: Panel
var _snap_assist_enabled: bool = true
var _dock_panel: Panel
var _start_button: Button
var _status_icons_row: HBoxContainer
var _status_button_defaults: Dictionary = {}
var _status_popover: Panel
var _status_popover_title: Label
var _status_popover_body: Label
var _status_popover_action: Button
var _status_popover_anchor: Control
var _status_popover_action_key: String = ""
var _session_menu_anchor: Control
var _launcher: Panel
var _launcher_frame: VBoxContainer
var _launcher_header_label: Label
var _launcher_user_label: Label
var _avatar_icon_cache: Dictionary = {}
var _launcher_search: LineEdit
var _launcher_scroll: ScrollContainer
var _launcher_list: Control
var _launcher_category_list: Control
var _launcher_footer: Control
var _launcher_filter_text: String = ""
var _launcher_category_filter: String = "all"
var _launcher_buttons: Dictionary = {}
var _launcher_selected_app_id: String = ""
var _session_menu: Panel
var _auth_overlay: Control
var _boot_overlay: Control
var _boot_video_player: VideoStreamPlayer
var _boot_finish_timer: Timer
var _boot_sequence_active := false
var _boot_next_action := "show_auth"
var _boot_target_auth_mode := "login"
var _boot_target_auth_message := ""
var _boot_started_on_startup := false
var _startup_boot_route_pending := false
var _alt_tab_overlay: Panel
var _alt_tab_content: HBoxContainer
var _alt_tab_selected_index: int = 0
var _alt_tab_window_order: Array[OSWindow] = []
var _user_button: Button
var _clock_label: Label
var _notification_button: Button
var _notification_layer: Control
var _notification_history_panel: Panel
var _notification_list: VBoxContainer
var _notification_mute_button: Button
var _notifications: Array[Dictionary] = []
var _notification_sequence: int = 0
var _session_active: bool = false
var _theme_mode: String = "dark"
var _wallpaper_index: int = 0
var _wallpaper_colors: Array[Color] = []
var _dark_wallpaper_colors: Array[Color] = Tokens.WALLPAPER_BRIGHT_PRESETS
var _light_wallpaper_colors: Array[Color] = [
	Color("e7edf7"),
	Color("f1ede4"),
	Color("e8f2ea"),
	Color("f2e8ef"),
	Color("edf0f6")
]
var _wallpaper_images: Array[String] = []
var _current_wallpaper_image: String = ""
var _files_shortcuts: Array[Dictionary] = []
var _notes_active_note_id := ""
var _notes_open_notes: Array[String] = []
var _terminal_sessions: Dictionary = {}
var _terminal_instances: Dictionary = {}
var _terminal_session_sequence := 0
var _next_console_initial_cwd: String = ""
var _console_outputs: Array[TextEdit] = []
var _console_history: Array[String] = ["Type 'help' for commands. Current user: user"]
var _state_save_timer: Timer
var _state_loading := false
var _hermes_ui_window_manifest_cache: Dictionary = {}
var _hermes_shell_context: HermesShellContext
var _shell_fragment_runtime: HermesShellFragmentRuntime
var _launcher_view_model: HermesLauncherViewModel
var _shell_launcher_instance = null
var _shell_taskbar_instance = null

const CONSOLE_HISTORY_MAX_LINES := 400
const HERMES_GATEWAY_CLIENT_ENV_PATH := "res://runtime/hermes_gateway/compose.env"
const HERMES_V1_ALIAS_OPS: Dictionary = {
	"app.open": "windows.open_app",
	"read_file": "files.read_file",
	"readfile": "files.read_file",
	"write_file": "files.write_file",
	"writefile": "files.write_file",
	"create_file": "files.write_file",
	"listdir": "files.list_dir",
	"list_directory": "files.list_dir",
	"mkdir": "files.mkdir",
	"mkdirp": "files.mkdir",
	"create_directory": "files.mkdir",
	"create_folder": "files.mkdir",
	"make_directory": "files.mkdir",
	"makedir": "files.mkdir",
	"delete": "files.delete",
	"remove": "files.delete",
	"move": "files.move",
	"rename": "files.move",
	"copy": "files.copy",
	"files.create_folder": "files.mkdir",
	"files.list_directory": "files.list_dir"
}

const TASKBAR_HEIGHT := 46.0
const TOP_PANEL_HEIGHT := 32.0
const DOCK_HEIGHT := 56.0
const DOCK_BOTTOM_MARGIN := 14.0
const WINDOW_TOP_MARGIN := TOP_PANEL_HEIGHT + 4.0
const WINDOW_BOTTOM_MARGIN := DOCK_HEIGHT + DOCK_BOTTOM_MARGIN + 8.0
const LAUNCHER_MIN_WIDTH := 340.0
const LAUNCHER_MAX_WIDTH := 520.0
const LAUNCHER_MIN_HEIGHT := 280.0
const LAUNCHER_MARGIN := 8.0
const START_BUTTON_TOOLTIP := "Start"
const NOTIFICATIONS_BUTTON_TOOLTIP := "Notification history"
const START_MENU_ICON_SIZE := 22
const DESKTOP_ICON_SIZE := Vector2(118, 86)
const DESKTOP_ICON_GAP := Vector2(14, 10)
const DESKTOP_ICON_MARGIN := Vector2(14, 14)
const PERSISTED_STATE_PATH := "user://hermes_os_shell_state.cfg"
const BOOT_SPLASH_VIDEO_PATH := "res://addons/hermes_os/assets/video/hermes_os_boot_splash_v4.ogv"
const BOOT_SPLASH_DURATION := 7.6
const BOOT_SPLASH_FALLBACK_DURATION := 2.4
const BOOT_SPLASH_HEADLESS_DURATION := 0.05
const HERMES_UI_PRODUCTION_MANIFESTS := {
	"hermes_chat": "res://addons/hermes_os/scripts/apps/hermes_chat/manifest.json",
	"text": "res://addons/hermes_os/scripts/apps/text_editor/manifest.json",
	"notes": "res://addons/hermes_os/scripts/apps/notes/manifest.json",
	"system": "res://addons/hermes_os/scripts/apps/system_settings/manifest.json",
	"files": "res://addons/hermes_os/scripts/apps/files/manifest.json",
	"browser": "res://addons/hermes_os/scripts/apps/browser/manifest.json",
	"console": "res://addons/hermes_os/scripts/apps/terminal/manifest.json",
	"command_palette": "res://addons/hermes_os/scripts/apps/command_palette/manifest.json"
}
const SHELL_LAUNCHER_MANIFEST := "res://addons/hermes_os/scripts/os/hermes_shell/chrome/launcher/launcher_manifest.json"
const SHELL_TASKBAR_MANIFEST := "res://addons/hermes_os/scripts/os/shell_ui/taskbar_manifest.json"
const WINDOW_SIZE_CLASS_POLICY := {
	"utility": {"default": Vector2(680, 500), "min": Vector2(520, 360)},
	"standard": {"default": Vector2(840, 620), "min": Vector2(660, 460)},
	"document": {"default": Vector2(920, 680), "min": Vector2(720, 500)},
	"dashboard": {"default": Vector2(1020, 720), "min": Vector2(780, 540)},
	"workspace": {"default": Vector2(1080, 720), "min": Vector2(840, 560)}
}
const WINDOW_SIZE_CLASS_FALLBACK := "standard"

const Tokens = preload("res://addons/hermes_os/scripts/os/design_tokens.gd")
const StyleFactory = preload("res://addons/hermes_os/scripts/os/style_factory.gd")
const UIAnimator = preload("res://addons/hermes_os/scripts/os/ui_animator.gd")

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	position = Vector2.ZERO
	_event_bus = OSEventBus.new()
	_event_bus.event_emitted.connect(_on_os_event_bus_event_emitted)
	_event_bus.subscribe(OSEventBus.NOTIFICATION_CREATED, self, &"_on_notification_center_event")
	_event_bus.subscribe(OSEventBus.NOTIFICATION_CLEARED, self, &"_on_notification_center_event")
	_event_bus.subscribe(OSEventBus.WINDOW_OPENED, self, &"_on_window_service_event")
	_event_bus.subscribe(OSEventBus.WINDOW_CLOSED, self, &"_on_window_service_event")
	_event_bus.subscribe(OSEventBus.WINDOW_FOCUSED, self, &"_on_window_service_event")
	_event_bus.subscribe(OSEventBus.WINDOW_MINIMIZED, self, &"_on_window_service_event")
	_event_bus.subscribe(OSEventBus.WINDOW_RESTORED, self, &"_on_window_service_event")
	_notification_center = NotificationCenter.new()
	_notification_center.setup(_event_bus)
	_fs = OSFileSystem.new()
	if _fs.has_signal("file_system_event") and not _fs.file_system_event.is_connected(_on_file_system_event):
		_fs.file_system_event.connect(_on_file_system_event)
	_fs.load_or_create()
	_load_wallpaper_images()
	_apply_theme_mode(_theme_mode, false)
	_console_history = ["Type 'help' for commands. Current user: " + _fs.current_user()]
	_register_apps()
	_setup_action_registry()
	_build_ui()
	_sync_shell_visibility()
	_setup_window_manager()
	_setup_hermes_agent_service()
	_setup_state_save_timer()
	# Check for returning-from-3D-world BEFORE loading state so persisted windows can launch.
	var _skip_boot := false
	if has_node("/root/SceneBridge"):
		var bridge = get_node("/root/SceneBridge")
		if bridge.has_method("was_returning_from_os") and bridge.call("was_returning_from_os"):
			bridge.call("clear_returning_flag")
			_session_active = true
			_skip_boot = true

	_startup_boot_route_pending = true
	_load_persisted_state()
	_startup_boot_route_pending = false
	_update_clock()

	if _skip_boot:
		_boot_sequence_active = false
		_hide_auth_screen()
		_hide_boot_sequence()
		_sync_shell_visibility()
		print("[SceneBridge] Skipping boot — returning to desktop with restored windows")
	else:
		_begin_startup_boot_sequence("show_auth", "login")
	if has_node("/root/HermesOSKernel"):
		var kernel := get_node("/root/HermesOSKernel")
		if kernel and kernel.has_method("register_shell"):
			kernel.call("register_shell", self)

	var clock_timer := Timer.new()
	clock_timer.wait_time = 10.0
	clock_timer.autostart = true
	clock_timer.timeout.connect(_update_clock)
	add_child(clock_timer)

	resized.connect(_layout)

func _begin_startup_boot_sequence(auth_mode: String = "show_auth", auth_route: String = "login") -> void:
	if _boot_started_on_startup:
		return
	_boot_started_on_startup = true
	# Startup policy: always route through login/auth after boot splash.
	_session_active = false
	_begin_boot_sequence(auth_mode, auth_route)

func _should_skip_boot_splash() -> bool:
	var value := OS.get_environment("HERMESOS_SKIP_BOOT").strip_edges().to_lower()
	return value == "1" or value == "true" or value == "yes" or value == "on"

func _setup_window_manager() -> void:
	_window_manager = WindowManager.new()
	_window_manager.setup(_window_layer, _event_bus)
	_window_manager.window_opened.connect(_on_window_manager_window_opened)
	_window_manager.window_closed.connect(_on_window_manager_window_closed)
	_window_manager.window_focused.connect(_on_window_manager_window_focused)
	_window_manager.window_minimized.connect(_on_window_manager_window_minimized)
	_window_manager.window_restored.connect(_on_window_manager_window_restored)
	_window_manager.set_snap_assist_enabled(_snap_assist_enabled)

func _setup_hermes_agent_service() -> void:
	_hermes_agent_service = HermesAgentService.new()
	_hermes_agent_service.os_agent_init({
		"shell": self,
		"event_bus": _event_bus,
		"notification_center": _notification_center,
		"filesystem": _fs,
		"window_manager": _window_manager,
		"app_registry": _app_registry,
		"gateway": _hermes_gateway_config()
	})
	_agent_operation_router = _hermes_agent_service.get_operation_router()

func hermes_agent_service() -> HermesAgentService:
	return _hermes_agent_service

func hermes_operation_router() -> AgentOperationRouter:
	return _agent_operation_router

func _setup_action_registry() -> void:
	_os_action_registry = OSActionRegistry.new()
	_os_action_registry.setup({
		"shell": self,
		"app_registry": _app_registry
	})

func command_action_registry() -> OSActionRegistry:
	if _os_action_registry == null:
		_setup_action_registry()
	return _os_action_registry

func list_command_actions(query: String = "") -> Array:
	if command_action_registry() == null:
		return []
	return command_action_registry().list_actions(query)

func invoke_command_action(action_id: String) -> Dictionary:
	if command_action_registry() == null:
		return {"ok": false, "error": {"code": "ACTION_REGISTRY_UNAVAILABLE", "message": "Action registry unavailable", "details": {}}}
	return command_action_registry().invoke(action_id)

func _hermes_gateway_config() -> Dictionary:
	var gateway_env := _read_gateway_client_env(HERMES_GATEWAY_CLIENT_ENV_PATH)
	var gateway_host := _gateway_config_value(gateway_env, ["HERMESOS_GATEWAY_HOST", "HERMES_GATEWAY_HOST"], "127.0.0.1")
	var gateway_port_text := _gateway_config_value(gateway_env, ["HERMESOS_GATEWAY_PORT", "HERMES_GATEWAY_PORT"], "8643")
	var gateway_port := int(gateway_port_text) if gateway_port_text != "" else 8643
	var gateway_path := _gateway_config_value(gateway_env, ["HERMESOS_GATEWAY_PATH", "HERMES_GATEWAY_PATH"], "/v1/chat/completions")
	var gateway_model := _gateway_config_value(gateway_env, ["HERMESOS_GATEWAY_MODEL", "HERMES_GATEWAY_MODEL_NAME", "HERMES_GATEWAY_MODEL"], "hermesos")
	var gateway_profile_hint := _gateway_config_value(gateway_env, ["HERMESOS_GATEWAY_PROFILE", "HERMES_PROFILE"], "hermesos")
	var gateway_api_key := _gateway_config_value(gateway_env, ["HERMESOS_GATEWAY_API_KEY", "HERMES_GATEWAY_API_KEY"], "")
	return {
		"gateway_host": gateway_host,
		"gateway_port": gateway_port,
		"gateway_path": gateway_path,
		"gateway_api_key": gateway_api_key,
		"gateway_model": gateway_model,
		"gateway_profile_hint": gateway_profile_hint,
		"gateway_config_path": HERMES_GATEWAY_CLIENT_ENV_PATH,
		"gateway_config_present": not gateway_env.is_empty(),
		"gateway_timeout_seconds": 120.0
	}

func _read_gateway_client_env(path: String) -> Dictionary:
	var values: Dictionary = {}
	if not FileAccess.file_exists(path):
		return values
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return values
	var text := file.get_as_text()
	for raw_line in text.split("\n"):
		var line := str(raw_line).strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var separator := line.find("=")
		if separator <= 0:
			continue
		var key := line.substr(0, separator).strip_edges()
		var value := line.substr(separator + 1).strip_edges()
		if value.length() >= 2 and ((value.begins_with("\"") and value.ends_with("\"")) or (value.begins_with("'") and value.ends_with("'"))):
			value = value.substr(1, value.length() - 2)
		values[key] = value
	return values

func _gateway_config_value(file_values: Dictionary, names: Array, default_value: String = "") -> String:
	for name_value in names:
		var name := str(name_value)
		var env_value := OS.get_environment(name).strip_edges()
		if env_value != "":
			return env_value
		if file_values.has(name):
			var file_value := str(file_values.get(name, "")).strip_edges()
			if file_value != "":
				return file_value
	return default_value

func hermes_supported_operations() -> Array[String]:
	if _hermes_agent_service != null:
		return _hermes_agent_service.get_supported_operations()
	if _agent_operation_router != null:
		return _agent_operation_router.get_supported_operations()
	return []

func hermes_describe_operation(operation: String) -> Dictionary:
	if _hermes_agent_service != null:
		return _hermes_agent_service.describe_operation(operation)
	if _agent_operation_router != null:
		return _agent_operation_router.describe_operation(operation)
	return {"operation": operation, "capability": "legacy.compat", "risk": "medium", "mutates_state": false, "description": "Agent operation metadata unavailable", "requires_approval": false}

func _on_window_manager_window_opened(window: OSWindow, _window_id_value: int) -> void:
	if window == null or not is_instance_valid(window):
		return
	_open_windows[window.app_id] = window
	_create_task_button(window.app_id)
	_active_window = window
	_update_task_button(window.app_id, true)
	_update_taskbar_indicators()

func _on_window_manager_window_closed(window_id_value: int, app_id: String) -> void:
	_remove_app_instance_for_window(app_id, window_id_value)
	var remaining_window: OSWindow = null
	if _window_manager != null:
		var remaining_ids := _window_manager.get_window_ids_for_app(StringName(app_id))
		if not remaining_ids.is_empty():
			remaining_window = _window_manager.get_window(int(remaining_ids[remaining_ids.size() - 1]))
	if remaining_window != null:
		_open_windows[app_id] = remaining_window
	else:
		if _open_windows.has(app_id):
			_open_windows.erase(app_id)
		if _task_buttons.has(app_id):
			_task_buttons.erase(app_id)
		_refresh_taskbar_fragment()
		_emit_hermes_event("app.closed", {"app_id": app_id})
	_active_window = _window_manager.get_focused_window() if _window_manager != null else null
	_update_taskbar_indicators()

func _on_window_manager_window_focused(window: OSWindow, _window_id_value: int) -> void:
	if window == null or not is_instance_valid(window):
		return
	var previous_window := _active_window
	if previous_window != null and is_instance_valid(previous_window) and previous_window != window:
		_call_app_lifecycle(previous_window, "os_app_blur")
	_active_window = window
	_open_windows[window.app_id] = window
	_call_app_lifecycle(window, "os_app_focus")
	_update_task_button(window.app_id, true)
	_update_taskbar_indicators()

func _on_window_manager_window_minimized(window: OSWindow, _window_id_value: int) -> void:
	if window == null or not is_instance_valid(window):
		return
	if _active_window == window:
		_call_app_lifecycle(window, "os_app_blur")
		_active_window = null
	_update_task_button(window.app_id, false)
	_update_taskbar_indicators()

func _on_window_manager_window_restored(window: OSWindow, _window_id_value: int) -> void:
	if window == null or not is_instance_valid(window):
		return
	var previous_window := _active_window
	if previous_window != null and is_instance_valid(previous_window) and previous_window != window:
		_call_app_lifecycle(previous_window, "os_app_blur")
	_active_window = window
	_open_windows[window.app_id] = window
	_call_app_lifecycle(window, "os_app_focus")
	_update_task_button(window.app_id, true)
	_update_taskbar_indicators()

func _on_window_service_event(_event_name: StringName, _payload: Dictionary) -> void:
	_update_taskbar_indicators()

func _on_notification_center_event(event_name: StringName, payload: Dictionary) -> void:
	match event_name:
		OSEventBus.NOTIFICATION_CREATED:
			var notification_variant: Variant = payload.get("notification", {})
			if not (notification_variant is Dictionary):
				return
			var notification: Dictionary = (notification_variant as Dictionary).duplicate(true)
			_notifications = _notification_center.get_recent(50) if _notification_center != null else _notifications
			_refresh_notifications()
			_show_notification_toast(notification)
			var notification_id := str(notification.get("id", ""))
			if notification_id != "":
				notification_created.emit(notification_id)
			_emit_hermes_event("notification.shown", {
				"notification_id": notification_id,
				"title": str(notification.get("title", "")),
				"level": str(notification.get("level", "info"))
			})
		OSEventBus.NOTIFICATION_CLEARED:
			_notifications.clear()
			_refresh_notifications()

func _exit_tree() -> void:
	if _shell_fragment_runtime != null:
		_shell_fragment_runtime.teardown()
		_shell_fragment_runtime = null
		_shell_launcher_instance = null
		_shell_taskbar_instance = null
	_save_persisted_state()

func _setup_state_save_timer() -> void:
	if _state_save_timer != null:
		return
	_state_save_timer = Timer.new()
	_state_save_timer.wait_time = 0.35
	_state_save_timer.one_shot = true
	_state_save_timer.timeout.connect(_save_persisted_state)
	add_child(_state_save_timer)

func _queue_state_save() -> void:
	if _state_loading:
		return
	if _state_save_timer == null:
		_save_persisted_state()
		return
	_state_save_timer.start()

func _load_persisted_state() -> bool:
	if not FileAccess.file_exists(PERSISTED_STATE_PATH):
		return false
	var cfg := ConfigFile.new()
	if cfg.load(PERSISTED_STATE_PATH) != OK:
		return false
	var state_variant: Variant = cfg.get_value("shell", "state", {})
	if not (state_variant is Dictionary):
		return false
	_state_loading = true
	var message := import_state(state_variant as Dictionary)
	_state_loading = false
	if message != "":
		push_warning("Could not load HermesOS shell state: " + message)
		return false
	return true

func _save_persisted_state() -> void:
	if _state_loading:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("shell", "state", export_state())
	var err := cfg.save(PERSISTED_STATE_PATH)
	if err != OK:
		push_warning("Could not save HermesOS shell state")

func launch_app(app_id: String) -> OSWindow:
	if not _session_active or _auth_overlay != null:
		return null
	if not _apps.has(app_id):
		push_warning("Unknown app: %s" % app_id)
		return null

	var app: Dictionary = _apps[app_id]
	var single_instance := bool(app.get("single_instance", true))
	if single_instance:
		var existing := _current_window_for_app(app_id)
		if existing != null:
			existing.visible = true
			_focus_window(existing)
			_update_task_button(app_id, true)
			_sync_shell_overlay_content_layers(true)
			return existing

	var app_instance := _create_app_instance(app_id, {})
	var builder := app["builder"] as Callable
	var content := builder.call() as Control
	if content == null:
		_remove_app_instance(app_id, app_instance.instance_id if app_instance != null else 0)
		push_warning("App builder returned null content for: %s" % app_id)
		return null
	var window_options := _resolve_window_launch_options(app_id, app, content)
	var window: OSWindow
	if _window_manager != null:
		window = _window_manager.create_window(StringName(app_id), str(app["title"]), content, window_options)
	else:
		window = OSWindow.new()
		_window_layer.add_child(window)
		window.setup(app_id, str(app["title"]), content)
		window.set_window_size(window_options.get("size", _default_window_size(app_id)))
		window.position = _center_window_position(window)
		_clamp_window_to_layer(window)
		window.close_requested.connect(_on_window_close_requested)
		window.minimize_requested.connect(_on_window_minimize_requested)
		window.focused.connect(_focus_window)
	if window == null:
		_remove_app_instance(app_id, app_instance.instance_id if app_instance != null else 0)
		return null

	_open_windows[app_id] = window
	if app_instance != null and _window_manager != null:
		var manager_window_id := _window_manager.get_window_id(window)
		app_instance.add_window(manager_window_id)
		_window_to_app_instance[manager_window_id] = app_instance.instance_id
		_window_to_app_instance[_window_id(window)] = app_instance.instance_id
		window.set_meta("app_instance_id", app_instance.instance_id)
	elif app_instance != null:
		_window_to_app_instance[_window_id(window)] = app_instance.instance_id
		window.set_meta("app_instance_id", app_instance.instance_id)
	_create_task_button(app_id)
	_focus_window(window)
	_sync_shell_overlay_content_layers(true)
	_update_taskbar_indicators()
	_emit_hermes_event("app.opened", {"app_id": app_id})
	return window

func launch_app_with_context(app_id: String, context: Dictionary) -> OSWindow:
	if context.has("initial_cwd"):
		_next_console_initial_cwd = str(context.get("initial_cwd", ""))
	return launch_app(app_id)

func close_app(app_id: String) -> void:
	var window := _current_window_for_app(app_id)
	if window != null:
		_on_window_close_requested(window)

func _current_window_for_app(app_id: String) -> OSWindow:
	if _window_manager != null:
		var ids := _window_manager.get_window_ids_for_app(StringName(app_id))
		for index in range(ids.size() - 1, -1, -1):
			var window := _window_manager.get_window(int(ids[index]))
			if window != null and is_instance_valid(window):
				return window
	if _open_windows.has(app_id):
		var window := _open_windows[app_id] as OSWindow
		if is_instance_valid(window):
			return window
	return null

func _all_open_windows_in_app_order() -> Array[OSWindow]:
	var result: Array[OSWindow] = []
	if _window_manager == null:
		for app_id in _app_order:
			if _open_windows.has(app_id):
				var window := _open_windows[app_id] as OSWindow
				if is_instance_valid(window):
					result.append(window)
		return result
	for app_id in _app_order:
		var ids := _window_manager.get_window_ids_for_app(StringName(app_id))
		for id in ids:
			var window := _window_manager.get_window(int(id))
			if window != null and is_instance_valid(window):
				result.append(window)
	return result

func _create_app_instance(app_id: String, launch_args: Dictionary = {}) -> AppInstance:
	var instance := AppInstance.new()
	instance.instance_id = _next_app_instance_id
	instance.app_id = StringName(app_id)
	instance.launch_args = launch_args.duplicate(true)
	instance.created_at = Time.get_ticks_msec()
	instance.last_active_at = instance.created_at
	_next_app_instance_id += 1
	_app_instances[instance.instance_id] = instance
	if not _app_instances_by_app.has(app_id):
		_app_instances_by_app[app_id] = []
	var app_instance_ids: Array = _app_instances_by_app[app_id]
	app_instance_ids.append(instance.instance_id)
	_app_instances_by_app[app_id] = app_instance_ids
	_app_instance_by_app[app_id] = instance.instance_id
	return instance

func _remove_app_instance_for_window(app_id: String, window_id_value: int) -> void:
	var instance_id := int(_window_to_app_instance.get(window_id_value, 0))
	if instance_id == 0:
		instance_id = int(_app_instance_by_app.get(app_id, 0))
	if instance_id == 0 or not _app_instances.has(instance_id):
		_window_to_app_instance.erase(window_id_value)
		return
	var instance := _app_instances[instance_id] as AppInstance
	if instance == null:
		_window_to_app_instance.erase(window_id_value)
		return
	instance.remove_window(window_id_value)
	_window_to_app_instance.erase(window_id_value)
	if instance.window_ids.is_empty():
		_remove_app_instance(app_id, instance_id)

func _remove_app_instance(app_id: String, instance_id: int) -> void:
	if instance_id == 0:
		return
	_app_instances.erase(instance_id)
	for key in _window_to_app_instance.keys().duplicate():
		if int(_window_to_app_instance.get(key, 0)) == instance_id:
			_window_to_app_instance.erase(key)
	if _app_instances_by_app.has(app_id):
		var app_instance_ids: Array = _app_instances_by_app[app_id]
		app_instance_ids.erase(instance_id)
		if app_instance_ids.is_empty():
			_app_instances_by_app.erase(app_id)
		else:
			_app_instances_by_app[app_id] = app_instance_ids
	if int(_app_instance_by_app.get(app_id, 0)) == instance_id:
		if _app_instances_by_app.has(app_id):
			var remaining_ids: Array = _app_instances_by_app[app_id]
			_app_instance_by_app[app_id] = int(remaining_ids[remaining_ids.size() - 1]) if not remaining_ids.is_empty() else 0
		else:
			_app_instance_by_app.erase(app_id)

func _call_app_lifecycle(window: OSWindow, method_name: String) -> void:
	if window == null or not is_instance_valid(window):
		return
	_call_app_lifecycle_on_node(window, method_name)

func _call_app_lifecycle_on_node(root: Node, method_name: String) -> void:
	if root == null or not is_instance_valid(root):
		return
	if root.has_method(method_name):
		root.call(method_name)
	for child in root.get_children():
		_call_app_lifecycle_on_node(child, method_name)

func _app_content_allows_close(window: OSWindow) -> bool:
	if window == null or not is_instance_valid(window):
		return true
	return _node_content_allows_close(window)

func _node_content_allows_close(root: Node) -> bool:
	if root == null or not is_instance_valid(root):
		return true
	if root.has_method("os_app_close_requested"):
		var result: Variant = root.call("os_app_close_requested")
		if result is bool and not bool(result):
			return false
	for child in root.get_children():
		if not _node_content_allows_close(child):
			return false
	return true

func _capture_app_instance_state(window: OSWindow) -> void:
	if window == null or not is_instance_valid(window):
		return
	var instance_id := int(window.get_meta("app_instance_id", 0))
	if instance_id == 0 or not _app_instances.has(instance_id):
		return
	var state := _capture_app_state_from_node(window)
	if state.is_empty():
		return
	var instance := _app_instances[instance_id] as AppInstance
	if instance != null:
		instance.state = state.duplicate(true)
		instance.touch()

func _capture_app_state_from_node(root: Node) -> Dictionary:
	if root == null or not is_instance_valid(root):
		return {}
	if root.has_method("os_app_get_state"):
		var result: Variant = root.call("os_app_get_state")
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
	for child in root.get_children():
		var child_state := _capture_app_state_from_node(child)
		if not child_state.is_empty():
			return child_state
	return {}

func _unhandled_key_input(event: InputEvent) -> void:
	if _boot_sequence_active:
		if event is InputEventKey:
			var boot_key_event := event as InputEventKey
			if boot_key_event.pressed and not boot_key_event.echo:
				_finish_boot_sequence()
				get_viewport().set_input_as_handled()
		return
	if not _session_active or _auth_overlay != null:
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ESCAPE:
		if _alt_tab_overlay and _alt_tab_overlay.visible:
			_hide_alt_tab(false)
			get_viewport().set_input_as_handled()
			return
		if _has_visible_overlay():
			_close_shell_overlays()
			get_viewport().set_input_as_handled()
			return
		# No overlays open — exit to 3D world (preserve session)
		if has_node("/root/SceneBridge"):
			var bridge = get_node("/root/SceneBridge")
			var was_active: bool = _session_active
			bridge.call("set_returning_from_os", was_active)
			_save_persisted_state()  # Save state immediately before leaving
			print("[SceneBridge] Esc pressed, session_active=%s, state saved" % was_active)
			get_viewport().set_input_as_handled()
			bridge.call("exit_to_world")
			return
	elif key_event.keycode == KEY_META or (key_event.ctrl_pressed and key_event.keycode == KEY_SPACE):
		_toggle_launcher()
		get_viewport().set_input_as_handled()
	elif key_event.ctrl_pressed and key_event.alt_pressed and key_event.keycode == KEY_T:
		_toggle_window_tiling_mode()
		get_viewport().set_input_as_handled()
	elif key_event.ctrl_pressed and key_event.alt_pressed and key_event.keycode == KEY_F:
		_toggle_focused_window_floating()
		get_viewport().set_input_as_handled()
	elif key_event.ctrl_pressed and key_event.alt_pressed and key_event.keycode == KEY_LEFT:
		_snap_focused_window("left")
		get_viewport().set_input_as_handled()
	elif key_event.ctrl_pressed and key_event.alt_pressed and key_event.keycode == KEY_RIGHT:
		_snap_focused_window("right")
		get_viewport().set_input_as_handled()
	elif key_event.ctrl_pressed and key_event.alt_pressed and key_event.keycode == KEY_UP:
		_snap_focused_window("up")
		get_viewport().set_input_as_handled()
	elif key_event.ctrl_pressed and key_event.alt_pressed and key_event.keycode == KEY_DOWN:
		_snap_focused_window("down")
		get_viewport().set_input_as_handled()
	elif key_event.ctrl_pressed and key_event.alt_pressed and key_event.keycode == KEY_H:
		_focus_relative_tiled_window(-1)
		get_viewport().set_input_as_handled()
	elif key_event.ctrl_pressed and key_event.alt_pressed and key_event.keycode == KEY_L:
		_focus_relative_tiled_window(1)
		get_viewport().set_input_as_handled()
	elif _focused_text_control_should_keep_key(key_event):
		get_viewport().set_input_as_handled()
	elif _launcher and _launcher.visible and key_event.keycode == KEY_DOWN:
		_launcher_select_relative(1)
		get_viewport().set_input_as_handled()
	elif _launcher and _launcher.visible and key_event.keycode == KEY_UP:
		_launcher_select_relative(-1)
		get_viewport().set_input_as_handled()
	elif _launcher and _launcher.visible and key_event.keycode == KEY_ENTER:
		_launcher_activate_selected()
		get_viewport().set_input_as_handled()
	elif key_event.alt_pressed and key_event.keycode == KEY_TAB:
		if not _alt_tab_overlay.visible:
			_show_alt_tab()
		_alt_tab_advance()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_ALT and not key_event.pressed:
		if _alt_tab_overlay.visible:
			_hide_alt_tab(true)
			get_viewport().set_input_as_handled()
	elif key_event.ctrl_pressed and key_event.keycode == KEY_W:
		_close_active_window()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_DELETE:
		if _delete_selected_desktop_items():
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not _session_active or _auth_overlay != null:
		return
	if _launcher == null or not _launcher.visible:
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT and mouse_event.button_index != MOUSE_BUTTON_RIGHT:
		return
	var pointer := get_global_mouse_position()
	if _is_point_inside_control_global(_launcher, pointer):
		return
	_hide_launcher()
	_apply_dock_tooltip_policy()
	_apply_top_panel_tooltip_policy()

func _is_point_inside_control_global(control: Control, point: Vector2) -> bool:
	if control == null or not is_instance_valid(control) or not control.visible:
		return false
	return control.get_global_rect().has_point(point)

func _focused_text_control_should_keep_key(key_event: InputEventKey) -> bool:
	if key_event == null:
		return false
	var keep_key: bool = HermesShellInputGuard.should_preserve_text_editing_key(get_viewport(), key_event)
	if keep_key and _launcher != null and _launcher.visible and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER):
		var controller = _shell_fragment_controller("launcher")
		if controller != null and controller.has_method("focus_search"):
			controller.call("focus_search")
	return keep_key

func _is_text_editing_control(control: Control) -> bool:
	return HermesShellInputGuard.is_text_editing_control(control)

func export_state() -> Dictionary:
	return {
		"notifications": _notification_center.export_state() if _notification_center != null else _notifications.duplicate(true),
		"session": {
			"active": _session_active,
			"theme_mode": _theme_mode,
			"wallpaper_index": _wallpaper_index,
			"current_wallpaper_image": _current_wallpaper_image,
			"desktop_icon_positions": _desktop_icon_positions.duplicate(true),
			"desktop_highlight_color": [_desktop_highlight_color.r, _desktop_highlight_color.g, _desktop_highlight_color.b, _desktop_highlight_color.a],
			"accent_color": [_user_accent_color.r, _user_accent_color.g, _user_accent_color.b],
			"files_shortcuts": _files_shortcuts.duplicate(true),
			"snap_assist_enabled": _snap_assist_enabled
		},
		"windows": _export_window_state()
	}

func _export_window_state() -> Array:
	var windows: Array = []
	for app_id in _open_windows.keys():
		var window: OSWindow = _open_windows[app_id]
		if window == null or not is_instance_valid(window):
			continue
		_capture_app_instance_state(window)
		var entry := {
			"app_id": app_id,
			"position": [window.position.x, window.position.y],
			"size": [window.size.x, window.size.y],
			"minimized": window.visible == false,
		}
		var instance_id := int(window.get_meta("app_instance_id", 0))
		if instance_id > 0 and _app_instances.has(instance_id):
			var instance: AppInstance = _app_instances[instance_id]
			if instance != null:
				entry["app_state"] = instance.export_state()
		windows.append(entry)
	return windows

func _restore_window_state(windows: Array) -> void:
	for entry in windows:
		if not (entry is Dictionary):
			continue
		var app_id: String = str(entry.get("app_id", ""))
		if app_id == "" or not _apps.has(app_id):
			continue
		var window := launch_app(app_id)
		if window == null:
			continue
		var pos_arr = entry.get("position", [])
		if pos_arr is Array and pos_arr.size() >= 2:
			window.position = Vector2(float(pos_arr[0]), float(pos_arr[1]))
		var size_arr = entry.get("size", [])
		if size_arr is Array and size_arr.size() >= 2:
			window.size = Vector2(float(size_arr[0]), float(size_arr[1]))
		if bool(entry.get("minimized", false)):
			window.visible = false
		var saved_app_state = entry.get("app_state", {})
		if saved_app_state is Dictionary and not saved_app_state.is_empty():
			var instance_id := int(window.get_meta("app_instance_id", 0))
			if instance_id > 0 and _app_instances.has(instance_id):
				var instance: AppInstance = _app_instances[instance_id]
				if instance != null and saved_app_state.has("state"):
					instance.state = saved_app_state["state"].duplicate(true)
					_reload_app_state_for_window(window)

func _reload_app_state_for_window(window: OSWindow) -> void:
	if window == null or not is_instance_valid(window):
		return
	var instance_id := int(window.get_meta("app_instance_id", 0))
	if instance_id == 0 or not _app_instances.has(instance_id):
		return
	var instance: AppInstance = _app_instances[instance_id]
	if instance == null:
		return
	_apply_app_state_to_node(window, instance.state)

func _apply_app_state_to_node(root: Node, app_state: Dictionary) -> void:
	if root == null or not is_instance_valid(root):
		return
	if root.has_method("os_app_set_state"):
		root.call("os_app_set_state", app_state)
		return
	for child in root.get_children():
		_apply_app_state_to_node(child, app_state)

func import_state(state: Dictionary) -> String:
	# Account/filesystem state is canonical in OSFileSystem.SAVE_PATH (user://hermes_os_files.json).
	# Older shell state files may contain a stale "filesystem" snapshot; never import it here,
	# because doing so overwrites the live account store during startup and can resurrect @user.
	var notification_state: Variant = state.get("notifications", [])
	_notifications.clear()
	_notification_sequence = 0
	if _notification_center != null:
		_notification_center.import_state(notification_state if notification_state is Array else [])
		_notifications = _notification_center.get_recent(50)
		for notification in _notifications:
			_notification_sequence = maxi(_notification_sequence, int(str(notification.get("id", "0")).trim_prefix("n_")))
	elif notification_state is Array:
		for item in notification_state:
			if item is Dictionary:
				var notification: Dictionary = item
				_notifications.append(notification.duplicate(true))
				_notification_sequence = maxi(_notification_sequence, int(str(notification.get("id", "0")).trim_prefix("n_")))
	_refresh_notifications()
	var session: Dictionary = state.get("session", {}) if state.get("session", {}) is Dictionary else {}
	_apply_theme_mode(str(session.get("theme_mode", _theme_mode)), false)
	_wallpaper_index = clampi(int(session.get("wallpaper_index", _wallpaper_index)), 0, _wallpaper_colors.size() - 1)
	_current_wallpaper_image = str(session.get("current_wallpaper_image", _current_wallpaper_image))
	_snap_assist_enabled = bool(session.get("snap_assist_enabled", _snap_assist_enabled))
	if _window_manager != null:
		_window_manager.set_snap_assist_enabled(_snap_assist_enabled)
	_session_active = bool(session.get("active", _session_active))
	_desktop_icon_positions = session.get("desktop_icon_positions", {}).duplicate(true) if session.get("desktop_icon_positions", {}) is Dictionary else {}
	_set_desktop_highlight_color(_color_from_variant(session.get("desktop_highlight_color", []), _desktop_highlight_color))
	_update_system_accent(_color_from_variant(session.get("accent_color", []), Tokens.ACCENT), false)
	_files_shortcuts = _files_sanitize_shortcuts(session.get("files_shortcuts", []), _fs.home_path())
	_close_all_windows()
	var windows_state: Variant = state.get("windows", [])
	if windows_state is Array:
		_restore_window_state(windows_state)
	_hide_desktop_context_menu()
	if _launcher:
		_launcher.visible = false
	if _session_menu:
		_session_menu.visible = false
	if _status_popover:
		_status_popover.visible = false
	_apply_wallpaper()
	_refresh_desktop_icons()
	_update_clock()
	if _session_active:
		_hide_auth_screen()
	elif _startup_boot_route_pending:
		_hide_auth_screen()
	else:
		_show_auth_screen("login")
	_queue_state_save()
	return ""

func reset_state() -> void:
	_fs.reset()
	if _notification_center != null:
		_notification_center.reset()
	_notifications.clear()
	_notification_sequence = 0
	_refresh_notifications()
	_apply_theme_mode("dark", false)
	_wallpaper_index = 0
	_desktop_icon_positions.clear()
	_files_shortcuts.clear()
	_set_desktop_highlight_color(Tokens.alpha(Tokens.ACCENT, 0.25))
	_update_system_accent(Color("6fa8f7"), false)
	_session_active = false
	_close_all_windows()
	_hide_desktop_context_menu()
	_apply_wallpaper()
	_refresh_desktop_icons()
	_update_clock()
	_begin_boot_sequence("show_auth", "login")
	_queue_state_save()

func _register_apps() -> void:
	_app_registry = AppRegistry.new()
	_app_registry.register_app(FilesAppManifest.manifest(Callable(self, "_build_files_app")))
	_app_registry.register_app(NotesAppManifest.manifest(Callable(self, "_build_notes_app")))
	_app_registry.register_app(TextEditorAppManifest.manifest(Callable(self, "_build_text_app")))
	_app_registry.register_app({"id": &"browser", "title": "Browser", "name": "Browser", "description": "Web and local pages.", "subtitle": "Web and local pages", "keywords": "web internet", "category": "Internet", "pinned": true, "single_instance": true, "agent_visible": true, "agent_actions": ["browser.navigate", "browser.get_current_page"], "builder": Callable(self, "_build_browser_app")})
	_app_registry.register_app(TerminalAppManifest.manifest(Callable(self, "_build_console_app")))
	_app_registry.register_app(HermesChatManifest.manifest(Callable(self, "_build_hermes_chat_app")))
	_app_registry.register_app(SystemSettingsAppManifest.manifest(Callable(self, "_build_system_app")))
	_app_registry.register_app(AccountCenterAppManifest.manifest(Callable(self, "_build_account_center_app")))
	_app_registry.register_app(CommandPaletteAppManifest.manifest(Callable(self, "_build_command_palette_app")))
	_app_registry.register_app(CalculatorAppManifest.manifest(Callable(self, "_build_calculator_app")))
	_app_registry.register_app(MediaPlayerAppManifest.manifest(Callable(self, "_build_media_player_app")))
	# TODO(redesign): remove these compatibility mirrors once launcher/taskbar/app lifecycle fully read from AppRegistry.
	_apps = _app_registry.export_legacy_apps()
	_app_order = _app_registry.get_app_order()
	if _os_action_registry != null:
		_os_action_registry.setup({"shell": self, "app_registry": _app_registry})

func _apply_theme_mode(mode: String, refresh_ui: bool = true) -> void:
	_theme_mode = "light" if mode.to_lower() == "light" else "dark"
	if _theme_mode == "light":
		_wallpaper_colors = _light_wallpaper_colors.duplicate()
		Tokens.BG = Color("edf0f6")
		Tokens.BG_ELEVATED = Color("f7f8fb")
		Tokens.PANEL = Color("ffffff")
		Tokens.SURFACE = Color("f4f6fa")
		Tokens.SURFACE_HOVER = Color("e7ebf2")
		Tokens.SURFACE_ACTIVE = Color("dce3ee")
		Tokens.WINDOW = Tokens.BG_ELEVATED
		Tokens.INPUT_BG = Color("ffffff")
		Tokens.BORDER_SOFT = Color("dbe2ed")
		Tokens.BORDER = Color("c7cfdd")
		Tokens.BORDER_ACTIVE = Color("9aa9c0")
		Tokens.BORDER_STRONG = Color("76859c")
		Tokens.TEXT = Color("1c2433")
		Tokens.TEXT_MUTED = Color("5f6b7d")
		Tokens.TEXT_FAINT = Color("7d8798")
		Tokens.MUTED = Tokens.TEXT_MUTED
		Tokens.TEXT_DISABLED = Color("9aa4b4")
	else:
		_wallpaper_colors = _dark_wallpaper_colors.duplicate()
		Tokens.BG = Color("0b0d12")
		Tokens.BG_ELEVATED = Color("11141b")
		Tokens.PANEL = Color("171a22")
		Tokens.SURFACE = Color("1f2430")
		Tokens.SURFACE_HOVER = Color("272d3a")
		Tokens.SURFACE_ACTIVE = Color("303747")
		Tokens.WINDOW = Tokens.BG_ELEVATED
		Tokens.INPUT_BG = Color("0f131a")
		Tokens.BORDER_SOFT = Color("252b38")
		Tokens.BORDER = Color("3b4355")
		Tokens.BORDER_ACTIVE = Color("4b556d")
		Tokens.BORDER_STRONG = Color("616d88")
		Tokens.TEXT = Color("eceff6")
		Tokens.TEXT_MUTED = Color("9aa3b8")
		Tokens.TEXT_FAINT = Color("737d94")
		Tokens.MUTED = Tokens.TEXT_MUTED
		Tokens.TEXT_DISABLED = Color("5f687d")
	if _icon_atlas != null:
		_icon_atlas.set_icon_color(Tokens.TEXT)
	# Re-apply user accent (preserves across theme toggle).
	_update_system_accent(_user_accent_color, false)
	if refresh_ui:
		_apply_wallpaper()
		_refresh_shell_icons()
		_refresh_desktop_icons()
		_rebuild_launcher_list()
		_queue_state_save()

func _refresh_shell_icons() -> void:
	_ensure_icon_atlas()
	if _start_button:
		_start_button.icon = _icon_atlas.get_icon("start", 22)
	# Refresh start button accent tint when tokens change (theme/accent update).
	var taskbar_controller = _shell_fragment_controller("taskbar")
	if taskbar_controller != null and taskbar_controller.has_method("refresh_start_button_accent"):
		taskbar_controller.call("refresh_start_button_accent")
	if _status_icons_row:
		var status_keys: Array[String] = ["wifi", "volume", "bluetooth", "battery", "power", "notification", "user"]
		var index: int = 0
		for child in _status_icons_row.get_children():
			var button: Button = child as Button
			if button != null and index < status_keys.size():
				button.icon = _icon_atlas.get_icon(status_keys[index], 18)
				index += 1
	if _launcher_category_list:
		var categories: Array[String] = ["all", "Favorites", "Internet", "Office", "Programming", "System", "Administration"]
		var category_index: int = 0
		for child in _launcher_category_list.get_children():
			var button: Button = child as Button
			if button != null and category_index < categories.size():
				button.icon = _category_icon(categories[category_index])
			category_index += 1

func _apply_wallpaper() -> void:
	if not _desktop_bg:
		return
	if _current_wallpaper_image != "":
		if _desktop_wallpaper == null:
			_desktop_wallpaper = TextureRect.new()
			_desktop_wallpaper.set_anchors_preset(Control.PRESET_FULL_RECT)
			_desktop_wallpaper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_desktop_wallpaper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			_desktop_wallpaper.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			_desktop_wallpaper.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_desktop_wallpaper)
		var tex := load(_current_wallpaper_image) as Texture2D
		if tex:
			_desktop_wallpaper.texture = tex
			_desktop_wallpaper.visible = true
			_desktop_bg.visible = false
			if _desktop_layer and _desktop_wallpaper.get_parent() == self:
				move_child(_desktop_wallpaper, 0)
			return
	# color mode
	if _desktop_wallpaper:
		_desktop_wallpaper.visible = false
	_desktop_bg.visible = true
	if _wallpaper_colors.is_empty():
		_desktop_bg.color = Tokens.DESKTOP_GRADIENT_TOP
		return
	_wallpaper_index = clampi(_wallpaper_index, 0, _wallpaper_colors.size() - 1)
	_desktop_bg.color = _wallpaper_colors[_wallpaper_index]

func _build_ui() -> void:
	_desktop_bg = ColorRect.new()
	_desktop_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_wallpaper()
	add_child(_desktop_bg)

	_desktop_layer = Control.new()
	_desktop_layer.name = "DesktopLayer"
	_desktop_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_desktop_layer.offset_top = WINDOW_TOP_MARGIN
	_desktop_layer.offset_bottom = -WINDOW_BOTTOM_MARGIN
	_desktop_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_desktop_layer.gui_input.connect(_on_desktop_gui_input)
	add_child(_desktop_layer)
	_build_desktop_icons()

	_window_layer = Control.new()
	_window_layer.name = "WindowLayer"
	_window_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_window_layer.offset_top = WINDOW_TOP_MARGIN
	_window_layer.offset_bottom = -WINDOW_BOTTOM_MARGIN
	_window_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_window_layer)

	_build_taskbar()
	_build_launcher()
	_build_session_menu()
	_build_status_popover()
	_build_desktop_context_menu()
	_build_notification_history_panel()
	_build_notification_layer()
	_build_alt_tab_overlay()
	_layout()

	# z-order fixes per suggested layering (back to front): desktop wallpaper, icons, windows, dock/top bar shell, start menu overlays, tooltips, modals (front)
	# Start Menu above desktop/dock as intentional overlay. Dock not competing with Start Menu.
	_window_layer.z_index = 0
	_top_panel.z_index = 5
	_dock_panel.z_index = 5
	_launcher.z_index = 10

func _build_taskbar() -> void:
	_top_panel = Panel.new()
	_top_panel.name = "TopPanel"
	_top_panel.anchor_left = 0.0
	_top_panel.anchor_right = 1.0
	_top_panel.anchor_top = 0.0
	_top_panel.anchor_bottom = 0.0
	_top_panel.offset_bottom = TOP_PANEL_HEIGHT
	_top_panel.add_theme_stylebox_override("panel", StyleFactory.top_panel())
	add_child(_top_panel)

	var top_row := HBoxContainer.new()
	top_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	top_row.offset_left = 12
	top_row.offset_right = -12
	top_row.offset_top = 4
	top_row.offset_bottom = -4
	top_row.add_theme_constant_override("separation", 10)
	_top_panel.add_child(top_row)

	var left_row := HBoxContainer.new()
	left_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_row.add_theme_constant_override("separation", 8)
	top_row.add_child(left_row)

	var workspaces_button := _button("Workspaces", Vector2(0, 24))
	workspaces_button.flat = true
	workspaces_button.add_theme_color_override("font_color", Tokens.TEXT)
	left_row.add_child(workspaces_button)
	var apps_button := _button("Applications", Vector2(0, 24))
	apps_button.flat = true
	apps_button.pressed.connect(_toggle_launcher)
	apps_button.add_theme_color_override("font_color", Tokens.TEXT)
	left_row.add_child(apps_button)

	_clock_label = Label.new()
	_clock_label.custom_minimum_size = Vector2(180, 0)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clock_label.add_theme_color_override("font_color", Tokens.TEXT)
	_clock_label.add_theme_font_size_override("font_size", 14)
	top_row.add_child(_clock_label)

	_status_icons_row = HBoxContainer.new()
	_status_icons_row.alignment = BoxContainer.ALIGNMENT_END
	_status_icons_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_icons_row.add_theme_constant_override("separation", 4)
	top_row.add_child(_status_icons_row)

	var tray_items: Array[Dictionary] = [
		{"key": "network", "label": "Network", "icon": "wifi", "status": "Connected", "detail": "Wi-Fi connection is active."},
		{"key": "audio", "label": "Audio", "icon": "volume", "status": "Output ready", "detail": "System sound output is available."},
		{"key": "bluetooth", "label": "Bluetooth", "icon": "bluetooth", "status": "Unavailable", "detail": "No paired devices connected."},
		{"key": "battery", "label": "Battery", "icon": "battery", "status": "No battery detected", "detail": "This device is running on AC power."},
		{"key": "power", "label": "Power", "icon": "power", "status": "", "detail": ""},
		{"key": "notification", "label": "Notifications", "icon": "notification", "status": "", "detail": ""},
		{"key": "account", "label": "Account", "icon": "user", "status": "", "detail": ""}
	]
	_status_button_defaults.clear()
	for item in tray_items:
		var icon_button := _icon_button(str(item.get("icon", "placeholder")), Vector2(28, 24))
		var item_key := str(item.get("key", "status"))
		var label_text := str(item.get("label", "Status"))
		var default_tooltip := label_text if label_text in ["Power", "Notifications", "Account"] else label_text + ": " + str(item.get("status", "Status available"))
		icon_button.tooltip_text = default_tooltip
		_status_button_defaults[item_key] = default_tooltip
		if label_text == "Power":
			icon_button.name = "PowerMenuButton"
			icon_button.pressed.connect(_toggle_session_menu_from_button.bind(icon_button))
		elif label_text == "Notifications":
			icon_button.name = "NotificationStatusButton"
			icon_button.pressed.connect(_toggle_notification_history)
		elif label_text == "Account":
			icon_button.name = "AccountStatusButton"
			icon_button.pressed.connect(_open_account_settings)
		else:
			icon_button.name = label_text + "StatusButton"
			icon_button.pressed.connect(_toggle_status_popover.bind(item_key, label_text, str(item.get("status", "")), str(item.get("detail", "")), icon_button))
		_status_icons_row.add_child(icon_button)

	_dock_panel = Panel.new()
	_dock_panel.name = "Dock"
	_dock_panel.anchor_left = 0.5
	_dock_panel.anchor_right = 0.5
	_dock_panel.anchor_top = 1.0
	_dock_panel.anchor_bottom = 1.0
	_dock_panel.offset_left = -320
	_dock_panel.offset_right = 320
	_dock_panel.offset_top = -DOCK_HEIGHT - DOCK_BOTTOM_MARGIN
	_dock_panel.offset_bottom = -DOCK_BOTTOM_MARGIN
	# Dock: glass_surface_outer pill (remove rectangular backplate/shadow layer)
	_dock_panel.add_theme_stylebox_override("panel", StyleFactory.glass_surface_outer(24))
	add_child(_dock_panel)
	_mount_taskbar_fragment()

func _build_launcher() -> void:
	_launcher = Panel.new()
	_launcher.name = "Launcher"
	_launcher.visible = false
	_launcher.clip_contents = true
	_launcher.size = _compute_launcher_size(get_viewport_rect().size)
	# Launcher host is layout-only; visible surface is owned by launcher-window in launcher.hss.
	var launcher_host_box := StyleBoxFlat.new()
	launcher_host_box.bg_color = Color(0, 0, 0, 0)
	launcher_host_box.border_width_left = 0
	launcher_host_box.border_width_top = 0
	launcher_host_box.border_width_right = 0
	launcher_host_box.border_width_bottom = 0
	launcher_host_box.shadow_size = 0
	_launcher.add_theme_stylebox_override("panel", launcher_host_box)
	add_child(_launcher)
	_mount_launcher_fragment()
	_rebuild_launcher_list()
	_refresh_launcher_header()

func _ensure_shell_fragment_runtime() -> HermesShellFragmentRuntime:
	if _launcher_view_model == null:
		_launcher_view_model = HermesLauncherViewModel.new().setup(_app_registry)
	else:
		_launcher_view_model.set_app_registry(_app_registry)
	_hermes_shell_context = HermesShellContext.new().setup(_hermes_shell_context_values())
	if _shell_fragment_runtime == null:
		_shell_fragment_runtime = HermesShellFragmentRuntime.new().setup(_hermes_shell_context)
	else:
		_shell_fragment_runtime.setup(_hermes_shell_context)
	return _shell_fragment_runtime

func _hermes_shell_context_values() -> Dictionary:
	return {
		"shell": self,
		"filesystem": _fs,
		"event_bus": _event_bus,
		"window_manager": _window_manager,
		"app_registry": _app_registry,
		"notification_center": _notification_center,
		"agent_service": _hermes_agent_service,
		"launcher_host": _launcher,
		"launcher_view_model": _launcher_view_model,
		"launcher_search": _launcher_filter_text,
		"launcher_category": _launcher_category_filter,
		"launcher_selected_app_id": _launcher_selected_app_id,
		"launcher_set_search": Callable(self, "_launcher_set_search"),
		"launcher_set_category": Callable(self, "_launcher_set_category"),
		"launcher_set_selected_app": Callable(self, "_launcher_set_selected_app"),
		"launcher_hide": Callable(self, "_hide_launcher_fast"),
		"launcher_launch_app": Callable(self, "launch_app"),
		"launcher_open_account": Callable(self, "_open_account_settings"),
		"launcher_lock_session": Callable(self, "lock_session"),
		"launcher_toggle_session_menu": Callable(self, "_toggle_session_menu")
	}

func _launcher_set_search(text: String) -> void:
	_launcher_filter_text = text

func _launcher_set_category(category: String) -> void:
	_launcher_category_filter = category.strip_edges()
	if _launcher_category_filter == "":
		_launcher_category_filter = "all"

func _launcher_set_selected_app(app_id: String) -> void:
	_launcher_selected_app_id = app_id.strip_edges()

func _mount_launcher_fragment() -> void:
	if _launcher == null:
		return
	_shell_launcher_instance = _ensure_shell_fragment_runtime().mount_fragment("launcher", SHELL_LAUNCHER_MANIFEST, _launcher, {"shell": self, "launcher_host": _launcher, "launcher_view_model": _launcher_view_model})
	_sync_shell_launcher_controls()

func _mount_taskbar_fragment() -> void:
	if _dock_panel == null:
		return
	_shell_taskbar_instance = _ensure_shell_fragment_runtime().mount_fragment("taskbar", SHELL_TASKBAR_MANIFEST, _dock_panel, {"shell": self})
	_sync_shell_taskbar_controls()
	_refresh_taskbar_fragment()

func _shell_fragment_controller(fragment_id: String):
	if _shell_fragment_runtime == null:
		return null
	return _shell_fragment_runtime.get_controller(fragment_id)

func _sync_shell_launcher_controls() -> void:
	if _launcher == null:
		return
	_launcher_frame = _find_hermes_control(_launcher, "launcher-root") as VBoxContainer
	_launcher_header_label = _find_hermes_control(_launcher, "launcher-title") as Label
	_launcher_user_label = _find_hermes_control(_launcher, "launcher-user") as Label
	_launcher_search = _find_hermes_control(_launcher, "launcher-search") as LineEdit
	_launcher_scroll = _find_hermes_control(_launcher, "launcher-apps-scroll") as ScrollContainer
	_launcher_list = _find_hermes_control(_launcher, "launcher-apps")
	_launcher_category_list = _find_hermes_control(_launcher, "launcher-categories")
	_launcher_footer = _find_hermes_control(_launcher, "launcher-footer")
	_sync_launcher_buttons()

func _sync_launcher_buttons() -> void:
	_launcher_buttons.clear()
	for app_id in _app_order:
		var button := _find_hermes_control(_launcher, "launcher-app-" + app_id) as Button
		if button != null:
			_launcher_buttons[app_id] = button

func _sync_shell_taskbar_controls() -> void:
	if _dock_panel == null:
		return
	_start_button = _find_hermes_control(_dock_panel, "taskbar-start") as Button
	_taskbar_windows = _find_hermes_control(_dock_panel, "taskbar-windows")
	_apply_dock_tooltip_policy()
	_sync_task_buttons_from_fragment()

func _sync_task_buttons_from_fragment() -> void:
	_task_buttons.clear()
	if _dock_panel == null:
		return
	for app_id in _app_order:
		var button := _find_hermes_control(_dock_panel, "taskbar-window-" + app_id) as Button
		if button != null:
			_task_buttons[app_id] = button

func _refresh_taskbar_fragment() -> void:
	var controller = _shell_fragment_controller("taskbar")
	if controller != null and controller.has_method("refresh_taskbar"):
		controller.call("refresh_taskbar")
	_sync_shell_taskbar_controls()
	_apply_dock_tooltip_policy()

func _find_hermes_control(node: Node, hermes_id: String) -> Control:
	if node == null:
		return null
	if node is Control and node.has_meta("hermes_id") and str(node.get_meta("hermes_id", "")) == hermes_id:
		return node as Control
	for child in node.get_children():
		var found: Control = _find_hermes_control(child, hermes_id)
		if found != null:
			return found
	return null

func _build_session_menu() -> void:
	_session_menu = Panel.new()
	_session_menu.name = "SessionMenu"
	_session_menu.visible = false
	_session_menu.size = Vector2(304, 324)
	_session_menu.clip_contents = false
	_session_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_session_menu.z_index = 12
	_session_menu.add_theme_stylebox_override("panel", StyleFactory.context_menu(14))
	add_child(_session_menu)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 14
	column.offset_right = -14
	column.offset_top = 14
	column.offset_bottom = -14
	column.add_theme_constant_override("separation", 9)
	_session_menu.add_child(column)

	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", 2)
	column.add_child(identity)

	var user_label := _label(_fs.current_user(), 15, Tokens.TEXT)
	user_label.name = "SessionMenuUser"
	user_label.add_theme_font_size_override("font_size", 15)
	identity.add_child(user_label)

	var home_label := _label(_fs.home_path(), 11, Tokens.MUTED)
	home_label.name = "SessionMenuHome"
	home_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.add_child(home_label)

	var account_button := _button("Account Center", Vector2(0, 36))
	account_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	account_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	account_button.tooltip_text = "Open Account Center"
	account_button.pressed.connect(func() -> void:
		_session_menu.visible = false
		_sync_shell_overlay_content_layers()
		_open_account_settings()
	)
	column.add_child(account_button)

	column.add_child(HSeparator.new())

	for item in [["Lock", "lock"], ["Switch user", "switch"], ["Log out", "logoff"], ["Reboot", "reboot"], ["Shut down", "shutdown"]]:
		var option := _button(str(item[0]), Vector2(0, 36))
		option.alignment = HORIZONTAL_ALIGNMENT_LEFT
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var action_key := str(item[1])
		option.pressed.connect(func() -> void:
			_session_menu.visible = false
			_sync_shell_overlay_content_layers()
			if action_key == "switch":
				switch_user_session()
			else:
				_power_action(action_key)
		)
		column.add_child(option)

func _build_status_popover() -> void:
	_status_popover = Panel.new()
	_status_popover.name = "TopPanelStatusPopover"
	_status_popover.visible = false
	_status_popover.size = Vector2(280, 132)
	_status_popover.clip_contents = false
	_status_popover.mouse_filter = Control.MOUSE_FILTER_STOP
	_status_popover.z_index = 12
	_status_popover.add_theme_stylebox_override("panel", StyleFactory.context_menu(14))
	add_child(_status_popover)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 14
	column.offset_right = -14
	column.offset_top = 14
	column.offset_bottom = -14
	column.add_theme_constant_override("separation", 8)
	_status_popover.add_child(column)

	_status_popover_title = _label("Status", 15, Tokens.TEXT)
	_status_popover_title.name = "TopPanelStatusTitle"
	_status_popover_title.add_theme_font_size_override("font_size", 15)
	column.add_child(_status_popover_title)

	_status_popover_body = _label("", 12, Tokens.MUTED)
	_status_popover_body.name = "TopPanelStatusBody"
	_status_popover_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_popover_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_popover_body.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_child(_status_popover_body)

	_status_popover_action = _button("", Vector2(0, 34))
	_status_popover_action.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status_popover_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_popover_action.visible = false
	_status_popover_action.pressed.connect(_on_status_popover_action_pressed)
	column.add_child(_status_popover_action)

func _build_desktop_context_menu() -> void:
	_desktop_context_menu = Panel.new()
	_desktop_context_menu.name = "DesktopContextMenu"
	_desktop_context_menu.visible = false
	_desktop_context_menu.size = Vector2(272, 393)
	_desktop_context_menu.clip_contents = true
	_desktop_context_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_desktop_context_menu.add_theme_stylebox_override("panel", StyleFactory.context_menu(12))
	add_child(_desktop_context_menu)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 10
	column.offset_right = -10
	column.offset_top = 10
	column.offset_bottom = -10
	column.add_theme_constant_override("separation", 5)
	_desktop_context_menu.add_child(column)

	column.add_child(_label("Desktop", 14, Tokens.TEXT))

	_desktop_general_actions.clear()

	var new_file_button := _context_menu_button("New file")
	new_file_button.pressed.connect(func() -> void:
		_hide_desktop_context_menu()
		_create_desktop_item(false)
	)
	column.add_child(new_file_button)
	_desktop_general_actions.append(new_file_button)

	var new_folder_button := _context_menu_button("New folder")
	new_folder_button.pressed.connect(func() -> void:
		_hide_desktop_context_menu()
		_create_desktop_item(true)
	)
	column.add_child(new_folder_button)
	_desktop_general_actions.append(new_folder_button)

	var open_files_button := _context_menu_button("Open Files")
	open_files_button.pressed.connect(func() -> void:
		_hide_desktop_context_menu()
		launch_app("files")
	)
	column.add_child(open_files_button)
	_desktop_general_actions.append(open_files_button)

	var open_terminal_button := _context_menu_button("Open in Terminal")
	open_terminal_button.pressed.connect(func() -> void:
		_hide_desktop_context_menu()
		if has_method("launch_app_with_context"):
			launch_app_with_context("console", {"initial_cwd": _desktop_folder_path()})
		else:
			launch_app("console")
	)
	column.add_child(open_terminal_button)
	_desktop_general_actions.append(open_terminal_button)

	var wallpaper_button := _context_menu_button("Change wallpaper")
	wallpaper_button.pressed.connect(func() -> void:
		_hide_desktop_context_menu()
		_cycle_wallpaper()
	)
	column.add_child(wallpaper_button)
	_desktop_general_actions.append(wallpaper_button)

	var settings_button := _context_menu_button("Desktop settings")
	settings_button.pressed.connect(func() -> void:
		_hide_desktop_context_menu()
		launch_app("system")
	)
	column.add_child(settings_button)
	_desktop_general_actions.append(settings_button)

	_desktop_actions_separator = HSeparator.new()
	column.add_child(_desktop_actions_separator)

	_desktop_rename_input = LineEdit.new()
	_desktop_rename_input.placeholder_text = "Rename selected item"
	_desktop_rename_input.custom_minimum_size = Vector2(0, 30)
	_style_line_edit(_desktop_rename_input)
	_desktop_rename_input.text_submitted.connect(func(_submitted: String) -> void:
		_rename_selected_desktop_item()
	)
	column.add_child(_desktop_rename_input)

	_desktop_rename_button = _context_menu_button("Rename selected")
	_desktop_rename_button.pressed.connect(func() -> void:
		_rename_selected_desktop_item()
	)
	column.add_child(_desktop_rename_button)

	_desktop_delete_button = _context_menu_button("Delete selected")
	_desktop_delete_button.pressed.connect(func() -> void:
		_delete_selected_desktop_items()
	)
	column.add_child(_desktop_delete_button)

	_desktop_status_label = Label.new()
	_desktop_status_label.add_theme_font_size_override("font_size", 12)
	_desktop_status_label.add_theme_color_override("font_color", Tokens.MUTED)
	_desktop_status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_desktop_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_desktop_status_label.custom_minimum_size = Vector2(0, 18)
	_desktop_status_label.visible = false
	column.add_child(_desktop_status_label)
	_update_desktop_context_actions()

func notify(data: Dictionary) -> String:
	if _notification_center != null:
		var notification := _notification_center.notify_from_dict(data)
		_notification_sequence = maxi(_notification_sequence, int(str(notification.get("id", "0")).trim_prefix("n_")))
		return str(notification.get("id", ""))
	_notification_sequence += 1
	var notification_id := "n_" + str(_notification_sequence)
	var notification := {
		"id": notification_id,
		"title": str(data.get("title", "Notification")).strip_edges(),
		"body": str(data.get("body", "")).strip_edges(),
		"app_id": str(data.get("app_id", "system")).strip_edges(),
		"level": str(data.get("level", "info")).strip_edges().to_lower(),
		"timestamp": _time_text(),
		"action": data.get("action", {}) if data.get("action", {}) is Dictionary else {}
	}
	if str(notification["title"]) == "":
		notification["title"] = "Notification"
	_notifications.push_front(notification)
	while _notifications.size() > 50:
		_notifications.pop_back()
	_refresh_notifications()
	_show_notification_toast(notification)
	notification_created.emit(notification_id)
	_emit_hermes_event("notification.shown", {
		"notification_id": notification_id,
		"title": str(notification.get("title", "")),
		"level": str(notification.get("level", "info"))
	})
	return notification_id

func clear_notifications() -> void:
	var dismissed_ids: Array[String] = []
	if _notification_center != null:
		dismissed_ids = _notification_center.clear()
		_notifications.clear()
	else:
		for notification in _notifications:
			var item: Dictionary = notification
			dismissed_ids.append(str(item.get("id", "")))
		_notifications.clear()
	_refresh_notifications()
	for notification_id in dismissed_ids:
		if notification_id != "":
			notification_dismissed.emit(notification_id)

# Mute/unmute control and state update for notification center UI (per notification-behavior-repair-001)
func _toggle_notification_mute() -> void:
	if _notification_center == null:
		return
	if _notification_center.muted:
		_notification_center.unmute()
	else:
		_notification_center.mute()
	_update_mute_button_state()
	# Update topbar notification button tooltip/icon state
	_update_notification_button_mute_state()
	_refresh_notifications()

func _update_mute_button_state() -> void:
	if _notification_mute_button == null or _notification_center == null:
		return
	if _notification_center.muted:
		_notification_mute_button.text = "Unmute notifications"
	else:
		_notification_mute_button.text = "Mute notifications"

func _update_notification_button_mute_state() -> void:
	if _notification_button == null:
		return
	if _notification_center != null and _notification_center.muted:
		_notification_button.tooltip_text = "Notifications (muted - critical only)"
		# Icon state: could change icon but keep simple, use existing icon with note
	else:
		_notification_button.tooltip_text = "Notifications"

func _build_notification_layer() -> void:
	_notification_layer = Control.new()
	_notification_layer.name = "NotificationLayer"
	_notification_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_notification_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notification_layer)
	_notification_layer.move_to_front()

func _build_alt_tab_overlay() -> void:
	_alt_tab_overlay = Panel.new()
	_alt_tab_overlay.name = "AltTabOverlay"
	_alt_tab_overlay.visible = false
	_alt_tab_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_alt_tab_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_alt_tab_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.045, 0.055, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alt_tab_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_top = -80
	_alt_tab_overlay.add_child(center)

	var inner := Panel.new()
	inner.custom_minimum_size = Vector2(420, 130)
	inner.add_theme_stylebox_override("panel", StyleFactory.elevated_panel(1, 0.92, 14))
	center.add_child(inner)

	_alt_tab_content = HBoxContainer.new()
	_alt_tab_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_alt_tab_content.offset_left = 16
	_alt_tab_content.offset_right = -16
	_alt_tab_content.offset_top = 16
	_alt_tab_content.offset_bottom = -16
	_alt_tab_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_alt_tab_content.add_theme_constant_override("separation", 14)
	inner.add_child(_alt_tab_content)

func _build_notification_history_panel() -> void:
	_notification_history_panel = Panel.new()
	_notification_history_panel.name = "NotificationHistory"
	_notification_history_panel.visible = false
	_notification_history_panel.size = Vector2(352, 320)
	_notification_history_panel.add_theme_stylebox_override("panel", StyleFactory.elevated_panel(2, 0.94, 12))
	add_child(_notification_history_panel)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 10
	column.offset_right = -10
	column.offset_top = 10
	column.offset_bottom = -10
	column.add_theme_constant_override("separation", 6)
	_notification_history_panel.add_child(column)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 30)
	header.add_theme_constant_override("separation", 8)
	column.add_child(header)
	var header_title := Label.new()
	header_title.text = "Notifications"
	header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	header_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header_title.add_theme_font_size_override("font_size", 13)
	header_title.add_theme_color_override("font_color", Tokens.TEXT)
	header.add_child(header_title)
	var clear_button := _button("Clear", Vector2(60, 30))
	clear_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clear_button.pressed.connect(clear_notifications)
	header.add_child(clear_button)
	# Visible mute/unmute control added per notification-behavior-repair-001
	_notification_mute_button = _button("Mute notifications", Vector2(140, 30))
	_notification_mute_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_notification_mute_button.pressed.connect(_toggle_notification_mute)
	header.add_child(_notification_mute_button)
	_update_mute_button_state()

	var divider := HSeparator.new()
	column.add_child(divider)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_notification_list = VBoxContainer.new()
	_notification_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notification_list.add_theme_constant_override("separation", 5)
	scroll.add_child(_notification_list)
	_refresh_notifications()

func _toggle_notification_history() -> void:
	if not _session_active:
		return
	_close_shell_overlays("notification_history")
	_notification_history_panel.visible = not _notification_history_panel.visible
	_sync_shell_overlay_content_layers()
	_apply_dock_tooltip_policy()
	_apply_top_panel_tooltip_policy()
	if _notification_history_panel.visible:
		_notification_history_panel.move_to_front()
		_update_mute_button_state()
		_update_notification_button_mute_state()

func _refresh_notifications() -> void:
	if not _notification_list:
		return
	for child in _notification_list.get_children():
		child.queue_free()
	if _notifications.is_empty():
		_notification_list.add_child(_label("No notifications", 12, Tokens.MUTED))
		return
	for notification in _notifications:
		var item: Dictionary = notification
		_notification_list.add_child(_notification_row(item))

func _notification_row(notification: Dictionary) -> Control:
	var button := _button(_notification_summary(notification), Vector2(0, 48))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 12)
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.tooltip_text = str(notification.get("body", ""))
	var normal := StyleFactory.button_normal(6)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	var hover := StyleFactory.button_hover(6)
	hover.content_margin_left = 8
	hover.content_margin_right = 8
	hover.content_margin_top = 4
	hover.content_margin_bottom = 4
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.pressed.connect(func() -> void:
		_handle_notification_clicked(notification)
	)
	return button

func _notification_summary(notification: Dictionary) -> String:
	var title := str(notification.get("title", "Notification")).strip_edges()
	if title == "":
		title = "Notification"
	var level := str(notification.get("level", "info"))
	var body := str(notification.get("body", "")).strip_edges().replace("\n", " ")
	if body.length() > 42:
		body = body.substr(0, 42) + "…"
	var detail := str(notification.get("timestamp", ""))
	if body != "":
		detail += " · " + body
	return "[%s] %s\n%s" % [level, title, detail]

func _show_notification_toast(notification: Dictionary) -> void:
	if not _notification_layer:
		return
	var toast := Panel.new()
	toast.name = "Toast_" + str(notification.get("id", ""))
	toast.size = Vector2(330, 92)
	toast.position = Vector2(maxf(size.x - toast.size.x - 16.0, 16.0), 18.0 + minf(float(_notification_layer.get_child_count()) * 102.0, 306.0))
	toast.mouse_filter = Control.MOUSE_FILTER_STOP
	toast.add_theme_stylebox_override("panel", StyleFactory.toast(str(notification.get("level", "info")), 10))
	_notification_layer.add_child(toast)
	toast.move_to_front()

	var button := _button(_notification_summary(notification), toast.size)
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.pressed.connect(func() -> void:
		_handle_notification_clicked(notification)
		if is_instance_valid(toast):
			toast.queue_free()
	)
	toast.add_child(button)

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 4.0
	timer.timeout.connect(func() -> void:
		if is_instance_valid(toast):
			toast.queue_free()
	)
	toast.add_child(timer)
	timer.start()

func _handle_notification_clicked(notification: Dictionary) -> void:
	var notification_id := str(notification.get("id", ""))
	notification_clicked.emit(notification_id)
	var action: Dictionary = notification.get("action", {}) if notification.get("action", {}) is Dictionary else {}
	if str(action.get("type", "")) == "launch_app":
		var app_id := str(action.get("app_id", ""))
		if app_id != "":
			launch_app(app_id)
	if _notification_history_panel:
		_notification_history_panel.visible = false
	_sync_shell_overlay_content_layers()

func _notification_level_color(level: String) -> Color:
	match level:
		"success":
			return Color("7fb069")
		"warning":
			return Color("d19a66")
		"error":
			return Tokens.ERROR
		"message":
			return Tokens.FOCUS
		_:
			return Tokens.BORDER_ACTIVE

func _notifications_text() -> String:
	if _notifications.is_empty():
		return "No notifications"
	var lines: Array[String] = []
	for notification in _notifications:
		var item: Dictionary = notification
		lines.append("%s %s [%s] %s - %s" % [str(item.get("id", "")), str(item.get("timestamp", "")), str(item.get("level", "info")), str(item.get("title", "Notification")), str(item.get("body", ""))])
	return "\n".join(lines)

func _build_desktop_icons() -> void:
	_desktop_icons = Control.new()
	_desktop_icons.name = "DesktopIcons"
	_desktop_icons.set_anchors_preset(Control.PRESET_FULL_RECT)
	_desktop_icons.offset_left = DESKTOP_ICON_MARGIN.x
	_desktop_icons.offset_top = DESKTOP_ICON_MARGIN.y
	_desktop_icons.offset_right = -DESKTOP_ICON_MARGIN.x
	_desktop_icons.offset_bottom = -DESKTOP_ICON_MARGIN.y
	_desktop_icons.mouse_filter = Control.MOUSE_FILTER_PASS
	_desktop_layer.add_child(_desktop_icons)
	_ensure_icon_atlas()
	_desktop_folder_icon = _icon_atlas.get_icon("folder", 40)
	_desktop_file_icon = _icon_atlas.get_icon("file", 40)
	_desktop_drag_rect = ColorRect.new()
	_desktop_drag_rect.visible = false
	_desktop_drag_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desktop_drag_rect.color = Tokens.alpha(Tokens.ACCENT, 0.15)
	_desktop_layer.add_child(_desktop_drag_rect)

func _refresh_desktop_icons() -> void:
	if not _desktop_icons:
		return
	for child in _desktop_icons.get_children():
		child.queue_free()
	_desktop_drag_selecting = false
	_desktop_dragging_icon = null
	if _desktop_drag_rect:
		_desktop_drag_rect.visible = false
	_desktop_selected_paths.clear()
	_desktop_selected_path = ""
	if not _session_active:
		_update_desktop_context_actions()
		return
	var message := _ensure_desktop_folder()
	_ensure_standard_home_dirs()
	if message != "":
		_set_desktop_context_status(message, true)
		_update_desktop_context_actions()
		return
	var index := 0
	for entry in _fs.list_dir(_desktop_folder_path()):
		var item: Dictionary = entry
		var button := _desktop_icon_button(item)
		_desktop_icons.add_child(button)
		var item_path := str(item.get("path", ""))
		if _desktop_icon_positions.has(item_path):
			_set_desktop_icon_position(button, _desktop_icon_positions[item_path], false)
		else:
			_set_desktop_icon_position(button, _desktop_icon_slot_position(index), false)
		index += 1
	_clamp_all_desktop_icon_positions()
	_update_desktop_context_actions()

func _desktop_icon_button(entry: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = DESKTOP_ICON_SIZE
	button.size = DESKTOP_ICON_SIZE
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.text = str(entry.get("name", "Item"))
	button.icon = _desktop_folder_icon if str(entry.get("type", "file")) == "dir" else _desktop_file_icon
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.tooltip_text = str(entry.get("path", ""))
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Tokens.TEXT)
	button.add_theme_color_override("font_hover_color", Tokens.TEXT)
	button.add_theme_color_override("font_pressed_color", Tokens.TEXT)
	button.add_theme_color_override("font_focus_color", Tokens.TEXT)
	button.add_theme_constant_override("icon_max_width", 34)
	button.set_meta("desktop_path", str(entry.get("path", "")))
	button.set_meta("desktop_is_dir", bool(str(entry.get("type", "file")) == "dir"))
	button.pressed.connect(_on_desktop_icon_pressed.bind(button, false))
	button.gui_input.connect(_on_desktop_icon_gui_input.bind(button, bool(str(entry.get("type", "file")) == "dir")))
	if DisplayServer.get_name() != "headless":
		button.mouse_entered.connect(func() -> void:
			var tw: Tween = button.create_tween()
			tw.set_trans(Tween.TRANS_QUAD)
			tw.set_ease(Tween.EASE_OUT)
			tw.tween_property(button, "scale", Vector2(1.05, 1.05), Tokens.TIME["fast"])
		)
		button.mouse_exited.connect(func() -> void:
			var tw: Tween = button.create_tween()
			tw.set_trans(Tween.TRANS_QUAD)
			tw.set_ease(Tween.EASE_OUT)
			tw.tween_property(button, "scale", Vector2(1.0, 1.0), Tokens.TIME["fast"])
		)
		button.pivot_offset = DESKTOP_ICON_SIZE / 2.0
	_apply_desktop_icon_style(button, false)
	return button

func _desktop_icon_slot_position(index: int) -> Vector2:
	if not _desktop_icons:
		return Vector2.ZERO
	var cell := DESKTOP_ICON_SIZE + DESKTOP_ICON_GAP
	var columns := maxi(int((_desktop_icons.size.x + DESKTOP_ICON_GAP.x) / cell.x), 1)
	var row := int(index / columns)
	var column := int(index % columns)
	return Vector2(column * cell.x, row * cell.y)

func _desktop_icon_bounds() -> Rect2:
	if not _desktop_icons:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	return Rect2(Vector2.ZERO, _desktop_icons.size)

func _set_desktop_icon_position(button: Button, desired_position: Vector2, save_position := true) -> void:
	var bounds := _desktop_icon_bounds()
	var max_x := maxf(bounds.size.x - button.size.x, 0.0)
	var max_y := maxf(bounds.size.y - button.size.y, 0.0)
	button.position = Vector2(clampf(desired_position.x, 0.0, max_x), clampf(desired_position.y, 0.0, max_y))
	if save_position:
		var item_path := str(button.get_meta("desktop_path", ""))
		if item_path != "":
			_desktop_icon_positions[item_path] = button.position
			_queue_state_save()

func _clamp_all_desktop_icon_positions() -> void:
	if not _desktop_icons:
		return
	for child in _desktop_icons.get_children():
		if child is Button:
			_set_desktop_icon_position(child as Button, (child as Button).position, true)

func _apply_desktop_icon_style(button: Button, selected: bool) -> void:
	var border_color := _desktop_highlight_border_color()
	var normal_color := _desktop_highlight_color if selected else Color(0, 0, 0, 0)
	var normal_style := StyleFactory.build(normal_color, border_color if selected else Color.TRANSPARENT, 1 if selected else 0, 10)
	var hover_style := StyleFactory.desktop_icon_hover(10)
	var pressed_style := StyleFactory.build(_desktop_highlight_color, border_color, 1, 10)
	var focus_style := StyleFactory.build(_desktop_highlight_color, border_color, 1, 10)
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("focus", focus_style)

func _desktop_highlight_border_color() -> Color:
	return Color(minf(_desktop_highlight_color.r + 0.16, 1.0), minf(_desktop_highlight_color.g + 0.16, 1.0), minf(_desktop_highlight_color.b + 0.16, 1.0), 0.95)

func _on_desktop_icon_pressed(button: Button, additive := false) -> void:
	var path := str(button.get_meta("desktop_path", ""))
	if path == "":
		return
	if not additive:
		_desktop_selected_paths.clear()
	_desktop_selected_paths[path] = true
	_desktop_selected_path = path
	_update_desktop_icon_selection()

func _on_desktop_icon_gui_input(event: InputEvent, button: Button, is_dir: bool) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			_on_desktop_icon_pressed(button)
			_show_desktop_context_menu(get_global_mouse_position())
			get_viewport().set_input_as_handled()
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_on_desktop_icon_pressed(button, mouse_event.ctrl_pressed)
			if mouse_event.double_click:
				_open_desktop_item(_desktop_icon_path(button), is_dir)
				get_viewport().set_input_as_handled()
				return
			_desktop_drag_selecting = false
			_desktop_dragging_icon = button
			_desktop_drag_icon_offset = mouse_event.position
			_desktop_drag_icon_moved = false
			_hide_desktop_context_menu()
			get_viewport().set_input_as_handled()
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed and _desktop_dragging_icon == button:
			if _desktop_drag_icon_moved:
				var drop_target := _desktop_folder_drop_target(button, mouse_event.global_position)
				if drop_target != null:
					_move_desktop_item_to_folder(button, drop_target)
				else:
					_set_desktop_context_status("Moved " + _desktop_icon_path(button))
			_desktop_dragging_icon = null
			_desktop_drag_icon_moved = false
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and _desktop_dragging_icon == button:
		var motion := event as InputEventMouseMotion
		var target := motion.global_position - _desktop_icons.global_position - _desktop_drag_icon_offset
		if button.position.distance_to(target) > 1.0:
			_desktop_drag_icon_moved = true
		_set_desktop_icon_position(button, target, true)
		get_viewport().set_input_as_handled()

func _update_desktop_icon_selection() -> void:
	if not _desktop_icons:
		return
	for child in _desktop_icons.get_children():
		if child is Button:
			var button := child as Button
			var selected := _desktop_selected_paths.has(_desktop_icon_path(button))
			button.button_pressed = selected
			_apply_desktop_icon_style(button, selected)
	if _desktop_selected_path == "" and not _desktop_selected_paths.is_empty():
		_desktop_selected_path = str(_desktop_selected_paths.keys()[0])
	_update_desktop_context_actions()

func _clear_desktop_icon_selection() -> void:
	_desktop_selected_paths.clear()
	_desktop_selected_path = ""
	_update_desktop_icon_selection()

func _desktop_icon_path(button: Button) -> String:
	return str(button.get_meta("desktop_path", ""))

func _desktop_selected_path_list() -> Array[String]:
	var paths: Array[String] = []
	for key in _desktop_selected_paths.keys():
		paths.append(str(key))
	paths.sort()
	return paths

func _open_desktop_item(path: String, is_dir: bool) -> void:
	if path == "":
		return
	_hide_desktop_context_menu()
	if is_dir:
		_open_files_to_path(path)
		_set_desktop_context_status("Opened folder: " + path.get_file())
		return
	_open_text_file(path)
	_set_desktop_context_status("Opened file in Text: " + path.get_file())

func _delete_selected_desktop_items() -> bool:
	var paths := _desktop_selected_path_list()
	if paths.is_empty():
		if _desktop_selected_path != "":
			paths.append(_desktop_selected_path)
	if paths.is_empty():
		_set_desktop_context_status("Select an icon first", true)
		_update_desktop_context_actions()
		return false
	var deleted := 0
	var used_trash := false
	for item_path in paths:
		var message := ""
		if _fs.has_method("trash_path"):
			var trash_result: Variant = _fs.trash_path(item_path)
			if trash_result is Dictionary:
				var trash_dict: Dictionary = trash_result
				if bool(trash_dict.get("ok", false)):
					used_trash = true
				else:
					var error_value: Variant = trash_dict.get("error", {})
					message = str((error_value as Dictionary).get("message", "Could not move item to Trash")) if error_value is Dictionary else str(error_value)
			elif bool(trash_result):
				used_trash = true
			else:
				message = "Could not move item to Trash"
		else:
			message = _fs.delete_path(item_path)
		if message != "":
			_set_desktop_context_status(message, true)
			continue
		deleted += 1
		_desktop_icon_positions.erase(item_path)
	if deleted == 0:
		return false
	_refresh_desktop_icons()
	_hide_desktop_context_menu()
	_set_desktop_context_status(("Moved %d item(s) to Trash" if used_trash else "Deleted %d item(s)") % deleted)
	_queue_state_save()
	return true

func _rename_selected_desktop_item() -> bool:
	var paths := _desktop_selected_path_list()
	if paths.is_empty() and _desktop_selected_path != "":
		paths.append(_desktop_selected_path)
	if paths.size() != 1:
		_set_desktop_context_status("Select a single item to rename", true)
		_update_desktop_context_actions()
		return false
	var source_path := paths[0]
	var source_name := source_path.get_file()
	var target_name := _desktop_rename_input.text.strip_edges() if _desktop_rename_input else ""
	if target_name == "":
		_set_desktop_context_status("Enter a new name", true)
		return false
	if _fs.is_file(source_path):
		var source_extension := source_name.get_extension()
		if source_extension != "" and target_name.get_extension() == "":
			target_name += "." + source_extension
	if target_name == source_name:
		_set_desktop_context_status("Name unchanged")
		return false
	var message := _fs.rename_path(source_path, target_name)
	if message != "":
		_set_desktop_context_status(message, true)
		return false
	var target_path := _fs.normalize_path(_fs.join_path(_fs.parent_path(source_path), target_name))
	if _desktop_icon_positions.has(source_path):
		_desktop_icon_positions[target_path] = _desktop_icon_positions[source_path]
		_desktop_icon_positions.erase(source_path)
	_refresh_desktop_icons()
	_select_desktop_icon_by_path(target_path)
	if _desktop_rename_input:
		_desktop_rename_input.text = target_name
	_set_desktop_context_status("Renamed to " + target_name)
	_queue_state_save()
	return true

func _select_desktop_icon_by_path(target_path: String) -> void:
	if target_path == "":
		return
	if not _desktop_icons:
		return
	for child in _desktop_icons.get_children():
		if child is Button:
			var button := child as Button
			if _desktop_icon_path(button) == target_path:
				_desktop_selected_paths.clear()
				_desktop_selected_paths[target_path] = true
				_desktop_selected_path = target_path
				_update_desktop_icon_selection()
				return

func _desktop_folder_drop_target(source_button: Button, drop_global: Vector2) -> Button:
	if not _desktop_icons:
		return null
	var drop_local := drop_global - _desktop_icons.global_position
	for child in _desktop_icons.get_children():
		if child is Button:
			var target := child as Button
			if target == source_button:
				continue
			if not bool(target.get_meta("desktop_is_dir", false)):
				continue
			if Rect2(target.position, target.size).has_point(drop_local):
				return target
	return null

func _move_desktop_item_to_folder(source_button: Button, target_folder_button: Button) -> bool:
	var source_path := _desktop_icon_path(source_button)
	var target_folder_path := _desktop_icon_path(target_folder_button)
	if source_path == "" or target_folder_path == "":
		return false
	var destination := _paste_destination_path(source_path, target_folder_path)
	var message := _fs.move_path(source_path, destination)
	if message != "":
		_set_desktop_context_status(message, true)
		return false
	_desktop_icon_positions.erase(source_path)
	_refresh_desktop_icons()
	_set_desktop_context_status("Moved to " + target_folder_path.get_file())
	_queue_state_save()
	return true

func _update_desktop_context_actions() -> void:
	if not _desktop_delete_button:
		return
	var selected_count := _desktop_selected_paths.size()
	if selected_count == 0 and _desktop_selected_path != "":
		selected_count = 1
	var single_selected_path := _desktop_selected_path
	if selected_count == 1 and single_selected_path == "" and not _desktop_selected_paths.is_empty():
		single_selected_path = str(_desktop_selected_paths.keys()[0])
	var has_selection := selected_count > 0
	for action in _desktop_general_actions:
		if action != null and is_instance_valid(action):
			action.visible = not has_selection
	if _desktop_actions_separator:
		_desktop_actions_separator.visible = has_selection
	if _desktop_rename_input:
		_desktop_rename_input.visible = selected_count == 1
		if selected_count == 1:
			var selected_name := single_selected_path.get_file()
			var previous_source_path := str(_desktop_rename_input.get_meta("source_path", ""))
			if _desktop_rename_input.text.strip_edges() == "" or previous_source_path != single_selected_path:
				_desktop_rename_input.text = selected_name
				var selected_extension := selected_name.get_extension()
				if selected_extension != "":
					var stem_length := maxi(selected_name.length() - selected_extension.length() - 1, 0)
					_desktop_rename_input.select(0, stem_length)
				else:
					_desktop_rename_input.select_all()
			_desktop_rename_input.set_meta("source_path", single_selected_path)
		else:
			_desktop_rename_input.text = ""
			_desktop_rename_input.set_meta("source_path", "")
	if _desktop_rename_button:
		_desktop_rename_button.visible = selected_count == 1
	_desktop_delete_button.visible = selected_count > 0
	_desktop_delete_button.disabled = selected_count == 0
	_desktop_delete_button.text = "Delete selected" if selected_count <= 1 else "Delete selected (%d)" % selected_count
	_desktop_context_menu.size = Vector2(272, 220 if has_selection else 393)

func _set_desktop_highlight_color(color: Color) -> void:
	_desktop_highlight_color = Color(color.r, color.g, color.b, clampf(color.a, 0.14, 0.7))
	if _desktop_drag_rect:
		_desktop_drag_rect.color = Tokens.alpha(_desktop_highlight_color, minf(_desktop_highlight_color.a * 0.6, 0.45))
	_update_desktop_icon_selection()
	_queue_state_save()

func _update_system_accent(accent: Color, save: bool = true) -> void:
	_user_accent_color = Tokens.set_accent(accent)
	_refresh_shell_icons()
	if save:
		_queue_state_save()

func _desktop_icon_texture(_is_folder: bool) -> Texture2D:
	# DEPRECATED: use IconAtlas instead
	return ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))

func _context_menu_button(text_value: String) -> Button:
	var button := _button(text_value, Vector2(0, 36))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
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

func _on_desktop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _desktop_drag_selecting:
		var motion := event as InputEventMouseMotion
		_desktop_drag_current = motion.position
		_update_desktop_drag_rect_visual()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			_show_desktop_context_menu(get_global_mouse_position())
			get_viewport().set_input_as_handled()
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_close_shell_overlays()
				_clear_desktop_icon_selection()
				_desktop_drag_selecting = true
				_desktop_drag_start = mouse_event.position
				_desktop_drag_current = mouse_event.position
				_update_desktop_drag_rect_visual()
				get_viewport().set_input_as_handled()
			elif _desktop_drag_selecting:
				_desktop_drag_selecting = false
				_select_icons_in_drag_rect()
				if _desktop_drag_rect:
					_desktop_drag_rect.visible = false
				get_viewport().set_input_as_handled()

func _update_desktop_drag_rect_visual() -> void:
	if not _desktop_drag_rect:
		return
	var top_left := Vector2(minf(_desktop_drag_start.x, _desktop_drag_current.x), minf(_desktop_drag_start.y, _desktop_drag_current.y))
	var size_value := Vector2(absf(_desktop_drag_current.x - _desktop_drag_start.x), absf(_desktop_drag_current.y - _desktop_drag_start.y))
	_desktop_drag_rect.position = top_left
	_desktop_drag_rect.size = size_value
	_desktop_drag_rect.visible = size_value.length() >= 4.0

func _select_icons_in_drag_rect() -> void:
	if not _desktop_icons:
		return
	var rect := Rect2(_desktop_drag_rect.position, _desktop_drag_rect.size)
	if rect.size.length() < 4.0:
		return
	_desktop_selected_paths.clear()
	for child in _desktop_icons.get_children():
		if child is Button:
			var button := child as Button
			if rect.intersects(Rect2(button.position, button.size), true):
				_desktop_selected_paths[_desktop_icon_path(button)] = true
	if _desktop_selected_paths.is_empty():
		_desktop_selected_path = ""
	else:
		_desktop_selected_path = str(_desktop_selected_paths.keys()[0])
	_update_desktop_icon_selection()

func _show_desktop_context_menu(global_pos: Vector2) -> void:
	if not _session_active or _auth_overlay != null:
		return
	_close_shell_overlays("desktop_context")
	_desktop_context_menu.position = Vector2(
		clampf(global_pos.x, 8.0, maxf(size.x - _desktop_context_menu.size.x - 8.0, 8.0)),
		clampf(global_pos.y, WINDOW_TOP_MARGIN, maxf(size.y - WINDOW_BOTTOM_MARGIN - _desktop_context_menu.size.y - 8.0, WINDOW_TOP_MARGIN))
	)
	_set_desktop_context_status("")
	_update_desktop_context_actions()
	_desktop_context_menu.visible = true
	_desktop_context_menu.move_to_front()

func _hide_desktop_context_menu() -> void:
	if _desktop_context_menu:
		_desktop_context_menu.visible = false

func _desktop_folder_path() -> String:
	return _fs.join_path(_fs.home_path(), "Desktop")

func _ensure_desktop_folder() -> String:
	var desktop_path := _desktop_folder_path()
	if _fs.is_dir(desktop_path):
		return ""
	return _fs.make_dir(desktop_path)

func _ensure_standard_home_dirs() -> void:
	if _fs == null or not _fs.has_method("home_path"):
		return
	var home := _fs.home_path()
	for dir_name in ["Desktop", "Documents", "Downloads", "Music", "Pictures", "Videos"]:
		var dir_path := _fs.join_path(home, dir_name)
		if not _fs.is_dir(dir_path):
			_fs.make_dir(dir_path)
	# Ensure Trash directories exist
	var local_dir := _fs.join_path(home, ".local")
	var share_dir := _fs.join_path(local_dir, "share")
	var trash_base := _fs.join_path(share_dir, "Trash")
	for trash_dir in [local_dir, share_dir, trash_base, _fs.join_path(trash_base, "files"), _fs.join_path(trash_base, "info")]:
		if not _fs.is_dir(trash_dir):
			_fs.make_dir(trash_dir)

func _create_desktop_item(is_folder: bool) -> void:
	var message := _ensure_desktop_folder()
	_ensure_standard_home_dirs()
	if message != "":
		_set_desktop_context_status(message, true)
		return
	var desktop_path := _desktop_folder_path()
	var base_name := "New Folder" if is_folder else "New File.txt"
	var target_path := _unique_child_path(desktop_path, base_name)
	message = _fs.make_dir(target_path) if is_folder else _fs.write_file(target_path, "")
	if message != "":
		_set_desktop_context_status(message, true)
		return
	_refresh_desktop_icons()
	_set_desktop_context_status("Created " + target_path)

func _unique_child_path(parent_path: String, base_name: String) -> String:
	var clean_parent := _fs.normalize_path(parent_path)
	var stem := base_name.get_basename()
	var extension := base_name.get_extension()
	var candidate_name := base_name
	var index := 2
	while _fs.exists(_fs.join_path(clean_parent, candidate_name)):
		if extension == "":
			candidate_name = "%s %d" % [stem, index]
		else:
			candidate_name = "%s %d.%s" % [stem, index, extension]
		index += 1
	return _fs.join_path(clean_parent, candidate_name)

func _cycle_wallpaper() -> void:
	_load_wallpaper_images()
	if not _wallpaper_images.is_empty():
		var next_index: int = 0
		if _current_wallpaper_image != "":
			var current_index: int = _wallpaper_images.find(_current_wallpaper_image)
			if current_index >= 0:
				next_index = (current_index + 1) % _wallpaper_images.size()
		_current_wallpaper_image = _wallpaper_images[next_index]
	else:
		_current_wallpaper_image = ""
		_wallpaper_index = (_wallpaper_index + 1) % _wallpaper_colors.size()
	_apply_wallpaper()
	_set_desktop_context_status("Wallpaper changed")
	_queue_state_save()

func _set_wallpaper_image(path: String) -> void:
	var clean_path: String = path.strip_edges()
	if clean_path == "":
		return
	_load_wallpaper_images()
	if not _wallpaper_images.has(clean_path):
		return
	_current_wallpaper_image = clean_path
	_apply_wallpaper()
	_set_desktop_context_status("Wallpaper changed")
	_queue_state_save()

func _load_wallpaper_images() -> void:
	_wallpaper_images.clear()
	var wallpaper_dir := "res://addons/hermes_os/assets/wallpapers"
	var dir := DirAccess.open(wallpaper_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var ext: String = file_name.get_extension().to_lower()
			if ext in ["jpg", "jpeg", "png", "webp"]:
				_wallpaper_images.append(wallpaper_dir.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	_wallpaper_images.sort()

func _set_desktop_context_status(message: String, is_error := false) -> void:
	if not _desktop_status_label:
		return
	var clean_message := message.strip_edges()
	if clean_message == "":
		_desktop_status_label.text = ""
		_desktop_status_label.tooltip_text = ""
		_desktop_status_label.visible = false
		return
	var short_message := clean_message
	if short_message.length() > 64:
		short_message = short_message.substr(0, 64) + "…"
	_desktop_status_label.text = short_message
	_desktop_status_label.tooltip_text = clean_message
	_desktop_status_label.visible = true
	_desktop_status_label.add_theme_color_override("font_color", Tokens.ERROR if is_error else Tokens.MUTED)

func _app_button(app_id: String, min_size: Vector2) -> Button:
	var app: Dictionary = _apps[app_id]
	var subtitle := str(app.get("subtitle", "")).strip_edges()
	var button_text := str(app["title"]) if subtitle == "" else "%s\n%s" % [str(app["title"]), subtitle]
	var button := _button(button_text, min_size)
	button.icon = _app_icon(app_id)
	button.expand_icon = false
	button.add_theme_constant_override("icon_max_width", START_MENU_ICON_SIZE)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 48.0)
	button.tooltip_text = "Open " + str(app["title"])
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(func() -> void:
		_hide_launcher()
		launch_app(app_id)
	)
	return button

func _app_icon(app_id: String) -> Texture2D:
	match app_id:
		"files":
			return _start_menu_icon("folder")
		"notes":
			return _start_menu_icon("notes")
		"text":
			return _start_menu_icon("file")
		"browser":
			return _start_menu_icon("browser")
		"console":
			return _start_menu_icon("terminal")
		"system":
			return _start_menu_icon("settings")
		_:
			return _start_menu_icon("placeholder")

func _start_menu_icon(icon_name: String) -> Texture2D:
	_ensure_icon_atlas()
	return _icon_atlas.get_icon(icon_name, START_MENU_ICON_SIZE)

func _category_icon(category_name: String) -> Texture2D:
	match category_name.to_lower():
		"all":
			return _start_menu_icon("start")
		"favorites":
			return _start_menu_icon("home")
		"internet":
			return _start_menu_icon("browser")
		"office":
			return _start_menu_icon("notes")
		"programming":
			return _start_menu_icon("code")
		"system":
			return _start_menu_icon("settings")
		"administration":
			return _start_menu_icon("settings")
		_:
			return _start_menu_icon("placeholder")

func _user_avatar_icon(username: String) -> Texture2D:
	if _fs == null:
		return _start_menu_icon("user")
	var cache_key := "avatar::" + username
	if _avatar_icon_cache.has(cache_key):
		var cached: Variant = _avatar_icon_cache[cache_key]
		if cached is Texture2D:
			return cached as Texture2D
	var texture: Texture2D = null
	if _fs.has_method("get_user_avatar"):
		var avatar: Variant = _fs.get_user_avatar(username)
		if avatar is Dictionary:
			var avatar_dict: Dictionary = avatar
			var avatar_type := str(avatar_dict.get("type", "initials"))
			var avatar_value := str(avatar_dict.get("value", "")).strip_edges()
			if avatar_type == "asset" and avatar_value.begins_with("res://"):
				var loaded := load(avatar_value)
				if loaded is Texture2D:
					texture = loaded as Texture2D
	if texture == null:
		texture = _start_menu_icon("user")
	_avatar_icon_cache[cache_key] = texture
	return texture

func _open_account_settings() -> void:
	_hide_launcher()
	launch_app("accounts")
	# Notification on open removed to stop noisy Account Center notification (per notification-behavior-repair-001)

func _power_action(action: String) -> void:
	match action:
		"shutdown":
			logout_session()
			notify({"title": "Power", "body": "System powered off (session closed)", "level": "warning", "app_id": "system"})
			if has_node("/root/SceneBridge"):
				var bridge = get_node("/root/SceneBridge")
				bridge.call("set_returning_from_os", false)  # Shutdown = fresh boot next time
				bridge.call("exit_to_world")
		"reboot":
			_close_all_windows()
			_session_active = false
			_begin_boot_sequence("show_auth", "login", "System rebooted")
			_queue_state_save()
		"lock":
			lock_session()
		"logoff":
			logout_session()

func _compute_launcher_size(viewport_size: Vector2) -> Vector2:
	var usable_height := maxf(viewport_size.y - WINDOW_TOP_MARGIN - WINDOW_BOTTOM_MARGIN - (LAUNCHER_MARGIN * 2.0), LAUNCHER_MIN_HEIGHT)
	var width := clampf(viewport_size.x * 0.38, LAUNCHER_MIN_WIDTH, 720.0)
	var height := clampf(usable_height * 0.86, LAUNCHER_MIN_HEIGHT, usable_height)
	return Vector2(width, height)

func _refresh_launcher_header() -> void:
	var controller = _shell_fragment_controller("launcher")
	if controller != null and controller.has_method("refresh_launcher"):
		controller.call("refresh_launcher")
		_sync_shell_launcher_controls()
		return
	if _launcher_header_label:
		_launcher_header_label.text = "Start Menu"
	if _launcher_user_label:
		var user_name := _fs.current_user() if _fs else "user"
		var home := _fs.home_path() if _fs else "~"
		_launcher_user_label.text = "%s  %s" % [user_name, home]

func _hide_launcher_fast() -> void:
	if _launcher:
		_launcher.visible = false
	_sync_shell_overlay_content_layers()

func _hide_launcher() -> void:
	if _launcher:
		_launcher.visible = false
	if _launcher_search:
		_launcher_search.text = ""
	_launcher_filter_text = ""
	_launcher_category_filter = "all"
	_launcher_selected_app_id = ""
	_sync_shell_launcher_controls()
	_sync_shell_overlay_content_layers()

func _launcher_matches_filter(app_id: String) -> bool:
	if not _apps.has(app_id):
		return false
	var app: Dictionary = _apps[app_id]
	if _launcher_category_filter != "all":
		var app_category := str(app.get("category", "")).to_lower()
		if _launcher_category_filter == "favorites":
			if not bool(app.get("pinned", false)):
				return false
		elif app_category != _launcher_category_filter.to_lower():
			return false
	if _launcher_filter_text == "":
		return true
	var normalized_search := _launcher_filter_text.strip_edges().to_lower()
	if normalized_search == "":
		return true
	var haystack := (app_id + " " + str(app.get("title", "")) + " " + str(app.get("subtitle", "")) + " " + str(app.get("keywords", "")) + " " + str(app.get("category", ""))).to_lower()
	return haystack.find(normalized_search) != -1

func _rebuild_launcher_list() -> void:
	var controller = _shell_fragment_controller("launcher")
	if controller != null and controller.has_method("refresh_launcher"):
		controller.call("refresh_launcher")
		_sync_shell_launcher_controls()
		return
	if _launcher_list == null:
		return
	for child in _launcher_list.get_children():
		child.queue_free()
	_launcher_buttons.clear()
	_launcher_selected_app_id = ""

	var any_added := false
	var section_title := "Favorites" if _launcher_category_filter == "favorites" else "Applications"
	_launcher_list.add_child(_label(section_title, 12, Tokens.MUTED))

	for app_id in _app_order:
		if not _launcher_matches_filter(app_id):
			continue
		var button := _app_button(app_id, Vector2(0, 48))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_launcher_list.add_child(button)
		_launcher_buttons[app_id] = button
		if _launcher_selected_app_id == "":
			_launcher_selected_app_id = app_id
		any_added = true

	if not any_added:
		_launcher_list.add_child(_label("No apps match this view.", 12, Tokens.MUTED))

	_update_launcher_selection_visuals()

func _update_launcher_selection_visuals() -> void:
	var controller = _shell_fragment_controller("launcher")
	if controller != null and controller.has_method("set_selected_app"):
		controller.call("set_selected_app", _launcher_selected_app_id)
		_sync_shell_launcher_controls()
	for app_id in _launcher_buttons.keys():
		var button := _launcher_buttons[app_id] as Button
		if not is_instance_valid(button):
			continue
		if app_id == _launcher_selected_app_id:
			button.add_theme_stylebox_override("normal", StyleFactory.button_selected(8))
			button.add_theme_color_override("font_color", Tokens.TEXT)
		else:
			button.add_theme_stylebox_override("normal", StyleFactory.list_row("normal", 8))
			button.add_theme_color_override("font_color", Tokens.MUTED)

func _launcher_select_relative(delta: int) -> void:
	var ids: Array[String] = []
	for app_id in _app_order:
		if _launcher_buttons.has(app_id):
			ids.append(app_id)
	if ids.is_empty():
		return
	var index: int = maxi(ids.find(_launcher_selected_app_id), 0)
	index = clampi(index + delta, 0, ids.size() - 1)
	_launcher_selected_app_id = ids[index]
	_update_launcher_selection_visuals()
	var selected: Control = _launcher_buttons.get(_launcher_selected_app_id, null) as Control
	if selected != null and _launcher_scroll:
		_launcher_scroll.ensure_control_visible(selected)

func _launcher_activate_selected() -> void:
	if _launcher_selected_app_id == "":
		return
	if _launcher_buttons.has(_launcher_selected_app_id):
		var button := _launcher_buttons[_launcher_selected_app_id] as Button
		if is_instance_valid(button):
			button.emit_signal("pressed")

func _layout() -> void:
	if _dock_panel:
		var estimated := 0
		if has_meta("taskbar_estimated_width"):
			estimated = int(get_meta("taskbar_estimated_width"))
		else:
			estimated = 48 + 3 * 46  # default Start + 3 tasks + gaps
		var dock_width := clampf(float(estimated), 380.0, clampf(size.x * 0.65, 520.0, 1100.0))
		_dock_panel.offset_left = -dock_width * 0.5
		_dock_panel.offset_right = dock_width * 0.5
		_dock_panel.offset_top = -DOCK_HEIGHT - DOCK_BOTTOM_MARGIN
		_dock_panel.offset_bottom = -DOCK_BOTTOM_MARGIN
		# Ensure pill-shaped, Start left inset, no artifacts, horizontal overflow, active indicator aligned
		_dock_panel.add_theme_stylebox_override("panel", StyleFactory.glass_surface_outer(24))
	if _launcher:
		_launcher.size = _compute_launcher_size(size)
		var start_center_x := size.x * 0.5
		if _start_button != null and is_instance_valid(_start_button):
			start_center_x = _start_button.get_global_rect().get_center().x
		var launcher_pos := Vector2(start_center_x - (_launcher.size.x * 0.24), size.y - WINDOW_BOTTOM_MARGIN - _launcher.size.y - 8.0)
		var max_x := maxf(size.x - _launcher.size.x - LAUNCHER_MARGIN, LAUNCHER_MARGIN)
		var max_y := maxf(size.y - WINDOW_BOTTOM_MARGIN - _launcher.size.y - LAUNCHER_MARGIN, LAUNCHER_MARGIN)
		_launcher.position = Vector2(clampf(launcher_pos.x, LAUNCHER_MARGIN, max_x), clampf(launcher_pos.y, WINDOW_TOP_MARGIN, max_y))
	if _session_menu:
		_position_session_menu(_session_menu_anchor)
	if _status_popover:
		_position_status_popover(_status_popover_anchor)
	if _notification_history_panel:
		_notification_history_panel.position = Vector2(maxf(size.x - _notification_history_panel.size.x - 8.0, 8.0), TOP_PANEL_HEIGHT + 8.0)
	_clamp_all_desktop_icon_positions()
	if _desktop_drag_rect and _desktop_drag_selecting:
		_update_desktop_drag_rect_visual()
	if _window_manager != null and _window_manager.is_tiling_enabled():
		_window_manager.reflow_tiled_windows()
	else:
		for key in _open_windows.keys():
			var window := _open_windows[key] as OSWindow
			if is_instance_valid(window) and window.visible:
				_clamp_window_to_layer(window)

func _resolve_window_launch_options(app_id: String, app: Dictionary, content: Control) -> Dictionary:
	var default_size := _default_window_size(app_id, app, content)
	var min_size := _resolve_window_min_size(app_id, app, content)
	if content != null:
		if default_size != Vector2.ZERO:
			content.set_meta("window_default_size", default_size)
		if min_size != Vector2.ZERO:
			content.set_meta("window_min_size", min_size)
	return {"size": default_size}

func _default_window_size(app_id: String, app: Dictionary = {}, content: Control = null) -> Vector2:
	var manifest_window := _window_config_for_app(app_id, app)
	var size_class_default := _window_size_for_class(manifest_window, "default")
	if size_class_default != Vector2.ZERO:
		return size_class_default
	var manifest_size := _window_size_from_config(manifest_window, "default_width", "default_height")
	if manifest_size != Vector2.ZERO:
		return manifest_size
	if content != null and content.has_meta("window_default_size"):
		var meta_size: Variant = content.get_meta("window_default_size")
		if meta_size is Vector2:
			return meta_size
	match app_id:
		"files":
			return Vector2(1100, 680)
		"browser":
			return Vector2(860, 560)
		"console":
			return Vector2(900, 560)
		"hermes_chat":
			return Vector2(760, 560)
		"system":
			return Vector2(980, 640)
		"text":
			return Vector2(860, 620)
		"notes":
			return Vector2(900, 620)
		_:
			return Vector2(560, 380)

func _resolve_window_min_size(app_id: String, app: Dictionary, content: Control) -> Vector2:
	var manifest_window := _window_config_for_app(app_id, app)
	var size_class_min := _window_size_for_class(manifest_window, "min")
	if size_class_min != Vector2.ZERO:
		return size_class_min
	var manifest_size := _window_size_from_config(manifest_window, "min_width", "min_height")
	if manifest_size != Vector2.ZERO:
		return manifest_size
	if content != null and content.has_meta("window_min_size"):
		var meta_size: Variant = content.get_meta("window_min_size")
		if meta_size is Vector2:
			return meta_size
	return Vector2.ZERO

func _window_size_for_class(window_config: Dictionary, size_kind: String) -> Vector2:
	if window_config.is_empty():
		return Vector2.ZERO
	var size_class := str(window_config.get("size_class", "")).strip_edges().to_lower()
	if size_class == "":
		return Vector2.ZERO
	if not WINDOW_SIZE_CLASS_POLICY.has(size_class):
		size_class = WINDOW_SIZE_CLASS_FALLBACK
	var policy_entry: Dictionary = WINDOW_SIZE_CLASS_POLICY.get(size_class, {}) as Dictionary
	if policy_entry.is_empty():
		return Vector2.ZERO
	var size_value: Variant = policy_entry.get(size_kind, Vector2.ZERO)
	if size_value is Vector2:
		return size_value
	return Vector2.ZERO

func _window_config_for_app(app_id: String, app: Dictionary) -> Dictionary:
	if app.has("window") and app["window"] is Dictionary:
		return (app["window"] as Dictionary).duplicate(true)
	return _load_hermes_ui_window_config(app_id)

func _load_hermes_ui_window_config(app_id: String) -> Dictionary:
	if _hermes_ui_window_manifest_cache.has(app_id):
		return (_hermes_ui_window_manifest_cache[app_id] as Dictionary).duplicate(true)
	if not HERMES_UI_PRODUCTION_MANIFESTS.has(app_id):
		_hermes_ui_window_manifest_cache[app_id] = {}
		return {}
	var manifest_path: String = str(HERMES_UI_PRODUCTION_MANIFESTS[app_id])
	if not FileAccess.file_exists(manifest_path):
		_hermes_ui_window_manifest_cache[app_id] = {}
		return {}
	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		_hermes_ui_window_manifest_cache[app_id] = {}
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		_hermes_ui_window_manifest_cache[app_id] = {}
		return {}
	var window_config: Dictionary = {}
	var parsed_dict := parsed as Dictionary
	if parsed_dict.has("window") and parsed_dict["window"] is Dictionary:
		window_config = (parsed_dict["window"] as Dictionary).duplicate(true)
	_hermes_ui_window_manifest_cache[app_id] = window_config
	return window_config.duplicate(true)

func _window_size_from_config(window_config: Dictionary, width_key: String, height_key: String) -> Vector2:
	if window_config.is_empty():
		return Vector2.ZERO
	var width := float(window_config.get(width_key, 0))
	var height := float(window_config.get(height_key, 0))
	if width <= 0.0 or height <= 0.0:
		return Vector2.ZERO
	return Vector2(width, height)

func _center_window_position(window: OSWindow) -> Vector2:
	if not _window_layer:
		return Vector2.ZERO
	return Vector2(
		maxf((_window_layer.size.x - window.size.x) * 0.5, 0.0),
		maxf((_window_layer.size.y - window.size.y) * 0.5, 0.0)
	)

func _clamp_window_to_layer(window: OSWindow) -> void:
	if not _window_layer:
		return
	var max_x := maxf(_window_layer.size.x - window.size.x, 0.0)
	var max_y := maxf(_window_layer.size.y - window.size.y, 0.0)
	window.position = Vector2(clampf(window.position.x, 0.0, max_x), clampf(window.position.y, 0.0, max_y))

func _toggle_window_tiling_mode() -> void:
	if _window_manager == null:
		return
	_window_manager.toggle_tiling()

func _toggle_focused_window_floating() -> void:
	if _window_manager == null:
		return
	_window_manager.toggle_focused_window_floating()

func _focus_relative_tiled_window(direction: int) -> void:
	if _window_manager == null:
		return
	_window_manager.focus_next_tiled_window(direction)

func set_snap_assist_enabled(enabled: bool) -> void:
	_snap_assist_enabled = enabled
	if _window_manager != null:
		_window_manager.set_snap_assist_enabled(enabled)
	_queue_state_save()

func is_snap_assist_enabled() -> bool:
	return _snap_assist_enabled

func _snap_focused_window(direction: String) -> void:
	if not _snap_assist_enabled or _window_manager == null:
		return
	_window_manager.snap_focused_window(direction)

func _focus_window(window: OSWindow) -> void:
	if _window_manager != null:
		var managed_id := _window_manager.get_window_id(window)
		if managed_id > 0 and _window_manager.get_focused_window_id() != managed_id:
			_window_manager.focus_window(managed_id)
			return
	var previous_window := _active_window
	_active_window = window
	for key in _open_windows.keys():
		var other := _open_windows[key] as OSWindow
		if is_instance_valid(other):
			if other != window and other == previous_window:
				_call_app_lifecycle(other, "os_app_blur")
			other.set_active(other == window)
	window.visible = true
	window.move_to_front()
	_open_windows[window.app_id] = window
	_call_app_lifecycle(window, "os_app_focus")
	_update_task_button(window.app_id, true)
	_update_taskbar_indicators()
	if _window_manager == null:
		_emit_hermes_event("window.focused", {
			"window_id": _window_id(window),
			"app_id": window.app_id
		})

func _on_window_close_requested(window: OSWindow) -> void:
	if not _app_content_allows_close(window):
		return
	_capture_app_instance_state(window)
	if _window_manager != null:
		var managed_id := _window_manager.get_window_id(window)
		if managed_id > 0 and _window_manager.get_window(managed_id) != null:
			_window_manager.close_window(managed_id)
			return
	var app_id := window.app_id
	var window_id := _window_id(window)
	_prepare_window_content_for_close(window)
	if _active_window == window:
		_active_window = null
	if _window_manager == null:
		_remove_app_instance_for_window(app_id, int(window.get_meta("window_id", 0)))
	var remaining_window := _current_window_for_app(app_id)
	if remaining_window != null and remaining_window != window:
		_open_windows[app_id] = remaining_window
	else:
		if _open_windows.has(app_id):
			_open_windows.erase(app_id)
		if _task_buttons.has(app_id):
			var button := _task_buttons[app_id] as Button
			if is_instance_valid(button):
				button.queue_free()
			_task_buttons.erase(app_id)
	window.visible = false
	if app_id == "browser":
		_queue_browser_close_poll(window, Time.get_ticks_msec() + 1800)
	else:
		var close_timer := get_tree().create_timer(0.12)
		close_timer.timeout.connect(func() -> void:
			if is_instance_valid(window):
				_prepare_window_content_for_close(window)
				window.queue_free()
		)
	_update_taskbar_indicators()
	_emit_hermes_event("window.closed", {"window_id": window_id, "app_id": app_id})
	_emit_hermes_event("app.closed", {"app_id": app_id})

func _queue_browser_close_poll(window: OSWindow, deadline_msec: int) -> void:
	var poll := get_tree().create_timer(0.05)
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

func _prepare_window_content_for_close(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	if root.has_method("prepare_for_close"):
		root.call("prepare_for_close")
	for child in root.get_children():
		_prepare_window_content_for_close(child)

func _on_window_minimize_requested(window: OSWindow) -> void:
	if _window_manager != null:
		var managed_id := _window_manager.get_window_id(window)
		if managed_id > 0 and _window_manager.get_window(managed_id) != null:
			_window_manager.minimize_window(managed_id)
			return
	if _active_window == window:
		_active_window = null
	window.visible = false
	_update_task_button(window.app_id, false)
	_update_taskbar_indicators()
	_emit_hermes_event("window.minimized", {"window_id": _window_id(window), "app_id": window.app_id})

func _create_task_button(app_id: String) -> void:
	if _task_buttons.has(app_id):
		return
	_refresh_taskbar_fragment()
	if _task_buttons.has(app_id):
		return
	# Legacy fallback for non-HermesUI taskbar mounts.
	var app: Dictionary = _apps[app_id]
	var button := _icon_button(app_id, Vector2(42, 40))
	button.tooltip_text = str(app.get("title", app_id))
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(_on_task_button_pressed.bind(app_id))

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

	_taskbar_windows.add_child(button)
	_task_buttons[app_id] = button

func _update_task_button(app_id: String, active: bool) -> void:
	if not _task_buttons.has(app_id):
		return
	var button := _task_buttons[app_id] as Button
	if not is_instance_valid(button):
		return
	if active:
		button.add_theme_stylebox_override("normal", StyleFactory.button_selected(8))
		button.add_theme_color_override("font_color", Tokens.TEXT)
	else:
		button.add_theme_stylebox_override("normal", StyleFactory.icon_button_normal(8))
		button.add_theme_color_override("font_color", Tokens.MUTED)

func _update_taskbar_indicators() -> void:
	for app_id in _task_buttons.keys():
		var button := _task_buttons[app_id] as Button
		if not is_instance_valid(button):
			continue
		var indicator: ColorRect = button.get_node_or_null("Indicator") as ColorRect
		if indicator == null:
			continue
		if _open_windows.has(app_id) and is_instance_valid(_open_windows[app_id]):
			var window := _open_windows[app_id] as OSWindow
			if window.visible:
				if _active_window == window:
					indicator.color = Tokens.FOCUS
				else:
					indicator.color = Color(Tokens.MUTED.r, Tokens.MUTED.g, Tokens.MUTED.b, 0.45)
			else:
				indicator.color = Color(Tokens.MUTED.r, Tokens.MUTED.g, Tokens.MUTED.b, 0.18)
		else:
			indicator.color = Color.TRANSPARENT

func _on_task_button_pressed(app_id: String) -> void:
	var window := _current_window_for_app(app_id)
	if window == null:
		launch_app(app_id)
		return
	if not window.visible:
		_restore_window(window)
		return
	if _active_window == window:
		_on_window_minimize_requested(window)
		return
	_focus_window(window)

func _restore_window(window: OSWindow) -> void:
	if window == null or not is_instance_valid(window):
		return
	if _window_manager != null:
		var managed_id := _window_manager.get_window_id(window)
		if managed_id > 0 and _window_manager.get_window(managed_id) != null:
			_window_manager.restore_window(managed_id)
			return
	window.visible = true
	_focus_window(window)
	_update_task_button(window.app_id, true)
	_update_taskbar_indicators()
	_emit_hermes_event("window.restored", {"window_id": _window_id(window), "app_id": window.app_id})

func _close_active_window() -> void:
	if _active_window and is_instance_valid(_active_window):
		_on_window_close_requested(_active_window)

func _focus_next_window() -> void:
	var visible_windows: Array[OSWindow] = []
	for window in _all_open_windows_in_app_order():
		if is_instance_valid(window) and window.visible:
			visible_windows.append(window)
	if visible_windows.is_empty():
		return
	var next_index := 0
	if _active_window and is_instance_valid(_active_window):
		var current_index := visible_windows.find(_active_window)
		if current_index != -1:
			next_index = (current_index + 1) % visible_windows.size()
	_focus_window(visible_windows[next_index])

func _toggle_launcher() -> void:
	if not _session_active:
		return
	_close_shell_overlays("launcher")
	if _launcher == null:
		return
	_launcher.visible = not _launcher.visible
	_sync_shell_overlay_content_layers()
	_apply_dock_tooltip_policy()
	_apply_top_panel_tooltip_policy()
	if _launcher.visible:
		_refresh_launcher_header()
		_rebuild_launcher_list()
		_layout()
		_launcher.move_to_front()
		var animator := UIAnimator.new()
		animator.menu_pop(_launcher, Tokens.TIME["normal"])
		if _launcher_search:
			_launcher_search.grab_focus()
	else:
		_hide_launcher()

func _toggle_session_menu_from_button(anchor: Control) -> void:
	_toggle_session_menu(anchor)

func _toggle_session_menu(anchor: Control = null) -> void:
	if not _session_active:
		return
	_close_shell_overlays("session_menu")
	_session_menu_anchor = anchor
	_session_menu.visible = not _session_menu.visible
	_sync_shell_overlay_content_layers()
	if _session_menu.visible:
		_position_session_menu(anchor)
		_session_menu.move_to_front()
	_apply_dock_tooltip_policy()
	_apply_top_panel_tooltip_policy()

func _toggle_status_popover(status_key: String, title: String, status: String, detail: String, anchor: Control) -> void:
	if not _session_active or _status_popover == null:
		return
	_close_shell_overlays("status_popover")
	_status_popover_anchor = anchor
	_status_popover_action_key = status_key
	if _status_popover_title:
		_status_popover_title.text = title
	if _status_popover_body:
		var body_text := status.strip_edges()
		if detail.strip_edges() != "":
			body_text += "\n" + detail.strip_edges()
		_status_popover_body.text = body_text
	_configure_status_popover_action(status_key)
	_status_popover.visible = not _status_popover.visible
	_sync_shell_overlay_content_layers()
	if _status_popover.visible:
		_position_status_popover(anchor)
		_status_popover.move_to_front()
	_apply_dock_tooltip_policy()
	_apply_top_panel_tooltip_policy()

func _position_session_menu(anchor: Control = null) -> void:
	_position_anchored_panel(_session_menu, anchor, Vector2(size.x - _session_menu.size.x - 12.0, TOP_PANEL_HEIGHT + 8.0))

func _position_status_popover(anchor: Control = null) -> void:
	_position_anchored_panel(_status_popover, anchor, Vector2(size.x - _status_popover.size.x - 12.0, TOP_PANEL_HEIGHT + 8.0))

func _position_anchored_panel(panel: Control, anchor: Control, fallback_position: Vector2) -> void:
	if panel == null:
		return
	var target := fallback_position
	if anchor != null and is_instance_valid(anchor):
		var shell_origin := get_global_rect().position
		var anchor_rect := anchor.get_global_rect()
		target = Vector2(anchor_rect.position.x + anchor_rect.size.x - panel.size.x - shell_origin.x, anchor_rect.position.y + anchor_rect.size.y + 6.0 - shell_origin.y)
	var margin := 8.0
	var min_y := TOP_PANEL_HEIGHT + 6.0
	var max_x := maxf(size.x - panel.size.x - margin, margin)
	var max_y := maxf(size.y - panel.size.y - margin, min_y)
	panel.position = Vector2(clampf(target.x, margin, max_x), clampf(target.y, min_y, max_y))

func _show_alt_tab() -> void:
	_alt_tab_window_order.clear()
	for window in _all_open_windows_in_app_order():
		if is_instance_valid(window) and window.visible:
			_alt_tab_window_order.append(window)
	if _alt_tab_window_order.size() < 2:
		return
	var current_index := 0
	if _active_window and is_instance_valid(_active_window):
		current_index = _alt_tab_window_order.find(_active_window)
		if current_index == -1:
			current_index = 0
	_alt_tab_selected_index = (current_index + 1) % _alt_tab_window_order.size()
	_rebuild_alt_tab_content()
	_alt_tab_overlay.visible = true
	_alt_tab_overlay.move_to_front()
	_sync_shell_overlay_content_layers()

func _alt_tab_advance() -> void:
	if _alt_tab_window_order.is_empty():
		return
	_alt_tab_selected_index = (_alt_tab_selected_index + 1) % _alt_tab_window_order.size()
	_rebuild_alt_tab_content()

func _hide_alt_tab(activate := true) -> void:
	if not _alt_tab_overlay or not _alt_tab_overlay.visible:
		return
	_alt_tab_overlay.visible = false
	_sync_shell_overlay_content_layers()
	if activate and _alt_tab_selected_index >= 0 and _alt_tab_selected_index < _alt_tab_window_order.size():
		var window := _alt_tab_window_order[_alt_tab_selected_index] as OSWindow
		if is_instance_valid(window):
			_focus_window(window)

func _rebuild_alt_tab_content() -> void:
	if not _alt_tab_content:
		return
	for child in _alt_tab_content.get_children():
		child.queue_free()
	for i in range(_alt_tab_window_order.size()):
		var window := _alt_tab_window_order[i] as OSWindow
		var item := _alt_tab_item(window, i == _alt_tab_selected_index)
		_alt_tab_content.add_child(item)

func _alt_tab_item(window: OSWindow, selected: bool) -> Control:
	var container := VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 6)
	container.custom_minimum_size = Vector2(74, 0)

	_ensure_icon_atlas()
	var icon := TextureRect.new()
	icon.texture = _app_icon(window.app_id)
	icon.custom_minimum_size = Vector2(28, 28)
	icon.size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color(1, 1, 1, 1.0) if selected else Color(1, 1, 1, 0.6)
	container.add_child(icon)

	var title := Label.new()
	title.text = str(window.app_title).strip_edges()
	if title.text == "":
		title.text = window.app_id.capitalize()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Tokens.TEXT if selected else Tokens.MUTED)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.custom_minimum_size = Vector2(0, 18)
	container.add_child(title)

	var indicator := ColorRect.new()
	indicator.custom_minimum_size = Vector2(32 if selected else 0, 3)
	indicator.size = Vector2(32 if selected else 0, 3)
	indicator.color = Tokens.FOCUS if selected else Color.TRANSPARENT
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(indicator)

	return container

func _update_clock() -> void:
	if not _clock_label:
		return
	var now := Time.get_datetime_dict_from_system()
	_clock_label.text = "%s %d, %s" % [_month_name(int(now.month)), int(now.day), _topbar_time_text(now)]

func login_session(username: String, password := "") -> String:
	var clean := _fs.clean_username(username)
	var auth := _fs.authenticate_user(clean, password)
	if not bool(auth.get("ok", false)):
		return str(auth.get("error", "Authentication failed"))
	var previous_user := _fs.current_user()
	var was_active := _session_active
	var message := _fs.set_current_user(clean)
	if message != "":
		return message
	if previous_user != clean or not was_active:
		_close_all_windows()
	_session_active = true
	_hide_auth_screen()
	_sync_shell_visibility()
	_refresh_desktop_icons()
	_update_clock()
	_queue_state_save()
	return ""

func lock_session() -> void:
	if not _session_active:
		_show_auth_screen("login")
		_queue_state_save()
		return
	_show_auth_screen("locked", "Locked as " + _fs.current_user())
	_queue_state_save()

func switch_user_session() -> void:
	_show_auth_screen("switch", "Choose another account")
	_queue_state_save()

func logout_session() -> void:
	_close_all_windows()
	_session_active = false
	_refresh_desktop_icons()
	_show_auth_screen("login", "Signed out")
	_queue_state_save()

func _route_after_boot() -> void:
	if _boot_next_action == "show_desktop" and _session_active:
		_hide_auth_screen()
		_hide_desktop_context_menu()
		_sync_shell_visibility()
		return
	_show_auth_screen(_boot_target_auth_mode, _boot_target_auth_message)

func _apply_dock_tooltip_policy() -> void:
	var suppress := _shell_tooltips_suppressed()
	if _start_button != null and is_instance_valid(_start_button):
		_start_button.tooltip_text = "" if suppress else START_BUTTON_TOOLTIP
	for app_id in _task_buttons.keys():
		var button := _task_buttons[app_id] as Button
		if button == null or not is_instance_valid(button):
			continue
		if suppress:
			button.tooltip_text = ""
			continue
		var app: Dictionary = _apps.get(app_id, {}) as Dictionary
		button.tooltip_text = str(app.get("title", app_id))

func _apply_top_panel_tooltip_policy() -> void:
	if _status_icons_row == null:
		return
	var suppress := _shell_tooltips_suppressed()
	for child in _status_icons_row.get_children():
		var button := child as Button
		if button == null:
			continue
		if suppress:
			button.tooltip_text = ""
			continue
		var status_key := _status_key_for_button(button)
		button.tooltip_text = str(_status_button_defaults.get(status_key, button.name))

func _status_key_for_button(button: Button) -> String:
	if button == null:
		return ""
	if button.name == "NetworkStatusButton":
		return "network"
	if button.name == "AudioStatusButton":
		return "audio"
	if button.name == "BluetoothStatusButton":
		return "bluetooth"
	if button.name == "BatteryStatusButton":
		return "battery"
	if button.name == "PowerMenuButton":
		return "power"
	if button.name == "NotificationStatusButton":
		return "notification"
	if button.name == "AccountStatusButton":
		return "account"
	return ""

func _configure_status_popover_action(status_key: String) -> void:
	if _status_popover_action == null:
		return
	_status_popover_action.visible = true
	_status_popover_action.disabled = false
	_status_popover_action.tooltip_text = ""
	match status_key:
		"network", "audio", "bluetooth", "battery":
			_status_popover_action.text = "Open System Settings"
		"":
			_status_popover_action.visible = false
		_:
			_status_popover_action.visible = false

func _on_status_popover_action_pressed() -> void:
	if _status_popover:
		_status_popover.visible = false
	_sync_shell_overlay_content_layers()
	match _status_popover_action_key:
		"network", "audio", "bluetooth", "battery":
			launch_app("system")
		_:
			pass
	_apply_dock_tooltip_policy()
	_apply_top_panel_tooltip_policy()

func _has_visible_overlay() -> bool:
	if _launcher and _launcher.visible:
		return true
	if _session_menu and _session_menu.visible:
		return true
	if _status_popover and _status_popover.visible:
		return true
	if _desktop_context_menu and _desktop_context_menu.visible:
		return true
	if _notification_history_panel and _notification_history_panel.visible:
		return true
	return false

func _close_shell_overlays(except: String = "") -> void:
	var keep := except.strip_edges().to_lower()
	if keep != "desktop_context":
		_hide_desktop_context_menu()
	if keep != "launcher":
		_hide_launcher()
	if keep != "session_menu" and _session_menu:
		_session_menu.visible = false
	if keep != "status_popover" and _status_popover:
		_status_popover.visible = false
	if keep != "notification_history" and _notification_history_panel:
		_notification_history_panel.visible = false
	_apply_dock_tooltip_policy()
	_apply_top_panel_tooltip_policy()
	_sync_shell_overlay_content_layers()

func _sync_shell_overlay_content_layers(force := false) -> void:
	var active := _shell_content_overlay_active()
	if not force and _shell_overlay_content_occluded == active:
		return
	_shell_overlay_content_occluded = active
	for window in _all_open_windows_in_app_order():
		if is_instance_valid(window):
			_set_app_content_occluded_by_shell_overlay(window, active)

func _shell_content_overlay_active() -> bool:
	return _shell_tooltips_suppressed() \
		or (_alt_tab_overlay != null and _alt_tab_overlay.visible)

func _set_app_content_occluded_by_shell_overlay(root: Node, active: bool) -> void:
	if root == null or not is_instance_valid(root):
		return
	if root.has_method("set_shell_overlay_occluded"):
		root.call("set_shell_overlay_occluded", active)
	for child in root.get_children():
		_set_app_content_occluded_by_shell_overlay(child, active)

func _shell_tooltips_suppressed() -> bool:
	return (_launcher != null and _launcher.visible) \
		or (_session_menu != null and _session_menu.visible) \
		or (_status_popover != null and _status_popover.visible) \
		or (_notification_history_panel != null and _notification_history_panel.visible)

func _topbar_time_text(now: Dictionary) -> String:
	var hour_24 := int(now.get("hour", 0))
	var minute := int(now.get("minute", 0))
	var meridiem := "AM" if hour_24 < 12 else "PM"
	var hour_12 := hour_24 % 12
	if hour_12 == 0:
		hour_12 = 12
	return "%d:%02d %s" % [hour_12, minute, meridiem]

func _sync_shell_visibility() -> void:
	# Central gating for shell chrome visibility based on session/auth/boot state.
	# Prevents taskbar/dock/topbar/launcher leakage on boot splash or login.
	# Called on state transitions and after shell construction.
	var desktop_ready := _session_active and not _boot_sequence_active and not (_auth_overlay and is_instance_valid(_auth_overlay) and _auth_overlay.visible) and not (_boot_overlay and is_instance_valid(_boot_overlay) and _boot_overlay.visible)
	if _top_panel:
		_top_panel.visible = desktop_ready
		_top_panel.mouse_filter = Control.MOUSE_FILTER_STOP if desktop_ready else Control.MOUSE_FILTER_IGNORE
	if _dock_panel:
		_dock_panel.visible = desktop_ready
		_dock_panel.mouse_filter = Control.MOUSE_FILTER_STOP if desktop_ready else Control.MOUSE_FILTER_IGNORE
	if _launcher:
		if not desktop_ready:
			_launcher.visible = false
	_apply_dock_tooltip_policy()
	_apply_top_panel_tooltip_policy()
	if _session_menu:
		if not desktop_ready:
			_session_menu.visible = false
	if _status_popover:
		if not desktop_ready:
			_status_popover.visible = false
	if _notification_history_panel:
		if not desktop_ready:
			_notification_history_panel.visible = false
	_sync_shell_overlay_content_layers(true)
	# Tooltips/popups and alt_tab follow similar gating when needed.

func _begin_boot_sequence(next_action: String = "show_auth", auth_mode: String = "login", auth_message := "") -> void:
	_boot_next_action = next_action
	_boot_target_auth_mode = auth_mode
	_boot_target_auth_message = auth_message
	_hide_auth_screen()
	_hide_boot_sequence()
	if DisplayServer.get_name() == "headless" or _should_skip_boot_splash():
		_route_after_boot()
		return
	_boot_sequence_active = true
	_hide_desktop_context_menu()
	_sync_shell_visibility()

	_boot_overlay = Control.new()
	_boot_overlay.name = "BootOverlay"
	_boot_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boot_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_boot_overlay.focus_mode = Control.FOCUS_ALL
	_boot_overlay.gui_input.connect(_on_boot_overlay_gui_input)
	add_child(_boot_overlay)
	_boot_overlay.move_to_front()

	var backdrop := ColorRect.new()
	backdrop.color = Color("080a0f")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boot_overlay.add_child(backdrop)

	var stream := load(BOOT_SPLASH_VIDEO_PATH) as VideoStream
	if stream != null:
		_boot_video_player = VideoStreamPlayer.new()
		_boot_video_player.name = "BootVideo"
		_boot_video_player.set_anchors_preset(Control.PRESET_FULL_RECT)
		_boot_video_player.expand = true
		_boot_video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_boot_video_player.stream = stream
		_boot_video_player.finished.connect(_finish_boot_sequence)
		_boot_overlay.add_child(_boot_video_player)
		_boot_video_player.play()
	else:
		push_warning("HermesOS boot splash video not found at %s" % BOOT_SPLASH_VIDEO_PATH)

	var vignette := ColorRect.new()
	vignette.color = Color(0.02, 0.03, 0.05, 0.34)
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boot_overlay.add_child(vignette)

	var safe_area := MarginContainer.new()
	safe_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe_area.add_theme_constant_override("margin_left", 28)
	safe_area.add_theme_constant_override("margin_right", 28)
	safe_area.add_theme_constant_override("margin_top", 28)
	safe_area.add_theme_constant_override("margin_bottom", 28)
	_boot_overlay.add_child(safe_area)

	var frame := VBoxContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.alignment = BoxContainer.ALIGNMENT_END
	frame.add_theme_constant_override("separation", 14)
	safe_area.add_child(frame)

	var boot_card := Panel.new()
	boot_card.custom_minimum_size = Vector2(460, 0)
	boot_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	boot_card.add_theme_stylebox_override("panel", StyleFactory.glass_panel(0.86, Tokens.alpha(Tokens.WHITE, 0.12), 1, 18))
	frame.add_child(boot_card)

	var boot_column := VBoxContainer.new()
	boot_column.set_anchors_preset(Control.PRESET_FULL_RECT)
	boot_column.offset_left = 20
	boot_column.offset_right = -20
	boot_column.offset_top = 18
	boot_column.offset_bottom = -18
	boot_column.add_theme_constant_override("separation", 8)
	boot_card.add_child(boot_column)

	boot_column.add_child(_label("HermesOS", 24, Tokens.TEXT))
	boot_column.add_child(_label("Booting native shell services", 13, Tokens.MUTED))
	boot_column.add_child(_label("Press any key or click to continue", 12, Tokens.alpha(Tokens.TEXT, 0.78)))

	_boot_finish_timer = Timer.new()
	_boot_finish_timer.one_shot = true
	_boot_finish_timer.wait_time = BOOT_SPLASH_DURATION if stream != null else BOOT_SPLASH_FALLBACK_DURATION
	_boot_finish_timer.timeout.connect(_finish_boot_sequence)
	_boot_overlay.add_child(_boot_finish_timer)
	_boot_finish_timer.start()
	_boot_overlay.grab_focus()

func _on_boot_overlay_gui_input(event: InputEvent) -> void:
	if not _boot_sequence_active:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed:
			_finish_boot_sequence()
			get_viewport().set_input_as_handled()

func _finish_boot_sequence() -> void:
	if not _boot_sequence_active and _boot_overlay == null:
		return
	_hide_boot_sequence()
	_route_after_boot()

func _hide_boot_sequence() -> void:
	_boot_sequence_active = false
	if _boot_finish_timer and is_instance_valid(_boot_finish_timer):
		_boot_finish_timer.stop()
	if _boot_video_player and is_instance_valid(_boot_video_player):
		_boot_video_player.stop()
	if _boot_overlay and is_instance_valid(_boot_overlay):
		_boot_overlay.queue_free()
	_boot_overlay = null
	_boot_video_player = null
	_boot_finish_timer = null

func _show_auth_screen(mode: String, message := "") -> void:
	_hide_boot_sequence()
	_hide_auth_screen()
	_hide_desktop_context_menu()
	_sync_shell_visibility()

	_auth_overlay = Control.new()
	_auth_overlay.name = "AuthOverlay"
	_auth_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_auth_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_auth_overlay)
	_auth_overlay.move_to_front()

	var dim := ColorRect.new()
	dim.color = Color(0.035, 0.04, 0.05, 0.95)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_auth_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 24
	center.offset_right = -24
	center.offset_top = 24
	center.offset_bottom = -24
	_auth_overlay.add_child(center)

	var card := Panel.new()
	card.custom_minimum_size = Vector2(860, 520)
	card.add_theme_stylebox_override("panel", StyleFactory.elevated_panel(3, 0.96, 14))
	center.add_child(card)
	if DisplayServer.get_name() != "headless":
		var animator := UIAnimator.new()
		animator.scale_in(card, Tokens.TIME["slow"])

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 18
	root.offset_right = -18
	root.offset_top = 18
	root.offset_bottom = -18
	root.add_theme_constant_override("separation", 12)
	card.add_child(root)

	var title_text := "Sign in"
	if mode == "locked":
		title_text = "Session locked"
	elif mode == "switch":
		title_text = "Switch user"
	root.add_child(_label(title_text, 22, Tokens.TEXT))

	var subtitle := _label("Choose an account and enter its password.", 13, Tokens.MUTED)
	if mode == "login":
		subtitle.text = "Choose an account to start a session. Blank passwords are accepted until a password is set."
	elif mode == "locked":
		subtitle.text = "Unlock the current session, or sign in as another user."
	elif mode == "switch":
		subtitle.text = "Sign in as another user. Switching users closes the current user's app windows."
	root.add_child(subtitle)

	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 320
	root.add_child(split)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	split.add_child(left)

	left.add_child(_label("Accounts", 14, Tokens.TEXT))
	left.add_child(_label("Visible login profiles", 12, Tokens.MUTED))

	var users := ItemList.new()
	users.name = "AuthUsersList"
	users.custom_minimum_size = Vector2(0, 260)
	users.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	users.size_flags_vertical = Control.SIZE_EXPAND_FILL
	users.select_mode = ItemList.SELECT_SINGLE
	_style_item_list(users)
	left.add_child(users)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	split.add_child(right)

	var selected_avatar := TextureRect.new()
	selected_avatar.name = "AuthSelectedAvatar"
	selected_avatar.custom_minimum_size = Vector2(72, 72)
	selected_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	selected_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	right.add_child(selected_avatar)

	var selected_name := _label("No account selected", 18, Tokens.TEXT)
	selected_name.name = "AuthSelectedName"
	right.add_child(selected_name)

	var selected_username := _label("", 12, Tokens.MUTED)
	selected_username.name = "AuthSelectedUsername"
	right.add_child(selected_username)

	var selected_home := _label("", 11, Tokens.MUTED)
	selected_home.name = "AuthSelectedHome"
	right.add_child(selected_home)

	var selected_state := _label("", 11, Tokens.MUTED)
	selected_state.name = "AuthSelectedState"
	right.add_child(selected_state)

	var username_input := LineEdit.new()
	username_input.placeholder_text = "username"
	username_input.editable = false
	_style_line_edit(username_input)
	right.add_child(username_input)

	var password_input := LineEdit.new()
	password_input.placeholder_text = "password"
	password_input.secret = true
	_style_line_edit(password_input)
	right.add_child(password_input)

	var status := _label(message, 12, Tokens.MUTED)
	right.add_child(status)

	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.add_theme_constant_override("h_separation", 8)
	buttons.add_theme_constant_override("v_separation", 8)
	right.add_child(buttons)

	var sign_in_button := _button("Sign in", Vector2(120, 36))
	buttons.add_child(sign_in_button)

	if mode == "switch" and _session_active:
		var cancel_button := _button("Cancel", Vector2(96, 36))
		cancel_button.pressed.connect(_hide_auth_screen)
		buttons.add_child(cancel_button)

	if mode != "login":
		var logout_button := _button("Log out", Vector2(96, 36))
		logout_button.pressed.connect(logout_session)
		buttons.add_child(logout_button)

	var login_users: Array = []
	if _fs.has_method("list_login_users"):
		login_users = _fs.list_login_users()
	else:
		for fallback_username in _fs.get_users():
			if fallback_username == "root":
				continue
			login_users.append({
				"username": fallback_username,
				"display_name": fallback_username,
				"home": _fs.home_path(fallback_username),
				"locked": false
			})

	var account_by_username: Dictionary = {}
	for account_item in login_users:
		if not (account_item is Dictionary):
			continue
		var account_dict: Dictionary = account_item
		var username_text := str(account_dict.get("username", "")).strip_edges()
		if username_text == "":
			continue
		account_by_username[username_text] = account_dict.duplicate(true)
		var display_name := str(account_dict.get("display_name", username_text)).strip_edges()
		var home_path := str(account_dict.get("home", _fs.home_path(username_text))).strip_edges()
		users.add_item("%s  @%s\n%s" % [display_name, username_text, home_path])
		users.set_item_metadata(users.item_count - 1, username_text)
		var avatar_icon := _user_avatar_icon(username_text)
		if avatar_icon != null:
			users.set_item_icon(users.item_count - 1, avatar_icon)

	if users.item_count == 0:
		_set_status(status, "No login-visible accounts found. Create an account first.", true)
		sign_in_button.disabled = true
		password_input.editable = false
		selected_name.text = "No login accounts"
		selected_username.text = ""
		selected_home.text = ""
		selected_state.text = ""
		selected_avatar.texture = _start_menu_icon("user")

	var update_selected := func(selected_user: String) -> void:
		var username_text := selected_user.strip_edges()
		if username_text == "":
			return
		username_input.text = username_text
		var account: Dictionary = account_by_username.get(username_text, {})
		var display_name := str(account.get("display_name", username_text)).strip_edges()
		var home_path := str(account.get("home", _fs.home_path(username_text))).strip_edges()
		var locked := bool(account.get("locked", false))
		selected_name.text = display_name
		selected_username.text = "@" + username_text
		selected_home.text = home_path
		selected_state.text = "Locked account" if locked else "Ready to sign in"
		selected_state.modulate = Tokens.WARNING if locked else Tokens.MUTED
		selected_avatar.texture = _user_avatar_icon(username_text)

	for index in users.item_count:
		if str(users.get_item_metadata(index)) == _fs.current_user():
			users.select(index)
			update_selected.call(str(users.get_item_metadata(index)))
			break
	if users.get_selected_items().is_empty() and users.item_count > 0:
		users.select(0)
		update_selected.call(str(users.get_item_metadata(0)))

	users.item_selected.connect(func(index: int) -> void:
		var selected_user := str(users.get_item_metadata(index))
		update_selected.call(selected_user)
		password_input.grab_focus()
	)

	var attempt_login := func() -> void:
		var result := login_session(username_input.text, password_input.text)
		if result != "":
			_set_status(status, result, true)
			password_input.text = ""
			password_input.grab_focus()

	sign_in_button.pressed.connect(attempt_login)
	password_input.text_submitted.connect(func(_submitted: String) -> void:
		attempt_login.call()
	)
	username_input.text_submitted.connect(func(_submitted: String) -> void:
		password_input.grab_focus()
	)
	password_input.grab_focus()

func _hide_auth_screen() -> void:
	if _auth_overlay and is_instance_valid(_auth_overlay):
		_auth_overlay.queue_free()
	_auth_overlay = null

func _close_all_windows() -> void:
	_active_window = null
	if _window_manager != null:
		_window_manager.close_all()
	else:
		for key in _open_windows.keys():
			var window := _open_windows[key] as OSWindow
			if is_instance_valid(window):
				window.queue_free()
	_open_windows.clear()
	_app_instances.clear()
	_app_instances_by_app.clear()
	_app_instance_by_app.clear()
	_window_to_app_instance.clear()
	for key in _task_buttons.keys():
		var button := _task_buttons[key] as Button
		if is_instance_valid(button):
			button.queue_free()
	_task_buttons.clear()

func _build_files_app() -> Control:
	var files_app := FilesApp.new()
	files_app.name = "FilesApp"
	files_app.os_app_init({
		"shell": self,
		"filesystem": _fs,
		"shortcuts": _files_shortcuts.duplicate(true),
		"open_file_callback": Callable(self, "_open_text_file"),
		"shortcuts_changed_callback": Callable(self, "_sync_files_shortcuts_from_app"),
		"state_save_callback": Callable(self, "_queue_state_save")
	})
	return files_app

func _files_default_shortcuts(home: String) -> Array[Dictionary]:
	return [
		{"label": "Desktop", "path": _fs.join_path(home, "Desktop")},
		{"label": "Documents", "path": _fs.join_path(home, "Documents")},
		{"label": "Downloads", "path": _fs.join_path(home, "Downloads")},
		{"label": "Music", "path": _fs.join_path(home, "Music")},
		{"label": "Pictures", "path": _fs.join_path(home, "Pictures")},
		{"label": "Videos", "path": _fs.join_path(home, "Videos")},
		{"label": "Home", "path": home},
		{"label": "Trash", "path": _fs.join_path(home, ".local/share/Trash/files")},
		{"label": "Networks", "path": home}
	]

func _files_sanitize_shortcuts(value: Variant, home: String) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if value is Array:
		for item in value:
			if not (item is Dictionary):
				continue
			var shortcut: Dictionary = item
			var label := str(shortcut.get("label", "")).strip_edges()
			var path := str(shortcut.get("path", "")).strip_edges()
			if label == "" or path == "":
				continue
			output.append({
				"label": label,
				"path": _fs.normalize_path(path)
			})
	if output.is_empty():
		output = _files_default_shortcuts(home)
	return output

func _files_app_instance(window: OSWindow = null) -> FilesApp:
	var target_window := window
	if target_window == null:
		target_window = _current_window_for_app("files")
	if target_window == null or not is_instance_valid(target_window):
		return null
	var node := target_window.find_child("FilesApp", true, false)
	if node != null and node is FilesApp:
		return node as FilesApp
	return null

func _sync_files_shortcuts_from_app(shortcuts: Array) -> void:
	_files_shortcuts = _files_sanitize_shortcuts(shortcuts, _fs.home_path())

func _open_files_to_path(path: String) -> void:
	var target := _fs.normalize_path(path)
	var folder_path := target
	if _fs.is_file(target):
		folder_path = _fs.parent_path(target)
	elif not _fs.is_dir(target):
		folder_path = _fs.home_path()
	var window := launch_app("files")
	if window == null:
		return
	var files_app := _files_app_instance(window)
	if files_app != null:
		files_app.open_path(folder_path)
		if _fs.is_file(target):
			files_app.select_path(target)
	_focus_window(window)

func _paste_destination_path(source_path: String, destination_dir: String) -> String:
	var clean_source := _fs.normalize_path(source_path)
	var clean_destination_dir := _fs.normalize_path(destination_dir)
	var base_name := clean_source.get_file()
	var stem := base_name.get_basename()
	var extension := base_name.get_extension()
	var candidate_name := base_name
	var index := 1
	while _fs.exists(_fs.join_path(clean_destination_dir, candidate_name)):
		if extension == "":
			candidate_name = "%s copy%s" % [stem, "" if index == 1 else " " + str(index)]
		else:
			candidate_name = "%s copy%s.%s" % [stem, "" if index == 1 else " " + str(index), extension]
		index += 1
	return _fs.join_path(clean_destination_dir, candidate_name)

func _build_notes_app() -> Control:
	var notes_app := NotesApp.new()
	notes_app.name = "NotesApp"
	notes_app.os_app_init({"shell": self, "filesystem": _fs})
	return notes_app

func _build_text_app() -> Control:
	var text_app := TextEditorApp.new()
	text_app.name = "TextEditorApp"
	text_app.os_app_init({"shell": self, "filesystem": _fs})
	return text_app

func _build_calculator_app() -> Control:
	var calc_app := CalculatorApp.new()
	calc_app.name = "CalculatorApp"
	calc_app.os_app_init({"shell": self, "filesystem": _fs})
	return calc_app

func _build_media_player_app() -> Control:
	var media_app := MediaPlayerApp.new()
	media_app.name = "MediaPlayerApp"
	media_app.os_app_init({"shell": self, "filesystem": _fs})
	return media_app

func _text_editor_instance(window: OSWindow = null) -> TextEditorApp:
	var target_window := window
	if target_window == null:
		target_window = _current_window_for_app("text")
	if target_window == null or not is_instance_valid(target_window):
		return null
	var node := target_window.find_child("TextEditorApp", true, false)
	if node != null and node is TextEditorApp:
		return node as TextEditorApp
	return null

func _notes_app_instance(window: OSWindow = null) -> NotesApp:
	var target_window := window
	if target_window == null:
		target_window = _current_window_for_app("notes")
	if target_window == null or not is_instance_valid(target_window):
		return null
	var node := target_window.find_child("NotesApp", true, false)
	if node != null and node is NotesApp:
		return node as NotesApp
	return null

func _open_text_file(path: String, app_id := "text") -> void:
	var target_path := _fs.normalize_path(path)
	if not _fs.is_file(target_path):
		_set_desktop_context_status("File not found: " + target_path, true)
		return
	var window := launch_app(app_id)
	if window == null:
		return
	if app_id == "text":
		var text_app := _text_editor_instance(window)
		if text_app == null:
			return
		text_app.open_file(target_path)
		_focus_window(window)
		return
	if app_id == "notes":
		var notes_app := _notes_app_instance(window)
		if notes_app == null:
			return
		notes_app.open_file(target_path)
		_focus_window(window)
		return
	_set_desktop_context_status("Unsupported text app target: " + app_id, true)

func _build_console_app() -> Control:
	_terminal_session_sequence += 1
	var session_id := "terminal_%d" % _terminal_session_sequence
	var terminal := TerminalApp.new()
	terminal.name = "TerminalApp"
	var initial_cwd: String = _next_console_initial_cwd
	_next_console_initial_cwd = ""
	if initial_cwd == "" or not _fs.is_dir(initial_cwd):
		initial_cwd = _fs.home_path()
	var state := {"cwd": initial_cwd, "history": [], "session_id": session_id}
	_terminal_sessions[session_id] = state
	terminal.os_app_init({"shell": self, "filesystem": _fs, "state": state, "session_id": session_id})
	return terminal

func _build_hermes_chat_app() -> Control:
	var host := Control.new()
	host.name = "HermesChatHost"
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var runtime := HermesUIRuntime.new()
	runtime.set_os_context({
		"shell": self,
		"filesystem": _fs,
		"event_bus": _event_bus,
		"window_manager": _window_manager,
		"app_registry": _app_registry,
		"notification_center": _notification_center,
		"agent_service": _hermes_agent_service
	})
	var instance = runtime.create_app_instance("res://addons/hermes_os/scripts/apps/hermes_chat/manifest.json")
	host.set_meta("hermes_ui_runtime", runtime)
	host.set_meta("hermes_ui_instance", instance)
	if instance == null:
		var error_label := Label.new()
		error_label.name = "HermesChatManifestError"
		error_label.text = "Hermes Chat manifest failed to load."
		error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		error_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		host.add_child(error_label)
		return host
	var mounted: Control = runtime.mount_instance(instance, host)
	if mounted == null:
		var mount_error := Label.new()
		mount_error.name = "HermesChatMountError"
		mount_error.text = "Hermes Chat runtime failed to mount."
		mount_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mount_error.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		host.add_child(mount_error)
	host.tree_exiting.connect(func() -> void:
		if runtime != null and instance != null:
			runtime.unmount_instance(instance)
	)
	return host

func _build_browser_app() -> Control:
	var browser := BrowserApp.new()
	browser.name = "BrowserApp"
	browser.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	browser.size_flags_vertical = Control.SIZE_EXPAND_FILL
	browser.set_meta("window_min_size", Vector2(760, 520))
	browser.os_app_init({"shell": self, "filesystem": _fs})
	return browser

func _browser_instance() -> BrowserApp:
	if not _open_windows.has("browser"):
		return null
	var window := _open_windows["browser"] as OSWindow
	if window == null or not is_instance_valid(window):
		return null
	var node := window.find_child("BrowserApp", true, false)
	if node != null and node is BrowserApp:
		return node as BrowserApp
	return null

func _open_browser_url(url: String) -> Dictionary:
	var clean_url := url.strip_edges()
	if clean_url == "":
		clean_url = "http://home.hermes/"
	var window := launch_app("browser")
	if window == null:
		return {"ok": false, "error": HermesProtocol.make_error("OPEN_FAILED", "Could not open browser")}
	var browser := _browser_instance()
	if browser == null:
		return {"ok": false, "error": HermesProtocol.make_error("BROWSER_UNAVAILABLE", "Browser instance unavailable")}
	browser.open_url(clean_url)
	_focus_window(window)
	_emit_hermes_event("browser.page_opened", {"url": browser.get_current_url(), "title": browser.get_current_title()})
	return {"ok": true, "result": {"url": browser.get_current_url(), "title": browser.get_current_title(), "window_id": _window_id(window)}}

func _browser_search(query: String) -> Dictionary:
	var clean_query := query.strip_edges()
	if clean_query == "":
		return {"ok": false, "error": HermesProtocol.make_error("MISSING_ARG", "browser.search requires query")}
	var window := launch_app("browser")
	if window == null:
		return {"ok": false, "error": HermesProtocol.make_error("OPEN_FAILED", "Could not open browser")}
	var browser := _browser_instance()
	if browser == null:
		return {"ok": false, "error": HermesProtocol.make_error("BROWSER_UNAVAILABLE", "Browser instance unavailable")}
	browser.search(clean_query)
	_focus_window(window)
	_emit_hermes_event("browser.search_submitted", {"query": clean_query, "url": browser.get_current_url()})
	return {"ok": true, "result": {"query": clean_query, "url": browser.get_current_url(), "window_id": _window_id(window)}}

func _browser_state_snapshot() -> Dictionary:
	var browser := _browser_instance()
	if browser == null:
		return {"open": false, "current_url": "", "title": ""}
	return {"open": true, "current_url": browser.get_current_url(), "title": browser.get_current_title()}

func _handle_console_command(command: String, input: LineEdit, state: Dictionary) -> void:
	var clean := command.strip_edges()
	if clean == "":
		return
	var backend := _create_terminal_backend(state)
	var prompt := backend.get_prompt()
	var result: Dictionary = backend.run_command(clean)
	if bool(result.get("clear_screen", false)):
		_console_history.clear()
		_refresh_console_outputs()
		input.text = ""
		input.placeholder_text = backend.get_prompt()
		return
	var output := str(result.get("stdout", ""))
	if output == "":
		output = str(result.get("stderr", ""))
	_append_console_entry(prompt, clean, output)
	input.text = ""
	input.placeholder_text = backend.get_prompt()

func _create_terminal_backend(state: Dictionary, session_id: String = "") -> TerminalShellBackend:
	if not state.has("cwd"):
		state["cwd"] = _fs.home_path()
	var backend := TerminalShellBackend.new()
	backend.terminal_shell_init({"shell": self, "filesystem": _fs, "state": state, "session_id": session_id})
	return backend

func _register_console_output(output: TextEdit) -> void:
	if output == null:
		return
	if not _console_outputs.has(output):
		_console_outputs.append(output)

func _unregister_console_output(output: TextEdit) -> void:
	if output == null:
		return
	_console_outputs.erase(output)

func _console_history_text() -> String:
	if _console_history.is_empty():
		return ""
	return "\n".join(_console_history)

func _refresh_console_outputs() -> void:
	var history_text := _console_history_text()
	for i in range(_console_outputs.size() - 1, -1, -1):
		var output := _console_outputs[i]
		if output == null or not is_instance_valid(output):
			_console_outputs.remove_at(i)
			continue
		output.text = history_text
		output.scroll_vertical = max(output.get_line_count() - 1, 0)

func _append_console_entry(prompt: String, command: String, result: String) -> void:
	if _console_history.is_empty():
		_console_history.append("Type 'help' for commands. Current user: " + _fs.current_user())
	var command_line := prompt
	if command.strip_edges() != "":
		command_line += " " + command
	_console_history.append(command_line)
	_console_history.append(result)
	if _console_history.size() > CONSOLE_HISTORY_MAX_LINES:
		_console_history = _console_history.slice(_console_history.size() - CONSOLE_HISTORY_MAX_LINES, _console_history.size())
	_refresh_console_outputs()

func _append_hermes_terminal_output(text: String, source := "Hermes", terminal_session_id: String = "") -> void:
	var clean_source := source.strip_edges()
	if clean_source == "":
		clean_source = "Hermes"
	var message := text.strip_edges()
	_append_console_entry("[" + clean_source + "]", "", message if message != "" else "(no output)")
	if terminal_session_id != "" and _terminal_instances.has(terminal_session_id):
		var terminal: Variant = _terminal_instances[terminal_session_id]
		if terminal != null and is_instance_valid(terminal) and (terminal as Object).has_method("append_external_output"):
			(terminal as Object).call("append_external_output", message if message != "" else "(no output)", clean_source)
		return
	for key in _terminal_instances.keys():
		var instance: Variant = _terminal_instances[key]
		if instance != null and is_instance_valid(instance) and (instance as Object).has_method("append_external_output"):
			(instance as Object).call("append_external_output", message if message != "" else "(no output)", clean_source)

func _register_terminal_instance(session_id: String, terminal: Object) -> void:
	if session_id.strip_edges() == "" or terminal == null:
		return
	_terminal_instances[session_id] = terminal

func _unregister_terminal_instance(session_id: String, terminal: Object) -> void:
	if session_id.strip_edges() == "":
		return
	if _terminal_instances.get(session_id, null) == terminal:
		_terminal_instances.erase(session_id)

func _normalize_v1_operation(op: String, args: Dictionary) -> Dictionary:
	var clean_op := op.strip_edges()
	if HERMES_V1_ALIAS_OPS.has(clean_op):
		clean_op = str(HERMES_V1_ALIAS_OPS[clean_op])
	return {"op": clean_op, "args": args.duplicate(true)}

func _console_prompt(state: Dictionary) -> String:
	var symbol := "#" if _fs.current_user() == OSFileSystem.ROOT_USER else "$"
	return _fs.current_user() + ":" + str(state.get("cwd", _fs.home_path())) + symbol

func _resolve_command_path(path: String, state: Dictionary) -> String:
	return _fs.resolve_path(path, str(state.get("cwd", _fs.home_path())))

func _build_system_app() -> Control:
	var system_app := SystemSettingsApp.new()
	system_app.name = "SystemSettingsApp"
	system_app.os_app_init({"shell": self, "filesystem": _fs})
	return system_app

func _build_account_center_app() -> Control:
	var account_app := AccountCenterApp.new()
	account_app.name = "AccountCenterApp"
	account_app.os_app_init({"shell": self, "filesystem": _fs})
	return account_app

func _build_command_palette_app() -> Control:
	var command_palette_app := CommandPaletteApp.new()
	command_palette_app.name = "CommandPaletteApp"
	command_palette_app.os_app_init({"shell": self, "filesystem": _fs})
	return command_palette_app

func _apps_text() -> String:
	var lines: Array[String] = []
	for app_id in _app_order:
		var app: Dictionary = _apps[app_id]
		lines.append(app_id + " - " + str(app["title"]))
	return "\n".join(lines)

func _app_ids_text() -> String:
	return ", ".join(_app_order)

func _windows_text() -> String:
	if _open_windows.is_empty():
		return "none"
	var lines: Array[String] = []
	for key in _open_windows.keys():
		var window := _open_windows[key] as OSWindow
		if is_instance_valid(window):
			lines.append(str(key) + (" visible" if window.visible else " minimized"))
	return "\n".join(lines)

func _virtual_files_text(path: String) -> String:
	var normalized := _fs.normalize_path(path)
	if not _fs.is_dir(normalized):
		return "Folder not found: " + normalized
	if not _fs.can_list_dir(normalized):
		return "Permission denied: " + normalized
	var entries := _fs.list_dir(normalized)
	if entries.is_empty():
		return "Empty folder"
	var lines: Array[String] = []
	for entry in entries:
		var item: Dictionary = entry
		var name := str(item["name"])
		if str(item["type"]) == "dir":
			name += "/"
		lines.append("%s %s %s %d %s" % [str(item["mode"]), str(item["owner"]), str(item["group"]), int(item["size"]), name])
	return "\n".join(lines)

func _command_requires_path(parts: PackedStringArray, command_name: String) -> String:
	if parts.size() < 2:
		return "Usage: " + command_name + " <path>"
	return ""

func _time_text() -> String:
	var now := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [now.year, now.month, now.day, now.hour, now.minute, now.second]

func _emit_hermes_event(event_name: String, payload: Dictionary = {}) -> void:
	if _event_bus != null:
		_event_bus.emit_event(StringName(event_name), payload)
		return
	hermes_event.emit(event_name, payload)

func _on_file_system_event(event_name: StringName, payload: Dictionary) -> void:
	_emit_hermes_event(str(event_name), payload)

func _on_os_event_bus_event_emitted(event_name: StringName, payload: Dictionary) -> void:
	var event_text := str(event_name)
	hermes_event.emit(event_text, payload)
	if event_text in ["file.created", "file.updated", "file.deleted", "file.moved", "file.copied"]:
		_refresh_desktop_icons_for_file_event(payload)

func _refresh_desktop_icons_for_file_event(payload: Dictionary) -> void:
	if _fs == null or _desktop_icons == null:
		return
	var desktop_path := _fs.normalize_path(_desktop_folder_path())
	var candidate_paths: Array[String] = []
	for key in ["path", "source", "destination"]:
		var value := str(payload.get(key, "")).strip_edges()
		if value != "":
			candidate_paths.append(_fs.normalize_path(value))
	for path in candidate_paths:
		if path == desktop_path or path.begins_with(desktop_path + "/"):
			_refresh_desktop_icons()
			return

func _hermes_kernel_node() -> Node:
	return get_node_or_null("/root/HermesOSKernel")

func _kernel_bridge_state() -> Dictionary:
	var kernel := _hermes_kernel_node()
	if kernel == null or not kernel.has_method("get_bridge_state"):
		return {
			"connected": false,
			"endpoint": "",
			"session_id": "",
			"last_message_at": 0,
			"last_error": {},
			"metrics": {}
		}
	var state: Variant = kernel.call("get_bridge_state")
	if state is Dictionary:
		return state
	return {
		"connected": false,
		"endpoint": "",
		"session_id": "",
		"last_message_at": 0,
		"last_error": {},
		"metrics": {}
	}

func _window_id(window: OSWindow) -> String:
	return "win_%s" % str(window.get_instance_id())

func _find_window_by_id(window_id: String) -> OSWindow:
	for key in _open_windows.keys():
		var window := _open_windows[key] as OSWindow
		if is_instance_valid(window) and _window_id(window) == window_id:
			return window
	return null

func _window_state_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in _open_windows.keys():
		var window := _open_windows[key] as OSWindow
		if not is_instance_valid(window):
			continue
		result.append({
			"id": _window_id(window),
			"app_id": window.app_id,
			"title": window.app_title,
			"focused": _active_window == window,
			"minimized": not window.visible,
			"maximized": false,
			"position": [window.position.x, window.position.y],
			"size": [window.size.x, window.size.y],
			"z_index": window.get_index()
		})
	return result

func _notes_directory_path() -> String:
	return _fs.join_path(_fs.home_path(), "notes")

func _ensure_notes_directory() -> String:
	var path := _notes_directory_path()
	if _fs.is_dir(path):
		return ""
	var message := _fs.make_dir(path)
	if message.begins_with("Path already exists"):
		return ""
	return message

func _notes_slug(title: String) -> String:
	var clean := title.strip_edges().to_lower()
	if clean == "":
		clean = "untitled"
	clean = clean.replace("/", "-").replace("\\", "-").replace(":", "-").replace("*", "-").replace("?", "-").replace("\"", "-").replace("<", "-").replace(">", "-").replace("|", "-")
	while clean.find("  ") != -1:
		clean = clean.replace("  ", " ")
	clean = clean.replace(" ", "-")
	while clean.find("--") != -1:
		clean = clean.replace("--", "-")
	return clean.strip_edges()

func _note_path_from_id(note_id: String) -> String:
	if note_id.begins_with("/"):
		return _fs.normalize_path(note_id)
	var file_name := note_id.strip_edges()
	if file_name == "":
		file_name = "untitled"
	if not file_name.ends_with(".txt"):
		file_name += ".txt"
	return _fs.join_path(_notes_directory_path(), file_name)

func _create_unique_note_path(title: String) -> String:
	var slug := _notes_slug(title)
	if slug == "":
		slug = "untitled"
	var candidate := _note_path_from_id(slug)
	var suffix := 2
	while _fs.exists(candidate):
		candidate = _note_path_from_id("%s-%d" % [slug, suffix])
		suffix += 1
	return candidate

func _list_notes_state() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	var notes_path := _notes_directory_path()
	if not _fs.is_dir(notes_path):
		return output
	var entries := _fs.list_dir(notes_path)
	for entry in entries:
		var item: Dictionary = entry
		if str(item.get("type", "")) != "file":
			continue
		output.append({
			"note_id": str(item.get("name", "")),
			"path": str(item.get("path", "")),
			"size": int(item.get("size", 0)),
			"owner": str(item.get("owner", ""))
		})
	return output

func _notes_create_note(title: String, content: String) -> Dictionary:
	var dir_message := _ensure_notes_directory()
	if dir_message != "":
		return {"ok": false, "error": HermesProtocol.make_error("NOTES_DIR_FAILED", dir_message)}
	var target_path := _create_unique_note_path(title)
	var write_message := _fs.write_file(target_path, content)
	if write_message != "":
		return {"ok": false, "error": HermesProtocol.make_error("WRITE_FAILED", write_message)}
	var note_id := target_path.get_file()
	_notes_active_note_id = note_id
	if not _notes_open_notes.has(note_id):
		_notes_open_notes.append(note_id)
	_emit_hermes_event("note.created", {"note_id": note_id, "path": target_path})
	_emit_hermes_event("file.created", {"path": target_path})
	return {"ok": true, "result": {"note_id": note_id, "path": target_path}}

func _notes_open_note(note_id_or_path: String) -> Dictionary:
	var dir_message := _ensure_notes_directory()
	if dir_message != "":
		return {"ok": false, "error": HermesProtocol.make_error("NOTES_DIR_FAILED", dir_message)}
	var target_path := _note_path_from_id(note_id_or_path)
	if not _fs.is_file(target_path):
		return {"ok": false, "error": HermesProtocol.make_error("NOTE_NOT_FOUND", "Note not found: " + target_path)}
	_open_text_file(target_path, "notes")
	var note_id := target_path.get_file()
	_notes_active_note_id = note_id
	if not _notes_open_notes.has(note_id):
		_notes_open_notes.append(note_id)
	var read_result := _fs.read_file_result(target_path)
	if not bool(read_result.get("ok", false)):
		return {"ok": false, "error": HermesProtocol.make_error("READ_FAILED", str(read_result.get("error", "Could not read note")))}
	return {
		"ok": true,
		"result": {
			"note_id": note_id,
			"path": target_path,
			"content": str(read_result.get("content", ""))
		}
	}

func _notes_update_note(note_id_or_path: String, content: String) -> Dictionary:
	var target_path := _note_path_from_id(note_id_or_path)
	var write_message := _fs.write_file(target_path, content)
	if write_message != "":
		return {"ok": false, "error": HermesProtocol.make_error("WRITE_FAILED", write_message)}
	var note_id := target_path.get_file()
	_notes_active_note_id = note_id
	var notes_app := _notes_app_instance()
	if notes_app != null and notes_app.get_current_path() == target_path:
		notes_app.set_note_content(content, false)
	if not _notes_open_notes.has(note_id):
		_notes_open_notes.append(note_id)
	_emit_hermes_event("note.updated", {"note_id": note_id, "path": target_path})
	_emit_hermes_event("file.updated", {"path": target_path})
	return {"ok": true, "result": {"note_id": note_id, "path": target_path}}

func hermes_get_state(options := {}) -> Dictionary:
	var include_apps := bool(options.get("include_apps", true)) if options is Dictionary else true
	var include_windows := bool(options.get("include_windows", true)) if options is Dictionary else true
	var include_filesystem := bool(options.get("include_filesystem", false)) if options is Dictionary else false
	var snapshot := {
		"desktop": {
			"focused_window_id": _window_id(_active_window) if _active_window and is_instance_valid(_active_window) else "",
			"session_active": _session_active,
			"current_user": _fs.current_user()
		},
		"notifications": _notifications.duplicate(true),
		"bridge": _kernel_bridge_state()
	}
	if include_windows:
		snapshot["windows"] = _window_state_snapshot()
	if include_apps:
		snapshot["apps"] = {
			"notes": {
				"active_note_id": _notes_active_note_id,
				"open_notes": _notes_open_notes.duplicate(),
				"notes": _list_notes_state()
			},
			"browser": _browser_state_snapshot(),
			"terminal": {
				"sessions": _terminal_sessions.duplicate(true)
			}
		}
	if include_filesystem:
		snapshot["filesystem"] = _fs.export_state()
	return snapshot

func hermes_get_manifest_apps() -> Array[Dictionary]:
	return [
		{
			"id": "desktop",
			"name": "Desktop",
			"description": "Desktop shell actions",
			"actions": {
				"desktop.show_notification": {
					"description": "Display an in-OS notification",
					"args_schema": {"title": "string", "body": "string", "level": "string"}
				}
			}
		},
		{
			"id": "windows",
			"name": "Window Manager",
			"description": "Window operations",
			"actions": {
				"windows.open_app": {"description": "Open app window", "args_schema": {"app_id": "string"}},
				"windows.focus": {"description": "Focus a window", "args_schema": {"window_id": "string", "app_id": "string"}},
				"windows.focus_window": {"description": "Compatibility alias for windows.focus", "args_schema": {"window_id": "string", "app_id": "string"}},
				"windows.close_window": {"description": "Close a window", "args_schema": {"window_id": "string", "app_id": "string"}}
			}
		},
		{
			"id": "files",
			"name": "Files",
			"description": "Virtual filesystem browser",
			"actions": {
				"files.list_dir": {"description": "List a directory", "args_schema": {"path": "string"}},
				"files.read_file": {"description": "Read a file", "args_schema": {"path": "string"}},
				"files.write_file": {"description": "Write a file", "args_schema": {"path": "string", "content": "string"}},
				"files.mkdir": {"description": "Create a directory", "args_schema": {"path": "string"}},
				"files.delete": {"description": "Delete a file or directory", "args_schema": {"path": "string"}},
				"files.move": {"description": "Move or rename a file or directory", "args_schema": {"source": "string", "destination": "string"}},
				"files.copy": {"description": "Copy a file or directory", "args_schema": {"source": "string", "destination": "string"}}
			}
		},
		{
			"id": "notes",
			"name": "Notes",
			"description": "Create and open notes",
			"actions": {
				"notes.create_note": {"description": "Create note", "args_schema": {"title": "string", "content": "string"}},
				"notes.open_note": {"description": "Open note", "args_schema": {"note_id": "string"}},
				"notes.update_note": {"description": "Update note", "args_schema": {"note_id": "string", "content": "string"}},
				"notes.list_notes": {"description": "List notes", "args_schema": {}}
			}
		},
		{
			"id": "browser",
			"name": "Browser",
			"description": "Fake intranet browser",
			"actions": {
				"browser.open_url": {"description": "Open a URL in the browser", "args_schema": {"url": "string"}},
				"browser.search": {"description": "Search the fake intranet", "args_schema": {"query": "string"}}
			}
		},
		{
			"id": "terminal",
			"name": "Terminal",
			"description": "In-game terminal commands",
			"actions": {
				"terminal.open_session": {"description": "Open terminal session", "args_schema": {"cwd": "string"}},
				"terminal.run_command": {"description": "Run command", "args_schema": {"session_id": "string", "command": "string"}},
				"terminal.append_output": {"description": "Append text to in-game terminal transcript", "args_schema": {"text": "string", "source": "string"}},
				"hermes.propose_operation": {"description": "Execute Hermes operation proposal immediately", "args_schema": {"op": "string", "args": "object", "source": "string"}}
			}
		}
	]

func hermes_execute_operation(op: String, args: Dictionary) -> Dictionary:
	if _agent_operation_router != null:
		return _agent_operation_router.execute_operation(op, args)
	if _hermes_agent_service != null:
		var service_router: AgentOperationRouter = _hermes_agent_service.get_operation_router()
		if service_router != null:
			_agent_operation_router = service_router
			return _agent_operation_router.execute_operation(op, args)
	return _hermes_execute_operation_legacy_dispatch(op, args)

func _hermes_execute_operation_legacy_dispatch(op: String, args: Dictionary) -> Dictionary:
	var normalized := _normalize_v1_operation(op, args)
	op = str(normalized.get("op", "")).strip_edges()
	args = normalized.get("args", {}).duplicate(true)
	if op == "":
		return {"ok": false, "error": HermesProtocol.make_error("MISSING_OPERATION", "Operation name is required")}
	if op == "hermes.propose_operation":
		var proposed_op := str(args.get("op", "")).strip_edges()
		var proposed_args: Dictionary = {}
		var proposed_args_value: Variant = args.get("args", {})
		if proposed_args_value is Dictionary:
			proposed_args = (proposed_args_value as Dictionary).duplicate(true)
		if proposed_op == "":
			return {"ok": false, "error": HermesProtocol.make_error("MISSING_ARG", "hermes.propose_operation requires op")}
		if proposed_op == "hermes.propose_operation":
			return {"ok": false, "error": HermesProtocol.make_error("INVALID_PROPOSAL", "Nested hermes.propose_operation is not allowed")}
		var normalized_proposal: Dictionary = _normalize_v1_operation(proposed_op, proposed_args)
		proposed_op = str(normalized_proposal.get("op", "")).strip_edges()
		proposed_args = (normalized_proposal.get("args", {}) as Dictionary).duplicate(true)
		_append_hermes_terminal_output("Executing proposed operation: %s" % proposed_op, str(args.get("source", "Hermes")))
		return hermes_execute_operation(proposed_op, proposed_args)
	match op:
		"desktop.show_notification":
			var title := str(args.get("title", "Hermes"))
			var body := str(args.get("body", ""))
			var level := str(args.get("level", "info"))
			var notification_id := notify({"title": title, "body": body, "level": level, "app_id": "hermes"})
			return {"ok": true, "result": {"displayed": true, "notification_id": notification_id}}
		"windows.open_app":
			var app_id := str(args.get("app_id", ""))
			if app_id == "":
				return {"ok": false, "error": HermesProtocol.make_error("MISSING_ARG", "windows.open_app requires app_id")}
			var window := launch_app(app_id)
			if window == null:
				return {"ok": false, "error": HermesProtocol.make_error("OPEN_FAILED", "Could not open app: " + app_id)}
			return {"ok": true, "result": {"window_id": _window_id(window), "app_id": app_id}}
		"windows.focus_window":
			var focus_window_id := str(args.get("window_id", ""))
			var focus_app_id := str(args.get("app_id", ""))
			var target_window: OSWindow = null
			if focus_window_id != "":
				target_window = _find_window_by_id(focus_window_id)
			elif focus_app_id != "" and _open_windows.has(focus_app_id):
				target_window = _open_windows[focus_app_id] as OSWindow
			if target_window == null or not is_instance_valid(target_window):
				return {"ok": false, "error": HermesProtocol.make_error("WINDOW_NOT_FOUND", "Window not found")}
			_focus_window(target_window)
			return {"ok": true, "result": {"window_id": _window_id(target_window), "app_id": target_window.app_id}}
		"windows.close_window":
			var close_window_id := str(args.get("window_id", ""))
			var close_app_id := str(args.get("app_id", ""))
			var close_window: OSWindow = null
			if close_window_id != "":
				close_window = _find_window_by_id(close_window_id)
			elif close_app_id != "" and _open_windows.has(close_app_id):
				close_window = _open_windows[close_app_id] as OSWindow
			if close_window == null or not is_instance_valid(close_window):
				return {"ok": false, "error": HermesProtocol.make_error("WINDOW_NOT_FOUND", "Window not found")}
			_on_window_close_requested(close_window)
			return {"ok": true, "result": {"closed": true}}
		"files.list_dir":
			var list_path := _fs.normalize_path(str(args.get("path", _fs.home_path())))
			if not _fs.is_dir(list_path):
				return {"ok": false, "error": HermesProtocol.make_error("DIR_NOT_FOUND", "Directory not found: " + list_path)}
			return {"ok": true, "result": {"path": list_path, "entries": _fs.list_dir(list_path)}}
		"files.read_file":
			var read_path := _fs.normalize_path(str(args.get("path", "")))
			if read_path == "":
				return {"ok": false, "error": HermesProtocol.make_error("MISSING_ARG", "files.read_file requires path")}
			var read_result := _fs.read_file_result(read_path)
			if not bool(read_result.get("ok", false)):
				return {"ok": false, "error": HermesProtocol.make_error("READ_FAILED", str(read_result.get("error", "Could not read file")))}
			return {"ok": true, "result": {"path": read_path, "content": str(read_result.get("content", ""))}}
		"files.write_file":
			var write_path := _fs.normalize_path(str(args.get("path", "")))
			if write_path == "":
				return {"ok": false, "error": HermesProtocol.make_error("MISSING_ARG", "files.write_file requires path")}
			var had_file := _fs.exists(write_path)
			var write_message := _fs.write_file(write_path, str(args.get("content", "")))
			if write_message != "":
				return {"ok": false, "error": HermesProtocol.make_error("WRITE_FAILED", write_message)}
			_emit_hermes_event("file.updated" if had_file else "file.created", {"path": write_path})
			return {"ok": true, "result": {"path": write_path, "saved": true}}
		"notes.create_note":
			return _notes_create_note(str(args.get("title", "Untitled")), str(args.get("content", "")))
		"notes.open_note":
			return _notes_open_note(str(args.get("note_id", args.get("path", ""))))
		"notes.update_note":
			return _notes_update_note(str(args.get("note_id", args.get("path", ""))), str(args.get("content", "")))
		"notes.list_notes":
			return {"ok": true, "result": {"notes": _list_notes_state(), "path": _notes_directory_path()}}
		"browser.open_url":
			return _open_browser_url(str(args.get("url", args.get("href", ""))))
		"browser.search":
			return _browser_search(str(args.get("query", "")))
		"terminal.open_session":
			var cwd := _fs.resolve_path(str(args.get("cwd", "~")), _fs.home_path())
			if not _fs.is_dir(cwd):
				cwd = _fs.home_path()
			_terminal_session_sequence += 1
			var session_id := str(args.get("session_id", "t_%d" % _terminal_session_sequence))
			_terminal_sessions[session_id] = {"cwd": cwd, "opened_at": int(Time.get_unix_time_from_system())}
			_emit_hermes_event("terminal.session_opened", {"session_id": session_id, "cwd": cwd})
			return {"ok": true, "result": {"session_id": session_id, "cwd": cwd}}
		"terminal.run_command":
			var command := str(args.get("command", "")).strip_edges()
			if command == "":
				return {"ok": false, "error": HermesProtocol.make_error("MISSING_ARG", "terminal.run_command requires command")}
			var terminal_session_id := str(args.get("session_id", ""))
			var terminal_state := {"cwd": _fs.home_path()}
			if terminal_session_id != "" and _terminal_sessions.has(terminal_session_id):
				terminal_state = _terminal_sessions[terminal_session_id]
			_emit_hermes_event("terminal.command_started", {"session_id": terminal_session_id, "command": command})
			var terminal_result := _execute_terminal_command(command, terminal_state)
			if terminal_session_id != "":
				_terminal_sessions[terminal_session_id] = terminal_state
			_emit_hermes_event("terminal.command_finished", {
				"session_id": terminal_session_id,
				"command": command,
				"exit_code": int(terminal_result.get("exit_code", 1))
			})
			_append_console_entry("[Hermes:" + (terminal_session_id if terminal_session_id != "" else "session") + "]", command, str(terminal_result.get("stdout", "")).strip_edges() if str(terminal_result.get("stdout", "")).strip_edges() != "" else str(terminal_result.get("stderr", "")).strip_edges())
			return {"ok": true, "result": terminal_result}
		"terminal.append_output":
			var text := str(args.get("text", "")).strip_edges()
			if text == "":
				return {"ok": false, "error": HermesProtocol.make_error("MISSING_ARG", "terminal.append_output requires text")}
			_append_hermes_terminal_output(text, str(args.get("source", "Hermes")))
			return {"ok": true, "result": {"appended": true}}
		_:
			return {"ok": false, "error": HermesProtocol.make_error("UNKNOWN_OPERATION", "No registered operation: " + op)}

func _execute_terminal_command(command: String, state: Dictionary) -> Dictionary:
	var backend := _create_terminal_backend(state)
	var result: Dictionary = backend.run_command(command)
	return {
		"stdout": str(result.get("stdout", "")),
		"stderr": str(result.get("stderr", "")),
		"exit_code": int(result.get("exit_code", 0)),
		"cwd": str(result.get("cwd", state.get("cwd", _fs.home_path())))
	}

func _color_from_variant(value: Variant, fallback: Color) -> Color:
	if value is Array:
		var parts: Array = value
		if parts.size() >= 3:
			var alpha := float(parts[3]) if parts.size() >= 4 else fallback.a
			return Color(float(parts[0]), float(parts[1]), float(parts[2]), alpha)
	if value is Dictionary:
		var data: Dictionary = value
		if data.has("r") and data.has("g") and data.has("b"):
			return Color(float(data.get("r", fallback.r)), float(data.get("g", fallback.g)), float(data.get("b", fallback.b)), float(data.get("a", fallback.a)))
	return fallback

func _app_root() -> VBoxContainer:
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	return root

func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _month_name(month: int) -> String:
	var names := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	if month < 1 or month > names.size():
		return "Mon"
	return str(names[month - 1])

func _set_status(label: Label, message: String, is_error := false) -> void:
	label.text = message
	label.add_theme_color_override("font_color", Tokens.ERROR if is_error else Tokens.MUTED)

func _button(text_value: String, min_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = min_size
	button.add_theme_color_override("font_color", Tokens.TEXT)
	button.add_theme_color_override("font_hover_color", Tokens.TEXT)
	button.add_theme_color_override("font_pressed_color", Tokens.TEXT)
	button.add_theme_color_override("font_disabled_color", Tokens.TEXT_DISABLED)
	button.add_theme_stylebox_override("normal", StyleFactory.button_normal(8))
	button.add_theme_stylebox_override("hover", StyleFactory.button_hover(8))
	button.add_theme_stylebox_override("pressed", StyleFactory.button_pressed(8))
	button.add_theme_stylebox_override("focus", StyleFactory.button_focus(8))
	button.add_theme_stylebox_override("disabled", StyleFactory.button_disabled(8))
	# Smooth hover scale (disabled in headless)
	if DisplayServer.get_name() != "headless":
		button.mouse_entered.connect(func() -> void:
			var tw: Tween = button.create_tween()
			tw.set_trans(Tween.TRANS_QUAD)
			tw.set_ease(Tween.EASE_OUT)
			tw.tween_property(button, "scale", Vector2(1.02, 1.02), Tokens.TIME["fast"])
		)
		button.mouse_exited.connect(func() -> void:
			var tw: Tween = button.create_tween()
			tw.set_trans(Tween.TRANS_QUAD)
			tw.set_ease(Tween.EASE_OUT)
			tw.tween_property(button, "scale", Vector2(1.0, 1.0), Tokens.TIME["fast"])
		)
		button.pivot_offset = min_size / 2.0
	return button

var _icon_atlas: IconAtlas

func _ensure_icon_atlas() -> void:
	if _icon_atlas == null:
		_icon_atlas = IconAtlas.new()
	_icon_atlas.set_icon_color(Tokens.TEXT)

func _icon_button(icon_name: String, min_size: Vector2) -> Button:
	_ensure_icon_atlas()
	var button := Button.new()
	button.custom_minimum_size = min_size
	button.icon = _icon_atlas.get_icon(icon_name, int(min(minf(min_size.x, min_size.y) * 0.55, 22)))
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_theme_color_override("font_color", Tokens.TEXT)
	button.add_theme_stylebox_override("normal", StyleFactory.icon_button_normal(8))
	button.add_theme_stylebox_override("hover", StyleFactory.icon_button_hover(8))
	button.add_theme_stylebox_override("pressed", StyleFactory.icon_button_pressed(8))
	button.add_theme_stylebox_override("focus", StyleFactory.icon_button_focus(8))
	# Smooth hover scale (disabled in headless)
	if DisplayServer.get_name() != "headless":
		button.mouse_entered.connect(func() -> void:
			var tw: Tween = button.create_tween()
			tw.set_trans(Tween.TRANS_QUAD)
			tw.set_ease(Tween.EASE_OUT)
			tw.tween_property(button, "scale", Vector2(1.06, 1.06), Tokens.TIME["fast"])
		)
		button.mouse_exited.connect(func() -> void:
			var tw: Tween = button.create_tween()
			tw.set_trans(Tween.TRANS_QUAD)
			tw.set_ease(Tween.EASE_OUT)
			tw.tween_property(button, "scale", Vector2(1.0, 1.0), Tokens.TIME["fast"])
		)
		button.pivot_offset = min_size / 2.0
	return button

func _files_menu_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(52, 28)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Tokens.MUTED)
	button.add_theme_color_override("font_hover_color", Tokens.TEXT)
	button.add_theme_color_override("font_pressed_color", Tokens.TEXT)
	button.add_theme_stylebox_override("hover", StyleFactory.build(Tokens.alpha(Tokens.WHITE, 0.06), Color(0, 0, 0, 0), 0, 6))
	button.add_theme_stylebox_override("pressed", StyleFactory.build(Tokens.alpha(Tokens.WHITE, 0.10), Color(0, 0, 0, 0), 0, 6))
	return button

func _files_sidebar_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 30)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Tokens.MUTED)
	button.add_theme_color_override("font_hover_color", Tokens.TEXT)
	button.add_theme_color_override("font_pressed_color", Tokens.TEXT)
	button.add_theme_stylebox_override("normal", StyleFactory.build(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 6))
	button.add_theme_stylebox_override("hover", StyleFactory.build(Tokens.alpha(Tokens.WHITE, 0.06), Color(0, 0, 0, 0), 0, 6))
	button.add_theme_stylebox_override("pressed", StyleFactory.build(Tokens.alpha(Tokens.WHITE, 0.10), Color(0, 0, 0, 0), 0, 6))
	button.add_theme_stylebox_override("focus", StyleFactory.build(Color(0, 0, 0, 0), Tokens.FOCUS, 1, 6))
	return button

func _files_chrome_button(text_value: String, min_size: Vector2) -> Button:
	var button := _button(text_value, min_size)
	button.add_theme_font_size_override("font_size", 13)
	return button

func _files_table_header_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.custom_minimum_size = Vector2(0, 26)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Tokens.TEXT)
	return label

func _style_files_tree(tree: Tree) -> void:
	tree.add_theme_color_override("font_color", Tokens.TEXT)
	tree.add_theme_color_override("font_selected_color", Tokens.TEXT)
	tree.add_theme_color_override("guide_color", Tokens.alpha(Tokens.WHITE, 0.04))
	tree.add_theme_stylebox_override("panel", StyleFactory.list_panel(10))
	tree.add_theme_stylebox_override("selected", StyleFactory.list_selected())
	tree.add_theme_stylebox_override("selected_focus", StyleFactory.list_selected())
	tree.add_theme_stylebox_override("cursor", StyleFactory.list_selected())
	tree.add_theme_stylebox_override("cursor_unfocused", StyleFactory.build(Tokens.alpha(Tokens.SURFACE, 0.5), Tokens.BORDER_ACTIVE, 1, 4))
	tree.add_theme_stylebox_override("focus", StyleFactory.build(Color(0, 0, 0, 0), Tokens.FOCUS, 2, 10))

func _style_line_edit(input: LineEdit) -> void:
	input.add_theme_color_override("font_color", Tokens.TEXT)
	input.add_theme_color_override("caret_color", Tokens.TEXT)
	input.add_theme_color_override("font_placeholder_color", Tokens.MUTED)
	input.add_theme_stylebox_override("normal", StyleFactory.input_field(8))
	input.add_theme_stylebox_override("focus", StyleFactory.input_field_focus(8))

func _style_text_edit(input: TextEdit) -> void:
	input.add_theme_color_override("font_color", Tokens.TEXT)
	input.add_theme_color_override("font_readonly_color", Tokens.MUTED)
	input.add_theme_color_override("caret_color", Tokens.TEXT)
	input.add_theme_stylebox_override("normal", StyleFactory.input_field(8))
	input.add_theme_stylebox_override("focus", StyleFactory.input_field_focus(8))
	input.add_theme_stylebox_override("read_only", StyleFactory.build(Tokens.alpha(Tokens.PANEL, 0.5), Tokens.BORDER, 1, 8))

func _style_item_list(list: ItemList) -> void:
	list.add_theme_color_override("font_color", Tokens.TEXT)
	list.add_theme_color_override("font_selected_color", Tokens.TEXT)
	list.add_theme_stylebox_override("panel", StyleFactory.list_panel(10))
	list.add_theme_stylebox_override("focus", StyleFactory.build(Color(0, 0, 0, 0), Tokens.FOCUS, 2, 8))
	list.add_theme_stylebox_override("selected", StyleFactory.list_selected())
	list.add_theme_stylebox_override("selected_focus", StyleFactory.list_selected())

func _style(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	return StyleFactory.build(bg, border, border_width, radius)

func _style_corners(bg: Color, border: Color, border_width: int, top_left: int, top_right: int, bottom_left: int, bottom_right: int) -> StyleBoxFlat:
	var style := StyleFactory.build(bg, border, border_width, top_left)
	style.corner_radius_top_left = top_left
	style.corner_radius_top_right = top_right
	style.corner_radius_bottom_left = bottom_left
	style.corner_radius_bottom_right = bottom_right
	return style
