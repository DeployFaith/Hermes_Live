class_name HermesLauncherViewModel
extends RefCounted

var _app_registry: RefCounted = null

func setup(app_registry: RefCounted) -> HermesLauncherViewModel:
	_app_registry = app_registry
	return self

func set_app_registry(app_registry: RefCounted) -> void:
	_app_registry = app_registry

func app_registry() -> RefCounted:
	return _app_registry

func project_apps(search: String = "", category_filter: String = "all", selected_app_id: String = "") -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for app in _source_apps():
		if not (app is Dictionary):
			continue
		var projected: Dictionary = _project_app(app as Dictionary)
		if not _matches_category(projected, category_filter):
			continue
		if not _matches_search(projected, search):
			continue
		projected["selected"] = str(projected.get("app_id", "")) == selected_app_id
		output.append(projected)
	return output

func project_categories(selected_category: String = "all") -> Array[Dictionary]:
	var selected: String = _normalize_category_id(selected_category)
	var ordered: Array[String] = ["all", "favorites"]
	var seen: Dictionary = {"all": true, "favorites": true}
	for app in _source_apps():
		if not (app is Dictionary):
			continue
		var category: String = str((app as Dictionary).get("category", "Other")).strip_edges()
		if category == "":
			category = "Other"
		var category_key: String = _normalize_category_id(category)
		if not seen.has(category_key):
			seen[category_key] = true
			ordered.append(category)
	var output: Array[Dictionary] = []
	for category in ordered:
		var category_id: String = _normalize_category_id(category)
		var public_id: String = category_id if category_id in ["all", "favorites"] else category
		output.append({
			"id": public_id,
			"category_id": category_id,
			"label": _category_label(category),
			"selected": category_id == selected
		})
	return output

func first_app_id(search: String = "", category_filter: String = "all") -> String:
	var apps: Array[Dictionary] = project_apps(search, category_filter, "")
	if apps.is_empty():
		return ""
	return str(apps[0].get("app_id", ""))

func has_app(app_id: String, search: String = "", category_filter: String = "all") -> bool:
	for app in project_apps(search, category_filter, app_id):
		if str(app.get("app_id", "")) == app_id:
			return true
	return false

func _source_apps() -> Array:
	if _app_registry != null and _app_registry.has_method("get_launcher_apps"):
		var value: Variant = _app_registry.call("get_launcher_apps")
		if value is Array:
			return (value as Array).duplicate(true)
	return []

func _project_app(app: Dictionary) -> Dictionary:
	var app_id: String = str(app.get("id", app.get("app_id", ""))).strip_edges()
	var title: String = str(app.get("title", app.get("name", app_id))).strip_edges()
	if title == "":
		title = app_id
	var name: String = str(app.get("name", title)).strip_edges()
	if name == "":
		name = title
	var description: String = str(app.get("description", app.get("subtitle", ""))).strip_edges()
	var subtitle: String = str(app.get("subtitle", description)).strip_edges()
	var category: String = str(app.get("category", "Other")).strip_edges()
	if category == "":
		category = "Other"
	var keywords: Array[String] = _keywords_array(app.get("keywords", []))
	var label: String = title if subtitle == "" else "%s\n%s" % [title, subtitle]
	return {
		"id": app_id,
		"app_id": app_id,
		"title": title,
		"name": name,
		"description": description,
		"subtitle": subtitle,
		"category": category,
		"category_id": _normalize_category_id(category),
		"icon": str(app.get("icon", "")),
		"pinned": bool(app.get("pinned", false)),
		"keywords": keywords,
		"label": label,
		"selected": false
	}

func _matches_category(app: Dictionary, category_filter: String) -> bool:
	var filter_id: String = _normalize_category_id(category_filter)
	if filter_id == "" or filter_id == "all":
		return true
	if filter_id == "favorites":
		return bool(app.get("pinned", false))
	return str(app.get("category_id", "")) == filter_id

func _matches_search(app: Dictionary, search: String) -> bool:
	var normalized: String = search.strip_edges().to_lower()
	if normalized == "":
		return true
	var parts: Array[String] = [
		str(app.get("app_id", "")),
		str(app.get("id", "")),
		str(app.get("title", "")),
		str(app.get("name", "")),
		str(app.get("description", "")),
		str(app.get("subtitle", "")),
		str(app.get("category", ""))
	]
	for keyword in _keywords_array(app.get("keywords", [])):
		parts.append(keyword)
	return " ".join(parts).to_lower().find(normalized) != -1

func _keywords_array(value: Variant) -> Array[String]:
	var output: Array[String] = []
	if value is Array:
		for item in value:
			var clean: String = str(item).strip_edges()
			if clean != "" and not output.has(clean):
				output.append(clean)
	elif value is PackedStringArray:
		for item in value:
			var clean_psa: String = str(item).strip_edges()
			if clean_psa != "" and not output.has(clean_psa):
				output.append(clean_psa)
	else:
		for token in str(value).split(" ", false):
			var clean_token: String = token.strip_edges()
			if clean_token != "" and not output.has(clean_token):
				output.append(clean_token)
	return output

func _normalize_category_id(category: String) -> String:
	var clean: String = category.strip_edges().to_lower()
	if clean == "":
		return "all"
	return clean.replace(" ", "_")

func _category_label(category: String) -> String:
	var category_id: String = _normalize_category_id(category)
	if category_id == "all":
		return "All"
	if category_id == "favorites":
		return "Favorites"
	return category.strip_edges().capitalize()
