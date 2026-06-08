class_name HermesInternetRegistry
extends RefCounted

const REGISTRY_PATH := "res://addons/hermes_os/content/hermes_internet/registry.json"

var _registry_path: String = REGISTRY_PATH
var _loaded: bool = false
var _sites: Dictionary = {}
var _site_order: Array[String] = []
var _last_error: String = ""

func _init(registry_path: String = REGISTRY_PATH) -> void:
	_registry_path = registry_path

func load_registry(force: bool = false) -> bool:
	if _loaded and not force:
		return true
	_loaded = false
	_sites.clear()
	_site_order.clear()
	_last_error = ""
	if not FileAccess.file_exists(_registry_path):
		_last_error = "Hermes Internet registry not found: %s" % _registry_path
		return false
	var text: String = FileAccess.get_file_as_string(_registry_path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		_last_error = "Hermes Internet registry is not valid JSON object: %s" % _registry_path
		return false
	var root: Dictionary = parsed as Dictionary
	var entries: Array = root.get("sites", []) if root.get("sites", []) is Array else []
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var site: Dictionary = (entry as Dictionary).duplicate(true)
		var domain: String = str(site.get("domain", "")).strip_edges().to_lower()
		if domain == "":
			continue
		site["domain"] = domain
		if not site.has("root"):
			site["root"] = "res://addons/hermes_os/content/hermes_internet/sites/%s" % domain
		if not site.has("entry"):
			site["entry"] = "/"
		if not site.has("routes") or not (site.get("routes") is Dictionary):
			site["routes"] = {"/": "pages/index.html"}
		_sites[domain] = site
		_site_order.append(domain)
	_loaded = true
	return true

func has_site(domain: String) -> bool:
	_ensure_loaded()
	return _sites.has(_normalize_domain(domain))

func get_site(domain: String) -> Dictionary:
	_ensure_loaded()
	var key: String = _normalize_domain(domain)
	if _sites.has(key):
		return (_sites[key] as Dictionary).duplicate(true)
	return {}

func list_sites() -> Array[Dictionary]:
	_ensure_loaded()
	var out: Array[Dictionary] = []
	for domain in _site_order:
		if _sites.has(domain):
			out.append((_sites[domain] as Dictionary).duplicate(true))
	return out

func get_last_error() -> String:
	return _last_error

func _ensure_loaded() -> void:
	if not _loaded:
		load_registry()

func _normalize_domain(domain: String) -> String:
	return domain.strip_edges().to_lower()
