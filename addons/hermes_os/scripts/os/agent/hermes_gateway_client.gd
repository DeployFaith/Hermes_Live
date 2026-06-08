class_name HermesGatewayClient
extends RefCounted

signal response_received(payload: Dictionary)
signal error_received(message: String, details: Dictionary)
signal status_changed(status: Dictionary)
signal stream_delta_received(text: String)
signal stream_completed(full_text: String)

const HermesGatewayStreamParser = preload("res://addons/hermes_os/scripts/os/agent/hermes_gateway_stream_parser.gd")

const DEFAULT_HOST := "127.0.0.1"
const DEFAULT_PORT := 8643
const DEFAULT_PATH := "/v1/chat/completions"
const DEFAULT_MODEL := "gpt-5.3-codex-spark"
const DEFAULT_PROFILE_HINT := "hermesos"
const DEFAULT_API_KEY := ""
const DEFAULT_TIMEOUT_SECONDS := 120.0

var _shell: Node
var _request: HTTPRequest
var _host: String = DEFAULT_HOST
var _port: int = DEFAULT_PORT
var _path: String = DEFAULT_PATH
var _model: String = DEFAULT_MODEL
var _profile_hint: String = DEFAULT_PROFILE_HINT
var _api_key: String = DEFAULT_API_KEY
var _timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS
var _busy: bool = false
var _last_error: Dictionary = {}
var _last_response: Dictionary = {}
var _last_latency_ms: int = 0
var _started_msec: int = 0
var _pending_prompt: String = ""
var _pending_context: Dictionary = {}
var _stream_parser = null
var _stream_http_client: HTTPClient
var _stream_poll_timer: Timer
var _stream_request_sent: bool = false
var _stream_response_checked: bool = false
var _stream_completed: bool = false
var _stream_body: String = ""
var _stream_options: Dictionary = {}

func gateway_init(context: Dictionary = {}) -> void:
	_shell = context.get("shell", null) as Node
	configure(context.get("gateway", {}) if context.get("gateway", {}) is Dictionary else {})
	_ensure_request_node()
	_emit_status_changed()

func configure(config: Dictionary = {}) -> void:
	_host = str(config.get("gateway_host", _host)).strip_edges()
	if _host == "":
		_host = DEFAULT_HOST
	_port = int(config.get("gateway_port", _port))
	_path = str(config.get("gateway_path", _path)).strip_edges()
	if _path == "":
		_path = DEFAULT_PATH
	if not _path.begins_with("/"):
		_path = "/" + _path
	_model = str(config.get("gateway_model", _model)).strip_edges()
	if _model == "":
		_model = DEFAULT_MODEL
	_profile_hint = str(config.get("gateway_profile_hint", _profile_hint)).strip_edges()
	if _profile_hint == "":
		_profile_hint = DEFAULT_PROFILE_HINT
	_api_key = str(config.get("gateway_api_key", _api_key)).strip_edges()
	_timeout_seconds = float(config.get("gateway_timeout_seconds", _timeout_seconds))
	if _timeout_seconds <= 0.0:
		_timeout_seconds = DEFAULT_TIMEOUT_SECONDS
	if _request != null:
		_request.timeout = _timeout_seconds
	_emit_status_changed()

func get_status() -> Dictionary:
	return {
		"configured": _host != "" and _port > 0 and _path != "",
		"busy": _busy,
		"endpoint": _endpoint_url(),
		"host": _host,
		"port": _port,
		"path": _path,
		"model": _model,
		"profile_hint": _profile_hint,
		"auth_required": _api_key != "",
		"api_key_present": _api_key != "",
		"api_key_length": _api_key.length(),
		"last_latency_ms": _last_latency_ms,
		"last_error": _last_error.duplicate(true),
		"last_response": _last_response.duplicate(true)
	}

func send_message(prompt: String, options: Dictionary = {}) -> Dictionary:
	var clean_prompt := prompt.strip_edges()
	if clean_prompt == "":
		return _fail("MISSING_PROMPT", "Usage: hermes <prompt>")
	if _busy:
		return _fail("REQUEST_IN_PROGRESS", "Hermes Gateway request already in progress")
	if _ensure_request_node() == null:
		return _fail("REQUEST_UNAVAILABLE", "Hermes Gateway HTTP client is unavailable")
	if _api_key == "":
		return _fail("GATEWAY_API_KEY_MISSING", "Hermes Gateway API key is not configured.")

	_pending_prompt = clean_prompt
	_pending_context = options.duplicate(true)
	_last_error.clear()
	_last_response.clear()
	_last_latency_ms = 0
	_started_msec = Time.get_ticks_msec()
	_busy = true
	_emit_status_changed()

	var messages: Array = []
	var system_text := str(options.get("system", "")).strip_edges()
	if system_text != "":
		messages.append({"role": "system", "content": system_text})
	messages.append({"role": "user", "content": clean_prompt})
	var body := JSON.stringify({
		"model": _model,
		"profile_hint": _profile_hint,
		"messages": messages,
		"stream": false
	})
	var headers: PackedStringArray = ["Content-Type: application/json"]
	if _api_key != "":
		headers.append("Authorization: " + "Bearer " + _api_key)
	var err := _request.request(_endpoint_url(), headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_busy = false
		return _fail("REQUEST_START_FAILED", "Could not start Hermes Gateway request", {"godot_error": err})
	return {"ok": true, "terminal_result": "Sent to Hermes Gateway: " + clean_prompt, "endpoint": _endpoint_url()}

func send_message_stream(prompt: String, options: Dictionary = {}) -> Dictionary:
	var clean_prompt := prompt.strip_edges()
	if clean_prompt == "":
		return _fail("MISSING_PROMPT", "Usage: hermes <prompt>")
	if _busy:
		return _fail("REQUEST_IN_PROGRESS", "Hermes Gateway request already in progress")
	if _shell == null or not is_instance_valid(_shell):
		return _fail("REQUEST_UNAVAILABLE", "Hermes Gateway streaming client is unavailable")
	if _api_key == "":
		return _fail("GATEWAY_API_KEY_MISSING", "Hermes Gateway API key is not configured.")

	_pending_prompt = clean_prompt
	_pending_context = options.duplicate(true)
	_last_error.clear()
	_last_response.clear()
	_last_latency_ms = 0
	_started_msec = Time.get_ticks_msec()
	_busy = true
	_stream_request_sent = false
	_stream_response_checked = false
	_stream_completed = false
	_stream_body = ""
	_stream_options = options.duplicate(true)
	_ensure_stream_parser()
	_stream_parser.reset()
	_stream_http_client = HTTPClient.new()
	var err := _stream_http_client.connect_to_host(_host, _port)
	if err != OK:
		_cleanup_stream(false)
		_busy = false
		return _fail("STREAM_CONNECT_FAILED", "Could not connect to Hermes Gateway streaming endpoint", {"godot_error": err})
	_ensure_stream_poll_timer()
	_stream_poll_timer.start()
	_emit_status_changed()
	return {"ok": true, "terminal_result": "Streaming from Hermes Gateway: " + clean_prompt, "endpoint": _endpoint_url()}

func cancel_stream() -> Dictionary:
	if not _busy or _stream_http_client == null:
		return {"ok": true, "cancelled": false}
	_cleanup_stream(false)
	_busy = false
	var details := {"code": "STREAM_CANCELLED", "endpoint": _endpoint_url()}
	_last_error = details.duplicate(true)
	_last_error["message"] = "Hermes Gateway stream cancelled"
	error_received.emit("Hermes Gateway stream cancelled", _last_error.duplicate(true))
	_emit_status_changed()
	return {"ok": true, "cancelled": true}

func cancel() -> Dictionary:
	if not _busy:
		return {"ok": true, "cancelled": false}
	if _stream_http_client != null:
		return cancel_stream()
	if _request != null:
		_request.cancel_request()
	_busy = false
	var details := {"code": "REQUEST_CANCELLED", "endpoint": _endpoint_url()}
	_last_error = details.duplicate(true)
	_last_error["message"] = "Hermes Gateway request cancelled"
	error_received.emit("Hermes Gateway request cancelled", _last_error.duplicate(true))
	_emit_status_changed()
	return {"ok": true, "cancelled": true}

func _ensure_request_node() -> HTTPRequest:
	if _request != null and is_instance_valid(_request):
		return _request
	if _shell == null or not is_instance_valid(_shell):
		return null
	_request = HTTPRequest.new()
	_request.name = "HermesGatewayHTTPRequest"
	_request.timeout = _timeout_seconds
	_request.use_threads = true
	_shell.add_child(_request)
	_request.request_completed.connect(_on_request_completed)
	return _request

func _ensure_stream_parser() -> void:
	if _stream_parser != null:
		return
	_stream_parser = HermesGatewayStreamParser.new()
	_stream_parser.delta_received.connect(_on_stream_parser_delta_received)
	_stream_parser.completion_received.connect(_on_stream_parser_completion_received)
	_stream_parser.error_received.connect(_on_stream_parser_error_received)

func _ensure_stream_poll_timer() -> Timer:
	if _stream_poll_timer != null and is_instance_valid(_stream_poll_timer):
		return _stream_poll_timer
	_stream_poll_timer = Timer.new()
	_stream_poll_timer.name = "HermesGatewayStreamPollTimer"
	_stream_poll_timer.wait_time = 0.05
	_stream_poll_timer.one_shot = false
	_shell.add_child(_stream_poll_timer)
	_stream_poll_timer.timeout.connect(_poll_stream)
	return _stream_poll_timer

func _poll_stream() -> void:
	if _stream_http_client == null or _stream_completed:
		return
	if _timeout_seconds > 0.0 and _started_msec > 0:
		var elapsed := float(Time.get_ticks_msec() - _started_msec) / 1000.0
		if elapsed > _timeout_seconds:
			_emit_stream_error("STREAM_TIMEOUT", "Hermes Gateway stream timed out", {"timeout_seconds": _timeout_seconds})
			return
	for _i in range(8):
		var poll_err := _stream_http_client.poll()
		if poll_err != OK:
			_emit_stream_error("STREAM_POLL_FAILED", "Hermes Gateway stream polling failed", {"godot_error": poll_err})
			return
		var status := _stream_http_client.get_status()
		match status:
			HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING:
				return
			HTTPClient.STATUS_CONNECTED:
				if not _stream_request_sent:
					_start_stream_request()
					return
				if _stream_response_checked and not _stream_completed:
					_complete_stream_from_connection_close()
					return
			HTTPClient.STATUS_REQUESTING:
				return
			HTTPClient.STATUS_BODY:
				_check_stream_response_code()
				_read_stream_chunks()
				return
			HTTPClient.STATUS_DISCONNECTED:
				if _stream_response_checked:
					_complete_stream_from_connection_close()
				else:
					_emit_stream_error("STREAM_DISCONNECTED", "Hermes Gateway stream disconnected before response", {})
				return
			_:
				return

func _start_stream_request() -> void:
	var messages: Array = []
	var system_text := str(_stream_options.get("system", "")).strip_edges()
	if system_text != "":
		messages.append({"role": "system", "content": system_text})
	messages.append({"role": "user", "content": _pending_prompt})
	var body := JSON.stringify({
		"model": _model,
		"profile_hint": _profile_hint,
		"messages": messages,
		"stream": true
	})
	var headers: PackedStringArray = ["Content-Type: application/json", "Accept: text/event-stream"]
	if _api_key != "":
		headers.append("Authorization: " + "Bearer " + _api_key)
	var err := _stream_http_client.request(HTTPClient.METHOD_POST, _path, headers, body)
	if err != OK:
		_emit_stream_error("STREAM_REQUEST_START_FAILED", "Could not start Hermes Gateway stream request", {"godot_error": err})
		return
	_stream_request_sent = true

func _check_stream_response_code() -> void:
	if _stream_response_checked or _stream_http_client == null or not _stream_http_client.has_response():
		return
	_stream_response_checked = true
	var response_code := _stream_http_client.get_response_code()
	if response_code == 401:
		_emit_stream_error("GATEWAY_UNAUTHORIZED", "Hermes Gateway unauthorized. Check gateway_api_key / HERMES_GATEWAY_API_KEY.", {"response_code": response_code, "auth_required": _api_key != ""})
		return
	if response_code < 200 or response_code >= 300:
		_emit_stream_error("HTTP_" + str(response_code), "Hermes Gateway returned HTTP " + str(response_code), {"response_code": response_code, "body": _stream_body})

func _read_stream_chunks() -> void:
	if _stream_http_client == null or _stream_completed:
		return
	while _stream_http_client.get_status() == HTTPClient.STATUS_BODY:
		var chunk := _stream_http_client.read_response_body_chunk()
		if chunk.is_empty():
			break
		var chunk_text := chunk.get_string_from_utf8()
		_stream_body += chunk_text
		if _stream_parser != null:
			_stream_parser.feed(chunk_text)
		if _stream_completed:
			return

func _complete_stream_from_connection_close() -> void:
	if _stream_completed:
		return
	var full_text: String = _stream_parser.get_accumulated_text() if _stream_parser != null else ""
	_on_stream_parser_completion_received(full_text)

func _on_stream_parser_delta_received(text: String) -> void:
	stream_delta_received.emit(text)

func _on_stream_parser_completion_received(full_text: String) -> void:
	if _stream_completed:
		return
	_stream_completed = true
	_busy = false
	_last_latency_ms = Time.get_ticks_msec() - _started_msec if _started_msec > 0 else 0
	_last_response = {
		"ok": true,
		"assistant_text": full_text,
		"raw": {"stream": true, "body": _stream_body},
		"endpoint": _endpoint_url(),
		"latency_ms": _last_latency_ms,
		"prompt": _pending_prompt,
		"context": _pending_context.duplicate(true)
	}
	_cleanup_stream(false)
	stream_completed.emit(full_text)
	_emit_status_changed()

func _on_stream_parser_error_received(message: String, details: Dictionary) -> void:
	_emit_stream_error("STREAM_PARSE_ERROR", message, details)

func _emit_stream_error(code: String, message: String, details: Dictionary = {}) -> void:
	if _stream_completed:
		return
	_stream_completed = true
	_busy = false
	_last_latency_ms = Time.get_ticks_msec() - _started_msec if _started_msec > 0 else 0
	_cleanup_stream(false)
	_emit_request_error(code, message, details)

func _cleanup_stream(reset_parser: bool = true) -> void:
	if _stream_poll_timer != null and is_instance_valid(_stream_poll_timer):
		_stream_poll_timer.stop()
	if _stream_http_client != null:
		_stream_http_client.close()
	_stream_http_client = null
	_stream_request_sent = false
	_stream_response_checked = false
	_stream_options.clear()
	if reset_parser and _stream_parser != null:
		_stream_parser.reset()

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	_last_latency_ms = Time.get_ticks_msec() - _started_msec if _started_msec > 0 else 0
	var body_text := body.get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS:
		_emit_request_error("GATEWAY_UNAVAILABLE", "Hermes Gateway unavailable: " + _endpoint_url(), {"result": result, "response_code": response_code, "body": body_text})
		return
	if response_code == 401:
		_emit_request_error("GATEWAY_UNAUTHORIZED", "Hermes Gateway unauthorized. Check gateway_api_key / HERMES_GATEWAY_API_KEY.", {"response_code": response_code, "body": body_text, "auth_required": _api_key != ""})
		return
	if response_code < 200 or response_code >= 300:
		_emit_request_error("HTTP_" + str(response_code), "Hermes Gateway returned HTTP " + str(response_code), {"response_code": response_code, "body": body_text})
		return
	var parsed: Variant = JSON.parse_string(body_text)
	if not (parsed is Dictionary):
		_emit_request_error("INVALID_JSON", "Hermes Gateway returned invalid JSON", {"body": body_text})
		return
	var data: Dictionary = parsed
	var assistant_text := _extract_assistant_text(data)
	_last_response = {
		"ok": true,
		"assistant_text": assistant_text,
		"raw": data.duplicate(true),
		"endpoint": _endpoint_url(),
		"latency_ms": _last_latency_ms,
		"prompt": _pending_prompt,
		"context": _pending_context.duplicate(true)
	}
	response_received.emit(_last_response.duplicate(true))
	_emit_status_changed()

func _extract_assistant_text(data: Dictionary) -> String:
	var choices: Array = data.get("choices", []) if data.get("choices", []) is Array else []
	if choices.is_empty():
		return ""
	var first: Dictionary = choices[0] if choices[0] is Dictionary else {}
	var message: Dictionary = first.get("message", {}) if first.get("message", {}) is Dictionary else {}
	var content: Variant = message.get("content", "")
	if content is String:
		return (content as String).strip_edges()
	return str(content).strip_edges()

func _emit_request_error(code: String, message: String, details: Dictionary = {}) -> void:
	_last_error = details.duplicate(true)
	_last_error["code"] = code
	_last_error["message"] = message
	_last_error["endpoint"] = _endpoint_url()
	_last_error["latency_ms"] = _last_latency_ms
	error_received.emit(message, _last_error.duplicate(true))
	_emit_status_changed()

func _fail(code: String, message: String, details: Dictionary = {}) -> Dictionary:
	var error := details.duplicate(true)
	error["code"] = code
	error["message"] = message
	error["endpoint"] = _endpoint_url()
	_last_error = error.duplicate(true)
	_emit_status_changed()
	return {"ok": false, "terminal_result": message, "error": error}

func _endpoint_url() -> String:
	return "http://" + _host + ":" + str(_port) + _path

func _emit_status_changed() -> void:
	status_changed.emit(get_status())
