extends "res://addons/hermes_os/scripts/ui/hermes_ui/runtime/hermes_app_controller.gd"

const OSEventBus = preload("res://addons/hermes_os/scripts/os/core/os_event_bus.gd")
const CHAT_HISTORY_PATH := "user://hermes_chat_history.json"

var ready_called: bool = false
var input_events: Array[String] = []
var send_invocations: Array[String] = []
var gateway_results: Array[Dictionary] = []
var last_event = null
var _event_bus = null
var _agent_service = null
var _stream_handled: bool = false
var _chat_history: Array[String] = []
var _history_cursor: int = -1

func _app_ready() -> void:
	ready_called = true
	_attach_agent_events()
	if state == null:
		return
	state.set_many({
		"draft": "",
		"can_send": false,
		"is_sending": false,
		"is_streaming": false,
		"is_thinking": false,
		"messages": [],
		"messages_text": "",
		"streaming_text": "",
		"streaming_status": "",
		"has_messages": false,
		"has_action_status": true,
		"action_status": "Ready for Hermes_OS actions",
		"action_status_detail": "Try an example: see the OS, open Browser, go to home.hermes, click, type, or scroll.",
		"gateway": _gateway_status_state(),
		"gateway_display_label": _gateway_status_state().get("label", "Gateway: Offline")
	})
	state.watch("draft", Callable(self, "_on_draft_changed"))
	# Fix: HermesUI TextInput does not set keep_editing_on_text_submit.
	# Without this, the LineEdit has focus but won't accept typed input after
	# text_submitted — same bug we fixed in Terminal.
	var input_control = ui.by_id("message-input") if ui != null else null
	if input_control != null and input_control is LineEdit:
		input_control.keep_editing_on_text_submit = true
		var gui_input_cb := Callable(self, "_on_message_input_gui_input")
		if not input_control.gui_input.is_connected(gui_input_cb):
			input_control.gui_input.connect(gui_input_cb)
	_load_chat_history()

func _on_message_input_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_UP:
			_history_previous()
		KEY_DOWN:
			_history_next()

func _history_previous() -> void:
	if _chat_history.is_empty():
		return
	if _history_cursor < 0:
		_history_cursor = _chat_history.size() - 1
	elif _history_cursor > 0:
		_history_cursor -= 1
	else:
		return
	var entry: String = _chat_history[_history_cursor]
	if ui != null:
		ui.set_value("message-input", entry)
	if state != null:
		state.set("draft", entry)

func _history_next() -> void:
	if _chat_history.is_empty() or _history_cursor < 0:
		return
	_history_cursor += 1
	if _history_cursor >= _chat_history.size():
		_history_cursor = -1
		if ui != null:
			ui.set_value("message-input", "")
		if state != null:
			state.set("draft", "")
		return
	var entry: String = _chat_history[_history_cursor]
	if ui != null:
		ui.set_value("message-input", entry)
	if state != null:
		state.set("draft", entry)

func _append_message(role: String, text: String) -> void:
	if state == null:
		return
	var clean_role: String = role.strip_edges().to_lower()
	if clean_role != "user" and clean_role != "assistant":
		clean_role = "assistant"
	var clean_text: String = str(text)
	var messages_value = state.get_value("messages", [])
	var messages: Array = []
	if messages_value is Array:
		messages = (messages_value as Array).duplicate(true)
	# Dedup: skip if last message is same role and same text
	if not messages.is_empty():
		var last = messages[messages.size() - 1]
		if last is Dictionary and str(last.get("role", "")) == clean_role and str(last.get("text", "")) == clean_text:
			return
	messages.append({"role": clean_role, "text": clean_text})
	state.set("messages", messages)
	state.set("has_messages", messages.size() > 0)
	_save_chat_history()
	_update_messages_text()

func clear_history(event = null) -> void:
	last_event = event
	if state == null:
		return
	state.set_many({
		"messages": [],
		"messages_text": "",
		"has_messages": false,
		"is_sending": false,
		"is_streaming": false,
		"is_thinking": false,
		"streaming_text": "",
		"streaming_status": "",
		"can_send": state.get_string("draft", "").strip_edges() != "",
		"has_action_status": true,
		"action_status": "Chat history cleared",
		"action_status_detail": "Message history and active streaming display were reset."
	})
	_set_gateway_state(_gateway_status_state())
	_save_chat_history()

func _set_last_assistant_message(text: String) -> bool:
	if state == null:
		return false
	var messages_value = state.get_value("messages", [])
	if not (messages_value is Array):
		return false
	var messages: Array = (messages_value as Array).duplicate(true)
	if messages.is_empty():
		return false
	var last_index: int = messages.size() - 1
	var last_value = messages[last_index]
	if not (last_value is Dictionary):
		return false
	var last_message: Dictionary = (last_value as Dictionary).duplicate(true)
	if str(last_message.get("role", "")) != "assistant":
		return false
	var previous_text: String = str(last_message.get("text", ""))
	if previous_text != "Waiting for Hermes Gateway response…" and previous_text != "Hermes is thinking…":
		return false
	last_message["text"] = str(text)
	messages[last_index] = last_message
	state.set("messages", messages)
	state.set("has_messages", messages.size() > 0)
	_save_chat_history()
	_update_messages_text()
	return true

func _update_messages_text() -> void:
	if state == null:
		return
	state.set("messages_text", _format_messages())

func _save_chat_history() -> void:
	if state == null:
		return
	var messages_value = state.get_value("messages", [])
	if not (messages_value is Array) or messages_value.is_empty():
		# No messages — remove file if it exists
		if FileAccess.file_exists(CHAT_HISTORY_PATH):
			DirAccess.remove_absolute(CHAT_HISTORY_PATH)
		return
	var save_data := {
		"messages": messages_value,
		"chat_history": _chat_history,
	}
	var file := FileAccess.open(CHAT_HISTORY_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(save_data))
	file.close()

func _load_chat_history() -> void:
	if state == null:
		return
	if not FileAccess.file_exists(CHAT_HISTORY_PATH):
		return
	var file := FileAccess.open(CHAT_HISTORY_PATH, FileAccess.READ)
	if file == null:
		return
	var json_text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(json_text) != OK:
		return
	var data = json.data
	if not (data is Dictionary):
		return
	var messages = data.get("messages", [])
	if messages is Array and not messages.is_empty():
		state.set("messages", messages)
		state.set("has_messages", true)
		_update_messages_text()
	var history = data.get("chat_history", [])
	if history is Array:
		_chat_history.clear()
		for item in history:
			_chat_history.append(str(item))

func _format_messages() -> String:
	if state == null:
		return ""
	var lines := PackedStringArray()
	var messages_value = state.get_value("messages", [])
	if messages_value is Array:
		for message_value in messages_value:
			if not (message_value is Dictionary):
				continue
			var message: Dictionary = message_value as Dictionary
			var role: String = str(message.get("role", "assistant"))
			var label: String = "You" if role == "user" else "Hermes"
			lines.append(label + ": " + str(message.get("text", "")))
	var streaming_text: String = state.get_string("streaming_text", "").strip_edges()
	if streaming_text != "":
		lines.append("Hermes: " + streaming_text)
	elif state.get_bool("is_thinking", false):
		lines.append("Hermes: thinking…")
	return "\n\n".join(lines)

func _on_draft_changed(value) -> void:
	if state == null:
		return
	var clean: String = str(value).strip_edges()
	state.set("can_send", clean != "" and not state.get_bool("is_sending", false) and not state.get_bool("is_streaming", false))

func _refocus_input() -> void:
	if ui != null:
		ui.focus("message-input")

func _try_local_device_command(text: String) -> Dictionary:
	var controller = null
	# root_control is a Control in the scene tree — use it to reach autoloads
	if root_control != null and is_instance_valid(root_control):
		controller = root_control.get_node_or_null("/root/HomeDeviceController")
	if controller == null:
		return {"handled": false}
	if not controller.has_method("try_handle_chat_message"):
		return {"handled": false}
	return controller.call("try_handle_chat_message", text)

func handle_input(event) -> void:
	last_event = event
	_history_cursor = -1
	input_events.append(str(event.value))

func send_message(event = null) -> void:
	last_event = event
	if state == null:
		return
	var draft: String = state.get_string("draft", "").strip_edges()
	if draft == "":
		_set_gateway_state({"label": "Gateway: enter a message", "variant": "warning"})
		return
	if state.get_bool("is_sending", false) or state.get_bool("is_streaming", false):
		return

	# Try local device command first (short-circuits gateway)
	var device_result := _try_local_device_command(draft)
	if device_result.get("handled", false):
		_append_message("user", draft)
		_chat_history.append(draft)
		_history_cursor = -1
		_append_message("assistant", str(device_result.get("message", "Done.")))
		state.set_many({
			"draft": "",
			"is_sending": false,
			"is_streaming": false,
			"is_thinking": false,
			"streaming_text": "",
			"streaming_status": "",
			"can_send": true,
			"has_action_status": true,
			"action_status": "Local command executed",
			"action_status_detail": str(device_result.get("message", "Done."))
		})
		if ui != null:
			ui.set_value("message-input", "")
			ui.focus("message-input")
		_update_messages_text()
		_refocus_input()
		return

	send_invocations.append(draft)
	_stream_handled = false
	_append_message("user", draft)
	_chat_history.append(draft)
	_history_cursor = -1
	state.set_many({
		"is_sending": true,
		"is_streaming": false,
		"is_thinking": false,
		"streaming_text": "",
		"streaming_status": "",
		"can_send": false,
		"has_action_status": true,
		"action_status": "Attempting Hermes_OS action…",
		"action_status_detail": _action_intent_text(draft)
	})
	_set_gateway_state({"label": "Gateway: Sending", "variant": "warning"})

	var stream_result: Dictionary = _send_to_gateway_stream(draft)
	if bool(stream_result.get("available", false)):
		gateway_results.append(stream_result.duplicate(true))
		if bool(stream_result.get("ok", false)):
			if ui != null:
				ui.set_value("message-input", "")
				ui.focus("message-input")
			state.set_many({
				"draft": "",
				"is_sending": true,
				"is_streaming": true,
				"is_thinking": true,
				"streaming_text": "",
				"streaming_status": "Hermes is thinking…",
				"can_send": false,
				"has_action_status": true,
				"action_status": "Hermes is thinking…",
				"action_status_detail": "Hermes is working on your request before response text is available."
			})
			_update_messages_text()
			_set_gateway_state({"label": "Gateway: Streaming", "variant": "warning"})
			return
		state.set_many({
			"is_sending": false,
			"is_streaming": false,
			"is_thinking": false,
			"streaming_text": "",
			"streaming_status": ""
		})

	var result: Dictionary = _send_to_gateway(draft)
	gateway_results.append(result.duplicate(true))
	var ok: bool = bool(result.get("ok", false))
	if ok:
		if ui != null:
			ui.set_value("message-input", "")
			ui.focus("message-input")
		if _gateway_result_is_async(result):
			state.set_many({
				"draft": "",
				"is_sending": true,
				"is_streaming": false,
				"is_thinking": false,
				"streaming_text": "",
				"streaming_status": "",
				"can_send": false,
				"has_action_status": true,
				"action_status": "Hermes is working in Hermes_OS…",
				"action_status_detail": "Waiting for Gateway/MCP tool results. If blocked, Hermes will report the exact Hermes_OS tool or gate."
			})
			_append_message("assistant", "Waiting for Hermes Gateway response…")
			_set_gateway_state({"label": "Gateway: Sending", "variant": "warning"})
			return
		state.set_many({
			"draft": "",
			"is_sending": false,
			"is_streaming": false,
			"is_thinking": false,
			"streaming_text": "",
			"streaming_status": "",
			"can_send": false,
			"has_action_status": true,
			"action_status": "Hermes reported a result",
			"action_status_detail": _gateway_result_text(result)
		})
		_append_message("assistant", _gateway_result_text(result))
		_set_gateway_state(_gateway_status_state())
		_refocus_input()
		return
	state.set_many({
		"is_sending": false,
		"is_streaming": false,
		"is_thinking": false,
		"streaming_text": "",
		"streaming_status": "",
		"can_send": draft != "",
		"has_action_status": true,
		"action_status": "Hermes_OS action blocked",
		"action_status_detail": _gateway_error_text(result)
	})
	_append_message("assistant", _gateway_error_text(result))
	_set_gateway_state({"label": "Gateway: Offline", "variant": "danger"})
	_refocus_input()

func _send_to_gateway_stream(prompt: String) -> Dictionary:
	var agent_service = _resolve_agent_service()
	if agent_service == null or not agent_service.has_method("send_user_message_stream"):
		return {"available": false, "ok": false}
	var value = agent_service.call("send_user_message_stream", prompt, {"source": "hermes_chat"})
	if value is Dictionary:
		var result: Dictionary = (value as Dictionary).duplicate(true)
		result["available"] = true
		return result
	return {"available": true, "ok": false, "terminal_result": "Hermes Gateway stream request failed", "error": {"code": "STREAM_RESULT_INVALID", "message": "Hermes Gateway stream request failed"}}

func _send_to_gateway(prompt: String) -> Dictionary:
	if os != null and os.gateway != null and os.gateway.has_method("send_chat"):
		var value = os.gateway.send_chat(prompt)
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {
		"ok": false,
		"terminal_result": "Hermes Gateway service is unavailable",
		"error": {"code": "GATEWAY_UNAVAILABLE", "message": "Hermes Gateway service is unavailable"}
	}

func _gateway_result_is_async(result: Dictionary) -> bool:
	var result_value = result.get("result", null)
	if result_value is Dictionary and bool((result_value as Dictionary).get("queued", false)):
		return true
	var terminal_result: String = str(result.get("terminal_result", "")).strip_edges().to_lower()
	return terminal_result.contains("sent to hermes gateway")

func _attach_agent_events() -> void:
	_attach_streaming_events()
	if os == null or not (os.context is Dictionary):
		return
	var bus_value = os.context.get("event_bus", null)
	if bus_value == null or not bus_value.has_method("subscribe"):
		return
	_event_bus = bus_value
	_event_bus.subscribe(OSEventBus.AGENT_RESPONSE_RECEIVED, self, "_on_agent_event")
	_event_bus.subscribe(OSEventBus.AGENT_ERROR, self, "_on_agent_event")
	_event_bus.subscribe(OSEventBus.AGENT_STATUS_CHANGED, self, "_on_agent_event")
	_event_bus.subscribe(OSEventBus.AGENT_OPERATION_REQUESTED, self, "_on_agent_event")
	_event_bus.subscribe(OSEventBus.AGENT_OPERATION_COMPLETED, self, "_on_agent_event")
	_event_bus.subscribe(OSEventBus.AGENT_OPERATION_FAILED, self, "_on_agent_event")

func _attach_streaming_events() -> void:
	var agent_service = _resolve_agent_service()
	if agent_service == null:
		return
	_agent_service = agent_service
	if agent_service.has_signal("stream_delta_received"):
		var delta_callable := Callable(self, "_on_stream_delta")
		if not agent_service.is_connected("stream_delta_received", delta_callable):
			agent_service.connect("stream_delta_received", delta_callable)
	if agent_service.has_signal("stream_completed"):
		var completed_callable := Callable(self, "_on_stream_completed")
		if not agent_service.is_connected("stream_completed", completed_callable):
			agent_service.connect("stream_completed", completed_callable)
	if agent_service.has_signal("stream_error"):
		var error_callable := Callable(self, "_on_stream_error")
		if not agent_service.is_connected("stream_error", error_callable):
			agent_service.connect("stream_error", error_callable)

func _detach_streaming_events() -> void:
	if _agent_service == null:
		return
	var delta_callable := Callable(self, "_on_stream_delta")
	if _agent_service.has_signal("stream_delta_received") and _agent_service.is_connected("stream_delta_received", delta_callable):
		_agent_service.disconnect("stream_delta_received", delta_callable)
	var completed_callable := Callable(self, "_on_stream_completed")
	if _agent_service.has_signal("stream_completed") and _agent_service.is_connected("stream_completed", completed_callable):
		_agent_service.disconnect("stream_completed", completed_callable)
	var error_callable := Callable(self, "_on_stream_error")
	if _agent_service.has_signal("stream_error") and _agent_service.is_connected("stream_error", error_callable):
		_agent_service.disconnect("stream_error", error_callable)
	_agent_service = null

func app_unmounted() -> void:
	if _event_bus != null and _event_bus.has_method("unsubscribe"):
		_event_bus.unsubscribe(OSEventBus.AGENT_RESPONSE_RECEIVED, self, "_on_agent_event")
		_event_bus.unsubscribe(OSEventBus.AGENT_ERROR, self, "_on_agent_event")
		_event_bus.unsubscribe(OSEventBus.AGENT_STATUS_CHANGED, self, "_on_agent_event")
		_event_bus.unsubscribe(OSEventBus.AGENT_OPERATION_REQUESTED, self, "_on_agent_event")
		_event_bus.unsubscribe(OSEventBus.AGENT_OPERATION_COMPLETED, self, "_on_agent_event")
		_event_bus.unsubscribe(OSEventBus.AGENT_OPERATION_FAILED, self, "_on_agent_event")
	_event_bus = null
	_detach_streaming_events()
	super.app_unmounted()

func _on_agent_event(event_name: StringName, payload: Dictionary) -> void:
	if state == null:
		return
	match event_name:
		OSEventBus.AGENT_RESPONSE_RECEIVED:
			if _stream_handled:
				_stream_handled = false
				return
			if not state.get_bool("is_sending", false) and not state.get_bool("is_streaming", false):
				return
			var assistant_text: String = _clean_user_facing_text(str(payload.get("assistant_text", "")).strip_edges())
			var response_text: String = assistant_text if assistant_text != "" else "(no output)"
			state.set_many({
				"is_sending": false,
				"is_streaming": false,
				"is_thinking": false,
				"streaming_text": "",
				"streaming_status": "",
				"can_send": state.get_string("draft", "").strip_edges() != "",
				"has_action_status": true,
				"action_status": "Hermes reported a result",
				"action_status_detail": _compact_status_detail(response_text)
			})
			if not _set_last_assistant_message(response_text):
				_append_message("assistant", response_text)
			_set_gateway_state(_gateway_status_state())
			_refocus_input()
		OSEventBus.AGENT_ERROR:
			if _stream_handled:
				_stream_handled = false
				return
			if not state.get_bool("is_sending", false) and not state.get_bool("is_streaming", false):
				return
			var error_text: String = _clean_user_facing_text(str(payload.get("message", "Hermes Gateway error")))
			state.set_many({
				"is_sending": false,
				"is_streaming": false,
				"is_thinking": false,
				"streaming_text": "",
				"streaming_status": "",
				"can_send": state.get_string("draft", "").strip_edges() != "",
				"has_action_status": true,
				"action_status": "Hermes_OS action blocked",
				"action_status_detail": error_text
			})
			if not _set_last_assistant_message(error_text):
				_append_message("assistant", error_text)
			_set_gateway_state({"label": "Gateway: Offline", "variant": "danger"})
			_refocus_input()
		OSEventBus.AGENT_STATUS_CHANGED:
			if not state.get_bool("is_sending", false) and not state.get_bool("is_streaming", false):
				_set_gateway_state(_gateway_status_state())
		OSEventBus.AGENT_OPERATION_REQUESTED:
			state.set_many({
				"has_action_status": true,
				"action_status": "Using Hermes_OS tool: " + _payload_operation(payload),
				"action_status_detail": _format_operation_detail(payload, false)
			})
		OSEventBus.AGENT_OPERATION_COMPLETED:
			state.set_many({
				"has_action_status": true,
				"action_status": "Succeeded: " + _payload_operation(payload),
				"action_status_detail": _format_operation_detail(payload, false)
			})
		OSEventBus.AGENT_OPERATION_FAILED:
			state.set_many({
				"has_action_status": true,
				"action_status": "Blocked: " + _payload_operation(payload),
				"action_status_detail": _format_operation_detail(payload, true)
			})

func _on_stream_delta(payload: Dictionary) -> void:
	if state == null:
		return
	var partial: String = str(payload.get("assistant_text_partial", ""))
	if partial == "":
		return
	var accumulated: String = state.get_string("streaming_text", "") + partial
	state.set_many({
		"is_streaming": true,
		"is_sending": true,
		"is_thinking": false,
		"streaming_text": accumulated,
		"streaming_status": "Hermes is responding…",
		"last_gateway_message": accumulated,
		"has_action_status": true,
		"action_status": "Hermes is responding…",
		"action_status_detail": "Receiving live response chunks from Hermes Gateway."
	})
	_update_messages_text()
	_set_gateway_state({"label": "Gateway: Streaming", "variant": "warning"})

func _on_stream_completed(payload: Dictionary) -> void:
	if state == null:
		return
	var assistant_text: String = _clean_user_facing_text(str(payload.get("assistant_text", "")).strip_edges())
	if assistant_text == "":
		assistant_text = state.get_string("streaming_text", "").strip_edges()
	if assistant_text == "":
		assistant_text = "(no output)"
	state.set_many({
		"is_streaming": false,
		"is_sending": false,
		"is_thinking": false,
		"streaming_text": "",
		"streaming_status": "",
		"can_send": state.get_string("draft", "").strip_edges() != "",
		"last_gateway_message": assistant_text,
		"has_action_status": true,
		"action_status": "Hermes reported a result",
		"action_status_detail": _compact_status_detail(assistant_text)
	})
	_stream_handled = true
	_append_message("assistant", assistant_text)
	_set_gateway_state(_gateway_status_state())
	_refocus_input()

func _on_stream_error(payload: Dictionary) -> void:
	if state == null:
		return
	var error_text: String = _clean_user_facing_text(str(payload.get("message", payload.get("error", "Hermes Gateway stream error"))))
	if error_text == "":
		error_text = "Hermes Gateway stream error"
	state.set_many({
		"is_streaming": false,
		"is_sending": false,
		"is_thinking": false,
		"streaming_text": "",
		"streaming_status": "",
		"can_send": state.get_string("draft", "").strip_edges() != "",
		"has_action_status": true,
		"action_status": "Hermes_OS action blocked",
		"action_status_detail": error_text
	})
	_stream_handled = true
	_append_message("assistant", error_text)
	_set_gateway_state({"label": "Gateway: Offline", "variant": "danger"})
	_refocus_input()

func _action_intent_text(prompt: String) -> String:
	var lower := prompt.to_lower()
	if lower.contains("what can you see") or lower.contains("apps and windows"):
		return "Expected tools: hermes_os_observe / hermes_os_get_ui_tree / window-app state."
	if lower.contains("open") and lower.contains("browser"):
		return "Expected tool: hermes_os_open_app with app_id=browser."
	if lower.contains("navigate") or lower.contains("home.hermes"):
		return "Expected tool: hermes_os_browser_navigate to a bundled Hermes Internet page."
	if lower.contains("click"):
		return "Expected tool: hermes_os_browser_activate_link or hermes_os_click, scoped to Hermes_OS."
	if lower.contains("type"):
		return "Expected tool: hermes_os_type_text, scoped to the focused Hermes_OS surface."
	if lower.contains("scroll"):
		return "Expected tool: hermes_os_scroll or hermes_os_browser_test_scroll, scoped to Hermes_OS."
	return "Hermes will use Hermes_OS MCP tools when the request involves OS state or visible control."

func _payload_operation(payload: Dictionary) -> String:
	var operation: String = str(payload.get("operation", "")).strip_edges()
	if operation == "":
		operation = str(payload.get("op", "")).strip_edges()
	return operation if operation != "" else "Hermes_OS operation"

func _format_operation_detail(payload: Dictionary, prefer_error: bool) -> String:
	if prefer_error:
		var error_value = payload.get("error", {})
		if error_value is Dictionary:
			var message: String = str((error_value as Dictionary).get("message", "")).strip_edges()
			var code: String = str((error_value as Dictionary).get("code", "")).strip_edges()
			if message != "" and code != "":
				return code + ": " + message
			if message != "":
				return message
			if code != "":
				return code
	var result_value = payload.get("result", {})
	if result_value is Dictionary and not (result_value as Dictionary).is_empty():
		return _dictionary_to_user_text(result_value as Dictionary)
	var args_value = payload.get("args", {})
	if args_value is Dictionary and not (args_value as Dictionary).is_empty():
		return "Args: " + _format_key_values(args_value as Dictionary)
	return "Hermes_OS operation state changed."

func _clean_user_facing_text(text: String) -> String:
	var clean := text.strip_edges()
	if clean == "":
		return ""
	if (clean.begins_with("{") and clean.ends_with("}")) or (clean.begins_with("[") and clean.ends_with("]")):
		var parsed: Variant = JSON.parse_string(clean)
		if parsed is Dictionary:
			return _dictionary_to_user_text(parsed as Dictionary)
	return _compact_status_detail(clean)

func _dictionary_to_user_text(data: Dictionary) -> String:
	var error_value = data.get("error", null)
	if error_value is Dictionary:
		return _format_blocker(error_value as Dictionary)
	var assistant_text: String = str(data.get("assistant_text", "")).strip_edges()
	if assistant_text != "":
		return _clean_user_facing_text(assistant_text)
	var message: String = str(data.get("message", "")).strip_edges()
	if message != "":
		return _ensure_sentence(message)
	var terminal_result: String = str(data.get("terminal_result", "")).strip_edges()
	if terminal_result != "":
		return _ensure_sentence(terminal_result)
	var result_value = data.get("result", null)
	if result_value is Dictionary and not (result_value as Dictionary).is_empty():
		return _dictionary_to_user_text(result_value as Dictionary)
	var state_parts := PackedStringArray()
	for key in ["app_id", "window_id", "title", "url", "status", "focused"]:
		if data.has(key):
			state_parts.append(str(key) + "=" + str(data.get(key)))
	if state_parts.size() > 0:
		return _compact_status_detail("Hermes_OS result: " + ", ".join(state_parts))
	return "Hermes_OS operation completed."

func _format_blocker(error: Dictionary) -> String:
	var code: String = str(error.get("code", "")).strip_edges()
	var message: String = str(error.get("message", "")).strip_edges()
	if code != "" and message != "":
		return "Blocked: " + code + " — " + _ensure_sentence(message)
	if message != "":
		return "Blocked: " + _ensure_sentence(message)
	if code != "":
		return "Blocked: " + code
	return "Blocked: Hermes_OS operation failed."

func _format_key_values(values: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in values.keys():
		parts.append(str(key) + "=" + str(values.get(key)))
	return _compact_status_detail(", ".join(parts))

func _ensure_sentence(text: String) -> String:
	var clean := text.strip_edges()
	if clean == "":
		return clean
	var last := clean.substr(clean.length() - 1, 1)
	if last == "." or last == "!" or last == "?":
		return clean
	return clean + "."

func _compact_status_detail(text: String) -> String:
	var clean := text.strip_edges().replace("\n", " ")
	while clean.contains("  "):
		clean = clean.replace("  ", " ")
	if clean.length() > 220:
		return clean.substr(0, 217) + "…"
	return clean

func _gateway_status_state() -> Dictionary:
	var status: Dictionary = _agent_gateway_status()
	var configured: bool = bool(status.get("configured", false))
	var busy: bool = bool(status.get("busy", false))
	if busy:
		return {"label": "Gateway: Checking", "variant": "warning"}
	if configured:
		return {"label": "Gateway: Online", "variant": "success"}
	return {"label": "Gateway: Offline", "variant": "danger"}

func _set_gateway_state(value: Dictionary) -> void:
	if state == null:
		return
	var next: Dictionary = value.duplicate(true)
	state.set("gateway", next)
	state.set("gateway_display_label", str(next.get("label", "Gateway: Offline")))

func _resolve_agent_service():
	if os != null:
		if os.context is Dictionary:
			var context_service = os.context.get("agent_service", null)
			if context_service != null:
				return context_service
		if os.has_method("hermes_agent_service"):
			return os.call("hermes_agent_service")
	return null

func _agent_gateway_status() -> Dictionary:
	var agent_service = _resolve_agent_service()
	if agent_service != null and agent_service.has_method("get_status"):
		var value = agent_service.call("get_status")
		if value is Dictionary:
			var gateway_value = (value as Dictionary).get("gateway", {})
			if gateway_value is Dictionary:
				return (gateway_value as Dictionary).duplicate(true)
	return {"configured": false, "busy": false, "model": "", "profile_hint": "hermesos"}

func _gateway_result_text(result: Dictionary) -> String:
	var terminal_result: String = str(result.get("terminal_result", "")).strip_edges()
	if terminal_result != "":
		return terminal_result
	var result_value = result.get("result", null)
	if result_value is Dictionary:
		var text: String = str((result_value as Dictionary).get("assistant_text", "")).strip_edges()
		if text != "":
			return text
	return "Message sent to Hermes Gateway."

func _gateway_error_text(result: Dictionary) -> String:
	var terminal_result: String = str(result.get("terminal_result", "")).strip_edges()
	if terminal_result != "":
		return terminal_result
	var error_value = result.get("error", null)
	if error_value is Dictionary:
		return str((error_value as Dictionary).get("message", "Hermes Gateway request failed"))
	return "Hermes Gateway request failed"
