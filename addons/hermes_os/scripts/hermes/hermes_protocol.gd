class_name HermesProtocol
extends RefCounted

const PROTOCOL_VERSION := "0.1.0"

static func timestamp_unix() -> int:
	return int(Time.get_unix_time_from_system())

static func parse_json_message(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {
			"ok": false,
			"error": {
				"code": "INVALID_JSON",
				"message": "Expected JSON object message"
			}
		}
	return {"ok": true, "message": parsed}

static func make_hello(session_id: String, project_id: String) -> Dictionary:
	return {
		"type": "hello",
		"protocol_version": PROTOCOL_VERSION,
		"session_id": session_id,
		"project_id": project_id,
		"client": "godot",
		"os": "HermesOS"
	}

static func make_manifest(session_id: String, manifest: Dictionary) -> Dictionary:
	return {
		"type": "os.manifest",
		"protocol_version": PROTOCOL_VERSION,
		"session_id": session_id,
		"manifest": manifest
	}

static func make_event(event_name: String, payload: Dictionary) -> Dictionary:
	return {
		"type": "event",
		"event": event_name,
		"timestamp": timestamp_unix(),
		"payload": payload
	}

static func make_operation_result(operation_id: String, ok: bool, result: Dictionary, error_data: Dictionary = {}) -> Dictionary:
	var message := {
		"type": "operation_result",
		"id": operation_id,
		"ok": ok
	}
	if ok:
		message["result"] = result
	else:
		message["error"] = error_data
	return message

static func make_response(request_id: String, ok: bool, result: Dictionary, error_data: Dictionary = {}) -> Dictionary:
	var message := {
		"type": "response",
		"id": request_id,
		"ok": ok
	}
	if ok:
		message["result"] = result
	else:
		message["error"] = error_data
	return message

static func make_error(code: String, message: String, details: Dictionary = {}) -> Dictionary:
	return {
		"code": code,
		"message": message,
		"details": details
	}
