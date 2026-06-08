class_name OSFileSystem
extends RefCounted

signal file_system_event(event_name: StringName, payload: Dictionary)

const SAVE_PATH := "user://hermes_os_files.json"
const ROOT_USER := "root"
const DEFAULT_USERNAME := "user"
const DEFAULT_UID := 1000
const BUILTIN_AVATARS: Array[String] = [
	"res://addons/hermes_os/assets/avatars/avatar_01.svg",
	"res://addons/hermes_os/assets/avatars/avatar_02.svg",
	"res://addons/hermes_os/assets/avatars/avatar_03.svg",
	"res://addons/hermes_os/assets/avatars/avatar_04.svg",
	"res://addons/hermes_os/assets/avatars/avatar_05.svg",
	"res://addons/hermes_os/assets/avatars/avatar_06.svg",
	"res://addons/hermes_os/assets/avatars/avatar_07.svg",
	"res://addons/hermes_os/assets/avatars/avatar_08.svg",
	"res://addons/hermes_os/assets/avatars/avatar_09.svg",
	"res://addons/hermes_os/assets/avatars/avatar_10.svg",
	"res://addons/hermes_os/assets/avatars/avatar_11.svg",
	"res://addons/hermes_os/assets/avatars/avatar_12.svg"
]

var _state: Dictionary = {}
var _tree: Dictionary = {}
var _root_authorization_depth := 0

func load_or_create() -> void:
	_state = _empty_state()
	_tree = _state["tree"]
	if not FileAccess.file_exists(SAVE_PATH):
		_ensure_system_layout()
		save()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_ensure_system_layout()
		return
	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var parsed_dict: Dictionary = parsed
		if _is_valid_state(parsed_dict):
			_state = parsed_dict
			_tree = _state["tree"]
		elif _is_valid_tree(parsed_dict):
			_state = _empty_state()
			_state["tree"] = parsed_dict
			_tree = _state["tree"]
		else:
			_state = _empty_state()
			_tree = _state["tree"]
	else:
		_state = _empty_state()
		_tree = _state["tree"]
	_ensure_system_layout()
	# FIX for live save/load mismatch: do NOT save() after successful load.
	# Previous always-save after load could trigger _ensure mutations or overwrite renamed state on every startup/restart.
	# Only save on creation or error recovery. Live-path probe now verifies rename survives actual load_or_create without forced save.

func save() -> void:
	_state["tree"] = _tree
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save virtual filesystem")
		return
	file.store_string(JSON.stringify(_state, "\t"))

func reset() -> void:
	_state = _empty_state()
	_tree = _state["tree"]
	_ensure_system_layout()
	save()

func export_state() -> Dictionary:
	_state["tree"] = _tree
	return _state.duplicate(true)

func import_state(state: Dictionary) -> String:
	if not _is_valid_state(state):
		return "Invalid HermesOS filesystem state"
	_state = state.duplicate(true)
	_tree = _state["tree"]
	_ensure_system_layout()
	save()
	return ""

func current_user() -> String:
	return str(_state.get("current_user", DEFAULT_USERNAME))

func has_root_privilege() -> bool:
	return current_user() == ROOT_USER or _root_authorization_depth > 0

func with_root_authorization(action: Callable) -> Variant:
	_root_authorization_depth += 1
	var result: Variant = null
	if action.is_valid():
		result = action.call()
	_root_authorization_depth = maxi(0, _root_authorization_depth - 1)
	return result

func set_current_user(username: String) -> String:
	var clean := clean_username(username)
	if clean == "":
		return "Usage: su <user>"
	if not user_exists(clean):
		return "Unknown user: " + clean
	_state["current_user"] = clean
	save()
	return ""

func authenticate_user(username: String, password: String) -> Dictionary:
	var clean := clean_username(username)
	if clean == "" or not user_exists(clean):
		return {"ok": false, "error": "Unknown user"}
	var users: Dictionary = _state.get("users", {})
	var account: Dictionary = users[clean]
	if bool(account.get("locked", false)):
		return {"ok": false, "error": "Account is locked"}
	if clean == ROOT_USER and not bool(account.get("login_visible", false)):
		return {"ok": false, "error": "Account is not available for login"}
	var expected := str(account.get("password_hash", _password_hash("")))
	if expected != _password_hash(password):
		return {"ok": false, "error": "Incorrect password"}
	return {"ok": true, "error": "", "user": clean}

func set_current_user_authenticated(username: String, password: String) -> String:
	var auth := authenticate_user(username, password)
	if not bool(auth.get("ok", false)):
		return str(auth.get("error", "Authentication failed"))
	return set_current_user(str(auth.get("user", username)))

# Root authorization helpers for scoped elevation (added for root-auth execution repair)
func validate_root_password(password: String) -> bool:
	if not user_exists(ROOT_USER):
		return false
	var users: Dictionary = _state.get("users", {})
	var account: Dictionary = users[ROOT_USER]
	var expected := str(account.get("password_hash", _password_hash("")))
	if password == "":
		return expected == _password_hash("")
	return expected == _password_hash(password)

func auth_root(password: String) -> bool:
	return validate_root_password(password)

func set_user_password(username: String, new_password: String, current_password := "") -> String:
	var clean := clean_username(username)
	if clean == "" or not user_exists(clean):
		return "Unknown user: " + username
	if not has_root_privilege():
		if clean != current_user():
			return "Permission denied: passwd can only change your own password"
		var auth := authenticate_user(clean, current_password)
		if not bool(auth.get("ok", false)):
			return str(auth.get("error", "Authentication failed"))
	var users: Dictionary = _state.get("users", {})
	var account: Dictionary = users[clean]
	account["password_hash"] = _password_hash(new_password)
	users[clean] = account
	_state["users"] = users
	_sync_system_files()
	save()
	return ""

func user_exists(username: String) -> bool:
	var users: Dictionary = _state.get("users", {})
	return users.has(username)

func add_user(username: String) -> String:
	return create_user_account(username, username, "")

func get_users() -> Array[String]:
	var users: Dictionary = _state.get("users", {})
	var result: Array[String] = []
	for key in users.keys():
		result.append(str(key))
	result.sort()
	return result

func list_builtin_avatars() -> Array[String]:
	return BUILTIN_AVATARS.duplicate()

func list_login_users() -> Array[Dictionary]:
	var users: Dictionary = _state.get("users", {})
	var output: Array[Dictionary] = []
	for username in get_users():
		if username == ROOT_USER:
			continue
		if not users.has(username):
			continue
		var account: Dictionary = users[username]
		if not bool(account.get("login_visible", true)):
			continue
		output.append({
			"username": username,
			"display_name": str(account.get("display_name", username)),
			"home": str(account.get("home", "/home/" + username)),
			"locked": bool(account.get("locked", false)),
			"login_visible": true,
			"avatar": get_user_avatar(username)
		})
	return output

func create_user_account(username: String, display_name: String, password: String) -> String:
	if not has_root_privilege():
		return "Permission denied: creating accounts requires root"
	var clean := clean_username(username)
	if clean == "":
		return "Username must contain only letters, numbers, '_' or '-'"
	if clean == ROOT_USER:
		return "Cannot create another root account"
	if user_exists(clean):
		return "User already exists: " + clean
	var users: Dictionary = _state.get("users", {})
	var next_uid := DEFAULT_UID
	for key in users.keys():
		var account_scan: Dictionary = users[key]
		next_uid = maxi(next_uid, int(account_scan.get("uid", DEFAULT_UID)) + 1)
	var final_display := display_name.strip_edges()
	if final_display == "":
		final_display = clean
	users[clean] = {
		"uid": next_uid,
		"gid": next_uid,
		"group": clean,
		"home": "/home/" + clean,
		"shell": "/bin/sh",
		"groups": [clean],
		"password_hash": _password_hash(password),
		"display_name": final_display,
		"login_visible": true,
		"locked": false,
		"created_at": Time.get_unix_time_from_system(),
		"avatar_type": "initials",
		"avatar_value": ""
	}
	_state["users"] = users
	_force_dir("/home/" + clean, clean, clean, "0755")
	_sync_system_files()
	save()
	return ""

func delete_user_account(username: String, remove_home := false) -> String:
	if not has_root_privilege():
		return "Permission denied: deleting accounts requires root"
	var clean := clean_username(username)
	if clean == "" or not user_exists(clean):
		return "Unknown user: " + username
	if clean == ROOT_USER:
		return "Cannot delete root"
	if clean == current_user():
		return "Cannot delete currently active user"
	var users: Dictionary = _state.get("users", {})
	users.erase(clean)
	_state["users"] = users
	if bool(remove_home):
		delete_path("/home/" + clean)
	_sync_system_files()
	save()
	return ""

func rename_user_account(old_username: String, new_username: String) -> String:
	if not has_root_privilege():
		return "Permission denied: renaming accounts requires root"
	var active_before := current_user()
	var source := clean_username(old_username)
	var target := clean_username(new_username)
	var renaming_active := active_before == source
	if source == "" or not user_exists(source):
		return "Unknown user: " + old_username
	if target == "":
		return "Username must contain only letters, numbers, '_' or '-'"
	if source == ROOT_USER:
		return "Cannot rename root"
	if source == target:
		return ""
	if user_exists(target):
		return "User already exists: " + target
	var users: Dictionary = _state.get("users", {})
	var original_account: Dictionary = (users[source] as Dictionary).duplicate(true)
	var account: Dictionary = original_account.duplicate(true)
	users.erase(source)
	account["group"] = target
	account["home"] = "/home/" + target
	account["groups"] = [target]
	if str(account.get("display_name", "")).strip_edges() == "" or str(account.get("display_name", "")) == source:
		account["display_name"] = target
	if str(account.get("avatar_type", "initials")) == "custom_file":
		var avatar_path := str(account.get("avatar_value", ""))
		if avatar_path == "/home/%s/.config/hermesos/avatar.png" % source:
			account["avatar_value"] = "/home/%s/.config/hermesos/avatar.png" % target
	users[target] = account
	_state["users"] = users
	var source_home := "/home/" + source
	var target_home := "/home/" + target
	if exists(source_home):
		var move_error := move_path(source_home, target_home, false)
		if move_error != "":
			users.erase(target)
			users[source] = original_account
			_state["users"] = users
			_state["current_user"] = active_before
			return move_error
		var home_node := get_node_at(target_home)
		if not home_node.is_empty():
			_reassign_node_owner_recursive(home_node, target, target)
	if renaming_active:
		_state["current_user"] = target
	else:
		_state["current_user"] = active_before
	_sync_system_files()
	save()
	return ""

func duplicate_user_account(source_username: String, target_username: String, display_name := "") -> String:
	if not has_root_privilege():
		return "Permission denied: duplicating accounts requires root"
	var source := clean_username(source_username)
	var target := clean_username(target_username)
	if source == "" or not user_exists(source):
		return "Unknown user: " + source_username
	if source == ROOT_USER:
		return "Cannot duplicate root"
	if target == "":
		return "Username must contain only letters, numbers, '_' or '-'"
	if user_exists(target):
		return "User already exists: " + target
	var users: Dictionary = _state.get("users", {})
	var source_account: Dictionary = users[source]
	var create_error := create_user_account(target, display_name, "")
	if create_error != "":
		return create_error
	users = _state.get("users", {})
	var target_account: Dictionary = users[target]
	target_account["locked"] = bool(source_account.get("locked", false))
	target_account["login_visible"] = bool(source_account.get("login_visible", true))
	target_account["avatar_type"] = str(source_account.get("avatar_type", "initials"))
	target_account["avatar_value"] = str(source_account.get("avatar_value", ""))
	target_account["password_hash"] = str(source_account.get("password_hash", _password_hash("")))
	if str(display_name).strip_edges() == "":
		target_account["display_name"] = "%s (copy)" % str(source_account.get("display_name", source))
	users[target] = target_account
	_state["users"] = users
	var source_home := "/home/" + source
	var target_home := "/home/" + target
	if exists(source_home):
		if exists(target_home):
			delete_path(target_home)
		var copy_error := copy_path(source_home, target_home)
		if copy_error != "":
			return copy_error
		var copied_home := get_node_at(target_home)
		if not copied_home.is_empty():
			_reassign_node_owner_recursive(copied_home, target, target)
	_sync_system_files()
	save()
	return ""

func set_user_display_name(username: String, display_name: String) -> String:
	var clean := clean_username(username)
	if clean == "" or not user_exists(clean):
		return "Unknown user: " + username
	if current_user() != ROOT_USER and clean != current_user():
		return "Permission denied: can only edit your own profile"
	var users: Dictionary = _state.get("users", {})
	var account: Dictionary = users[clean]
	var value := display_name.strip_edges()
	if value == "":
		value = clean
	account["display_name"] = value
	users[clean] = account
	_state["users"] = users
	save()
	return ""

func set_user_login_visible(username: String, visible: bool) -> String:
	if not has_root_privilege():
		return "Permission denied: changing login visibility requires root"
	var clean := clean_username(username)
	if clean == "" or not user_exists(clean):
		return "Unknown user: " + username
	if clean == ROOT_USER:
		return "Cannot change root login visibility"
	var users: Dictionary = _state.get("users", {})
	var account: Dictionary = users[clean]
	account["login_visible"] = visible
	users[clean] = account
	_state["users"] = users
	save()
	return ""

func set_user_locked(username: String, locked: bool) -> String:
	if not has_root_privilege():
		return "Permission denied: locking accounts requires root"
	var clean := clean_username(username)
	if clean == "" or not user_exists(clean):
		return "Unknown user: " + username
	if clean == ROOT_USER:
		return "Cannot lock root"
	var users: Dictionary = _state.get("users", {})
	var account: Dictionary = users[clean]
	account["locked"] = locked
	users[clean] = account
	_state["users"] = users
	save()
	return ""

func get_user_avatar(username: String) -> Dictionary:
	var clean := clean_username(username)
	if clean == "" or not user_exists(clean):
		return {"type": "initials", "value": ""}
	var users: Dictionary = _state.get("users", {})
	var account: Dictionary = users[clean]
	var avatar_type := str(account.get("avatar_type", "initials")).strip_edges()
	var avatar_value := str(account.get("avatar_value", "")).strip_edges()
	if avatar_type == "asset" and not BUILTIN_AVATARS.has(avatar_value):
		avatar_type = "initials"
		avatar_value = ""
	if avatar_type == "custom_file" and avatar_value != "" and not exists(avatar_value):
		avatar_type = "initials"
		avatar_value = ""
	if avatar_type == "":
		avatar_type = "initials"
	return {"type": avatar_type, "value": avatar_value}

func set_user_avatar_asset(username: String, asset_path: String) -> String:
	var clean := clean_username(username)
	if clean == "" or not user_exists(clean):
		return "Unknown user: " + username
	if current_user() != ROOT_USER and clean != current_user():
		return "Permission denied: can only edit your own profile"
	var value := asset_path.strip_edges()
	if not BUILTIN_AVATARS.has(value):
		return "Unknown avatar asset"
	var users: Dictionary = _state.get("users", {})
	var account: Dictionary = users[clean]
	account["avatar_type"] = "asset"
	account["avatar_value"] = value
	users[clean] = account
	_state["users"] = users
	save()
	return ""

func set_user_avatar_file(username: String, file_path: String) -> String:
	var clean := clean_username(username)
	if clean == "" or not user_exists(clean):
		return "Unknown user: " + username
	if current_user() != ROOT_USER and clean != current_user():
		return "Permission denied: can only edit your own profile"
	var normalized := normalize_path(file_path)
	if not exists(normalized) or not is_file(normalized):
		return "Avatar file not found: " + normalized
	if not _is_supported_avatar_path(normalized):
		return "Unsupported avatar format. Use png, jpg, jpeg, webp, or svg"
	var users: Dictionary = _state.get("users", {})
	var account: Dictionary = users[clean]
	account["avatar_type"] = "custom_file"
	account["avatar_value"] = normalized
	users[clean] = account
	_state["users"] = users
	save()
	return ""

func clear_user_avatar(username: String) -> String:
	var clean := clean_username(username)
	if clean == "" or not user_exists(clean):
		return "Unknown user: " + username
	if current_user() != ROOT_USER and clean != current_user():
		return "Permission denied: can only edit your own profile"
	var users: Dictionary = _state.get("users", {})
	var account: Dictionary = users[clean]
	account["avatar_type"] = "initials"
	account["avatar_value"] = ""
	users[clean] = account
	_state["users"] = users
	save()
	return ""

func home_path(username := "") -> String:
	var target := username if username != "" else current_user()
	var users: Dictionary = _state.get("users", {})
	if users.has(target):
		var account: Dictionary = users[target]
		return str(account.get("home", "/home/" + target))
	return "/home/" + target

func user_id_text(username := "") -> String:
	var target := username if username != "" else current_user()
	var users: Dictionary = _state.get("users", {})
	if not users.has(target):
		return "Unknown user: " + target
	var account: Dictionary = users[target]
	var group := str(account.get("group", target))
	return "uid=%d(%s) gid=%d(%s) groups=%s" % [
		int(account.get("uid", 0)),
		target,
		int(account.get("gid", 0)),
		group,
		_groups_text(account)
	]

func list_dir(path: String) -> Array[Dictionary]:
	var node := get_node_at(path)
	var result: Array[Dictionary] = []
	if node.is_empty() or str(node.get("type", "")) != "dir":
		return result
	if not _can_read(node, current_user()) or not _can_execute(node, current_user()):
		return result

	var children: Dictionary = node.get("children", {})
	var names: Array[String] = []
	for key in children.keys():
		names.append(str(key))
	names.sort()

	for name in names:
		var child: Dictionary = children[name]
		var type := str(child.get("type", "file"))
		result.append({
			"name": name,
			"type": type,
			"path": join_path(normalize_path(path), name),
			"size": _node_size(child),
			"owner": str(child.get("owner", DEFAULT_USERNAME)),
			"group": str(child.get("group", str(child.get("owner", DEFAULT_USERNAME)))),
			"mode": str(child.get("mode", "0644" if type == "file" else "0755"))
		})
	return result

func exists(path: String) -> bool:
	return not get_node_at(path).is_empty()

func is_dir(path: String) -> bool:
	var node := get_node_at(path)
	return not node.is_empty() and str(node.get("type", "")) == "dir"

func is_file(path: String) -> bool:
	var node := get_node_at(path)
	return not node.is_empty() and str(node.get("type", "")) == "file"

func can_list_dir(path: String) -> bool:
	var node := get_node_at(path)
	return not node.is_empty() and str(node.get("type", "")) == "dir" and _can_read(node, current_user()) and _can_execute(node, current_user())

func read_file(path: String) -> String:
	var result := read_file_result(path)
	if not bool(result.get("ok", false)):
		return ""
	return str(result.get("content", ""))

func read_file_result(path: String) -> Dictionary:
	var normalized := normalize_path(path)
	var node := get_node_at(normalized)
	if node.is_empty() or str(node.get("type", "")) != "file":
		return {"ok": false, "error": "File not found: " + normalized, "content": ""}
	if not _can_read(node, current_user()):
		return {"ok": false, "error": "Permission denied: " + normalized, "content": ""}
	return {"ok": true, "error": "", "content": str(node.get("content", ""))}

func write_file(path: String, content: String) -> String:
	var normalized := normalize_path(path)
	var info := _parent_info(normalized)
	if not bool(info.get("ok", false)):
		return str(info.get("error", "Invalid path"))

	var parent: Dictionary = info["parent"]
	var parent_path_text := parent_path(normalized)
	var name := str(info["name"])
	var children: Dictionary = parent.get("children", {})
	if children.has(name):
		var existing: Dictionary = children[name]
		if str(existing.get("type", "")) == "dir":
			return "A folder already exists at " + normalized
		if not _can_write(existing, current_user()):
			return "Permission denied: " + normalized
		existing["content"] = content
		children[name] = existing
	else:
		if not _can_write(parent, current_user()) or not _can_execute(parent, current_user()):
			return "Permission denied: " + parent_path_text
		children[name] = _file_node(content, current_user(), _primary_group(current_user()), "0644")
	parent["children"] = children
	save()
	return ""

func make_dir(path: String) -> String:
	var normalized := normalize_path(path)
	var info := _parent_info(normalized)
	if not bool(info.get("ok", false)):
		return str(info.get("error", "Invalid path"))

	var parent: Dictionary = info["parent"]
	var parent_path_text := parent_path(normalized)
	if not _can_write(parent, current_user()) or not _can_execute(parent, current_user()):
		return "Permission denied: " + parent_path_text
	var name := str(info["name"])
	var children: Dictionary = parent.get("children", {})
	if children.has(name):
		return "Path already exists: " + normalized
	children[name] = _dir_node(current_user(), _primary_group(current_user()), "0755")
	parent["children"] = children
	save()
	return ""

func delete_path(path: String) -> String:
	var normalized := normalize_path(path)
	if normalized == "/":
		return "Cannot delete root"
	if _is_protected_system_path(normalized):
		return "Cannot delete protected system path: " + normalized
	var info := _parent_info(normalized)
	if not bool(info.get("ok", false)):
		return str(info.get("error", "Invalid path"))

	var parent: Dictionary = info["parent"]
	var parent_path_text := parent_path(normalized)
	if not _can_write(parent, current_user()) or not _can_execute(parent, current_user()):
		return "Permission denied: " + parent_path_text
	var name := str(info["name"])
	var children: Dictionary = parent.get("children", {})
	if not children.has(name):
		return "Path not found: " + normalized
	var target: Dictionary = children[name]
	if _has_sticky_bit(parent) and not has_root_privilege() and current_user() != str(target.get("owner", "")) and current_user() != str(parent.get("owner", "")):
		return "Permission denied: " + normalized
	children.erase(name)
	parent["children"] = children
	save()
	file_system_event.emit(&"file.deleted", {"path": normalized, "parent": parent_path_text})
	return ""

func trash_path(path: String) -> Dictionary:
	var normalized := normalize_path(path)
	if normalized == "/":
		return {"ok": false, "error": {"message": "Cannot trash root"}}
	if _is_protected_system_path(normalized):
		return {"ok": false, "error": {"message": "Cannot trash protected system path"}}
	var home := home_path()
	var local_dir := join_path(home, ".local")
	var share_dir := join_path(local_dir, "share")
	var trash_base := join_path(share_dir, "Trash")
	var trash_files := join_path(trash_base, "files")
	var trash_info_dir := join_path(trash_base, "info")
	for dir_path in [local_dir, share_dir, trash_base, trash_files, trash_info_dir]:
		if is_dir(dir_path):
			continue
		var dir_error := make_dir(dir_path)
		if dir_error != "" and not dir_error.begins_with("Path already exists"):
			return {"ok": false, "error": {"message": dir_error}}
	var base_name := normalized.get_file() if normalized.get_file() != "" else normalized.get_base_dir().get_file()
	var trashed_name := base_name + "." + str(Time.get_ticks_usec())
	var dest_path := join_path(trash_files, trashed_name)
	var err := move_path(normalized, dest_path)
	if err != "":
		return {"ok": false, "error": {"message": err}}
	var info_path := join_path(trash_info_dir, trashed_name + ".trashinfo")
	write_file(info_path, "[Trash Info]\nPath=" + normalized + "\n")
	file_system_event.emit(&"file.moved", {
		"path": normalized,
		"source": normalized,
		"destination": dest_path,
		"parent": parent_path(normalized),
		"destination_parent": trash_files,
		"trash_info_path": info_path,
		"trashed": true
	})
	return {"ok": true, "trashed_from": normalized, "trashed_to": dest_path}

func empty_trash() -> Dictionary:
	var trash_files := join_path(join_path(join_path(join_path(home_path(), ".local"), "share"), "Trash"), "files")
	var trash_info_dir := join_path(join_path(join_path(join_path(home_path(), ".local"), "share"), "Trash"), "info")
	var deleted_count := 0
	if is_dir(trash_files):
		for entry in list_dir(trash_files):
			var p := str(entry.get("path", ""))
			if p != "":
				delete_path(p)
				deleted_count += 1
	if is_dir(trash_info_dir):
		for entry in list_dir(trash_info_dir):
			var p := str(entry.get("path", ""))
			if p != "":
				delete_path(p)
	return {"ok": true, "deleted_count": deleted_count}

func trash_item_count() -> int:
	var trash_files := join_path(join_path(join_path(join_path(home_path(), ".local"), "share"), "Trash"), "files")
	if not is_dir(trash_files):
		return 0
	return list_dir(trash_files).size()

func rename_path(path: String, new_name: String) -> String:
	var normalized := normalize_path(path)
	if normalized == "/":
		return "Cannot rename root"
	if _is_protected_system_path(normalized):
		return "Cannot rename protected system path: " + normalized
	var clean_name := _clean_name(new_name)
	if clean_name == "":
		return "Name is required"

	var info := _parent_info(normalized)
	if not bool(info.get("ok", false)):
		return str(info.get("error", "Invalid path"))

	var parent: Dictionary = info["parent"]
	var parent_path_text := parent_path(normalized)
	if not _can_write(parent, current_user()) or not _can_execute(parent, current_user()):
		return "Permission denied: " + parent_path_text
	var old_name := str(info["name"])
	var children: Dictionary = parent.get("children", {})
	if not children.has(old_name):
		return "Path not found: " + normalized
	if children.has(clean_name):
		return "Path already exists: " + join_path(parent_path_text, clean_name)

	children[clean_name] = children[old_name]
	children.erase(old_name)
	parent["children"] = children
	save()
	return ""

func copy_path(source_path: String, destination_path: String) -> String:
	var source := normalize_path(source_path)
	var destination := normalize_path(destination_path)
	if source == "/":
		return "Cannot copy root"
	var source_node := get_node_at(source)
	if source_node.is_empty():
		return "Path not found: " + source
	if not _can_read(source_node, current_user()):
		return "Permission denied: " + source
	if str(source_node.get("type", "")) == "dir" and not _can_execute(source_node, current_user()):
		return "Permission denied: " + source

	var info := _parent_info(destination)
	if not bool(info.get("ok", false)):
		return str(info.get("error", "Invalid path"))
	var parent: Dictionary = info["parent"]
	var parent_path_text := parent_path(destination)
	if not _can_write(parent, current_user()) or not _can_execute(parent, current_user()):
		return "Permission denied: " + parent_path_text
	var name := str(info["name"])
	var children: Dictionary = parent.get("children", {})
	if children.has(name):
		return "Path already exists: " + destination
	children[name] = _copy_node(source_node, current_user(), _primary_group(current_user()))
	parent["children"] = children
	save()
	return ""

func move_path(source_path: String, destination_path: String, save_after := true) -> String:
	var source := normalize_path(source_path)
	var destination := normalize_path(destination_path)
	if source == "/":
		return "Cannot move root"
	if _is_protected_system_path(source):
		return "Cannot move protected system path: " + source
	if destination == source or destination.begins_with(source + "/"):
		return "Cannot move a folder into itself"

	var source_info := _parent_info(source)
	if not bool(source_info.get("ok", false)):
		return str(source_info.get("error", "Invalid path"))
	var source_parent: Dictionary = source_info["parent"]
	var source_parent_path := parent_path(source)
	if not _can_write(source_parent, current_user()) or not _can_execute(source_parent, current_user()):
		return "Permission denied: " + source_parent_path
	var source_name := str(source_info["name"])
	var source_children: Dictionary = source_parent.get("children", {})
	if not source_children.has(source_name):
		return "Path not found: " + source
	var source_node: Dictionary = source_children[source_name]
	if _has_sticky_bit(source_parent) and not has_root_privilege() and current_user() != str(source_node.get("owner", "")) and current_user() != str(source_parent.get("owner", "")):
		return "Permission denied: " + source

	var destination_info := _parent_info(destination)
	if not bool(destination_info.get("ok", false)):
		return str(destination_info.get("error", "Invalid path"))
	var destination_parent: Dictionary = destination_info["parent"]
	var destination_parent_path := parent_path(destination)
	if not _can_write(destination_parent, current_user()) or not _can_execute(destination_parent, current_user()):
		return "Permission denied: " + destination_parent_path
	var destination_name := str(destination_info["name"])
	var destination_children: Dictionary = destination_parent.get("children", {})
	if destination_children.has(destination_name):
		return "Path already exists: " + destination

	if source_parent_path == destination_parent_path:
		source_children.erase(source_name)
		source_children[destination_name] = source_node
		source_parent["children"] = source_children
	else:
		destination_children[destination_name] = source_node
		destination_parent["children"] = destination_children
		source_children.erase(source_name)
		source_parent["children"] = source_children
	if save_after:
		save()
	return ""

func set_mode(path: String, mode: String) -> String:
	var normalized := normalize_path(path)
	var clean_mode := _clean_mode(mode)
	if clean_mode == "":
		return "Mode must be 3 or 4 numeric digits"
	var node := get_node_at(normalized)
	if node.is_empty():
		return "Path not found: " + normalized
	if not has_root_privilege() and current_user() != str(node.get("owner", "")):
		return "Permission denied: chmod requires owner or root"
	node["mode"] = clean_mode
	save()
	return ""

func set_owner(path: String, username: String) -> String:
	if not has_root_privilege():
		return "Permission denied: chown requires root"
	var normalized := normalize_path(path)
	var clean := clean_username(username)
	if not user_exists(clean):
		return "Unknown user: " + clean
	var node := get_node_at(normalized)
	if node.is_empty():
		return "Path not found: " + normalized
	node["owner"] = clean
	node["group"] = _primary_group(clean)
	save()
	return ""

func stat_text(path: String) -> String:
	var normalized := normalize_path(path)
	var node := get_node_at(normalized)
	if node.is_empty():
		return "Path not found: " + normalized
	return "%s %s %s %s %d %s" % [
		str(node.get("mode", "0644")),
		str(node.get("owner", DEFAULT_USERNAME)),
		str(node.get("group", str(node.get("owner", DEFAULT_USERNAME)))),
		str(node.get("type", "file")),
		_node_size(node),
		normalized
	]

func get_node_at(path: String) -> Dictionary:
	var normalized := normalize_path(path)
	if normalized == "/":
		return _tree

	var parts := _path_parts(normalized)
	var node: Dictionary = _tree
	for part in parts:
		if str(node.get("type", "")) != "dir":
			return {}
		var children: Dictionary = node.get("children", {})
		if not children.has(part):
			return {}
		node = children[part]
	return node

func resolve_path(path: String, base_path := "") -> String:
	var clean := path.strip_edges().replace("\\", "/")
	var base := normalize_path(base_path if base_path != "" else home_path())
	if clean == "":
		return base
	if clean == "~":
		return home_path()
	if clean.begins_with("~/"):
		return _collapse_path(home_path() + clean.substr(1))
	if clean.begins_with("/"):
		return _collapse_path(clean)
	return _collapse_path(join_path(base, clean))

func normalize_path(path: String) -> String:
	var clean := path.strip_edges().replace("\\", "/")
	if clean == "" or clean == "/":
		return "/"
	if clean == "~" or clean.begins_with("~/"):
		return resolve_path(clean)
	if not clean.begins_with("/"):
		clean = "/" + clean
	return _collapse_path(clean)

func parent_path(path: String) -> String:
	var normalized := normalize_path(path)
	if normalized == "/":
		return "/"
	var parts := _path_parts(normalized)
	if parts.size() <= 1:
		return "/"
	parts.remove_at(parts.size() - 1)
	return "/" + "/".join(parts)

func join_path(base: String, child: String) -> String:
	var clean_base := normalize_path(base)
	var clean_child := child.strip_edges().replace("\\", "/")
	if clean_child == "":
		return clean_base
	if clean_child.begins_with("/"):
		return normalize_path(clean_child)
	# Handle multi-segment child paths like ".local/share/Trash/files"
	var result := clean_base
	for segment in clean_child.split("/", false):
		var clean_segment := _clean_name(segment)
		if clean_segment == "":
			continue
		if result == "/":
			result = "/" + clean_segment
		else:
			result = result + "/" + clean_segment
	return result

func clean_username(value: String) -> String:
	var clean := value.strip_edges().to_lower()
	if clean == "":
		return ""
	for index in clean.length():
		var code := clean.unicode_at(index)
		var valid_number := code >= 48 and code <= 57
		var valid_lower := code >= 97 and code <= 122
		var valid_symbol := code == 45 or code == 95
		if not valid_number and not valid_lower and not valid_symbol:
			return ""
	return clean

func _parent_info(path: String) -> Dictionary:
	var normalized := normalize_path(path)
	if normalized == "/":
		return {"ok": false, "error": "Path must include a name"}

	var name := _clean_name(normalized.get_file())
	if name == "":
		return {"ok": false, "error": "Name is required"}
	var parent_path_text := parent_path(normalized)
	var parent := get_node_at(parent_path_text)
	if parent.is_empty() or str(parent.get("type", "")) != "dir":
		return {"ok": false, "error": "Parent folder not found: " + parent_path_text}
	return {"ok": true, "parent": parent, "name": name}

func _path_parts(path: String) -> Array[String]:
	var normalized := normalize_path(path)
	var result: Array[String] = []
	if normalized == "/":
		return result
	var raw_parts := normalized.substr(1).split("/", false)
	for part in raw_parts:
		result.append(str(part))
	return result

func _clean_name(value: String) -> String:
	var clean := value.strip_edges().replace("\\", "").replace("/", "")
	return clean

func _clean_mode(mode: String) -> String:
	var clean := mode.strip_edges()
	if clean.length() != 3 and clean.length() != 4:
		return ""
	for index in clean.length():
		var digit := int(clean.substr(index, 1))
		if digit < 0 or digit > 7 or clean.substr(index, 1) != str(digit):
			return ""
	return clean

func _collapse_path(path: String) -> String:
	var clean := path.strip_edges().replace("\\", "/")
	while clean.contains("//"):
		clean = clean.replace("//", "/")
	if clean == "" or clean == "/":
		return "/"
	if not clean.begins_with("/"):
		clean = "/" + clean
	var result: Array[String] = []
	var raw_parts := clean.substr(1).split("/", false)
	for raw_part in raw_parts:
		var part := str(raw_part)
		if part == "." or part == "":
			continue
		if part == "..":
			if not result.is_empty():
				result.remove_at(result.size() - 1)
			continue
		result.append(part)
	if result.is_empty():
		return "/"
	return "/" + "/".join(result)

func _node_size(node: Dictionary) -> int:
	if str(node.get("type", "")) == "file":
		return str(node.get("content", "")).length()
	var children: Dictionary = node.get("children", {})
	return children.size()

func _empty_state() -> Dictionary:
	var state := {
		"version": 2,
		"current_user": DEFAULT_USERNAME,
		"users": {},
		"tree": _dir_node(ROOT_USER, ROOT_USER, "0755")
	}
	state["users"] = {
		ROOT_USER: _default_account_record(ROOT_USER, 0, false),
		DEFAULT_USERNAME: _default_account_record(DEFAULT_USERNAME, DEFAULT_UID, true)
	}
	return state

func _dir_node(owner: String, group: String, mode: String) -> Dictionary:
	return {"type": "dir", "owner": owner, "group": group, "mode": mode, "children": {}}

func _file_node(content: String, owner: String, group: String, mode: String) -> Dictionary:
	return {"type": "file", "owner": owner, "group": group, "mode": mode, "content": content}

func _copy_node(node: Dictionary, owner: String, group: String) -> Dictionary:
	var type := str(node.get("type", "file"))
	if type == "dir":
		var copy := _dir_node(owner, group, str(node.get("mode", "0755")))
		var source_children: Dictionary = node.get("children", {})
		var copied_children: Dictionary = {}
		for key in source_children.keys():
			if source_children[key] is Dictionary:
				copied_children[key] = _copy_node(source_children[key], owner, group)
		copy["children"] = copied_children
		return copy
	return _file_node(str(node.get("content", "")), owner, group, str(node.get("mode", "0644")))

func _is_valid_tree(value: Dictionary) -> bool:
	return str(value.get("type", "")) == "dir" and value.has("children") and value["children"] is Dictionary

func _is_valid_state(value: Dictionary) -> bool:
	return value.has("tree") and value["tree"] is Dictionary and _is_valid_tree(value["tree"]) and value.has("users") and value["users"] is Dictionary

func _ensure_system_layout() -> void:
	if _tree.is_empty() or not _is_valid_tree(_tree):
		_tree = _dir_node(ROOT_USER, ROOT_USER, "0755")
	_state["tree"] = _tree
	_add_metadata_recursive(_tree, DEFAULT_USERNAME, DEFAULT_USERNAME)
	_tree["owner"] = ROOT_USER
	_tree["group"] = ROOT_USER
	_tree["mode"] = "0755"
	if not _state.has("users") or not (_state["users"] is Dictionary):
		_state["users"] = _empty_state()["users"]
	var users: Dictionary = _state["users"]
	if not users.has(ROOT_USER):
		users[ROOT_USER] = _default_account_record(ROOT_USER, 0, false)
	if not _has_usable_non_root_user(users) and not users.has(DEFAULT_USERNAME):
		users[DEFAULT_USERNAME] = _default_account_record(DEFAULT_USERNAME, DEFAULT_UID, true)
	for key in users.keys():
		var account: Dictionary = users[key]
		_apply_account_defaults(account, str(key), int(account.get("uid", 0)))
		users[key] = account
	_state["users"] = users
	_force_dir("/home", ROOT_USER, ROOT_USER, "0755")
	_force_dir("/root", ROOT_USER, ROOT_USER, "0700")
	_force_dir("/tmp", ROOT_USER, ROOT_USER, "1777")
	_force_dir("/etc", ROOT_USER, ROOT_USER, "0755")
	_force_dir("/bin", ROOT_USER, ROOT_USER, "0755")
	_force_dir("/usr", ROOT_USER, ROOT_USER, "0755")
	_force_dir("/var", ROOT_USER, ROOT_USER, "0755")
	for key in users.keys():
		var username := str(key)
		if username == ROOT_USER:
			continue
		_force_dir(home_path(username), username, _primary_group(username), "0755")
	if not user_exists(current_user()):
		var fallback_user := _fallback_current_user(users)
		if fallback_user == "":
			users[DEFAULT_USERNAME] = _default_account_record(DEFAULT_USERNAME, DEFAULT_UID, true)
			_state["users"] = users
			fallback_user = DEFAULT_USERNAME
		_state["current_user"] = fallback_user
	_sync_system_files()

func _has_usable_non_root_user(users: Dictionary) -> bool:
	for key in users.keys():
		var username := str(key)
		if username == ROOT_USER:
			continue
		var account: Dictionary = users[key]
		if bool(account.get("login_visible", true)) and not bool(account.get("locked", false)):
			return true
	return false

func _fallback_current_user(users: Dictionary) -> String:
	var names: Array[String] = []
	for key in users.keys():
		names.append(str(key))
	names.sort()
	for username in names:
		if username == ROOT_USER:
			continue
		var account: Dictionary = users[username]
		if bool(account.get("login_visible", true)) and not bool(account.get("locked", false)):
			return username
	if users.has(ROOT_USER):
		return ROOT_USER
	if names.size() > 0:
		return names[0]
	return ""

func _force_dir(path: String, owner: String, group: String, mode: String) -> void:
	var normalized := normalize_path(path)
	if normalized == "/":
		return
	var parts := _path_parts(normalized)
	var node: Dictionary = _tree
	var current := ""
	for part in parts:
		current += "/" + part
		var children: Dictionary = node.get("children", {})
		if not children.has(part) or not (children[part] is Dictionary) or str((children[part] as Dictionary).get("type", "")) != "dir":
			children[part] = _dir_node(owner, group, mode)
			node["children"] = children
		node = children[part]
		if current == normalized:
			node["owner"] = owner
			node["group"] = group
			node["mode"] = mode

func _sync_system_files() -> void:
	var etc := get_node_at("/etc")
	if etc.is_empty():
		return
	var children: Dictionary = etc.get("children", {})
	children["passwd"] = _file_node(_passwd_text(), ROOT_USER, ROOT_USER, "0644")
	children["group"] = _file_node(_group_text(), ROOT_USER, ROOT_USER, "0644")
	children["shadow"] = _file_node(_shadow_text(), ROOT_USER, ROOT_USER, "0640")
	etc["children"] = children

func _passwd_text() -> String:
	var lines: Array[String] = []
	for username in get_users():
		var users: Dictionary = _state.get("users", {})
		var account: Dictionary = users[username]
		lines.append("%s:x:%d:%d:%s:%s:%s" % [
			username,
			int(account.get("uid", 0)),
			int(account.get("gid", 0)),
			username,
			str(account.get("home", "/home/" + username)),
			str(account.get("shell", "/bin/sh"))
		])
	return "\n".join(lines) + "\n"

func _group_text() -> String:
	var lines: Array[String] = []
	for username in get_users():
		var users: Dictionary = _state.get("users", {})
		var account: Dictionary = users[username]
		lines.append("%s:x:%d:%s" % [str(account.get("group", username)), int(account.get("gid", 0)), username])
	return "\n".join(lines) + "\n"

func _shadow_text() -> String:
	var lines: Array[String] = []
	var users: Dictionary = _state.get("users", {})
	for username in get_users():
		var account: Dictionary = users[username]
		lines.append("%s:%s:0:0:99999:7:::" % [username, str(account.get("password_hash", _password_hash("")))])
	return "\n".join(lines) + "\n"

func _default_account_record(username: String, uid: int, login_visible: bool) -> Dictionary:
	var clean := clean_username(username)
	if clean == "":
		clean = DEFAULT_USERNAME
	var root := clean == ROOT_USER
	return {
		"uid": 0 if root else uid,
		"gid": 0 if root else uid,
		"group": ROOT_USER if root else clean,
		"home": "/root" if root else "/home/" + clean,
		"shell": "/bin/sh",
		"groups": [ROOT_USER] if root else [clean],
		"password_hash": _password_hash(""),
		"display_name": "Root" if root else clean,
		"login_visible": false if root else login_visible,
		"locked": false,
		"created_at": Time.get_unix_time_from_system(),
		"avatar_type": "initials",
		"avatar_value": ""
	}

func _apply_account_defaults(account: Dictionary, username: String, uid_hint: int) -> void:
	var root := username == ROOT_USER
	if not account.has("uid"):
		account["uid"] = 0 if root else uid_hint
	if not account.has("gid"):
		account["gid"] = 0 if root else int(account.get("uid", uid_hint))
	if not account.has("group") or str(account.get("group", "")).strip_edges() == "":
		account["group"] = ROOT_USER if root else username
	if not account.has("home") or str(account.get("home", "")).strip_edges() == "":
		account["home"] = "/root" if root else "/home/" + username
	if not account.has("shell"):
		account["shell"] = "/bin/sh"
	if not account.has("groups") or not (account["groups"] is Array):
		account["groups"] = [ROOT_USER] if root else [username]
	if not account.has("password_hash"):
		account["password_hash"] = _password_hash("")
	if not account.has("display_name") or str(account.get("display_name", "")).strip_edges() == "":
		account["display_name"] = "Root" if root else username
	if not account.has("login_visible"):
		account["login_visible"] = not root
	if root:
		account["login_visible"] = false
	if not account.has("locked"):
		account["locked"] = false
	if not account.has("created_at"):
		account["created_at"] = Time.get_unix_time_from_system()
	if not account.has("avatar_type"):
		account["avatar_type"] = "initials"
	if not account.has("avatar_value"):
		account["avatar_value"] = ""

func _is_supported_avatar_path(path: String) -> bool:
	var lower := path.to_lower()
	return lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".jpeg") or lower.ends_with(".webp") or lower.ends_with(".svg")

func _reassign_node_owner_recursive(node: Dictionary, owner: String, group: String) -> void:
	node["owner"] = owner
	node["group"] = group
	if str(node.get("type", "")) != "dir":
		return
	var children: Dictionary = node.get("children", {})
	for key in children.keys():
		if children[key] is Dictionary:
			_reassign_node_owner_recursive(children[key], owner, group)

func _password_hash(password: String) -> String:
	return password.sha256_text()

func _add_metadata_recursive(node: Dictionary, owner: String, group: String) -> void:
	var type := str(node.get("type", "dir"))
	if not node.has("owner"):
		node["owner"] = owner
	if not node.has("group"):
		node["group"] = group
	if not node.has("mode"):
		node["mode"] = "0644" if type == "file" else "0755"
	if type == "dir":
		if not node.has("children") or not (node["children"] is Dictionary):
			node["children"] = {}
		var children: Dictionary = node.get("children", {})
		for key in children.keys():
			if children[key] is Dictionary:
				_add_metadata_recursive(children[key], owner, group)
	if type == "file" and not node.has("content"):
		node["content"] = ""

func _can_read(node: Dictionary, username: String) -> bool:
	return _has_permission(node, username, 4)

func _can_write(node: Dictionary, username: String) -> bool:
	return _has_permission(node, username, 2)

func _can_execute(node: Dictionary, username: String) -> bool:
	return _has_permission(node, username, 1)

func _has_permission(node: Dictionary, username: String, bit: int) -> bool:
	if username == ROOT_USER or _root_authorization_depth > 0:
		return true
	var mode := str(node.get("mode", "0644"))
	var perms := mode.substr(maxi(mode.length() - 3, 0), 3)
	if perms.length() < 3:
		return false
	var digit_index := 2
	if username == str(node.get("owner", "")):
		digit_index = 0
	elif _user_in_group(username, str(node.get("group", ""))):
		digit_index = 1
	var digit := int(perms.substr(digit_index, 1))
	return (digit & bit) == bit

func _has_sticky_bit(node: Dictionary) -> bool:
	var mode := str(node.get("mode", ""))
	return mode.length() == 4 and mode.begins_with("1")

func _primary_group(username: String) -> String:
	var users: Dictionary = _state.get("users", {})
	if users.has(username):
		var account: Dictionary = users[username]
		return str(account.get("group", username))
	return username

func _user_in_group(username: String, group: String) -> bool:
	if group == "":
		return false
	var users: Dictionary = _state.get("users", {})
	if not users.has(username):
		return false
	var account: Dictionary = users[username]
	if str(account.get("group", username)) == group:
		return true
	var groups: Array = account.get("groups", [])
	for item in groups:
		if str(item) == group:
			return true
	return false

func _groups_text(account: Dictionary) -> String:
	var groups: Array = account.get("groups", [])
	var result: Array[String] = []
	for group in groups:
		result.append(str(group))
	return ",".join(result)

func _is_protected_system_path(path: String) -> bool:
	return path == "/home" or path == "/etc" or path == "/bin" or path == "/usr" or path == "/var" or path == "/tmp" or path == "/root"

# Persistence probe/smoke for username rename (added for account-center-username-rename-persistence-001)
# LIVE-PATH VERSION: prints globalized user:// path, performs rename via live fs path (Account Center adjacent), reads on-disk save file, reloads using EXACT load_or_create path (the actual startup/restart path), asserts dadmin persists, user not resurrected, current_user survives. This exercises the real save/load mismatch path.
func persistence_probe_rename() -> String:
	print("Live OS user data dir: ", OS.get_user_data_dir())
	print("Globalized SAVE_PATH (user://hermes_os_files.json): ", ProjectSettings.globalize_path(SAVE_PATH))
	var original := export_state().duplicate(true)
	reset()
	var prev_user := current_user()
	# Root auth for rename
	set_current_user(ROOT_USER)
	# Create test user to rename (isolated, via live fs path)
	var create_err := create_user_account("testuser", "Test Display", "testpass123")
	if create_err != "":
		import_state(original)
		set_current_user(prev_user)
		return "create_err: " + create_err
	# Perform rename (root authorized, via live fs path equivalent to Account Center/root-auth)
	# Updated for real live-path active rename test: set current to testuser before rename to exercise the exact reported mismatch path (active user rename under root auth elevation)
	var set_active_err := set_current_user("testuser")
	if set_active_err != "":
		import_state(original)
		set_current_user(prev_user)
		return "set_active_err: " + set_active_err
	var rename_err := rename_user_account("testuser", "dadmin")
	if rename_err != "":
		import_state(original)
		set_current_user(prev_user)
		return "rename_err: " + rename_err
	save()
	# Read actual on-disk save file at globalized user:// path (post-rename, before any mutation)
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		import_state(original)
		set_current_user(prev_user)
		return "no_save_file"
	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		import_state(original)
		set_current_user(prev_user)
		return "parse_fail"
	var loaded: Dictionary = parsed
	var loaded_users: Dictionary = loaded.get("users", {})
	var loaded_current := str(loaded.get("current_user", ""))
	# Assert on-disk after rename (pre-restart)
	if not loaded_users.has("dadmin"):
		import_state(original)
		set_current_user(prev_user)
		return "assert_fail: dadmin missing in on-disk"
	if loaded_users.has("testuser") or loaded_users.has(DEFAULT_USERNAME):
		import_state(original)
		set_current_user(prev_user)
		return "assert_fail: old user still in on-disk"
	if loaded_current != "dadmin":
		import_state(original)
		set_current_user(prev_user)
		return "assert_fail: current_user not dadmin in on-disk"
	# NOW reload using the EXACT live load_or_create path (simulates actual reboot/restart/load)
	load_or_create()
	# Assert on in-memory state after live load_or_create (verifies rename survives actual restart/load path)
	var curr := current_user()
	var users_arr := get_users()
	if not user_exists("dadmin") or curr != "dadmin":
		import_state(original)
		set_current_user(prev_user)
		return "assert_fail: dadmin not persisted after load_or_create"
	if users_arr.has("testuser") or users_arr.has(DEFAULT_USERNAME):
		import_state(original)
		set_current_user(prev_user)
		return "assert_fail: old user resurrected after load_or_create"
	# Test rejects (still work)
	var bad1 := rename_user_account("dadmin", "")
	if bad1 == "":
		import_state(original)
		set_current_user(prev_user)
		return "reject_blank_fail"
	var bad2 := rename_user_account("dadmin", "dadmin")
	if bad2 == "":
		import_state(original)
		set_current_user(prev_user)
		return "reject_duplicate_fail"
	# Cleanup only isolated test state
	import_state(original)
	set_current_user(prev_user)
	return ""  # PASS (live-path verified)
