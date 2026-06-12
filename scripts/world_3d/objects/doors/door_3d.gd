extends Node3D
class_name Door3D

@export var door_id: String = ""
@export var prompt_text: String = "Press E to open"
@export var starts_open: bool = false
@export var locked: bool = false
@export var open_angle: float = 90.0
@export var open_time: float = 0.5
@export var open_direction: float = -1.0

@onready var door_pivot: Node3D = $DoorPivot
@onready var door_area: Area3D = $DoorArea

var _is_open: bool = false

func _ready() -> void:
	door_area.set_meta("is_door", true)
	door_area.add_to_group("interactable")
	if starts_open:
		door_pivot.rotation.y = deg_to_rad(open_angle * open_direction)
		_is_open = true

func toggle() -> void:
	if locked:
		return
	if _is_open:
		close()
	else:
		open()

func open() -> void:
	if locked or _is_open:
		return
	_is_open = true
	var tween := create_tween()
	tween.tween_property(door_pivot, "rotation:y", deg_to_rad(open_angle * open_direction), open_time)

func close() -> void:
	if not _is_open:
		return
	_is_open = false
	var tween := create_tween()
	tween.tween_property(door_pivot, "rotation:y", 0.0, open_time)

func get_prompt_text() -> String:
	if locked:
		return "Locked"
	if _is_open:
		return "Press E to close"
	return prompt_text
