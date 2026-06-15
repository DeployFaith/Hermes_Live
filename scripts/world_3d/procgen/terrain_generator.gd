extends Node3D
class_name ProceduralTerrain

## Stylized low-poly island terrain generated as a flat-shaded mesh.

@export var seed: int = 42
@export var terrain_size: float = 200.0
@export var grid_resolution: int = 128
@export var max_height: float = 25.0
@export var water_height: float = 3.0
@export_range(0.0, 1.0, 0.01) var island_falloff_radius: float = 0.8
@export var noise_frequency: float = 0.008
@export var noise_octaves: int = 5
@export var generate_on_ready: bool = true

const SAND_COLOR := Color(0.85, 0.78, 0.55)
const GRASS_COLOR := Color(0.35, 0.55, 0.25)
const ROCK_COLOR := Color(0.45, 0.42, 0.40)
const SLOPE_ROCK_DEGREES := 30.0
const SAND_HEIGHT_OFFSET := 2.0

var _noise: FastNoiseLite
var _height_samples: PackedFloat32Array = PackedFloat32Array()
var _mesh_instance: MeshInstance3D
var _collision_body: StaticBody3D

func _ready() -> void:
	if generate_on_ready:
		generate()

func generate() -> void:
	_clear_generated_children()
	_setup_noise()
	_generate_height_samples()

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var collision_faces := PackedVector3Array()
	_build_flat_mesh_arrays(vertices, normals, colors, collision_faces)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _create_terrain_material())

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "TerrainMesh"
	_mesh_instance.mesh = mesh
	add_child(_mesh_instance)

	_create_collision(collision_faces)
	print("[ProceduralTerrain] Generated low-poly terrain: size=%.1f resolution=%d seed=%d" % [terrain_size, grid_resolution, seed])

func get_height_at(world_x: float, world_z: float) -> float:
	if _height_samples.is_empty():
		return 0.0
	var half_size := terrain_size * 0.5
	var local_x := clampf(world_x - global_position.x, -half_size, half_size)
	var local_z := clampf(world_z - global_position.z, -half_size, half_size)
	var step := _get_grid_step()
	var gx := (local_x + half_size) / step
	var gz := (local_z + half_size) / step
	var x0 := clampi(floori(gx), 0, grid_resolution - 1)
	var z0 := clampi(floori(gz), 0, grid_resolution - 1)
	var x1 := clampi(x0 + 1, 0, grid_resolution - 1)
	var z1 := clampi(z0 + 1, 0, grid_resolution - 1)
	var tx := gx - float(x0)
	var tz := gz - float(z0)
	var h00 := _get_height_sample(x0, z0)
	var h10 := _get_height_sample(x1, z0)
	var h01 := _get_height_sample(x0, z1)
	var h11 := _get_height_sample(x1, z1)
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz) + global_position.y

func get_slope_degrees_at(world_x: float, world_z: float) -> float:
	var step := maxf(_get_grid_step(), 0.1)
	var h_l := get_height_at(world_x - step, world_z)
	var h_r := get_height_at(world_x + step, world_z)
	var h_d := get_height_at(world_x, world_z - step)
	var h_u := get_height_at(world_x, world_z + step)
	var gradient := Vector2((h_r - h_l) / (step * 2.0), (h_u - h_d) / (step * 2.0)).length()
	return rad_to_deg(atan(gradient))

func get_zone_at(world_x: float, world_z: float) -> String:
	var height := get_height_at(world_x, world_z) - global_position.y
	var slope := get_slope_degrees_at(world_x, world_z)
	return _get_zone_for_height_and_slope(height, slope)

func is_inside_terrain(world_x: float, world_z: float) -> bool:
	var half_size := terrain_size * 0.5
	var local := Vector2(world_x - global_position.x, world_z - global_position.z)
	return absf(local.x) <= half_size and absf(local.y) <= half_size

func _setup_noise() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = noise_frequency
	_noise.fractal_octaves = noise_octaves
	_noise.fractal_gain = 0.5
	_noise.fractal_lacunarity = 2.0

func _generate_height_samples() -> void:
	grid_resolution = maxi(grid_resolution, 2)
	_height_samples.resize(grid_resolution * grid_resolution)
	for z in range(grid_resolution):
		for x in range(grid_resolution):
			_height_samples[_get_sample_index(x, z)] = _calculate_height_for_grid(x, z)

func _calculate_height_for_grid(x: int, z: int) -> float:
	var half_size := terrain_size * 0.5
	var step := _get_grid_step()
	var world_x := -half_size + float(x) * step
	var world_z := -half_size + float(z) * step
	var raw := _noise.get_noise_2d(world_x, world_z)
	var normalized := clampf((raw + 1.0) * 0.5, 0.0, 1.0)
	var shaped := pow(normalized, 1.35)
	var land_height := water_height + shaped * max_height
	var edge_depth := water_height - 5.0
	var radius := Vector2(world_x, world_z).length() / half_size
	var falloff_start := clampf(island_falloff_radius, 0.0, 0.99)
	var falloff := smoothstep(falloff_start, 1.0, radius)
	var height := lerpf(land_height, edge_depth, falloff)
	return height

func _build_flat_mesh_arrays(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, collision_faces: PackedVector3Array) -> void:
	for z in range(grid_resolution - 1):
		for x in range(grid_resolution - 1):
			var v00 := _get_vertex_for_grid(x, z)
			var v10 := _get_vertex_for_grid(x + 1, z)
			var v01 := _get_vertex_for_grid(x, z + 1)
			var v11 := _get_vertex_for_grid(x + 1, z + 1)
			_add_triangle(vertices, normals, colors, collision_faces, v00, v11, v10)
			_add_triangle(vertices, normals, colors, collision_faces, v00, v01, v11)

func _add_triangle(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, collision_faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.y < 0.0:
		var temp := b
		b = c
		c = temp
		normal = (b - a).cross(c - a).normalized()
	var slope_degrees := rad_to_deg(acos(clampf(normal.dot(Vector3.UP), -1.0, 1.0)))
	var average_height := (a.y + b.y + c.y) / 3.0
	var color := _get_color_for_height_and_slope(average_height, slope_degrees)
	vertices.append_array([a, b, c])
	normals.append_array([normal, normal, normal])
	colors.append_array([color, color, color])
	collision_faces.append_array([a, b, c])

func _get_vertex_for_grid(x: int, z: int) -> Vector3:
	var half_size := terrain_size * 0.5
	var step := _get_grid_step()
	return Vector3(-half_size + float(x) * step, _get_height_sample(x, z), -half_size + float(z) * step)

func _get_height_sample(x: int, z: int) -> float:
	return _height_samples[_get_sample_index(clampi(x, 0, grid_resolution - 1), clampi(z, 0, grid_resolution - 1))]

func _get_sample_index(x: int, z: int) -> int:
	return z * grid_resolution + x

func _get_grid_step() -> float:
	return terrain_size / float(maxi(grid_resolution - 1, 1))

func _get_color_for_height_and_slope(height: float, slope_degrees: float) -> Color:
	var zone := _get_zone_for_height_and_slope(height, slope_degrees)
	if zone == "sand":
		return SAND_COLOR
	if zone == "rock":
		return ROCK_COLOR
	return GRASS_COLOR

func _get_zone_for_height_and_slope(height: float, slope_degrees: float) -> String:
	if height < water_height + SAND_HEIGHT_OFFSET:
		return "sand"
	if slope_degrees > SLOPE_ROCK_DEGREES or height > water_height + max_height * 0.72:
		return "rock"
	return "grass"

func _create_terrain_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	material.roughness = 0.9
	return material

func _create_collision(collision_faces: PackedVector3Array) -> void:
	_collision_body = StaticBody3D.new()
	_collision_body.name = "TerrainCollision"
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(collision_faces)
	collision_shape.shape = shape
	_collision_body.add_child(collision_shape)
	add_child(_collision_body)

func _clear_generated_children() -> void:
	for child in get_children():
		child.queue_free()
	_mesh_instance = null
	_collision_body = null
