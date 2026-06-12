extends Node3D
class_name DeskLamp3D

## Self-registering desk lamp device.
## Place in any scene — it finds HomeDeviceController and registers itself.

@export var device_id: String = "desk_lamp"
@export var display_name: String = "desk lamp"
@export var aliases: Array[String] = ["desk lamp", "table lamp", "lamp"]
@export var default_on: bool = true
@export var default_color: String = "warm"

@onready var shade: CSGCylinder3D = $Shade
@onready var omni_light: OmniLight3D = $OmniLight3D

var _base_energy: float = 0.8

func _ready() -> void:
	_register()
	_connect_signals()

func _register() -> void:
	var hdc := get_node_or_null("/root/HomeDeviceController")
	if hdc == null:
		push_warning("[DeskLamp3D] HomeDeviceController not found")
		return
	# Always pass defaults — register_device() restores saved state on top
	hdc.call("register_device", device_id, "light", {"is_on": default_on, "color": default_color}, self, display_name, aliases)
	# Apply whatever state ended up registered (saved or default)
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
	var is_on: bool = bool(state.get("is_on", true))
	var color_name: String = str(state.get("color", "warm"))
	var light_color: Color = Color(1.0, 0.9, 0.7)
	var hdc := get_node_or_null("/root/HomeDeviceController")
	if hdc != null and hdc.has_method("get_color_value"):
		light_color = hdc.call("get_color_value", color_name)
	if omni_light:
		omni_light.light_energy = _base_energy if is_on else 0.0
		omni_light.light_color = light_color
	if shade:
		var mat: StandardMaterial3D = shade.material.duplicate() if shade.material else StandardMaterial3D.new()
		if is_on:
			mat.emission_enabled = true
			mat.emission = light_color
			mat.emission_energy_multiplier = 0.4
		else:
			mat.emission_enabled = false
		shade.material = mat
