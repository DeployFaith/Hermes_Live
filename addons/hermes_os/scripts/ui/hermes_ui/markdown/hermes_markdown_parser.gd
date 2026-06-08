class_name HermesMarkdownParser
extends RefCounted

const HermesMarkdownDocument = preload("res://addons/hermes_os/scripts/ui/hermes_ui/markdown/hermes_markdown_document.gd")

func parse_file(path: String):
	var document = HermesMarkdownDocument.new()
	document.source_path = path
	if not FileAccess.file_exists(path):
		document.add_diagnostic("Markdown file not found", -1)
		return document
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		document.add_diagnostic("Markdown file could not be opened", -1)
		return document
	return parse_text(file.get_as_text(), path)

func parse_text(text: String, source_path: String = ""):
	var document = HermesMarkdownDocument.new()
	document.source_path = source_path
	var lines: PackedStringArray = text.split("\n", true)
	var nodes: Array = []
	var stack: Array = []
	var index := 0

	if lines.size() > 0 and lines[0].strip_edges() == "---":
		index = _parse_frontmatter(lines, document)

	for i in range(index, lines.size()):
		var line_number := i + 1
		var raw_line: String = lines[i]
		var trimmed := raw_line.strip_edges()
		if trimmed == "":
			if not stack.is_empty():
				stack[stack.size() - 1]["accepting_block_props"] = false
			continue
		if trimmed == "::":
			if stack.is_empty():
				document.add_diagnostic("Unmatched component close", line_number)
				continue
			stack.pop_back()
			continue
		if trimmed.begins_with("::"):
			var open_node = _parse_component_open(trimmed, line_number, document)
			if open_node == null:
				continue
			if stack.is_empty():
				nodes.append(open_node)
			else:
				stack[stack.size() - 1]["accepting_block_props"] = false
				stack[stack.size() - 1]["children"].append(open_node)
			stack.append(open_node)
			continue
		if _is_prop_line(trimmed):
			if stack.is_empty():
				document.add_diagnostic("Malformed prop line outside component block", line_number)
				continue
			var current_node: Dictionary = stack[stack.size() - 1]
			if bool(current_node.get("accepting_block_props", false)):
				if _is_valid_block_prop_line(trimmed):
					if not _apply_prop_line(current_node, trimmed, line_number, document):
						document.add_diagnostic("Malformed prop line", line_number)
					continue
				if _is_malformed_initial_prop_line(trimmed):
					if not _apply_prop_line(current_node, trimmed, line_number, document):
						document.add_diagnostic("Malformed prop line", line_number)
					continue
		if not stack.is_empty() and trimmed.begins_with("= "):
			stack[stack.size() - 1]["accepting_block_props"] = false
			stack[stack.size() - 1]["children"].append({"kind": "text", "value": trimmed.substr(2).strip_edges()})
			continue
		var converted_node = _parse_markdown_line(trimmed)
		if stack.is_empty():
			nodes.append(converted_node)
		else:
			stack[stack.size() - 1]["accepting_block_props"] = false
			stack[stack.size() - 1]["children"].append(converted_node)

	for unclosed in stack:
		var opened_line := int(unclosed.get("line", -1))
		document.add_diagnostic("Unclosed component block: %s" % str(unclosed.get("name", "")), opened_line)

	document.generated_hml = _emit_hml(nodes, document.frontmatter)
	return document

func _parse_frontmatter(lines: PackedStringArray, document) -> int:
	var frontmatter: Dictionary = {}
	for i in range(1, lines.size()):
		var trimmed := lines[i].strip_edges()
		if trimmed == "---":
			document.frontmatter = frontmatter
			return i + 1
		if trimmed == "":
			continue
		var delimiter := trimmed.find(":")
		if delimiter <= 0:
			document.add_diagnostic("Malformed frontmatter line", i + 1)
			continue
		var key := trimmed.substr(0, delimiter).strip_edges()
		var value := trimmed.substr(delimiter + 1).strip_edges()
		frontmatter[key] = value
	document.frontmatter = frontmatter
	document.add_diagnostic("Invalid frontmatter fence: missing closing ---", 1)
	return lines.size()

func _parse_component_open(trimmed: String, line_number: int, document):
	var payload := trimmed.substr(2).strip_edges()
	if payload == "":
		document.add_diagnostic("Empty/invalid component name", line_number)
		return null
	var name_end := payload.find(" ")
	var component_name := payload
	var prop_text := ""
	if name_end >= 0:
		component_name = payload.substr(0, name_end)
		prop_text = payload.substr(name_end + 1).strip_edges()
	if not _is_valid_component_name(component_name):
		document.add_diagnostic("Empty/invalid component name", line_number)
		return null
	var node := {
		"kind": "component",
		"name": component_name,
		"attrs": {},
		"children": [],
		"line": line_number,
		"accepting_block_props": true
	}
	if prop_text != "":
		_parse_inline_props(node, prop_text, line_number, document)
	return node

func _parse_inline_props(node: Dictionary, prop_text: String, line_number: int, document) -> void:
	var rx := RegEx.new()
	var compile := rx.compile("([A-Za-z_][A-Za-z0-9_:-]*)\\s*=\\s*\"([^\"]*)\"")
	if compile != OK:
		document.add_diagnostic("Malformed inline props", line_number)
		return
	if _has_missing_closing_quote(prop_text):
		document.add_diagnostic("Malformed inline props: missing closing quote", line_number)
		return
	var matches = rx.search_all(prop_text)
	var consumed: Array = []
	for match in matches:
		var key := match.get_string(1)
		var value := match.get_string(2)
		node["attrs"][key] = value
		consumed.append(match.get_string(0))
	var remainder := prop_text
	for token in consumed:
		remainder = remainder.replace(token, "")
	remainder = remainder.strip_edges()
	if remainder == "":
		if matches.is_empty():
			document.add_diagnostic("Malformed inline props", line_number)
		return
	if _apply_prop_line(node, remainder, line_number, document):
		return
	if remainder.find("=") >= 0:
		document.add_diagnostic("Malformed inline props: malformed attribute syntax", line_number)
		return
	if remainder != "":
		document.add_diagnostic("Malformed inline props", line_number)

func _is_prop_line(line: String) -> bool:
	if line.find(":") < 0:
		return false
	if line.begins_with("#") or line.begins_with("::"):
		return false
	return true

func _is_valid_block_prop_line(line: String) -> bool:
	var delimiter := line.find(":")
	if delimiter <= 0:
		return false
	var key := line.substr(0, delimiter).strip_edges()
	var value := line.substr(delimiter + 1).strip_edges()
	if key == "" or value == "":
		return false
	if key == "on":
		return false
	if key.begins_with("on "):
		var event_name := key.substr(3).strip_edges()
		return _is_valid_prop_key(event_name)
	return _is_valid_prop_key(key)

func _is_malformed_initial_prop_line(line: String) -> bool:
	var delimiter := line.find(":")
	if delimiter <= 0:
		return false
	var key := line.substr(0, delimiter).strip_edges()
	var value := line.substr(delimiter + 1).strip_edges()
	if key == "" or value == "":
		return true
	if key == "on" or key.begins_with("on "):
		return not _is_valid_block_prop_line(line)
	return false

func _is_valid_prop_key(key: String) -> bool:
	if key == "":
		return false
	var rx := RegEx.new()
	if rx.compile("^[A-Za-z_][A-Za-z0-9_:-]*$") != OK:
		return false
	return rx.search(key) != null

func _apply_prop_line(node: Dictionary, line: String, line_number: int, document) -> bool:
	var delimiter := line.find(":")
	if delimiter <= 0:
		return false
	var key := line.substr(0, delimiter).strip_edges()
	var value := line.substr(delimiter + 1).strip_edges()
	if key == "" or value == "":
		if (key == "on" or key.begins_with("on ")) and value == "":
			document.add_diagnostic("Malformed inline props: event missing handler", line_number)
		return false
	if key == "on":
		document.add_diagnostic("Malformed inline props: event missing event name", line_number)
		return false
	if key.begins_with("on "):
		var event_name := key.substr(3).strip_edges()
		if event_name == "":
			document.add_diagnostic("Malformed inline props: event missing event name", line_number)
			return false
		node["attrs"]["on:%s" % event_name] = value
		return true
	node["attrs"][key] = value
	return true

func _parse_markdown_line(line: String) -> Dictionary:
	if line.begins_with("# "):
		return {
			"kind": "component",
			"name": "Title",
			"attrs": {},
			"children": [{"kind": "text", "value": line.substr(2).strip_edges()}]
		}
	if line.begins_with("## "):
		return {
			"kind": "component",
			"name": "Text",
			"attrs": {"role": "heading", "level": "2"},
			"children": [{"kind": "text", "value": line.substr(3).strip_edges()}]
		}
	return {
		"kind": "component",
		"name": "Text",
		"attrs": {},
		"children": [{"kind": "text", "value": line}]
	}

func _emit_hml(nodes: Array, frontmatter: Dictionary) -> String:
	var app_attrs := []
	for key in ["title", "target", "controller", "style"]:
		if frontmatter.has(key):
			app_attrs.append("%s=\"%s\"" % [key, _escape_xml_attr(str(frontmatter[key]))])
	var lines: Array = []
	lines.append("<App%s>" % (" " + " ".join(app_attrs) if not app_attrs.is_empty() else ""))
	lines.append("  <Column>")
	for node in nodes:
		_emit_node(node, lines, 2)
	lines.append("  </Column>")
	lines.append("</App>")
	return "\n".join(lines)

func _emit_node(node: Dictionary, out_lines: Array, depth: int) -> void:
	var indent := "  ".repeat(depth)
	if str(node.get("kind", "")) == "text":
		out_lines.append(indent + _escape_xml_text(str(node.get("value", ""))))
		return
	var name := str(node.get("name", ""))
	var attrs: Dictionary = node.get("attrs", {})
	var attr_tokens: Array = []
	for key in attrs.keys():
		attr_tokens.append("%s=\"%s\"" % [str(key), _escape_xml_attr(str(attrs[key]))])
	attr_tokens.sort()
	var attr_text := ""
	if not attr_tokens.is_empty():
		attr_text = " " + " ".join(attr_tokens)
	var children: Array = node.get("children", [])
	if children.is_empty():
		out_lines.append("%s<%s%s></%s>" % [indent, name, attr_text, name])
		return
	out_lines.append("%s<%s%s>" % [indent, name, attr_text])
	for child in children:
		_emit_node(child, out_lines, depth + 1)
	out_lines.append("%s</%s>" % [indent, name])

func _is_valid_component_name(name: String) -> bool:
	if name == "":
		return false
	var rx := RegEx.new()
	if rx.compile("^[A-Za-z][A-Za-z0-9_]*$") != OK:
		return false
	return rx.search(name) != null

func _escape_xml_text(value: String) -> String:
	return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

func _escape_xml_attr(value: String) -> String:
	return _escape_xml_text(value).replace("\"", "&quot;").replace("'", "&apos;")

func _has_missing_closing_quote(prop_text: String) -> bool:
	var eq_quote_count := 0
	for i in range(prop_text.length() - 1):
		if prop_text[i] == "=" and prop_text[i + 1] == "\"":
			eq_quote_count += 1
	var quote_count := prop_text.count("\"")
	return quote_count < (eq_quote_count * 2)
