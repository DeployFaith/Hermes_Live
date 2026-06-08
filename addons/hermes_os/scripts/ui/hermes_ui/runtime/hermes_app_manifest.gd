class_name HermesAppManifest
extends RefCounted

var manifest_path: String = ""
var app_dir: String = ""
var app_id: String = ""
var name: String = ""
var version: String = ""
var hermes_ui_version: String = ""
var icon_path: String = ""
var entry_path: String = ""
var styles_paths: Array[String] = []
var controller_path: String = ""
var surface: String = "window"
var window_config: Dictionary = {}
var permissions: Array[String] = []
var raw_data: Dictionary = {}

func load_from_dictionary(data: Dictionary, source_path: String) -> void:
	manifest_path = source_path
	app_dir = source_path.get_base_dir()
	raw_data = data.duplicate(true)
	app_id = str(data.get("id", "")).strip_edges()
	name = str(data.get("name", app_id)).strip_edges()
	version = str(data.get("version", "0.1.0")).strip_edges()
	hermes_ui_version = str(data.get("hermes_ui", "0.1")).strip_edges()
	icon_path = _normalize_path(str(data.get("icon", "")).strip_edges())
	entry_path = _normalize_path(str(data.get("entry", "")).strip_edges())
	controller_path = _normalize_path(str(data.get("controller", "")).strip_edges())
	surface = str(data.get("surface", "window")).strip_edges()
	window_config = _normalize_window_config(data.get("window", {}), name)
	styles_paths.clear()
	var styles_value: Variant = data.get("styles", [])
	if styles_value is Array:
		for item in styles_value:
			styles_paths.append(_normalize_path(str(item).strip_edges()))
	permissions.clear()
	var permissions_value: Variant = data.get("permissions", [])
	if permissions_value is Array:
		for item in permissions_value:
			permissions.append(str(item).strip_edges())
	if str(window_config.get("title", "")).strip_edges() == "":
		window_config["title"] = name

func _normalize_path(value: String) -> String:
	if value == "":
		return ""
	if value.begins_with("res://") or value.begins_with("user://"):
		return value
	return app_dir.path_join(value)

func _normalize_window_config(window_value: Variant, fallback_title: String) -> Dictionary:
	var source: Dictionary = {}
	if window_value is Dictionary:
		source = (window_value as Dictionary).duplicate(true)
	var title := str(source.get("title", fallback_title)).strip_edges()
	if title == "":
		title = fallback_title if fallback_title != "" else app_id
	var default_width := _window_dimension(source.get("default_width", 720), 720)
	var default_height := _window_dimension(source.get("default_height", 520), 520)
	var min_width := _window_dimension(source.get("min_width", 520), 520)
	var min_height := _window_dimension(source.get("min_height", 360), 360)
	if default_width < min_width:
		default_width = min_width
	if default_height < min_height:
		default_height = min_height
	return {
		"title": title,
		"default_width": default_width,
		"default_height": default_height,
		"min_width": min_width,
		"min_height": min_height,
		"resizable": bool(source.get("resizable", true)),
		"chromed": bool(source.get("chromed", true))
	}

func _window_dimension(value: Variant, fallback: int) -> int:
	var parsed := int(value)
	if parsed <= 0:
		return fallback
	return parsed
