extends Node3D
class_name BuildItem

@export var grid_pos: Vector3i = Vector3i.ZERO
@export var item_id: String = ""
@export var behavior_id: String = ""
@export var device_id: String = ""
@export var display_name: String = "build item"
@export var prompt_text: String = "Press E"
@export var default_on: bool = true
@export var default_color: String = "warm"

@onready var _light: Light3D = _find_first_light(self)

func _ready() -> void:
	if item_id == "":
		item_id = name.to_snake_case().replace("_item", "")
	if behavior_id == "":
		behavior_id = item_id
	if device_id == "":
		device_id = "%s_%d_%d_%d" % [item_id, grid_pos.x, grid_pos.y, grid_pos.z]
	_configure_interaction_areas(self)
	_register()
	_connect_signals()

func setup(pos: Vector3i, id: String, behavior: String) -> void:
	grid_pos = pos
	item_id = id
	behavior_id = behavior
	device_id = "%s_%d_%d_%d" % [id, pos.x, pos.y, pos.z]
	display_name = id.replace("_", " ")
	prompt_text = _default_prompt()

func activate(player: Node) -> void:
	match behavior_id:
		"desk_lamp":
			var hdc := get_node_or_null("/root/HomeDeviceController")
			if hdc != null:
				hdc.call("execute_command", device_id, "toggle", {})
		"computer":
			var scene_bridge := get_node_or_null("/root/SceneBridge")
			if scene_bridge != null:
				if player is CharacterBody3D:
					var camera := _find_camera(player)
					var pitch: float = camera.rotation.x if camera != null else 0.0
					scene_bridge.call("save_player_state", player.global_position, player.rotation.y, pitch)
				scene_bridge.call("enter_os")
		"door":
			_toggle_door()
		_:
			pass

func unregister() -> void:
	var hdc := get_node_or_null("/root/HomeDeviceController")
	if hdc != null:
		if hdc.has_method("unregister_device"):
			hdc.call("unregister_device", device_id)
		if hdc.has_signal("device_state_changed") and hdc.device_state_changed.is_connected(_on_device_state_changed):
			hdc.device_state_changed.disconnect(_on_device_state_changed)

func _configure_interaction_areas(node: Node) -> void:
	if node is Area3D:
		node.add_to_group("interactable")
		node.set_meta("interaction_id", device_id)
		node.set_meta("prompt_text", _default_prompt())
		node.set_meta("item_entity", self)
	for child in node.get_children():
		_configure_interaction_areas(child)

func _default_prompt() -> String:
	match behavior_id:
		"door":
			return "Press E to open"
		"bed":
			return "Press E to rest"
		"computer":
			return "Press E to use PC"
		"desk_lamp":
			return "Press E to toggle lamp"
		_:
			return prompt_text

func _register() -> void:
	var hdc := get_node_or_null("/root/HomeDeviceController")
	if hdc == null:
		return
	var type := "item"
	var state := {}
	if behavior_id == "desk_lamp":
		type = "light"
		state = {"is_on": default_on, "color": default_color}
	else:
		state = {"is_on": true}
	var device_display := "%s %d,%d,%d" % [display_name, grid_pos.x, grid_pos.y, grid_pos.z]
	var aliases: Array = [display_name, item_id.replace("_", " "), device_id.replace("_", " ")]
	hdc.call("register_device", device_id, type, state, self, device_display, aliases)
	var final_state: Dictionary = hdc.call("get_device_state", device_id)
	if not final_state.is_empty():
		_apply_state(final_state)

func _connect_signals() -> void:
	var hdc := get_node_or_null("/root/HomeDeviceController")
	if hdc != null and hdc.has_signal("device_state_changed"):
		if not hdc.device_state_changed.is_connected(_on_device_state_changed):
			hdc.device_state_changed.connect(_on_device_state_changed)

func _on_device_state_changed(id: String, new_state: Dictionary) -> void:
	if id == device_id:
		_apply_state(new_state)

func _apply_state(state: Dictionary) -> void:
	if behavior_id != "desk_lamp" or _light == null:
		return
	var is_on := bool(state.get("is_on", true))
	var light_color := Color(1.0, 0.9, 0.7)
	var hdc := get_node_or_null("/root/HomeDeviceController")
	if hdc != null and hdc.has_method("get_color_value"):
		light_color = hdc.call("get_color_value", str(state.get("color", "warm")))
	_light.light_energy = 0.8 if is_on else 0.0
	_light.light_color = light_color

func _toggle_door() -> void:
	var panel := get_node_or_null("DoorPanel")
	if panel == null:
		return
	var target := 0.0 if abs(panel.rotation_degrees.y) > 1.0 else 90.0
	var tween := create_tween()
	tween.tween_property(panel, "rotation_degrees:y", target, 0.35)
	_configure_interaction_areas(self)

func _find_first_light(node: Node) -> Light3D:
	if node is Light3D:
		return node
	for child in node.get_children():
		var found := _find_first_light(child)
		if found != null:
			return found
	return null

func _find_camera(node: Node) -> Camera3D:
	for child in node.get_children():
		if child is Camera3D:
			return child
		var found := _find_camera(child)
		if found != null:
			return found
	return null
