class_name HermesBindingExpression
extends RefCounted

var template: String = ""

func configure(value: String):
	template = value
	return self

static func has_binding(value: String) -> bool:
	return value.find("{") != -1 and value.find("}") != -1

func is_bound() -> bool:
	return has_binding(template)

func evaluate(scope):
	var clean: String = template.strip_edges()
	var full: Dictionary = _full_binding_range(clean)
	if not full.is_empty():
		return _evaluate_token(str(full.get("token", "")), scope)
	return _interpolate(template, scope)

func _interpolate(text: String, scope) -> String:
	var result: String = ""
	var index: int = 0
	while index < text.length():
		var open_index: int = text.find("{", index)
		if open_index == -1:
			result += text.substr(index)
			break
		result += text.substr(index, open_index - index)
		var close_index: int = text.find("}", open_index + 1)
		if close_index == -1:
			result += text.substr(open_index)
			break
		var token: String = text.substr(open_index + 1, close_index - open_index - 1)
		result += str(_evaluate_token(token, scope))
		index = close_index + 1
	return result

func _full_binding_range(text: String) -> Dictionary:
	if not text.begins_with("{") or not text.ends_with("}"):
		return {}
	var close_index: int = text.find("}")
	if close_index != text.length() - 1:
		return {}
	return {"token": text.substr(1, text.length() - 2)}

func _evaluate_token(token: String, scope):
	var expression: String = token.strip_edges()
	if expression == "":
		return ""
	if expression.begins_with("!"):
		return not _boolish(_resolve_path(expression.substr(1).strip_edges(), scope))
	var equals_index: int = expression.find("==")
	if equals_index != -1:
		var left = _resolve_operand(expression.substr(0, equals_index).strip_edges(), scope)
		var right = _resolve_operand(expression.substr(equals_index + 2).strip_edges(), scope)
		return str(left) == str(right)
	return _resolve_path(expression, scope)

func _resolve_operand(text: String, scope):
	var clean: String = text.strip_edges()
	if (clean.begins_with("\"") and clean.ends_with("\"")) or (clean.begins_with("'") and clean.ends_with("'")):
		return clean.substr(1, clean.length() - 2)
	return _resolve_path(clean, scope)

func _resolve_path(path: String, scope):
	if path == "":
		return ""
	if scope != null and scope is Object and (scope as Object).has_method("get_value"):
		return (scope as Object).call("get_value", path, null)
	if scope != null and scope is Object and (scope as Object).has_method("get"):
		return (scope as Object).call("get", path)
	var current = scope
	for part in path.split(".", false):
		if current is Dictionary:
			var dictionary: Dictionary = current
			if not dictionary.has(part):
				return null
			current = dictionary[part]
		else:
			return null
	return current

func _boolish(value) -> bool:
	if value is bool:
		return bool(value)
	var text: String = str(value).strip_edges().to_lower()
	return text == "true" or text == "1" or text == "yes" or text == "on"
