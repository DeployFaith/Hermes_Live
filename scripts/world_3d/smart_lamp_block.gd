extends Node3D
class_name SmartLampBlock

## Smart lamp block entity. Integrates with HomeDeviceController.
## Spawns a light and interaction area. Follows DeskLamp3D pattern.

@export var grid_pos: Vector3i = Vector3i.ZERO
@export var device_id: String = ""
@export var default_on: bool = true
@export var default_color: String = "warm"

var _omni_light: OmniLight3D
var _interactable: Area3D

func _ready() -> void:
	if device_id == "":
		device_id = "smart_lamp_%d_%d_%d" % [grid_pos.x, grid_pos.y, grid_pos.z]
	_build_nodes()
	_register()
	_connect_signals()

func setup(pos: Vector3i) -> void:
	grid_pos = pos
	device_id = "smart_lamp_%d_%d_%d" % [pos.x, pos.y, pos.z]

func activate(_player: Node) -> void:
	var hdc := get_node_or_null("/root/HomeDeviceController")
	if hdc != null:
		hdc.call("execute_command", device_id, "toggle", {})

func unregister() -> void:
	var hdc := get_node_or_null("/root/HomeDeviceController")
	if hdc != null:
		if hdc.has_method("unregister_device"):
			hdc.call("unregister_device", device_id)
		if hdc.has_signal("device_state_changed"):
			if hdc.device_state_changed.is_connected(_on_device_state_changed):
				hdc.device_state_changed.disconnect(_on_device_state_changed)

func _build_nodes() -> void:
	_omni_light = OmniLight3D.new()
	_omni_light.name = "Light"
	_omni_light.position = Vector3(0, 0.15, 0)
	_omni_light.omni_range = 4.0
	_omni_light.light_energy = 1.2
	add_child(_omni_light)

	_interactable = Area3D.new()
	_interactable.name = "Interactable"
	_interactable.add_to_group("interactable")
	_interactable.set_meta("interaction_id", device_id)
	_interactable.set_meta("prompt_text", "Press E to toggle lamp")
	_interactable.set_meta("lamp_entity", self)
	add_child(_interactable)

	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box := BoxShape3D.new()
	box.size = Vector3(0.48, 0.48, 0.48)
	shape.shape = box
	_interactable.add_child(shape)

func _register() -> void:
	var hdc := get_node_or_null("/root/HomeDeviceController")
	if hdc == null:
		return
	var display := "smart lamp %d,%d,%d" % [grid_pos.x, grid_pos.y, grid_pos.z]
	var aliases: Array = [display, "smart lamp", "lamp", device_id.replace("_", " ")]
	hdc.call("register_device", device_id, "light", {"is_on": default_on, "color": default_color}, self, display, aliases)
	var state: Dictionary = hdc.call("get_device_state", device_id)
	if not state.is_empty():
		_apply_state(state)

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
	if _omni_light:
		_omni_light.light_energy = 1.2 if is_on else 0.0
		_omni_light.light_color = light_color
