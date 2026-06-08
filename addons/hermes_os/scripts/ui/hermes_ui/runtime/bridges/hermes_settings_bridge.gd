class_name HermesSettingsBridge
extends RefCounted

var _settings = null
var last_error: Dictionary = {}

func setup(context: Dictionary) -> HermesSettingsBridge:
	_settings = context.get("settings", null)
	last_error.clear()
	return self

func get_value(key: String, default_value = null):
	last_error.clear()
	if _settings != null:
		if _settings.has_method("get_setting"):
			return _settings.call("get_setting", key, default_value)
		if _settings.has_method("get_value"):
			return _settings.call("get_value", key, default_value)
	last_error = _unavailable("Hermes settings service is unavailable")
	return default_value

func set_value(key: String, value) -> bool:
	last_error.clear()
	if _settings != null:
		if _settings.has_method("set_setting"):
			var setting_result: Variant = _settings.call("set_setting", key, value)
			return _truthy_ok(setting_result)
		if _settings.has_method("set_value"):
			var result: Variant = _settings.call("set_value", key, value)
			return _truthy_ok(result)
	last_error = _unavailable("Hermes settings service is unavailable")
	return false

func _truthy_ok(value) -> bool:
	if value is Dictionary:
		return bool((value as Dictionary).get("ok", false))
	if value is bool:
		return bool(value)
	return value == null

func _unavailable(message: String) -> Dictionary:
	return {"ok": false, "error": {"code": "SETTINGS_UNAVAILABLE", "message": message, "details": {}}}
