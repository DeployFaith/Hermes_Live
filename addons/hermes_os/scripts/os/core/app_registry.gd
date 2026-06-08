class_name AppRegistry
extends RefCounted

const AppManifest = preload("res://addons/hermes_os/scripts/os/core/app_manifest.gd")

var _apps: Dictionary = {}
var _order: Array[String] = []

func clear() -> void:
	_apps.clear()
	_order.clear()

func register_app(manifest: Dictionary) -> void:
	var normalized := AppManifest.normalize(manifest)
	var app_id := str(normalized.get("id", ""))
	if app_id == "":
		push_warning("Ignoring app manifest without id")
		return
	if not _apps.has(app_id):
		_order.append(app_id)
	_apps[app_id] = normalized

func has_app(app_id: StringName) -> bool:
	return _apps.has(str(app_id))

func get_app(app_id: StringName) -> Dictionary:
	return (_apps.get(str(app_id), {}) as Dictionary).duplicate(true)

func get_app_order() -> Array[String]:
	return _order.duplicate()

func get_launcher_apps() -> Array[Dictionary]:
	var apps: Array[Dictionary] = []
	for app_id in _order:
		apps.append(get_app(StringName(app_id)))
	return apps

func get_pinned_apps() -> Array[Dictionary]:
	var apps: Array[Dictionary] = []
	for app_id in _order:
		var app := get_app(StringName(app_id))
		if bool(app.get("pinned", false)):
			apps.append(app)
	return apps

func get_categories() -> Array[String]:
	var seen: Dictionary = {}
	var categories: Array[String] = []
	for app_id in _order:
		var app := get_app(StringName(app_id))
		var category := str(app.get("category", "Other"))
		if not seen.has(category):
			seen[category] = true
			categories.append(category)
	return categories

func export_legacy_apps() -> Dictionary:
	var result: Dictionary = {}
	for app_id in _order:
		result[app_id] = get_app(StringName(app_id))
	return result
