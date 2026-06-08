class_name HermesMarkupDocument
extends RefCounted

var source_path: String = ""
var root = null
var errors: Array = []

func add_error(message: String, line: int = -1) -> void:
	var error_script = load("res://addons/hermes_os/scripts/ui/hermes_ui/markup/hermes_markup_error.gd")
	errors.append(error_script.new(message, source_path, line))

func free_tree() -> void:
	if root != null:
		root.free_tree()
		root = null
	errors.clear()
