extends Node3D
class_name CeilingLight3D

@export var device_id: String = "ceiling_light"
@export var display_name: String = "ceiling light"
@export var aliases: Array[String] = ["ceiling light", "overhead light", "main light", "room light"]
@export var default_on: bool = true
@export var default_color: String = "white"

@onready var light_fixture: CSGBox3D = $Fixture
@onready var omni_light: OmniLight3D = $OmniLight3D

var _base_energy: float = 0.4

func _ready() -> void:
	_register_devices()
	_connect_device_signals()

func _register_devices() -> void:
	var controller := get_node_or_null("/root/HomeDeviceController")
	if controller == null:
		push_warning("[CeilingLight3D] HomeDeviceController not found")
		return
	# Always pass defaults — register_device() restores saved state on top
	controller.call("register_device", device_id, "light", {"is_on": default_on, "color": default_color}, self, display_name, aliases)
	# Apply whatever state ended up registered (saved or default)
	var final_state: Dictionary = controller.call("get_device_state", device_id)
	if not final_state.is_empty():
		_apply_state(final_state)

func _connect_device_signals() -> void:
	var controller := get_node_or_null("/root/HomeDeviceController")
	if controller != null and controller.has_signal("device_state_changed"):
		if not controller.device_state_changed.is_connected(_on_device_state_changed):
			controller.device_state_changed.connect(_on_device_state_changed)

func _on_device_state_changed(id: String, new_state: Dictionary) -> void:
	if id == device_id:
		_apply_state(new_state)

func _apply_state(state: Dictionary) -> void:
	var is_on: bool = bool(state.get("is_on", true))
	var color_name: String = str(state.get("color", "white"))
	var light_color: Color = Color(1.0, 0.9, 0.7)
	var controller := get_node_or_null("/root/HomeDeviceController")
	if controller != null and controller.has_method("get_color_value"):
		light_color = controller.call("get_color_value", color_name)
	if omni_light:
		omni_light.light_energy = _base_energy if is_on else 0.0
		omni_light.light_color = light_color
	if light_fixture:
		var mat: StandardMaterial3D = light_fixture.material.duplicate() if light_fixture.material else StandardMaterial3D.new()
		if is_on:
			mat.emission_enabled = true
			mat.emission = light_color
			mat.emission_energy_multiplier = 0.15
		else:
			mat.emission_enabled = false
		light_fixture.material = mat
