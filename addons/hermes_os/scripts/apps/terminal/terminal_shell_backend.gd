class_name TerminalShellBackend
extends RefCounted

const TerminalCommandRegistry = preload("res://addons/hermes_os/scripts/apps/terminal/terminal_command_registry.gd")

var _shell: Node
var _fs: Object
var _registry: TerminalCommandRegistry
var _state: Dictionary = {}
var _session_id: String = ""
var _history: Array[String] = []

func terminal_shell_init(context: Dictionary = {}) -> void:
	_shell = context.get("shell", null) as Node
	_fs = context.get("filesystem", null) as Object
	if _fs == null and _shell != null:
		_fs = _shell.get("_fs") as Object
	_state = context.get("state", {}) if context.get("state", {}) is Dictionary else {}
	_session_id = str(context.get("session_id", _session_id))
	if not _state.has("cwd"):
		_state["cwd"] = home_path()
	else:
		_state["cwd"] = resolve_path(str(_state.get("cwd", home_path())))
	if not _state.has("history"):
		_state["history"] = []
	var history_value: Variant = _state.get("history", [])
	if history_value is Array:
		for item in history_value:
			_history.append(str(item))
	_registry = TerminalCommandRegistry.new()
	_registry.command_registry_init({})

func run_command(command_line: String) -> Dictionary:
	var clean := command_line.strip_edges()
	if clean == "":
		return make_result()
	_add_history(clean)
	var parsed := parse_command_line(clean)
	if not bool(parsed.get("ok", false)):
		return make_result([], [str(parsed.get("error", "Could not parse command"))], 1)
	var result: Dictionary = _registry.execute(parsed, self)
	result["cwd"] = get_cwd()
	result["session_id"] = _session_id
	return result

func parse_command_line(command_line: String) -> Dictionary:
	var tokens_result := _tokenize(command_line)
	if not bool(tokens_result.get("ok", false)):
		return tokens_result
	var tokens: Array = tokens_result.get("tokens", []) if tokens_result.get("tokens", []) is Array else []
	if tokens.is_empty():
		return {"ok": true, "command": "", "args": [], "tail": "", "redirect_path": "", "raw": command_line}
	var command := str(tokens[0]).to_lower()
	var args: Array[String] = []
	var redirect_path := ""
	var index := 1
	while index < tokens.size():
		var token := str(tokens[index])
		if token == ">":
			if index + 1 >= tokens.size():
				return {"ok": false, "error": "Missing redirect path", "raw": command_line}
			redirect_path = str(tokens[index + 1])
			break
		args.append(token)
		index += 1
	var tail := command_line.substr(command.length()).strip_edges()
	return {"ok": true, "command": command, "args": args, "tail": tail, "redirect_path": redirect_path, "raw": command_line}

func make_result(stdout_lines: Array = [], stderr_lines: Array = [], exit_code: int = 0, clear_screen: bool = false) -> Dictionary:
	var out: Array[String] = []
	var err: Array[String] = []
	for line in stdout_lines:
		out.append(str(line))
	for line in stderr_lines:
		err.append(str(line))
	return {
		"ok": exit_code == 0,
		"stdout_lines": out,
		"stderr_lines": err,
		"stdout": "\n".join(out),
		"stderr": "\n".join(err),
		"exit_code": exit_code,
		"clear_screen": clear_screen,
		"cwd": get_cwd(),
		"session_id": _session_id
	}

func get_help_text() -> String:
	return _registry.get_help_text() if _registry != null else ""

func get_command_names() -> Array[String]:
	return _registry.get_command_names() if _registry != null and _registry.has_method("get_command_names") else []

func complete_input(input: String, caret_column: int = -1) -> Dictionary:
	var context := _completion_context(input, caret_column)
	var token := str(context.get("token", ""))
	var command_name := str(context.get("command", ""))
	var mode := str(context.get("mode", "command"))
	var candidates: Array[String] = []
	var suffix := ""
	if mode == "command":
		candidates = _matching_command_candidates(token)
		suffix = " "
	elif command_name == "open" and int(context.get("argument_index", 0)) <= 1:
		candidates = _merge_unique(_matching_path_candidates(token), _matching_app_candidates(token))
	else:
		candidates = _matching_path_candidates(token)
	return _make_completion_result(
		input,
		str(context.get("before", "")),
		str(context.get("after", "")),
		str(context.get("prefix_before_token", "")),
		token,
		mode,
		candidates,
		suffix
	)

func suggest_input(input: String, caret_column: int = -1) -> Dictionary:
	var caret := caret_column
	if caret < 0 or caret > input.length():
		caret = input.length()
	if caret != input.length():
		return _make_suggestion_result(input, "", "")
	var clean := input.strip_edges()
	if clean == "":
		return _make_suggestion_result(input, "", "")
	for index in range(_history.size() - 1, -1, -1):
		var item := _history[index]
		if item != clean and item.begins_with(clean):
			return _make_suggestion_result(input, item, "history")
	var context := _completion_context(input, caret)
	var token := str(context.get("token", ""))
	var command_name := str(context.get("command", ""))
	var mode := str(context.get("mode", "command"))
	var candidates: Array[String] = []
	var suffix := ""
	if mode == "command":
		candidates = _matching_command_candidates(token)
		suffix = " "
	elif command_name == "open" and int(context.get("argument_index", 0)) <= 1:
		candidates = _merge_unique(_matching_path_candidates(token), _matching_app_candidates(token))
	else:
		candidates = _matching_path_candidates(token)
	for candidate in candidates:
		var suggestion := str(context.get("prefix_before_token", "")) + candidate + suffix + str(context.get("after", ""))
		if suggestion != input and suggestion.begins_with(input):
			return _make_suggestion_result(input, suggestion, mode)
	return _make_suggestion_result(input, "", "")

func export_state() -> Dictionary:
	_state["cwd"] = get_cwd()
	_state["history"] = _history.duplicate()
	_state["session_id"] = _session_id
	return _state.duplicate(true)

func get_history() -> Array[String]:
	var result: Array[String] = []
	for item in _history:
		result.append(item)
	return result

func get_session_id() -> String:
	return _session_id

func get_prompt() -> String:
	var symbol := "#" if current_user() == "root" else "$"
	var cwd := get_cwd()
	var home := home_path()
	var display_cwd := cwd
	if cwd == home:
		display_cwd = "~"
	elif cwd.begins_with(home + "/"):
		display_cwd = "~" + cwd.substr(home.length())
	return current_user() + "@hermes_os:" + display_cwd + symbol

func get_cwd() -> String:
	return str(_state.get("cwd", home_path()))

func set_cwd(path: String) -> void:
	_state["cwd"] = resolve_path(path)

func home_path() -> String:
	if _fs != null and _fs.has_method("home_path"):
		return str(_fs.call("home_path"))
	return "/root"

func current_user() -> String:
	if _fs != null and _fs.has_method("current_user"):
		return str(_fs.call("current_user"))
	return "user"

func resolve_path(path: String) -> String:
	if _fs != null and _fs.has_method("resolve_path"):
		return str(_fs.call("resolve_path", path, get_cwd()))
	return path

func is_dir(path: String) -> bool:
	return bool(_fs.call("is_dir", path)) if _fs != null and _fs.has_method("is_dir") else false

func is_file(path: String) -> bool:
	return bool(_fs.call("is_file", path)) if _fs != null and _fs.has_method("is_file") else false

func exists(path: String) -> bool:
	return bool(_fs.call("exists", path)) if _fs != null and _fs.has_method("exists") else is_dir(path) or is_file(path)

func can_list_dir(path: String) -> bool:
	return bool(_fs.call("can_list_dir", path)) if _fs != null and _fs.has_method("can_list_dir") else is_dir(path)

func list_dir(path: String) -> Array:
	if _fs == null or not _fs.has_method("list_dir"):
		return []
	var value: Variant = _fs.call("list_dir", path)
	return value if value is Array else []

func read_file(path: String) -> Dictionary:
	if _fs == null or not _fs.has_method("read_file_result"):
		return {"ok": false, "error": "Filesystem unavailable", "content": ""}
	var result: Variant = _fs.call("read_file_result", path)
	return result if result is Dictionary else {"ok": false, "error": "Could not read file", "content": ""}

func write_file(path: String, content: String) -> Dictionary:
	if _fs == null or not _fs.has_method("write_file"):
		return {"ok": false, "error": "Filesystem unavailable", "path": path}
	var had_file := exists(path)
	var message := str(_fs.call("write_file", path, content))
	if message != "":
		return {"ok": false, "error": message, "path": path}
	_emit_file_event("file.updated" if had_file else "file.created", {"path": path, "type": "file"})
	return {"ok": true, "path": path, "created": not had_file}

func make_dir(path: String) -> Dictionary:
	if _fs == null or not _fs.has_method("make_dir"):
		return {"ok": false, "error": "Filesystem unavailable", "path": path}
	var message := str(_fs.call("make_dir", path))
	if message != "":
		return {"ok": false, "error": message, "path": path}
	_emit_file_event("file.created", {"path": path, "type": "dir"})
	return {"ok": true, "path": path, "created": true}

func delete_path(path: String) -> Dictionary:
	if _fs == null or not _fs.has_method("delete_path"):
		return {"ok": false, "error": "Filesystem unavailable", "path": path}
	var message := str(_fs.call("delete_path", path))
	if message != "":
		return {"ok": false, "error": message, "path": path}
	_emit_file_event("file.deleted", {"path": path})
	return {"ok": true, "path": path, "deleted": true}

func copy_path(source: String, destination: String) -> Dictionary:
	if _fs == null or not _fs.has_method("copy_path"):
		return {"ok": false, "error": "Filesystem unavailable"}
	var message := str(_fs.call("copy_path", source, destination))
	if message != "":
		return {"ok": false, "error": message}
	_emit_file_event("file.created", {"path": destination, "type": "file"})
	return {"ok": true, "source": source, "destination": destination}

func move_path(source: String, destination: String) -> Dictionary:
	if _fs == null or not _fs.has_method("move_path"):
		return {"ok": false, "error": "Filesystem unavailable"}
	var message := str(_fs.call("move_path", source, destination))
	if message != "":
		return {"ok": false, "error": message}
	_emit_file_event("file.deleted", {"path": source})
	_emit_file_event("file.created", {"path": destination, "type": "file"})
	return {"ok": true, "source": source, "destination": destination}

func open_target(target: String) -> Dictionary:
	var resolved := resolve_path(target)
	if is_file(resolved):
		if _shell != null and _shell.has_method("_open_text_file"):
			_shell.call("_open_text_file", resolved, "text")
			return {"ok": true, "message": "Opened " + resolved, "path": resolved}
		return {"ok": false, "error": "Text app unavailable"}
	if _shell != null and _shell.has_method("launch_app"):
		var apps_value: Variant = _shell.get("_apps")
		var apps: Dictionary = apps_value if apps_value is Dictionary else {}
		if apps.has(target):
			var window: Variant = _shell.call("launch_app", target)
			if window != null:
				return {"ok": true, "message": "Opened " + target, "app_id": target}
	return {"ok": false, "error": "Unknown app or file: " + target}

func send_hermes(prompt: String) -> Dictionary:
	if _shell == null:
		return {"ok": false, "terminal_result": "Hermes shell unavailable"}
	var service: Variant = _shell.get("_hermes_agent_service")
	if service == null:
		return {"ok": false, "terminal_result": "Hermes agent service is unavailable."}
	if not (service is Object) or not (service as Object).has_method("send_terminal_message"):
		return {"ok": false, "terminal_result": "Hermes agent service is unavailable."}
	return (service as Object).call("send_terminal_message", prompt, {
		"cwd": get_cwd(),
		"user": current_user(),
		"timestamp": int(Time.get_unix_time_from_system()),
		"terminal_session_id": _session_id,
		"source": "terminal"
	})

func _add_history(command_line: String) -> void:
	_history.append(command_line)
	_state["history"] = _history.duplicate()

func _emit_file_event(event_name: String, payload: Dictionary) -> void:
	if _shell != null and _shell.has_method("_emit_hermes_event"):
		_shell.call("_emit_hermes_event", event_name, payload)

func _completion_context(input: String, caret_column: int = -1) -> Dictionary:
	var caret := caret_column
	if caret < 0 or caret > input.length():
		caret = input.length()
	var before := input.substr(0, caret)
	var after := input.substr(caret)
	var token_start := _current_token_start(before)
	var token := before.substr(token_start)
	var prefix_before_token := before.substr(0, token_start)
	var command_name := _first_token(before).to_lower()
	return {
		"caret": caret,
		"before": before,
		"after": after,
		"token_start": token_start,
		"token": token,
		"prefix_before_token": prefix_before_token,
		"command": command_name,
		"argument_index": _argument_index(before),
		"mode": "command" if prefix_before_token.strip_edges() == "" else "path"
	}

func _current_token_start(text: String) -> int:
	var index := text.length() - 1
	while index >= 0:
		var ch := text[index]
		if ch == " " or ch == "	":
			return index + 1
		index -= 1
	return 0

func _first_token(text: String) -> String:
	var trimmed := text.strip_edges()
	if trimmed == "":
		return ""
	var pieces := trimmed.split(" ", false)
	return str(pieces[0]) if not pieces.is_empty() else ""

func _argument_index(text: String) -> int:
	var trimmed := text.strip_edges()
	if trimmed == "":
		return 0
	return trimmed.split(" ", false).size() - 1

func _matching_command_candidates(prefix: String) -> Array[String]:
	var result: Array[String] = []
	for name in get_command_names():
		if prefix == "" or name.begins_with(prefix.to_lower()):
			result.append(name)
	return result

func _matching_app_candidates(prefix: String) -> Array[String]:
	var result: Array[String] = []
	for app_id in _app_ids():
		if prefix == "" or app_id.begins_with(prefix):
			result.append(app_id)
	return result

func _matching_path_candidates(token: String) -> Array[String]:
	var split := _split_path_token(token)
	var base_token := str(split.get("base", ""))
	var name_prefix := str(split.get("prefix", ""))
	var display_base := str(split.get("display_base", ""))
	var dir_path := get_cwd() if base_token == "." or base_token == "" else resolve_path(base_token)
	if not is_dir(dir_path) or not can_list_dir(dir_path):
		return []
	var entries := list_dir(dir_path)
	var result: Array[String] = []
	for value in entries:
		if not (value is Dictionary):
			continue
		var entry: Dictionary = value
		var name := str(entry.get("name", ""))
		if name == "" or not name.begins_with(name_prefix):
			continue
		var suffix := "/" if str(entry.get("type", "")) == "dir" else ""
		result.append(display_base + name + suffix)
	result.sort()
	return result

func _split_path_token(token: String) -> Dictionary:
	var slash_index := token.rfind("/")
	if slash_index < 0:
		return {"base": ".", "display_base": "", "prefix": token}
	var display_base := token.substr(0, slash_index + 1)
	var prefix := token.substr(slash_index + 1)
	var base := display_base
	if base == "":
		base = "."
	return {"base": base, "display_base": display_base, "prefix": prefix}

func _app_ids() -> Array[String]:
	var ids: Array[String] = []
	if _shell != null:
		var registry_value: Variant = _shell.get("_app_registry")
		if registry_value is Object and (registry_value as Object).has_method("get_app_order"):
			var order_value: Variant = (registry_value as Object).call("get_app_order")
			if order_value is Array:
				for item in order_value:
					var id := str(item)
					if id != "" and not ids.has(id):
						ids.append(id)
		var apps_value: Variant = _shell.get("_apps")
		if apps_value is Dictionary:
			for key in (apps_value as Dictionary).keys():
				var id := str(key)
				if id != "" and not ids.has(id):
					ids.append(id)
	ids.sort()
	return ids

func _merge_unique(first: Array[String], second: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value in first:
		if not result.has(value):
			result.append(value)
	for value in second:
		if not result.has(value):
			result.append(value)
	result.sort()
	return result

func _make_completion_result(input: String, before: String, after: String, prefix_before_token: String, token: String, mode: String, candidates: Array[String], suffix: String = "") -> Dictionary:
	var replacement := input
	var hint := ""
	if candidates.size() == 1:
		replacement = prefix_before_token + candidates[0] + suffix + after
		hint = "completed " + candidates[0]
	elif candidates.size() > 1:
		hint = "%d matches: %s" % [candidates.size(), "  ".join(candidates)]
	return {
		"ok": candidates.size() > 0,
		"input": input,
		"before": before,
		"after": after,
		"token": token,
		"replacement": replacement,
		"candidates": candidates,
		"hint": hint,
		"mode": mode
	}

func _make_suggestion_result(input: String, suggestion: String, source: String) -> Dictionary:
	var ok := suggestion != "" and suggestion != input
	return {
		"ok": ok,
		"input": input,
		"suggestion": suggestion if ok else "",
		"hint": ("suggestion: " + suggestion + "    Tab/Right to accept") if ok else "",
		"source": source if ok else ""
	}

func _tokenize(command_line: String) -> Dictionary:
	var tokens: Array[String] = []
	var current := ""
	var quote := ""
	var index := 0
	while index < command_line.length():
		var ch := command_line[index]
		if quote != "":
			if ch == quote:
				quote = ""
			elif ch == "\\" and quote == "\"" and index + 1 < command_line.length():
				index += 1
				current += command_line[index]
			else:
				current += ch
		elif ch == "\"" or ch == "'":
			quote = ch
		elif ch == ">":
			if current != "":
				tokens.append(current)
				current = ""
			tokens.append(">")
		elif ch == " " or ch == "\t":
			if current != "":
				tokens.append(current)
				current = ""
		else:
			current += ch
		index += 1
	if quote != "":
		return {"ok": false, "error": "Unclosed quote", "tokens": []}
	if current != "":
		tokens.append(current)
	return {"ok": true, "tokens": tokens}
