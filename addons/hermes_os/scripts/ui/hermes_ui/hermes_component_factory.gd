class_name HermesComponentFactory
extends RefCounted

const HermesThemeScript = preload("res://addons/hermes_os/scripts/ui/hermes_ui/hermes_theme.gd")
const HermesRefsScript = preload("res://addons/hermes_os/scripts/ui/hermes_ui/hermes_refs.gd")
const DesignTokens = preload("res://addons/hermes_os/scripts/os/design_tokens.gd")
const TerminalViewScript = preload("res://addons/hermes_os/scripts/apps/terminal/terminal_view.gd")
const BrowserContentSurfaceScript = preload("res://addons/hermes_os/scripts/apps/browser/browser_content.gd")

const BODY_META := "hermes_ui_body"
const SELECTED_META := "hermes_ui_selected_id"
const ACTIVE_TAB_META := "hermes_ui_active_tab"

const COMMON_OPTIONS: Array[String] = [
	"name", "tooltip", "disabled", "visible", "min_size", "expand_h", "expand_v", "size_flags_h", "size_flags_v",
	"ref", "mcp_role", "mcp_actions", "label", "width", "height", "padding", "padding_h", "padding_v", "gap",
	"variant", "kind", "bg", "border", "border_width", "radius", "autowrap", "readonly", "empty_text", "selected_id",
	"on_pressed", "on_change", "on_submit", "on_select", "on_toggled", "on_value_changed", "on_item_selected", "active_id",
	"items", "value", "placeholder", "text", "title", "body", "id", "state", "icon", "app_id", "category", "timestamp",
	"left", "center", "right", "footer", "search", "apps", "actions", "separator", "checked", "pressed", "max", "min", "step",
	"mcp_label", "mcp_enabled", "meta", "vertical", "v_gap", "label_width", "selected", "size", "elevation",
	"content", "subtitle", "description", "align", "dense", "type", "path", "modified"
]

var theme = null

func _init(p_theme = null) -> void:
	theme = p_theme if p_theme != null else HermesThemeScript.new()

# -----------------------------------------------------------------------------
# Child/composition helpers
# -----------------------------------------------------------------------------
func body_of(control: Control) -> Control:
	if control == null:
		if OS.is_debug_build():
			push_warning("HermesUI body_of called with null control")
		return null
	if control.has_meta(BODY_META):
		var body: Variant = control.get_meta(BODY_META)
		if body is Control and is_instance_valid(body):
			return body as Control
	return control

func add(control: Control, child: Control) -> Control:
	if control == null:
		if OS.is_debug_build():
			push_warning("HermesUI add skipped null parent control")
		return null
	if child == null:
		if OS.is_debug_build():
			push_warning("HermesUI add skipped null child for %s" % control.name)
		return control
	var body: Control = body_of(control)
	if body != null:
		body.add_child(child)
	elif OS.is_debug_build():
		push_warning("HermesUI add could not resolve body for %s" % control.name)
	return control

func add_many(control: Control, children: Array) -> Control:
	for child in children:
		if child is Control:
			add(control, child as Control)
		elif child == null and OS.is_debug_build():
			push_warning("HermesUI add_many skipped null child for %s" % (control.name if control != null else "<null>"))
	return control

func clear_children(control: Control) -> void:
	var body: Control = body_of(control)
	if body == null:
		return
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()

# -----------------------------------------------------------------------------
# Layout / containers
# -----------------------------------------------------------------------------
func vbox(children: Array = [], gap: int = -1, options: Dictionary = {}) -> VBoxContainer:
	_validate_options("vbox", options)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", theme.spacing("space_3") if gap < 0 else gap)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_many(box, children)
	_apply_common_options(box, options)
	return box

func hbox(children: Array = [], gap: int = -1, options: Dictionary = {}) -> HBoxContainer:
	_validate_options("hbox", options)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", theme.spacing("space_3") if gap < 0 else gap)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_many(box, children)
	_apply_common_options(box, options)
	return box

func flow_row(children: Array = [], options: Dictionary = {}) -> HFlowContainer:
	_validate_options("flow_row", options)
	var flow := HFlowContainer.new()
	flow.name = "HermesFlowRow"
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", int(options.get("gap", theme.spacing("space_2"))))
	flow.add_theme_constant_override("v_separation", int(options.get("v_gap", options.get("gap", theme.spacing("space_2")))))
	add_many(flow, children)
	_apply_common_options(flow, options)
	return flow

func spacer(size: int = 8, vertical: bool = false) -> Control:
	var node := Control.new()
	node.name = "HermesSpacer"
	if vertical:
		node.custom_minimum_size = Vector2(1, size)
	else:
		node.custom_minimum_size = Vector2(size, 1)
	return node

func divider(options: Dictionary = {}) -> Control:
	_validate_options("divider", options)
	var line := ColorRect.new()
	line.name = "HermesDivider"
	line.color = options.get("color", theme.divider_color())
	var vertical: bool = bool(options.get("vertical", false))
	line.custom_minimum_size = Vector2(1, 0) if vertical else Vector2(0, 1)
	line.size_flags_horizontal = Control.SIZE_FILL if vertical else Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_EXPAND_FILL if vertical else Control.SIZE_FILL
	_apply_common_options(line, options)
	return line

func scroll_container(content: Control = null, options: Dictionary = {}) -> ScrollContainer:
	_validate_options("scroll_container", options)
	var scroll := ScrollContainer.new()
	scroll.name = "HermesScrollContainer"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if content != null:
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(content)
		scroll.set_meta(BODY_META, content)
	_apply_scrollbar_theme(scroll)
	_apply_common_options(scroll, options)
	return scroll

func split_view(left: Control, right: Control, sidebar_width: int = -1, options: Dictionary = {}) -> Control:
	_validate_options("split_view", options)
	var root := HBoxContainer.new()
	root.name = "HermesSplitView"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 0)
	var width: int = theme.size("sidebar_width") if sidebar_width < 0 else sidebar_width
	if left != null:
		left.custom_minimum_size = Vector2(width, left.custom_minimum_size.y)
		left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		left.size_flags_vertical = Control.SIZE_EXPAND_FILL
		root.add_child(left)
	root.add_child(divider({"vertical": true}))
	if right != null:
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.size_flags_vertical = Control.SIZE_EXPAND_FILL
		root.add_child(right)
	_apply_common_options(root, options)
	return root

# -----------------------------------------------------------------------------
# Surfaces / text / controls
# -----------------------------------------------------------------------------
func panel(children: Array = [], padding: int = -1, variant: String = "base", options: Dictionary = {}) -> PanelContainer:
	_validate_options("panel", options)
	var panel_node := PanelContainer.new()
	panel_node.name = "HermesPanel"
	var style_options: Dictionary = options.duplicate(true)
	if padding >= 0:
		style_options["padding"] = padding
	var is_elevated: bool = variant == "elevated" or str(options.get("variant", "")) == "elevated"
	if is_elevated:
		style_options["bg"] = theme.color("surface_2")
		style_options["elevation"] = int(options.get("elevation", 1))
	panel_node.add_theme_stylebox_override("panel", theme.panel_style(style_options))
	panel_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := vbox(children, int(options.get("gap", theme.spacing("space_3"))))
	body.name = "HermesPanelBody"
	panel_node.add_child(body)
	panel_node.set_meta(BODY_META, body)
	_apply_common_options(panel_node, options)
	return panel_node

func card(children: Array = [], padding: int = -1, options: Dictionary = {}) -> PanelContainer:
	_validate_options("card", options)
	var card_node := PanelContainer.new()
	card_node.name = "HermesCard"
	var style_options: Dictionary = options.duplicate(true)
	if padding >= 0:
		style_options["padding"] = padding
	# Cards have subtle depth by default; callers can set elevation=0 for flat cards.
	if not style_options.has("elevation"):
		style_options["elevation"] = 1
	card_node.add_theme_stylebox_override("panel", theme.card_style(style_options))
	card_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := vbox(children, int(options.get("gap", theme.spacing("space_3"))))
	body.name = "HermesCardBody"
	card_node.add_child(body)
	card_node.set_meta(BODY_META, body)
	_apply_common_options(card_node, options)
	return card_node

func label(text: String = "", variant: Variant = "body", options: Dictionary = {}) -> Label:
	if variant is Dictionary:
		options = (variant as Dictionary).duplicate(true)
		variant = str(options.get("variant", "body"))
	_validate_options("label", options)
	var node := Label.new()
	node.text = str(options.get("text", text))
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var autowrap_enabled: bool = bool(options.get("autowrap", false))
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if autowrap_enabled else TextServer.AUTOWRAP_OFF
	node.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING if autowrap_enabled else TextServer.OVERRUN_TRIM_ELLIPSIS
	if autowrap_enabled:
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_label_variant(node, str(variant))
	_apply_common_options(node, options)
	return node

func badge(text: String = "", kind: Variant = "info", options: Dictionary = {}) -> Control:
	if kind is Dictionary:
		options = (kind as Dictionary).duplicate(true)
		kind = str(options.get("kind", "info"))
	_validate_options("badge", options)
	var holder := PanelContainer.new()
	holder.name = "HermesBadge"
	holder.add_theme_stylebox_override("panel", theme.badge_style(str(kind), options))
	var text_label := label(text, {"variant": "status", "name": "HermesBadgeLabel"})
	text_label.add_theme_color_override("font_color", theme.kind_text_color(str(kind)))
	holder.add_child(text_label)
	holder.set_meta(BODY_META, text_label)
	_apply_common_options(holder, options)
	return holder

func path_breadcrumb(path: String = "", options: Dictionary = {}) -> Label:
	_validate_options("path_breadcrumb", options)
	var opts: Dictionary = options.duplicate(true)
	opts["text"] = path
	if not opts.has("name"):
		opts["name"] = "HermesPathBreadcrumb"
	if not opts.has("expand_h"):
		opts["expand_h"] = true
	var node: Label = label("", "body", opts)
	node.autowrap_mode = TextServer.AUTOWRAP_OFF
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return node

func button(text: String = "", on_pressed: Variant = Callable(), variant: String = "secondary", disabled: bool = false, options: Dictionary = {}) -> Button:
	if on_pressed is Dictionary:
		options = (on_pressed as Dictionary).duplicate(true)
		on_pressed = options.get("on_pressed", Callable())
		variant = str(options.get("variant", variant))
		disabled = bool(options.get("disabled", disabled))
	_validate_options("button", options)
	var node := Button.new()
	node.text = text
	node.disabled = disabled or bool(options.get("disabled", false))
	node.custom_minimum_size = Vector2(int(options.get("width", 0)), int(options.get("height", theme.component_size("button", str(options.get("size", "md"))))))
	node.add_theme_color_override("font_color", theme.color("text"))
	node.add_theme_color_override("font_disabled_color", theme.color("text_disabled"))
	_apply_button_styles(node, variant, options)
	var cb: Callable = on_pressed if on_pressed is Callable else Callable()
	if cb.is_valid():
		node.pressed.connect(cb)
	_attach_interactive_meta(node, text, "button", options)
	_apply_common_options(node, options)
	return node

func icon_button(icon: Variant = "", on_pressed: Variant = Callable(), variant: String = "ghost", disabled: bool = false, options: Dictionary = {}) -> Button:
	if icon is Dictionary:
		options = (icon as Dictionary).duplicate(true)
		icon = options.get("icon", "")
		on_pressed = options.get("on_pressed", Callable())
		variant = str(options.get("variant", variant))
		disabled = bool(options.get("disabled", disabled))
	var icon_options: Dictionary = options.duplicate(true)
	icon_options["width"] = int(icon_options.get("width", theme.component_size("button", "md")))
	icon_options["height"] = int(icon_options.get("height", theme.component_size("button", "md")))
	var node := button(str(icon), on_pressed, variant, disabled, icon_options)
	node.name = str(options.get("name", "HermesIconButton"))
	return node

func input(value: Variant = "", placeholder: String = "", on_change: Variant = Callable(), on_submit: Variant = Callable(), options: Dictionary = {}) -> LineEdit:
	if value is Dictionary:
		options = (value as Dictionary).duplicate(true)
		value = str(options.get("value", ""))
		placeholder = str(options.get("placeholder", ""))
		on_change = options.get("on_change", Callable())
		on_submit = options.get("on_submit", Callable())
	_validate_options("input", options)
	var node := LineEdit.new()
	node.text = str(value)
	node.placeholder_text = placeholder
	node.custom_minimum_size = Vector2(0, int(options.get("height", theme.component_size("input", str(options.get("size", "md"))))))
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.editable = not bool(options.get("disabled", false))
	node.add_theme_color_override("font_color", theme.color("text"))
	node.add_theme_color_override("font_placeholder_color", theme.color("text_faint"))
	node.add_theme_stylebox_override("normal", theme.input_style("normal"))
	node.add_theme_stylebox_override("focus", theme.input_style("focused"))
	node.add_theme_stylebox_override("read_only", theme.input_style("disabled"))
	var change_cb: Callable = on_change if on_change is Callable else Callable()
	var submit_cb: Callable = on_submit if on_submit is Callable else Callable()
	if change_cb.is_valid():
		node.text_changed.connect(change_cb)
	if submit_cb.is_valid():
		node.text_submitted.connect(submit_cb)
	_attach_interactive_meta(node, placeholder if placeholder != "" else str(value), "textbox", options)
	_apply_common_options(node, options)
	return node

func search_input(options: Dictionary = {}) -> LineEdit:
	_validate_options("search_input", options)
	var search: LineEdit = input(options)
	search.name = str(options.get("name", "HermesSearchInput"))
	search.placeholder_text = str(options.get("placeholder", "Search"))
	search.clear_button_enabled = true
	search.add_theme_stylebox_override("normal", theme.input_style("normal", {"radius": options.get("radius", "pill"), "padding_h": int(options.get("padding_h", 12))}))
	search.add_theme_stylebox_override("focus", theme.input_style("focused", {"radius": options.get("radius", "pill"), "padding_h": int(options.get("padding_h", 12))}))
	search.add_theme_stylebox_override("read_only", theme.input_style("disabled", {"radius": options.get("radius", "pill"), "padding_h": int(options.get("padding_h", 12))}))
	return search

func list_item(options: Dictionary = {}) -> Button:
	_validate_options("list_item", options)
	var title: String = str(options.get("text", options.get("title", options.get("id", "Item"))))
	var subtitle: String = str(options.get("subtitle", options.get("description", ""))).strip_edges()
	var label_text: String = title if subtitle == "" else "%s\n%s" % [title, subtitle]
	var selected: bool = bool(options.get("selected", false))
	var state: String = str(options.get("state", "selected" if selected else "normal"))
	var row: Button = button(label_text, {
		"variant": "ghost",
		"on_pressed": options.get("on_pressed", Callable()),
		"name": str(options.get("name", "HermesListItem")),
		"height": int(options.get("height", theme.size("list_row_height"))),
		"ref": str(options.get("ref", "")),
		"mcp_role": str(options.get("mcp_role", "listitem")),
		"mcp_actions": options.get("mcp_actions", ["press"]),
		"disabled": bool(options.get("disabled", false))
	})
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_theme_stylebox_override("normal", theme.list_row_style(state))
	row.add_theme_stylebox_override("hover", theme.list_row_style("hover"))
	row.add_theme_stylebox_override("pressed", theme.list_row_style("selected" if selected else "pressed"))
	row.add_theme_stylebox_override("focus", theme.button_style("ghost", "focused"))
	row.add_theme_color_override("font_color", theme.color("text" if selected else "text_muted"))
	row.add_theme_color_override("font_hover_color", theme.color("text"))
	_apply_common_options(row, options)
	return row

func sidebar_item(options: Dictionary = {}) -> Button:
	_validate_options("sidebar_item", options)
	var opts: Dictionary = options.duplicate(true)
	opts["name"] = str(options.get("name", "HermesSidebarItem"))
	opts["height"] = int(options.get("height", theme.size("list_row_height")))
	opts["mcp_role"] = str(options.get("mcp_role", "navigation_item"))
	var row: Button = list_item(opts)
	row.add_theme_font_size_override("font_size", theme.font_size("status"))
	return row

func text_area(value: Variant = "", placeholder: String = "", on_change: Variant = Callable(), options: Dictionary = {}) -> TextEdit:
	if value is Dictionary:
		options = (value as Dictionary).duplicate(true)
		value = str(options.get("value", ""))
		placeholder = str(options.get("placeholder", ""))
		on_change = options.get("on_change", Callable())
	_validate_options("text_area", options)
	var node := TextEdit.new()
	node.text = str(value)
	node.placeholder_text = placeholder
	node.custom_minimum_size = Vector2(0, int(options.get("height", 96)))
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL if bool(options.get("expand_v", false)) else Control.SIZE_FILL
	node.editable = not bool(options.get("readonly", false)) and not bool(options.get("disabled", false))
	node.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	node.add_theme_color_override("font_color", theme.color("text"))
	node.add_theme_color_override("font_placeholder_color", theme.color("text_faint"))
	node.add_theme_stylebox_override("normal", theme.text_area_style("normal"))
	node.add_theme_stylebox_override("focus", theme.text_area_style("focused"))
	node.add_theme_stylebox_override("read_only", theme.text_area_style("disabled"))
	var change_cb: Callable = on_change if on_change is Callable else Callable()
	if change_cb.is_valid():
		node.text_changed.connect(change_cb)
	_attach_interactive_meta(node, placeholder if placeholder != "" else "text area", "text_area", options)
	_apply_common_options(node, options)
	return node

func terminal_surface(options: Dictionary = {}) -> Control:
	_validate_options("terminal_surface", options)
	var surface = TerminalViewScript.new()
	surface.terminal_view_init({"shell": options.get("shell", null)})
	surface.name = str(options.get("name", "HermesTerminalSurface"))
	_apply_common_options(surface, options)
	if surface.size_flags_horizontal == Control.SIZE_FILL:
		surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if surface.size_flags_vertical == Control.SIZE_FILL:
		surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return surface

func browser_surface(options: Dictionary = {}) -> Control:
	_validate_options("browser_surface", options)
	var surface = BrowserContentSurfaceScript.new()
	surface.name = str(options.get("name", "HermesBrowserSurface"))
	if surface.has_method("set_chrome_visible"):
		surface.call("set_chrome_visible", false)
	_apply_common_options(surface, options)
	if surface.size_flags_horizontal == Control.SIZE_FILL:
		surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if surface.size_flags_vertical == Control.SIZE_FILL:
		surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return surface

# -----------------------------------------------------------------------------
# Form controls
# -----------------------------------------------------------------------------
func dropdown(items: Array = [], options: Dictionary = {}) -> OptionButton:
	_validate_options("dropdown", options)
	var node := OptionButton.new()
	node.name = "HermesDropdown"
	node.custom_minimum_size = Vector2(int(options.get("width", 0)), int(options.get("height", theme.size("input_height"))))
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in items:
		var data: Dictionary = _item_to_dictionary(item)
		node.add_item(str(data.get("text", data.get("label", data.get("id", "Item")))))
		var idx: int = node.item_count - 1
		node.set_item_metadata(idx, str(data.get("id", idx)))
	var selected_id: String = str(options.get("selected_id", options.get("value", "")))
	if selected_id != "":
		for i in node.item_count:
			if str(node.get_item_metadata(i)) == selected_id or node.get_item_text(i) == selected_id:
				node.select(i)
				break
	node.add_theme_color_override("font_color", theme.color("text"))
	node.add_theme_color_override("font_disabled_color", theme.color("text_disabled"))
	node.add_theme_stylebox_override("normal", theme.input_style("normal"))
	node.add_theme_stylebox_override("hover", theme.input_style("normal"))
	node.add_theme_stylebox_override("focus", theme.input_style("focused"))
	node.add_theme_stylebox_override("disabled", theme.input_style("disabled"))
	var popup: PopupMenu = node.get_popup()
	if popup != null:
		popup.add_theme_stylebox_override("panel", theme.option_popup_style())
		popup.add_theme_color_override("font_color", theme.color("text"))
		popup.add_theme_color_override("font_hover_color", theme.color("text"))
	var cb: Callable = options.get("on_change", options.get("on_item_selected", Callable()))
	if cb.is_valid():
		node.item_selected.connect(func(index: int) -> void:
			var id_value: Variant = node.get_item_metadata(index)
			cb.call(index, str(id_value))
		)
	_attach_interactive_meta(node, str(options.get("label", "dropdown")), "combobox", options)
	_apply_common_options(node, options)
	return node

func slider(options: Dictionary = {}) -> HSlider:
	_validate_options("slider", options)
	var node := HSlider.new()
	node.name = "HermesSlider"
	node.min_value = float(options.get("min", 0.0))
	node.max_value = float(options.get("max", 1.0))
	node.step = float(options.get("step", 0.01))
	node.value = float(options.get("value", node.min_value))
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_stylebox_override("slider", theme.slider_track_style())
	node.add_theme_stylebox_override("grabber_area", theme.slider_track_style())
	node.add_theme_stylebox_override("grabber_area_highlight", theme.slider_track_style())
	node.add_theme_stylebox_override("grabber", theme.slider_grabber_style())
	node.add_theme_stylebox_override("grabber_highlight", theme.slider_grabber_style("hover"))
	node.add_theme_stylebox_override("grabber_disabled", theme.slider_grabber_style("disabled"))
	var cb: Callable = options.get("on_change", options.get("on_value_changed", Callable()))
	if cb.is_valid():
		node.value_changed.connect(cb)
	_attach_interactive_meta(node, str(options.get("label", "slider")), "slider", options)
	_apply_common_options(node, options)
	return node

func toggle(text: String = "", options: Dictionary = {}) -> CheckBox:
	_validate_options("toggle", options)
	var node := CheckBox.new()
	node.name = "HermesToggle"
	node.text = text
	node.button_pressed = bool(options.get("pressed", options.get("checked", false)))
	node.add_theme_color_override("font_color", theme.color("text"))
	var cb: Callable = options.get("on_toggled", options.get("on_change", Callable()))
	if cb.is_valid():
		node.toggled.connect(cb)
	_attach_interactive_meta(node, text, "checkbox", options)
	_apply_common_options(node, options)
	return node

func radio_group(items: Array = [], options: Dictionary = {}) -> Control:
	_validate_options("radio_group", options)
	var root := vbox([], int(options.get("gap", theme.spacing("space_1"))), {"name": "HermesRadioGroup", "expand_h": bool(options.get("expand_h", false))})
	var group := ButtonGroup.new()
	var selected_id: String = str(options.get("selected_id", options.get("value", "")))
	var cb: Callable = options.get("on_change", Callable())
	for item in items:
		var data: Dictionary = _item_to_dictionary(item)
		var item_id: String = str(data.get("id", data.get("text", "")))
		var radio := CheckBox.new()
		radio.text = str(data.get("text", item_id))
		radio.button_group = group
		radio.button_pressed = item_id == selected_id
		radio.add_theme_color_override("font_color", theme.color("text"))
		if cb.is_valid():
			radio.toggled.connect(func(pressed: bool) -> void:
				if pressed:
					cb.call(item_id)
			)
		root.add_child(radio)
	_apply_common_options(root, options)
	return root

func settings_row(row_label: String = "", control: Control = null, options: Dictionary = {}) -> Control:
	_validate_options("settings_row", options)
	var label_width: int = int(options.get("label_width", 116))
	var text_label := label(row_label, {"variant": str(options.get("label_variant", "body")), "min_size": Vector2(label_width, 0)})
	var row := hbox([text_label], int(options.get("gap", theme.spacing("form_row_gap"))), {"name": "HermesSettingsRow", "expand_h": true})
	if control == null:
		if OS.is_debug_build():
			push_warning("HermesUI settings_row missing control for %s" % row_label)
		control = label("Unavailable", {"variant": "faint", "name": "HermesSettingsRowPlaceholder", "expand_h": true})
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	_apply_common_options(row, options)
	return row

func form_group(title: String = "", rows: Array = [], options: Dictionary = {}) -> Control:
	_validate_options("form_group", options)
	var children: Array = []
	if title != "":
		children.append(section_header(title, str(options.get("body", ""))))
	for row in rows:
		if row is Control:
			children.append(row)
	return card(children, int(options.get("padding", theme.spacing("card"))), {"name": str(options.get("name", "HermesFormGroup")), "gap": int(options.get("gap", theme.spacing("space_2")))})

# -----------------------------------------------------------------------------
# App structures / feedback
# -----------------------------------------------------------------------------
func toolbar(children: Array = [], options: Dictionary = {}) -> Control:
	_validate_options("toolbar", options)
	var bar := PanelContainer.new()
	bar.name = "HermesToolbar"
	# Toolbar: surface bg, visible bottom border separator, no radius
	bar.add_theme_stylebox_override("panel", theme.panel_style({"bg": theme.color("bg_elevated"), "border": theme.color("border_soft"), "radius": 0, "padding": 0, "border_width": 0}))
	# Add a bottom border via style override
	var toolbar_style: StyleBoxFlat = bar.get_theme_stylebox("panel") as StyleBoxFlat
	if toolbar_style != null:
		toolbar_style.border_width_bottom = 1
	bar.custom_minimum_size = Vector2(0, int(options.get("height", theme.size("toolbar_height"))))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := hbox(children, int(options.get("gap", theme.spacing("toolbar_gap"))))
	row.name = "HermesToolbarRow"
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar.add_child(row)
	bar.set_meta(BODY_META, row)
	_apply_common_options(bar, options)
	return bar

func sidebar(children: Array = [], width: int = -1, options: Dictionary = {}) -> Control:
	var opts: Dictionary = {"bg": theme.color("bg_elevated"), "border": theme.color("border_soft"), "border_width": 0, "radius": 0, "gap": int(options.get("gap", theme.spacing("space_2")))}
	for key in options.keys():
		opts[key] = options[key]
	var node := panel(children, int(options.get("padding", theme.spacing("panel"))), "base", opts)
	node.name = "HermesSidebar"
	node.custom_minimum_size = Vector2(theme.size("sidebar_width") if width < 0 else width, 0)
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_common_options(node, options)
	return node

func status_bar(text: String = "", kind: String = "info", options: Dictionary = {}) -> Control:
	_validate_options("status_bar", options)
	var bar := PanelContainer.new()
	bar.name = "HermesStatusBar"
	bar.custom_minimum_size = Vector2(0, int(options.get("height", theme.size("status_bar_height"))))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Status bar: recessed/darker bg with top border, clearly below content
	bar.add_theme_stylebox_override("panel", theme.panel_style({"bg": theme.color("bg"), "border": theme.color("border"), "radius": 0, "padding": 0, "border_width": 0}))
	# Add top border separator
	var status_style: StyleBoxFlat = bar.get_theme_stylebox("panel") as StyleBoxFlat
	if status_style != null:
		status_style.border_width_top = 1
	var row := hbox([], int(options.get("gap", theme.spacing("space_2"))))
	row.name = "HermesStatusRow"
	var status_label := label(text, {"variant": "status", "name": "HermesStatusText"})
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.add_theme_color_override("font_color", theme.kind_text_color(kind))
	row.add_child(status_label)
	bar.add_child(row)
	bar.set_meta(BODY_META, row)
	bar.set_meta("status_label", status_label)
	_apply_common_options(bar, options)
	return bar

func section_header(title: String = "", body_text: String = "", options: Dictionary = {}) -> Control:
	var children: Array = [label(title, {"variant": str(options.get("variant", "heading")), "name": str(options.get("title_name", "HermesSectionTitle"))})]
	if body_text != "":
		children.append(label(body_text, {"variant": "muted", "autowrap": true, "name": str(options.get("body_name", "HermesSectionBody"))}))
	return vbox(children, theme.spacing("space_1"), {"name": str(options.get("name", "HermesSectionHeader")), "expand_h": true})

func empty_state(title: String = "", body_text: String = "", options: Dictionary = {}) -> Control:
	var icon_text: String = str(options.get("icon", "·"))
	var children: Array = [label(icon_text, {"variant": "faint", "name": "HermesEmptyIcon"}), label(title, {"variant": "heading", "name": "HermesEmptyTitle"})]
	if body_text != "":
		children.append(label(body_text, {"variant": "muted", "autowrap": true, "name": "HermesEmptyBody"}))
	return panel(children, int(options.get("padding", theme.spacing("panel"))), "base", {"name": str(options.get("name", "HermesEmptyState")), "bg": DesignTokens.alpha(theme.color("surface"), 0.4), "border": theme.color("border_soft")})

func progress_bar(options: Dictionary = {}) -> ProgressBar:
	_validate_options("progress_bar", options)
	var node := ProgressBar.new()
	node.name = "HermesProgressBar"
	node.min_value = float(options.get("min", 0.0))
	node.max_value = float(options.get("max", 100.0))
	node.value = float(options.get("value", 0.0))
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_stylebox_override("background", theme.progress_bg_style())
	node.add_theme_stylebox_override("fill", theme.progress_fill_style(str(options.get("kind", "info"))))
	node.add_theme_color_override("font_color", theme.color("text"))
	_apply_common_options(node, options)
	return node

func loading_indicator(options: Dictionary = {}) -> Control:
	var text: String = str(options.get("text", "Loading…"))
	return badge(text, {"kind": str(options.get("kind", "busy")), "name": str(options.get("name", "HermesLoadingIndicator"))})

func alert(message: String = "", options: Dictionary = {}) -> Control:
	var kind: String = str(options.get("kind", "info"))
	var title_text: String = str(options.get("title", ""))
	var children: Array = []
	if title_text != "":
		children.append(label(title_text, {"variant": kind if kind != "error" else "danger"}))
	children.append(label(message, {"variant": "body", "autowrap": true}))
	return panel(children, int(options.get("padding", theme.spacing("card"))), "base", {"name": str(options.get("name", "HermesAlert")), "bg": DesignTokens.alpha(theme.kind_color(kind), 0.12), "border": DesignTokens.alpha(theme.kind_color(kind), 0.45)})

func message_item(sender: String = "", text: String = "", kind: Variant = "user", options: Dictionary = {}) -> Control:
	if kind is Dictionary:
		options = (kind as Dictionary).duplicate(true)
		kind = str(options.get("kind", "user"))
	_validate_options("message_item", options)
	var style_options := options.duplicate(true)
	# User messages: right-aligned feel, active surface bg, visible border
	# Hermes messages: surface_2 bg with accent border accent
	# System messages: warning-tinted
	# Error messages: error-tinted
	var alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
	match str(kind):
		"user":
			style_options["bg"] = theme.color("surface_3")
			style_options["border"] = theme.color("border_active")
			alignment = HORIZONTAL_ALIGNMENT_RIGHT
		"hermes":
			style_options["bg"] = theme.color("surface_2")
			style_options["border"] = DesignTokens.alpha(theme.color("accent"), 0.35)
		"system":
			style_options["bg"] = DesignTokens.alpha(theme.color("warning"), 0.10)
			style_options["border"] = DesignTokens.alpha(theme.color("warning"), 0.40)
		"error":
			style_options["bg"] = DesignTokens.alpha(theme.color("error"), 0.10)
			style_options["border"] = DesignTokens.alpha(theme.color("error"), 0.40)
		_:
			style_options["bg"] = theme.color("surface_2")
	var sender_label := label(sender, {"variant": "status", "name": "HermesMessageSender"})
	sender_label.add_theme_color_override("font_color", theme.color("accent") if str(kind) == "hermes" else theme.color("text_muted"))
	var body_text: String = str(options.get("body", options.get("content", options.get("text", text))))
	var body_label := label(body_text, {"variant": "body", "name": "HermesMessageBody", "autowrap": true, "expand_h": true})
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var children: Array = [sender_label, body_label]
	if str(options.get("timestamp", "")) != "":
		children.append(label(str(options.get("timestamp", "")), {"variant": "faint", "name": "HermesMessageTimestamp"}))
	var padding: int = int(options.get("padding", 14))
	var wrapper := card(children, padding, style_options)
	wrapper.name = "HermesMessageItem"
	return wrapper

func list_view(items: Array = [], options: Dictionary = {}) -> ScrollContainer:
	_validate_options("list_view", options)
	var selected_id: String = str(options.get("selected_id", ""))
	var on_select: Callable = options.get("on_select", Callable())
	var scroll := scroll_container(null, {"name": str(options.get("name", "HermesList")), "expand_h": true, "expand_v": true})
	var rows := vbox([], int(options.get("gap", 2)), {"name": "HermesListRows", "expand_h": true})
	scroll.add_child(rows)
	scroll.set_meta(BODY_META, rows)
	scroll.set_meta(SELECTED_META, selected_id)
	_rebuild_list_rows(rows, items, selected_id, on_select, options)
	_apply_common_options(scroll, options)
	return scroll

func list(items: Array = [], selected_id: String = "", on_select: Callable = Callable(), options: Dictionary = {}) -> ScrollContainer:
	var opts: Dictionary = options.duplicate(true)
	opts["selected_id"] = selected_id
	opts["on_select"] = on_select
	return list_view(items, opts)

func file_list(options: Dictionary = {}) -> ScrollContainer:
	_validate_options("file_list", options)
	var scroll := scroll_container(null, {"name": str(options.get("name", "HermesFileList")), "expand_h": true, "expand_v": true})
	var rows := vbox([], int(options.get("gap", 4)), {"name": "HermesFileListRows", "expand_h": true})
	scroll.add_child(rows)
	scroll.set_meta(BODY_META, rows)
	scroll.add_theme_stylebox_override("panel", theme.panel_style({"bg": theme.color("surface"), "border": theme.color("border_soft"), "radius": theme.radius("lg"), "padding": 0}))
	_apply_common_options(scroll, options)
	return scroll

func file_row(options: Dictionary = {}) -> Button:
	_validate_options("file_row", options)
	# `name` in factory options is reserved for the control node name (e.g. HermesRenderFileRow).
	# Visible file/folder text must come from bound row data, never the control name.
	var entry_name_text: String = str(options.get("text", options.get("label", options.get("id", ""))))
	var modified_text: String = str(options.get("modified", "—"))
	var size_text: String = str(options.get("size", ""))
	var combined_text: String = "%s  |  %s  |  %s" % [entry_name_text, modified_text, size_text]
	var row_options: Dictionary = options.duplicate(true)
	row_options["text"] = combined_text
	row_options["height"] = int(options.get("height", theme.size("list_row_height")))
	row_options["mcp_role"] = str(options.get("mcp_role", "file" if str(options.get("type", "file")) == "file" else "folder"))
	return list_item(row_options)

func rebuild_list(list_control: Control, items: Array, options: Dictionary = {}) -> void:
	var rows: Control = body_of(list_control)
	if rows == null:
		return
	clear_children(list_control)
	_rebuild_list_rows(rows as Container, items, str(options.get("selected_id", get_selected_id(list_control))), options.get("on_select", Callable()), options)

func get_selected_id(list_control: Control) -> String:
	if list_control == null:
		return ""
	if list_control is OptionButton:
		var dropdown: OptionButton = list_control as OptionButton
		var selected_index: int = dropdown.selected
		if selected_index >= 0:
			return str(dropdown.get_item_metadata(selected_index))
	return str(list_control.get_meta(SELECTED_META, ""))

func set_selected_id(list_control: Control, id: String) -> void:
	if list_control != null:
		list_control.set_meta(SELECTED_META, id)
		_restyle_list_selection(list_control, id)

func set_list_items(list_control: Control, items: Array, options: Dictionary = {}) -> void:
	if list_control == null:
		return
	var opts: Dictionary = options.duplicate(true)
	if opts.has("selected_id"):
		set_selected_id(list_control, str(opts["selected_id"]))
	rebuild_list(list_control, items, opts)

func tabs(items: Array = [], active_id: Variant = "", on_change: Variant = Callable(), options: Dictionary = {}) -> Control:
	if active_id is Dictionary:
		options = (active_id as Dictionary).duplicate(true)
		active_id = str(options.get("active_id", ""))
		on_change = options.get("on_change", Callable())
	_validate_options("tabs", options)
	var row := hbox([], int(options.get("gap", 4)), options)
	row.name = "HermesTabs"
	row.custom_minimum_size = Vector2(0, theme.size("tab_height"))
	row.set_meta(ACTIVE_TAB_META, str(active_id))
	for item in items:
		var data := _item_to_dictionary(item)
		var tab_id := str(data.get("id", data.get("text", "")))
		# Active tabs use accent variant to stand out; inactive use ghost
		var tab_variant := "primary" if tab_id == str(active_id) else "ghost"
		var tab_button := button(str(data.get("text", tab_id)), Callable(), tab_variant, false, {"height": theme.size("tab_height"), "mcp_role": "tab", "ref": data.get("ref", "")})
		var cb: Callable = on_change if on_change is Callable else Callable()
		if cb.is_valid():
			tab_button.pressed.connect(func() -> void:
				row.set_meta(ACTIVE_TAB_META, tab_id)
				cb.call(tab_id)
			)
		row.add_child(tab_button)
	return row

func get_active_tab(tab_control: Control) -> String:
	return str(tab_control.get_meta(ACTIVE_TAB_META, "")) if tab_control != null else ""

func set_active_tab(tab_control: Control, id: String) -> void:
	if tab_control != null:
		tab_control.set_meta(ACTIVE_TAB_META, id)

# -----------------------------------------------------------------------------
# Shell chrome scaffolding
# -----------------------------------------------------------------------------
func taskbar(options: Dictionary = {}) -> Control:
	var left: Array = options.get("left", []) if options.get("left", []) is Array else []
	var center: Array = options.get("center", []) if options.get("center", []) is Array else []
	var right: Array = options.get("right", []) if options.get("right", []) is Array else []
	var left_slot := hbox(left, theme.spacing("space_2"), {"name": "HermesTaskbarLeft"})
	var center_slot := hbox(center, theme.spacing("space_2"), {"name": "HermesTaskbarCenter", "expand_h": true})
	var right_slot := hbox(right, theme.spacing("space_2"), {"name": "HermesTaskbarRight"})
	return panel([hbox([left_slot, center_slot, right_slot], theme.spacing("space_2"), {"expand_h": true})], 8, "base", {"name": str(options.get("name", "HermesTaskbar")), "height": int(options.get("height", theme.size("taskbar_height"))), "radius": "xl"})

func taskbar_item(app_id: String, title: String, icon: Variant = "", options: Dictionary = {}) -> Button:
	var state: String = str(options.get("state", "running"))
	var variant: String = "secondary" if state == "focused" else "ghost"
	var label_text: String = (str(icon) + " " + title).strip_edges()
	return button(label_text, {"variant": variant, "on_pressed": options.get("on_pressed", Callable()), "name": str(options.get("name", "HermesTaskbarItem")), "ref": str(options.get("ref", "shell.taskbar." + app_id)), "mcp_role": "taskbar_item", "mcp_actions": ["press"], "height": theme.size("button_height")})

func launcher_menu(options: Dictionary = {}) -> Control:
	var children: Array = []
	if options.has("search") and options["search"] is Control:
		children.append(options["search"])
	if options.has("content") and options["content"] is Control:
		children.append(options["content"])
	if options.has("footer") and options["footer"] is Control:
		children.append(options["footer"])
	return panel(children, int(options.get("padding", theme.spacing("panel"))), "elevated", {"name": str(options.get("name", "HermesLauncherMenu")), "min_size": options.get("min_size", Vector2(420, 480))})

func launcher_grid(apps: Array = [], options: Dictionary = {}) -> Control:
	var flow := flow_row([], {"name": str(options.get("name", "HermesLauncherGrid")), "gap": theme.spacing("space_2")})
	for app in apps:
		var data: Dictionary = _item_to_dictionary(app)
		flow.add_child(button(str(data.get("icon", "□")) + " " + str(data.get("title", data.get("name", data.get("id", "App")))), {"variant": "ghost", "on_pressed": data.get("on_pressed", Callable()), "ref": data.get("ref", ""), "mcp_role": "launcher_item"}))
	return flow

func tray(options: Dictionary = {}) -> Control:
	var children: Array = options.get("children", []) if options.get("children", []) is Array else []
	return hbox(children, theme.spacing("space_2"), {"name": str(options.get("name", "HermesTray"))})

func notification_toast(message: String = "", options: Dictionary = {}) -> Control:
	var kind: String = str(options.get("kind", "info"))
	var title_text: String = str(options.get("title", ""))
	var children: Array = []
	if title_text != "":
		children.append(label(title_text, {"variant": kind if kind != "error" else "danger"}))
	children.append(label(message, {"variant": "body", "autowrap": true}))
	return panel(children, int(options.get("padding", theme.spacing("card"))), "elevated", {"name": str(options.get("name", "HermesNotificationToast")), "bg": DesignTokens.alpha(theme.kind_color(kind), 0.12), "border": theme.kind_color(kind), "elevation": 2})

func context_menu(items: Array = [], options: Dictionary = {}) -> Control:
	var root := panel([], int(options.get("padding", theme.spacing("space_2"))), "elevated", {"name": str(options.get("name", "HermesContextMenu")), "radius": "md", "elevation": 2})
	for item in items:
		var data: Dictionary = _item_to_dictionary(item)
		if bool(data.get("separator", false)):
			add(root, divider())
		else:
			add(root, button(str(data.get("text", data.get("label", "Item"))), {"variant": "ghost", "disabled": bool(data.get("disabled", false)), "on_pressed": data.get("on_pressed", Callable()), "mcp_role": "menuitem"}))
	return root

func desktop_icon(icon_label: String = "", icon: Variant = "", options: Dictionary = {}) -> Control:
	var selected: bool = bool(options.get("selected", false))
	var icon_text := label(str(icon), {"variant": "heading", "name": "HermesDesktopIconGlyph"})
	var text_label := label(icon_label, {"variant": "status", "name": "HermesDesktopIconLabel", "autowrap": true})
	var node := panel([icon_text, text_label], 6, "base", {"name": str(options.get("name", "HermesDesktopIcon")), "bg": theme.color("accent_soft") if selected else Color.TRANSPARENT, "border": theme.color("accent") if selected else Color.TRANSPARENT, "radius": "md", "ref": options.get("ref", ""), "mcp_role": "desktop_icon"})
	return node

func window_titlebar(title: String = "", options: Dictionary = {}) -> Control:
	var icon_text: String = str(options.get("icon", ""))
	var title_label := label((icon_text + " " + title).strip_edges(), {"variant": "heading", "name": "HermesWindowTitle"})
	var filler := Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var controls: Control = options.get("controls", window_controls(options)) if options.get("controls", null) is Control else window_controls(options)
	return toolbar([title_label, filler, controls], {"name": str(options.get("name", "HermesWindowTitlebar")), "height": int(options.get("height", theme.size("window_titlebar_height")))})

func window_controls(options: Dictionary = {}) -> Control:
	var min_btn := icon_button("−", {"name": "HermesWindowMinimize", "on_pressed": options.get("on_minimize", Callable()), "mcp_role": "button"})
	var max_btn := icon_button("□", {"name": "HermesWindowMaximize", "on_pressed": options.get("on_maximize", Callable()), "mcp_role": "button"})
	var close_btn := icon_button("×", {"name": "HermesWindowClose", "variant": "danger", "on_pressed": options.get("on_close", Callable()), "mcp_role": "button"})
	return hbox([min_btn, max_btn, close_btn], theme.spacing("space_1"), {"name": str(options.get("name", "HermesWindowControls"))})

# -----------------------------------------------------------------------------
# Internals
# -----------------------------------------------------------------------------
func _apply_button_styles(node: Button, variant: String, options: Dictionary) -> void:
	node.add_theme_stylebox_override("normal", theme.button_style(variant, "normal", options))
	node.add_theme_stylebox_override("hover", theme.button_style(variant, "hover", options))
	node.add_theme_stylebox_override("pressed", theme.button_style(variant, "pressed", options))
	node.add_theme_stylebox_override("disabled", theme.button_style(variant, "disabled", options))
	node.add_theme_stylebox_override("focus", theme.button_style(variant, "focused", options))
	# Apply on_accent text color if the style specifies one
	var normal_style: StyleBoxFlat = theme.button_style(variant, "normal", options)
	if normal_style.has_meta("hermes_ui_text_color"):
		var tc: Variant = normal_style.get_meta("hermes_ui_text_color")
		if tc is Color:
			node.add_theme_color_override("font_color", tc as Color)
			node.add_theme_color_override("font_hover_color", tc as Color)
			node.add_theme_color_override("font_pressed_color", tc as Color)

func _apply_label_variant(node: Label, variant: String) -> void:
	var color_name := "text"
	var size_name: Variant = "text_base"
	match variant:
		"title":
			size_name = "text_xl"
		"heading":
			size_name = "text_lg"
		"muted":
			color_name = "text_muted"
		"faint":
			color_name = "text_faint"
		"mono":
			size_name = "terminal"
		"status":
			size_name = "status"
			color_name = "text_muted"
		"danger", "error":
			color_name = "danger"
		"success":
			color_name = "success"
		"warning":
			color_name = "warning"
		"info":
			color_name = "info"
		_:
			size_name = "text_base"
	node.add_theme_font_size_override("font_size", theme.font_size(size_name))
	node.add_theme_color_override("font_color", theme.color(color_name))

func _apply_common_options(node: Control, options: Dictionary) -> void:
	if options.has("name"):
		node.name = str(options["name"])
	if options.has("tooltip"):
		node.tooltip_text = str(options["tooltip"])
	if options.has("visible"):
		node.visible = bool(options["visible"])
	if options.has("min_size") and options["min_size"] is Vector2:
		node.custom_minimum_size = options["min_size"]
	elif options.has("width") or options.has("height"):
		node.custom_minimum_size = Vector2(int(options.get("width", node.custom_minimum_size.x)), int(options.get("height", node.custom_minimum_size.y)))
	if bool(options.get("expand_h", false)):
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if bool(options.get("expand_v", false)):
		node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if options.has("size_flags_h"):
		node.size_flags_horizontal = int(options["size_flags_h"])
	if options.has("size_flags_v"):
		node.size_flags_vertical = int(options["size_flags_v"])
	if options.has("ref") or options.has("mcp_role") or options.has("mcp_actions"):
		var meta := {
			"ref": str(options.get("ref", "")),
			"role": str(options.get("mcp_role", "")),
			"label": str(options.get("mcp_label", options.get("label", node.name))),
			"actions": options.get("mcp_actions", []),
			"enabled": bool(options.get("mcp_enabled", not bool(options.get("disabled", false)))),
			"visible": node.visible
		}
		HermesRefsScript.attach_meta(node, meta)
	if options.has("meta") and options["meta"] is Dictionary:
		for key in (options["meta"] as Dictionary).keys():
			node.set_meta(str(key), (options["meta"] as Dictionary)[key])

func _attach_interactive_meta(node: Control, label_text: String, role: String, options: Dictionary) -> void:
	var meta := {
		"ref": str(options.get("ref", "")),
		"role": str(options.get("mcp_role", role)),
		"label": str(options.get("mcp_label", options.get("label", label_text))),
		"actions": options.get("mcp_actions", ["press"] if role == "button" else []),
		"enabled": not bool(options.get("disabled", false)),
		"visible": node.visible
	}
	if meta["ref"] != "" or meta["role"] != "":
		HermesRefsScript.attach_meta(node, meta)

func _item_to_dictionary(item: Variant) -> Dictionary:
	if item is Dictionary:
		return (item as Dictionary).duplicate(true)
	return {"id": str(item), "text": str(item)}

func _rebuild_list_rows(rows: Container, items: Array, selected_id: String, on_select: Callable, options: Dictionary) -> void:
	if rows == null:
		return
	if items.is_empty():
		rows.add_child(empty_state(str(options.get("empty_text", "No items")), "", {"name": "HermesListEmpty"}))
		return
	for item in items:
		var data := _item_to_dictionary(item)
		if data.has("node") and data["node"] is Control:
			var custom_row := data["node"] as Control
			custom_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rows.add_child(custom_row)
			continue
		var item_id := str(data.get("id", data.get("text", "")))
		var row_button := list_item({
			"id": item_id,
			"text": str(data.get("text", item_id)),
			"subtitle": str(data.get("subtitle", "")),
			"selected": item_id == selected_id,
			"name": "HermesListRow",
			"height": theme.size("list_row_height"),
			"ref": data.get("ref", ""),
			"mcp_role": "listitem"
		})
		row_button.set_meta("hermes_ui_item_id", item_id)
		if on_select.is_valid():
			row_button.pressed.connect(func() -> void:
				var owner_list: Control = rows.get_parent() as Control
				if owner_list != null:
					set_selected_id(owner_list, item_id)
				on_select.call(item_id)
			)
		rows.add_child(row_button)

func _apply_scrollbar_theme(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	var vbar: VScrollBar = scroll.get_v_scroll_bar()
	if vbar != null:
		vbar.custom_minimum_size.x = 10
		vbar.add_theme_stylebox_override("scroll", theme.scrollbar_track_style())
		vbar.add_theme_stylebox_override("grabber", theme.scrollbar_grabber_style())
		vbar.add_theme_stylebox_override("grabber_highlight", theme.scrollbar_grabber_style("hover"))
		vbar.add_theme_stylebox_override("grabber_pressed", theme.scrollbar_grabber_style("pressed"))
	var hbar: HScrollBar = scroll.get_h_scroll_bar()
	if hbar != null:
		hbar.custom_minimum_size.y = 10
		hbar.add_theme_stylebox_override("scroll", theme.scrollbar_track_style())
		hbar.add_theme_stylebox_override("grabber", theme.scrollbar_grabber_style())
		hbar.add_theme_stylebox_override("grabber_highlight", theme.scrollbar_grabber_style("hover"))
		hbar.add_theme_stylebox_override("grabber_pressed", theme.scrollbar_grabber_style("pressed"))

func _restyle_list_selection(list_control: Control, selected_id: String) -> void:
	var rows: Control = body_of(list_control)
	if rows == null:
		return
	for child in rows.get_children():
		if child is Button:
			var row: Button = child as Button
			var item_id: String = str(row.get_meta("hermes_ui_item_id", ""))
			var selected: bool = item_id != "" and item_id == selected_id
			row.add_theme_stylebox_override("normal", theme.list_row_style("selected" if selected else "normal"))
			row.add_theme_stylebox_override("pressed", theme.list_row_style("selected" if selected else "pressed"))
			row.add_theme_color_override("font_color", theme.color("text" if selected else "text_muted"))

func _validate_options(component: String, options: Dictionary) -> void:
	if not OS.is_debug_build():
		return
	for key in options.keys():
		if not COMMON_OPTIONS.has(str(key)):
			push_warning("HermesUI %s unknown option: %s" % [component, str(key)])
