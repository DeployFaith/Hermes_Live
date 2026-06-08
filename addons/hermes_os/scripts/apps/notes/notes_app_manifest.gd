extends RefCounted

static func manifest(builder: Callable) -> Dictionary:
	return {
		"id": &"notes",
		"title": "Notes",
		"name": "Notes",
		"description": "Quick note workspace.",
		"subtitle": "Quick note workspace",
		"keywords": "notes writing markdown",
		"category": "Office",
		"pinned": true,
		"single_instance": true,
		"agent_visible": true,
		"agent_actions": ["notes.create", "notes.open"],
		"builder": builder
	}
