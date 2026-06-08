class_name TerminalFSCommands
extends RefCounted

const COMMANDS: Array[String] = ["pwd", "ls", "cd", "mkdir", "touch", "cat", "read", "echo", "rm", "clear", "cp", "mv", "tree", "head", "tail", "grep", "ll", "la", "cls"]

func has_command(command: String) -> bool:
	return COMMANDS.has(command)

func command_names() -> Array[String]:
	return COMMANDS.duplicate()

func help_entries() -> Array[String]:
	return [
		"pwd",
		"ls [path]",
		"cd [path]",
		"mkdir <path>",
		"touch <path>",
		"cat <path>",
		"echo <text> [> path]",
		"rm <path>",
		"cp <source> <dest>",
		"mv <source> <dest>",
		"tree [path]",
		"head <path> [lines]",
		"tail <path> [lines]",
		"grep <pattern> <path>",
		"clear",
		"ll  (alias: ls)",
		"la  (alias: ls)",
		"cls (alias: clear)"
	]

func execute(command: String, parsed: Dictionary, backend: Object) -> Dictionary:
	match command:
		"pwd":
			return backend.call("make_result", [backend.call("get_cwd")])
		"ls":
			return _cmd_ls(parsed, backend)
		"ll":
			return _cmd_ls(parsed, backend)
		"la":
			return _cmd_ls(parsed, backend)
		"cd":
			return _cmd_cd(parsed, backend)
		"mkdir":
			return _cmd_mkdir(parsed, backend)
		"touch":
			return _cmd_touch(parsed, backend)
		"cat", "read":
			return _cmd_cat(parsed, backend)
		"echo":
			return _cmd_echo(parsed, backend)
		"rm":
			return _cmd_rm(parsed, backend)
		"cp":
			return _cmd_cp(parsed, backend)
		"mv":
			return _cmd_mv(parsed, backend)
		"tree":
			return _cmd_tree(parsed, backend)
		"head":
			return _cmd_head(parsed, backend)
		"tail":
			return _cmd_tail(parsed, backend)
		"grep":
			return _cmd_grep(parsed, backend)
		"clear", "cls":
			return backend.call("make_result", [], [], 0, true)
	return backend.call("make_result", [], ["Unknown command: " + command], 1)

func _args(parsed: Dictionary) -> Array:
	return parsed.get("args", []) if parsed.get("args", []) is Array else []

func _cmd_ls(parsed: Dictionary, backend: Object) -> Dictionary:
	var args := _args(parsed)
	var target := str(backend.call("get_cwd"))
	if args.size() >= 1:
		target = str(backend.call("resolve_path", str(args[0])))
	if not bool(backend.call("is_dir", target)):
		return backend.call("make_result", [], ["Folder not found: " + target], 1)
	if not bool(backend.call("can_list_dir", target)):
		return backend.call("make_result", [], ["Permission denied: " + target], 1)
	var entries_value: Variant = backend.call("list_dir", target)
	var entries: Array = entries_value if entries_value is Array else []
	var lines: Array[String] = []
	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var name := str(entry.get("name", ""))
		if str(entry.get("type", "")) == "dir":
			name += "/"
		lines.append(name)
	return backend.call("make_result", lines)

func _cmd_cd(parsed: Dictionary, backend: Object) -> Dictionary:
	var args := _args(parsed)
	var target := str(backend.call("home_path"))
	if args.size() >= 1:
		target = str(backend.call("resolve_path", str(args[0])))
	if not bool(backend.call("is_dir", target)):
		return backend.call("make_result", [], ["Folder not found: " + target], 1)
	if not bool(backend.call("can_list_dir", target)):
		return backend.call("make_result", [], ["Permission denied: " + target], 1)
	backend.call("set_cwd", target)
	return backend.call("make_result", [target])

func _cmd_mkdir(parsed: Dictionary, backend: Object) -> Dictionary:
	var args := _args(parsed)
	if args.is_empty():
		return backend.call("make_result", [], ["Usage: mkdir <path>"], 1)
	var target := str(backend.call("resolve_path", str(args[0])))
	var result: Dictionary = backend.call("make_dir", target)
	if not bool(result.get("ok", false)):
		return backend.call("make_result", [], [str(result.get("error", "Could not create folder"))], 1)
	return backend.call("make_result", ["Folder created"])

func _cmd_touch(parsed: Dictionary, backend: Object) -> Dictionary:
	var args := _args(parsed)
	if args.is_empty():
		return backend.call("make_result", [], ["Usage: touch <path>"], 1)
	var target := str(backend.call("resolve_path", str(args[0])))
	var content := ""
	if bool(backend.call("is_file", target)):
		var existing: Dictionary = backend.call("read_file", target)
		if bool(existing.get("ok", false)):
			content = str(existing.get("content", ""))
	var result: Dictionary = backend.call("write_file", target, content)
	if not bool(result.get("ok", false)):
		return backend.call("make_result", [], [str(result.get("error", "Could not touch file"))], 1)
	return backend.call("make_result", ["File touched"])

func _cmd_cat(parsed: Dictionary, backend: Object) -> Dictionary:
	var args := _args(parsed)
	if args.is_empty():
		return backend.call("make_result", [], ["Usage: cat <path>"], 1)
	var target := str(backend.call("resolve_path", str(args[0])))
	var result: Dictionary = backend.call("read_file", target)
	if not bool(result.get("ok", false)):
		return backend.call("make_result", [], [str(result.get("error", "Could not read file"))], 1)
	return backend.call("make_result", [str(result.get("content", ""))])

func _cmd_echo(parsed: Dictionary, backend: Object) -> Dictionary:
	var args := _args(parsed)
	var content := " ".join(args)
	var redirect_path := str(parsed.get("redirect_path", ""))
	if redirect_path != "":
		var target := str(backend.call("resolve_path", redirect_path))
		var result: Dictionary = backend.call("write_file", target, content)
		if not bool(result.get("ok", false)):
			return backend.call("make_result", [], [str(result.get("error", "Could not write file"))], 1)
		return backend.call("make_result", [])
	return backend.call("make_result", [content])

func _cmd_rm(parsed: Dictionary, backend: Object) -> Dictionary:
	var args := _args(parsed)
	if args.is_empty():
		return backend.call("make_result", [], ["Usage: rm <path>"], 1)
	var target := str(backend.call("resolve_path", str(args[0])))
	var result: Dictionary = backend.call("delete_path", target)
	if not bool(result.get("ok", false)):
		return backend.call("make_result", [], [str(result.get("error", "Could not delete path"))], 1)
	return backend.call("make_result", ["Deleted"])

func _cmd_cp(parsed: Dictionary, backend: Object) -> Dictionary:
	var args := _args(parsed)
	if args.size() < 2:
		return backend.call("make_result", [], ["Usage: cp <source> <dest>"], 1)
	var source := str(backend.call("resolve_path", str(args[0])))
	var dest := str(backend.call("resolve_path", str(args[1])))
	if not bool(backend.call("exists", source)):
		return backend.call("make_result", [], ["Source not found: " + source], 1)
	var result: Dictionary = backend.call("copy_path", source, dest)
	if not bool(result.get("ok", false)):
		return backend.call("make_result", [], [str(result.get("error", "Could not copy"))], 1)
	return backend.call("make_result", ["Copied"])

func _cmd_mv(parsed: Dictionary, backend: Object) -> Dictionary:
	var args := _args(parsed)
	if args.size() < 2:
		return backend.call("make_result", [], ["Usage: mv <source> <dest>"], 1)
	var source := str(backend.call("resolve_path", str(args[0])))
	var dest := str(backend.call("resolve_path", str(args[1])))
	if not bool(backend.call("exists", source)):
		return backend.call("make_result", [], ["Source not found: " + source], 1)
	var result: Dictionary = backend.call("move_path", source, dest)
	if not bool(result.get("ok", false)):
		return backend.call("make_result", [], [str(result.get("error", "Could not move"))], 1)
	return backend.call("make_result", ["Moved"])

func _cmd_tree(parsed: Dictionary, backend: Object) -> Dictionary:
	backend_ref = backend
	var args := _args(parsed)
	var target := str(backend.call("get_cwd"))
	if args.size() >= 1:
		target = str(backend.call("resolve_path", str(args[0])))
	if not bool(backend.call("is_dir", target)):
		return backend.call("make_result", [], ["Not a directory: " + target], 1)
	var lines: Array[String] = []
	var base_name := target.get_file() if target != "/" else "/"
	lines.append(base_name + "/")
	_build_tree(target, "", lines, 0, 8)
	return backend.call("make_result", lines)

func _build_tree(dir_path: String, prefix: String, lines: Array[String], depth: int, max_depth: int) -> void:
	if depth >= max_depth:
		lines.append(prefix + "...")
		return
	if not bool(backend_ref.call("can_list_dir", dir_path)):
		return
	var entries_value: Variant = backend_ref.call("list_dir", dir_path)
	var entries: Array = entries_value if entries_value is Array else []
	var visible: Array[Dictionary] = []
	for entry_value in entries:
		if entry_value is Dictionary:
			visible.append(entry_value)
	for i in range(visible.size()):
		var entry: Dictionary = visible[i]
		var name := str(entry.get("name", ""))
		var is_last := i == visible.size() - 1
		var connector := "└── " if is_last else "├── "
		var is_subdir := str(entry.get("type", "")) == "dir"
		lines.append(prefix + connector + name + ("/" if is_subdir else ""))
		if is_subdir:
			var child_prefix := prefix + ("    " if is_last else "│   ")
			var child_path := dir_path.path_join(name)
			_build_tree(child_path, child_prefix, lines, depth + 1, max_depth)

var backend_ref: Object = null

func _cmd_head(parsed: Dictionary, backend: Object) -> Dictionary:
	var args := _args(parsed)
	if args.is_empty():
		return backend.call("make_result", [], ["Usage: head <path> [lines]"], 1)
	var target := str(backend.call("resolve_path", str(args[0])))
	var count := 10
	if args.size() >= 2:
		count = int(str(args[1]))
		if count <= 0:
			count = 10
	var result: Dictionary = backend.call("read_file", target)
	if not bool(result.get("ok", false)):
		return backend.call("make_result", [], [str(result.get("error", "Could not read file"))], 1)
	var content := str(result.get("content", ""))
	var file_lines := content.split("\n", true)
	var output: Array[String] = []
	for i in range(min(count, file_lines.size())):
		output.append(str(file_lines[i]))
	return backend.call("make_result", output)

func _cmd_tail(parsed: Dictionary, backend: Object) -> Dictionary:
	var args := _args(parsed)
	if args.is_empty():
		return backend.call("make_result", [], ["Usage: tail <path> [lines]"], 1)
	var target := str(backend.call("resolve_path", str(args[0])))
	var count := 10
	if args.size() >= 2:
		count = int(str(args[1]))
		if count <= 0:
			count = 10
	var result: Dictionary = backend.call("read_file", target)
	if not bool(result.get("ok", false)):
		return backend.call("make_result", [], [str(result.get("error", "Could not read file"))], 1)
	var content := str(result.get("content", ""))
	var file_lines := content.split("\n", true)
	var start := maxi(file_lines.size() - count, 0)
	var output: Array[String] = []
	for i in range(start, file_lines.size()):
		output.append(str(file_lines[i]))
	return backend.call("make_result", output)

func _cmd_grep(parsed: Dictionary, backend: Object) -> Dictionary:
	var args := _args(parsed)
	if args.size() < 2:
		return backend.call("make_result", [], ["Usage: grep <pattern> <path>"], 1)
	var pattern := str(args[0])
	var target := str(backend.call("resolve_path", str(args[1])))
	var result: Dictionary = backend.call("read_file", target)
	if not bool(result.get("ok", false)):
		return backend.call("make_result", [], [str(result.get("error", "Could not read file"))], 1)
	var content := str(result.get("content", ""))
	var file_lines := content.split("\n", true)
	var matches: Array[String] = []
	for i in range(file_lines.size()):
		var line := str(file_lines[i])
		if line.contains(pattern):
			matches.append("%d: %s" % [i + 1, line])
	if matches.is_empty():
		return backend.call("make_result", [], ["No matches found"], 1)
	return backend.call("make_result", matches)
