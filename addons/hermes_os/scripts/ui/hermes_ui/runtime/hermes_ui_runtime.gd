class_name HermesUIRuntime
extends RefCounted

const HermesAppLoader = preload("res://addons/hermes_os/scripts/ui/hermes_ui/runtime/hermes_app_loader.gd")
const HermesAppInstance = preload("res://addons/hermes_os/scripts/ui/hermes_ui/runtime/hermes_app_instance.gd")
const HermesAppController = preload("res://addons/hermes_os/scripts/ui/hermes_ui/runtime/hermes_app_controller.gd")
const HermesStore = preload("res://addons/hermes_os/scripts/ui/hermes_ui/bindings/hermes_store.gd")
const HermesBindingEngine = preload("res://addons/hermes_os/scripts/ui/hermes_ui/bindings/hermes_binding_engine.gd")
const HermesEventBus = preload("res://addons/hermes_os/scripts/ui/hermes_ui/events/hermes_event_bus.gd")
const HermesMarkupParser = preload("res://addons/hermes_os/scripts/ui/hermes_ui/markup/hermes_markup_parser.gd")
const HermesMarkdownParser = preload("res://addons/hermes_os/scripts/ui/hermes_ui/markdown/hermes_markdown_parser.gd")
const HermesRenderer = preload("res://addons/hermes_os/scripts/ui/hermes_ui/render/hermes_renderer.gd")
const HermesRenderContext = preload("res://addons/hermes_os/scripts/ui/hermes_ui/render/hermes_render_context.gd")
const HermesStyleParser = preload("res://addons/hermes_os/scripts/ui/hermes_ui/style/hermes_style_parser.gd")
const HermesControllerUI = preload("res://addons/hermes_os/scripts/ui/hermes_ui/runtime/bridges/hermes_controller_ui.gd")
const HermesOSBridge = preload("res://addons/hermes_os/scripts/ui/hermes_ui/runtime/bridges/hermes_os_bridge.gd")

const BUILTIN_STYLES := [
	"res://addons/hermes_os/scripts/ui/hermes_ui/theme/dark.tokens.hss",
	"res://addons/hermes_os/scripts/ui/hermes_ui/theme/components.hss",
	"res://addons/hermes_os/scripts/ui/hermes_ui/theme/os_shell.hss"
]

var loader = HermesAppLoader.new()
var _markup_parser := HermesMarkupParser.new()
var _markdown_parser := HermesMarkdownParser.new()
var _style_parser := HermesStyleParser.new()
var _os_context: Dictionary = {}

func set_os_context(context: Dictionary) -> void:
	_os_context = context.duplicate(true)

func get_os_context() -> Dictionary:
	return _os_context.duplicate(true)

func create_app_instance(manifest_path: String):
	var manifest = loader.load_manifest(manifest_path)
	if manifest == null:
		return null
	var instance := HermesAppInstance.new()
	instance.manifest = manifest
	instance.state = HermesStore.new()
	instance.event_bus = HermesEventBus.new()
	instance.controller = _load_controller(instance)
	return instance

func mount_instance(instance, host: Control) -> Control:
	if instance == null or host == null:
		return null
	if instance.is_mounted():
		return instance.root_control
	var root := Control.new()
	root.name = "HermesUIRuntimeRoot"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.set_meta("hermes_ui_app_id", instance.manifest.app_id if instance.manifest != null else "")

	var content_host := Control.new()
	content_host.name = "HermesUIRuntimeContent"
	content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(content_host)

	_apply_window_metadata(instance, host, root, content_host)

	var document = _load_markup_document(instance.manifest.entry_path if instance.manifest != null else "")
	var render_context = HermesRenderContext.new()
	render_context.stylesheets = _load_stylesheets(instance.manifest)
	render_context.state = instance.state
	var renderer = HermesRenderer.new()
	renderer.setup(render_context)
	instance.render_context = render_context
	instance.renderer = renderer

	if document != null and document.root != null and document.errors.is_empty():
		instance.root_element = document.root.to_element_instance()
		var rendered: Control = renderer.render_tree(instance.root_element, content_host)
		if rendered == null:
			content_host.add_child(_error_label("HermesUI renderer returned null"))
		else:
			rendered.set_anchors_preset(Control.PRESET_FULL_RECT)
			rendered.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rendered.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		content_host.add_child(_error_label(_document_error_text(document)))
	if document != null and document.has_method("free_tree"):
		document.free_tree()

	host.add_child(root)
	instance.mount(root, host)
	instance.binding_engine = HermesBindingEngine.new()
	if instance.root_element != null:
		instance.binding_engine.bind_app(instance, render_context, render_context.stylesheets)
	if instance.controller != null:
		instance.controller._attach_runtime(instance, self)
		instance.controller.state = instance.state
		instance.controller.events = instance.event_bus
		instance.controller.renderer = instance.renderer
		instance.controller.render_context = instance.render_context
		instance.controller.ui = HermesControllerUI.new().setup(instance)
		instance.controller.os = HermesOSBridge.new().setup(_bridge_context_for_instance(instance))
		instance.controller.app_mounted(root)
		if instance.controller.has_method("_app_ready"):
			instance.controller.call("_app_ready")
	return root

func unmount_instance(instance) -> void:
	if instance == null or not instance.is_mounted():
		return
	var root: Control = instance.root_control
	var host: Control = instance.mounted_host
	if instance.binding_engine != null and instance.binding_engine.has_method("teardown"):
		instance.binding_engine.teardown()
	if instance.state != null and instance.state.has_method("clear_watchers"):
		instance.state.clear_watchers()
	if instance.event_bus != null and instance.event_bus.has_method("clear_listeners"):
		instance.event_bus.clear_listeners()
	if instance.controller != null:
		instance.controller.app_unmounted()
	if instance.root_element != null:
		instance.root_element.clear_control_tree()
		instance.root_element.free_tree()
	if host != null and is_instance_valid(host) and root != null and is_instance_valid(root) and root.get_parent() == host:
		host.remove_child(root)
		root.queue_free()
	instance.unmount()

func _load_controller(instance):
	if instance == null or instance.manifest == null:
		return null
	var controller_path: String = instance.manifest.controller_path
	if controller_path == "":
		return null
	var script: Script = load(controller_path) as Script
	if script == null:
		push_warning("Hermes controller script failed to load: %s" % controller_path)
		return null
	var controller = script.new()
	if not (controller is HermesAppController):
		push_warning("Hermes controller does not extend HermesAppController: %s" % controller_path)
		return null
	controller._attach_runtime(instance, self)
	return controller

func _bridge_context_for_instance(instance) -> Dictionary:
	var context: Dictionary = _os_context.duplicate(true)
	context["runtime"] = self
	context["app"] = instance
	if instance != null:
		context["manifest"] = instance.manifest
		if instance.root_control != null and is_instance_valid(instance.root_control):
			context["root_control"] = instance.root_control
	return context

func _load_stylesheets(manifest) -> Array:
	var sheets: Array = []
	for path in BUILTIN_STYLES:
		var sheet = _style_parser.parse_file(path)
		if sheet != null:
			sheets.append(sheet)
	if manifest != null:
		for style_path in manifest.styles_paths:
			var sheet = _style_parser.parse_file(str(style_path))
			if sheet != null:
				sheets.append(sheet)
	return sheets

func _error_label(message: String) -> Label:
	var label := Label.new()
	label.name = "HermesUIRuntimeError"
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _document_error_text(document) -> String:
	if document == null:
		return "HermesUI markup document could not be loaded"
	if document.errors.is_empty():
		return "HermesUI markup document has no root"
	var first_error = document.errors[0]
	var line_value: int = first_error.line if first_error != null else -1
	var message: String = first_error.message if first_error != null else "Markup error"
	if line_value >= 0:
		return "%s (line %d)" % [message, line_value]
	return message

func _load_markup_document(entry_path: String):
	if entry_path.strip_edges() == "":
		var empty_document = _markup_parser.parse_text("", "")
		empty_document.errors.clear()
		empty_document.add_error("Markup file not found", -1)
		return empty_document
	if entry_path.to_lower().ends_with(".hmd"):
		var markdown_document = _markdown_parser.parse_file(entry_path)
		if markdown_document == null:
			var failed_document = _markup_parser.parse_text("", entry_path)
			failed_document.errors.clear()
			failed_document.add_error("Markdown file could not be parsed", -1)
			return failed_document
		if markdown_document.has_errors():
			var diagnostic_message := "HermesMarkdown parse error"
			var diagnostic_line := -1
			if not markdown_document.diagnostics.is_empty() and markdown_document.diagnostics[0] != null:
				diagnostic_message = str(markdown_document.diagnostics[0].message)
				diagnostic_line = int(markdown_document.diagnostics[0].line)
			var invalid_document = _markup_parser.parse_text("", entry_path)
			invalid_document.errors.clear()
			invalid_document.add_error(diagnostic_message, diagnostic_line)
			return invalid_document
		return _markup_parser.parse_text(str(markdown_document.generated_hml), entry_path + ".generated.hml")
	return _markup_parser.parse_file(entry_path)

func _apply_window_metadata(instance, host: Control, root: Control, content_host: Control) -> void:
	if instance == null or instance.manifest == null:
		return
	var window_config: Dictionary = instance.manifest.window_config if instance.manifest.window_config is Dictionary else {}
	if window_config.is_empty():
		return
	var default_size := Vector2(float(window_config.get("default_width", 0)), float(window_config.get("default_height", 0)))
	var min_size := Vector2(float(window_config.get("min_width", 0)), float(window_config.get("min_height", 0)))
	if default_size.x <= 0.0 or default_size.y <= 0.0:
		default_size = Vector2(720, 520)
	if min_size.x <= 0.0 or min_size.y <= 0.0:
		min_size = Vector2(520, 360)
	if default_size.x < min_size.x:
		default_size.x = min_size.x
	if default_size.y < min_size.y:
		default_size.y = min_size.y
	for node in [host, root, content_host]:
		if node == null:
			continue
		node.set_meta("window_default_size", default_size)
		node.set_meta("window_min_size", min_size)
