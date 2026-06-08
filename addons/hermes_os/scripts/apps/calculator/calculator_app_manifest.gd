extends RefCounted

static func manifest(builder: Callable) -> Dictionary:
	return {
		"id": &"calculator",
		"title": "Calculator",
		"name": "Calculator",
		"description": "Basic arithmetic calculator.",
		"subtitle": "Basic arithmetic calculator",
		"keywords": "calculator math arithmetic",
		"category": "Utilities",
		"pinned": false,
		"single_instance": true,
		"agent_visible": true,
		"agent_actions": ["calculator.calculate"],
		"builder": builder,
	}
