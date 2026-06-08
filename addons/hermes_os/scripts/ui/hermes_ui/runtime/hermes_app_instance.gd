class_name HermesAppInstance
extends RefCounted

const HermesSemanticTree = preload("res://addons/hermes_os/scripts/ui/hermes_ui/semantic/hermes_semantic_tree.gd")

var manifest = null
var controller = null
var root_control: Control = null
var mounted_host: Control = null
var root_element = null
var render_context = null
var renderer = null
var binding_engine = null
var state = null
var event_bus = null

func is_mounted() -> bool:
	return root_control != null and is_instance_valid(root_control) and mounted_host != null and is_instance_valid(mounted_host)

func mount(root: Control, host: Control) -> void:
	root_control = root
	mounted_host = host

func unmount() -> void:
	root_control = null
	mounted_host = null
	root_element = null
	render_context = null
	renderer = null
	binding_engine = null

func find_element_by_id(target_id: String):
	if renderer == null or root_element == null:
		return null
	return renderer.find_by_id(root_element, target_id)

func get_semantic_tree() -> Dictionary:
	return HermesSemanticTree.new().build(self).to_dictionary()
