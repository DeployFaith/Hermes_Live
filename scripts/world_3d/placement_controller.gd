extends Node
class_name PlacementController

## Minimal placement controller skeleton.
## Runtime InputMap actions are polled in _process; preview and placement are
## intentionally stubbed for later rewrite phases.

@export var camera_path: NodePath
@export var block_world_path: NodePath
@export var selected_label_path: NodePath
@export var max_distance: float = 8.0

var build_mode_enabled: bool = false
var selected_index: int = 0
var block_order: Array[String] = []
var rotation_steps: int = 0
var target_grid: Vector3i = Vector3i.ZERO
var target_valid: bool = false
var has_target_surface: bool = false

var camera: Camera3D
var block_world: BlockWorld
var selected_label: Label
var _library: BlockLibrary
var _latest_hit: Dictionary = {}

const ACT_TOGGLE := "build_toggle"
const ACT_SELECT_PREFIX := "build_select_"
const ACT_SCROLL_UP := "build_scroll_up"
const ACT_SCROLL_DOWN := "build_scroll_down"
const ACT_ROTATE := "build_rotate"
const ACT_PLACE := "build_place"
const ACT_REMOVE := "build_remove"
const GHOST_VALID_COLOR := Color(0.2, 1.0, 0.3, 0.3)
const GHOST_INVALID_COLOR := Color(1.0, 0.2, 0.2, 0.3)

var _ghost: CSGBox3D
var _ghost_material: StandardMaterial3D
var _dragging: bool = false
var _drag_start: Vector3i = Vector3i.ZERO
var _drag_cells: Array[Vector3i] = []
var _drag_valid: bool = false
var _ghost_pool: Array[CSGBox3D] = []
var _drag_press_active: bool = false
var _item_ghost: Node3D
var _item_ghost_id: String = ""
var _item_ghost_material: StandardMaterial3D
var _structure_ghost: Node3D
var _structure_ghost_id: String = ""
var _structure_ghost_material: StandardMaterial3D


func _ready() -> void:
	camera = get_node_or_null(camera_path) as Camera3D
	block_world = get_node_or_null(block_world_path) as BlockWorld
	selected_label = get_node_or_null(selected_label_path) as Label
	_library = get_node_or_null("../BlockLibrary") as BlockLibrary

	_register_actions()
	_populate_block_order()
	_create_ghost()
	_update_hud()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(ACT_TOGGLE):
		build_mode_enabled = not build_mode_enabled
		if not build_mode_enabled:
			_clear_drag_state()
			_hide_all_ghosts()
		_update_hud()

	_handle_selection_input()

	if not build_mode_enabled:
		_clear_drag_state()
		_hide_all_ghosts()
		return

	_update_target()
	_handle_build_input()
	_update_ghost()


func _register_actions() -> void:
	_ensure_key_action(ACT_TOGGLE, KEY_B)
	var number_keys: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]
	for i in range(number_keys.size()):
		_ensure_key_action("%s%d" % [ACT_SELECT_PREFIX, i + 1], number_keys[i])
	_ensure_mouse_action(ACT_SCROLL_UP, MOUSE_BUTTON_WHEEL_UP)
	_ensure_mouse_action(ACT_SCROLL_DOWN, MOUSE_BUTTON_WHEEL_DOWN)
	_ensure_key_action(ACT_ROTATE, KEY_R)
	_ensure_mouse_action(ACT_PLACE, MOUSE_BUTTON_LEFT)
	_ensure_mouse_action(ACT_REMOVE, MOUSE_BUTTON_RIGHT)


func _ensure_key_action(action_name: String, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if not _action_has_key(action_name, keycode):
		var event := InputEventKey.new()
		event.keycode = keycode
		InputMap.action_add_event(action_name, event)


func _ensure_mouse_action(action_name: String, button_index: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if not _action_has_mouse_button(action_name, button_index):
		var event := InputEventMouseButton.new()
		event.button_index = button_index
		InputMap.action_add_event(action_name, event)


func _action_has_key(action_name: String, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and (event as InputEventKey).keycode == keycode:
			return true
	return false


func _action_has_mouse_button(action_name: String, button_index: MouseButton) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == button_index:
			return true
	return false


func _populate_block_order() -> void:
	block_order.clear()
	if _library != null:
		block_order = _library.get_block_ids()
	if selected_index >= block_order.size():
		selected_index = maxi(block_order.size() - 1, 0)


func _handle_selection_input() -> void:
	for i in range(1, 10):
		if Input.is_action_just_pressed("%s%d" % [ACT_SELECT_PREFIX, i]):
			_select_index(i - 1)

	if Input.is_action_just_pressed(ACT_SCROLL_UP):
		_cycle_selection(-1)
	if Input.is_action_just_pressed(ACT_SCROLL_DOWN):
		_cycle_selection(1)


func _select_index(index: int) -> void:
	if index < 0 or index >= block_order.size():
		return
	selected_index = index
	_clear_drag_state()
	_update_hud()


func _cycle_selection(direction: int) -> void:
	if block_order.is_empty():
		return
	selected_index = wrapi(selected_index + direction, 0, block_order.size())
	_clear_drag_state()
	_update_hud()


func _handle_build_input() -> void:
	if Input.is_action_just_pressed(ACT_ROTATE):
		rotation_steps = (rotation_steps + 1) % 4
		if _is_selected_structure():
			target_valid = _is_valid(target_grid)
		_update_hud()

	_handle_drag_input()

	if Input.is_action_just_pressed(ACT_REMOVE):
		_clear_drag_state()
		_remove_target()


func _raycast() -> Dictionary:
	if camera == null:
		return {}
	var world := camera.get_world_3d()
	if world == null:
		return {}

	var origin := camera.global_position
	var forward := -camera.global_transform.basis.z.normalized()
	var end := origin + forward * max_distance
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_bodies = true
	query.collide_with_areas = true

	var player := camera.get_parent()
	if player is CollisionObject3D:
		query.exclude = [(player as CollisionObject3D).get_rid()]

	var result := world.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return {}
	return {
		"position": result.get("position"),
		"normal": result.get("normal"),
		"collider": result.get("collider"),
	}


func _update_target() -> void:
	has_target_surface = false
	target_valid = false
	_latest_hit = {}

	if camera == null or block_world == null:
		return

	var hit := _raycast()
	if hit.is_empty():
		return

	_latest_hit = hit
	has_target_surface = true
	var hit_pos: Vector3 = hit["position"]
	var hit_normal: Vector3 = hit["normal"]
	var target_world := hit_pos + hit_normal * (block_world.block_size * 0.5)
	target_grid = block_world.world_to_grid(target_world)
	target_valid = _is_valid(target_grid)


func _is_valid(grid_pos: Vector3i) -> bool:
	if block_world == null or not build_mode_enabled or not has_target_surface:
		return false
	if _is_selected_structure():
		return _are_structure_cells_valid(_get_structure_footprint_cells(grid_pos))
	if _is_selected_item():
		return _is_item_cell_valid(grid_pos)
	if not _is_selected_block() and not _is_selected_item():
		return false
	return not block_world.has_block(grid_pos) and not block_world.has_item(grid_pos) and not block_world.has_structure(grid_pos)


func _is_item_cell_valid(grid_pos: Vector3i) -> bool:
	if block_world == null:
		return false
	if block_world.has_block(grid_pos) or block_world.has_item(grid_pos) or block_world.has_structure(grid_pos):
		return false
	if grid_pos.y == 0:
		return true
	var below := grid_pos + Vector3i(0, -1, 0)
	return block_world.has_block(below)


func _get_item_target_grid(hit_pos: Vector3) -> Vector3i:
	var ground_world_y := block_world.to_global(Vector3.ZERO).y
	var floor_cell_world := Vector3(hit_pos.x, ground_world_y + block_world.block_size * 0.5, hit_pos.z)
	return block_world.world_to_grid(floor_cell_world)


func _is_item_ground_surface_hit() -> bool:
	if block_world == null or _latest_hit.is_empty():
		return false
	var hit_pos: Vector3 = _latest_hit.get("position", Vector3.ZERO)
	var hit_normal: Vector3 = _latest_hit.get("normal", Vector3.ZERO)
	var ground_world_y := block_world.to_global(Vector3.ZERO).y
	var ground_tolerance := maxf(0.05, block_world.block_size * 0.25)
	if absf(hit_pos.y - ground_world_y) > ground_tolerance:
		return false
	# Accept both upward and inverted floor normals, but reject walls/vertical faces.
	return absf(hit_normal.y) > 0.5


func get_selected_id() -> String:
	if selected_index < 0 or selected_index >= block_order.size():
		return ""
	return block_order[selected_index]


func _is_selected_block() -> bool:
	var selected_id := get_selected_id()
	if selected_id == "" or _library == null or not _library.has_block(selected_id):
		return false
	return not _library.is_item(selected_id) and not _library.is_structure(selected_id)


func _is_selected_item() -> bool:
	var selected_id := get_selected_id()
	if selected_id == "" or _library == null or not _library.has_block(selected_id):
		return false
	return _library.is_item(selected_id) or _library.get_category(selected_id) == "item"


func _is_selected_structure() -> bool:
	var selected_id := get_selected_id()
	if selected_id == "" or _library == null or not _library.has_block(selected_id):
		return false
	return _library.is_structure(selected_id) or _library.get_category(selected_id) == "structure"


func _get_selected_id() -> String:
	return get_selected_id()


func _get_selected_category() -> String:
	var selected_id := _get_selected_id()
	if selected_id == "" or _library == null:
		return ""
	return _library.get_category(selected_id)


func _update_hud() -> void:
	if selected_label == null:
		return
	var selected_id := _get_selected_id()
	var selected_name := "None"
	if selected_id != "":
		selected_name = _library.get_display_name(selected_id) if _library != null else selected_id.capitalize()
	var category := _get_selected_category()
	if category == "":
		category = "none"
	var drag_text := ""
	if _dragging:
		drag_text = " | Dragging %d blocks...%s" % [_drag_cells.size(), "" if _drag_valid else " (blocked)"]
	var rotation_text := ""
	if category == "item" or category == "structure":
		rotation_text = " | Rot %d°" % [rotation_steps * 90]
	selected_label.text = "Build: %s | %s (%s)%s%s" % ["ON" if build_mode_enabled else "OFF", selected_name, category, rotation_text, drag_text]
	selected_label.visible = true


func _create_ghost() -> void:
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_material.albedo_color = GHOST_INVALID_COLOR

	_ghost = CSGBox3D.new()
	_ghost.name = "PlacementGhost"
	_ghost.use_collision = false
	_ghost.visible = false
	if block_world != null:
		_ghost.size = Vector3.ONE * block_world.block_size
	else:
		_ghost.size = Vector3.ONE * 0.5
	_ghost.material = _ghost_material
	add_child(_ghost)
	_ghost_pool.append(_ghost)


func _hide_ghost() -> void:
	if _ghost != null:
		_ghost.visible = false


func _hide_all_ghosts() -> void:
	for ghost in _ghost_pool:
		if ghost != null:
			ghost.visible = false
	_hide_item_ghost()
	_hide_structure_ghost()


func _hide_extra_drag_ghosts() -> void:
	for i in range(1, _ghost_pool.size()):
		var ghost := _ghost_pool[i]
		if ghost != null:
			ghost.visible = false


func _update_ghost() -> void:
	if _ghost == null:
		return
	if _dragging:
		_hide_item_ghost()
		_update_drag_ghosts()
		return

	_hide_extra_drag_ghosts()
	if _is_selected_item():
		_hide_ghost()
		_hide_structure_ghost()
		_update_item_ghost()
		return
	if _is_selected_structure():
		_hide_item_ghost()
		_update_structure_preview()
		return

	_hide_item_ghost()
	_hide_structure_ghost()
	if not build_mode_enabled or block_world == null or not has_target_surface or not _is_selected_block():
		_hide_ghost()
		return

	_ghost.global_position = block_world.grid_to_world(target_grid)
	_ghost_material.albedo_color = GHOST_VALID_COLOR if target_valid else GHOST_INVALID_COLOR
	_ghost.visible = true


func _hide_item_ghost() -> void:
	if _item_ghost != null:
		_item_ghost.visible = false


func _hide_structure_ghost() -> void:
	if _structure_ghost != null:
		_structure_ghost.visible = false


func _update_item_ghost() -> void:
	if not build_mode_enabled or block_world == null or not has_target_surface or not _is_selected_item():
		_hide_item_ghost()
		return

	var selected_id := get_selected_id()
	if selected_id == "":
		_hide_item_ghost()
		return

	if _item_ghost == null or _item_ghost_id != selected_id:
		_rebuild_item_ghost(selected_id)

	if _item_ghost == null:
		return

	_item_ghost.global_position = _get_item_world_position(target_grid, _item_ghost)
	_item_ghost.rotation_degrees.y = float(rotation_steps * 90)
	_item_ghost_material.albedo_color = GHOST_VALID_COLOR if target_valid else GHOST_INVALID_COLOR
	_item_ghost.visible = true


func _get_item_world_position(grid_pos: Vector3i, item_root: Node3D) -> Vector3:
	var position := block_world.grid_to_world(grid_pos)
	position.y = block_world.to_global(Vector3(grid_pos) * block_world.block_size).y - _get_visual_min_y(item_root)
	return position


func _get_visual_min_y(root: Node3D) -> float:
	var found_visual := false
	var min_y := 0.0
	for node in _get_visual_nodes(root):
		var visual := node as VisualInstance3D
		var bounds := visual.get_aabb()
		var root_from_node := root.global_transform.affine_inverse() * visual.global_transform
		for corner in _get_aabb_corners(bounds):
			var corner_y := (root_from_node * corner).y
			if not found_visual or corner_y < min_y:
				min_y = corner_y
				found_visual = true
	return min_y


func _get_visual_nodes(root: Node) -> Array[Node]:
	var nodes: Array[Node] = []
	if root is GeometryInstance3D:
		nodes.append(root)
	for child in root.get_children():
		nodes.append_array(_get_visual_nodes(child))
	return nodes


func _get_aabb_corners(bounds: AABB) -> Array[Vector3]:
	var p := bounds.position
	var e := bounds.end
	return [
		Vector3(p.x, p.y, p.z),
		Vector3(e.x, p.y, p.z),
		Vector3(p.x, e.y, p.z),
		Vector3(e.x, e.y, p.z),
		Vector3(p.x, p.y, e.z),
		Vector3(e.x, p.y, e.z),
		Vector3(p.x, e.y, e.z),
		Vector3(e.x, e.y, e.z),
	]


func _rebuild_item_ghost(item_id: String) -> void:
	if _item_ghost != null:
		_item_ghost.visible = false
		_item_ghost.queue_free()
		_item_ghost = null
	_item_ghost_id = ""

	if _library == null:
		return
	var scene_path := _library.get_scene_path(item_id)
	if scene_path == "":
		return
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_warning("[PlacementController] Could not load item ghost scene: %s" % scene_path)
		return
	_item_ghost = packed.instantiate() as Node3D
	if _item_ghost == null:
		return
	_item_ghost.name = "ItemPlacementGhost_%s" % item_id
	_item_ghost.visible = false
	_strip_scripts_recursive(_item_ghost)
	add_child(_item_ghost)

	if _item_ghost_material == null:
		_item_ghost_material = StandardMaterial3D.new()
		_item_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_item_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_item_ghost_material.albedo_color = GHOST_INVALID_COLOR

	_disable_collisions_recursive(_item_ghost)
	_apply_ghost_material_recursive(_item_ghost, _item_ghost_material)
	_item_ghost_id = item_id


func _update_structure_preview() -> void:
	if not build_mode_enabled or block_world == null or not has_target_surface or not _is_selected_structure():
		_hide_structure_ghost()
		_hide_extra_drag_ghosts()
		_hide_ghost()
		return

	var selected_id := get_selected_id()
	if selected_id == "":
		_hide_structure_ghost()
		_hide_extra_drag_ghosts()
		_hide_ghost()
		return

	if _structure_ghost == null or _structure_ghost_id != selected_id:
		_rebuild_structure_ghost(selected_id)

	var cells := _get_structure_footprint_cells(target_grid)
	var valid := _are_structure_cells_valid(cells)
	target_valid = valid
	_update_structure_footprint_ghosts(cells, valid)

	if _structure_ghost == null:
		return
	_structure_ghost.global_position = _get_structure_world_position(target_grid, selected_id, rotation_steps * 90)
	_structure_ghost.rotation_degrees.y = float(rotation_steps * 90)
	_structure_ghost_material.albedo_color = GHOST_VALID_COLOR if valid else GHOST_INVALID_COLOR
	_structure_ghost.visible = true


func _rebuild_structure_ghost(structure_id: String) -> void:
	if _structure_ghost != null:
		_structure_ghost.visible = false
		_structure_ghost.queue_free()
		_structure_ghost = null
	_structure_ghost_id = ""

	if _library == null:
		return
	var scene_path := _library.get_scene_path(structure_id)
	if scene_path == "":
		return
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_warning("[PlacementController] Could not load structure ghost scene: %s" % scene_path)
		return
	_structure_ghost = packed.instantiate() as Node3D
	if _structure_ghost == null:
		return
	_structure_ghost.name = "StructurePlacementGhost_%s" % structure_id
	_structure_ghost.visible = false
	_strip_scripts_recursive(_structure_ghost)
	add_child(_structure_ghost)

	if _structure_ghost_material == null:
		_structure_ghost_material = StandardMaterial3D.new()
		_structure_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_structure_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_structure_ghost_material.albedo_color = GHOST_INVALID_COLOR

	_disable_collisions_recursive(_structure_ghost)
	_apply_ghost_material_recursive(_structure_ghost, _structure_ghost_material)
	_structure_ghost_id = structure_id


func _get_structure_footprint_cells(origin_grid: Vector3i) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	if block_world == null or not _is_selected_structure():
		return cells
	var selected_id := get_selected_id()
	if selected_id == "":
		return cells
	return block_world.get_structure_cells(origin_grid, selected_id, rotation_steps * 90)


func _are_structure_cells_valid(cells: Array[Vector3i]) -> bool:
	if cells.is_empty() or block_world == null:
		return false
	for cell in cells:
		if block_world.has_block(cell) or block_world.has_item(cell) or block_world.has_structure(cell):
			return false
	return true


func _update_structure_footprint_ghosts(cells: Array[Vector3i], valid: bool) -> void:
	if block_world == null:
		_hide_extra_drag_ghosts()
		_hide_ghost()
		return
	_ensure_drag_ghost_count(cells.size())
	_ghost_material.albedo_color = GHOST_VALID_COLOR if valid else GHOST_INVALID_COLOR
	for i in range(_ghost_pool.size()):
		var ghost := _ghost_pool[i]
		if ghost == null:
			continue
		if i < cells.size():
			ghost.global_position = block_world.grid_to_world(cells[i])
			ghost.visible = true
		else:
			ghost.visible = false


func _get_rotated_structure_size(structure_id: String, rotation_degrees: int) -> Vector3i:
	if _library == null or structure_id == "":
		return Vector3i.ONE
	var size := _library.get_grid_size(structure_id)
	var rot := wrapi(rotation_degrees, 0, 360)
	if rot == 90 or rot == 270:
		return Vector3i(size.z, size.y, size.x)
	return size


func _get_structure_world_position(origin_grid: Vector3i, structure_id: String, rotation_degrees: int) -> Vector3:
	var size := _get_rotated_structure_size(structure_id, rotation_degrees)
	return Vector3(origin_grid) * block_world.block_size + Vector3(size) * block_world.block_size * 0.5


func _strip_scripts_recursive(node: Node) -> void:
	node.set_script(null)
	for child in node.get_children():
		_strip_scripts_recursive(child)


func _disable_collisions_recursive(node: Node) -> void:
	if node is CollisionObject3D:
		var collision_object := node as CollisionObject3D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	if node is CollisionPolygon3D:
		(node as CollisionPolygon3D).disabled = true
	if node is CSGShape3D:
		(node as CSGShape3D).use_collision = false
	if node is Light3D:
		(node as Light3D).visible = false
	for child in node.get_children():
		_disable_collisions_recursive(child)


func _apply_ghost_material_recursive(node: Node, material: StandardMaterial3D) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).material_override = material
	for child in node.get_children():
		_apply_ghost_material_recursive(child, material)


func _handle_drag_input() -> void:
	if Input.is_action_just_pressed(ACT_PLACE):
		if _can_start_block_drag():
			_drag_press_active = true
			_drag_start = target_grid
			_dragging = false
			_drag_cells.clear()
			_drag_cells.append(_drag_start)
			_drag_valid = target_valid
			_update_hud()
		else:
			_place_selected()

	if _drag_press_active and Input.is_action_pressed(ACT_PLACE):
		if _can_start_block_drag():
			if target_grid != _drag_start:
				_dragging = true
			if _dragging:
				_update_drag_cells()
				_update_hud()
		else:
			_clear_drag_state()

	if _drag_press_active and Input.is_action_just_released(ACT_PLACE):
		if _dragging:
			_place_drag_cells()
		else:
			_place_selected()
		_clear_drag_state()
		_update_target()
		_update_hud()


func _can_start_block_drag() -> bool:
	return block_world != null and build_mode_enabled and has_target_surface and _is_selected_block()


func _clear_drag_state() -> void:
	_dragging = false
	_drag_press_active = false
	_drag_cells.clear()
	_drag_valid = false
	_hide_extra_drag_ghosts()


func _update_drag_cells() -> void:
	var end := target_grid
	end.y = _drag_start.y
	if Input.is_key_pressed(KEY_CTRL):
		_drag_cells = _make_rectangle_cells(_drag_start, end)
	else:
		if Input.is_key_pressed(KEY_SHIFT):
			end = _axis_locked_end(_drag_start, end)
		_drag_cells = _make_line_cells(_drag_start, end)
	_drag_valid = _are_drag_cells_valid(_drag_cells)


func _axis_locked_end(start: Vector3i, end: Vector3i) -> Vector3i:
	var dx := absi(end.x - start.x)
	var dz := absi(end.z - start.z)
	if dx >= dz:
		return Vector3i(end.x, start.y, start.z)
	return Vector3i(start.x, start.y, end.z)


func _make_rectangle_cells(start: Vector3i, end: Vector3i) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	var min_x := mini(start.x, end.x)
	var max_x := maxi(start.x, end.x)
	var min_z := mini(start.z, end.z)
	var max_z := maxi(start.z, end.z)
	for x in range(min_x, max_x + 1):
		for z in range(min_z, max_z + 1):
			cells.append(Vector3i(x, start.y, z))
	return cells


func _make_line_cells(start: Vector3i, end: Vector3i) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	var x0 := start.x
	var z0 := start.z
	var x1 := end.x
	var z1 := end.z
	var dx := absi(x1 - x0)
	var dz := absi(z1 - z0)
	var sx := 1 if x0 < x1 else -1
	var sz := 1 if z0 < z1 else -1
	var err := dx - dz

	while true:
		cells.append(Vector3i(x0, start.y, z0))
		if x0 == x1 and z0 == z1:
			break
		var e2 := err * 2
		if e2 > -dz:
			err -= dz
			x0 += sx
		if e2 < dx:
			err += dx
			z0 += sz
	return cells


func _are_drag_cells_valid(cells: Array[Vector3i]) -> bool:
	if cells.is_empty() or block_world == null:
		return false
	for cell in cells:
		if block_world.has_block(cell) or block_world.has_item(cell) or block_world.has_structure(cell):
			return false
	return true


func _ensure_drag_ghost_count(count: int) -> void:
	if _ghost == null:
		return
	while _ghost_pool.size() < count:
		var ghost := CSGBox3D.new()
		ghost.name = "PlacementDragGhost%d" % _ghost_pool.size()
		ghost.use_collision = false
		ghost.visible = false
		ghost.size = Vector3.ONE * (block_world.block_size if block_world != null else 0.5)
		ghost.material = _ghost_material
		add_child(ghost)
		_ghost_pool.append(ghost)


func _update_drag_ghosts() -> void:
	if block_world == null:
		_hide_all_ghosts()
		return
	_ensure_drag_ghost_count(_drag_cells.size())
	_ghost_material.albedo_color = GHOST_VALID_COLOR if _drag_valid else GHOST_INVALID_COLOR
	for i in range(_ghost_pool.size()):
		var ghost := _ghost_pool[i]
		if ghost == null:
			continue
		if i < _drag_cells.size():
			ghost.global_position = block_world.grid_to_world(_drag_cells[i])
			ghost.visible = true
		else:
			ghost.visible = false


func _place_drag_cells() -> void:
	if block_world == null or not build_mode_enabled or not _drag_valid or not _is_selected_block():
		return
	var selected_id := get_selected_id()
	if selected_id == "":
		return
	for cell in _drag_cells:
		block_world.place_block(cell, selected_id)


func _place_selected() -> void:
	if block_world == null or not build_mode_enabled or not target_valid:
		return
	var selected_id := get_selected_id()
	if selected_id == "":
		return

	if _is_selected_structure():
		block_world.place_structure(target_grid, selected_id, rotation_steps * 90)
	elif _is_selected_item():
		block_world.place_item(target_grid, selected_id, rotation_steps * 90)
	elif _is_selected_block():
		block_world.place_block(target_grid, selected_id)
	_update_target()
	_update_ghost()


func _remove_target() -> void:
	if block_world == null or not build_mode_enabled:
		return

	var hit := _raycast()
	if hit.is_empty():
		return

	var collider := hit.get("collider") as Node
	if collider != null and block_world.remove_item_node(collider):
		_update_target()
		_update_ghost()
		return

	var hit_pos: Vector3 = hit["position"]
	var hit_normal: Vector3 = hit["normal"]
	var remove_grid := block_world.world_to_grid(hit_pos - hit_normal * 0.01)

	if block_world.has_structure(remove_grid):
		block_world.remove_structure(remove_grid)
	elif block_world.has_item(remove_grid):
		block_world.remove_item(remove_grid)
	elif block_world.has_block(remove_grid):
		block_world.remove_block(remove_grid)

	_update_target()
	_update_ghost()
