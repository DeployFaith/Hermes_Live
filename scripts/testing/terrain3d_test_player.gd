extends CharacterBody3D

@export var walk_speed: float = 6.0
@export var sprint_speed: float = 10.0
@export var mouse_sensitivity: float = 0.002
@export var gravity: float = 22.0
@export var jump_speed: float = 6.0
@export var swim_speed: float = 3.2
@export var swim_sprint_speed: float = 5.0
@export var swim_vertical_speed: float = 2.8
@export var swim_acceleration: float = 7.0

@onready var camera: Camera3D = $Camera3D

const WATER_SURFACE_Y := 0.0
const UNDERWATER_TINT := Color(0.02, 0.42, 0.48, 1.0)
const UNDERWATER_FOG_COLOR := Color(0.04, 0.46, 0.52, 1.0)
const TERRAIN_COLLISION_LAYER := 1

var _pitch: float = 0.0
var _jump_requested := false
var _was_mouse_pressed := false

var _mouse_relative := Vector2.ZERO
var _world_environment: WorldEnvironment
var _base_environment: Environment
var _underwater_environment: Environment
var _underwater_overlay: ColorRect
var _base_camera_far := 5000.0
var _is_underwater := false


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_pitch = camera.rotation.x
	set_collision_mask_value(TERRAIN_COLLISION_LAYER, true)
	_setup_underwater_visuals()


func _enter_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_mouse_relative += event.relative


func _process(_delta: float) -> void:
	_poll_mouse_capture()
	_apply_mouse_look()
	_update_underwater_visuals()
	if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE):
		_jump_requested = true


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
	input_dir = input_dir.normalized()

	if _is_swimming():
		_apply_underwater_walk_movement(input_dir, delta)
	else:
		_apply_walk_movement(input_dir, delta)
	_jump_requested = false

	move_and_slide()


func _apply_walk_movement(input_dir: Vector2, delta: float) -> void:
	var direction := (global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var target_speed := sprint_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed
	velocity.x = direction.x * target_speed
	velocity.z = direction.z * target_speed

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = minf(velocity.y, 0.0)
		if _jump_requested:
			velocity.y = jump_speed


func _apply_underwater_walk_movement(input_dir: Vector2, delta: float) -> void:
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var direction := (right * input_dir.x + forward * -input_dir.y).normalized()

	var target_speed := swim_sprint_speed if Input.is_key_pressed(KEY_SHIFT) else swim_speed
	var target_horizontal_velocity := direction * target_speed
	var acceleration_factor := clampf(swim_acceleration * delta, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, target_horizontal_velocity.x, acceleration_factor)
	velocity.z = lerpf(velocity.z, target_horizontal_velocity.z, acceleration_factor)

	if not is_on_floor():
		velocity.y -= gravity * 0.45 * delta
		if Input.is_key_pressed(KEY_SPACE):
			velocity.y = minf(velocity.y + swim_vertical_speed * delta, swim_vertical_speed)
	else:
		velocity.y = minf(velocity.y, 0.0)
		if _jump_requested or Input.is_key_pressed(KEY_SPACE):
			velocity.y = swim_vertical_speed


func _is_swimming() -> bool:
	return _is_underwater or camera.global_position.y < WATER_SURFACE_Y - 0.02 or global_position.y < WATER_SURFACE_Y - 0.15


func _poll_mouse_capture() -> void:
	if Input.is_key_pressed(KEY_ESCAPE):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var mouse_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if mouse_pressed and not _was_mouse_pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_was_mouse_pressed = mouse_pressed


func _apply_mouse_look() -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		_mouse_relative = Vector2.ZERO
		return
	if _mouse_relative.length_squared() <= 0.001:
		return
	rotate_y(-_mouse_relative.x * mouse_sensitivity)
	_pitch = clamp(_pitch - _mouse_relative.y * mouse_sensitivity, deg_to_rad(-84.0), deg_to_rad(84.0))
	camera.rotation.x = _pitch
	_mouse_relative = Vector2.ZERO


func _setup_underwater_visuals() -> void:
	_base_camera_far = camera.far
	_world_environment = get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if _world_environment != null:
		_base_environment = _world_environment.environment
		if _base_environment != null:
			_underwater_environment = _base_environment.duplicate() as Environment
			_underwater_environment.fog_enabled = true
			_underwater_environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
			_underwater_environment.fog_light_color = UNDERWATER_FOG_COLOR
			_underwater_environment.fog_light_energy = 0.65
			_underwater_environment.fog_sun_scatter = 0.25
			_underwater_environment.fog_aerial_perspective = 1.0
			_underwater_environment.fog_sky_affect = 1.0
			_underwater_environment.ambient_light_color = Color(0.18, 0.62, 0.67, 1.0)
			_underwater_environment.ambient_light_energy = 0.38
			_underwater_environment.background_color = Color(0.02, 0.18, 0.24, 1.0)

	var layer := CanvasLayer.new()
	layer.name = "UnderwaterTintLayer"
	layer.layer = 100
	add_child(layer)

	_underwater_overlay = ColorRect.new()
	_underwater_overlay.name = "UnderwaterTint"
	_underwater_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_underwater_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_underwater_overlay.color = Color(UNDERWATER_TINT.r, UNDERWATER_TINT.g, UNDERWATER_TINT.b, 0.0)
	_underwater_overlay.visible = false
	layer.add_child(_underwater_overlay)


func _update_underwater_visuals() -> void:
	var depth := maxf(0.0, WATER_SURFACE_Y - camera.global_position.y)
	var underwater := depth > 0.02
	if underwater:
		var overlay_alpha := clampf(0.24 + depth * 0.055, 0.24, 0.58)
		var fog_density := clampf(0.055 + depth * 0.022, 0.055, 0.24)
		var view_distance := clampf(170.0 - depth * 12.0, 55.0, 170.0)

		if _underwater_environment != null:
			_underwater_environment.fog_density = fog_density
			_underwater_environment.fog_height = WATER_SURFACE_Y + 1.0
			_underwater_environment.fog_height_density = 0.35
			_world_environment.environment = _underwater_environment

		camera.far = view_distance
		_underwater_overlay.visible = true
		_underwater_overlay.color = Color(UNDERWATER_TINT.r, UNDERWATER_TINT.g, UNDERWATER_TINT.b, overlay_alpha)
	elif _is_underwater:
		if _world_environment != null and _base_environment != null:
			_world_environment.environment = _base_environment
		camera.far = _base_camera_far
		_underwater_overlay.visible = false
		_underwater_overlay.color = Color(UNDERWATER_TINT.r, UNDERWATER_TINT.g, UNDERWATER_TINT.b, 0.0)
	_is_underwater = underwater



