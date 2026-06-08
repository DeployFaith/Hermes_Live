extends Control

const HermesTheme = preload("res://addons/hermes_os/scripts/ui/hermes_ui/hermes_theme.gd")
const HermesComponentFactory = preload("res://addons/hermes_os/scripts/ui/hermes_ui/hermes_component_factory.gd")
const HermesLayout = preload("res://addons/hermes_os/scripts/ui/hermes_ui/hermes_layout.gd")

var hermes_theme: HermesTheme
var ui: HermesComponentFactory
var layout: HermesLayout

func _ready() -> void:
	hermes_theme = HermesTheme.new()
	ui = HermesComponentFactory.new(hermes_theme)
	layout = HermesLayout.new(hermes_theme, ui)
	_build_showcase()

func _build_showcase() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var content: VBoxContainer = ui.vbox([], hermes_theme.spacing("content_gap"), {"name": "HermesUIShowcaseContent", "expand_h": true})
	content.add_child(ui.section_header("HermesUI v2 Showcase", "Core primitives and shell layouts for a calm in-game Linux-like desktop.", {"name": "HermesUIShowcaseHeader"}))
	content.add_child(_tokens_section())
	content.add_child(_controls_section())
	content.add_child(_states_section())
	content.add_child(_layouts_section())
	var scroll: ScrollContainer = ui.scroll_container(content, {"name": "HermesUIShowcaseScroll", "expand_h": true, "expand_v": true})
	var root: Control = ui.panel([scroll], hermes_theme.spacing("panel"), "base", {"name": "HermesUIShowcaseRoot", "expand_h": true, "expand_v": true, "bg": hermes_theme.color("bg"), "border_width": 0, "radius": 0})
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

func _tokens_section() -> Control:
	var swatches: Array = []
	for token in ["bg", "bg_elevated", "surface", "surface_2", "surface_3", "input_bg", "border", "accent", "success", "warning", "error"]:
		var swatch: ColorRect = ColorRect.new()
		swatch.color = hermes_theme.color(str(token))
		swatch.custom_minimum_size = Vector2(84, 34)
		var label: Label = ui.label(str(token), {"variant": "status"})
		swatches.append(ui.vbox([swatch, label], hermes_theme.spacing("space_1"), {"min_size": Vector2(96, 56)}))
	return ui.card([ui.section_header("Tokens", "Surface, border, accent, and status colors."), ui.flow_row(swatches, {"gap": hermes_theme.spacing("space_2")})], hermes_theme.spacing("card"), {"name": "HermesUIShowcaseTokens"})

func _controls_section() -> Control:
	var input_row: Control = ui.hbox([
		ui.input({"placeholder": "Text input", "width": 220}),
		ui.search_input({"placeholder": "Search input", "width": 240}),
		ui.dropdown([{"id": "one", "text": "Option one"}, {"id": "two", "text": "Option two"}], {"selected_id": "one", "width": 180})
	], hermes_theme.spacing("space_3"), {"expand_h": true})
	var buttons: Control = ui.flow_row([
		ui.button("Primary", {"variant": "primary"}),
		ui.button("Secondary", {"variant": "secondary"}),
		ui.button("Ghost", {"variant": "ghost"}),
		ui.icon_button({"icon": "⚙", "tooltip": "Icon button"}),
		ui.button("Disabled", {"disabled": true})
	], {"gap": hermes_theme.spacing("space_2")})
	var rows: Control = ui.vbox([
		ui.sidebar_item({"text": "Selected sidebar item", "selected": true}),
		ui.sidebar_item({"text": "Normal sidebar item"}),
		ui.list_item({"text": "List item", "subtitle": "Secondary text and spacing rhythm", "selected": true}),
		ui.list_item({"text": "Muted list item", "subtitle": "Normal state"})
	], hermes_theme.spacing("space_1"), {"expand_h": true})
	return ui.card([ui.section_header("Primitives", "Buttons, inputs, search, dropdowns, rows, cards, badges, scrollbar-friendly panels."), buttons, input_row, rows], hermes_theme.spacing("card"), {"name": "HermesUIShowcasePrimitives"})

func _states_section() -> Control:
	var state_buttons: Array = []
	for state in ["normal", "hover", "pressed", "focused", "selected", "disabled"]:
		state_buttons.append(_state_button(str(state)))
	var badges: Control = ui.flow_row([
		ui.badge("Success", {"kind": "success"}),
		ui.badge("Warning", {"kind": "warning"}),
		ui.badge("Error", {"kind": "error"}),
		ui.loading_indicator({"text": "Loading", "kind": "busy"})
	], {"gap": hermes_theme.spacing("space_2")})
	var progress: ProgressBar = ui.progress_bar({"value": 64, "kind": "success"})
	return ui.card([ui.section_header("States", "Normal, hover, pressed, focused, selected, disabled, semantic, and loading states."), ui.flow_row(state_buttons, {"gap": hermes_theme.spacing("space_2")}), badges, progress], hermes_theme.spacing("card"), {"name": "HermesUIShowcaseStates"})

func _state_button(state: String) -> Button:
	var disabled: bool = state == "disabled"
	var button: Button = ui.button(state.capitalize(), {"variant": "secondary", "disabled": disabled, "width": 112})
	match state:
		"hover":
			button.add_theme_stylebox_override("normal", hermes_theme.button_style("secondary", "hover"))
		"pressed":
			button.add_theme_stylebox_override("normal", hermes_theme.button_style("secondary", "pressed"))
		"focused":
			button.add_theme_stylebox_override("normal", hermes_theme.button_style("secondary", "focused"))
		"selected":
			button.add_theme_stylebox_override("normal", hermes_theme.list_row_style("selected"))
		_:
			pass
	return button

func _layouts_section() -> Control:
	var toolbar: Control = ui.toolbar([ui.label("App title", {"variant": "heading"}), _filler(), ui.badge("Gateway: Online", {"kind": "success"})], {"name": "ShowcaseToolbar"})
	var sidebar: Control = ui.sidebar([ui.sidebar_item({"text": "System", "selected": true}), ui.sidebar_item({"text": "Appearance"})], 220, {"name": "ShowcaseSidebar"})
	var panel: Control = ui.panel([ui.section_header("Content panel", "Sidebar/content settings layout with one major split and no nested frame noise."), ui.message_item("Hermes", "Message layout uses shared cards, text rhythm, and status semantics.", {"kind": "hermes"})], hermes_theme.spacing("panel"), "base", {"expand_h": true, "expand_v": true})
	var status: Control = ui.status_bar("Ready", "success")
	var app_shell: Control = layout.sidebar_app(toolbar, sidebar, panel, status, {"sidebar_width": 220})
	app_shell.custom_minimum_size = Vector2(700, 360)
	var start_menu: Control = ui.launcher_menu({"search": ui.search_input({"placeholder": "Search apps"}), "content": ui.launcher_grid([{"id": "chat", "title": "Hermes Chat", "icon": "●"}, {"id": "settings", "title": "Settings", "icon": "●"}]), "footer": ui.hbox([ui.button("Account", {"variant": "ghost"}), ui.button("Power", {"variant": "ghost"})])})
	var dock: Control = ui.taskbar({"left": [ui.icon_button({"icon": "◎"})], "center": [ui.taskbar_item("chat", "Chat", "●", {"state": "focused"}), ui.taskbar_item("settings", "Settings", "●")], "right": [ui.badge("MCP", {"kind": "info"})]})
	return ui.card([ui.section_header("Layout components", "App shell, titlebar/toolbar, sidebar-content layout, start menu, chat content, and dock/taskbar primitives."), app_shell, ui.hbox([start_menu, dock], hermes_theme.spacing("space_4"), {"expand_h": true})], hermes_theme.spacing("card"), {"name": "HermesUIShowcaseLayouts"})

func _filler() -> Control:
	var filler: Control = Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return filler
