extends RefCounted

static func manifest(builder: Callable) -> Dictionary:
	return {
		"id": &"hermes_chat",
		"title": "Hermes Chat",
		"name": "Hermes Chat",
		"description": "Chat with Hermes through the Docker Gateway.",
		"subtitle": "Native Hermes OS chat client",
		"icon": "⚕",
		"keywords": "hermes ai chat gateway assistant",
		"category": "System",
		"pinned": true,
		"single_instance": true,
		"agent_visible": true,
		"agent_actions": ["chat.send", "chat.clear"],
		"builder": builder
	}
