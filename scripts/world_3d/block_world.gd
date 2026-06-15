extends Node3D
class_name BlockWorld

## Manages placed build blocks and one-cell item scene instances.
## Blocks are stored as cube data. Items share the same grid occupancy and are
## instanced from BlockLibrary scene_path definitions.

@export var block_size: float = 0.5  # Full edge length of each block cube
@export var create_block_collision: bool = true

var _placed: Dictionary = {}       # Vector3i -> block_id (String)
var _nodes: Dictionary = {}        # Vector3i -> Node3D (CSGBox3D or MeshInstance3D)
var _entities: Dictionary = {}     # Vector3i -> Node3D (for interactive blocks)
var _placed_items: Dictionary = {} # Vector3i -> {id, rotation_degrees, node}
var _placed_structures: Dictionary = {} # origin Vector3i -> {id, rotation_degrees, node, cells}
var _structure_cells: Dictionary = {}   # occupied Vector3i -> origin Vector3i
var _terrain_collision_body: StaticBody3D
var _terrain_collision_shapes: Dictionary = {} # Vector3i -> CollisionShape3D
var _library: BlockLibrary

const SMART_LAMP_SCRIPT := preload("res://scripts/world_3d/smart_lamp_block.gd")
const TERRAIN_COLLISION_BODY_NAME := "TerrainCollision"

func _ready() -> void:
	# Block grid coordinates are world-aligned; BlockWorld is only an organizational
	# container.  Keep its transform at identity so placed children, grid lookup,
	# and preview code cannot inherit an unexpected scene/editor offset.
	transform = Transform3D.IDENTITY
	_library = get_node_or_null("../BlockLibrary") as BlockLibrary
	if _library == null:
		push_warning("[BlockWorld] BlockLibrary not found")

func world_to_grid(world_pos: Vector3) -> Vector3i:
	var local_pos := to_local(world_pos)
	return Vector3i(
		floori(local_pos.x / block_size),
		floori(local_pos.y / block_size),
		floori(local_pos.z / block_size)
	)

func grid_to_local(grid_pos: Vector3i) -> Vector3:
	return Vector3(grid_pos) * block_size + Vector3.ONE * (block_size * 0.5)

func grid_to_world(grid_pos: Vector3i) -> Vector3:
	return to_global(grid_to_local(grid_pos))

func place_block(grid_pos: Vector3i, block_id: String) -> void:
	if _placed.has(grid_pos) or _placed_items.has(grid_pos) or has_structure(grid_pos):
		return  # Already occupied
	if _library == null or not _library.has_block(block_id):
		return
	if _library.is_item(block_id) or _library.is_structure(block_id):
		return

	_placed[grid_pos] = block_id

	# Create visual — use MeshInstance3D for per-face textures, CSGBox3D otherwise
	var node: Node3D
	if _library.has_per_face_textures(block_id):
		node = _create_mesh_block(grid_pos, block_id)
	else:
		node = _create_csg_block(grid_pos, block_id)
	add_child(node)
	_nodes[grid_pos] = node

	# If interactive, spawn entity
	if _library.is_interactable(block_id):
		_spawn_entity(grid_pos, block_id)

	# Bulk-generated terrain disables per-visual collision and uses one shared
	# StaticBody3D with one shape per terrain block. Removing a terrain block can
	# then remove exactly its shape, avoiding stale heightmap/ghost collision.
	if not create_block_collision:
		_add_terrain_collision_shape(grid_pos)

func set_block_collision_enabled(enabled: bool) -> void:
	create_block_collision = enabled

func _get_or_create_terrain_collision_body() -> StaticBody3D:
	if _terrain_collision_body != null and is_instance_valid(_terrain_collision_body):
		return _terrain_collision_body
	_terrain_collision_body = get_node_or_null(TERRAIN_COLLISION_BODY_NAME) as StaticBody3D
	if _terrain_collision_body == null:
		_terrain_collision_body = StaticBody3D.new()
		_terrain_collision_body.name = TERRAIN_COLLISION_BODY_NAME
		add_child(_terrain_collision_body)
	return _terrain_collision_body

func _add_terrain_collision_shape(grid_pos: Vector3i) -> void:
	if _terrain_collision_shapes.has(grid_pos):
		return
	var body := _get_or_create_terrain_collision_body()
	var collision := CollisionShape3D.new()
	collision.name = "TerrainCollision_%d_%d_%d" % [grid_pos.x, grid_pos.y, grid_pos.z]
	var shape := BoxShape3D.new()
	shape.size = Vector3(block_size, block_size, block_size)
	collision.shape = shape
	collision.position = grid_to_local(grid_pos)
	body.add_child(collision)
	_terrain_collision_shapes[grid_pos] = collision

func _remove_terrain_collision_shape(grid_pos: Vector3i) -> void:
	if not _terrain_collision_shapes.has(grid_pos):
		return
	var collision := _terrain_collision_shapes[grid_pos] as CollisionShape3D
	if collision != null and is_instance_valid(collision):
		collision.queue_free()
	_terrain_collision_shapes.erase(grid_pos)

func _create_csg_block(grid_pos: Vector3i, block_id: String) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.name = "Block_%s_%d_%d_%d" % [block_id, grid_pos.x, grid_pos.y, grid_pos.z]
	box.size = Vector3(block_size, block_size, block_size)
	box.position = grid_to_local(grid_pos)
	box.use_collision = false  # We add our own collision below
	box.material = _library.make_material(block_id)

	# Add explicit collision for normal player-placed blocks. Bulk-generated terrain
	# disables this and uses one shared terrain body instead.
	if create_block_collision:
		var static_body := StaticBody3D.new()
		static_body.name = "Collision"
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(block_size, block_size, block_size)
		collision.shape = shape
		static_body.add_child(collision)
		box.add_child(static_body)

	return box

func _create_mesh_block(grid_pos: Vector3i, block_id: String) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "Block_%s_%d_%d_%d" % [block_id, grid_pos.x, grid_pos.y, grid_pos.z]
	mesh_node.position = grid_to_local(grid_pos)

	mesh_node.mesh = _create_per_face_box_mesh(Vector3(block_size, block_size, block_size))

	# Assign per-face materials: [top, side, bottom]
	# Godot's BoxMesh is a single-surface PrimitiveMesh, so per-face materials
	# require an ArrayMesh with one surface per face. Surface order below is:
	# 0=top, 1=bottom, 2=right, 3=left, 4=front, 5=back.
	var face_materials := _library.make_face_materials(block_id)
	if face_materials.size() == 3:
		var top_mat: Material = face_materials[0]
		var side_mat: Material = face_materials[1]
		var bottom_mat: Material = face_materials[2]
		mesh_node.set_surface_override_material(0, top_mat)    # top
		mesh_node.set_surface_override_material(1, bottom_mat) # bottom
		mesh_node.set_surface_override_material(2, side_mat)   # right
		mesh_node.set_surface_override_material(3, side_mat)   # left
		mesh_node.set_surface_override_material(4, side_mat)   # front
		mesh_node.set_surface_override_material(5, side_mat)   # back

	# Add collision for normal player-placed blocks. Bulk-generated terrain disables
	# this and uses one shared terrain body instead.
	if create_block_collision:
		var static_body := StaticBody3D.new()
		static_body.name = "Collision"
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(block_size, block_size, block_size)
		collision.shape = shape
		static_body.add_child(collision)
		mesh_node.add_child(static_body)

	return mesh_node

func _create_per_face_box_mesh(size: Vector3) -> ArrayMesh:
	var half := size * 0.5
	var mesh := ArrayMesh.new()

	_add_box_face(mesh,
		[
			Vector3(half.x, half.y, half.z),
			Vector3(-half.x, half.y, half.z),
			Vector3(half.x, half.y, -half.z),
			Vector3(-half.x, half.y, -half.z),
		],
		Vector3.UP
	) # top
	_add_box_face(mesh,
		[
			Vector3(-half.x, -half.y, half.z),
			Vector3(half.x, -half.y, half.z),
			Vector3(-half.x, -half.y, -half.z),
			Vector3(half.x, -half.y, -half.z),
		],
		Vector3.DOWN
	) # bottom
	_add_box_face(mesh,
		[
			Vector3(half.x, half.y, half.z),
			Vector3(half.x, half.y, -half.z),
			Vector3(half.x, -half.y, half.z),
			Vector3(half.x, -half.y, -half.z),
		],
		Vector3.RIGHT
	) # right
	_add_box_face(mesh,
		[
			Vector3(-half.x, half.y, -half.z),
			Vector3(-half.x, half.y, half.z),
			Vector3(-half.x, -half.y, -half.z),
			Vector3(-half.x, -half.y, half.z),
		],
		Vector3.LEFT
	) # left
	_add_box_face(mesh,
		[
			Vector3(-half.x, half.y, half.z),
			Vector3(half.x, half.y, half.z),
			Vector3(-half.x, -half.y, half.z),
			Vector3(half.x, -half.y, half.z),
		],
		Vector3.BACK
	) # front (+Z)
	_add_box_face(mesh,
		[
			Vector3(half.x, half.y, -half.z),
			Vector3(-half.x, half.y, -half.z),
			Vector3(half.x, -half.y, -half.z),
			Vector3(-half.x, -half.y, -half.z),
		],
		Vector3.FORWARD
	) # back (-Z)

	return mesh

func _add_box_face(mesh: ArrayMesh, vertices: Array, normal: Vector3) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(vertices)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([normal, normal, normal, normal])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 1, 3, 2])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func remove_block(grid_pos: Vector3i) -> void:
	if not _placed.has(grid_pos):
		return

	_remove_terrain_collision_shape(grid_pos)

	# Remove entity first
	if _entities.has(grid_pos):
		var entity: Node3D = _entities[grid_pos]
		if entity != null and is_instance_valid(entity):
			if entity.has_method("unregister"):
				entity.call("unregister")
			entity.queue_free()
		_entities.erase(grid_pos)

	# Remove visual
	if _nodes.has(grid_pos):
		var node: Node3D = _nodes[grid_pos]
		if node != null and is_instance_valid(node):
			node.queue_free()
		_nodes.erase(grid_pos)

	_placed.erase(grid_pos)

func has_block(grid_pos: Vector3i) -> bool:
	return _placed.has(grid_pos)

func get_block_id(grid_pos: Vector3i) -> String:
	return str(_placed.get(grid_pos, ""))

func place_item(grid_pos: Vector3i, item_id: String, rotation_degrees: int) -> void:
	if _placed.has(grid_pos) or _placed_items.has(grid_pos) or has_structure(grid_pos):
		return
	if _library == null or not _library.has_block(item_id) or not _library.is_item(item_id):
		return

	var scene_path := _library.get_scene_path(item_id)
	if scene_path == "":
		return
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_warning("[BlockWorld] Could not load item scene: %s" % scene_path)
		return

	var item := packed.instantiate() as Node3D
	if item == null:
		return
	item.name = "Item_%s_%d_%d_%d" % [item_id, grid_pos.x, grid_pos.y, grid_pos.z]

	var behavior := _library.get_behavior_id(item_id)
	if item.has_method("setup"):
		item.call("setup", grid_pos, item_id, behavior)
	add_child(item)
	item.rotation_degrees.y = float(wrapi(rotation_degrees, 0, 360))
	item.global_position = _get_item_world_position(grid_pos, item)
	if _library.is_interactable(item_id):
		_add_interactable_group_recursive(item)

	_placed_items[grid_pos] = {
		"id": item_id,
		"rotation_degrees": wrapi(rotation_degrees, 0, 360),
		"node": item,
	}

func remove_item(grid_pos: Vector3i) -> bool:
	var origin := _get_item_origin_for_grid(grid_pos)
	if not _placed_items.has(origin):
		return false
	var data: Dictionary = _placed_items[origin]
	var item := data.get("node") as Node
	if item != null and is_instance_valid(item):
		if item.has_method("unregister"):
			item.call("unregister")
		item.queue_free()
	_placed_items.erase(origin)
	return true

func remove_item_node(node: Node) -> bool:
	if node == null:
		return false
	var origin := _get_item_origin_for_node(node)
	if not _placed_items.has(origin):
		return false
	return remove_item(origin)

func has_item(grid_pos: Vector3i) -> bool:
	return _placed_items.has(_get_item_origin_for_grid(grid_pos))

func _get_item_world_position(grid_pos: Vector3i, item_root: Node3D) -> Vector3:
	var position := grid_to_world(grid_pos)
	position.y = to_global(Vector3(grid_pos) * block_size).y - _get_visual_min_y(item_root)
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

func place_structure(origin_grid: Vector3i, structure_id: String, rotation_degrees: int) -> void:
	if _library == null or not _library.has_block(structure_id) or not _library.is_structure(structure_id):
		return
	var rotation := wrapi(rotation_degrees, 0, 360)
	var cells := get_structure_cells(origin_grid, structure_id, rotation)
	for cell in cells:
		if _placed.has(cell) or _placed_items.has(cell) or has_structure(cell):
			return

	var scene_path := _library.get_scene_path(structure_id)
	if scene_path == "":
		return
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_warning("[BlockWorld] Could not load structure scene: %s" % scene_path)
		return

	var structure := packed.instantiate() as Node3D
	if structure == null:
		return
	structure.name = "Structure_%s_%d_%d_%d" % [structure_id, origin_grid.x, origin_grid.y, origin_grid.z]
	add_child(structure)
	structure.global_position = _get_structure_world_position(origin_grid, structure_id, rotation)
	structure.rotation_degrees.y = float(rotation)
	if structure.has_method("setup"):
		structure.call("setup", origin_grid, structure_id, _library.get_behavior_id(structure_id))
	if _library.is_interactable(structure_id):
		_add_interactable_group_recursive(structure)

	_placed_structures[origin_grid] = {
		"id": structure_id,
		"rotation_degrees": rotation,
		"node": structure,
		"cells": cells,
	}
	for cell in cells:
		_structure_cells[cell] = origin_grid

func remove_structure(origin_grid: Vector3i) -> void:
	var origin := origin_grid
	if not _placed_structures.has(origin) and _structure_cells.has(origin_grid):
		origin = _structure_cells[origin_grid]
	if not _placed_structures.has(origin):
		return
	var data: Dictionary = _placed_structures[origin]
	var structure := data.get("node") as Node
	if structure != null and is_instance_valid(structure):
		if structure.has_method("unregister"):
			structure.call("unregister")
		structure.queue_free()
	var cells: Array = data.get("cells", [])
	for cell in cells:
		_structure_cells.erase(cell)
	_placed_structures.erase(origin)

func has_structure(grid_pos: Vector3i) -> bool:
	return _structure_cells.has(grid_pos)

func get_structure_cells(origin_grid: Vector3i, structure_id: String, rotation_degrees: int) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	if _library == null or not _library.has_block(structure_id):
		return cells
	var size := _get_rotated_structure_size(structure_id, rotation_degrees)
	for x in range(size.x):
		for y in range(size.y):
			for z in range(size.z):
				cells.append(origin_grid + Vector3i(x, y, z))
	return cells

func _get_rotated_structure_size(structure_id: String, rotation_degrees: int) -> Vector3i:
	var size := _library.get_grid_size(structure_id)
	var rot := wrapi(rotation_degrees, 0, 360)
	if rot == 90 or rot == 270:
		return Vector3i(size.z, size.y, size.x)
	return size

func _get_structure_world_position(origin_grid: Vector3i, structure_id: String, rotation_degrees: int) -> Vector3:
	var size := _get_rotated_structure_size(structure_id, rotation_degrees)
	return Vector3(origin_grid) * block_size + Vector3(size) * block_size * 0.5

func get_item_id(grid_pos: Vector3i) -> String:
	var origin := _get_item_origin_for_grid(grid_pos)
	if not _placed_items.has(origin):
		return ""
	var data: Dictionary = _placed_items[origin]
	return str(data.get("id", ""))

func _get_item_origin_for_grid(grid_pos: Vector3i) -> Vector3i:
	if _placed_items.has(grid_pos):
		return grid_pos
	for origin in _placed_items.keys():
		if _item_occupies_grid(origin, grid_pos):
			return origin
	return grid_pos

func _get_item_origin_for_node(node: Node) -> Vector3i:
	for origin in _placed_items.keys():
		var data: Dictionary = _placed_items[origin]
		var item := data.get("node") as Node
		var cursor := node
		while cursor != null:
			if cursor == item:
				return origin
			cursor = cursor.get_parent()
	return Vector3i(2147483647, 2147483647, 2147483647)

func _item_occupies_grid(origin_grid: Vector3i, grid_pos: Vector3i) -> bool:
	var data: Dictionary = _placed_items.get(origin_grid, {})
	var item_id := str(data.get("id", ""))
	var rotation := int(data.get("rotation_degrees", 0))
	var size := _get_rotated_item_size(item_id, rotation)
	var inside_x := grid_pos.x >= origin_grid.x and grid_pos.x < origin_grid.x + size.x
	var inside_y := grid_pos.y >= origin_grid.y and grid_pos.y < origin_grid.y + size.y
	var inside_z := grid_pos.z >= origin_grid.z and grid_pos.z < origin_grid.z + size.z
	return inside_x and inside_y and inside_z

func _get_rotated_item_size(item_id: String, rotation_degrees: int) -> Vector3i:
	if _library == null or item_id == "":
		return Vector3i.ONE
	var size := _library.get_grid_size(item_id)
	var rot := wrapi(rotation_degrees, 0, 360)
	if rot == 90 or rot == 270:
		return Vector3i(size.z, size.y, size.x)
	return size

func _add_interactable_group_recursive(node: Node) -> void:
	if node is Area3D:
		node.add_to_group("interactable")
	for child in node.get_children():
		_add_interactable_group_recursive(child)

func _spawn_entity(grid_pos: Vector3i, block_id: String) -> void:
	var behavior := _library.get_behavior_id(block_id)
	match behavior:
		"smart_lamp":
			var lamp := Node3D.new()
			lamp.name = "SmartLamp_%d_%d_%d" % [grid_pos.x, grid_pos.y, grid_pos.z]
			lamp.set_script(SMART_LAMP_SCRIPT)
			lamp.position = grid_to_local(grid_pos)
			add_child(lamp)
			lamp.setup(grid_pos)
			_entities[grid_pos] = lamp
