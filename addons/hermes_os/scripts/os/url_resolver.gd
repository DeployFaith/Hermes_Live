class_name URLResolver
extends RefCounted

const HermesInternetResolver = preload("res://addons/hermes_os/scripts/os/hermes_internet/hermes_internet_resolver.gd")

var _resolver: HermesInternetResolver

func _init() -> void:
	_resolver = HermesInternetResolver.new()

func normalize_user_url(input_url: String) -> String:
	return _resolver.normalize_user_url(input_url)

func resolve_to_backend(input_url: String) -> String:
	return _resolver.resolve_to_backend_url(input_url)

func display_url_from_backend(resolved_url: String) -> String:
	return _resolver.display_url_from_local(resolved_url)

func is_hermes_internet_route(input_url: String) -> bool:
	return _resolver.is_hermes_internet_route(input_url)

func is_known_hermes_site(input_url: String) -> bool:
	return _resolver.is_known_hermes_site(input_url)

func is_real_internet_unavailable(input_url: String) -> bool:
	return _resolver.is_real_internet_unavailable(input_url)

func is_internal_route(input_url: String) -> bool:
	return _resolver.normalize_user_url(input_url) == HermesInternetResolver.DEFAULT_URL

func requires_local_backend(_input_url: String) -> bool:
	return false

func local_route_hint(input_url: String) -> Dictionary:
	var display_url: String = normalize_user_url(input_url)
	return {
		"display_url": display_url,
		"local_url": resolve_to_backend(display_url),
		"service": "Hermes Internet in-process document loader"
	}

func extract_host(input_url: String) -> String:
	return _resolver.extract_host(input_url)

func extract_path_and_query(input_url: String) -> String:
	return _resolver.extract_path_and_query(input_url)
