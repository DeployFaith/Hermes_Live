class_name HermesFileBridge
extends RefCounted

var _filesystem = null

func setup(context: Dictionary) -> HermesFileBridge:
	_filesystem = context.get("filesystem", null)
	return self

func pick() -> Dictionary:
	return {"ok": false, "error": {"code": "FILE_PICKER_UNAVAILABLE", "message": "HermesOS does not expose a controller-safe file picker yet", "details": {}}}

func read(path: String) -> Dictionary:
	if _filesystem == null:
		return _fail("FILES_UNAVAILABLE", "HermesOS filesystem service is unavailable")
	if _filesystem.has_method("read_file_result"):
		var result: Variant = _filesystem.call("read_file_result", path)
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
	if _filesystem.has_method("read_file"):
		return {"ok": true, "path": path, "content": str(_filesystem.call("read_file", path))}
	return _fail("FILES_READ_UNAVAILABLE", "HermesOS filesystem read API is unavailable")

func write(path: String, content: String) -> Dictionary:
	if _filesystem == null:
		return _fail("FILES_UNAVAILABLE", "HermesOS filesystem service is unavailable")
	if _filesystem.has_method("write_file"):
		var result: Variant = _filesystem.call("write_file", path, content)
		var message: String = str(result)
		return {"ok": message == "", "path": normalize(path), "error": {"code": "FILES_WRITE_FAILED", "message": message, "details": {}} if message != "" else {}}
	return _fail("FILES_WRITE_UNAVAILABLE", "HermesOS filesystem write API is unavailable")

func create_file(path: String, content: String = "") -> Dictionary:
	return write(path, content)

func list_dir(path: String) -> Array:
	if _filesystem != null and _filesystem.has_method("list_dir"):
		var result: Variant = _filesystem.call("list_dir", path)
		if result is Array:
			return (result as Array).duplicate(true)
	return []

func list(path: String) -> Dictionary:
	if _filesystem == null:
		return _fail("FILES_UNAVAILABLE", "HermesOS filesystem service is unavailable")
	var entries: Array = list_dir(path)
	return {"ok": true, "path": normalize(path), "entries": entries}

func make_dir(path: String) -> Dictionary:
	if _filesystem == null:
		return _fail("FILES_UNAVAILABLE", "HermesOS filesystem service is unavailable")
	if _filesystem.has_method("make_dir"):
		var message: String = str(_filesystem.call("make_dir", path))
		var already_exists: bool = message.begins_with("Path already exists")
		return {"ok": message == "" or already_exists, "path": normalize(path), "error": {"code": "FILES_MKDIR_FAILED", "message": message, "details": {}} if message != "" and not already_exists else {}}
	return _fail("FILES_MKDIR_UNAVAILABLE", "HermesOS filesystem mkdir API is unavailable")

func rename(path: String, new_name: String) -> Dictionary:
	if _filesystem == null:
		return _fail("FILES_UNAVAILABLE", "HermesOS filesystem service is unavailable")
	if _filesystem.has_method("rename_path"):
		var source: String = normalize(path)
		var message: String = str(_filesystem.call("rename_path", source, new_name))
		var target: String = join_path(dirname(source), new_name)
		return {"ok": message == "", "path": source, "target": target, "error": {"code": "FILES_RENAME_FAILED", "message": message, "details": {}} if message != "" else {}}
	return _fail("FILES_RENAME_UNAVAILABLE", "HermesOS filesystem rename API is unavailable")

func move(source_path: String, destination_path: String) -> Dictionary:
	if _filesystem == null:
		return _fail("FILES_UNAVAILABLE", "HermesOS filesystem service is unavailable")
	if _filesystem.has_method("move_path"):
		var message: String = str(_filesystem.call("move_path", source_path, destination_path))
		return {"ok": message == "", "source": normalize(source_path), "destination": normalize(destination_path), "error": {"code": "FILES_MOVE_FAILED", "message": message, "details": {}} if message != "" else {}}
	return _fail("FILES_MOVE_UNAVAILABLE", "HermesOS filesystem move API is unavailable")

func copy(source_path: String, destination_path: String) -> Dictionary:
	if _filesystem == null:
		return _fail("FILES_UNAVAILABLE", "HermesOS filesystem service is unavailable")
	if _filesystem.has_method("copy_path"):
		var message: String = str(_filesystem.call("copy_path", source_path, destination_path))
		return {"ok": message == "", "source": normalize(source_path), "destination": normalize(destination_path), "error": {"code": "FILES_COPY_FAILED", "message": message, "details": {}} if message != "" else {}}
	return _fail("FILES_COPY_UNAVAILABLE", "HermesOS filesystem copy API is unavailable")

func delete(path: String) -> Dictionary:
	if _filesystem == null:
		return _fail("FILES_UNAVAILABLE", "HermesOS filesystem service is unavailable")
	if _filesystem.has_method("delete_path"):
		var message: String = str(_filesystem.call("delete_path", path))
		return {"ok": message == "", "path": normalize(path), "error": {"code": "FILES_DELETE_FAILED", "message": message, "details": {}} if message != "" else {}}
	return _fail("FILES_DELETE_UNAVAILABLE", "HermesOS filesystem delete API is unavailable")

func trash_path(path: String) -> Dictionary:
	if _filesystem == null:
		return _fail("FILES_UNAVAILABLE", "HermesOS filesystem service is unavailable")
	if _filesystem.has_method("trash_path"):
		var result: Variant = _filesystem.call("trash_path", path)
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
		return {"ok": bool(result), "path": normalize(path), "error": {} if bool(result) else {"code": "FILES_TRASH_FAILED", "message": "Could not move item to Trash", "details": {}}}
	return _fail("FILES_TRASH_UNAVAILABLE", "HermesOS filesystem trash API is unavailable")

func empty_trash() -> Dictionary:
	if _filesystem == null:
		return _fail("FILES_UNAVAILABLE", "HermesOS filesystem service is unavailable")
	if _filesystem.has_method("empty_trash"):
		var result: Variant = _filesystem.call("empty_trash")
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
		return {"ok": bool(result), "error": {} if bool(result) else {"code": "FILES_EMPTY_TRASH_FAILED", "message": "Could not empty Trash", "details": {}}}
	return _fail("FILES_EMPTY_TRASH_UNAVAILABLE", "HermesOS filesystem empty trash API is unavailable")

func trash_item_count() -> int:
	if _filesystem != null and _filesystem.has_method("trash_item_count"):
		return int(_filesystem.call("trash_item_count"))
	return 0

func exists(path: String) -> bool:
	if _filesystem != null and _filesystem.has_method("exists"):
		return bool(_filesystem.call("exists", path))
	return is_file(path) or is_dir(path)

func is_file(path: String) -> bool:
	if _filesystem != null and _filesystem.has_method("is_file"):
		return bool(_filesystem.call("is_file", path))
	return false

func is_dir(path: String) -> bool:
	if _filesystem != null and _filesystem.has_method("is_dir"):
		return bool(_filesystem.call("is_dir", path))
	return false

func stat(path: String) -> Dictionary:
	if _filesystem == null:
		return _fail("FILES_UNAVAILABLE", "HermesOS filesystem service is unavailable")
	var normalized: String = normalize(path)
	if _filesystem.has_method("get_node_at"):
		var node_value: Variant = _filesystem.call("get_node_at", normalized)
		if node_value is Dictionary:
			var node: Dictionary = node_value
			if node.is_empty():
				return _fail("FILES_STAT_NOT_FOUND", "Path not found: " + normalized)
			var node_type: String = str(node.get("type", "file"))
			var size_value: int = 0
			if node_type == "file":
				size_value = str(node.get("content", "")).length()
			else:
				var children: Dictionary = node.get("children", {})
				size_value = children.size()
			return {
				"ok": true,
				"path": normalized,
				"type": node_type,
				"size": size_value,
				"owner": str(node.get("owner", "")),
				"group": str(node.get("group", "")),
				"mode": str(node.get("mode", ""))
			}
	if _filesystem.has_method("stat_text"):
		return {"ok": true, "path": normalized, "text": str(_filesystem.call("stat_text", normalized))}
	return _fail("FILES_STAT_UNAVAILABLE", "HermesOS filesystem stat API is unavailable")

func normalize(path: String) -> String:
	if _filesystem != null and _filesystem.has_method("normalize_path"):
		return str(_filesystem.call("normalize_path", path))
	return path

func resolve(path: String, base_path: String = "") -> String:
	if _filesystem != null and _filesystem.has_method("resolve_path"):
		return str(_filesystem.call("resolve_path", path, base_path))
	return normalize(path)

func dirname(path: String) -> String:
	if _filesystem != null and _filesystem.has_method("parent_path"):
		return str(_filesystem.call("parent_path", path))
	return normalize(path.get_base_dir())

func parent_path(path: String) -> String:
	return dirname(path)

func basename(path: String) -> String:
	var normalized: String = normalize(path)
	return normalized.get_file()

func home_path() -> String:
	if _filesystem != null and _filesystem.has_method("home_path"):
		return str(_filesystem.call("home_path"))
	return "/"

func join_path(base: String, child: String) -> String:
	if _filesystem != null and _filesystem.has_method("join_path"):
		return str(_filesystem.call("join_path", base, child))
	return normalize(base.rstrip("/") + "/" + child.lstrip("/"))

func _fail(code: String, message: String) -> Dictionary:
	return {"ok": false, "error": {"code": code, "message": message, "details": {}}}
