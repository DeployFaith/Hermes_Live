class_name HermesInternetDocumentLoader
extends RefCounted

const HermesInternetRegistry = preload("res://addons/hermes_os/scripts/os/hermes_internet/hermes_internet_registry.gd")
const HermesInternetResolver = preload("res://addons/hermes_os/scripts/os/hermes_internet/hermes_internet_resolver.gd")

const NOT_FOUND_TEMPLATE := "res://addons/hermes_os/content/hermes_internet/system/not_found.html"
const SCRIPT_SRC_PATTERN := "(?is)<script\\b([^>]*)\\bsrc\\s*=\\s*([\"'])([^\"']+)\\2([^>]*)></script>"
const BLOCKED_SCRIPT_TOKENS := ["http://", "https://", "localhost", "127.0.0.1"]

var registry: HermesInternetRegistry
var resolver: HermesInternetResolver

func _init(site_registry: HermesInternetRegistry = null, site_resolver: HermesInternetResolver = null) -> void:
	registry = site_registry if site_registry != null else HermesInternetRegistry.new()
	registry.load_registry()
	resolver = site_resolver if site_resolver != null else HermesInternetResolver.new(registry)

func load(input_url: String) -> Dictionary:
	var resolved: Dictionary = resolver.resolve(input_url)
	var mode: String = str(resolved.get("mode", ""))
	match mode:
		"hermes_internet":
			return _load_site_document(resolved)
		"hermes_internet_site_not_found":
			return _load_site_not_found(resolved)
		"real_internet_unavailable":
			return _load_real_internet_unavailable(resolved)
		_:
			return _document_error(resolved, "Hermes Internet resolver returned an unknown mode: %s" % mode)

func _load_site_document(resolved: Dictionary) -> Dictionary:
	var domain: String = str(resolved.get("domain", ""))
	var display_url: String = str(resolved.get("display_url", resolver.DEFAULT_URL))
	var path: String = _path_without_query(str(resolved.get("path", "/")))
	var site: Dictionary = registry.get_site(domain)
	if site.is_empty():
		return _load_site_not_found(resolved)
	var routes: Dictionary = site.get("routes", {}) if site.get("routes", {}) is Dictionary else {}
	var route_path: String = path if path != "" else "/"
	if not routes.has(route_path):
		return _load_page_not_found(resolved, site)
	var root_path: String = str(site.get("root", ""))
	var document_path: String = _join_path(root_path, str(routes.get(route_path, "")))
	if not FileAccess.file_exists(document_path):
		return _document_error(resolved, "Hermes Internet document missing: %s" % document_path, site)
	var html: String = FileAccess.get_file_as_string(document_path)
	var injected: Dictionary = _inject_site_assets(html, site, document_path)
	return {
		"ok": true,
		"status_code": 200,
		"mode": "hermes_internet",
		"domain": domain,
		"path": route_path,
		"display_url": display_url,
		"local_url": str(resolved.get("local_url", "")),
		"title": str(site.get("title", domain)),
		"description": str(site.get("description", "")),
		"html": str(injected.get("html", html)),
		"inline_script_count": int(injected.get("inline_script_count", 0)),
		"blocked_script_count": int(injected.get("blocked_script_count", 0)),
		"content_type": "text/html; charset=utf-8",
		"source_path": document_path
	}

func _load_page_not_found(resolved: Dictionary, site: Dictionary) -> Dictionary:
	return _load_not_found_template(resolved, {
		"status_code": 404,
		"mode": "hermes_internet_page_not_found",
		"title": "Page not found — %s" % str(site.get("title", str(resolved.get("domain", "home.hermes")))),
		"heading": "Page not found",
		"message": "The Hermes Internet site exists, but this bundled page route is not available.",
		"action_url": "http://%s/" % str(resolved.get("domain", "home.hermes")),
		"action_label": "Open site home"
	})

func _load_site_not_found(resolved: Dictionary) -> Dictionary:
	return _load_not_found_template(resolved, {
		"status_code": 404,
		"mode": "hermes_internet_site_not_found",
		"title": "Hermes Internet site not found",
		"heading": "Hermes Internet site not found",
		"message": "No bundled Hermes Internet site is registered for this .hermes domain.",
		"action_url": resolver.DEFAULT_URL,
		"action_label": "Open home.hermes"
	})

func _load_real_internet_unavailable(resolved: Dictionary) -> Dictionary:
	return _load_not_found_template(resolved, {
		"status_code": 501,
		"mode": "real_internet_unavailable",
		"title": "Real Internet mode is not enabled",
		"heading": "Real Internet mode is not enabled yet",
		"message": "This Browser sprint only supports bundled Hermes Internet sites. External websites are intentionally disabled for now.",
		"action_url": resolver.DEFAULT_URL,
		"action_label": "Open Hermes Internet home"
	})

func _load_not_found_template(resolved: Dictionary, values: Dictionary) -> Dictionary:
	var html: String = FileAccess.get_file_as_string(NOT_FOUND_TEMPLATE) if FileAccess.file_exists(NOT_FOUND_TEMPLATE) else _fallback_not_found_template()
	html = html.replace("{{title}}", _html_escape(str(values.get("title", "Hermes Internet"))))
	html = html.replace("{{heading}}", _html_escape(str(values.get("heading", "Hermes Internet"))))
	html = html.replace("{{message}}", _html_escape(str(values.get("message", "The requested bundled page is not available."))))
	html = html.replace("{{requested_url}}", _html_escape(str(resolved.get("display_url", ""))))
	html = html.replace("{{action_url}}", _html_escape(str(values.get("action_url", resolver.DEFAULT_URL))))
	html = html.replace("{{action_label}}", _html_escape(str(values.get("action_label", "Open home.hermes"))))
	return {
		"ok": true,
		"status_code": int(values.get("status_code", 404)),
		"mode": str(values.get("mode", "hermes_internet_not_found")),
		"domain": str(resolved.get("domain", "")),
		"path": str(resolved.get("path", "/")),
		"display_url": str(resolved.get("display_url", resolver.DEFAULT_URL)),
		"local_url": str(resolved.get("local_url", "")),
		"title": str(values.get("title", "Hermes Internet")),
		"description": str(values.get("message", "")),
		"html": html,
		"content_type": "text/html; charset=utf-8",
		"source_path": NOT_FOUND_TEMPLATE
	}

func _document_error(resolved: Dictionary, message: String, site: Dictionary = {}) -> Dictionary:
	var html: String = "<!doctype html><html><head><meta charset=\"utf-8\"><title>Hermes Internet error</title></head><body><h1>Hermes Internet error</h1><p>%s</p></body></html>" % _html_escape(message)
	return {
		"ok": false,
		"status_code": 500,
		"mode": "hermes_internet_error",
		"domain": str(resolved.get("domain", site.get("domain", ""))),
		"path": str(resolved.get("path", "/")),
		"display_url": str(resolved.get("display_url", resolver.DEFAULT_URL)),
		"local_url": str(resolved.get("local_url", "")),
		"title": "Hermes Internet error",
		"description": message,
		"html": html,
		"content_type": "text/html; charset=utf-8"
	}

func _inject_site_assets(html: String, site: Dictionary, document_path: String) -> Dictionary:
	var root_path: String = str(site.get("root", ""))
	var css_path: String = _join_path(root_path, "styles/site.css")
	var css: String = FileAccess.get_file_as_string(css_path) if FileAccess.file_exists(css_path) else ""
	var with_css: String = html.replace("{{site_css}}", css)
	return _inline_local_scripts(with_css, root_path, document_path)

func _inline_local_scripts(html: String, site_root: String, document_path: String) -> Dictionary:
	var regex := RegEx.new()
	if regex.compile(SCRIPT_SRC_PATTERN) != OK:
		return {"html": html, "inline_script_count": 0, "blocked_script_count": 0}

	var matches: Array[RegExMatch] = regex.search_all(html)
	if matches.is_empty():
		return {"html": html, "inline_script_count": 0, "blocked_script_count": 0}

	var out := ""
	var cursor := 0
	var inline_count := 0
	var blocked_count := 0
	for match in matches:
		var start: int = match.get_start()
		var end: int = match.get_end()
		out += html.substr(cursor, start - cursor)
		cursor = end

		var script_src: String = str(match.get_string(3)).strip_edges()
		var script_path: String = _resolve_local_script_path(script_src, site_root, document_path)
		if script_path == "":
			blocked_count += 1
			out += "<script>console.warn('Hermes Internet blocked non-local script source.');</script>"
			continue

		var script_body: String = FileAccess.get_file_as_string(script_path)
		inline_count += 1
		out += "<script data-hermes-inline-src=\"%s\">\n%s\n</script>" % [_html_escape(script_src), script_body]

	out += html.substr(cursor)
	return {"html": out, "inline_script_count": inline_count, "blocked_script_count": blocked_count}

func _resolve_local_script_path(script_src: String, site_root: String, document_path: String) -> String:
	if script_src == "":
		return ""
	var src_lower: String = script_src.to_lower()
	for token in BLOCKED_SCRIPT_TOKENS:
		if src_lower.find(token) >= 0:
			return ""
	if src_lower.begins_with("//"):
		return ""
	if _has_uri_scheme(src_lower):
		return ""

	var path_only: String = script_src
	var query_index := path_only.find("?")
	if query_index >= 0:
		path_only = path_only.substr(0, query_index)
	var hash_index := path_only.find("#")
	if hash_index >= 0:
		path_only = path_only.substr(0, hash_index)
	if path_only == "":
		return ""

	var candidate: String = ""
	if path_only.begins_with("/"):
		candidate = _join_path(site_root, path_only)
	else:
		candidate = _join_path(document_path.get_base_dir(), path_only)

	if not _is_path_within(site_root, candidate):
		return ""
	if not FileAccess.file_exists(candidate):
		return ""
	return candidate

func _has_uri_scheme(value: String) -> bool:
	var colon_index := value.find(":")
	if colon_index <= 0:
		return false
	var slash_index := value.find("/")
	return slash_index < 0 or colon_index < slash_index

func _is_path_within(base_path: String, candidate_path: String) -> bool:
	var base_global := ProjectSettings.globalize_path(base_path).rstrip("/")
	var candidate_global := ProjectSettings.globalize_path(candidate_path)
	return candidate_global == base_global or candidate_global.begins_with(base_global + "/")

func _path_without_query(path: String) -> String:
	var q: int = path.find("?")
	return path.substr(0, q) if q >= 0 else path

func _join_path(base: String, child: String) -> String:
	return base.rstrip("/") + "/" + child.trim_prefix("/")

func _fallback_not_found_template() -> String:
	return "<!doctype html><html><head><meta charset=\"utf-8\"><title>{{title}}</title></head><body><h1>{{heading}}</h1><p>{{message}}</p><p>{{requested_url}}</p><p><a href=\"{{action_url}}\">{{action_label}}</a></p></body></html>"

func _html_escape(value: String) -> String:
	return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;")
