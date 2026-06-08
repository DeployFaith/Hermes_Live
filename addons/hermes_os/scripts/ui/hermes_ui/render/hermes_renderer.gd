class_name HermesRenderer
extends RefCounted

const HermesRenderContext = preload("res://addons/hermes_os/scripts/ui/hermes_ui/render/hermes_render_context.gd")
const HermesFlexContainer = preload("res://addons/hermes_os/scripts/ui/hermes_ui/layout/hermes_flex_container.gd")
const HermesGridContainer = preload("res://addons/hermes_os/scripts/ui/hermes_ui/layout/hermes_grid_container.gd")
const HermesScrollView = preload("res://addons/hermes_os/scripts/ui/hermes_ui/layout/hermes_scroll_view.gd")

var context = null

func setup(render_context) -> void:
	context = render_context if render_context != null else HermesRenderContext.new()
	if context.registry == null:
		var registry_script = load("res://addons/hermes_os/scripts/ui/hermes_ui/render/hermes_component_registry.gd")
		context.registry = registry_script.new()
	context.registry.register_defaults(self)

func render_tree(root_element, host: Control) -> Control:
	if context == null:
		setup(null)
	var control: Control = render_element(root_element)
	if control != null and host != null:
		host.add_child(control)
	if root_element != null and context.style_resolver != null and not context.stylesheets.is_empty():
		context.style_resolver.apply_tree(root_element, context.stylesheets)
	return control

func render_element(element) -> Control:
	if element == null:
		return null
	if element.node_type != "text" and element.props.has("for"):
		return null
	if element.node_type == "text":
		var text_label := Label.new()
		text_label.text = element.text_content
		element.control = text_label
		return text_label
	var component = context.registry.resolve(element.tag)
	var control: Control = null
	if component == null:
		control = make_unknown_control(element)
	else:
		control = component.render(element, context, self)
	if control == null:
		control = make_unknown_control(element)
	element.control = control
	control.set_meta("hermes_tag", element.tag)
	if element.id != "":
		control.set_meta("hermes_id", element.id)
	if component != null and str(component.semantic_role).strip_edges() != "" and str(element.get_semantic_metadata().get("role", "")).strip_edges() == "":
		element.merge_semantic_metadata({"role": str(component.semantic_role).strip_edges()})
	if component != null and bool(component.render_children):
		for child in element.children:
			var child_control: Control = render_element(child)
			if child_control != null:
				context.ui.add(control, child_control)
	return control

func find_by_id(root_element, target_id: String):
	if root_element == null:
		return null
	if root_element.id == target_id:
		return root_element
	for child in root_element.children:
		var found = find_by_id(child, target_id)
		if found != null:
			return found
	return null

func make_unknown_control(element) -> Control:
	var label := Label.new()
	label.name = "HermesUnknownComponent"
	label.text = "Unknown component <%s>" % element.tag
	return label

func _render_app(element, render_context, _renderer) -> Control:
	return render_context.ui.vbox([], render_context.theme.spacing("space_3"), {"name": "HermesRenderApp", "expand_h": true, "expand_v": true})

func _render_window(element, render_context, _renderer) -> Control:
	return render_context.ui.panel([], render_context.theme.spacing("panel"), "base", {"name": "HermesRenderWindow", "expand_h": true, "expand_v": true})

func _render_app_shell(_element, render_context, _renderer) -> Control:
	return render_context.ui.vbox([], render_context.theme.spacing("space_3"), {"name": "HermesRenderAppShell", "expand_h": true, "expand_v": true})

func _render_app_header(_element, render_context, _renderer) -> Control:
	return render_context.ui.panel([], render_context.theme.spacing("space_2"), "base", {"name": "HermesRenderAppHeader", "expand_h": true})

func _render_app_body(_element, render_context, _renderer) -> Control:
	return render_context.ui.vbox([], render_context.theme.spacing("space_3"), {"name": "HermesRenderAppBody", "expand_h": true, "expand_v": true})

func _render_app_footer(_element, render_context, _renderer) -> Control:
	return render_context.ui.panel([], render_context.theme.spacing("space_2"), "base", {"name": "HermesRenderAppFooter", "expand_h": true})

func _render_column(element, render_context, _renderer) -> Control:
	var control := HermesFlexContainer.new("column")
	control.name = "HermesRenderColumn"
	return control

func _render_row(element, render_context, _renderer) -> Control:
	var control := HermesFlexContainer.new("row")
	control.name = "HermesRenderRow"
	return control

func _render_panel(element, render_context, _renderer) -> Control:
	return render_context.ui.panel([], render_context.theme.spacing("panel"), "base", {"name": "HermesRenderPanel", "expand_h": true, "expand_v": true})

func _render_card(element, render_context, _renderer) -> Control:
	return render_context.ui.card([], render_context.theme.spacing("card"), {"name": "HermesRenderCard", "expand_h": true})

func _render_grid(element, _render_context, _renderer) -> Control:
	var control := HermesGridContainer.new()
	control.name = "HermesRenderGrid"
	return control

func _render_scroll_view(element, _render_context, _renderer) -> Control:
	var control := HermesScrollView.new()
	control.name = "HermesRenderScrollView"
	return control

func _render_flow_row(element, render_context, _renderer) -> Control:
	return render_context.ui.flow_row([], {"name": "HermesRenderFlowRow", "expand_h": true})

func _render_sidebar(element, render_context, _renderer) -> Control:
	var width: int = int(str(element.props.get("width", 220)).to_float())
	element.merge_semantic_metadata({"role": "navigation"})
	return render_context.ui.sidebar([], width, {"name": "HermesRenderSidebar", "expand_v": true})

func _render_toolbar(element, render_context, _renderer) -> Control:
	element.merge_semantic_metadata({"role": "toolbar"})
	return render_context.ui.toolbar([], {"name": "HermesRenderToolbar"})

func _render_status_bar(element, render_context, _renderer) -> Control:
	var kind: String = str(element.props.get("variant", element.props.get("kind", "info")))
	element.merge_semantic_metadata({"role": "status"})
	return render_context.ui.status_bar(element.get_text_content(), kind, {"name": "HermesRenderStatusBar"})

func _render_section_header(element, render_context, _renderer) -> Control:
	var title: String = str(element.props.get("title", element.get_text_content()))
	var body_text: String = str(element.props.get("subtitle", element.props.get("body", element.props.get("description", ""))))
	element.merge_semantic_metadata({"role": "heading"})
	return render_context.ui.section_header(title, body_text, {"name": "HermesRenderSectionHeader"})

func _render_settings_page(element, render_context, _renderer) -> Control:
	element.merge_semantic_metadata({"role": "region"})
	return render_context.ui.vbox([], render_context.theme.spacing("space_3"), {"name": "HermesRenderSettingsPage", "expand_h": true, "expand_v": true})

func _render_settings_section(element, render_context, _renderer) -> Control:
	var children: Array = []
	var title: String = str(element.props.get("title", "")).strip_edges()
	var subtitle: String = str(element.props.get("subtitle", element.props.get("body", element.props.get("description", "")))).strip_edges()
	if title != "" or subtitle != "":
		children.append(render_context.ui.section_header(title, subtitle))
	element.merge_semantic_metadata({"role": "region"})
	return render_context.ui.card(children, render_context.theme.spacing("card"), {"name": "HermesRenderSettingsSection", "expand_h": true})

func _render_settings_row(element, render_context, _renderer) -> Control:
	var label_text: String = str(element.props.get("label", element.props.get("title", ""))).strip_edges()
	var label_width: int = int(str(element.props.get("label-width", element.props.get("label_width", 116))).to_float())
	var row := HBoxContainer.new()
	row.name = "HermesRenderSettingsRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", render_context.theme.spacing("form_row_gap"))
	var text_label: Label = render_context.ui.label(label_text, {"variant": "body", "name": "HermesSettingsRowLabel", "min_size": Vector2(label_width, 0)})
	row.add_child(text_label)
	var body := HBoxContainer.new()
	body.name = "HermesSettingsRowBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", render_context.theme.spacing("space_2"))
	row.add_child(body)
	row.set_meta("hermes_ui_body", body)
	element.merge_semantic_metadata({"role": "group", "label": label_text})
	return row

func _render_text(element, render_context, _renderer) -> Control:
	return render_context.ui.label(element.get_text_content(), {"name": "HermesRenderText", "autowrap": true, "expand_h": true})

func _render_title(element, render_context, _renderer) -> Control:
	return render_context.ui.label(element.get_text_content(), {"variant": "heading", "name": "HermesRenderTitle", "expand_h": true})

func _render_button(element, render_context, _renderer) -> Control:
	return render_context.ui.button(element.get_text_content(), {"variant": str(element.props.get("variant", "secondary")), "disabled": str(element.props.get("disabled", "false")).to_lower() == "true", "name": "HermesRenderButton"})

func _render_text_input(element, render_context, _renderer) -> Control:
	return render_context.ui.input({"value": str(element.props.get("value", "")), "placeholder": str(element.props.get("placeholder", "")), "disabled": _prop_bool(element, "disabled"), "name": "HermesRenderTextInput", "expand_h": true})

func _render_text_area(element, render_context, _renderer) -> Control:
	var readonly: bool = _prop_bool(element, "readonly") or _prop_bool(element, "read-only")
	var disabled: bool = _prop_bool(element, "disabled")
	element.merge_semantic_metadata({"role": "textbox", "multiline": true, "state": {"multiline": true, "readonly": readonly, "disabled": disabled}})
	return render_context.ui.text_area({"value": str(element.props.get("value", "")), "placeholder": str(element.props.get("placeholder", "")), "readonly": readonly, "disabled": disabled, "name": "HermesRenderTextArea", "expand_h": true, "expand_v": true})

func _render_dropdown(element, render_context, _renderer) -> Control:
	var disabled: bool = _prop_bool(element, "disabled")
	var selected_id: String = str(element.props.get("value", element.props.get("selected", element.props.get("selected_id", ""))))
	element.merge_semantic_metadata({"role": "combobox", "value": selected_id, "state": {"disabled": disabled}})
	var node: OptionButton = render_context.ui.dropdown(_items_from_options(element), {"value": selected_id, "disabled": disabled, "label": str(element.props.get("label", "Select")), "name": "HermesRenderDropdown", "expand_h": true})
	node.disabled = disabled
	return node

func _render_slider(element, render_context, _renderer) -> Control:
	var disabled: bool = _prop_bool(element, "disabled")
	var value: float = str(element.props.get("value", element.props.get("model_value", element.props.get("min", 0.0)))).to_float()
	var min_value: float = str(element.props.get("min", 0.0)).to_float()
	var max_value: float = str(element.props.get("max", 1.0)).to_float()
	element.merge_semantic_metadata({"role": "slider", "value": value, "state": {"disabled": disabled, "min": min_value, "max": max_value}})
	var node: HSlider = render_context.ui.slider({"value": value, "min": min_value, "max": max_value, "step": str(element.props.get("step", 0.01)).to_float(), "label": str(element.props.get("label", "Slider")), "name": "HermesRenderSlider", "expand_h": true})
	node.editable = not disabled
	return node

func _render_toggle(element, render_context, _renderer) -> Control:
	var checked: bool = _prop_bool(element, "checked") or _prop_bool(element, "pressed") or _prop_bool(element, "value")
	var disabled: bool = _prop_bool(element, "disabled")
	var label_text: String = str(element.props.get("label", element.get_text_content()))
	element.merge_semantic_metadata({"role": "checkbox", "value": checked, "state": {"checked": checked, "disabled": disabled}})
	var node: CheckBox = render_context.ui.toggle(label_text, {"checked": checked, "disabled": disabled, "name": "HermesRenderToggle", "expand_h": true})
	node.disabled = disabled
	return node

func _render_list(element, render_context, _renderer) -> Control:
	element.merge_semantic_metadata({"role": "list"})
	return render_context.ui.vbox([], render_context.theme.spacing("space_1"), {"name": "HermesRenderList", "expand_h": true, "expand_v": true})

func _render_list_item(element, render_context, _renderer) -> Control:
	var selected: bool = _prop_bool(element, "selected")
	var disabled: bool = _prop_bool(element, "disabled")
	var role: String = "option" if selected or str(element.props.get("on:select", "")).strip_edges() != "" else "listitem"
	element.merge_semantic_metadata({"role": role, "selected": selected, "state": {"selected": selected, "disabled": disabled}})
	var item_text: String = element.get_text_content()
	if item_text == "":
		item_text = str(element.props.get("label", element.props.get("value", element.id)))
	return render_context.ui.list_item({"text": item_text, "selected": selected, "disabled": disabled, "name": "HermesRenderListItem", "expand_h": true})

func _render_file_list(_element, render_context, _renderer) -> Control:
	return render_context.ui.file_list({"name": "HermesRenderFileList", "expand_h": true, "expand_v": true, "gap": render_context.theme.spacing("space_1")})

func _render_file_row(element, render_context, _renderer) -> Control:
	var selected: bool = _prop_bool(element, "selected")
	var disabled: bool = _prop_bool(element, "disabled")
	var file_type: String = str(element.props.get("type", "file"))
	element.merge_semantic_metadata({"role": "folder" if file_type == "dir" else "file", "selected": selected, "state": {"selected": selected, "disabled": disabled}})
	var display_name: String = str(element.props.get("label", element.props.get("name", element.get_text_content())))
	var semantic_label: String = str(element.props.get("label", display_name))
	element.merge_semantic_metadata({"label": semantic_label})
	return render_context.ui.file_row({
		"id": element.id,
		"text": display_name,
		"modified": str(element.props.get("modified", "—")),
		"size": str(element.props.get("size", "")),
		"type": file_type,
		"selected": selected,
		"disabled": disabled,
		"name": "HermesRenderFileRow",
		"expand_h": true
	})

func _render_path_breadcrumb(element, render_context, _renderer) -> Control:
	var text_value: String = str(element.props.get("path", element.get_text_content()))
	element.merge_semantic_metadata({"role": "text", "value": text_value})
	return render_context.ui.path_breadcrumb(text_value, {"name": "HermesRenderPathBreadcrumb", "expand_h": true})

func _render_terminal_surface(element, render_context, _renderer) -> Control:
	var prompt_value: String = str(element.props.get("prompt", "")).strip_edges()
	var input_value: String = str(element.props.get("input", ""))
	var transcript_preview: String = str(element.props.get("transcript", "")).strip_edges()
	var session_id: String = str(element.props.get("session-id", element.props.get("session_id", ""))).strip_edges()
	element.merge_semantic_metadata({
		"role": "terminal",
		"value": {
			"prompt": prompt_value,
			"input": input_value,
			"session_id": session_id,
			"transcript": transcript_preview
		},
		"state": {
			"prompt": prompt_value,
			"input": input_value,
			"session_id": session_id,
			"transcript": transcript_preview
		}
	})
	return render_context.ui.terminal_surface({"name": "HermesRenderTerminalSurface", "expand_h": true, "expand_v": true})

func _render_browser_surface(element, render_context, _renderer) -> Control:
	var current_url: String = str(element.props.get("current-url", element.props.get("current_url", ""))).strip_edges()
	var loading: bool = _prop_bool(element, "loading")
	element.merge_semantic_metadata({
		"role": "browser",
		"value": current_url,
		"current_url": current_url,
		"state": {
			"current_url": current_url,
			"loading": loading
		}
	})
	return render_context.ui.browser_surface({"name": "HermesRenderBrowserSurface", "expand_h": true, "expand_v": true})

func _render_badge(element, render_context, _renderer) -> Control:
	return render_context.ui.badge(element.get_text_content(), {"kind": str(element.props.get("variant", "info")), "name": "HermesRenderBadge"})

func _prop_bool(element, prop_name: String) -> bool:
	if element == null:
		return false
	var value = element.props.get(prop_name, false)
	if value is bool:
		return bool(value)
	var text: String = str(value).strip_edges().to_lower()
	return text == "true" or text == "1" or text == "yes" or text == "on"

func _items_from_options(element) -> Array:
	if element == null:
		return []
	var raw = element.props.get("options", element.props.get("items", ""))
	if raw is Array:
		return raw
	var text: String = str(raw).strip_edges()
	var result: Array = []
	if text == "":
		return result
	var delimiter: String = "|" if text.find("|") != -1 else ","
	for part in text.split(delimiter, false):
		var clean: String = part.strip_edges()
		if clean == "":
			continue
		var pair: PackedStringArray = clean.split(":", false, 1)
		if pair.size() == 2:
			result.append({"id": pair[0].strip_edges(), "text": pair[1].strip_edges()})
		else:
			result.append({"id": clean, "text": clean})
	return result
