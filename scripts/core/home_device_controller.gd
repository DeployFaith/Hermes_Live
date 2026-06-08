extends Node

## Autoload singleton — shared in-game home/device control layer.
## Registered as "HomeDeviceController" in project.godot.
##
## Design: Devices register themselves by calling register_device().
## State is the single source of truth. 3D scene nodes observe state changes
## via the device_state_changed signal and update their visuals accordingly.
## Commands come from Chat, future Home app, future smartphone, etc.

signal device_state_changed(device_id: String, new_state: Dictionary)

# {device_id: {type, state, node_ref}}
var _devices: Dictionary = {}

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

func register_device(device_id: String, device_type: String, initial_state: Dictionary, node_ref: Node = null) -> void:
	_devices[device_id] = {
		"type": device_type,
		"state": initial_state.duplicate(true),
		"node_ref": node_ref,
	}

func unregister_device(device_id: String) -> void:
	_devices.erase(device_id)

func get_device_state(device_id: String) -> Dictionary:
	if _devices.has(device_id):
		return _devices[device_id].get("state", {}).duplicate(true)
	return {}

func get_all_devices() -> Dictionary:
	var result: Dictionary = {}
	for device_id in _devices.keys():
		result[device_id] = {
			"type": _devices[device_id].get("type", "unknown"),
			"state": _devices[device_id].get("state", {}).duplicate(true),
		}
	return result

func execute_command(device_id: String, command: String, args: Dictionary = {}) -> Dictionary:
	## Returns {ok, message, state}
	if not _devices.has(device_id):
		push_warning("[HomeDeviceController] Unknown device: %s" % device_id)
		return {"ok": false, "message": "Unknown device: %s" % device_id, "state": {}}

	var device: Dictionary = _devices[device_id]
	var device_type: String = device.get("type", "unknown")
	var current_state: Dictionary = device.get("state", {})
	print("[HomeDeviceController] execute_command: %s/%s (current: %s)" % [device_id, command, current_state])

	match device_type:
		"light":
			return _execute_light_command(device_id, current_state, command, args)
		_:
			return {"ok": false, "message": "Unknown device type: %s" % device_type, "state": current_state}

func _execute_light_command(device_id: String, current_state: Dictionary, command: String, args: Dictionary = {}) -> Dictionary:
	var new_state: Dictionary = current_state.duplicate(true)
	var was_on: bool = bool(current_state.get("is_on", false))
	var message: String = ""

	match command:
		"on":
			new_state["is_on"] = true
			message = "Light turned on."
		"off":
			new_state["is_on"] = false
			message = "Light turned off."
		"toggle":
			new_state["is_on"] = not was_on
			if new_state["is_on"]:
				message = "Light turned on."
			else:
				message = "Light turned off."
		"color":
			var color_name: String = str(args.get("color", "")).strip_edges().to_lower()
			if color_name == "":
				return {"ok": false, "message": "No color specified.", "state": current_state}
			if not COLOR_MAP.has(color_name):
				var available: String = ", ".join(COLOR_MAP.keys())
				return {"ok": false, "message": "Unknown color '%s'. Available: %s" % [color_name, available], "state": current_state}
			new_state["color"] = color_name
			new_state["is_on"] = true
			message = "Light color set to %s." % color_name
		"color_off":
			new_state["color"] = "white"
			message = "Light color reset to white."
		_:
			return {"ok": false, "message": "Unknown light command: %s" % command, "state": current_state}

	_devices[device_id]["state"] = new_state
	device_state_changed.emit(device_id, new_state)
	return {"ok": true, "message": message, "state": new_state}

func get_color_value(color_name: String) -> Color:
	if COLOR_MAP.has(color_name):
		return COLOR_MAP[color_name]
	return Color(1.0, 1.0, 1.0)

## Try to parse a natural-language light command. Returns {handled, response}.
func try_handle_chat_message(text: String) -> Dictionary:
	var lower: String = text.strip_edges().to_lower()

	# "turn on the light" / "lights on" / "on"
	if lower.begins_with("turn on") or lower == "on" or lower == "lights on" or lower == "light on":
		return execute_command("ceiling_light", "on")

	# "turn off the light" / "lights off" / "off"
	if lower.begins_with("turn off") or lower == "off" or lower == "lights off" or lower == "light off":
		return execute_command("ceiling_light", "off")

	# "toggle the light"
	if lower.begins_with("toggle") or lower == "toggle light" or lower == "toggle the light":
		return execute_command("ceiling_light", "toggle")

	# "light status" / "is the light on"
	if "light status" in lower or "light state" in lower or "is the light" in lower:
		var state := get_device_state("ceiling_light")
		var is_on: bool = bool(state.get("is_on", false))
		var color_name: String = str(state.get("color", "white"))
		var status_text: String = "on" if is_on else "off"
		return {"ok": true, "handled": true, "message": "The ceiling light is currently %s (color: %s)." % [status_text, color_name], "state": state}

	# "reset color" / "white light"
	if "reset color" in lower or "white light" in lower or "normal light" in lower:
		return execute_command("ceiling_light", "color_off")

	# Color commands: "make the light purple", "set color to blue", "light red", etc.
	if "light" in lower or "lights" in lower:
		# Check for color keywords
		for color_name in COLOR_MAP.keys():
			if color_name in lower:
				return execute_command("ceiling_light", "color", {"color": color_name})
		# Check for "color" without a specific color
		if "color" in lower or "colour" in lower or "hue" in lower:
			return {"ok": true, "handled": true, "message": "What color would you like? Available: %s" % ", ".join(COLOR_MAP.keys()), "state": get_device_state("ceiling_light")}
		# on/off fallback
		if "on" in lower:
			return execute_command("ceiling_light", "on")
		if "off" in lower:
			return execute_command("ceiling_light", "off")
		# Default: report status
		var state2 := get_device_state("ceiling_light")
		var is_on2: bool = bool(state2.get("is_on", false))
		var color2: String = str(state2.get("color", "white"))
		return {"ok": true, "handled": true, "message": "The ceiling light is currently %s (color: %s). You can say 'turn on/off the light', 'toggle', or 'make the light [color]'." % ["on" if is_on2 else "off", color2], "state": state2}

	return {"ok": false, "handled": false, "message": "", "state": {}}
