class_name HermesMarkupNode
extends RefCounted

const HermesElementInstance = preload("res://addons/hermes_os/scripts/ui/hermes_ui/render/hermes_element_instance.gd")

var node_type: String = "element"
var tag: String = ""
var attributes: Dictionary = {}
var text_content: String = ""
var children: Array = []
var parent = null
var source_path: String = ""
var source_line: int = -1

func configure_element(tag_name: String, attrs: Dictionary = {}, path: String = "", line: int = -1):
	node_type = "element"
	tag = tag_name
	attributes = attrs.duplicate(true)
	source_path = path
	source_line = line
	children.clear()
	return self

func configure_text(value: String, path: String = "", line: int = -1):
	node_type = "text"
	text_content = value
	source_path = path
	source_line = line
	children.clear()
	return self

func add_child(child) -> void:
	if child == null:
		return
	child.parent = self
	children.append(child)

func free_tree() -> void:
	for child in children:
		if child != null:
			child.free_tree()
	children.clear()
	parent = null

func to_element_instance():
	if node_type == "text":
		return HermesElementInstance.new().configure_text(text_content)
	var element = HermesElementInstance.new().configure_node(tag, attributes, [])
	element.source_file = source_path
	element.source_line = source_line
	for child in children:
		element.add_child(child.to_element_instance())
	return element
