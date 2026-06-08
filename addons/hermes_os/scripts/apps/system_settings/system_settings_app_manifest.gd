extends RefCounted

static func manifest(builder: Callable) -> Dictionary:
	return {
		"id": &"system",
		"title": "System",
		"name": "System",
		"description": "System status and settings.",
		"subtitle": "System status and settings",
		"keywords": "settings diagnostics",
		"category": "Administration",
		"pinned": true,
		"single_instance": true,
		"agent_visible": true,
		"agent_actions": ["system.get_state"],
		"builder": builder
	}
