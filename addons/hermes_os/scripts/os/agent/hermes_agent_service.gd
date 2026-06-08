class_name HermesAgentService
extends RefCounted

const OSEventBus = preload("res://addons/hermes_os/scripts/os/core/os_event_bus.gd")
const AgentContextBuilder = preload("res://addons/hermes_os/scripts/os/agent/agent_context_builder.gd")
const AgentOperationRouter = preload("res://addons/hermes_os/scripts/os/agent/agent_operation_router.gd")
const HermesGatewayClient = preload("res://addons/hermes_os/scripts/os/agent/hermes_gateway_client.gd")

signal stream_delta_received(payload: Dictionary)
signal stream_completed(payload: Dictionary)

var _shell: Node
var _event_bus: OSEventBus
var _notification_center: RefCounted
var _filesystem: RefCounted
var _window_manager: RefCounted
var _app_registry: RefCounted
var _context_builder: AgentContextBuilder
var _operation_router: AgentOperationRouter
var _gateway_client: HermesGatewayClient

var _initialized: bool = false
var _busy: bool = false
var _last_message: String = ""
var _last_response: Dictionary = {}
var _last_error: Dictionary = {}
var _last_context: Dictionary = {}
var _streaming_mode: bool = false

func os_agent_init(context: Dictionary) -> void:
	_shell = context.get("shell", null) as Node
	_event_bus = context.get("event_bus", null) as OSEventBus
	_notification_center = context.get("notification_center", null) as RefCounted
	_filesystem = context.get("filesystem", null) as RefCounted
	_window_manager = context.get("window_manager", null) as RefCounted
	_app_registry = context.get("app_registry", null) as RefCounted
	_context_builder = AgentContextBuilder.new()
	_context_builder.agent_context_init({
		"shell": _shell,
		"event_bus": _event_bus,
		"notification_center": _notification_center,
		"filesystem": _filesystem,
		"window_manager": _window_manager,
		"app_registry": _app_registry
	})
	_operation_router = AgentOperationRouter.new()
	_operation_router.agent_router_init({
		"shell": _shell,
		"event_bus": _event_bus,
		"notification_center": _notification_center,
		"filesystem": _filesystem,
		"window_manager": _window_manager,
		"app_registry": _app_registry
	})
	_gateway_client = HermesGatewayClient.new()
	_gateway_client.gateway_init({
		"shell": _shell,
		"gateway": context.get("gateway", {}) if context.get("gateway", {}) is Dictionary else {}
	})
	_gateway_client.response_received.connect(_on_gateway_response_received)
	_gateway_client.error_received.connect(_on_gateway_error_received)
	_gateway_client.status_changed.connect(_on_gateway_status_changed)
	_gateway_client.stream_delta_received.connect(_on_gateway_stream_delta)
	_gateway_client.stream_completed.connect(_on_gateway_stream_completed)
	_initialized = true
	_emit_status_changed()

func get_status() -> Dictionary:
	var gateway_state: Dictionary = _gateway_status()
	return {
		"initialized": _initialized,
		"busy": _busy or bool(gateway_state.get("busy", false)),
		"streaming_mode": _streaming_mode,
		"connected": bool(gateway_state.get("configured", false)),
		"gateway": gateway_state.duplicate(true),
		"bridge": _bridge_state().duplicate(true),
		"last_message": _last_message,
		"last_response": _last_response.duplicate(true),
		"last_error": _last_error.duplicate(true),
		"last_context": _last_context.duplicate(true),
		"operation_router_initialized": _operation_router != null and _operation_router.is_initialized()
	}

func get_context(options: Dictionary = {}) -> Dictionary:
	if _context_builder == null:
		return {}
	return _context_builder.build_context(options)

func get_context_builder() -> AgentContextBuilder:
	return _context_builder

func get_operation_router() -> AgentOperationRouter:
	return _operation_router

func execute_operation(op: String, args: Dictionary = {}) -> Dictionary:
	if _operation_router == null:
		return {"ok": false, "error": {"code": "ROUTER_UNAVAILABLE", "message": "AgentOperationRouter is unavailable", "details": {}}, "result": {}, "operation": op}
	return _operation_router.execute_operation(op, args)

func get_supported_operations() -> Array[String]:
	if _operation_router == null:
		return []
	return _operation_router.get_supported_operations()

func get_operation_metadata(operation: String) -> Dictionary:
	if _operation_router == null:
		return {"operation": operation, "capability": "legacy.compat", "risk": "medium", "mutates_state": false, "description": "AgentOperationRouter is unavailable", "requires_approval": false}
	return _operation_router.get_operation_metadata(operation)

func describe_operation(operation: String) -> Dictionary:
	if _operation_router == null:
		return {"operation": operation, "capability": "legacy.compat", "risk": "medium", "mutates_state": false, "description": "AgentOperationRouter is unavailable", "requires_approval": false}
	return _operation_router.describe_operation(operation)

func send_user_message(message: String, options: Dictionary = {}) -> Dictionary:
	return _send_message(message, options)

func send_user_message_stream(message: String, options: Dictionary = {}) -> Dictionary:
	return _send_message_stream(message, options)

func send_terminal_message(message: String, terminal_context: Dictionary = {}) -> Dictionary:
	var options: Dictionary = terminal_context.duplicate(true)
	options["source"] = str(options.get("source", "terminal"))
	return _send_message(message, options)

func notify_response(payload: Dictionary) -> void:
	_last_response = payload.duplicate(true)
	_last_error.clear()
	_busy = false
	_streaming_mode = false
	_emit_service_event(OSEventBus.AGENT_RESPONSE_RECEIVED, payload)
	_emit_status_changed()

func notify_error(message: String, details: Dictionary = {}) -> void:
	_last_error = details.duplicate(true)
	_last_error["message"] = message
	_busy = false
	_streaming_mode = false
	_emit_service_event(OSEventBus.AGENT_ERROR, _last_error)
	_emit_status_changed()

func _send_message(message: String, options: Dictionary) -> Dictionary:
	var prompt: String = message.strip_edges()
	_last_message = prompt
	_last_response.clear()
	_last_error.clear()
	if prompt == "":
		notify_error("Usage: hermes <prompt>", {"code": "MISSING_PROMPT"})
		return {"ok": false, "terminal_result": "Usage: hermes <prompt>", "error": _last_error.duplicate(true)}

	# Try local device command interception (before gateway)
	var device_result := _try_local_device_command(prompt)
	if device_result.get("handled", false):
		var response_text: String = str(device_result.get("message", "Done."))
		_last_response = {"ok": true, "terminal_result": response_text}
		_busy = false
		return {"ok": true, "terminal_result": response_text}

	_last_context = _build_terminal_context(prompt, options)
	_busy = true
	_emit_status_changed()
	var terminal_context: Dictionary = _last_context.get("terminal", {}) if _last_context.get("terminal", {}) is Dictionary else {}
	var payload: Dictionary = {
		"prompt": prompt,
		"cwd": str(terminal_context.get("cwd", options.get("cwd", _home_path()))),
		"user": str(terminal_context.get("user", options.get("user", _current_user()))),
		"timestamp": int(options.get("timestamp", Time.get_unix_time_from_system())),
		"source": str(options.get("source", "user")),
		"context": _last_context.duplicate(true)
	}
	_emit_service_event(OSEventBus.AGENT_MESSAGE_SENT, payload)
	if _gateway_client == null:
		notify_error("Hermes Gateway client is unavailable.", {"code": "GATEWAY_UNAVAILABLE"})
		return {"ok": false, "terminal_result": "Hermes Gateway client is unavailable.", "error": _last_error.duplicate(true), "context": _last_context.duplicate(true)}
	var request_options := _last_context.duplicate(true)
	request_options["terminal"] = terminal_context.duplicate(true)
	request_options["system"] = _hermes_os_control_system_prompt()
	var response: Dictionary = _gateway_client.send_message(prompt, request_options)
	if not bool(response.get("ok", false)):
		notify_error(str(response.get("terminal_result", "Hermes Gateway request failed")), response.get("error", {}) if response.get("error", {}) is Dictionary else {})
		return {"ok": false, "terminal_result": str(response.get("terminal_result", "Hermes Gateway request failed")), "error": _last_error.duplicate(true), "context": _last_context.duplicate(true)}
	_last_response = {"queued": true, "terminal_result": str(response.get("terminal_result", "Sent to Hermes Gateway")), "gateway": _gateway_client.get_status()}
	_emit_status_changed()
	return {"ok": true, "terminal_result": str(response.get("terminal_result", "Sent to Hermes Gateway")), "result": _last_response.duplicate(true), "context": _last_context.duplicate(true)}

func _send_message_stream(message: String, options: Dictionary) -> Dictionary:
	var prompt: String = message.strip_edges()
	_last_message = prompt
	_last_response.clear()
	_last_error.clear()
	if prompt == "":
		notify_error("Usage: hermes <prompt>", {"code": "MISSING_PROMPT"})
		return {"ok": false, "terminal_result": "Usage: hermes <prompt>", "error": _last_error.duplicate(true)}

	# Try local device command interception (before gateway)
	var device_result := _try_local_device_command(prompt)
	if device_result.get("handled", false):
		var response_text: String = str(device_result.get("message", "Done."))
		_last_response = {"ok": true, "terminal_result": response_text}
		_busy = false
		_streaming_mode = false
		return {"ok": true, "terminal_result": response_text}

	_last_context = _build_terminal_context(prompt, options)
	_busy = true
	_streaming_mode = true
	_emit_status_changed()
	var terminal_context: Dictionary = _last_context.get("terminal", {}) if _last_context.get("terminal", {}) is Dictionary else {}
	var payload: Dictionary = {
		"prompt": prompt,
		"cwd": str(terminal_context.get("cwd", options.get("cwd", _home_path()))),
		"user": str(terminal_context.get("user", options.get("user", _current_user()))),
		"timestamp": int(options.get("timestamp", Time.get_unix_time_from_system())),
		"source": str(options.get("source", "user")),
		"context": _last_context.duplicate(true),
		"stream": true
	}
	_emit_service_event(OSEventBus.AGENT_MESSAGE_SENT, payload)
	if _gateway_client == null:
		_streaming_mode = false
		notify_error("Hermes Gateway client is unavailable.", {"code": "GATEWAY_UNAVAILABLE"})
		return {"ok": false, "terminal_result": "Hermes Gateway client is unavailable.", "error": _last_error.duplicate(true), "context": _last_context.duplicate(true)}
	var request_options := _last_context.duplicate(true)
	request_options["terminal"] = terminal_context.duplicate(true)
	request_options["system"] = _hermes_os_control_system_prompt()
	var response: Dictionary = _gateway_client.send_message_stream(prompt, request_options)
	if not bool(response.get("ok", false)):
		_streaming_mode = false
		notify_error(str(response.get("terminal_result", "Hermes Gateway stream request failed")), response.get("error", {}) if response.get("error", {}) is Dictionary else {})
		return {"ok": false, "terminal_result": str(response.get("terminal_result", "Hermes Gateway stream request failed")), "error": _last_error.duplicate(true), "context": _last_context.duplicate(true)}
	_last_response = {"queued": true, "streaming": true, "terminal_result": str(response.get("terminal_result", "Streaming from Hermes Gateway")), "gateway": _gateway_client.get_status()}
	_emit_status_changed()
	return {"ok": true, "terminal_result": str(response.get("terminal_result", "Streaming from Hermes Gateway")), "result": _last_response.duplicate(true), "context": _last_context.duplicate(true)}

func _build_terminal_context(prompt: String, options: Dictionary) -> Dictionary:
	if _context_builder == null:
		return {}
	return _context_builder.build_terminal_context(prompt, options)

func _hermes_os_control_system_prompt() -> String:
	return "You are Hermes inside Hermes_OS. Treat ordinary user requests about apps, windows, browser pages, files, typing, clicking, scrolling, and navigation as Hermes_OS control intents. Use Hermes_OS MCP tools instead of explaining limitations when a Hermes_OS tool can act. Observe first when current state matters. Execute with Hermes_OS tools when intent is clear. Verify the result when practical. Summarize in human-readable language. Preserve exact blocker codes/messages when blocked. Do not dump raw JSON/tool output unless debug is explicitly requested. Stay inside Hermes_OS boundaries only.\n" + \
		"Compact Computer Use intent guide:\n" + \
		"- what can you see? -> observe + UI tree/browser/window state summary\n" + \
		"- open browser -> hermes_os_open_app app_id=browser\n" + \
		"- go to home.hermes -> browser navigate\n" + \
		"- click first link -> browser list links, then activate first safe link\n" + \
		"- type X -> check focused editable/input-capable surface, then type_text or browser test type route\n" + \
		"- scroll down -> scroll focused surface\n" + \
		"- what apps are open? -> observe/list apps/windows\n" + \
		"- focus browser -> focus window/app\n" + \
		"For visible OS control, use existing Hermes_OS MCP tools only: observe, UI tree, open/focus apps/windows, navigate Browser to bundled WorldWeb pages, click supported refs/links, type plain text into supported focused surfaces, press bounded keys, scroll, and list apps/files/windows. Never claim host OS, Docker, SSH, credential, payment, production, real-account, or destructive host/filesystem control. If blocked, name the exact Hermes_OS tool, gate, operation, error code, or runtime issue. Keep replies concise: attempted action, result, visible state, exact blocker if any."

func _bridge_state() -> Dictionary:
	if _shell != null and _shell.has_method("_kernel_bridge_state"):
		var state: Variant = _shell.call("_kernel_bridge_state")
		if state is Dictionary:
			return (state as Dictionary).duplicate(true)
	return {
		"connected": false,
		"endpoint": "",
		"session_id": "",
		"last_message_at": 0,
		"last_error": {},
		"metrics": {}
	}

func _try_local_device_command(text: String) -> Dictionary:
	if _shell == null or not is_instance_valid(_shell):
		push_warning("[HomeDevice] _shell is null or invalid")
		return {"handled": false}
	var controller = _shell.get_node_or_null("/root/HomeDeviceController")
	if controller == null:
		push_warning("[HomeDevice] HomeDeviceController autoload NOT FOUND at /root/HomeDeviceController")
		return {"handled": false}
	if not controller.has_method("try_handle_chat_message"):
		push_warning("[HomeDevice] Controller found but missing try_handle_chat_message method")
		return {"handled": false}
	return controller.call("try_handle_chat_message", text)

func _home_path() -> String:
	if _filesystem != null and _filesystem.has_method("home_path"):
		return str(_filesystem.call("home_path"))
	return "/home/player"

func _current_user() -> String:
	if _filesystem != null and _filesystem.has_method("current_user"):
		return str(_filesystem.call("current_user"))
	return "player"

func _gateway_status() -> Dictionary:
	if _gateway_client == null:
		return {
			"configured": false,
			"busy": false,
			"endpoint": "",
			"host": "",
			"port": 0,
			"path": "",
			"model": "",
			"profile_hint": "",
			"auth_required": false,
			"last_latency_ms": 0,
			"last_error": {},
			"last_response": {}
		}
	return _gateway_client.get_status()

func _on_gateway_response_received(payload: Dictionary) -> void:
	_last_response = payload.duplicate(true)
	_last_error.clear()
	_busy = false
	var assistant_text := str(payload.get("assistant_text", "")).strip_edges()
	var payload_context: Dictionary = payload.get("context", {}) if payload.get("context", {}) is Dictionary else {}
	var terminal_context: Dictionary = payload_context.get("terminal", {}) if payload_context.get("terminal", {}) is Dictionary else {}
	var terminal_session_id := str(terminal_context.get("terminal_session_id", ""))
	if _shell != null and _shell.has_method("_append_hermes_terminal_output"):
		_shell.call("_append_hermes_terminal_output", assistant_text if assistant_text != "" else "(no output)", "Hermes Gateway", terminal_session_id)
	_emit_service_event(OSEventBus.AGENT_RESPONSE_RECEIVED, payload)
	_emit_status_changed()

func _on_gateway_stream_delta(text: String) -> void:
	var payload := {"assistant_text_partial": text, "source": "gateway_stream"}
	stream_delta_received.emit(payload)

func _on_gateway_stream_completed(full_text: String) -> void:
	var payload := {
		"ok": true,
		"assistant_text": full_text,
		"source": "gateway_stream",
		"context": _last_context.duplicate(true),
		"gateway": _gateway_client.get_status() if _gateway_client != null else {}
	}
	_streaming_mode = false
	notify_response(payload)
	stream_completed.emit(payload)

func _on_gateway_error_received(message: String, details: Dictionary) -> void:
	_last_error = details.duplicate(true)
	_last_error["message"] = message
	_busy = false
	_streaming_mode = false
	var terminal_session_id := ""
	var last_terminal: Dictionary = _last_context.get("terminal", {}) if _last_context.get("terminal", {}) is Dictionary else {}
	terminal_session_id = str(last_terminal.get("terminal_session_id", ""))
	if _shell != null and _shell.has_method("_append_hermes_terminal_output"):
		_shell.call("_append_hermes_terminal_output", message, "Hermes Gateway Error", terminal_session_id)
	_emit_service_event(OSEventBus.AGENT_ERROR, _last_error)
	_emit_status_changed()

func _on_gateway_status_changed(_status: Dictionary) -> void:
	_emit_status_changed()

func _emit_service_event(event_name: StringName, payload: Dictionary = {}) -> void:
	if _event_bus != null:
		_event_bus.emit_event(event_name, payload)
		return
	if _shell != null and _shell.has_method("_emit_hermes_event"):
		_shell.call("_emit_hermes_event", str(event_name), payload)

func _emit_status_changed() -> void:
	_emit_service_event(OSEventBus.AGENT_STATUS_CHANGED, get_status())
