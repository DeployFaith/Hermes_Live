extends RefCounted

static func manifest(builder: Callable) -> Dictionary:
	return {
		"id": &"files",
		"title": "Files",
		"name": "Files",
		"description": "Browse the virtual filesystem.",
		"subtitle": "Browse and manage files",
		"keywords": "folders storage manager",
		"category": "System",
		"pinned": true,
		"single_instance": true,
		"agent_visible": true,
		"agent_actions": ["files.browse", "files.open"],
		"builder": builder
	}
