class_name HermesAppLoader
extends RefCounted

const HermesAppManifest = preload("res://addons/hermes_os/scripts/ui/hermes_ui/runtime/hermes_app_manifest.gd")

func load_manifest(manifest_path: String):
	if manifest_path.strip_edges() == "":
		push_warning("HermesAppLoader.load_manifest called with empty path")
		return null
	if not FileAccess.file_exists(manifest_path):
		push_warning("Hermes app manifest not found: %s" % manifest_path)
		return null
	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		push_warning("Hermes app manifest could not be opened: %s" % manifest_path)
		return null
	var text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("Hermes app manifest is not a JSON object: %s" % manifest_path)
		return null
	var manifest = HermesAppManifest.new()
	manifest.load_from_dictionary(parsed as Dictionary, manifest_path)
	return manifest
