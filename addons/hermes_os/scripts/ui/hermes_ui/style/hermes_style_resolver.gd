class_name HermesStyleResolver
extends RefCounted

const HermesComputedStyle = preload("res://addons/hermes_os/scripts/ui/hermes_ui/style/hermes_computed_style.gd")
const HermesStyleBoxFactory = preload("res://addons/hermes_os/scripts/ui/hermes_ui/style/hermes_style_box_factory.gd")
const HermesStyleParser = preload("res://addons/hermes_os/scripts/ui/hermes_ui/style/hermes_style_parser.gd")

const INHERITED_PROPERTIES: Array[String] = [
	"color",
	"font-family",
	"font-size",
	"font-weight",
	"line-height",
	"text-align"
]

var _box_factory := HermesStyleBoxFactory.new()
var _inline_parser := HermesStyleParser.new()

const LAYOUT_TAGS := {
	"App": true,
	"AppShell": true,
	"AppBody": true,
	"Column": true,
	"Row": true,
	"Grid": true,
	"FlowRow": true,
	"SettingsPage": true,
	"SettingsRow": true,
	"List": true
}

const SURFACE_TAGS := {
	"Window": true,
	"Panel": true,
	"Card": true,
	"SettingsSection": true,
	"FileList": true,
	"TerminalSurface": true,
	"BrowserSurface": true,
	"Sidebar": true
}

func apply_tree(root_element, stylesheets: Array) -> void:
	var variables: Dictionary = _collect_variables(stylesheets)
	_apply_recursive(root_element, stylesheets, variables, null)

func _apply_recursive(element, stylesheets: Array, variables: Dictionary, parent_style) -> void:
	if element == null:
		return
	var computed = compute_element_style(element, stylesheets, variables, parent_style)
	element.computed_style = computed
	_apply_to_control(element)
	for child in element.children:
		_apply_recursive(child, stylesheets, variables, computed)

func compute_element_style(element, stylesheets: Array, variables: Dictionary, parent_style = null):
	var computed = HermesComputedStyle.new()
	if parent_style != null:
		for property_name in INHERITED_PROPERTIES:
			if parent_style.has_property(property_name):
				computed.set_property(property_name, parent_style.properties[property_name])
	var winners: Dictionary = {}
	var source_order: int = 0
	for sheet in stylesheets:
		if sheet == null:
			continue
		for rule in sheet.rules:
			if rule == null:
				continue
			for selector in rule.selectors:
				if not _selector_matches(element, selector):
					continue
				computed.matched_selectors.append(selector)
				var specificity: int = _selector_specificity(selector)
				for declaration in rule.declarations:
					_consider_declaration(winners, declaration, specificity, source_order)
					source_order += 1
	var inline_style: String = str(element.props.get("style", "")).strip_edges()
	if inline_style != "":
		var inline_sheet = _inline_parser.parse_text("Inline { %s }" % inline_style, element.source_file)
		if inline_sheet != null and not inline_sheet.rules.is_empty():
			for declaration in inline_sheet.rules[0].declarations:
				_consider_declaration(winners, declaration, 1000, source_order)
				source_order += 1
	var property_names: Array = winners.keys()
	property_names.sort()
	for property_name in property_names:
		var winning = winners[property_name]
		var resolved = _resolve_declaration_value(winning.declaration, variables)
		computed.set_property(_normalize_property_name(property_name), resolved)
	return computed

func _consider_declaration(winners: Dictionary, declaration, specificity: int, source_order: int) -> void:
	if declaration == null:
		return
	var key: String = declaration.property_name
	if not winners.has(key):
		winners[key] = {"specificity": specificity, "order": source_order, "declaration": declaration}
		return
	var current: Dictionary = winners[key]
	if specificity > int(current.get("specificity", -1)):
		winners[key] = {"specificity": specificity, "order": source_order, "declaration": declaration}
		return
	if specificity == int(current.get("specificity", -1)) and source_order >= int(current.get("order", -1)):
		winners[key] = {"specificity": specificity, "order": source_order, "declaration": declaration}

func _collect_variables(stylesheets: Array) -> Dictionary:
	var variables: Dictionary = {}
	for sheet in stylesheets:
		if sheet == null:
			continue
		for key in sheet.variables.keys():
			variables[key] = sheet.variables[key]
	return variables

func _resolve_declaration_value(declaration, variables: Dictionary):
	if declaration == null:
		return null
	var property_name: String = str(declaration.property_name)
	var raw_text: String = str(declaration.value.raw_text if declaration.value != null else "").strip_edges()
	if property_name in ["grid-template-columns", "grid-template-rows", "shadow", "transition"]:
		return raw_text
	if raw_text.contains(" ") and property_name in ["border", "margin", "padding"]:
		return raw_text
	return _resolve_value(declaration.value, variables)

func _resolve_value(style_value, variables: Dictionary):
	if style_value == null:
		return null
	if style_value is Color or style_value is int or style_value is float:
		return style_value
	if not (style_value is RefCounted) or not style_value.has_method("configure"):
		return style_value
	match str(style_value.value_type):
		"var":
			var variable_name: String = str(style_value.value).strip_edges()
			if not variable_name.begins_with("--"):
				variable_name = "--" + variable_name
			if variables.has(variable_name):
				return _resolve_value(variables[variable_name], variables)
			return style_value.raw_text
		"color":
			return _parse_color(str(style_value.raw_text))
		"length", "number", "percent", "fr":
			return float(style_value.value)
		"string":
			return str(style_value.value)
		_:
			return str(style_value.value)

func _parse_color(text: String) -> Color:
	var clean: String = text.strip_edges()
	if clean == "transparent":
		return Color(0, 0, 0, 0)
	if clean.begins_with("#"):
		return Color(clean)
	if clean.begins_with("rgb(") or clean.begins_with("rgba("):
		return _parse_rgb_color(clean)
	return Color(clean)

func _parse_rgb_color(text: String) -> Color:
	var open_index: int = text.find("(")
	var close_index: int = text.rfind(")")
	if open_index == -1 or close_index == -1 or close_index <= open_index:
		return Color.TRANSPARENT
	var body: String = text.substr(open_index + 1, close_index - open_index - 1)
	var parts: PackedStringArray = body.split(",", false)
	if parts.size() < 3:
		return Color.TRANSPARENT
	var r: float = clampf(float(parts[0].strip_edges()) / 255.0, 0.0, 1.0)
	var g: float = clampf(float(parts[1].strip_edges()) / 255.0, 0.0, 1.0)
	var b: float = clampf(float(parts[2].strip_edges()) / 255.0, 0.0, 1.0)
	var a: float = 1.0
	if parts.size() >= 4:
		a = clampf(float(parts[3].strip_edges()), 0.0, 1.0)
	return Color(r, g, b, a)

func _normalize_property_name(property_name: String) -> String:
	match property_name:
		"background":
			return "background-color"
		_:
			return property_name

func _selector_matches(element, selector: String) -> bool:
	var parsed: Dictionary = _tokenize_selector(selector)
	var tokens: Array = parsed.get("tokens", [])
	var combinators: Array = parsed.get("combinators", [])
	if tokens.is_empty():
		return false
	return _match_selector_chain(element, tokens, combinators, tokens.size() - 1)

func _match_selector_chain(current, tokens: Array, combinators: Array, token_index: int) -> bool:
	if current == null:
		return false
	if not _simple_selector_matches(current, str(tokens[token_index])):
		return false
	if token_index == 0:
		return true
	var combinator: String = str(combinators[token_index - 1])
	if combinator == ">":
		return _match_selector_chain(current.parent, tokens, combinators, token_index - 1)
	var ancestor = current.parent
	while ancestor != null:
		if _match_selector_chain(ancestor, tokens, combinators, token_index - 1):
			return true
		ancestor = ancestor.parent
	return false

func _simple_selector_matches(element, selector: String) -> bool:
	var parsed: Dictionary = _parse_simple_selector(selector)
	var type_name: String = str(parsed.get("type", ""))
	if type_name != "" and type_name != element.tag:
		return false
	var id_name: String = str(parsed.get("id", ""))
	if id_name != "" and id_name != element.id:
		return false
	for class_token in parsed.get("classes", []):
		if not element.classes.has(str(class_token)):
			return false
	for attr_rule in parsed.get("attributes", []):
		var attr_name: String = str(attr_rule.get("name", ""))
		if not element.props.has(attr_name):
			return false
		if attr_rule.has("value"):
			var actual: String = str(element.props.get(attr_name, "")).strip_edges().to_lower()
			var expected: String = str(attr_rule.get("value", "")).strip_edges().trim_prefix("\"").trim_suffix("\"").trim_prefix("'").trim_suffix("'").to_lower()
			if actual != expected:
				return false
	for pseudo_name in parsed.get("pseudos", []):
		if not _pseudo_matches(element, str(pseudo_name)):
			return false
	return true

func _pseudo_matches(element, pseudo_name: String) -> bool:
	var clean: String = pseudo_name.strip_edges().to_lower()
	match clean:
		"hover", "focus", "pressed", "active":
			return element.is_pseudo_state(clean)
		"disabled":
			if element.is_pseudo_state("disabled"):
				return true
			if _boolish(element.props.get("disabled", false)):
				return true
			if element.control is Button:
				return (element.control as Button).disabled
			if element.control is LineEdit:
				return not (element.control as LineEdit).editable
			if element.control is TextEdit:
				return not (element.control as TextEdit).editable
			return false
		"selected", "checked":
			return element.is_pseudo_state(clean) or _boolish(element.props.get(clean, false))
		_:
			return false

func _boolish(value) -> bool:
	if value is bool:
		return bool(value)
	var text: String = str(value).strip_edges().to_lower()
	return text == "true" or text == "1" or text == "yes"

func _selector_specificity(selector: String) -> int:
	var parsed: Dictionary = _tokenize_selector(selector)
	var score: int = 0
	for token in parsed.get("tokens", []):
		var simple: Dictionary = _parse_simple_selector(str(token))
		if str(simple.get("id", "")) != "":
			score += 100
		score += (simple.get("classes", []) as Array).size() * 10
		score += (simple.get("attributes", []) as Array).size() * 10
		score += (simple.get("pseudos", []) as Array).size() * 10
		if str(simple.get("type", "")) != "":
			score += 1
	return score

func _tokenize_selector(selector: String) -> Dictionary:
	var tokens: Array = []
	var combinators: Array = []
	var current: String = ""
	var bracket_depth: int = 0
	var quote_char: String = ""
	var pending_descendant: bool = false
	for i in range(selector.length()):
		var ch: String = selector.substr(i, 1)
		if quote_char != "":
			current += ch
			if ch == quote_char:
				quote_char = ""
			continue
		if (ch == "\"" or ch == "'") and bracket_depth > 0:
			quote_char = ch
			current += ch
			continue
		if ch == "[":
			bracket_depth += 1
			current += ch
			continue
		if ch == "]":
			bracket_depth = max(bracket_depth - 1, 0)
			current += ch
			continue
		if bracket_depth == 0 and ch == ">":
			if current.strip_edges() != "":
				tokens.append(current.strip_edges())
				current = ""
			if pending_descendant and combinators.size() < tokens.size() - 1:
				combinators.append(" ")
			pending_descendant = false
			combinators.append(">")
			continue
		if bracket_depth == 0 and ch in [" ", "\t", "\n", "\r"]:
			if current.strip_edges() != "":
				tokens.append(current.strip_edges())
				current = ""
				pending_descendant = true
			elif not tokens.is_empty():
				pending_descendant = true
			continue
		if pending_descendant and not tokens.is_empty() and combinators.size() < tokens.size():
			combinators.append(" ")
			pending_descendant = false
		current += ch
	if current.strip_edges() != "":
		tokens.append(current.strip_edges())
	return {"tokens": tokens, "combinators": combinators}

func _parse_simple_selector(selector: String) -> Dictionary:
	var result: Dictionary = {
		"type": "",
		"id": "",
		"classes": [],
		"attributes": [],
		"pseudos": []
	}
	var i: int = 0
	while i < selector.length() and not selector.substr(i, 1) in ["#", ".", "[", ":"]:
		result["type"] += selector.substr(i, 1)
		i += 1
	while i < selector.length():
		var ch: String = selector.substr(i, 1)
		if ch == "#":
			i += 1
			var id_token: String = _read_identifier(selector, i)
			result["id"] = id_token
			i += id_token.length()
			continue
		if ch == ".":
			i += 1
			var class_token: String = _read_identifier(selector, i)
			(result["classes"] as Array).append(class_token)
			i += class_token.length()
			continue
		if ch == ":":
			i += 1
			var pseudo_token: String = _read_identifier(selector, i)
			(result["pseudos"] as Array).append(pseudo_token)
			i += pseudo_token.length()
			continue
		if ch == "[":
			var end_index: int = selector.find("]", i)
			if end_index == -1:
				break
			var attr_body: String = selector.substr(i + 1, end_index - i - 1).strip_edges()
			var attr_rule: Dictionary = {}
			var equals_index: int = attr_body.find("=")
			if equals_index == -1:
				attr_rule["name"] = attr_body
			else:
				attr_rule["name"] = attr_body.substr(0, equals_index).strip_edges()
				attr_rule["value"] = attr_body.substr(equals_index + 1).strip_edges()
			(result["attributes"] as Array).append(attr_rule)
			i = end_index + 1
			continue
		i += 1
	result["type"] = str(result["type"]).strip_edges()
	return result

func _read_identifier(text: String, start_index: int) -> String:
	var value: String = ""
	for i in range(start_index, text.length()):
		var ch: String = text.substr(i, 1)
		if ch in ["#", ".", "[", ":", "]"]:
			break
		value += ch
	return value.strip_edges()

func _apply_to_control(element) -> void:
	if element == null or element.control == null or element.computed_style == null:
		return
	var control: Control = element.control
	var computed = element.computed_style
	_apply_size_properties(control, computed)
	_apply_flex_properties(element, control, computed)
	_apply_parent_alignment(element, control)
	_apply_opacity(control, computed)
	_apply_gap(control, computed)
	_apply_layout_configuration(control, computed)
	_apply_contract_defaults(element, control, computed)
	_apply_visual_style(control, computed)
	_apply_text_style(control, computed)
	_apply_surface_containment(element, control, computed)

func _apply_contract_defaults(element, control: Control, computed) -> void:
	if element == null or control == null:
		return
	var tag: String = str(element.tag)
	if LAYOUT_TAGS.has(tag):
		if control is PanelContainer:
			(control as PanelContainer).add_theme_stylebox_override("panel", _transparent_box())
	if tag == "ScrollView":
		if control is PanelContainer:
			(control as PanelContainer).add_theme_stylebox_override("panel", _transparent_box())
		if control.has_method("get_scroll_container"):
			var scroll: Variant = control.call("get_scroll_container")
			if scroll is ScrollContainer:
				(scroll as ScrollContainer).add_theme_stylebox_override("panel", _transparent_box())

func _apply_surface_containment(element, control: Control, computed) -> void:
	if element == null or control == null:
		return
	var tag: String = str(element.tag)
	if not SURFACE_TAGS.has(tag):
		return
	var radius: int = int(round(computed.get_number("border-radius", 0.0)))
	if radius <= 0:
		return
	if control is Container:
		(control as Container).clip_contents = true

func _transparent_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_width_left = 0
	box.border_width_right = 0
	box.border_width_top = 0
	box.border_width_bottom = 0
	box.content_margin_left = 0
	box.content_margin_right = 0
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	return box

func _apply_size_properties(control: Control, computed) -> void:
	var width: int = int(round(computed.get_number("width", -1.0)))
	var height: int = int(round(computed.get_number("height", -1.0)))
	var min_width: int = int(round(computed.get_number("min-width", -1.0)))
	var min_height: int = int(round(computed.get_number("min-height", -1.0)))
	var current: Vector2 = control.custom_minimum_size
	if width >= 0:
		current.x = width
	if height >= 0:
		current.y = height
	if min_width >= 0:
		current.x = max(current.x, min_width)
	if min_height >= 0:
		current.y = max(current.y, min_height)
	control.custom_minimum_size = current

func _apply_opacity(control: Control, computed) -> void:
	if not computed.has_property("opacity"):
		return
	var alpha: float = clampf(computed.get_number("opacity", 1.0), 0.0, 1.0)
	control.modulate = Color(control.modulate.r, control.modulate.g, control.modulate.b, alpha)

func _apply_gap(control: Control, computed) -> void:
	if not computed.has_property("gap"):
		return
	var separation: int = int(round(computed.get_number("gap", 0.0)))
	var target: Control = _layout_target(control)
	if target is VBoxContainer or target is HBoxContainer:
		target.add_theme_constant_override("separation", separation)
		return
	if target != null and target.has_method("set_gap"):
		target.call("set_gap", separation)

func _apply_layout_configuration(control: Control, computed) -> void:
	var target: Control = _layout_target(control)
	if computed.has_property("justify-content"):
		var justify: String = computed.get_string("justify-content").strip_edges().to_lower()
		if target is BoxContainer:
			match justify:
				"center":
					(target as BoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
				"end", "right", "bottom":
					(target as BoxContainer).alignment = BoxContainer.ALIGNMENT_END
				_:
					(target as BoxContainer).alignment = BoxContainer.ALIGNMENT_BEGIN
		elif target != null and target.has_method("set_main_alignment"):
			target.call("set_main_alignment", justify)
	if computed.has_property("grid-template-columns") and target != null and target.has_method("set_template_columns_from_text"):
		target.call("set_template_columns_from_text", computed.get_string("grid-template-columns"))

func _apply_visual_style(control: Control, computed) -> void:
	var box: StyleBoxFlat = _box_factory.build(computed)
	if box == null:
		return
	if control is Button:
		(control as Button).add_theme_stylebox_override("normal", box)
		(control as Button).add_theme_stylebox_override("hover", box)
		(control as Button).add_theme_stylebox_override("pressed", box)
		(control as Button).add_theme_stylebox_override("focus", box)
		(control as Button).add_theme_stylebox_override("disabled", box)
		return
	if control is LineEdit:
		(control as LineEdit).add_theme_stylebox_override("normal", box)
		(control as LineEdit).add_theme_stylebox_override("focus", box)
		(control as LineEdit).add_theme_stylebox_override("read_only", box)
		return
	if control is TextEdit:
		(control as TextEdit).add_theme_stylebox_override("normal", box)
		(control as TextEdit).add_theme_stylebox_override("focus", box)
		(control as TextEdit).add_theme_stylebox_override("read_only", box)
		return
	if control is PanelContainer:
		(control as PanelContainer).add_theme_stylebox_override("panel", box)

func _apply_text_style(control: Control, computed) -> void:
	var font_color: Color = computed.get_color("color", Color.TRANSPARENT)
	var font_size: int = int(round(computed.get_number("font-size", -1.0)))
	if control is Label:
		if computed.has_property("color"):
			(control as Label).add_theme_color_override("font_color", font_color)
		if font_size > 0:
			(control as Label).add_theme_font_size_override("font_size", font_size)
		return
	if control is Button:
		if computed.has_property("color"):
			(control as Button).add_theme_color_override("font_color", font_color)
			(control as Button).add_theme_color_override("font_hover_color", font_color)
			(control as Button).add_theme_color_override("font_pressed_color", font_color)
			(control as Button).add_theme_color_override("font_disabled_color", font_color)
		if font_size > 0:
			(control as Button).add_theme_font_size_override("font_size", font_size)
		return
	if control is LineEdit:
		if computed.has_property("color"):
			(control as LineEdit).add_theme_color_override("font_color", font_color)
		if font_size > 0:
			(control as LineEdit).add_theme_font_size_override("font_size", font_size)
		return
	if control is TextEdit:
		if computed.has_property("color"):
			(control as TextEdit).add_theme_color_override("font_color", font_color)
		if font_size > 0:
			(control as TextEdit).add_theme_font_size_override("font_size", font_size)

func _apply_flex_properties(element, control: Control, computed) -> void:
	if not computed.has_property("flex"):
		return
	if computed.get_number("flex", 0.0) < 1.0:
		return
	var parent_tag: String = ""
	if element.parent != null:
		parent_tag = str(element.parent.tag)
	match parent_tag:
		"Row":
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		"Column", "AppShell", "AppBody":
			control.size_flags_vertical = Control.SIZE_EXPAND_FILL
		"Window", "ScrollView", "Grid":
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			control.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_:
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _apply_parent_alignment(element, control: Control) -> void:
	if element.parent == null or element.parent.computed_style == null:
		return
	var align_items: String = element.parent.computed_style.get_string("align-items", "").strip_edges().to_lower()
	if align_items == "":
		return
	var parent_tag: String = str(element.parent.tag)
	if parent_tag == "Row":
		control.size_flags_vertical = _cross_axis_flag_for_alignment(align_items)
	elif parent_tag == "Column":
		control.size_flags_horizontal = _cross_axis_flag_for_alignment(align_items)

func _cross_axis_flag_for_alignment(align_items: String) -> int:
	match align_items:
		"center":
			return Control.SIZE_SHRINK_CENTER
		"end", "right", "bottom":
			return Control.SIZE_SHRINK_END
		"stretch", "fill":
			return Control.SIZE_EXPAND_FILL
		_:
			return Control.SIZE_SHRINK_BEGIN

func _layout_target(control: Control) -> Control:
	if control != null and control.has_meta("hermes_ui_body"):
		var body: Variant = control.get_meta("hermes_ui_body")
		if body is Control:
			return body as Control
	return control
