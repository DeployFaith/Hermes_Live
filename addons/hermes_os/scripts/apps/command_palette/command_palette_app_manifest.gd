extends RefCounted

static func manifest(builder: Callable) -> Dictionary:
	return {
		"id": &"command_palette",
		"title": "Command Palette",
		"name": "Command Palette",
		"description": "Search and run HermesOS actions.",
		"subtitle": "Search and run actions",
		"keywords": "command palette actions launcher",
		"category": "System",
		"pinned": false,
		"single_instance": true,
		"agent_visible": true,
		"agent_actions": ["windows.open_app", "system.get_state"],
		"builder": builder
	}
