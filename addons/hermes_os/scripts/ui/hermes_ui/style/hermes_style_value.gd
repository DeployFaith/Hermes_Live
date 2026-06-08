class_name HermesStyleValue
extends RefCounted

var raw_text: String = ""
var value_type: String = "keyword"
var value = null

func configure(text: String):
	raw_text = text.strip_edges()
	value_type = _detect_type(raw_text)
	value = _coerce_value(raw_text, value_type)
	return self

func _detect_type(text: String) -> String:
	if text.begins_with("var("):
		return "var"
	if text.begins_with("rgba(") or text.begins_with("rgb("):
		return "color"
	if text.begins_with("#"):
		return "color"
	if text.begins_with("\"") or text.begins_with("'"):
		return "string"
	if text.ends_with("px"):
		return "length"
	if text.ends_with("%"):
		return "percent"
	if text.ends_with("fr"):
		return "fr"
	if text.is_valid_float() or text.is_valid_int():
		return "number"
	if text.contains("rgba(") or text.contains("rgb("):
		return "composite"
	return "keyword"

func _coerce_value(text: String, detected_type: String):
	match detected_type:
		"number":
			return float(text)
		"length":
			return float(text.trim_suffix("px"))
		"percent":
			return float(text.trim_suffix("%"))
		"fr":
			return float(text.trim_suffix("fr"))
		"var":
			return text.trim_prefix("var(").trim_suffix(")").strip_edges()
		"string":
			return text.substr(1, max(text.length() - 2, 0))
		_:
			return text
