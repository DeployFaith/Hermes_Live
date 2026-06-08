class_name HermesApp
extends Control

const HermesThemeScript = preload("res://addons/hermes_os/scripts/ui/hermes_ui/hermes_theme.gd")
const HermesComponentFactoryScript = preload("res://addons/hermes_os/scripts/ui/hermes_ui/hermes_component_factory.gd")
const HermesLayoutScript = preload("res://addons/hermes_os/scripts/ui/hermes_ui/hermes_layout.gd")
const HermesRefsScript = preload("res://addons/hermes_os/scripts/ui/hermes_ui/hermes_refs.gd")

var app_context: Dictionary = {}
var hermes_theme = null
var ui = null
var layout = null
var app_id: String = ""
var app_instance_id: String = ""
var _status: Dictionary = {"text": "", "kind": "info"}
var _rendered: bool = false
var _root_control: Control
var _status_control: Control
var _event_subscriptions: Array[Dictionary] = []

func os_app_init(context: Dictionary) -> void:
	app_context = context.duplicate(true)
	app_id = str(app_context.get("app_id", app_context.get("id", name.to_snake_case())))
	app_instance_id = str(app_context.get("app_instance_id", ""))
	_setup_runtime()
	setup(app_context)
	if not _rendered:
		render()
		_rendered = true
	var initial_state: Variant = app_context.get("state", {})
	if initial_state is Dictionary and not (initial_state as Dictionary).is_empty():
		os_app_restore_state(initial_state)

func _exit_tree() -> void:
	_cleanup_event_subscriptions()

func os_app_focus() -> void:
	on_focus()

func os_app_blur() -> void:
	on_blur()

func os_app_close_requested() -> bool:
	return on_close_requested()

func os_app_get_state() -> Dictionary:
	return get_serializable_state()

func os_app_restore_state(state: Dictionary) -> void:
	restore_state(_sanitize_value(state))

func os_app_handle_agent_action(action: StringName, args: Dictionary) -> Dictionary:
	return handle_mcp_action(str(action), _sanitize_value(args))

func setup(_context: Dictionary) -> void:
	pass

func render() -> void:
	pass

func refresh() -> void:
	clear_root()
	hermes_theme.refresh()
	hermes_theme.apply_to(self)
	render()
	_rendered = true

func on_focus() -> void:
	pass

func on_blur() -> void:
	pass

func on_close_requested() -> bool:
	return true

func get_state() -> Dictionary:
	return {}

func restore_state(_state: Dictionary) -> void:
	pass

func get_mcp_actions() -> Array:
	return []

func handle_mcp_action(_action: String, _args: Dictionary) -> Dictionary:
	return {"ok": false, "error": "Unsupported action"}

func clear_root() -> void:
	if _root_control != null and is_instance_valid(_root_control):
		_root_control.queue_free()
	_root_control = null

func set_root(control: Control) -> void:
	clear_root()
	_root_control = control
	if _root_control == null:
		return
	_root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_root_control)

func set_status(text: String, kind: String = "info") -> void:
	_status = {"text": text, "kind": kind}
	_update_status_control()

func get_status() -> Dictionary:
	return _status.duplicate(true)

func set_status_control(control: Control) -> void:
	_status_control = control
	_update_status_control()

func find_by_ref(ref: String) -> Control:
	if ref.strip_edges() == "":
		return null
	return _find_by_ref_recursive(self, ref)

func register_control_ref(control: Control, ref: String, meta: Dictionary = {}) -> void:
	if control == null:
		return
	var clean: Dictionary = meta.duplicate(true)
	clean["ref"] = ref
	HermesRefsScript.attach_meta(control, clean)

func get_serializable_state() -> Dictionary:
	var state: Dictionary = _sanitize_value(get_state())
	state["status"] = _sanitize_value(_status)
	return state

func on_event(event_name: StringName, callback: Callable) -> void:
	if not callback.is_valid():
		return
	var event_bus: Variant = app_context.get("event_bus", null)
	if event_bus == null:
		return
	if event_bus.has_method("subscribe"):
		event_bus.call("subscribe", event_name, self, callback.get_method())
		_event_subscriptions.append({"bus": event_bus, "event": event_name, "method": callback.get_method()})

func _setup_runtime() -> void:
	hermes_theme = app_context.get("theme", null)
	if hermes_theme == null:
		hermes_theme = HermesThemeScript.new()
	ui = app_context.get("ui", null)
	if ui == null:
		ui = HermesComponentFactoryScript.new(hermes_theme)
	layout = app_context.get("layout", null)
	if layout == null:
		layout = HermesLayoutScript.new(hermes_theme, ui)
	hermes_theme.apply_to(self)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func _update_status_control() -> void:
	if _status_control == null or not is_instance_valid(_status_control):
		return
	if _status_control.has_meta("status_label"):
		var status_label_variant: Variant = _status_control.get_meta("status_label")
		if status_label_variant is Label:
			var status_label := status_label_variant as Label
			status_label.text = str(_status.get("text", ""))
			status_label.add_theme_color_override("font_color", hermes_theme.kind_text_color(str(_status.get("kind", "info"))))
			return
	var label_node := _status_control.find_child("HermesStatusText", true, false)
	if label_node != null and label_node is Label:
		(label_node as Label).text = str(_status.get("text", ""))
		(label_node as Label).add_theme_color_override("font_color", hermes_theme.kind_text_color(str(_status.get("kind", "info"))))

func _sanitize_value(value: Variant) -> Variant:
	if value is Dictionary:
		var clean: Dictionary = {}
		for key in (value as Dictionary).keys():
			clean[key] = _sanitize_value((value as Dictionary)[key])
		return clean
	if value is Array:
		var clean_array: Array = []
		for item in value:
			clean_array.append(_sanitize_value(item))
		return clean_array
	if value == null or value is String or value is int or value is float or value is bool:
		return value
	return null

func _find_by_ref_recursive(node: Node, ref: String) -> Control:
	if node is Control:
		var meta: Dictionary = HermesRefsScript.get_attached_meta(node as Control)
		if str(meta.get("ref", "")) == ref:
			return node as Control
	for child in node.get_children():
		var found: Control = _find_by_ref_recursive(child, ref)
		if found != null:
			return found
	return null

func _cleanup_event_subscriptions() -> void:
	for item in _event_subscriptions:
		var bus: Variant = item.get("bus", null)
		if bus != null and bus.has_method("unsubscribe"):
			bus.call("unsubscribe", item.get("event"), self, item.get("method"))
	_event_subscriptions.clear()
