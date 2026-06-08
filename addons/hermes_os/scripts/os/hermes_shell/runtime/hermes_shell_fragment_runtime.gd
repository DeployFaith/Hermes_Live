class_name HermesShellFragmentRuntime
extends RefCounted

const HermesShellContext = preload("res://addons/hermes_os/scripts/os/hermes_shell/hermes_shell_context.gd")
const HermesUIRuntime = preload("res://addons/hermes_os/scripts/ui/hermes_ui/runtime/hermes_ui_runtime.gd")

var _runtime = HermesUIRuntime.new()
var _instances: Dictionary = {}
var _roots: Dictionary = {}
var _context: HermesShellContext = HermesShellContext.new().setup({})

func setup(context_value: Variant = {}) -> HermesShellFragmentRuntime:
	_context = _normalize_context(context_value)
	_runtime.set_os_context(_context.to_dictionary())
	return self

func context() -> HermesShellContext:
	return _context

func mount_fragment(fragment_id: String, manifest_path: String, host: Control, controller_context: Dictionary = {}) -> Control:
	if fragment_id.strip_edges() == "" or manifest_path.strip_edges() == "" or host == null:
		return null
	unmount_fragment(fragment_id)
	var instance = _runtime.create_app_instance(manifest_path)
	if instance == null:
		return null
	var root: Control = _runtime.mount_instance(instance, host)
	_instances[fragment_id] = instance
	_roots[fragment_id] = root
	if root != null:
		root.set_meta("hermes_shell_fragment", fragment_id)
		if fragment_id == "launcher":
			root.clip_contents = true
	if instance.controller != null and instance.controller.has_method("configure_shell_context"):
		var merged_context: Dictionary = _context.to_dictionary()
		for key in controller_context.keys():
			merged_context[key] = controller_context[key]
		merged_context["fragment_id"] = fragment_id
		merged_context["host"] = host
		merged_context["hermes_shell_context"] = _context.merged(controller_context)
		instance.controller.call("configure_shell_context", merged_context)
	return root

func unmount_fragment(fragment_id: String) -> void:
	if not _instances.has(fragment_id):
		return
	var instance = _instances[fragment_id]
	if instance != null:
		_runtime.unmount_instance(instance)
	_instances.erase(fragment_id)
	_roots.erase(fragment_id)

func get_instance(fragment_id: String):
	return _instances.get(fragment_id, null)

func get_controller(fragment_id: String):
	var instance = get_instance(fragment_id)
	if instance == null:
		return null
	return instance.controller

func get_root(fragment_id: String) -> Control:
	var root: Variant = _roots.get(fragment_id, null)
	return root as Control

func teardown() -> void:
	for fragment_id in _instances.keys().duplicate():
		unmount_fragment(str(fragment_id))

func _normalize_context(context_value: Variant) -> HermesShellContext:
	if context_value is HermesShellContext:
		return context_value as HermesShellContext
	if context_value is Dictionary:
		return HermesShellContext.new().setup(context_value as Dictionary)
	return HermesShellContext.new().setup({})
