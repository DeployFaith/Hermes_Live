extends Node

const HermesProtocol = preload("res://addons/hermes_os/scripts/hermes/hermes_protocol.gd")
const HermesBridgeClientScript = preload("res://addons/hermes_os/scripts/hermes/hermes_bridge_client.gd")
const HermesOperationRouterScript = preload("res://addons/hermes_os/scripts/hermes/hermes_operation_router.gd")
const BRIDGE_SETTINGS_PATH := "user://hermes_bridge_settings.cfg"

signal os_event(event_name: String, payload: Dictionary)
signal bridge_connected
signal bridge_disconnected

@export var auto_connect := true
@export var endpoint_url := "ws://127.0.0.1:8788/hermesos/ws"
@export var project_id := "hermesos_demo"

var session_id := "game_session_%d" % int(Time.get_unix_time_from_system())
var _booted := false
var _shell: Node
var _bridge
var _router
var _game_actions: Dictionary = {}
var _last_bridge_error: Dictionary = {}
var _last_message_at := 0
var _messages_received := 0
var _events_sent := 0
var _operation_results_sent := 0
var _responses_sent := 0

func _ready() -> void:
	_bridge = HermesBridgeClientScript.new()
	_bridge.name = "HermesBridgeClient"
	add_child(_bridge)
	_bridge.connected.connect(_on_bridge_connected)
	_bridge.disconnected.connect(_on_bridge_disconnected)
	_bridge.message_received.connect(_on_bridge_message_received)
	_bridge.protocol_error.connect(_on_bridge_protocol_error)

	_router = HermesOperationRouterScript.new()
	_router.setup(self)
	_load_bridge_settings()

	if auto_connect:
		connect_bridge()

func register_shell(shell_node: Node) -> void:
	_shell = shell_node
	if _shell.has_signal("hermes_event") and not _shell.hermes_event.is_connected(_on_shell_event):
		_shell.hermes_event.connect(_on_shell_event)
	boot()

func boot() -> void:
	if _booted:
		return
	_booted = true
	emit_os_event("os.booted", {"session_id": session_id})

func shutdown() -> void:
	if not _booted:
		return
	disconnect_bridge()
	_booted = false
	emit_os_event("os.shutdown", {"session_id": session_id})

func connect_bridge(url := "") -> String:
	var target := endpoint_url if url.strip_edges() == "" else url.strip_edges()
	if target == "":
		return "Missing endpoint URL"
	endpoint_url = target
	_save_bridge_settings()
	_last_bridge_error.clear()
	return _bridge.connect_to_endpoint(target)

func disconnect_bridge() -> void:
	if _bridge:
		_bridge.close_connection()

func is_bridge_connected() -> bool:
	return _bridge != null and _bridge.is_connected_to_backend()

func register_game_action(operation_name: String, metadata: Dictionary) -> void:
	_game_actions[operation_name] = metadata.duplicate(true)

func get_declared_operations() -> Dictionary:
	var declared: Dictionary = {}
	for key in _kernel_actions().keys():
		declared[str(key)] = true
	if _shell and _shell.has_method("hermes_get_manifest_apps"):
		var apps: Variant = _shell.call("hermes_get_manifest_apps")
		if apps is Array:
			for app_value in apps:
				if not (app_value is Dictionary):
					continue
				var app: Dictionary = app_value
				var actions: Variant = app.get("actions", {})
				if not (actions is Dictionary):
					continue
				for op_name in (actions as Dictionary).keys():
					declared[str(op_name)] = true
	for op_name in _game_actions.keys():
		declared[str(op_name)] = true
	return declared

func is_operation_declared(op: String) -> bool:
	var normalized: Dictionary = _normalize_declared_operation(op, {})
	var normalized_op: String = str(normalized.get("op", op)).strip_edges()
	if normalized_op == "":
		return false
	return get_declared_operations().has(normalized_op)

func is_operation_supported(op: String, args: Dictionary = {}) -> bool:
	if _shell == null or not _shell.has_method("hermes_supported_operations"):
		return false
	var normalized: Dictionary = _normalize_declared_operation(op, args)
	var normalized_op: String = str(normalized.get("op", op)).strip_edges()
	if normalized_op == "":
		return false
	var supported_value: Variant = _shell.call("hermes_supported_operations")
	if not (supported_value is Array):
		return false
	for entry in (supported_value as Array):
		if str(entry).strip_edges() == normalized_op:
			return true
	return false

func should_allow_undeclared_operation(op: String, args: Dictionary = {}) -> bool:
	if not is_dev_operation_mode():
		return false
	return is_operation_supported(op, args)

func is_dev_operation_mode() -> bool:
	var policy: String = OS.get_environment("HERMESOS_BRIDGE_POLICY").strip_edges().to_lower()
	if policy == "dev":
		return true
	var allow_mutations: String = OS.get_environment("HERMESOS_ALLOW_MUTATIONS").strip_edges().to_lower()
	return _is_truthy_env(allow_mutations)

func _is_truthy_env(value: String) -> bool:
	match value:
		"1", "true", "yes", "on":
			return true
		_:
			return false

func _normalize_declared_operation(op: String, args: Dictionary) -> Dictionary:
	if _shell != null and _shell.has_method("_normalize_v1_operation"):
		var normalized_value: Variant = _shell.call("_normalize_v1_operation", op, args.duplicate(true))
		if normalized_value is Dictionary:
			return normalized_value as Dictionary
	return {"op": op.strip_edges(), "args": args.duplicate(true)}

func get_bridge_state() -> Dictionary:
	return {
		"connected": is_bridge_connected(),
		"auto_connect": auto_connect,
		"endpoint": endpoint_url,
		"session_id": session_id,
		"last_message_at": _last_message_at,
		"last_error": _last_bridge_error.duplicate(true),
		"metrics": {
			"messages_received": _messages_received,
			"events_sent": _events_sent,
			"operation_results_sent": _operation_results_sent,
			"responses_sent": _responses_sent
		}
	}

func set_bridge_settings(settings: Dictionary) -> void:
	if settings.has("auto_connect"):
		auto_connect = bool(settings.get("auto_connect", auto_connect))
	if settings.has("endpoint"):
		var maybe_endpoint := str(settings.get("endpoint", endpoint_url)).strip_edges()
		if maybe_endpoint != "":
			endpoint_url = maybe_endpoint
	_save_bridge_settings()

func _load_bridge_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(BRIDGE_SETTINGS_PATH)
	if err != OK:
		return
	auto_connect = bool(config.get_value("bridge", "auto_connect", auto_connect))
	var saved_endpoint := str(config.get_value("bridge", "endpoint_url", endpoint_url)).strip_edges()
	if saved_endpoint != "":
		endpoint_url = saved_endpoint

func _save_bridge_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("bridge", "auto_connect", auto_connect)
	config.set_value("bridge", "endpoint_url", endpoint_url)
	var err := config.save(BRIDGE_SETTINGS_PATH)
	if err != OK:
		push_warning("Failed to save Hermes bridge settings to %s (error %d)" % [BRIDGE_SETTINGS_PATH, err])

func get_manifest() -> Dictionary:
	var apps: Array = []
	if _shell and _shell.has_method("hermes_get_manifest_apps"):
		apps = _shell.call("hermes_get_manifest_apps")
	var game_actions := {}
	for key in _game_actions.keys():
		game_actions[key] = _game_actions[key]
	return {
		"protocol_version": HermesProtocol.PROTOCOL_VERSION,
		"os": {"name": "HermesOS", "version": "0.1.0"},
		"session": {
			"session_id": session_id,
			"project_id": project_id
		},
		"capabilities": {
			"full_hermesos_control": true,
			"game_control": not _game_actions.is_empty(),
			"filesystem": true,
			"terminal": true,
			"notifications": true,
			"windows": true
		},
		"apps": apps,
		"game_actions": game_actions,
		"actions": _kernel_actions()
	}

func _kernel_actions() -> Dictionary:
	return {
		"os.get_state": {
			"description": "Get HermesOS state snapshot.",
			"args_schema": {
				"include_apps": "bool",
				"include_windows": "bool",
				"include_filesystem": "bool"
			}
		},
		"os.get_manifest": {
			"description": "Get HermesOS manifest.",
			"args_schema": {}
		}
	}

func get_state(options := {}) -> Dictionary:
	var state := {
		"desktop": {},
		"windows": [],
		"apps": {},
		"notifications": []
	}
	if _shell and _shell.has_method("hermes_get_state"):
		var shell_state: Variant = _shell.call("hermes_get_state", options)
		if shell_state is Dictionary:
			state = shell_state
	state["bridge"] = get_bridge_state()
	return state

func execute_operation(op: String, args: Dictionary, request_id := "") -> Dictionary:
	return _router.execute(op, args, request_id)

func route_os_operation(op: String, args: Dictionary, _request_id := "") -> Dictionary:
	match op:
		"os.get_state":
			return {"ok": true, "result": get_state(args)}
		"os.get_manifest":
			return {"ok": true, "result": get_manifest()}
		_:
			return {"ok": false, "error": HermesProtocol.make_error("UNKNOWN_OPERATION", "No registered operation: " + op)}

func route_game_operation(op: String, args: Dictionary, _request_id := "") -> Dictionary:
	if not _game_actions.has(op):
		return {"ok": false, "error": HermesProtocol.make_error("GAME_ACTION_NOT_EXPOSED", "No registered game action: " + op)}
	var entry: Dictionary = _game_actions[op]
	if not entry.has("handler"):
		return {"ok": false, "error": HermesProtocol.make_error("GAME_HANDLER_MISSING", "Game action has no handler: " + op)}
	var handler: Callable = entry["handler"]
	if not handler.is_valid():
		return {"ok": false, "error": HermesProtocol.make_error("GAME_HANDLER_INVALID", "Game action handler invalid: " + op)}
	var response: Variant = handler.call(args)
	if response is Dictionary:
		return response
	return {"ok": true, "result": {"value": response}}

func route_shell_operation(op: String, args: Dictionary, _request_id := "") -> Dictionary:
	if _shell == null or not _shell.has_method("hermes_execute_operation"):
		return {"ok": false, "error": HermesProtocol.make_error("SHELL_UNAVAILABLE", "HermesOS shell is not registered")}
	var response: Variant = _shell.call("hermes_execute_operation", op, args)
	if response is Dictionary:
		return response
	return {"ok": false, "error": HermesProtocol.make_error("INVALID_OPERATION_RESULT", "Shell returned invalid operation result")}

func emit_os_event(event_name: String, payload: Dictionary = {}) -> void:
	os_event.emit(event_name, payload)
	if is_bridge_connected():
		_events_sent += 1
		_send_bridge_message(HermesProtocol.make_event(event_name, payload))

func _on_bridge_connected() -> void:
	bridge_connected.emit()
	emit_os_event("bridge.connected", {"endpoint": endpoint_url})
	_send_bridge_message(HermesProtocol.make_hello(session_id, project_id))
	_send_bridge_message(HermesProtocol.make_manifest(session_id, get_manifest()))
	emit_os_event("manifest.sent", {})

func _on_bridge_disconnected() -> void:
	bridge_disconnected.emit()
	emit_os_event("bridge.disconnected", {})

func _on_bridge_protocol_error(error_data: Dictionary) -> void:
	_last_bridge_error = error_data.duplicate(true)
	emit_os_event("bridge.error", error_data)

func _on_bridge_message_received(message: Dictionary) -> void:
	_messages_received += 1
	_last_message_at = int(Time.get_unix_time_from_system())
	var message_type := str(message.get("type", ""))
	match message_type:
		"operation":
			_handle_operation_message(message)
		"operation_batch":
			_handle_operation_batch_message(message)
		"request":
			_handle_request_message(message)
		"ping":
			_send_bridge_message({"type": "pong", "timestamp": HermesProtocol.timestamp_unix()})
		_:
			emit_os_event("bridge.message_ignored", {"type": message_type})

func _handle_operation_message(message: Dictionary) -> void:
	var operation_id := str(message.get("id", ""))
	var op := str(message.get("op", ""))
	var args: Dictionary = message.get("args", {}) if message.get("args", {}) is Dictionary else {}
	emit_os_event("operation.received", {"id": operation_id, "op": op})
	var response := execute_operation(op, args, operation_id)
	if bool(response.get("ok", false)):
		emit_os_event("operation.completed", {"id": operation_id, "op": op})
		_operation_results_sent += 1
		_send_bridge_message(HermesProtocol.make_operation_result(operation_id, true, response.get("result", {}), {}))
	else:
		var error_data: Dictionary = response.get("error", HermesProtocol.make_error("OPERATION_FAILED", "Operation failed"))
		emit_os_event("operation.failed", {"id": operation_id, "op": op, "error": error_data})
		_operation_results_sent += 1
		_send_bridge_message(HermesProtocol.make_operation_result(operation_id, false, {}, error_data))

func _handle_operation_batch_message(message: Dictionary) -> void:
	var batch_id := str(message.get("id", ""))
	var operations: Array = message.get("operations", []) if message.get("operations", []) is Array else []
	var stop_on_error := bool(message.get("stop_on_error", true))
	var results: Array = []
	var halted_at := -1
	var batch_ok := true
	for index in range(operations.size()):
		var item: Variant = operations[index]
		if not (item is Dictionary):
			batch_ok = false
			halted_at = index
			results.append({
				"index": index,
				"ok": false,
				"error": HermesProtocol.make_error("INVALID_BATCH_ITEM", "Batch operation must be a Dictionary")
			})
			if stop_on_error:
				break
			continue
		var op_dict: Dictionary = item
		var op_name := str(op_dict.get("op", "")).strip_edges()
		var op_args: Dictionary = op_dict.get("args", {}) if op_dict.get("args", {}) is Dictionary else {}
		var op_id := str(op_dict.get("id", "batch_%d" % index))
		emit_os_event("operation.received", {"id": op_id, "op": op_name, "batch_id": batch_id})
		var response := execute_operation(op_name, op_args, op_id)
		if bool(response.get("ok", false)):
			emit_os_event("operation.completed", {"id": op_id, "op": op_name, "batch_id": batch_id})
			results.append({
				"index": index,
				"id": op_id,
				"op": op_name,
				"ok": true,
				"result": response.get("result", {})
			})
		else:
			batch_ok = false
			halted_at = index if halted_at < 0 else halted_at
			var error_data: Dictionary = response.get("error", HermesProtocol.make_error("OPERATION_FAILED", "Operation failed"))
			emit_os_event("operation.failed", {"id": op_id, "op": op_name, "error": error_data, "batch_id": batch_id})
			results.append({
				"index": index,
				"id": op_id,
				"op": op_name,
				"ok": false,
				"error": error_data
			})
			if stop_on_error:
				break
	_operation_results_sent += results.size()
	_send_bridge_message({
		"type": "operation_batch_result",
		"id": batch_id,
		"ok": batch_ok,
		"halted_at": halted_at,
		"results": results
	})

func _handle_request_message(message: Dictionary) -> void:
	var request_id := str(message.get("id", ""))
	var op := str(message.get("op", ""))
	var args: Dictionary = message.get("args", {}) if message.get("args", {}) is Dictionary else {}
	var response := execute_operation(op, args, request_id)
	if bool(response.get("ok", false)):
		_responses_sent += 1
		_send_bridge_message(HermesProtocol.make_response(request_id, true, response.get("result", {}), {}))
	else:
		var error_data: Dictionary = response.get("error", HermesProtocol.make_error("REQUEST_FAILED", "Request failed"))
		_responses_sent += 1
		_send_bridge_message(HermesProtocol.make_response(request_id, false, {}, error_data))

func _send_bridge_message(message: Dictionary) -> void:
	if _bridge == null:
		return
	var send_error: String = _bridge.send_message(message)
	if send_error != "":
		_last_bridge_error = HermesProtocol.make_error("SEND_FAILED", send_error)
		emit_os_event("bridge.send_error", _last_bridge_error)

func _on_shell_event(event_name: String, payload: Dictionary) -> void:
	emit_os_event(event_name, payload)
