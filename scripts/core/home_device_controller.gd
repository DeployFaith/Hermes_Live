extends Node

## Autoload singleton — shared in-game home/device control layer.
## Registered as "HomeDeviceController" in project.godot.
##
## Design: Devices register themselves with a unique device_id, a human-readable
## display_name, and an array of aliases (short names the agent can match).
## State is the single source of truth. 3D scene nodes observe state changes
## via the device_state_changed signal and update their visuals accordingly.
## Commands come from Chat, future Home app, future smartphone, etc.

signal device_state_changed(device_id: String, new_state: Dictionary)

# {device_id: {type, state, node_ref, display_name, aliases}}
var _devices: Dictionary = {}

# Persistence
const SAVE_PATH := "user://device_states.json"

# Color name → Godot Color mapping
const COLOR_MAP: Dictionary = {
	"white": Color(1.0, 1.0, 1.0),
	"warm": Color(1.0, 0.9, 0.7),
	"warm white": Color(1.0, 0.9, 0.7),
	"red": Color(1.0, 0.15, 0.15),
	"green": Color(0.15, 1.0, 0.15),
	"blue": Color(0.2, 0.4, 1.0),
	"purple": Color(0.6, 0.2, 1.0),
	"violet": Color(0.5, 0.1, 0.8),
	"pink": Color(1.0, 0.4, 0.7),
	"orange": Color(1.0, 0.5, 0.1),
	"yellow": Color(1.0, 0.95, 0.2),
	"cyan": Color(0.2, 0.9, 1.0),
	"teal": Color(0.1, 0.7, 0.7),
	"amber": Color(1.0, 0.75, 0.0),
	"gold": Color(1.0, 0.84, 0.0),
}

func _ready() -> void:
	print("[HomeDeviceController] Autoload loaded successfully")

## --- Persistence ---
func _save_states() -> void:
	var saved: Dictionary = {}
	for device_id in _devices.keys():
		saved[device_id] = {
			"type": _devices[device_id].get("type", "unknown"),
			"state": _devices[device_id].get("state", {}).duplicate(true),
		}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(saved, "	"))
		file.close()

func _load_states() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("[HomeDeviceController] Failed to parse saved states: %s" % json.get_error_message())
		return {}
	if json.data is Dictionary:
		return json.data
	return {}

## Register a device. Backward-compatible: display_name and aliases are optional.
func register_device(device_id: String, device_type: String, initial_state: Dictionary, node_ref: Node = null, display_name: String = "", aliases: Array = []) -> void:
	var resolved_name: String = display_name if display_name != "" else device_id.replace("_", " ")
	var resolved_aliases: Array[String] = []
	for a in aliases:
		resolved_aliases.append(str(a).to_lower())
	# Always include the display_name and device_id as matchable aliases
	resolved_aliases.append(resolved_name.to_lower())
	resolved_aliases.append(device_id.replace("_", " ").to_lower())

	# Always check saved state on registration — takes priority over both
	# initial_state and any stale in-memory state from a previous session.
	var saved_states := _load_states()
	var state_to_use: Dictionary = initial_state.duplicate(true)
	if saved_states.has(device_id):
		var saved: Dictionary = saved_states[device_id]
		var saved_state: Dictionary = saved.get("state", {})
		if not saved_state.is_empty():
			state_to_use = saved_state
			print("[HomeDeviceController] Restored saved state for '%s': %s" % [device_id, saved_state])

	_devices[device_id] = {
		"type": device_type,
		"state": state_to_use,
		"node_ref": node_ref,
		"display_name": resolved_name,
		"aliases": resolved_aliases,
	}
	print("[HomeDeviceController] Registered device: '%s' (aliases: %s)" % [device_id, resolved_aliases])

func unregister_device(device_id: String) -> void:
	_devices.erase(device_id)

func get_device_state(device_id: String) -> Dictionary:
	if _devices.has(device_id):
		return _devices[device_id].get("state", {}).duplicate(true)
	return {}

func get_device_info(device_id: String) -> Dictionary:
	## Returns full device info including display_name and aliases.
	if _devices.has(device_id):
		var d: Dictionary = _devices[device_id]
		return {
			"device_id": device_id,
			"type": d.get("type", "unknown"),
			"display_name": d.get("display_name", device_id),
			"aliases": d.get("aliases", []),
			"state": d.get("state", {}).duplicate(true),
		}
	return {}

func get_all_devices() -> Dictionary:
	## Returns {device_id: {type, display_name, aliases, state}} for all registered devices.
	var result: Dictionary = {}
	for device_id in _devices.keys():
		result[device_id] = {
			"type": _devices[device_id].get("type", "unknown"),
			"display_name": _devices[device_id].get("display_name", device_id),
			"aliases": _devices[device_id].get("aliases", []),
			"state": _devices[device_id].get("state", {}).duplicate(true),
		}
	return result

## Find a device_id by matching text against display_name and aliases.
## Returns "" if no match. Prefers exact matches over substring matches.
func find_device_by_name(text: String) -> String:
	var lower: String = text.strip_edges().to_lower()
	var best_id: String = ""
	var best_score: int = 0

	for device_id in _devices.keys():
		var device: Dictionary = _devices[device_id]
		var aliases_list: Array = device.get("aliases", [])
		var display: String = str(device.get("display_name", "")).to_lower()

		for alias in aliases_list:
			var alias_str: String = str(alias).to_lower()
			# Exact match wins outright
			if lower == alias_str:
				return device_id
			# Substring match — longer alias = better match
			if alias_str in lower and alias_str.length() > best_score:
				best_id = device_id
				best_score = alias_str.length()

	return best_id

## Find ALL device_ids mentioned in text. Returns array of device_ids.
func find_all_devices_in_text(text: String) -> Array[String]:
	var lower: String = text.strip_edges().to_lower()
	var found: Array[String] = []
	for device_id in _devices.keys():
		var device: Dictionary = _devices[device_id]
		for alias in device.get("aliases", []):
			if str(alias).to_lower() in lower:
				if device_id not in found:
					found.append(device_id)
				break
	return found

func execute_command(device_id: String, command: String, args: Dictionary = {}) -> Dictionary:
	## Returns {ok, message, state}
	if not _devices.has(device_id):
		push_warning("[HomeDeviceController] Unknown device: %s" % device_id)
		return {"ok": false, "message": "Unknown device: %s" % device_id, "state": {}}

	var device: Dictionary = _devices[device_id]
	var device_type: String = device.get("type", "unknown")
	var current_state: Dictionary = device.get("state", {})
	var display: String = device.get("display_name", device_id)
	print("[HomeDeviceController] execute_command: %s/%s (current: %s)" % [device_id, command, current_state])

	match device_type:
		"light":
			return _execute_light_command(device_id, display, current_state, command, args)
		_:
			return {"ok": false, "message": "Unknown device type: %s" % device_type, "state": current_state}

func _execute_light_command(device_id: String, display_name: String, current_state: Dictionary, command: String, args: Dictionary = {}) -> Dictionary:
	var new_state: Dictionary = current_state.duplicate(true)
	var was_on: bool = bool(current_state.get("is_on", false))
	var message: String = ""

	match command:
		"on":
			new_state["is_on"] = true
			message = "%s turned on." % display_name
		"off":
			new_state["is_on"] = false
			message = "%s turned off." % display_name
		"toggle":
			new_state["is_on"] = not was_on
			if new_state["is_on"]:
				message = "%s turned on." % display_name
			else:
				message = "%s turned off." % display_name
		"color":
			var color_name: String = str(args.get("color", "")).strip_edges().to_lower()
			if color_name == "":
				return {"ok": false, "message": "No color specified.", "state": current_state}
			if not COLOR_MAP.has(color_name):
				var available: String = ", ".join(COLOR_MAP.keys())
				return {"ok": false, "message": "Unknown color '%s'. Available: %s" % [color_name, available], "state": current_state}
			new_state["color"] = color_name
			new_state["is_on"] = true
			message = "%s color set to %s." % [display_name, color_name]
		"color_off":
			new_state["color"] = "white"
			message = "%s color reset to white." % display_name
		_:
			return {"ok": false, "message": "Unknown light command: %s" % command, "state": current_state}

	_devices[device_id]["state"] = new_state
	device_state_changed.emit(device_id, new_state)
	_save_states()
	return {"ok": true, "message": message, "state": new_state}

func get_color_value(color_name: String) -> Color:
	if COLOR_MAP.has(color_name):
		return COLOR_MAP[color_name]
	return Color(1.0, 1.0, 1.0)

## Try to parse a natural-language device command.
## Matches device names, actions (on/off/toggle/color), and dispatches.
## Returns {handled, response}.
func try_handle_chat_message(text: String) -> Dictionary:
	var lower: String = text.strip_edges().to_lower()

	# --- Device listing ---
	if "what devices" in lower or "list devices" in lower or "what lights" in lower or "list lights" in lower:
		return _handle_list_devices()

	# --- Find which device(s) the user is talking about ---
	var target_ids: Array[String] = find_all_devices_in_text(lower)

	# If no specific device mentioned, default to ceiling_light for backward compat
	if target_ids.is_empty():
		# Check if the message is about lights generically
		if "light" in lower or "lights" in lower:
			target_ids.append("ceiling_light")
		else:
			return {"ok": false, "handled": false, "message": "", "state": {}}

	# --- Extract action from text ---
	var action: String = _extract_action(lower)

	if action == "":
		# No clear action — report status of the matched device(s)
		return _handle_status(target_ids)

	# --- Execute action on each matched device ---
	var responses: Array[String] = []
	for device_id in target_ids:
		var result: Dictionary = {}
		match action:
			"on":
				result = execute_command(device_id, "on")
			"off":
				result = execute_command(device_id, "off")
			"toggle":
				result = execute_command(device_id, "toggle")
			"color":
				var color_name: String = _extract_color(lower)
				if color_name != "":
					result = execute_command(device_id, "color", {"color": color_name})
				else:
					result = {"ok": true, "message": "What color would you like? Available: %s" % ", ".join(COLOR_MAP.keys())}
			"reset":
				result = execute_command(device_id, "color_off")
		if result.has("message") and str(result["message"]) != "":
			responses.append(str(result["message"]))

	var combined: String = " ".join(responses) if responses.size() > 0 else "Done."
	return {"ok": true, "handled": true, "message": combined, "state": {}}

func _handle_list_devices() -> Dictionary:
	var all := get_all_devices()
	if all.is_empty():
		return {"ok": true, "handled": true, "message": "No devices registered.", "state": {}}
	var lines: Array[String] = []
	for device_id in all.keys():
		var d: Dictionary = all[device_id]
		var s: Dictionary = d.get("state", {})
		var status: String = "on" if bool(s.get("is_on", false)) else "off"
		var color: String = str(s.get("color", "white"))
		lines.append("- %s (%s): %s, color %s" % [d.get("display_name", device_id), device_id, status, color])
	return {"ok": true, "handled": true, "message": "Registered devices:\n" + "\n".join(lines), "state": {}}

func _handle_status(device_ids: Array[String]) -> Dictionary:
	var lines: Array[String] = []
	for device_id in device_ids:
		var info := get_device_info(device_id)
		var s: Dictionary = info.get("state", {})
		var status: String = "on" if bool(s.get("is_on", false)) else "off"
		var color: String = str(s.get("color", "white"))
		lines.append("The %s is currently %s (color: %s)." % [info.get("display_name", device_id), status, color])
	return {"ok": true, "handled": true, "message": " ".join(lines), "state": {}}

func _extract_action(text: String) -> String:
	if "turn on" in text or text == "on" or "lights on" in text or "light on" in text:
		return "on"
	if "turn off" in text or text == "off" or "lights off" in text or "light off" in text:
		return "off"
	if "toggle" in text:
		return "toggle"
	if "reset color" in text or "white light" in text or "normal light" in text:
		return "reset"
	# Check for color keywords
	for color_name in COLOR_MAP.keys():
		if color_name in text:
			return "color"
	# on/off as substring fallback
	if " on" in text or text.ends_with(" on"):
		return "on"
	if " off" in text or text.ends_with(" off"):
		return "off"
	return ""

func _extract_color(text: String) -> String:
	# Check multi-word colors first (longer = more specific)
	var sorted_colors: Array = COLOR_MAP.keys()
	sorted_colors.sort_custom(func(a, b): return a.length() > b.length())
	for color_name in sorted_colors:
		if color_name in text:
			return color_name
	return ""
