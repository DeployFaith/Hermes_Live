extends Node3D
class_name PropScatterer

## Lightweight scatter pass for simple low-poly trees and rocks.

@export var terrain_path: NodePath
@export var seed: int = 42
@export var rock_count: int = 30
@export var tree_count: int = 20
@export var minimum_distance: float = 5.0
@export var spawn_clear_radius: float = 8.0
@export var generate_on_ready: bool = true

const MAX_ATTEMPTS_PER_PROP := 80
const TREE_SLOPE_LIMIT := 24.0
const ROCK_SLOPE_LIMIT := 42.0

var _terrain: Node
var _rng := RandomNumberGenerator.new()
var _occupied_points: Array[Vector2] = []
var _tree_trunk_material: StandardMaterial3D
var _tree_canopy_material: StandardMaterial3D
var _rock_material: StandardMaterial3D

func _ready() -> void:
	if generate_on_ready:
		call_deferred("scatter")

func scatter() -> void:
	_clear_generated_children()
	_terrain = get_node_or_null(terrain_path)
	if _terrain == null:
		push_warning("[PropScatterer] ProceduralTerrain not found at path: %s" % str(terrain_path))
		return
	_rng.seed = seed
	_occupied_points.clear()
	_create_materials()
	_scatter_trees()
	_scatter_rocks()
	print("[PropScatterer] Scattered %d trees and %d rocks (requested)." % [tree_count, rock_count])

func _scatter_trees() -> void:
	for i in range(tree_count):
		var point: Variant = _find_valid_point(true)
		if point == null:
			continue
		_add_tree(point as Vector3)

func _scatter_rocks() -> void:
	for i in range(rock_count):
		var point: Variant = _find_valid_point(false)
		if point == null:
			continue
		_add_rock(point as Vector3)

func _find_valid_point(tree: bool) -> Variant:
	var half_size: float = float(_terrain.get("terrain_size")) * 0.5
	var margin: float = 6.0
	for attempt in range(MAX_ATTEMPTS_PER_PROP):
		var x: float = _rng.randf_range(-half_size + margin, half_size - margin) + _terrain.global_position.x
		var z: float = _rng.randf_range(-half_size + margin, half_size - margin) + _terrain.global_position.z
		var point := Vector2(x, z)
		if point.length() < spawn_clear_radius:
			continue
		if not _terrain.is_inside_terrain(x, z):
			continue
		if not _has_minimum_distance(point):
			continue
		var height: float = float(_terrain.call("get_height_at", x, z))
		if height <= float(_terrain.get("water_height")) + 1.0:
			continue
		var slope: float = float(_terrain.call("get_slope_degrees_at", x, z))
		var zone: String = str(_terrain.call("get_zone_at", x, z))
		if tree:
			if zone != "grass" or slope > TREE_SLOPE_LIMIT:
				continue
		else:
			if zone == "sand" or slope > ROCK_SLOPE_LIMIT:
				continue
		_occupied_points.append(point)
		return Vector3(x, height, z)
	return null

func _has_minimum_distance(point: Vector2) -> bool:
	for occupied in _occupied_points:
		if point.distance_to(occupied) < minimum_distance:
			return false
	return true

func _add_tree(base_position: Vector3) -> void:
	var tree_root := Node3D.new()
	tree_root.name = "Tree"
	add_child(tree_root)
	tree_root.global_position = base_position
	tree_root.rotation_degrees.y = _rng.randf_range(0.0, 360.0)

	var trunk_height := _rng.randf_range(2.0, 3.3)
	var trunk_radius := _rng.randf_range(0.22, 0.34)
	var trunk := MeshInstance3D.new()
	trunk.name = "Trunk"
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = trunk_radius * 0.75
	trunk_mesh.bottom_radius = trunk_radius
	trunk_mesh.height = trunk_height
	trunk_mesh.radial_segments = 6
	trunk_mesh.rings = 1
	trunk.mesh = trunk_mesh
	trunk.material_override = _tree_trunk_material
	trunk.position.y = trunk_height * 0.5
	tree_root.add_child(trunk)

	var canopy := MeshInstance3D.new()
	canopy.name = "Canopy"
	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = _rng.randf_range(1.0, 1.45)
	canopy_mesh.height = canopy_mesh.radius * 1.5
	canopy_mesh.radial_segments = 8
	canopy_mesh.rings = 4
	canopy.mesh = canopy_mesh
	canopy.material_override = _tree_canopy_material
	canopy.position.y = trunk_height + canopy_mesh.height * 0.35
	tree_root.add_child(canopy)

	var body := StaticBody3D.new()
	body.name = "Collision"
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = trunk_radius
	shape.height = trunk_height
	collision.shape = shape
	collision.position.y = trunk_height * 0.5
	body.add_child(collision)
	tree_root.add_child(body)

func _add_rock(base_position: Vector3) -> void:
	var rock_root := Node3D.new()
	rock_root.name = "Rock"
	var scale_value := _rng.randf_range(0.7, 1.7)
	add_child(rock_root)
	rock_root.global_position = base_position
	rock_root.rotation_degrees = Vector3(0.0, _rng.randf_range(0.0, 360.0), 0.0)
	rock_root.scale = Vector3(scale_value * _rng.randf_range(0.9, 1.5), scale_value * _rng.randf_range(0.55, 0.9), scale_value)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "RockMesh"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 1.0, 1.0)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _rock_material
	mesh_instance.position.y = 0.5
	rock_root.add_child(mesh_instance)

	var body := StaticBody3D.new()
	body.name = "Collision"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 1.0, 1.0)
	collision.shape = shape
	collision.position.y = 0.5
	body.add_child(collision)
	rock_root.add_child(body)

func _create_materials() -> void:
	_tree_trunk_material = _make_material(Color(0.38, 0.22, 0.12))
	_tree_canopy_material = _make_material(Color(0.20, 0.42, 0.17))
	_rock_material = _make_material(Color(0.38, 0.36, 0.34))

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	material.roughness = 0.9
	return material

func _clear_generated_children() -> void:
	for child in get_children():
		child.queue_free()
