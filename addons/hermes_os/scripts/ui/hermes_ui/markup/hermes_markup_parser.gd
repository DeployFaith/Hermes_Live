class_name HermesMarkupParser
extends RefCounted

const HermesMarkupDocument = preload("res://addons/hermes_os/scripts/ui/hermes_ui/markup/hermes_markup_document.gd")
const HermesMarkupNode = preload("res://addons/hermes_os/scripts/ui/hermes_ui/markup/hermes_markup_node.gd")

func parse_file(path: String):
	if not FileAccess.file_exists(path):
		var missing = HermesMarkupDocument.new()
		missing.source_path = path
		missing.add_error("Markup file not found", -1)
		return missing
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var unreadable = HermesMarkupDocument.new()
		unreadable.source_path = path
		unreadable.add_error("Markup file could not be opened", -1)
		return unreadable
	return parse_text(file.get_as_text(), path)

func parse_text(text: String, source_path: String = ""):
	var document = HermesMarkupDocument.new()
	document.source_path = source_path
	var parser := XMLParser.new()
	var open_result: Error = parser.open_buffer(text.to_utf8_buffer())
	if open_result != OK:
		document.add_error("Failed to open markup buffer", -1)
		return document
	var stack: Array = []
	while true:
		var read_result: Error = parser.read()
		if read_result == ERR_FILE_EOF:
			break
		if read_result != OK:
			document.add_error("Markup parse error", _safe_line(parser))
			break
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var node = HermesMarkupNode.new().configure_element(parser.get_node_name(), _extract_attributes(parser), source_path, _safe_line(parser))
				if stack.is_empty():
					if document.root == null:
						document.root = node
					else:
						document.add_error("Multiple root nodes are not supported", _safe_line(parser))
				else:
					stack[stack.size() - 1].add_child(node)
				if not parser.is_empty():
					stack.append(node)
			XMLParser.NODE_ELEMENT_END:
				if not stack.is_empty():
					stack.pop_back()
			XMLParser.NODE_TEXT:
				var value: String = parser.get_node_data()
				if value.strip_edges() != "" and not stack.is_empty():
					stack[stack.size() - 1].add_child(HermesMarkupNode.new().configure_text(value.strip_edges(), source_path, _safe_line(parser)))
	if document.root == null and document.errors.is_empty():
		document.add_error("Markup document had no root element", -1)
	return document

func _extract_attributes(parser: XMLParser) -> Dictionary:
	var attributes: Dictionary = {}
	for index in range(parser.get_attribute_count()):
		attributes[parser.get_attribute_name(index)] = parser.get_attribute_value(index)
	return attributes

func _safe_line(parser: XMLParser) -> int:
	if parser.has_method("get_current_line"):
		return int(parser.call("get_current_line"))
	return -1
