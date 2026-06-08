class_name HermesComponentRegistry
extends RefCounted

const HermesComponent = preload("res://addons/hermes_os/scripts/ui/hermes_ui/render/hermes_component.gd")

var _components: Dictionary = {}

func register_component(tag_name: String, component) -> void:
	if tag_name.strip_edges() == "" or component == null:
		return
	_components[tag_name] = component

func has_component(tag_name: String) -> bool:
	return _components.has(tag_name)

func resolve(tag_name: String):
	return _components.get(tag_name, null)

func register_defaults(renderer) -> void:
	if not _components.is_empty():
		return
	register_component("App", HermesComponent.new("App", Callable(renderer, "_render_app"), true, "application"))
	register_component("Window", HermesComponent.new("Window", Callable(renderer, "_render_window"), true, "window"))
	register_component("AppShell", HermesComponent.new("AppShell", Callable(renderer, "_render_app_shell"), true, "application"))
	register_component("AppHeader", HermesComponent.new("AppHeader", Callable(renderer, "_render_app_header"), true, "banner"))
	register_component("AppBody", HermesComponent.new("AppBody", Callable(renderer, "_render_app_body"), true, "main"))
	register_component("AppFooter", HermesComponent.new("AppFooter", Callable(renderer, "_render_app_footer"), true, "contentinfo"))
	register_component("Column", HermesComponent.new("Column", Callable(renderer, "_render_column"), true, "group"))
	register_component("Row", HermesComponent.new("Row", Callable(renderer, "_render_row"), true, "group"))
	register_component("Panel", HermesComponent.new("Panel", Callable(renderer, "_render_panel"), true, "region"))
	register_component("Card", HermesComponent.new("Card", Callable(renderer, "_render_card"), true, "region"))
	register_component("Grid", HermesComponent.new("Grid", Callable(renderer, "_render_grid"), true, "group"))
	register_component("ScrollView", HermesComponent.new("ScrollView", Callable(renderer, "_render_scroll_view"), true, "scrollarea"))
	register_component("FlowRow", HermesComponent.new("FlowRow", Callable(renderer, "_render_flow_row"), true, "group"))
	register_component("Sidebar", HermesComponent.new("Sidebar", Callable(renderer, "_render_sidebar"), true, "navigation"))
	register_component("Toolbar", HermesComponent.new("Toolbar", Callable(renderer, "_render_toolbar"), true, "toolbar"))
	register_component("StatusBar", HermesComponent.new("StatusBar", Callable(renderer, "_render_status_bar"), false, "status"))
	register_component("SectionHeader", HermesComponent.new("SectionHeader", Callable(renderer, "_render_section_header"), false, "heading"))
	register_component("SettingsPage", HermesComponent.new("SettingsPage", Callable(renderer, "_render_settings_page"), true, "region"))
	register_component("SettingsSection", HermesComponent.new("SettingsSection", Callable(renderer, "_render_settings_section"), true, "region"))
	register_component("SettingsRow", HermesComponent.new("SettingsRow", Callable(renderer, "_render_settings_row"), true, "group"))
	register_component("Text", HermesComponent.new("Text", Callable(renderer, "_render_text"), false, "text"))
	register_component("Title", HermesComponent.new("Title", Callable(renderer, "_render_title"), false, "heading"))
	register_component("Button", HermesComponent.new("Button", Callable(renderer, "_render_button"), false, "button"))
	register_component("TextInput", HermesComponent.new("TextInput", Callable(renderer, "_render_text_input"), false, "textbox"))
	register_component("TextArea", HermesComponent.new("TextArea", Callable(renderer, "_render_text_area"), false, "textbox"))
	register_component("Select", HermesComponent.new("Select", Callable(renderer, "_render_dropdown"), false, "combobox"))
	register_component("Dropdown", HermesComponent.new("Dropdown", Callable(renderer, "_render_dropdown"), false, "combobox"))
	register_component("Slider", HermesComponent.new("Slider", Callable(renderer, "_render_slider"), false, "slider"))
	register_component("Toggle", HermesComponent.new("Toggle", Callable(renderer, "_render_toggle"), false, "checkbox"))
	register_component("List", HermesComponent.new("List", Callable(renderer, "_render_list"), true, "list"))
	register_component("ListItem", HermesComponent.new("ListItem", Callable(renderer, "_render_list_item"), false, "listitem"))
	register_component("FileList", HermesComponent.new("FileList", Callable(renderer, "_render_file_list"), true, "list"))
	register_component("FileRow", HermesComponent.new("FileRow", Callable(renderer, "_render_file_row"), false, "file"))
	register_component("PathBreadcrumb", HermesComponent.new("PathBreadcrumb", Callable(renderer, "_render_path_breadcrumb"), false, "text"))
	register_component("TerminalSurface", HermesComponent.new("TerminalSurface", Callable(renderer, "_render_terminal_surface"), false, "terminal"))
	register_component("BrowserSurface", HermesComponent.new("BrowserSurface", Callable(renderer, "_render_browser_surface"), false, "browser"))
	register_component("Badge", HermesComponent.new("Badge", Callable(renderer, "_render_badge"), false, "status"))
