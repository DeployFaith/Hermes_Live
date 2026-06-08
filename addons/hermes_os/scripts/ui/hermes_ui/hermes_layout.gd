class_name HermesLayout
extends RefCounted

const HermesThemeScript = preload("res://addons/hermes_os/scripts/ui/hermes_ui/hermes_theme.gd")
const HermesComponentFactoryScript = preload("res://addons/hermes_os/scripts/ui/hermes_ui/hermes_component_factory.gd")

var theme = null
var ui = null

func _init(p_theme = null, p_ui = null) -> void:
	theme = p_theme if p_theme != null else HermesThemeScript.new()
	ui = p_ui if p_ui != null else HermesComponentFactoryScript.new(theme)

func basic_app(toolbar: Control, content: Control, status: Control, options: Dictionary = {}) -> Control:
	var root := _root("HermesBasicApp", options)
	_add_fixed(root, toolbar, theme.size("toolbar_height"))
	_add_expanding(root, content)
	_add_fixed(root, status, theme.size("status_bar_height"))
	return root

func sidebar_app(toolbar: Control, sidebar: Control, content: Control, status: Control, options: Dictionary = {}) -> Control:
	var root := _root("HermesSidebarApp", options)
	_add_fixed(root, toolbar, theme.size("toolbar_height"))
	var split: Control = ui.split_view(sidebar, content, int(options.get("sidebar_width", theme.size("sidebar_width"))))
	_add_expanding(root, split)
	_add_fixed(root, status, theme.size("status_bar_height"))
	return root

func chat_app(toolbar: Control, message_list: Control, composer: Control, status: Control, options: Dictionary = {}) -> Control:
	var root := _root("HermesChatLayout", options)
	_add_fixed(root, toolbar, theme.size("toolbar_height"))
	_add_expanding(root, message_list)
	if composer != null:
		composer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		composer.size_flags_vertical = Control.SIZE_SHRINK_END
		root.add_child(composer)
	_add_fixed(root, status, theme.size("status_bar_height"))
	return root

func _root(name_value: String, options: Dictionary) -> VBoxContainer:
	var root := VBoxContainer.new()
	root.name = name_value
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", int(options.get("gap", 0)))
	root.add_theme_stylebox_override("panel", theme.panel_style({"bg": theme.color("bg"), "border": Color.TRANSPARENT, "border_width": 0, "radius": 0, "padding": 0}))
	return root

func _add_fixed(root: VBoxContainer, node: Control, height: int) -> void:
	if node == null:
		return
	node.custom_minimum_size = Vector2(node.custom_minimum_size.x, height)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_FILL
	root.add_child(node)

func _add_expanding(root: VBoxContainer, node: Control) -> void:
	if node == null:
		return
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(node)
