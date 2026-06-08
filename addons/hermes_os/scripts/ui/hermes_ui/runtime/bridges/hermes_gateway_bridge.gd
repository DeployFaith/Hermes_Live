class_name HermesGatewayBridge
extends RefCounted

var _agent_service = null
var _gateway = null

func setup(context: Dictionary) -> HermesGatewayBridge:
	_agent_service = context.get("agent_service", null)
	_gateway = context.get("gateway", null)
	return self

func send_chat(prompt: String) -> Dictionary:
	var clean: String = prompt.strip_edges()
	if clean == "":
		return _fail("MISSING_PROMPT", "Prompt is required")
	if _agent_service != null:
		if _agent_service.has_method("send_user_message"):
			var user_result: Variant = _agent_service.call("send_user_message", clean, {"source": "hermes_ui_controller"})
			return _normalize_result(user_result)
		if _agent_service.has_method("send_terminal_message"):
			var terminal_result: Variant = _agent_service.call("send_terminal_message", clean, {"source": "hermes_ui_controller"})
			return _normalize_result(terminal_result)
	if _gateway != null and _gateway.has_method("send_message"):
		return _normalize_result(_gateway.call("send_message", clean, {"source": "hermes_ui_controller"}))
	return _fail("GATEWAY_UNAVAILABLE", "Hermes Gateway service is unavailable")

func _normalize_result(value) -> Dictionary:
	if value is Dictionary:
		var result: Dictionary = (value as Dictionary).duplicate(true)
		if not result.has("ok"):
			result["ok"] = true
		return result
	return {"ok": true, "result": value}

func _fail(code: String, message: String) -> Dictionary:
	return {"ok": false, "error": {"code": code, "message": message, "details": {}}, "terminal_result": message}
