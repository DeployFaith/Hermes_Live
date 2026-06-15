extends Node3D
class_name BuildPad

## Flat collision platform for the existing grid-based BlockWorld build layer.

@export var terrain_path: NodePath
@export var pad_size: Vector3 = Vector3(20.0, 0.2, 20.0)
@export var pad_position: Vector3 = Vector3(0.0, 0.0, 0.0)
@export var generate_on_ready: bool = true

var _terrain: Node
var _mesh_instance: MeshInstance3D
var _collision_body: StaticBody3D

func _ready() -> void:
	if generate_on_ready:
		call_deferred("generate")

func generate() -> void:
	_clear_generated_children()
	_terrain = get_node_or_null(terrain_path)
	var adjusted_position := pad_position
	if _terrain != null:
		adjusted_position.y = _get_pad_surface_y() + pad_size.y * 0.5
	else:
		push_warning("[BuildPad] ProceduralTerrain not found at path: %s" % str(terrain_path))
	global_position = adjusted_position
	_add_visual()
	_add_collision()

func contains_world_position(world_position: Vector3) -> bool:
	var local := to_local(world_position)
	return absf(local.x) <= pad_size.x * 0.5 and absf(local.z) <= pad_size.z * 0.5 and local.y >= -pad_size.y * 0.5

func get_top_y() -> float:
	return global_position.y + pad_size.y * 0.5

func _get_pad_surface_y() -> float:
	var highest_y := -INF
	var samples := 5
	for x_index in range(samples):
		for z_index in range(samples):
			var tx := float(x_index) / float(samples - 1)
			var tz := float(z_index) / float(samples - 1)
			var sample_x := pad_position.x + lerpf(-pad_size.x * 0.5, pad_size.x * 0.5, tx)
			var sample_z := pad_position.z + lerpf(-pad_size.z * 0.5, pad_size.z * 0.5, tz)
			highest_y = maxf(highest_y, float(_terrain.call("get_height_at", sample_x, sample_z)))
	return highest_y + 0.05

func _add_visual() -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "BuildPadMesh"
	var mesh := BoxMesh.new()
	mesh.size = pad_size
	_mesh_instance.mesh = mesh
	_mesh_instance.material_override = _create_pad_material()
	add_child(_mesh_instance)

func _add_collision() -> void:
	_collision_body = StaticBody3D.new()
	_collision_body.name = "BuildPadCollision"
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = pad_size
	collision.shape = shape
	_collision_body.add_child(collision)
	add_child(_collision_body)

func _create_pad_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.62, 0.62, 0.58)
	material.roughness = 0.85
	return material

func _clear_generated_children() -> void:
	for child in get_children():
		child.queue_free()
	_mesh_instance = null
	_collision_body = null
