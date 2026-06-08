class_name HermesSemanticNode
extends RefCounted

var id: String = ""
var tag: String = ""
var role: String = ""
var label: String = ""
var text: String = ""
var value = null
var app_id: String = ""
var path: String = ""
var variant: String = ""
var visible: bool = true
var disabled: bool = false
var selected: bool = false
var focused: bool = false
var actions: Array[String] = []
var state: Dictionary = {}
var minimized: bool = false
var maximized: bool = false
var tiled: bool = false
var floating = null
var tileable = null
var children: Array = []

func configure(data: Dictionary) -> HermesSemanticNode:
	id = str(data.get("id", ""))
	tag = str(data.get("tag", ""))
	role = str(data.get("role", ""))
	label = str(data.get("label", ""))
	text = str(data.get("text", ""))
	value = data.get("value", null)
	app_id = str(data.get("app_id", ""))
	path = str(data.get("path", ""))
	variant = str(data.get("variant", ""))
	visible = bool(data.get("visible", true))
	disabled = bool(data.get("disabled", false))
	selected = bool(data.get("selected", false))
	focused = bool(data.get("focused", false))
	actions = _string_array(data.get("actions", []))
	state = data.get("state", {}).duplicate(true) if data.get("state", {}) is Dictionary else {}
	minimized = bool(data.get("minimized", false))
	maximized = bool(data.get("maximized", false))
	tiled = bool(data.get("tiled", false))
	floating = data.get("floating", null)
	tileable = data.get("tileable", null)
	children.clear()
	for child in data.get("children", []):
		if child != null:
			children.append(child)
	return self

func add_child(child) -> void:
	if child != null:
		children.append(child)

func to_dictionary() -> Dictionary:
	var child_dicts: Array = []
	for child in children:
		if child != null and child.has_method("to_dictionary"):
			child_dicts.append(child.to_dictionary())
	return {
		"id": id,
		"tag": tag,
		"role": role,
		"label": label,
		"text": text,
		"value": value,
		"app_id": app_id,
		"path": path,
		"variant": variant,
		"visible": visible,
		"disabled": disabled,
		"selected": selected,
		"focused": focused,
		"actions": actions.duplicate(),
		"state": state.duplicate(true),
		"minimized": minimized,
		"maximized": maximized,
		"tiled": tiled,
		"floating": floating,
		"tileable": tileable,
		"children": child_dicts
	}

func _string_array(value) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			var clean: String = str(item).strip_edges()
			if clean != "" and not result.has(clean):
				result.append(clean)
	return result
