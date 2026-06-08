class_name TerminalHermesCommands
extends RefCounted

const COMMANDS: Array[String] = ["hermes"]

func has_command(command: String) -> bool:
	return COMMANDS.has(command)

func command_names() -> Array[String]:
	return COMMANDS.duplicate()

func help_entries() -> Array[String]:
	return ["hermes <prompt>"]

func execute(command: String, parsed: Dictionary, backend: Object) -> Dictionary:
	if command != "hermes":
		return backend.call("make_result", [], ["Unknown command: " + command], 1)
	var prompt := str(parsed.get("tail", "")).strip_edges()
	if prompt == "":
		return backend.call("make_result", [], ["Usage: hermes <prompt>"], 1)
	var result: Dictionary = backend.call("send_hermes", prompt)
	if not bool(result.get("ok", false)):
		return backend.call("make_result", [], [str(result.get("terminal_result", result.get("error", "Hermes Gateway request failed")))], 1)
	return backend.call("make_result", [str(result.get("terminal_result", "Sent to Hermes Gateway: " + prompt))])
