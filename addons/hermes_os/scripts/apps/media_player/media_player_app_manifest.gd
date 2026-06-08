extends RefCounted

static func manifest(builder: Callable) -> Dictionary:
	return {
		"id": &"media_player",
		"title": "Media Player",
		"name": "Media Player",
		"description": "Play and manage your music library.",
		"subtitle": "Play and manage your music library",
		"keywords": "media player music audio",
		"category": "Media",
		"pinned": false,
		"single_instance": true,
		"agent_visible": true,
		"agent_actions": ["media.play", "media.pause", "media.next", "media.previous"],
		"builder": builder,
	}
