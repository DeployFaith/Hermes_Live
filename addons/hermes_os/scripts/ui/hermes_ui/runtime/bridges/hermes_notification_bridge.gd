class_name HermesNotificationBridge
extends RefCounted

var _shell: Node = null
var _notification_center = null

func setup(context: Dictionary) -> HermesNotificationBridge:
	_shell = context.get("shell", null) as Node
	_notification_center = context.get("notification_center", null)
	return self

func show(data: Dictionary) -> Dictionary:
	var payload: Dictionary = data.duplicate(true)
	if _shell != null and _shell.has_method("notify"):
		var shell_result: Variant = _shell.call("notify", payload)
		return {"ok": true, "id": str(shell_result), "result": shell_result}
	if _notification_center != null:
		if _notification_center.has_method("notify_from_dict"):
			var center_result: Variant = _notification_center.call("notify_from_dict", payload)
			return _normalize(center_result)
		if _notification_center.has_method("notify"):
			var title: String = str(payload.get("title", "Notification"))
			var body: String = str(payload.get("body", ""))
			var options: Dictionary = payload.duplicate(true)
			options.erase("title")
			options.erase("body")
			return _normalize(_notification_center.call("notify", title, body, options))
	return {"ok": false, "error": {"code": "NOTIFICATIONS_UNAVAILABLE", "message": "Hermes notification service is unavailable", "details": {}}}

func _normalize(value) -> Dictionary:
	if value is Dictionary:
		var result: Dictionary = (value as Dictionary).duplicate(true)
		if not result.has("ok"):
			result["ok"] = true
		return result
	return {"ok": true, "result": value}
