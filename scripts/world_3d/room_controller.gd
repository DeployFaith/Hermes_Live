extends Node3D
## Controller for the editable room scene.
## Handles HomeDeviceController integration for lights and door.

var _ceiling_light: OmniLight3D
var _desk_light: OmniLight3D
var _ceiling_light_fixture: CSGBox3D
var _door_panel: CSGBox3D
var _door_open: bool = false

const CEILING_LIGHT_ENERGY := 0.4
const DESK_LIGHT_ENERGY := 1.7

func _ready() -> void:
	_find_nodes()
	_register_devices()
	_connect_device_signals()
	_connect_door_area()

func _find_nodes() -> void:
	var room_scene := get_node_or_null("RoomScene")
	if room_scene == null:
		push_warning("[RoomController] RoomScene not found")
		return
	var lights_node := room_scene.get_node_or_null("Lights")
	if lights_node:
		_ceiling_light = lights_node.get_node_or_null("CeilingLight") as OmniLight3D
		_desk_light = lights_node.get_node_or_null("DeskLight") as OmniLight3D
	var geo := room_scene.get_node_or_null("RoomGeometry")
	if geo:
		_ceiling_light_fixture = geo.get_node_or_null("CeilingLightFixture") as CSGBox3D
		_door_panel = geo.get_node_or_null("DoorPanel") as CSGBox3D

func _register_devices() -> void:
	var controller := get_node_or_null("/root/HomeDeviceController")
	if controller == null:
		return
	var existing: Dictionary = controller.call("get_device_state", "ceiling_light")
	if existing.is_empty():
		controller.call("register_device", "ceiling_light", "light", {"is_on": true, "color": "white"}, self)
	else:
		controller.call("register_device", "ceiling_light", "light", existing, self)
		_apply_light_state(existing)

func _connect_device_signals() -> void:
	var controller := get_node_or_null("/root/HomeDeviceController")
	if controller != null and controller.has_signal("device_state_changed"):
		if not controller.device_state_changed.is_connected(_on_device_state_changed):
			controller.device_state_changed.connect(_on_device_state_changed)

func _on_device_state_changed(device_id: String, new_state: Dictionary) -> void:
	if device_id == "ceiling_light":
		_apply_light_state(new_state)

func _apply_light_state(state: Dictionary) -> void:
	var is_on: bool = bool(state.get("is_on", true))
	var color_name: String = str(state.get("color", "white"))
	var light_color: Color = Color(1.0, 0.9, 0.7)
	var controller := get_node_or_null("/root/HomeDeviceController")
	if controller != null and controller.has_method("get_color_value"):
		light_color = controller.call("get_color_value", color_name)

	if _ceiling_light:
		_ceiling_light.light_energy = CEILING_LIGHT_ENERGY if is_on else 0.0
		_ceiling_light.light_color = light_color
	if _desk_light:
		_desk_light.light_energy = DESK_LIGHT_ENERGY if is_on else 0.0
		_desk_light.light_color = light_color
	if _ceiling_light_fixture:
		var mat: StandardMaterial3D = _ceiling_light_fixture.material.duplicate() if _ceiling_light_fixture.material else StandardMaterial3D.new()
		if is_on:
			mat.emission_enabled = true
			mat.emission = light_color
			mat.emission_energy_multiplier = 0.15
		else:
			mat.emission_enabled = false
		_ceiling_light_fixture.material = mat

func _connect_door_area() -> void:
	var room_scene := get_node_or_null("RoomScene")
	if room_scene == null:
		return
	# Only connect the original room/front door area. Hallway doors are handled
	# by WorldInteractionSystem proximity tracking and must not auto-open here.
	var door_area := room_scene.get_node_or_null("DoorArea")
	if door_area != null and door_area is Area3D:
		if not door_area.body_entered.is_connected(_on_door_body_entered):
			door_area.body_entered.connect(_on_door_body_entered)

func _on_door_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and not _door_open:
		_open_door()

func _open_door() -> void:
	if _door_open or _door_panel == null:
		return
	_door_open = true
	var tween := create_tween()
	tween.tween_property(_door_panel, "rotation:y", deg_to_rad(-90), 0.5)
