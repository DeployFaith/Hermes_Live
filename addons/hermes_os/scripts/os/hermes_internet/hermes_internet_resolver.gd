class_name HermesInternetResolver
extends RefCounted

const HermesInternetRegistry = preload("res://addons/hermes_os/scripts/os/hermes_internet/hermes_internet_registry.gd")

const DEFAULT_DOMAIN := "home.hermes"
const DEFAULT_URL := "http://home.hermes/"
const LOCAL_SCHEME := "hermes-internet://"
const NEWTAB_SCHEMES: Array[String] = ["browser://newtab", "hermes://newtab"]

var registry: HermesInternetRegistry

func _init(site_registry: HermesInternetRegistry = null) -> void:
	registry = site_registry if site_registry != null else HermesInternetRegistry.new()
	registry.load_registry()

func normalize_user_url(input_url: String) -> String:
	var s: String = input_url.strip_edges()
	if s == "":
		return DEFAULT_URL
	var lower: String = s.to_lower()
	if NEWTAB_SCHEMES.has(lower):
		return DEFAULT_URL
	if not s.contains("://"):
		s = "http://" + s
	if not s.ends_with("/") and s.find("/", s.find("://") + 3) == -1:
		s += "/"
	return s

func resolve(input_url: String) -> Dictionary:
	var display_url: String = normalize_user_url(input_url)
	var host: String = extract_host(display_url)
	var path: String = extract_path_and_query(display_url)
	if registry.has_site(host):
		return {
			"ok": true,
			"mode": "hermes_internet",
			"domain": host,
			"path": path,
			"display_url": display_url,
			"local_url": local_url_for(display_url),
			"site_found": true
		}
	if is_hermes_domain_host(host):
		return {
			"ok": true,
			"mode": "hermes_internet_site_not_found",
			"domain": host,
			"path": path,
			"display_url": display_url,
			"local_url": local_url_for(display_url),
			"site_found": false
		}
	return {
		"ok": true,
		"mode": "real_internet_unavailable",
		"domain": host,
		"path": path,
		"display_url": display_url,
		"local_url": "",
		"site_found": false
	}

func is_hermes_internet_route(input_url: String) -> bool:
	var resolved: Dictionary = resolve(input_url)
	return str(resolved.get("mode", "")).begins_with("hermes_internet")

func is_known_hermes_site(input_url: String) -> bool:
	var resolved: Dictionary = resolve(input_url)
	return bool(resolved.get("site_found", false))

func is_hermes_domain_host(host: String) -> bool:
	var normalized: String = host.strip_edges().to_lower()
	return normalized == DEFAULT_DOMAIN or normalized.ends_with(".hermes")

func is_real_internet_unavailable(input_url: String) -> bool:
	return str(resolve(input_url).get("mode", "")) == "real_internet_unavailable"

func local_url_for(input_url: String) -> String:
	var display_url: String = normalize_user_url(input_url)
	var host: String = extract_host(display_url)
	var path: String = extract_path_and_query(display_url)
	return "%s%s%s" % [LOCAL_SCHEME, host, path]

func resolve_to_backend_url(input_url: String) -> String:
	var resolved: Dictionary = resolve(input_url)
	var local_url: String = str(resolved.get("local_url", ""))
	return local_url if local_url != "" else str(resolved.get("display_url", normalize_user_url(input_url)))

func display_url_from_local(local_url: String) -> String:
	if not local_url.begins_with(LOCAL_SCHEME):
		return local_url
	var rem: String = local_url.substr(LOCAL_SCHEME.length())
	var slash: int = rem.find("/")
	if slash < 0:
		return "http://%s/" % rem
	return "http://%s" % rem

func extract_host(url: String) -> String:
	var normalized: String = normalize_user_url(url)
	var i: int = normalized.find("://")
	if i < 0:
		return ""
	var rest: String = normalized.substr(i + 3)
	var slash: int = rest.find("/")
	if slash >= 0:
		rest = rest.substr(0, slash)
	var colon: int = rest.find(":")
	if colon >= 0:
		rest = rest.substr(0, colon)
	return rest.to_lower()

func extract_path_and_query(url: String) -> String:
	var normalized: String = normalize_user_url(url)
	var i: int = normalized.find("://")
	if i < 0:
		return "/"
	var rest: String = normalized.substr(i + 3)
	var slash: int = rest.find("/")
	if slash < 0:
		return "/"
	return rest.substr(slash)
