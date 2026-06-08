extends RefCounted

static func manifest(builder: Callable) -> Dictionary:
	return {
		"id": &"text",
		"title": "Text",
		"name": "Text",
		"description": "Edit plain text files.",
		"subtitle": "Edit plain text files",
		"keywords": "editor code",
		"category": "Programming",
		"pinned": false,
		"single_instance": true,
		"agent_visible": true,
		"agent_actions": ["files.open", "files.write"],
		"builder": builder
	}
