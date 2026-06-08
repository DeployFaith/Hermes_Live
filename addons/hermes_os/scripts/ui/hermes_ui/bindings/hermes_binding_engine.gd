class_name HermesBindingEngine
extends RefCounted

const HermesBindingExpression = preload("res://addons/hermes_os/scripts/ui/hermes_ui/bindings/hermes_binding_expression.gd")
const HermesEvent = preload("res://addons/hermes_os/scripts/ui/hermes_ui/events/hermes_event.gd")
const HermesElementInstance = preload("res://addons/hermes_os/scripts/ui/hermes_ui/render/hermes_element_instance.gd")

var app = null
var state = null
var controller = null
var events = null
var render_context = null
var stylesheets: Array = []

var _text_bindings: Array = []
var _prop_bindings: Array = []
var _model_bindings: Array = []
var _repeat_bindings: Array = []
var _refreshing: bool = false
var _suppress_input: Dictionary = {}

func bind_app(app_instance, context, app_stylesheets: Array = []) -> void:
	teardown()
	app = app_instance
	render_context = context
	stylesheets = app_stylesheets.duplicate()
	state = app_instance.state if app_instance != null else null
	controller = app_instance.controller if app_instance != null else null
	events = app_instance.event_bus if app_instance != null else null
	_text_bindings.clear()
	_prop_bindings.clear()
	_model_bindings.clear()
	_repeat_bindings.clear()
	_suppress_input.clear()
	if state != null:
		var batch_change := Callable(self, "_on_state_batch_changed")
		if not state.state_batch_changed.is_connected(batch_change):
			state.state_batch_changed.connect(batch_change)
	_index_tree(app_instance.root_element if app_instance != null else null)
	_apply_all()

func teardown() -> void:
	if state != null:
		var batch_change := Callable(self, "_on_state_batch_changed")
		if state.state_batch_changed.is_connected(batch_change):
			state.state_batch_changed.disconnect(batch_change)
	_text_bindings.clear()
	_prop_bindings.clear()
	_model_bindings.clear()
	_repeat_bindings.clear()
	_suppress_input.clear()
	stylesheets.clear()
	app = null
	state = null
	controller = null
	events = null
	render_context = null

func _index_tree(element) -> void:
	if element == null:
		return
	if element.node_type != "text" and element.props.has("for"):
		var repeat_spec: Dictionary = _parse_repeat_spec(str(element.props.get("for", "")))
		if not repeat_spec.is_empty():
			_repeat_bindings.append({
				"template": element,
				"parent": element.parent,
				"item_var": str(repeat_spec.get("item_var", "")),
				"collection": str(repeat_spec.get("collection", "")),
				"key_expression": HermesBindingExpression.new().configure(str(element.props.get("key", ""))) if str(element.props.get("key", "")).strip_edges() != "" else null
			})
		return
	if element.node_type == "text":
		if HermesBindingExpression.has_binding(str(element.text_content)):
			_text_bindings.append({
				"kind": "text_node",
				"element": element,
				"expression": HermesBindingExpression.new().configure(str(element.text_content))
			})
		return
	var own_text: String = _direct_text_template(element)
	if own_text != "" and HermesBindingExpression.has_binding(own_text) and element.tag in ["Text", "Title", "Button", "Badge", "ListItem", "StatusBar", "SectionHeader"]:
		_text_bindings.append({
			"kind": "element_text",
			"element": element,
			"expression": HermesBindingExpression.new().configure(own_text)
		})
	for prop_name in element.props.keys():
		var value = element.props[prop_name]
		if str(prop_name) == "model":
			_model_bindings.append({"element": element, "key": str(value)})
			continue
		if str(prop_name).begins_with("on:"):
			continue
		if value is String and HermesBindingExpression.has_binding(str(value)):
			_prop_bindings.append({
				"element": element,
				"property": str(prop_name),
				"expression": HermesBindingExpression.new().configure(str(value))
			})
	_connect_events_for_element(element)
	for child in element.children:
		_index_tree(child)

func _connect_events_for_element(element) -> void:
	if element == null or element.control == null:
		return
	if element.control is OptionButton:
		var dropdown := element.control as OptionButton
		var dropdown_has_model: bool = str(element.props.get("model", "")).strip_edges() != ""
		var change_method: String = str(element.props.get("on:change", element.props.get("on:select", ""))).strip_edges()
		if dropdown_has_model or change_method != "":
			var dropdown_cb := Callable(self, "_on_option_selected").bind(element, change_method)
			if not dropdown.item_selected.is_connected(dropdown_cb):
				dropdown.item_selected.connect(dropdown_cb)
	if element.control is Range:
		var range := element.control as Range
		var range_has_model: bool = str(element.props.get("model", "")).strip_edges() != ""
		var range_method: String = str(element.props.get("on:change", element.props.get("on:value_changed", ""))).strip_edges()
		if range_has_model or range_method != "":
			var range_cb := Callable(self, "_on_range_changed").bind(element, range_method)
			if not range.value_changed.is_connected(range_cb):
				range.value_changed.connect(range_cb)
	if element.control is CheckBox:
		var toggle := element.control as CheckBox
		var toggle_has_model: bool = str(element.props.get("model", "")).strip_edges() != ""
		var toggle_method: String = str(element.props.get("on:change", element.props.get("on:toggled", ""))).strip_edges()
		if toggle_has_model or toggle_method != "":
			var toggle_cb := Callable(self, "_on_toggle_changed").bind(element, toggle_method)
			if not toggle.toggled.is_connected(toggle_cb):
				toggle.toggled.connect(toggle_cb)
	if element.control is Button:
		var button := element.control as Button
		if str(element.tag) in ["ListItem", "FileRow"]:
			var list_click_method: String = str(element.props.get("on:click", "")).strip_edges()
			var list_select_method: String = str(element.props.get("on:select", "")).strip_edges()
			var list_open_method: String = str(element.props.get("on:open", element.props.get("on:activate", element.props.get("on:double_click", element.props.get("on:double-click", ""))))).strip_edges()
			if list_click_method != "" or list_select_method != "":
				var list_cb := Callable(self, "_on_list_item_pressed").bind(element, list_click_method, list_select_method)
				if not button.pressed.is_connected(list_cb):
					button.pressed.connect(list_cb)
			if list_open_method != "":
				var open_cb := Callable(self, "_on_list_item_gui_input").bind(element, list_open_method)
				if not button.gui_input.is_connected(open_cb):
					button.gui_input.connect(open_cb)
		else:
			var click_method: String = str(element.props.get("on:click", "")).strip_edges()
			if click_method != "":
				var click_cb := Callable(self, "_on_button_pressed").bind(element, click_method)
				if not button.pressed.is_connected(click_cb):
					button.pressed.connect(click_cb)
	if element.control is TextEdit:
		var area := element.control as TextEdit
		var has_model: bool = str(element.props.get("model", "")).strip_edges() != ""
		var input_method: String = str(element.props.get("on:input", "")).strip_edges()
		if has_model or input_method != "":
			var area_input_cb := Callable(self, "_on_text_edit_changed").bind(element, input_method)
			if not area.text_changed.is_connected(area_input_cb):
				area.text_changed.connect(area_input_cb)
	if element.control is LineEdit:
		var input := element.control as LineEdit
		var has_model: bool = str(element.props.get("model", "")).strip_edges() != ""
		var input_method: String = str(element.props.get("on:input", "")).strip_edges()
		if has_model or input_method != "":
			var input_cb := Callable(self, "_on_text_changed").bind(element, input_method)
			if not input.text_changed.is_connected(input_cb):
				input.text_changed.connect(input_cb)
		var submit_method: String = str(element.props.get("on:submit", "")).strip_edges()
		if submit_method != "":
			var submit_cb := Callable(self, "_on_text_submitted").bind(element, submit_method)
			if not input.text_submitted.is_connected(submit_cb):
				input.text_submitted.connect(submit_cb)
		var focus_method: String = str(element.props.get("on:focus", "")).strip_edges()
		if focus_method != "":
			var focus_cb := Callable(self, "_on_focus_event").bind(element, focus_method, "focus")
			if not input.focus_entered.is_connected(focus_cb):
				input.focus_entered.connect(focus_cb)
		var blur_method: String = str(element.props.get("on:blur", "")).strip_edges()
		if blur_method != "":
			var blur_cb := Callable(self, "_on_focus_event").bind(element, blur_method, "blur")
			if not input.focus_exited.is_connected(blur_cb):
				input.focus_exited.connect(blur_cb)

func _on_state_changed(key_path: String, _value) -> void:
	var keys := PackedStringArray([key_path])
	_apply_all(_state_change_requires_repeat_rebuild(keys), keys)

func _on_state_batch_changed(keys: PackedStringArray) -> void:
	_apply_all(_state_change_requires_repeat_rebuild(keys), keys)

func _apply_all(rebuild_repeats: bool = true, changed_keys: PackedStringArray = PackedStringArray()) -> void:
	if _refreshing:
		return
	_refreshing = true
	if rebuild_repeats:
		_apply_repeats()
	else:
		_apply_generated_repeat_bindings(changed_keys)
	for binding in _text_bindings:
		_apply_text_binding(binding)
	for binding in _prop_bindings:
		_apply_prop_binding(binding)
	for binding in _model_bindings:
		_apply_model_binding(binding)
	if rebuild_repeats and app != null and app.root_element != null and render_context != null and render_context.style_resolver != null and not stylesheets.is_empty():
		render_context.style_resolver.apply_tree(app.root_element, stylesheets)
	_refreshing = false

func _state_change_requires_repeat_rebuild(keys: PackedStringArray) -> bool:
	if _repeat_bindings.is_empty():
		return false
	if keys.is_empty():
		return true
	for binding in _repeat_bindings:
		var collection: String = str(binding.get("collection", "")).strip_edges()
		if collection == "":
			continue
		for key in keys:
			var changed: String = str(key)
			if changed == collection or changed.begins_with(collection + "."):
				return true
	return false

func _apply_text_binding(binding: Dictionary) -> void:
	var element = binding.get("element", null)
	var expression = binding.get("expression", null)
	if element == null or expression == null:
		return
	var value = expression.evaluate(state)
	match str(binding.get("kind", "")):
		"text_node":
			if element.control is Label:
				(element.control as Label).text = str(value)
		"element_text":
			_apply_text_to_control(element, str(value))

func _apply_prop_binding(binding: Dictionary) -> void:
	var element = binding.get("element", null)
	var expression = binding.get("expression", null)
	var property_name: String = str(binding.get("property", ""))
	if element == null or expression == null or property_name == "":
		return
	var value = expression.evaluate(state)
	element.props[property_name] = value
	_apply_property_to_control(element, property_name, value)

func _apply_model_binding(binding: Dictionary) -> void:
	var element = binding.get("element", null)
	var key_path: String = str(binding.get("key", "")).strip_edges()
	if element == null or key_path == "":
		return
	var value = state.get_value(key_path, "") if state != null else ""
	element.props["value"] = value
	if element.control is LineEdit:
		var input := element.control as LineEdit
		var desired: String = str(value)
		if input.text != desired:
			_suppress_input[key_path] = true
			input.text = desired
			_suppress_input.erase(key_path)
	elif element.control is TextEdit:
		var area := element.control as TextEdit
		var desired_area_text: String = str(value)
		if area.text != desired_area_text:
			_suppress_input[key_path] = true
			area.text = desired_area_text
			_suppress_input.erase(key_path)
	elif element.control is OptionButton:
		_suppress_input[key_path] = true
		_select_option_value(element.control as OptionButton, value)
		_suppress_input.erase(key_path)
	elif element.control is Range:
		var range := element.control as Range
		var desired_number: float = str(value).to_float()
		if not is_equal_approx(range.value, desired_number):
			_suppress_input[key_path] = true
			range.value = desired_number
			_suppress_input.erase(key_path)
	elif element.control is CheckBox:
		var toggle := element.control as CheckBox
		var desired_checked: bool = _boolish(value)
		if toggle.button_pressed != desired_checked:
			_suppress_input[key_path] = true
			toggle.button_pressed = desired_checked
			_suppress_input.erase(key_path)

func _apply_text_to_control(element, value: String) -> void:
	if element == null or element.control == null:
		return
	if element.control is Label:
		(element.control as Label).text = value
		return
	if element.control is Button:
		(element.control as Button).text = value
		return
	if str(element.tag) in ["Badge", "StatusBar", "SectionHeader"]:
		var label: Label = _find_label(element.control)
		if label != null:
			label.text = value

func _apply_property_to_control(element, property_name: String, value) -> void:
	if element == null or element.control == null:
		return
	match property_name:
		"disabled", "readonly", "read-only":
			var disabled: bool = _boolish(value)
			if property_name == "disabled":
				element.set_pseudo_state("disabled", disabled)
			if element.control is Button:
				(element.control as Button).disabled = disabled
			elif element.control is LineEdit:
				(element.control as LineEdit).editable = not disabled
			elif element.control is TextEdit:
				(element.control as TextEdit).editable = not disabled
			elif element.control is Range:
				(element.control as Range).editable = not disabled
			_apply_style_to_element(element)
		"variant":
			if str(element.tag) == "Badge":
				_apply_badge_variant(element.control, str(value))
			elif element.control is Button:
				_apply_button_variant(element.control as Button, str(value))
		"value":
			element.props["value"] = value
			if element.control is LineEdit:
				var input := element.control as LineEdit
				var desired: String = str(value)
				if input.text != desired:
					input.text = desired
			elif element.control is TextEdit:
				var area := element.control as TextEdit
				var desired_area_text: String = str(value)
				if area.text != desired_area_text:
					area.text = desired_area_text
			elif element.control is OptionButton:
				_select_option_value(element.control as OptionButton, value)
			elif element.control is Range:
				(element.control as Range).value = str(value).to_float()
			elif element.control is CheckBox:
				(element.control as CheckBox).button_pressed = _boolish(value)
		"checked", "pressed":
			var checked: bool = _boolish(value)
			element.props["checked"] = checked
			element.props["value"] = checked
			element.set_pseudo_state("checked", checked)
			if element.control is CheckBox:
				(element.control as CheckBox).button_pressed = checked
		"selected":
			var selected: bool = _boolish(value)
			element.set_pseudo_state("selected", selected)
			element.props["selected"] = selected
			_apply_style_to_element(element)
		"hidden":
			element.control.visible = not _boolish(value)
		"path":
			if element.control is Label:
				(element.control as Label).text = str(value)
			elif element.control is LineEdit:
				(element.control as LineEdit).text = str(value)
		_:
			pass

func _apply_badge_variant(control: Control, variant: String) -> void:
	if control == null or render_context == null or render_context.theme == null:
		return
	control.add_theme_stylebox_override("panel", render_context.theme.badge_style(variant))
	var badge_label: Label = _find_label(control)
	if badge_label != null:
		badge_label.add_theme_color_override("font_color", render_context.theme.kind_text_color(variant))

func _apply_button_variant(control: Button, variant: String) -> void:
	if control == null or render_context == null or render_context.theme == null:
		return
	var normal_style: StyleBoxFlat = render_context.theme.button_style(variant, "normal")
	control.add_theme_stylebox_override("normal", normal_style)
	control.add_theme_stylebox_override("hover", render_context.theme.button_style(variant, "hover"))
	control.add_theme_stylebox_override("pressed", render_context.theme.button_style(variant, "pressed"))
	control.add_theme_stylebox_override("disabled", render_context.theme.button_style(variant, "disabled"))
	control.add_theme_stylebox_override("focus", render_context.theme.button_style(variant, "focused"))
	if normal_style != null and normal_style.has_meta("hermes_ui_text_color"):
		var color_value = normal_style.get_meta("hermes_ui_text_color")
		if color_value is Color:
			control.add_theme_color_override("font_color", color_value)
			control.add_theme_color_override("font_hover_color", color_value)
			control.add_theme_color_override("font_pressed_color", color_value)

func _apply_style_to_element(element) -> void:
	if element == null or render_context == null or render_context.style_resolver == null or stylesheets.is_empty():
		return
	render_context.style_resolver.apply_tree(element, stylesheets)

func _on_button_pressed(element, method_name: String) -> void:
	var button_text: String = ""
	if element != null and element.control is Button:
		button_text = (element.control as Button).text
	_dispatch_event("click", element, button_text, method_name, null)

func _on_list_item_pressed(element, click_method: String, select_method: String) -> void:
	var value = _event_value_for_element(element)
	if click_method != "":
		_dispatch_event("click", element, value, click_method, null)
	if select_method != "":
		_dispatch_event("select", element, value, select_method, null)

func _on_list_item_gui_input(event: InputEvent, element, open_method: String) -> void:
	if open_method == "" or not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.double_click:
		return
	_dispatch_event("open", element, _event_value_for_element(element), open_method, event)

func _event_value_for_element(element):
	if element == null:
		return null
	if element.props.has("value"):
		return element.props.get("value")
	if str(element.id).strip_edges() != "":
		return str(element.id)
	if element.control is Button:
		return (element.control as Button).text
	return null

func _on_option_selected(index: int, element, method_name: String) -> void:
	var value = ""
	if element != null and element.control is OptionButton:
		var dropdown := element.control as OptionButton
		value = dropdown.get_item_metadata(index)
		if value == null:
			value = dropdown.get_item_text(index)
	var key_path: String = str(element.props.get("model", "")).strip_edges() if element != null else ""
	if key_path != "" and not _suppress_input.has(key_path) and state != null:
		state.set(key_path, value)
	if element != null:
		element.props["value"] = value
		element.merge_semantic_metadata({"value": value})
	_dispatch_event("change", element, value, method_name, index)

func _on_range_changed(value: float, element, method_name: String) -> void:
	var key_path: String = str(element.props.get("model", "")).strip_edges() if element != null else ""
	if key_path != "" and not _suppress_input.has(key_path) and state != null:
		state.set(key_path, value)
	if element != null:
		element.props["value"] = value
		element.merge_semantic_metadata({"value": value})
	_dispatch_event("change", element, value, method_name, value)

func _on_toggle_changed(pressed: bool, element, method_name: String) -> void:
	var key_path: String = str(element.props.get("model", "")).strip_edges() if element != null else ""
	if key_path != "" and not _suppress_input.has(key_path) and state != null:
		state.set(key_path, pressed)
	if element != null:
		element.props["checked"] = pressed
		element.props["value"] = pressed
		element.set_pseudo_state("checked", pressed)
		element.merge_semantic_metadata({"value": pressed, "state": {"checked": pressed, "disabled": _boolish(element.props.get("disabled", false))}})
	_dispatch_event("change", element, pressed, method_name, pressed)

func _on_text_changed(value: String, element, method_name: String) -> void:
	var key_path: String = str(element.props.get("model", "")).strip_edges() if element != null else ""
	if key_path != "" and not _suppress_input.has(key_path) and state != null:
		state.set(key_path, value)
	_dispatch_event("input", element, value, method_name, value)

func _on_text_edit_changed(element, method_name: String) -> void:
	var value: String = ""
	if element != null and element.control is TextEdit:
		value = (element.control as TextEdit).text
	var key_path: String = str(element.props.get("model", "")).strip_edges() if element != null else ""
	if key_path != "" and not _suppress_input.has(key_path) and state != null:
		state.set(key_path, value)
	_dispatch_event("input", element, value, method_name, value)

func _on_text_submitted(value: String, element, method_name: String) -> void:
	_dispatch_event("submit", element, value, method_name, value)

func _on_focus_event(element, method_name: String, event_type: String) -> void:
	_dispatch_event(event_type, element, null, method_name, null)

func _dispatch_event(event_type: String, element, value, method_name: String, raw_event) -> void:
	var event = HermesEvent.new().configure(event_type, element, value, app, raw_event)
	if events != null:
		events.emit_event(event)
	if controller != null and method_name != "" and controller.has_method(method_name):
		controller.call(method_name, event)

func _apply_repeats() -> void:
	if _repeat_bindings.is_empty() or app == null or app.renderer == null:
		return
	for binding in _repeat_bindings:
		var template = binding.get("template", null)
		var parent = binding.get("parent", null)
		if template == null or parent == null or parent.control == null:
			continue
		_clear_generated_repeat(parent, template)
		var collection_value = state.get_value(str(binding.get("collection", "")), []) if state != null else []
		if not (collection_value is Array):
			continue
		var template_index: int = parent.children.find(template)
		if template_index < 0:
			template_index = parent.children.size()
		var insert_index: int = template_index + 1
		var item_var: String = str(binding.get("item_var", "item"))
		var offset: int = 0
		for item in collection_value:
			var scope: Dictionary = _repeat_scope(item_var, item)
			var clone = _clone_for_repeat(template, scope, item_var, item)
			if clone == null:
				continue
			clone.props["__repeat_generated"] = true
			clone.props["__repeat_source_id"] = str(template.get_instance_id())
			_set_repeat_metadata_recursive(clone, str(template.get_instance_id()), item_var, item)
			var key_expression = binding.get("key_expression", null)
			if key_expression != null:
				clone.props["key"] = key_expression.evaluate(scope)
			clone.parent = parent
			parent.children.insert(insert_index + offset, clone)
			offset += 1
			var control: Control = app.renderer.render_element(clone)
			if control != null:
				render_context.ui.add(parent.control, control)
				_connect_generated_tree(clone)

func _clear_generated_repeat(parent, template) -> void:
	if parent == null or template == null:
		return
	var source_id: String = str(template.get_instance_id())
	for index in range(parent.children.size() - 1, -1, -1):
		var child = parent.children[index]
		if child == null or not bool(child.props.get("__repeat_generated", false)) or str(child.props.get("__repeat_source_id", "")) != source_id:
			continue
		if child.control != null and is_instance_valid(child.control):
			var control_parent: Node = child.control.get_parent()
			if control_parent != null:
				control_parent.remove_child(child.control)
			child.control.queue_free()
		parent.children.remove_at(index)
		child.free_tree()

func _repeat_scope(item_var: String, item) -> Dictionary:
	var scope: Dictionary = state.to_dictionary() if state != null and state.has_method("to_dictionary") else {}
	scope[item_var] = item
	return scope

func _set_repeat_metadata_recursive(element, source_id: String, item_var: String, item) -> void:
	if element == null:
		return
	element.props["__repeat_generated"] = true
	element.props["__repeat_source_id"] = source_id
	element.props["__repeat_item_var"] = item_var
	element.props["__repeat_item"] = item
	for child in element.children:
		_set_repeat_metadata_recursive(child, source_id, item_var, item)

func _apply_generated_repeat_bindings(changed_keys: PackedStringArray = PackedStringArray()) -> void:
	if app == null or app.root_element == null:
		return
	_apply_generated_repeat_bindings_recursive(app.root_element, changed_keys)

func _apply_generated_repeat_bindings_recursive(element, changed_keys: PackedStringArray) -> void:
	if element == null:
		return
	if bool(element.props.get("__repeat_generated", false)):
		var item_var: String = str(element.props.get("__repeat_item_var", ""))
		if item_var != "":
			var scope: Dictionary = _repeat_scope(item_var, element.props.get("__repeat_item", null))
			if element.node_type == "text":
				var text_template: String = str(element.props.get("__repeat_text_template", ""))
				if text_template != "" and element.control is Label and _template_depends_on_changed_key(text_template, changed_keys):
					(element.control as Label).text = _resolve_template_string(text_template, scope)
			else:
				var prop_templates: Dictionary = element.props.get("__repeat_prop_templates", {}) if element.props.get("__repeat_prop_templates", {}) is Dictionary else {}
				for key in prop_templates.keys():
					var prop_name: String = str(key)
					var template_text: String = str(prop_templates[key])
					if not _template_depends_on_changed_key(template_text, changed_keys):
						continue
					var value = HermesBindingExpression.new().configure(template_text).evaluate(scope)
					if element.props.get(prop_name, null) == value:
						continue
					element.props[prop_name] = value
					_apply_property_to_control(element, prop_name, value)
	for child in element.children:
		_apply_generated_repeat_bindings_recursive(child, changed_keys)

func _template_depends_on_changed_key(template_text: String, changed_keys: PackedStringArray) -> bool:
	if changed_keys.is_empty():
		return true
	for key in changed_keys:
		var clean: String = str(key).strip_edges()
		if clean != "" and template_text.find(clean) != -1:
			return true
	return false

func _clone_for_repeat(element, scope: Dictionary, item_var: String = "", item = null):
	if element == null:
		return null
	if element.node_type == "text":
		var text_template: String = str(element.text_content)
		var text_clone = HermesElementInstance.new().configure_text(_resolve_template_string(text_template, scope))
		if HermesBindingExpression.has_binding(text_template):
			text_clone.props["__repeat_text_template"] = text_template
		return text_clone
	var props: Dictionary = {}
	var prop_templates: Dictionary = {}
	for key in element.props.keys():
		var key_text: String = str(key)
		if key_text in ["for", "key", "__repeat_generated", "__repeat_source_id", "__repeat_item_var", "__repeat_item", "__repeat_prop_templates", "__repeat_text_template"]:
			continue
		var value = element.props[key]
		if value is String and HermesBindingExpression.has_binding(str(value)):
			var template_text: String = str(value)
			props[key_text] = HermesBindingExpression.new().configure(template_text).evaluate(scope)
			prop_templates[key_text] = template_text
		else:
			props[key_text] = value
	var clone = HermesElementInstance.new().configure_node(str(element.tag), props, [])
	if not prop_templates.is_empty():
		clone.props["__repeat_prop_templates"] = prop_templates
	clone.source_file = element.source_file
	clone.source_line = element.source_line
	for child in element.children:
		var child_clone = _clone_for_repeat(child, scope, item_var, item)
		if child_clone != null:
			clone.add_child(child_clone)
	return clone

func _resolve_template_string(value: String, scope: Dictionary) -> String:
	if HermesBindingExpression.has_binding(value):
		return str(HermesBindingExpression.new().configure(value).evaluate(scope))
	return value

func _connect_generated_tree(element) -> void:
	if element == null:
		return
	_connect_events_for_element(element)
	for child in element.children:
		_connect_generated_tree(child)

func _parse_repeat_spec(spec: String) -> Dictionary:
	var clean: String = spec.strip_edges()
	var parts: PackedStringArray = clean.split(" in ", false, 1)
	if parts.size() != 2:
		return {}
	var item_var: String = parts[0].strip_edges()
	var collection: String = parts[1].strip_edges()
	if item_var == "" or collection == "":
		return {}
	return {"item_var": item_var, "collection": collection}

func _direct_text_template(element) -> String:
	if element == null:
		return ""
	var parts: Array[String] = []
	for child in element.children:
		if child != null and child.node_type == "text":
			parts.append(str(child.text_content))
	return "".join(parts).strip_edges()

func _select_option_value(dropdown: OptionButton, value) -> void:
	if dropdown == null:
		return
	var desired: String = str(value)
	for i in dropdown.item_count:
		if str(dropdown.get_item_metadata(i)) == desired or dropdown.get_item_text(i) == desired:
			dropdown.select(i)
			return

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
	var text: String = str(value).strip_edges().to_lower()
	return text == "true" or text == "1" or text == "yes" or text == "on"
