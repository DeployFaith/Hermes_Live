extends CharacterBody3D
class_name PlayerController3D

@export var walk_speed: float = 5.0
@export var mouse_sensitivity: float = 0.002
@export var gravity: float = 18.0

@onready var camera: Camera3D = $Camera3D
@onready var interaction_ray: RayCast3D = $Camera3D/RayCast3D

var _pitch: float = 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_pitch = camera.rotation.x

	if interaction_ray:
		interaction_ray.target_position = Vector3(0.0, 0.0, -3.0)
		interaction_ray.enabled = true
		interaction_ray.collide_with_areas = true
		interaction_ray.collide_with_bodies = true

	# Restore saved position if returning from OS
	_restore_player_state()

func _restore_player_state() -> void:
	var bridge := get_node_or_null("/root/SceneBridge")
	if bridge == null or not bridge.get("has_player_state"):
		return
	global_position = bridge.player_position
	rotation.y = bridge.player_rotation_y
	_pitch = bridge.player_camera_pitch
	camera.rotation.x = _pitch

func _enter_tree() -> void:
	# Re-capture mouse when returning to this scene
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clamp(_pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-85.0), deg_to_rad(85.0))
		camera.rotation.x = _pitch

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event is InputEventMouseButton and event.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1.0
	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1.0

	var direction := (global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	velocity.x = direction.x * walk_speed
	velocity.z = direction.z * walk_speed

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = minf(velocity.y, 0.0)

	move_and_slide()
