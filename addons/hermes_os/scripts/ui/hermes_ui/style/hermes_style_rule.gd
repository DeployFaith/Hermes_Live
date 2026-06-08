class_name HermesStyleRule
extends RefCounted

var selectors: Array[String] = []
var declarations: Array = []
var source_line: int = -1
var source_path: String = ""

func configure(p_selectors: Array, line: int = -1, path: String = ""):
	selectors.clear()
	for selector in p_selectors:
		selectors.append(str(selector).strip_edges())
	declarations.clear()
	source_line = line
	source_path = path
	return self

func add_declaration(declaration) -> void:
	if declaration != null:
		declarations.append(declaration)

func has_property(property_name: String) -> bool:
	return get_property(property_name) != null

func get_property(property_name: String):
	for declaration in declarations:
		if declaration != null and declaration.property_name == property_name:
			return declaration.value
	return null
