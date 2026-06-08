class_name HermesComputedStyle
extends RefCounted

var properties: Dictionary = {}
var matched_selectors: Array[String] = []

func set_property(name: String, value) -> void:
	properties[name] = value

func has_property(name: String) -> bool:
	return properties.has(name)

func get_value(name: String, default_value = null):
	if not properties.has(name):
		return default_value
	var value = properties[name]
	if value is Color:
		return "#" + (value as Color).to_html(false).to_lower()
	return value

func get_number(name: String, default_value: float = 0.0) -> float:
	if not properties.has(name):
		return default_value
	var value = properties[name]
	if value is int or value is float:
		return float(value)
	var text: String = str(value).strip_edges()
	if text.is_valid_int() or text.is_valid_float():
		return float(text)
	return default_value

func get_string(name: String, default_value: String = "") -> String:
	if not properties.has(name):
		return default_value
	var value = properties[name]
	if value is Color:
		return "#" + (value as Color).to_html(false).to_lower()
	return str(value)

func get_color(name: String, default_value: Color = Color.TRANSPARENT) -> Color:
	if not properties.has(name):
		return default_value
	var value = properties[name]
	if value is Color:
		return value as Color
	var text: String = str(value).strip_edges()
	if text == "":
		return default_value
	if text == "transparent":
		return Color(0, 0, 0, 0)
	if not text.begins_with("#") and (text.length() == 6 or text.length() == 8):
		text = "#" + text
	if text.begins_with("#"):
		return Color(text)
	if text.begins_with("rgb(") or text.begins_with("rgba("):
		return _parse_rgb_color(text, default_value)
	return default_value

func _parse_rgb_color(text: String, default_value: Color) -> Color:
	var body: String = text.substr(text.find("(") + 1, text.rfind(")") - text.find("(") - 1)
	var parts: PackedStringArray = body.split(",", false)
	if parts.size() < 3:
		return default_value
	var r: float = clampf(float(parts[0].strip_edges()) / 255.0, 0.0, 1.0)
	var g: float = clampf(float(parts[1].strip_edges()) / 255.0, 0.0, 1.0)
	var b: float = clampf(float(parts[2].strip_edges()) / 255.0, 0.0, 1.0)
	var a: float = 1.0
	if parts.size() >= 4:
		a = clampf(float(parts[3].strip_edges()), 0.0, 1.0)
	return Color(r, g, b, a)
