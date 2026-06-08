class_name HermesElementInstance
extends RefCounted

var node_type: String = "element"
var tag: String = ""
var id: String = ""
var classes: Array[String] = []
var props: Dictionary = {}
var text_content: String = ""
var parent = null
var children: Array = []
var control: Control = null
var computed_style = null
var pseudo_states: Dictionary = {}
var semantic_metadata: Dictionary = {}
var source_file: String = ""
var source_line: int = -1

func configure_node(tag_name: String, attributes: Dictionary = {}, child_nodes: Array = []):
	node_type = "element"
	tag = tag_name
	props = attributes.duplicate(true)
	computed_style = null
	pseudo_states = {}
	semantic_metadata = {}
	id = str(attributes.get("id", "")).strip_edges()
	classes.clear()
	var class_value: String = str(attributes.get("class", "")).strip_edges()
	if class_value != "":
		for item in class_value.split(" ", false):
			var clean: String = item.strip_edges()
			if clean != "":
				classes.append(clean)
	children.clear()
	for child in child_nodes:
		add_child(child)
	return self

func configure_text(value: String):
	node_type = "text"
	text_content = value
	computed_style = null
	pseudo_states = {}
	semantic_metadata = {}
	children.clear()
	return self

func add_child(child) -> void:
	if child == null:
		return
	child.parent = self
	children.append(child)

func get_text_content() -> String:
	if node_type == "text":
		return text_content
	var parts: Array[String] = []
	for child in children:
		if child != null and child.node_type == "text":
			parts.append(str(child.text_content))
	return "".join(parts).strip_edges()

func clear_control_tree() -> void:
	control = null
	computed_style = null
	for child in children:
		if child != null:
			child.clear_control_tree()

func set_pseudo_state(name: String, active: bool) -> void:
	pseudo_states[name.strip_edges().to_lower()] = active

func is_pseudo_state(name: String) -> bool:
	return bool(pseudo_states.get(name.strip_edges().to_lower(), false))

func set_semantic_metadata(metadata: Dictionary) -> void:
	semantic_metadata = metadata.duplicate(true)

func merge_semantic_metadata(metadata: Dictionary) -> void:
	for key in metadata.keys():
		semantic_metadata[key] = metadata[key]

func get_semantic_metadata() -> Dictionary:
	return semantic_metadata.duplicate(true)

func get_semantic_role() -> String:
	return str(semantic_metadata.get("role", props.get("role", ""))).strip_edges()

func free_tree() -> void:
	for child in children:
		if child != null:
			child.free_tree()
	children.clear()
	parent = null
	control = null
	computed_style = null
	pseudo_states.clear()
	semantic_metadata.clear()
