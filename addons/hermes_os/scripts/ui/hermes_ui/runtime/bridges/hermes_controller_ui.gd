class_name HermesControllerUI
extends RefCounted

var _app = null
var _root: Control = null

func setup(app_instance) -> HermesControllerUI:
	_app = app_instance
	_root = app_instance.root_control if app_instance != null else null
	return self

func teardown() -> void:
	_app = null
	_root = null

func by_id(target_id: String) -> Control:
	var element = _element_by_id(target_id)
	if element != null and element.control != null and is_instance_valid(element.control):
		return element.control as Control
	if _root != null and is_instance_valid(_root):
		return _control_by_meta_id(_root, target_id)
	return null

func get_value(target_id: String):
	var control: Control = by_id(target_id)
	if control == null:
		return null
	if control is LineEdit:
		return (control as LineEdit).text
	if control is TextEdit:
		return (control as TextEdit).text
	if control is Label:
		return (control as Label).text
	if control is Button and not (control is OptionButton) and not (control is CheckBox):
		return (control as Button).text
	if control is OptionButton:
		var dropdown: OptionButton = control as OptionButton
		if dropdown.selected >= 0:
			var selected_value = dropdown.get_item_metadata(dropdown.selected)
			return selected_value if selected_value != null else dropdown.get_item_text(dropdown.selected)
	if control is CheckBox:
		return (control as CheckBox).button_pressed
	if control is BaseButton:
		return (control as BaseButton).button_pressed
	if control is Range:
		return (control as Range).value
	if control.has_meta("value"):
		return control.get_meta("value")
	return null

func set_value(target_id: String, value) -> bool:
	var control: Control = by_id(target_id)
	if control == null:
		return false
	var applied: bool = true
	if control is LineEdit:
		(control as LineEdit).text = str(value)
	elif control is TextEdit:
		(control as TextEdit).text = str(value)
	elif control is Label:
		(control as Label).text = str(value)
	elif control is Button and not (control is OptionButton) and not (control is CheckBox):
		(control as Button).text = str(value)
	elif control is OptionButton:
		_select_option_value(control as OptionButton, value)
	elif control is CheckBox:
		(control as CheckBox).button_pressed = _boolish(value)
	elif control is BaseButton:
		(control as BaseButton).button_pressed = _boolish(value)
	elif control is Range:
		(control as Range).value = float(value)
	else:
		control.set_meta("value", value)
		applied = control.has_meta("value")
	if applied:
		var element = _element_by_id(target_id)
		if element != null:
			element.props["value"] = value
	return applied

func focus(target_id: String) -> bool:
	var control: Control = by_id(target_id)
	if control == null or not is_instance_valid(control):
		return false
	control.grab_focus()
	return true

func add_class(target_id: String, class_value: String) -> bool:
	var element = _element_by_id(target_id)
	var clean: String = class_value.strip_edges()
	if element == null or clean == "":
		return false
	if not element.classes.has(clean):
		element.classes.append(clean)
	_apply_styles()
	return true

func remove_class(target_id: String, class_value: String) -> bool:
	var element = _element_by_id(target_id)
	var clean: String = class_value.strip_edges()
	if element == null or clean == "":
		return false
	element.classes.erase(clean)
	_apply_styles()
	return true

func set_prop(target_id: String, prop_name: String, value) -> bool:
	var element = _element_by_id(target_id)
	var clean: String = prop_name.strip_edges()
	if element == null or clean == "":
		return false
	element.props[clean] = value
	if _app != null and _app.binding_engine != null and _app.binding_engine.has_method("_apply_property_to_control"):
		_app.binding_engine.call("_apply_property_to_control", element, clean, value)
	else:
		_apply_prop_direct(element.control, clean, value)
	_apply_styles()
	return true

func invoke(target_id: String) -> bool:
	var control: Control = by_id(target_id)
	if control == null:
		return false
	if control is Button:
		var button := control as Button
		if button.disabled:
			return false
		button.emit_signal("pressed")
		return true
	if control is LineEdit:
		var input := control as LineEdit
		input.emit_signal("text_submitted", input.text)
		return true
	if control is OptionButton:
		var dropdown := control as OptionButton
		if dropdown.selected >= 0:
			dropdown.emit_signal("item_selected", dropdown.selected)
			return true
	if control is BaseButton:
		(control as BaseButton).emit_signal("pressed")
		return true
	return false

func _element_by_id(target_id: String):
	if _app == null or target_id.strip_edges() == "":
		return null
	if _app.has_method("find_element_by_id"):
		return _app.find_element_by_id(target_id)
	return null

func _control_by_meta_id(node: Node, target_id: String) -> Control:
	if node is Control and node.has_meta("hermes_id") and str(node.get_meta("hermes_id", "")) == target_id:
		return node as Control
	for child in node.get_children():
		var found: Control = _control_by_meta_id(child, target_id)
		if found != null:
			return found
	return null

func _apply_styles() -> void:
	if _app == null or _app.root_element == null or _app.render_context == null:
		return
	var context = _app.render_context
	if context.style_resolver != null and not context.stylesheets.is_empty():
		context.style_resolver.apply_tree(_app.root_element, context.stylesheets)

func _select_option_value(dropdown: OptionButton, value) -> void:
	if dropdown == null:
		return
	var desired: String = str(value)
	for i in dropdown.item_count:
		if str(dropdown.get_item_metadata(i)) == desired or dropdown.get_item_text(i) == desired:
			dropdown.select(i)
			return

func _apply_prop_direct(control: Control, prop_name: String, value) -> void:
	if control == null:
		return
	match prop_name:
		"disabled", "readonly", "read-only":
			if control is Button:
				(control as Button).disabled = _boolish(value)
			elif control is LineEdit:
				(control as LineEdit).editable = not _boolish(value)
			elif control is TextEdit:
				(control as TextEdit).editable = not _boolish(value)
		"value":
			set_value(str(control.get_meta("hermes_id", "")), value)
		"hidden":
			control.visible = not _boolish(value)
		"visible":
			control.visible = _boolish(value)
		_:
			control.set_meta(prop_name, value)

func _boolish(value) -> bool:
	if value is bool:
		return bool(value)
	var text: String = str(value).strip_edges().to_lower()
	return text == "true" or text == "1" or text == "yes" or text == "on"
