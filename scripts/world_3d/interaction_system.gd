extends Node
class_name WorldInteractionSystem

@export var raycast_path: NodePath
@export var prompt_label_path: NodePath

@onready var interaction_ray: RayCast3D = get_node_or_null(raycast_path) as RayCast3D
@onready var prompt_label: Label = get_node_or_null(prompt_label_path) as Label

var _current_interactable: Node = null
var _nearby_door: Node = null
var _open_doors: Dictionary = {}
var _build_controller: Node = null

func _ready() -> void:
	_set_prompt_visible(false)
	call_deferred("_connect_door_signals")
	_build_controller = get_node_or_null("../BuildController")

func _connect_door_signals() -> void:
	var world := get_parent()
	if world == null:
		return
	for child in world.get_children():
		_connect_door_signals_recursive(child)

func _connect_door_signals_recursive(node: Node) -> void:
	if node is Area3D and node.has_meta("is_door") and node.get_meta("is_door", false):
		if not node.body_entered.is_connected(_on_door_body_entered.bind(node)):
			node.body_entered.connect(_on_door_body_entered.bind(node))
		if not node.body_exited.is_connected(_on_door_body_exited.bind(node)):
			node.body_exited.connect(_on_door_body_exited.bind(node))
	for child in node.get_children():
		_connect_door_signals_recursive(child)

func _on_door_body_entered(body: Node3D, door_area: Area3D) -> void:
	if body is CharacterBody3D:
		_nearby_door = door_area

func _on_door_body_exited(body: Node3D, door_area: Area3D) -> void:
	if body is CharacterBody3D and _nearby_door == door_area:
		_nearby_door = null

func _process(_delta: float) -> void:
	# When build mode is active, show build prompt instead of interaction
	if _build_controller != null and _build_controller.build_mode_enabled:
		_set_prompt_visible(false)
		_current_interactable = null
		return

	# Doors use proximity only and always take priority over raycast interactables.
	if _nearby_door != null and not _open_doors.has(_nearby_door):
		_set_prompt_text("Press E to open")
		_set_prompt_visible(true)
		_current_interactable = null
		return

	# PCs and other non-door interactables use raycast only.
	_current_interactable = _find_interactable_from_raycast()
	if _current_interactable != null:
		var prompt_text := _get_prompt_text(_current_interactable)
		_set_prompt_text(prompt_text)
		_set_prompt_visible(true)
	else:
		_set_prompt_visible(false)

func _unhandled_input(event: InputEvent) -> void:
	# When build mode is active, don't handle E for regular interactions
	if _build_controller != null and _build_controller.build_mode_enabled:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		# Check nearby door first (walk-up)
		if _nearby_door != null and not _open_doors.has(_nearby_door):
			_open_door(_nearby_door)
			return
		# Check raycast interactable
		if _current_interactable != null:
			_activate_interactable(_current_interactable)

func _activate_interactable(interactable: Node) -> void:
	# Check for smart lamp interaction
	if interactable.has_meta("lamp_entity"):
		var lamp = interactable.get_meta("lamp_entity")
		if lamp != null and lamp.has_method("activate"):
			var player := _get_player()
			lamp.call("activate", player)
			return

	# Placed item scenes expose their root script through item_entity.
	if interactable.has_meta("item_entity"):
		var item = interactable.get_meta("item_entity")
		if item != null and item.has_method("activate"):
			var player := _get_player()
			item.call("activate", player)
			return

	var scene_bridge := get_node_or_null("/root/SceneBridge")
	if scene_bridge == null:
		return

	# Doors are proximity-only
	if interactable.has_meta("is_door") and interactable.get_meta("is_door", false):
		return

	# PC — save player state and enter OS
	_save_player_state(scene_bridge)
	scene_bridge.call("enter_os")

func _open_door(door_area: Area3D) -> void:
	if _open_doors.has(door_area):
		return
	_open_doors[door_area] = true
	_nearby_door = null
	_set_prompt_visible(false)

	var parent := door_area.get_parent()
	if parent == null:
		return

	var door_panel: Node = null
	for child in parent.get_children():
		if child is CSGBox3D and "DoorPanel" in child.name:
			door_panel = child
			break

	if door_panel == null:
		for child in parent.get_children():
			if child is CSGBox3D and "Panel" in child.name:
				door_panel = child
				break

	if door_panel != null:
		var direction: float = door_area.get_meta("open_direction", -1.0) if door_area.has_meta("open_direction") else -1.0
		var tween := create_tween()
		tween.tween_property(door_panel, "rotation:y", deg_to_rad(90.0 * direction), 0.5)

func _get_prompt_text(interactable: Node) -> String:
	if interactable.has_meta("is_door") and interactable.get_meta("is_door", false):
		return "Press E to open"
	if interactable.has_meta("prompt_text"):
		return str(interactable.get_meta("prompt_text"))
	if interactable.is_in_group("interactable"):
		return "Press E to use PC"
	return "Press E"

func _save_player_state(scene_bridge: Node) -> void:
	if interaction_ray == null:
		return
	var camera := interaction_ray.get_parent()
	if camera == null:
		return
	var player := camera.get_parent()
	if player == null or not player is CharacterBody3D:
		return
	var pitch: float = camera.rotation.x if camera is Camera3D else 0.0
	scene_bridge.call("save_player_state", player.global_position, player.rotation.y, pitch)

func _find_interactable_from_raycast() -> Node:
	if interaction_ray == null:
		return null
	interaction_ray.force_raycast_update()
	if not interaction_ray.is_colliding():
		return null
	var collider := interaction_ray.get_collider()
	if collider is Node:
		return _find_interactable_parent(collider)
	return null

func _find_interactable_parent(node: Node) -> Node:
	var current := node
	while current != null:
		if current.is_in_group("interactable"):
			if current.has_meta("is_door") and current.get_meta("is_door", false):
				return null
			return current
		current = current.get_parent()
	return null

func _get_player() -> Node:
	if interaction_ray == null:
		return null
	var camera := interaction_ray.get_parent()
	if camera == null:
		return null
	return camera.get_parent()

func _set_prompt_visible(is_visible: bool) -> void:
	if prompt_label != null:
		prompt_label.visible = is_visible

func _set_prompt_text(text: String) -> void:
	if prompt_label != null:
		prompt_label.text = text
