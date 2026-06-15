extends Node
class_name WorldGenerator

## Seeded procedural terrain generator for BlockWorld.
## Generates a 100x100 Minecraft-style terrain by default, using BlockWorld's
## grid so placement, raycasts, and block collision continue to work normally.

@export var seed: int = 42
@export var world_size: Vector2i = Vector2i(100, 100)
@export var block_world_path: NodePath
@export var generate_on_ready: bool = false
@export var center_on_origin: bool = true

const MIN_HEIGHT: int = 3
const MAX_HEIGHT: int = 8
const NOISE_FREQUENCY: float = 0.05
const NOISE_OCTAVES: int = 3
const GRASS_BLOCK_ID: String = "grass"
const DIRT_BLOCK_ID: String = "dirt"
const STONE_BLOCK_ID: String = "stone"
const TERRAIN_SURFACE_Y: float = 0.0
const TERRAIN_CACHE_PATH := "user://runtime/terrain_cache.json"
const TERRAIN_CACHE_VERSION := 2
const AABB_OVERLAP_EPSILON: float = 0.01

var _block_world: BlockWorld
var _generated_positions: Array[Vector3i] = []
var _existing_aabbs: Array[AABB] = []

func _ready() -> void:
	if generate_on_ready:
		generate()

func generate() -> void:
	_resolve_block_world()
	if _block_world == null:
		push_warning("[WorldGenerator] BlockWorld not found at path: %s" % str(block_world_path))
		return

	_clear_previous_generation()
	_collect_existing_aabbs()
	if _load_terrain_cache():
		return

	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = NOISE_FREQUENCY
	noise.fractal_octaves = NOISE_OCTAVES

	var half_size := Vector2i(world_size.x / 2, world_size.y / 2)
	var total_blocks := 0
	var previous_block_collision := _block_world.create_block_collision
	_block_world.set_block_collision_enabled(false)
	for local_x in range(world_size.x):
		for local_z in range(world_size.y):
			var grid_x := local_x - half_size.x if center_on_origin else local_x
			var grid_z := local_z - half_size.y if center_on_origin else local_z
			var column_height := _get_column_height(noise, grid_x, grid_z)
			var dirt_depth := _get_dirt_depth(noise, grid_x, grid_z)
			var base_y := _get_column_base_y(column_height)

			for y_offset in range(column_height):
				var y := base_y + y_offset
				var grid_pos := Vector3i(grid_x, y, grid_z)
				if _block_intersects_existing_aabb(grid_pos):
					continue
				var block_id := _get_block_id_for_layer(y, column_height, dirt_depth)
				_block_world.place_block(grid_pos, block_id)
				if _block_world.has_block(grid_pos):
					_generated_positions.append(grid_pos)
					total_blocks += 1
	_block_world.set_block_collision_enabled(previous_block_collision)
	_save_terrain_cache()

	print("[WorldGenerator] Generated %d terrain blocks across %dx%d columns with shared per-block terrain collision (seed=%d)." % [total_blocks, world_size.x, world_size.y, seed])

func _load_terrain_cache() -> bool:
	if not FileAccess.file_exists(TERRAIN_CACHE_PATH):
		return false

	var file := FileAccess.open(TERRAIN_CACHE_PATH, FileAccess.READ)
	if file == null:
		push_warning("[WorldGenerator] Could not open terrain cache: %s" % TERRAIN_CACHE_PATH)
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_warning("[WorldGenerator] Terrain cache is invalid JSON, regenerating.")
		return false

	var cache: Dictionary = parsed
	if not _is_cache_metadata_valid(cache):
		return false

	var blocks_value = cache.get("blocks", [])
	if not (blocks_value is Array):
		push_warning("[WorldGenerator] Terrain cache blocks field is not an array, regenerating.")
		return false
	var blocks: Array = blocks_value
	if blocks.is_empty():
		push_warning("[WorldGenerator] Terrain cache has no blocks, regenerating.")
		return false

	var previous_block_collision := _block_world.create_block_collision
	_block_world.set_block_collision_enabled(false)
	var total_blocks := 0
	for block in blocks:
		if not (block is Dictionary):
			continue
		var grid_pos := Vector3i(int(block.get("x", 0)), int(block.get("y", 0)), int(block.get("z", 0)))
		var block_id := str(block.get("id", ""))
		if block_id == "":
			continue
		_block_world.place_block(grid_pos, block_id)
		if _block_world.has_block(grid_pos):
			_generated_positions.append(grid_pos)
			total_blocks += 1
	_block_world.set_block_collision_enabled(previous_block_collision)

	print("[WorldGenerator] Loaded %d cached terrain blocks from %s (seed=%d)." % [total_blocks, TERRAIN_CACHE_PATH, seed])
	return true

func _save_terrain_cache() -> void:
	var blocks: Array = []
	blocks.resize(_generated_positions.size())
	for i in range(_generated_positions.size()):
		var grid_pos := _generated_positions[i]
		blocks[i] = {
			"x": grid_pos.x,
			"y": grid_pos.y,
			"z": grid_pos.z,
			"id": _block_world.get_block_id(grid_pos),
		}

	var cache := {
		"version": TERRAIN_CACHE_VERSION,
		"seed": seed,
		"world_size": [world_size.x, world_size.y],
		"center_on_origin": center_on_origin,
		"block_size": _block_world.block_size,
		"min_height": MIN_HEIGHT,
		"max_height": MAX_HEIGHT,
		"noise_frequency": NOISE_FREQUENCY,
		"noise_octaves": NOISE_OCTAVES,
		"terrain_surface_y": TERRAIN_SURFACE_Y,
		"existing_aabb_signature": _get_existing_aabb_signature(),
		"blocks": blocks,
	}

	var cache_dir := TERRAIN_CACHE_PATH.get_base_dir()
	var absolute_cache_dir := ProjectSettings.globalize_path(cache_dir)
	var dir_result := DirAccess.make_dir_recursive_absolute(absolute_cache_dir)
	if dir_result != OK:
		push_warning("[WorldGenerator] Could not create terrain cache directory: %s" % cache_dir)
		return

	var file := FileAccess.open(TERRAIN_CACHE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[WorldGenerator] Could not write terrain cache: %s" % TERRAIN_CACHE_PATH)
		return
	file.store_string(JSON.stringify(cache))
	file = null
	if not FileAccess.file_exists(TERRAIN_CACHE_PATH):
		push_warning("[WorldGenerator] Terrain cache write did not create readable file: %s" % TERRAIN_CACHE_PATH)
		return
	print("[WorldGenerator] Saved terrain cache to %s (%d blocks)." % [TERRAIN_CACHE_PATH, blocks.size()])

func _is_cache_metadata_valid(cache: Dictionary) -> bool:
	if int(cache.get("version", -1)) != TERRAIN_CACHE_VERSION:
		return false
	if int(cache.get("seed", -1)) != seed:
		return false
	var cached_world_size_value = cache.get("world_size", [])
	if not (cached_world_size_value is Array):
		return false
	var cached_world_size: Array = cached_world_size_value
	if cached_world_size.size() != 2:
		return false
	if int(cached_world_size[0]) != world_size.x or int(cached_world_size[1]) != world_size.y:
		return false
	if bool(cache.get("center_on_origin", true)) != center_on_origin:
		return false
	if not is_equal_approx(float(cache.get("block_size", 0.0)), _block_world.block_size):
		return false
	if int(cache.get("min_height", -1)) != MIN_HEIGHT or int(cache.get("max_height", -1)) != MAX_HEIGHT:
		return false
	if not is_equal_approx(float(cache.get("noise_frequency", -1.0)), NOISE_FREQUENCY):
		return false
	if int(cache.get("noise_octaves", -1)) != NOISE_OCTAVES:
		return false
	if not is_equal_approx(float(cache.get("terrain_surface_y", -99999.0)), TERRAIN_SURFACE_Y):
		return false
	if cache.get("existing_aabb_signature", []) != _get_existing_aabb_signature():
		return false
	return cache.has("blocks")

func _get_existing_aabb_signature() -> Array:
	var signature: Array = []
	for existing_aabb in _existing_aabbs:
		signature.append([
			_round_cache_float(existing_aabb.position.x),
			_round_cache_float(existing_aabb.position.y),
			_round_cache_float(existing_aabb.position.z),
			_round_cache_float(existing_aabb.size.x),
			_round_cache_float(existing_aabb.size.y),
			_round_cache_float(existing_aabb.size.z),
		])
	return signature

func _round_cache_float(value: float) -> int:
	return roundi(value * 1000.0)

func _resolve_block_world() -> void:
	_block_world = get_node_or_null(block_world_path) as BlockWorld

func _clear_previous_generation() -> void:
	if _block_world == null:
		_generated_positions.clear()
		return
	for grid_pos in _generated_positions:
		if _block_world.has_block(grid_pos):
			_block_world.remove_block(grid_pos)
	_generated_positions.clear()

func _collect_existing_aabbs() -> void:
	_existing_aabbs.clear()
	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	_collect_existing_aabbs_recursive(root)

func _collect_existing_aabbs_recursive(node: Node) -> void:
	if node.is_queued_for_deletion():
		return
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			_existing_aabbs.append(mesh_instance.mesh.get_aabb() * mesh_instance.global_transform)
	elif node is CSGBox3D:
		var box := node as CSGBox3D
		_existing_aabbs.append(AABB(-box.size * 0.5, box.size) * box.global_transform)
	elif node is CSGMesh3D:
		var csg_mesh := node as CSGMesh3D
		if csg_mesh.mesh != null:
			_existing_aabbs.append(csg_mesh.mesh.get_aabb() * csg_mesh.global_transform)
	elif node is CSGSphere3D:
		var sphere := node as CSGSphere3D
		var diameter := sphere.radius * 2.0
		_existing_aabbs.append(AABB(Vector3.ONE * -sphere.radius, Vector3.ONE * diameter) * sphere.global_transform)
	elif node is CSGCylinder3D:
		var cylinder := node as CSGCylinder3D
		var cylinder_size := Vector3(cylinder.radius * 2.0, cylinder.height, cylinder.radius * 2.0)
		_existing_aabbs.append(AABB(-cylinder_size * 0.5, cylinder_size) * cylinder.global_transform)
	elif node is CSGPolygon3D:
		var polygon := node as CSGPolygon3D
		var polygon_aabb := _get_csg_polygon_local_aabb(polygon)
		if polygon_aabb.size != Vector3.ZERO:
			_existing_aabbs.append(polygon_aabb * polygon.global_transform)
	elif node is CSGTorus3D:
		var torus := node as CSGTorus3D
		var outer_radius := maxf(torus.outer_radius, torus.inner_radius)
		var torus_size := Vector3(outer_radius * 2.0, outer_radius * 2.0, outer_radius * 2.0)
		_existing_aabbs.append(AABB(-torus_size * 0.5, torus_size) * torus.global_transform)
	elif node is CSGCombiner3D:
		var combiner_aabb := _get_combined_child_aabb(node)
		if combiner_aabb.size != Vector3.ZERO:
			_existing_aabbs.append(combiner_aabb)
	elif node is CSGPrimitive3D:
		var primitive_aabb := _get_generic_csg_primitive_aabb(node as CSGPrimitive3D)
		if primitive_aabb.size != Vector3.ZERO:
			_existing_aabbs.append(primitive_aabb)

	for child in node.get_children():
		_collect_existing_aabbs_recursive(child)

func _get_csg_polygon_local_aabb(polygon: CSGPolygon3D) -> AABB:
	if polygon.polygon.is_empty():
		return AABB()
	var bounds_min := polygon.polygon[0]
	var bounds_max := polygon.polygon[0]
	for point in polygon.polygon:
		bounds_min.x = minf(bounds_min.x, point.x)
		bounds_min.y = minf(bounds_min.y, point.y)
		bounds_max.x = maxf(bounds_max.x, point.x)
		bounds_max.y = maxf(bounds_max.y, point.y)
	var depth := polygon.depth
	return AABB(
		Vector3(bounds_min.x, bounds_min.y, -depth * 0.5),
		Vector3(bounds_max.x - bounds_min.x, bounds_max.y - bounds_min.y, depth)
	)

func _get_combined_child_aabb(node: Node) -> AABB:
	var combined := AABB()
	var has_aabb := false
	for child in node.get_children():
		var child_aabb := _get_node_aabb(child)
		if child_aabb.size == Vector3.ZERO:
			continue
		if has_aabb:
			combined = combined.merge(child_aabb)
		else:
			combined = child_aabb
			has_aabb = true
	return combined if has_aabb else AABB()

func _get_generic_csg_primitive_aabb(primitive: CSGPrimitive3D) -> AABB:
	# All concrete CSG primitives are handled above. Keep a conservative fallback for
	# any future/custom CSGPrimitive3D without known sizing properties.
	return AABB(primitive.global_position, Vector3.ZERO)

func _get_node_aabb(node: Node) -> AABB:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		return mesh_instance.mesh.get_aabb() * mesh_instance.global_transform if mesh_instance.mesh != null else AABB()
	if node is CSGBox3D:
		var box := node as CSGBox3D
		return AABB(-box.size * 0.5, box.size) * box.global_transform
	if node is CSGMesh3D:
		var csg_mesh := node as CSGMesh3D
		return csg_mesh.mesh.get_aabb() * csg_mesh.global_transform if csg_mesh.mesh != null else AABB()
	if node is CSGSphere3D:
		var sphere := node as CSGSphere3D
		var diameter := sphere.radius * 2.0
		return AABB(Vector3.ONE * -sphere.radius, Vector3.ONE * diameter) * sphere.global_transform
	if node is CSGCylinder3D:
		var cylinder := node as CSGCylinder3D
		var cylinder_size := Vector3(cylinder.radius * 2.0, cylinder.height, cylinder.radius * 2.0)
		return AABB(-cylinder_size * 0.5, cylinder_size) * cylinder.global_transform
	if node is CSGPolygon3D:
		var polygon := node as CSGPolygon3D
		return _get_csg_polygon_local_aabb(polygon) * polygon.global_transform
	if node is CSGTorus3D:
		var torus := node as CSGTorus3D
		var outer_radius := maxf(torus.outer_radius, torus.inner_radius)
		var torus_size := Vector3(outer_radius * 2.0, outer_radius * 2.0, outer_radius * 2.0)
		return AABB(-torus_size * 0.5, torus_size) * torus.global_transform
	return AABB()

func _block_intersects_existing_aabb(grid_pos: Vector3i) -> bool:
	var block_size := _block_world.block_size if _block_world != null else 0.5
	var block_world_pos := _block_world.grid_to_world(grid_pos)
	var block_aabb := AABB(
		block_world_pos - Vector3.ONE * (block_size * 0.5),
		Vector3.ONE * block_size
	)
	for existing_aabb in _existing_aabbs:
		if _aabbs_have_physical_overlap(block_aabb, existing_aabb):
			return true
	return false

func _aabbs_have_physical_overlap(a: AABB, b: AABB) -> bool:
	# Use strict, meaningful overlap on all three axes so terrain is skipped only
	# for blocks that would physically intersect an object. A block below, beside,
	# merely touching, or grazing a slightly oversized visual AABB is still placed,
	# preventing whole-column gaps around houses/structures.
	var overlap_x: float = minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x)
	var overlap_y: float = minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y)
	var overlap_z: float = minf(a.end.z, b.end.z) - maxf(a.position.z, b.position.z)
	return (
		overlap_x > AABB_OVERLAP_EPSILON
		and overlap_y > AABB_OVERLAP_EPSILON
		and overlap_z > AABB_OVERLAP_EPSILON
	)

func _get_column_height(noise: FastNoiseLite, grid_x: int, grid_z: int) -> int:
	var raw_noise := noise.get_noise_2d(float(grid_x), float(grid_z))
	var normalized := (raw_noise + 1.0) * 0.5
	return roundi(lerpf(float(MIN_HEIGHT), float(MAX_HEIGHT), normalized))

func _get_dirt_depth(noise: FastNoiseLite, grid_x: int, grid_z: int) -> int:
	var raw_noise := noise.get_noise_2d(float(grid_x + 1024), float(grid_z - 1024))
	return 2 + int(raw_noise > 0.0)

func _get_column_base_y(column_height: int) -> int:
	# BlockWorld grid positions identify cube cells. With block_size=0.5, grid y=-1
	# spans -0.5..0.0, so making that the top grass cell keeps the terrain surface
	# flush with the room floor at world y=0.
	var block_size := _block_world.block_size if _block_world != null else 0.5
	var top_grid_y := roundi(TERRAIN_SURFACE_Y / block_size) - 1
	return top_grid_y - column_height + 1

func _get_block_id_for_layer(y: int, column_height: int, dirt_depth: int) -> String:
	var top_y := _get_column_base_y(column_height) + column_height - 1
	if y == top_y:
		return GRASS_BLOCK_ID
	if y >= top_y - dirt_depth:
		return DIRT_BLOCK_ID
	return STONE_BLOCK_ID
