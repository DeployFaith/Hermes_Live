class_name HermesStyleParser
extends RefCounted

const HermesStyleSheet = preload("res://addons/hermes_os/scripts/ui/hermes_ui/style/hermes_style_sheet.gd")
const HermesStyleRule = preload("res://addons/hermes_os/scripts/ui/hermes_ui/style/hermes_style_rule.gd")
const HermesStyleDeclaration = preload("res://addons/hermes_os/scripts/ui/hermes_ui/style/hermes_style_declaration.gd")
const HermesStyleValue = preload("res://addons/hermes_os/scripts/ui/hermes_ui/style/hermes_style_value.gd")

func parse_file(path: String):
	var sheet = HermesStyleSheet.new()
	sheet.source_path = path
	if not FileAccess.file_exists(path):
		sheet.add_error("Stylesheet not found", -1)
		return sheet
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		sheet.add_error("Stylesheet could not be opened", -1)
		return sheet
	return parse_text(file.get_as_text(), path)

func parse_text(text: String, source_path: String = ""):
	var sheet = HermesStyleSheet.new()
	sheet.source_path = source_path
	var sanitized: String = _strip_comments(text)
	var index: int = 0
	while index < sanitized.length():
		var open_brace: int = sanitized.find("{", index)
		if open_brace == -1:
			break
		var selector_text: String = sanitized.substr(index, open_brace - index).strip_edges()
		var close_brace: int = _find_matching_brace(sanitized, open_brace)
		if close_brace == -1:
			sheet.add_error("Unclosed selector block", _line_number(sanitized, open_brace))
			break
		var body: String = sanitized.substr(open_brace + 1, close_brace - open_brace - 1)
		if selector_text == "":
			sheet.add_error("Selector block missing selector", _line_number(sanitized, open_brace))
		else:
			_parse_block(sheet, selector_text, body, _line_number(sanitized, open_brace))
		index = close_brace + 1
	return sheet

func _parse_block(sheet, selector_text: String, body: String, line: int) -> void:
	var selectors: Array[String] = []
	for selector in selector_text.split(",", false):
		var clean: String = selector.strip_edges()
		if clean != "":
			selectors.append(clean)
	if selectors.is_empty():
		sheet.add_error("Empty selector group", line)
		return
	var declarations: Array = _parse_declarations(body, line, sheet)
	if selectors.size() == 1 and selectors[0] == ":root":
		for declaration in declarations:
			if declaration == null:
				continue
			if declaration.property_name.begins_with("--"):
				sheet.add_variable(declaration.property_name, declaration.value)
			else:
				sheet.add_error(":root only supports variables in this parser", declaration.source_line)
		return
	var rule = HermesStyleRule.new().configure(selectors, line, sheet.source_path)
	for declaration in declarations:
		rule.add_declaration(declaration)
	sheet.add_rule(rule)

func _parse_declarations(body: String, start_line: int, sheet) -> Array:
	var declarations: Array = []
	var current: String = ""
	var paren_depth: int = 0
	var line: int = start_line
	for i in range(body.length()):
		var ch := body[i]
		if ch == "\n":
			line += 1
		if ch == "(":
			paren_depth += 1
		elif ch == ")" and paren_depth > 0:
			paren_depth -= 1
		if ch == ";" and paren_depth == 0:
			_add_declaration_chunk(declarations, current, line, sheet)
			current = ""
		else:
			current += ch
	if current.strip_edges() != "":
		_add_declaration_chunk(declarations, current, line, sheet)
	return declarations

func _add_declaration_chunk(declarations: Array, chunk: String, line: int, sheet) -> void:
	var trimmed: String = chunk.strip_edges()
	if trimmed == "":
		return
	if trimmed.contains("{") or trimmed.contains("}"):
		sheet.add_error("Invalid declaration syntax", line)
		return
	var colon_index: int = trimmed.find(":")
	if colon_index == -1:
		sheet.add_error("Declaration missing ':'", line)
		return
	var property_name: String = trimmed.substr(0, colon_index).strip_edges()
	var raw_value: String = trimmed.substr(colon_index + 1).strip_edges()
	if property_name == "" or raw_value == "":
		sheet.add_error("Declaration missing property or value", line)
		return
	declarations.append(HermesStyleDeclaration.new().configure(property_name, raw_value, line))

func _strip_comments(text: String) -> String:
	var result := ""
	var i: int = 0
	while i < text.length():
		if i + 1 < text.length() and text[i] == "/" and text[i + 1] == "*":
			i += 2
			while i + 1 < text.length() and not (text[i] == "*" and text[i + 1] == "/"):
				result += "\n" if text[i] == "\n" else " "
				i += 1
			i += 2
			continue
		result += text[i]
		i += 1
	return result

func _find_matching_brace(text: String, open_brace: int) -> int:
	var depth: int = 0
	for i in range(open_brace, text.length()):
		if text[i] == "{":
			depth += 1
		elif text[i] == "}":
			depth -= 1
			if depth == 0:
				return i
	return -1

func _line_number(text: String, index: int) -> int:
	var line: int = 1
	for i in range(min(index, text.length())):
		if text[i] == "\n":
			line += 1
	return line
