class_name HermesSemanticTree
extends RefCounted

const HermesSemanticNode = preload("res://addons/hermes_os/scripts/ui/hermes_ui/semantic/hermes_semantic_node.gd")

const DEFAULT_ROLES := {
	"App": "application",
	"Window": "window",
	"Button": "button",
	"IconButton": "button",
	"TextInput": "textbox",
	"SearchInput": "searchbox",
	"TextArea": "textbox",
	"Text": "text",
	"Title": "heading",
	"Badge": "status",
	"Card": "region",
	"ScrollView": "scrollarea",
	"FlowRow": "group",
	"Sidebar": "navigation",
	"Toolbar": "toolbar",
	"StatusBar": "status",
	"SectionHeader": "heading",
	"SettingsPage": "region",
	"SettingsSection": "region",
	"SettingsRow": "group",
	"Select": "combobox",
	"Dropdown": "combobox",
	"Slider": "slider",
	"Toggle": "checkbox",
	"List": "list",
	"ListItem": "listitem",
	"FileList": "list",
	"FileRow": "file",
	"PathBreadcrumb": "text",
	"TerminalSurface": "terminal",
	"BrowserSurface": "browser",
	"DockItem": "appbutton",
	"AppLauncher": "application",
	"DesktopItem": "desktopitem",
	"FileTile": "file",
	"FolderTile": "folder",
	"AppShortcut": "application"
}

const INTERACTIVE_ROLES := [
	"button",
	"textbox",
	"searchbox",
	"listitem",
	"option",
	"combobox",
	"slider",
	"checkbox",
	"appbutton",
	"desktopitem",
	"file",
	"folder"
]

var app_id: String = ""
var root = null
var warnings: Array[String] = []

func build(app_instance) -> HermesSemanticTree:
	root = null
	warnings.clear()
	app_id = ""
	if app_instance == null:
		warnings.append("Hermes semantic tree requested for null app instance")
		return self
	if app_instance.manifest != null:
		app_id = str(app_instance.manifest.app_id)
	if app_instance.root_element == null:
		warnings.append("Hermes semantic tree requested before root element is available")
		return self
	root = _build_element(app_instance.root_element, "/%s" % _element_segment(app_instance.root_element, 0), true)
	return self

func to_dictionary() -> Dictionary:
	return {
		"app_id": app_id,
		"root": root.to_dictionary() if root != null else {},
		"warnings": warnings.duplicate()
	}

func _build_element(element, current_path: String, ancestor_visible: bool):
	if element == null:
		return null
	if element.props.has("for"):
		return null
	var role: String = _role_for_element(element)
	var text_value: String = _text_for_element(element)
	var label_value: String = _label_for_element(element, text_value)
	var actions_value: Array[String] = _actions_for_element(element, role)
	var control: Control = element.control if element.control != null and is_instance_valid(element.control) else null
	var visible_value: bool = ancestor_visible and _visible_for_element(element, control)
	var disabled_value: bool = _disabled_for_element(element, control)
	var selected_value: bool = _boolish(_semantic_value(element, "selected", false))
	var focused_value: bool = control.has_focus() if control != null and is_instance_valid(control) else false
	var state_value: Dictionary = _state_for_element(element)
	var node = HermesSemanticNode.new().configure({
		"id": str(element.id),
		"tag": str(element.tag),
		"role": role,
		"label": label_value,
		"text": text_value,
		"value": _value_for_element(element, control),
		"app_id": app_id,
		"path": current_path,
		"variant": str(_semantic_value(element, "variant", "")),
		"visible": visible_value,
		"disabled": disabled_value,
		"selected": selected_value,
		"focused": focused_value,
		"actions": actions_value,
		"state": state_value,
		"minimized": _boolish(_semantic_value(element, "minimized", false)),
		"maximized": _boolish(_semantic_value(element, "maximized", false)),
		"tiled": _boolish(_semantic_value(element, "tiled", false)),
		"floating": _nullable_bool(element, "floating"),
		"tileable": _nullable_bool(element, "tileable")
	})
	_maybe_record_warnings(element, node)
	var index: int = 0
	for child in element.children:
		if child == null:
			continue
		var child_node = _build_element(child, current_path + "/" + _element_segment(child, index), visible_value)
		if child_node != null:
			node.add_child(child_node)
		index += 1
	return node

func _role_for_element(element) -> String:
	var explicit_role: String = str(_semantic_value(element, "role", "")).strip_edges()
	if explicit_role != "":
		return explicit_role
	var tag_name: String = str(element.tag) if element != null else ""
	if tag_name in ["Panel", "Card", "SettingsSection", "SettingsPage", "SettingsRow"] and not _has_label(element):
		return ""
	if tag_name in ["Row", "Column", "Grid"] and not _has_label(element):
		return ""
	if tag_name == "ListItem" and (element.props.has("selected") or _has_handler(element, ["on:select"])):
		return "option"
	if element != null and element.has_method("get_semantic_role"):
		var element_role: String = str(element.get_semantic_role()).strip_edges()
		if element_role != "":
			return element_role
	return str(DEFAULT_ROLES.get(tag_name, ""))

func _text_for_element(element) -> String:
	if element == null:
		return ""
	if element.node_type == "text":
		if element.control is Label:
			return (element.control as Label).text.strip_edges()
		return str(element.text_content).strip_edges()
	if element.control is Button:
		return (element.control as Button).text.strip_edges()
	if element.control is Label:
		return (element.control as Label).text.strip_edges()
	if str(element.tag) == "Badge":
		var badge_label: Label = _find_label(element.control)
		if badge_label != null:
			return badge_label.text.strip_edges()
	return str(element.get_text_content()).strip_edges()

func _label_for_element(element, text_value: String) -> String:
	var explicit_label: String = str(_semantic_value(element, "label", "")).strip_edges()
	if explicit_label != "":
		return explicit_label
	var aria_label: String = str(_semantic_value(element, "aria-label", "")).strip_edges()
	if aria_label != "":
		return aria_label
	if text_value.strip_edges() != "":
		return text_value.strip_edges()
	return ""

func _value_for_element(element, control: Control):
	if control is LineEdit:
		return (control as LineEdit).text
	if control is OptionButton:
		var dropdown := control as OptionButton
		if dropdown.selected >= 0:
			var selected_value = dropdown.get_item_metadata(dropdown.selected)
			return selected_value if selected_value != null else dropdown.get_item_text(dropdown.selected)
	if control is Range:
		return (control as Range).value
	if control is CheckBox:
		return (control as CheckBox).button_pressed
	var prop_value = _semantic_value(element, "value", null)
	if prop_value != null:
		return prop_value
	if control is TextEdit:
		return (control as TextEdit).text
	return null

func _actions_for_element(element, role: String) -> Array[String]:
	var result: Array[String] = []
	if element == null:
		return result
	var tag_name: String = str(element.tag)
	for key in element.props.keys():
		var key_text: String = str(key).strip_edges()
		if not key_text.begins_with("on:"):
			continue
		var event_name: String = key_text.substr(3).strip_edges().to_lower()
		var handler_name: String = str(element.props.get(key, "")).strip_edges()
		if tag_name == "Button" and event_name == "click" and handler_name != "":
			_add_action(result, handler_name)
		elif tag_name == "TextInput" and event_name == "input":
			_add_action(result, "input")
		elif tag_name in ["SearchInput", "TextArea"] and event_name == "input":
			_add_action(result, "input")
		elif tag_name in ["Select", "Dropdown", "Slider", "Toggle"] and event_name in ["change", "select", "value_changed", "toggled"]:
			_add_action(result, "change")
		else:
			_add_action(result, event_name)
	if tag_name in ["AppLauncher", "AppShortcut"]:
		_add_action(result, "open")
	if tag_name in ["FileTile", "FolderTile"]:
		if _has_handler(element, ["on:open", "on:click", "on:activate"]):
			_add_action(result, "open")
		if _has_handler(element, ["on:rename"]):
			_add_action(result, "rename")
		if _has_handler(element, ["on:delete", "on:remove"]):
			_add_action(result, "delete")
	if role == "button" and _has_handler(element, ["on:click"]):
		_add_action(result, "click")
	return result

func _add_action(actions_array: Array[String], action: String) -> void:
	var clean: String = action.strip_edges()
	if clean != "" and not actions_array.has(clean):
		actions_array.append(clean)

func _state_for_element(element) -> Dictionary:
	var state_value: Dictionary = {}
	if element == null:
		return state_value
	var metadata: Dictionary = element.get_semantic_metadata() if element.has_method("get_semantic_metadata") else {}
	if metadata.has("state") and metadata["state"] is Dictionary:
		state_value = metadata["state"].duplicate(true)
	for key in ["disabled", "readonly", "read-only", "multiline", "selected", "checked", "pressed", "focused", "min", "max", "value", "minimized", "maximized", "tiled", "floating", "tileable"]:
		if element.props.has(key):
			var state_key: String = "readonly" if str(key) == "read-only" else str(key)
			state_value[state_key] = element.props[key]
	return state_value

func _visible_for_element(element, control: Control) -> bool:
	if _boolish(_semantic_value(element, "hidden", false)):
		return false
	if control != null and is_instance_valid(control):
		if control.is_inside_tree():
			return control.is_visible_in_tree()
		return control.visible
	return true

func _disabled_for_element(element, control: Control) -> bool:
	if control is Button:
		return (control as Button).disabled
	if control is LineEdit:
		return not (control as LineEdit).editable
	if control is TextEdit:
		if not (control as TextEdit).editable:
			return true
		return _boolish(_semantic_value(element, "disabled", false)) or _boolish(_semantic_value(element, "readonly", false)) or _boolish(_semantic_value(element, "read-only", false))
	if control is Range:
		return not (control as Range).editable
	return _boolish(_semantic_value(element, "disabled", false))

func _semantic_value(element, key: String, default_value = null):
	if element == null:
		return default_value
	var metadata: Dictionary = element.get_semantic_metadata() if element.has_method("get_semantic_metadata") else {}
	if metadata.has(key):
		return metadata[key]
	if element.props.has(key):
		return element.props[key]
	return default_value

func _nullable_bool(element, key: String):
	var value = _semantic_value(element, key, null)
	if value == null:
		return null
	return _boolish(value)

func _has_label(element) -> bool:
	if element == null:
		return false
	return str(_semantic_value(element, "label", "")).strip_edges() != "" or str(element.get_text_content()).strip_edges() != ""

func _has_handler(element, keys: Array) -> bool:
	if element == null:
		return false
	for key in keys:
		if str(element.props.get(str(key), "")).strip_edges() != "":
			return true
	return false

func _maybe_record_warnings(element, semantic_node) -> void:
	if element == null or semantic_node == null:
		return
	var interactive: bool = INTERACTIVE_ROLES.has(str(semantic_node.role)) or not semantic_node.actions.is_empty()
	if not interactive:
		return
	var tag_name: String = str(element.tag)
	var location: String = semantic_node.path
	if str(semantic_node.id).strip_edges() == "":
		warnings.append("Interactive <%s> at %s has no id" % [tag_name, location])
	if str(semantic_node.label).strip_edges() == "" and str(semantic_node.text).strip_edges() == "":
		warnings.append("Interactive <%s> at %s has no label or text" % [tag_name, location])

func _element_segment(element, index: int) -> String:
	if element == null:
		return "node[%d]" % index
	var tag_name: String = str(element.tag) if str(element.tag) != "" else str(element.node_type)
	var element_id: String = str(element.id).strip_edges()
	if element_id != "":
		return "%s#%s" % [tag_name, element_id]
	return "%s[%d]" % [tag_name, index]

func _find_label(node: Node) -> Label:
	if node == null:
		return null
	if node is Label:
		return node as Label
	for child in node.get_children():
		var found: Label = _find_label(child)
		if found != null:
			return found
	return null

func _boolish(value) -> bool:
	if value is bool:
		return bool(value)
	if value == null:
		return false
	var text_value: String = str(value).strip_edges().to_lower()
	return text_value == "true" or text_value == "1" or text_value == "yes" or text_value == "on"
