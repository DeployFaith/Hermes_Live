class_name TerminalAppCommands
extends RefCounted

const COMMANDS: Array[String] = ["help", "open", "history", "whoami", "date", "uname", "which", "exit", "logout"]

func has_command(command: String) -> bool:
	return COMMANDS.has(command)

func command_names() -> Array[String]:
	return COMMANDS.duplicate()

func help_entries() -> Array[String]:
	return [
		"help",
		"open <path|app_id>",
		"history",
		"whoami",
		"date",
		"uname",
		"which <command>",
		"exit",
		"logout"
	]

func execute(command: String, parsed: Dictionary, backend: Object) -> Dictionary:
	match command:
		"help":
			return backend.call("make_result", [str(backend.call("get_help_text"))])
		"open":
			return _cmd_open(parsed, backend)
		"history":
			return _cmd_history(parsed, backend)
		"whoami":
			return backend.call("make_result", [str(backend.call("current_user"))])
		"date":
			return _cmd_date(backend)
		"uname":
			return _cmd_uname(backend)
		"which":
			return _cmd_which(parsed, backend)
		"exit", "logout":
			return _cmd_exit(backend)
	return backend.call("make_result", [], ["Unknown command: " + command], 1)

func _cmd_open(parsed: Dictionary, backend: Object) -> Dictionary:
	var args: Array = parsed.get("args", []) if parsed.get("args", []) is Array else []
	if args.is_empty():
		return backend.call("make_result", [], ["Usage: open <path|app_id>"], 1)
	var target := str(args[0])
	var result: Dictionary = backend.call("open_target", target)
	if not bool(result.get("ok", false)):
		return backend.call("make_result", [], [str(result.get("error", "Could not open target"))], 1)
	return backend.call("make_result", [str(result.get("message", "Opened " + target))])

func _cmd_history(parsed: Dictionary, backend: Object) -> Dictionary:
	var history_value: Variant = backend.call("get_history")
	var history: Array = history_value if history_value is Array else []
	var lines: Array[String] = []
	for i in range(history.size()):
		lines.append("  %d  %s" % [i + 1, str(history[i])])
	if lines.is_empty():
		return backend.call("make_result", ["(no history)"])
	return backend.call("make_result", lines)

func _cmd_date(backend: Object) -> Dictionary:
	var dt := Time.get_datetime_dict_from_system()
	var weekday_names: Array[String] = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
	var month_names: Array[String] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var weekday: String = weekday_names[int(dt.get("weekday", 0))]
	var month: String = month_names[int(dt.get("month", 1)) - 1]
	var day := int(dt.get("day", 1))
	var hour := int(dt.get("hour", 0))
	var minute := int(dt.get("minute", 0))
	var second := int(dt.get("second", 0))
	var year := int(dt.get("year", 2026))
	var tz := str(dt.get("timezone", ""))
	var formatted := "%s %s %02d %02d:%02d:%02d %s %d" % [weekday, month, day, hour, minute, second, tz, year]
	return backend.call("make_result", [formatted])

func _cmd_uname(backend: Object) -> Dictionary:
	return backend.call("make_result", ["HermOS 1.0.0 HermesOS Kernel"])

func _cmd_which(parsed: Dictionary, backend: Object) -> Dictionary:
	var args: Array = parsed.get("args", []) if parsed.get("args", []) is Array else []
	if args.is_empty():
		return backend.call("make_result", [], ["Usage: which <command>"], 1)
	var name := str(args[0]).to_lower()
	var names_value: Variant = backend.call("get_command_names")
	var names: Array = names_value if names_value is Array else []
	for n in names:
		if str(n) == name:
			return backend.call("make_result", ["hermes:" + name])
	return backend.call("make_result", [], ["not found: " + name], 1)

func _cmd_exit(backend: Object) -> Dictionary:
	var result: Dictionary = backend.call("make_result", ["logout"])
	result["close_terminal"] = true
	return result
