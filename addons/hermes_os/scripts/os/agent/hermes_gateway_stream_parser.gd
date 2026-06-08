class_name HermesGatewayStreamParser
extends RefCounted

signal delta_received(text: String)
signal completion_received(full_text: String)
signal error_received(message: String, details: Dictionary)

var _buffer: String = ""
var _accumulated_text: String = ""

func feed(chunk: String) -> void:
	if chunk == "":
		return
	_buffer += chunk
	var lines := _buffer.split("\n", false)
	if not _buffer.ends_with("\n"):
		_buffer = str(lines[lines.size() - 1]) if not lines.is_empty() else _buffer
		lines = lines.slice(0, max(0, lines.size() - 1))
	else:
		_buffer = ""
	for raw_line in lines:
		_process_line(str(raw_line).strip_edges())

func get_accumulated_text() -> String:
	return _accumulated_text

func reset() -> void:
	_buffer = ""
	_accumulated_text = ""

func _process_line(line: String) -> void:
	if line == "":
		return
	if not line.begins_with("data:"):
		return
	var payload := line.substr(5).strip_edges()
	if payload == "[DONE]":
		completion_received.emit(_accumulated_text)
		return
	var parsed: Variant = JSON.parse_string(payload)
	if not (parsed is Dictionary):
		error_received.emit("Hermes Gateway stream returned invalid JSON", {"payload": payload})
		return
	var data: Dictionary = parsed
	var choices: Array = data.get("choices", []) if data.get("choices", []) is Array else []
	if choices.is_empty():
		return
	var first: Dictionary = choices[0] if choices[0] is Dictionary else {}
	var delta: Dictionary = first.get("delta", {}) if first.get("delta", {}) is Dictionary else {}
	var content: Variant = delta.get("content", "")
	if content is String and not (content as String).is_empty():
		_accumulated_text += content as String
		delta_received.emit(content as String)
