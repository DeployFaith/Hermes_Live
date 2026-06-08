class_name AppManifest
extends RefCounted

static func normalize(data: Dictionary) -> Dictionary:
	var manifest := data.duplicate(true)
	var id := StringName(str(manifest.get("id", "")).strip_edges())
	manifest["id"] = id
	manifest["name"] = str(manifest.get("name", manifest.get("title", id))).strip_edges()
	manifest["title"] = str(manifest.get("title", manifest.get("name", id))).strip_edges()
	manifest["description"] = str(manifest.get("description", manifest.get("subtitle", ""))).strip_edges()
	manifest["subtitle"] = str(manifest.get("subtitle", manifest.get("description", ""))).strip_edges()
	manifest["icon"] = manifest.get("icon", "")
	manifest["category"] = str(manifest.get("category", "Other")).strip_edges()
	manifest["keywords"] = str(manifest.get("keywords", "")).strip_edges()
	manifest["pinned"] = bool(manifest.get("pinned", false))
	manifest["single_instance"] = bool(manifest.get("single_instance", true))
	manifest["agent_visible"] = bool(manifest.get("agent_visible", true))
	manifest["agent_actions"] = manifest.get("agent_actions", []) if manifest.get("agent_actions", []) is Array else []
	return manifest
