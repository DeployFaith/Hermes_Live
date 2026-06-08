class_name HermesStyleSheet
extends RefCounted

var source_path: String = ""
var rules: Array = []
var variables: Dictionary = {}
var errors: Array = []

func add_rule(rule) -> void:
	if rule != null:
		rules.append(rule)

func add_variable(name: String, value) -> void:
	variables[name] = value

func add_error(message: String, line: int = -1) -> void:
	errors.append({"message": message, "line": line, "source_path": source_path})

func has_selector(selector: String) -> bool:
	return find_rule(selector) != null

func find_rule(selector: String):
	for rule in rules:
		if rule == null:
			continue
		for item in rule.selectors:
			if item == selector:
				return rule
	return null
