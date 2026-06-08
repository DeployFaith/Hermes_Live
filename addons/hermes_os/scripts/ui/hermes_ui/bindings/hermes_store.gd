class_name HermesStore
extends RefCounted

signal state_changed(key_path, value)
signal state_batch_changed(keys)

var _state: Dictionary = {}
var _watchers: Dictionary = {}

@warning_ignore("native_method_override")
func set(key_path: StringName, value: Variant) -> void:
	var path_text: String = str(key_path).strip_edges()
	if path_text == "":
		return
	var current = get_value(path_text, null)
	if current == value:
		return
	_set_path_value(path_text, value)
	_notify_watchers(path_text, value)
	emit_signal("state_changed", path_text, value)
	emit_signal("state_batch_changed", PackedStringArray([path_text]))

@warning_ignore("native_method_override")
func get(key_path: StringName) -> Variant:
	return get_value(str(key_path), null)

func get_value(key_path: String, default_value = null):
	if key_path.strip_edges() == "":
		return default_value
	return _get_path_value(key_path, default_value)

func get_string(key_path: String, default_value: String = "") -> String:
	return str(get_value(key_path, default_value))

func get_bool(key_path: String, default_value: bool = false) -> bool:
	var value = get_value(key_path, default_value)
	if value is bool:
		return bool(value)
	var text: String = str(value).strip_edges().to_lower()
	return text == "true" or text == "1" or text == "yes" or text == "on"

func to_dictionary() -> Dictionary:
	return _state.duplicate(true)

func set_many(values: Dictionary) -> void:
	if values.is_empty():
		return
	var changed_keys: Array[String] = []
	for key in values.keys():
		var key_path: String = str(key)
		var new_value = values[key]
		var current = get_value(key_path, null)
		if current == new_value:
			continue
		_set_path_value(key_path, new_value)
		changed_keys.append(key_path)
		_notify_watchers(key_path, new_value)
		emit_signal("state_changed", key_path, new_value)
	if changed_keys.is_empty():
		return
	emit_signal("state_batch_changed", PackedStringArray(changed_keys))

func push(key_path: String, value) -> void:
	var current = get_value(key_path, [])
	var items: Array = []
	if current is Array:
		items = (current as Array).duplicate(true)
	items.append(value)
	set(key_path, items)

func watch(key_path: String, callback: Callable) -> void:
	if key_path.strip_edges() == "" or not callback.is_valid():
		return
	if not _watchers.has(key_path):
		_watchers[key_path] = []
	var callbacks: Array = _watchers[key_path]
	if callbacks.has(callback):
		return
	callbacks.append(callback)
	_watchers[key_path] = callbacks

func _notify_watchers(key_path: String, value) -> void:
	if not _watchers.has(key_path):
		return
	var callbacks: Array = (_watchers[key_path] as Array).duplicate()
	for callback in callbacks:
		if callback is Callable and (callback as Callable).is_valid():
			(callback as Callable).call(value)

func clear_watchers() -> void:
	_watchers.clear()

func _get_path_value(key_path: String, default_value = null):
	var parts: PackedStringArray = key_path.split(".", false)
	var current = _state
	for index in range(parts.size()):
		var key: String = parts[index]
		if current is Dictionary:
			var dictionary: Dictionary = current
			if not dictionary.has(key):
				return default_value
			current = dictionary[key]
		else:
			return default_value
	return current

func _set_path_value(key_path: String, value) -> void:
	var parts: PackedStringArray = key_path.split(".", false)
	if parts.is_empty():
		return
	var current: Dictionary = _state
	for index in range(parts.size() - 1):
		var key: String = parts[index]
		var next_value = current.get(key, {})
		if not (next_value is Dictionary):
			next_value = {}
		current[key] = next_value
		current = current[key]
	current[parts[parts.size() - 1]] = value
