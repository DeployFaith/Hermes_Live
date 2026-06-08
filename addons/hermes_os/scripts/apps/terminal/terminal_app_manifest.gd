extends RefCounted

static func manifest(builder: Callable) -> Dictionary:
	return {
		"id": &"console",
		"title": "Terminal",
		"name": "Terminal",
		"description": "Command line shell.",
		"subtitle": "Command line shell",
		"keywords": "console terminal shell",
		"category": "Programming",
		"pinned": true,
		"single_instance": false,
		"agent_visible": true,
		"agent_actions": ["terminal.run_simulated"],
		"builder": builder
	}
