extends Node

## Autoload singleton that manages transitions between 3D rooms and the OS.
## Registered as "SceneBridge" in project.godot.

signal room_changed(room_path: String)
signal entered_os
signal entered_world

const WORLD_SCENE := "res://scenes/world_3d.tscn"
const OS_SCENE := "res://scenes/os/os_shell.tscn"

var current_scene: String = "world"  # "world" or "os"
var current_room: String = "res://scenes/world_3d.tscn"
var _returning_from_os: bool = false

# Player state — persists across scene changes
var player_position: Vector3 = Vector3.ZERO
var player_rotation_y: float = 0.0
var player_camera_pitch: float = 0.0
var has_player_state: bool = false

# Room spawn points — where the player appears when entering a room
# {room_path: {position, rotation_y, camera_pitch}}
var _room_spawn_points: Dictionary = {}

func enter_os() -> void:
	current_scene = "os"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file(OS_SCENE)
	entered_os.emit()

func exit_to_world() -> void:
	current_scene = "world"
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().change_scene_to_file(current_room)
	entered_world.emit()

func change_room(room_path: String, spawn_position: Vector3 = Vector3.ZERO, spawn_rotation_y: float = 0.0) -> void:
	## Transition to a different 3D room
	current_scene = "world"
	current_room = room_path
	# Set spawn point for the target room
	player_position = spawn_position
	player_rotation_y = spawn_rotation_y
	player_camera_pitch = 0.0
	has_player_state = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().change_scene_to_file(room_path)
	room_changed.emit(room_path)

## Called by OS shell before transitioning to world, to preserve session state.
func set_returning_from_os(was_logged_in: bool) -> void:
	_returning_from_os = was_logged_in

func was_returning_from_os() -> bool:
	return _returning_from_os

func clear_returning_flag() -> void:
	_returning_from_os = false

## Save/restore 3D player state
func save_player_state(pos: Vector3, rot_y: float, pitch: float) -> void:
	player_position = pos
	player_rotation_y = rot_y
	player_camera_pitch = pitch
	has_player_state = true

func is_in_world() -> bool:
	return current_scene == "world"

func is_in_os() -> bool:
	return current_scene == "os"
