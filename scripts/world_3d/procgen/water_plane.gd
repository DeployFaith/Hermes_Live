extends Node3D
class_name WaterPlane

## Simple visual and collision water surface.

@export var water_height: float = 3.0
@export var water_size: float = 300.0
@export var generate_on_ready: bool = true

func _ready() -> void:
	if generate_on_ready:
		generate()

func generate() -> void:
	_clear_generated_children()
	position.y = water_height
	_add_visual_plane()
	_add_collision_plane()

func _add_visual_plane() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "WaterMesh"
	var plane := PlaneMesh.new()
	plane.size = Vector2(water_size, water_size)
	mesh_instance.mesh = plane
	mesh_instance.material_override = _create_water_material()
	add_child(mesh_instance)

func _add_collision_plane() -> void:
	var body := StaticBody3D.new()
	body.name = "WaterCollision"
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(water_size, 0.1, water_size)
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _create_water_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.38, 0.82, 0.45)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.35
	material.metallic = 0.0
	return material

func _clear_generated_children() -> void:
	for child in get_children():
		child.queue_free()
