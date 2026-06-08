class_name TerminalCommandRegistry
extends RefCounted

const FSCommands = preload("res://addons/hermes_os/scripts/apps/terminal/terminal_commands/fs_commands.gd")
const AppCommands = preload("res://addons/hermes_os/scripts/apps/terminal/terminal_commands/app_commands.gd")
const HermesCommands = preload("res://addons/hermes_os/scripts/apps/terminal/terminal_commands/hermes_commands.gd")

var _modules: Array[RefCounted] = []

func command_registry_init(_context: Dictionary = {}) -> void:
	_modules.clear()
	_modules.append(FSCommands.new())
	_modules.append(AppCommands.new())
	_modules.append(HermesCommands.new())

func execute(parsed: Dictionary, backend: Object) -> Dictionary:
	var command := str(parsed.get("command", "")).to_lower()
	if command == "":
		return backend.call("make_result")
	for module in _modules:
		if module.has_method("has_command") and bool(module.call("has_command", command)):
			return module.call("execute", command, parsed, backend)
	return backend.call("make_result", [], ["Unknown command: " + command], 1)

func get_help_text() -> String:
	var lines: Array[String] = []
	for module in _modules:
		if not module.has_method("help_entries"):
			continue
		var entries_value: Variant = module.call("help_entries")
		if not (entries_value is Array):
			continue
		for entry in entries_value:
			lines.append(str(entry))
	return "\n".join(lines)

func get_command_names() -> Array[String]:
	var names: Array[String] = []
	for module in _modules:
		if not module.has_method("command_names"):
			continue
		var value: Variant = module.call("command_names")
		if not (value is Array):
			continue
		for item in value:
			var name := str(item)
			if name != "" and not names.has(name):
				names.append(name)
	names.sort()
	return names
