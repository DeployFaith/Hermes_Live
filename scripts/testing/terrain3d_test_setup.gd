extends Node

## Performance-optimized Terrain3D test setup.
## Caches packed textures and generated maps to disk so subsequent loads are fast.

const HEIGHTMAP_SIZE := 2049
const REGION_SIZE := 1024
const TERRAIN_OFFSET := Vector3(-1024.0, 0.0, -1024.0)
const HEIGHT_SCALE := 20.0
const BUILD_PAD_POSITION_XZ := Vector2(0.0, 0.0)

const TEXTURE_BASE := "res://assets/textures/terrain/"
const CACHE_DIR := "user://terrain_cache/"
const TEXTURE_CACHE_VERSION := "matte_v4_beach_shelf"
const TERRAIN_MIN_HEIGHT := -8.0
const GRASS_ID := 0
const DIRT_ID := 1
const ROCK_ID := 2
const SAND_ID := 3

const TREE_ASSETS := [
	{"id": 0, "name": "KayKit Tree 1", "path": "res://assets/models/nature/trees/Tree_1_A_Color1.gltf"},
	{"id": 1, "name": "KayKit Tree 2", "path": "res://assets/models/nature/trees/Tree_2_A_Color1.gltf"},
	{"id": 2, "name": "KayKit Tree 3", "path": "res://assets/models/nature/trees/Tree_3_A_Color1.gltf"},
]
const BUSH_ASSET := {"id": 3, "name": "KayKit Bush", "path": "res://assets/models/nature/bushes/Bush_1_A_Color1.gltf"}
const FOLIAGE_SEED := 424242
const TREE_SPACING := 30.0
const BUSH_SPACING := 15.0
const MAX_FOLIAGE_SLOPE_DEGREES := 25.0
const SPAWN_CLEAR_RADIUS := 10.0
const BUILD_PAD_CLEAR_RADIUS := 42.0
const WATERLINE_HEIGHT := 1.0

var terrain: Terrain3D
var _generated_heights := PackedFloat32Array()


func _ready() -> void:
	terrain = create_terrain()
	_position_player_on_terrain()
	_position_build_pad_on_terrain()


func create_terrain() -> Terrain3D:
	var t_start := Time.get_ticks_msec()

	var grass_ta := _load_or_cache_texture("Grass", "grass", 0.32, 0.18)
	var dirt_ta := _load_or_cache_texture("Dirt / Beach Soil", "dirt", 0.28, 0.23)
	var rock_ta := _load_or_cache_texture("Rock", "rock", 0.22, 0.12)
	var sand_ta := _load_or_cache_texture("Sand / Beach", "sand", 0.28, 0.23)

	var t_textures := Time.get_ticks_msec()
	print("[Terrain3DTest] Textures loaded in %dms" % (t_textures - t_start))

	var new_terrain := Terrain3D.new()
	new_terrain.name = "Terrain3D"
	new_terrain.region_size = REGION_SIZE
	new_terrain.vertex_spacing = 1.0
	add_child(new_terrain, true)
	# Terrain3D ignores collision property assignments before it enters the scene tree.
	# Apply collision settings after add_child(), and after data import below, so Full Game
	# collision is built from populated regions instead of leaving the default Dynamic Game mode.
	# Control map handles all texture zones — no auto shader
	new_terrain.material.world_background = Terrain3DMaterial.NONE
	new_terrain.material.auto_shader = false

	new_terrain.assets = Terrain3DAssets.new()
	new_terrain.assets.set_texture(GRASS_ID, grass_ta)
	new_terrain.assets.set_texture(DIRT_ID, dirt_ta)
	new_terrain.assets.set_texture(ROCK_ID, rock_ta)
	new_terrain.assets.set_texture(SAND_ID, sand_ta)

	var terrain_images := _load_or_cache_maps()
	new_terrain.data.import_images([terrain_images[0], terrain_images[1], null], TERRAIN_OFFSET, TERRAIN_MIN_HEIGHT, HEIGHT_SCALE)
	new_terrain.collision_layer = 1
	new_terrain.collision_mask = 1
	new_terrain.collision_shape_size = 32
	new_terrain.collision_mode = Terrain3DCollision.FULL_GAME
	_setup_foliage(new_terrain)

	var t_total := Time.get_ticks_msec()
	print("[Terrain3DTest] Total terrain setup: %dms" % (t_total - t_start))
	return new_terrain


# --- Texture loading with caching ---

func _load_or_cache_texture(asset_name: String, prefix: String, uv_scale: float, detiling: float) -> Terrain3DTextureAsset:
	var cache_alb := CACHE_DIR + prefix + "_" + TEXTURE_CACHE_VERSION + "_albedo_packed.png"
	var cache_nrm := CACHE_DIR + prefix + "_" + TEXTURE_CACHE_VERSION + "_normal_packed.png"

	var alb_img: Image
	var nrm_img: Image

	if FileAccess.file_exists(cache_alb) and FileAccess.file_exists(cache_nrm):
		alb_img = _load_image(cache_alb)
		nrm_img = _load_image(cache_nrm)
		alb_img.generate_mipmaps()
		nrm_img.generate_mipmaps()
		print("[Terrain3DTest] Loaded cached texture: %s" % prefix)
	else:
		alb_img = _load_image(TEXTURE_BASE + prefix + "_albedo.png")
		nrm_img = _load_image(TEXTURE_BASE + prefix + "_normal.png")
		var rgh_img := _load_image(TEXTURE_BASE + prefix + "_roughness.png")

		alb_img.convert(Image.FORMAT_RGBA8)
		nrm_img.convert(Image.FORMAT_RGBA8)
		rgh_img.convert(Image.FORMAT_RF)

		# Pack roughness/luminance into alpha channels
		for x in range(alb_img.get_width()):
			for y in range(alb_img.get_height()):
				var source_roughness: float = rgh_img.get_pixel(x, y).r
				var matte_roughness: float = clamp(maxf(source_roughness, 0.86), 0.86, 1.0)
				var alb: Color = alb_img.get_pixel(x, y)
				alb.a = clamp(alb.get_luminance() * 1.35, 0.05, 1.0)
				alb_img.set_pixel(x, y, alb)
				var nrm: Color = nrm_img.get_pixel(x, y)
				nrm.a = matte_roughness
				nrm_img.set_pixel(x, y, nrm)

		alb_img.generate_mipmaps()
		nrm_img.generate_mipmaps()

		# Save cached versions
		_ensure_cache_dir()
		alb_img.save_png(ProjectSettings.globalize_path(cache_alb))
		nrm_img.save_png(ProjectSettings.globalize_path(cache_nrm))
		print("[Terrain3DTest] Packed and cached texture: %s" % prefix)

	var ta := Terrain3DTextureAsset.new()
	ta.name = asset_name
	ta.albedo_texture = ImageTexture.create_from_image(alb_img)
	ta.normal_texture = ImageTexture.create_from_image(nrm_img)
	ta.uv_scale = uv_scale
	ta.detiling_rotation = detiling
	ta.normal_depth = 0.85
	ta.ao_strength = 0.75
	ta.roughness = 0.12
	return ta


# --- Terrain3D foliage instancing ---

func _setup_foliage(target_terrain: Terrain3D) -> void:
	if target_terrain == null or target_terrain.assets == null or target_terrain.get_instancer() == null:
		return

	var registered_tree_ids: Array[int] = []
	for asset_info: Dictionary in TREE_ASSETS:
		var mesh_asset := _create_foliage_mesh_asset(asset_info)
		if mesh_asset == null:
			continue
		var mesh_id: int = asset_info["id"]
		target_terrain.assets.set_mesh_asset(mesh_id, mesh_asset)
		registered_tree_ids.push_back(mesh_id)

	var bush_mesh_asset := _create_foliage_mesh_asset(BUSH_ASSET)
	var bush_id: int = BUSH_ASSET["id"]
	var has_bushes := bush_mesh_asset != null
	if has_bushes:
		target_terrain.assets.set_mesh_asset(bush_id, bush_mesh_asset)

	if registered_tree_ids.is_empty() and not has_bushes:
		push_warning("[Terrain3DTest] No KayKit foliage scenes loaded; skipping Terrain3D foliage scatter.")
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = FOLIAGE_SEED

	var tree_transforms_by_id: Dictionary = {}
	for mesh_id in registered_tree_ids:
		var empty_transforms: Array[Transform3D] = []
		tree_transforms_by_id[mesh_id] = empty_transforms
	var bush_transforms: Array[Transform3D] = []

	_generate_tree_transforms(target_terrain, registered_tree_ids, tree_transforms_by_id, rng)
	if has_bushes:
		_generate_bush_transforms(target_terrain, bush_transforms, rng)

	var instancer := target_terrain.get_instancer()
	for mesh_id in registered_tree_ids:
		instancer.clear_by_mesh(mesh_id)
		var transforms: Array[Transform3D] = tree_transforms_by_id[mesh_id]
		if not transforms.is_empty():
			instancer.add_transforms(mesh_id, transforms)
			print("[Terrain3DTest] Scattered %d tree instances for mesh id %d" % [transforms.size(), mesh_id])

	if has_bushes:
		instancer.clear_by_mesh(bush_id)
		if not bush_transforms.is_empty():
			instancer.add_transforms(bush_id, bush_transforms)
			print("[Terrain3DTest] Scattered %d bush instances for mesh id %d" % [bush_transforms.size(), bush_id])


func _create_foliage_mesh_asset(asset_info: Dictionary) -> Terrain3DMeshAsset:
	var path: String = asset_info["path"]
	var scene := load(path) as PackedScene
	if scene == null:
		push_warning("[Terrain3DTest] Failed to load foliage scene: %s" % path)
		return null

	var mesh_asset := Terrain3DMeshAsset.new()
	mesh_asset.name = asset_info["name"]
	mesh_asset.id = asset_info["id"]
	mesh_asset.enabled = true
	mesh_asset.set_scene_file(scene)
	mesh_asset.height_offset = 0.0
	mesh_asset.density = 1.0
	mesh_asset.cast_shadows = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mesh_asset


func _generate_tree_transforms(target_terrain: Terrain3D, mesh_ids: Array[int], transforms_by_id: Dictionary, rng: RandomNumberGenerator) -> void:
	if mesh_ids.is_empty():
		return

	var start := TERRAIN_OFFSET.x + TREE_SPACING * 0.5
	var end := TERRAIN_OFFSET.x + float(HEIGHTMAP_SIZE - 1) - TREE_SPACING * 0.5
	var z := start
	while z <= end:
		var x := start
		while x <= end:
			var pos_x := x + rng.randf_range(-TREE_SPACING * 0.35, TREE_SPACING * 0.35)
			var pos_z := z + rng.randf_range(-TREE_SPACING * 0.35, TREE_SPACING * 0.35)
			var pos := Vector3(pos_x, 0.0, pos_z)
			if _is_valid_tree_position(pos) and rng.randf() < 0.76:
				pos.y = target_terrain.data.get_height(pos)
				var mesh_id := mesh_ids[rng.randi_range(0, mesh_ids.size() - 1)]
				var transforms: Array[Transform3D] = transforms_by_id[mesh_id]
				transforms.push_back(_random_foliage_transform(pos, rng.randf_range(0.5, 1.6), rng))
			x += TREE_SPACING
		z += TREE_SPACING


func _generate_bush_transforms(target_terrain: Terrain3D, transforms: Array[Transform3D], rng: RandomNumberGenerator) -> void:
	var start := TERRAIN_OFFSET.x + BUSH_SPACING * 0.5
	var end := TERRAIN_OFFSET.x + float(HEIGHTMAP_SIZE - 1) - BUSH_SPACING * 0.5
	var z := start
	while z <= end:
		var x := start
		while x <= end:
			var pos_x := x + rng.randf_range(-BUSH_SPACING * 0.38, BUSH_SPACING * 0.38)
			var pos_z := z + rng.randf_range(-BUSH_SPACING * 0.38, BUSH_SPACING * 0.38)
			var pos := Vector3(pos_x, 0.0, pos_z)
			if _is_valid_bush_position(pos) and rng.randf() < 0.34:
				pos.y = target_terrain.data.get_height(pos)
				transforms.push_back(_random_foliage_transform(pos, rng.randf_range(0.5, 1.4), rng))
			x += BUSH_SPACING
		z += BUSH_SPACING


func _random_foliage_transform(pos: Vector3, scale: float, rng: RandomNumberGenerator) -> Transform3D:
	var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
	basis = basis.scaled(Vector3.ONE * scale)
	return Transform3D(basis, pos)


func _is_valid_tree_position(pos: Vector3) -> bool:
	if not _is_valid_foliage_position(pos):
		return false
	var map_pos := _world_to_heightmap(pos)
	var height := _get_generated_height(map_pos.x, map_pos.y)
	var slope := _slope_at(map_pos.x, map_pos.y)
	if height < 3.0:
		return false
	if _is_rock_zone(height, slope):
		return false
	return true


func _is_valid_bush_position(pos: Vector3) -> bool:
	if not _is_valid_foliage_position(pos):
		return false
	var map_pos := _world_to_heightmap(pos)
	var height := _get_generated_height(map_pos.x, map_pos.y)
	var slope := _slope_at(map_pos.x, map_pos.y)
	if height < 2.4:
		return false
	if slope > tan(deg_to_rad(18.0)):
		return false
	if _is_rock_zone(height, slope):
		return false
	return true


func _is_valid_foliage_position(pos: Vector3) -> bool:
	var xz := Vector2(pos.x, pos.z)
	if xz.length() < SPAWN_CLEAR_RADIUS:
		return false
	if xz.distance_to(BUILD_PAD_POSITION_XZ) < BUILD_PAD_CLEAR_RADIUS:
		return false
	if not _is_inside_heightmap(pos):
		return false
	var map_pos := _world_to_heightmap(pos)
	var height := _get_generated_height(map_pos.x, map_pos.y)
	if height <= WATERLINE_HEIGHT:
		return false
	if _slope_at(map_pos.x, map_pos.y) > tan(deg_to_rad(MAX_FOLIAGE_SLOPE_DEGREES)):
		return false
	return true


func _is_rock_zone(height: float, slope: float) -> bool:
	return slope > 0.30 or (height > 7.4 and slope > 0.14)


func _is_inside_heightmap(pos: Vector3) -> bool:
	var max_world := TERRAIN_OFFSET.x + float(HEIGHTMAP_SIZE - 1)
	return pos.x >= TERRAIN_OFFSET.x and pos.x <= max_world and pos.z >= TERRAIN_OFFSET.z and pos.z <= max_world


func _world_to_heightmap(pos: Vector3) -> Vector2i:
	return Vector2i(
		clampi(roundi(pos.x - TERRAIN_OFFSET.x), 0, HEIGHTMAP_SIZE - 1),
		clampi(roundi(pos.z - TERRAIN_OFFSET.z), 0, HEIGHTMAP_SIZE - 1)
	)


# --- Heightmap/control map generation ---
# Control map uses bit-packed floats destroyed by PNG. Always regenerate both.

func _load_or_cache_maps() -> Array[Image]:
	print("[Terrain3DTest] Generating heightmap + control map...")
	var heightmap := _generate_island_maps()
	var control_map := _generate_control_map(heightmap)
	return [heightmap, control_map]


func _generate_island_maps() -> Image:
	_generated_heights = PackedFloat32Array()
	_generated_heights.resize(HEIGHTMAP_SIZE * HEIGHTMAP_SIZE)

	var detail_noise := FastNoiseLite.new()
	detail_noise.seed = 73013
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail_noise.frequency = 0.012
	detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	detail_noise.fractal_octaves = 4
	detail_noise.fractal_lacunarity = 2.1
	detail_noise.fractal_gain = 0.48

	var broad_noise := FastNoiseLite.new()
	broad_noise.seed = 18371
	broad_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	broad_noise.frequency = 0.0045
	broad_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	broad_noise.fractal_octaves = 3

	var center := Vector2((HEIGHTMAP_SIZE - 1) * 0.5, (HEIGHTMAP_SIZE - 1) * 0.5)
	var max_radius := HEIGHTMAP_SIZE * 0.48

	# Pass 1: generate heights
	for x in range(HEIGHTMAP_SIZE):
		for y in range(HEIGHTMAP_SIZE):
			var p := Vector2(float(x), float(y))
			var dist := p.distance_to(center) / max_radius
			var detail := detail_noise.get_noise_2d(float(x), float(y))
			var broad := broad_noise.get_noise_2d(float(x), float(y))
			var land := 1.0 - smoothstep(0.50, 0.88, dist)
			var shore_drop := smoothstep(0.55, 0.95, dist)
			var edge_hills := smoothstep(0.42, 0.60, dist) * (1.0 - smoothstep(0.80, 0.98, dist))
			var central_pad := 1.0 - smoothstep(0.0, 0.23, dist)
			var rolling := 4.2 + broad * 1.35 + detail * 0.75
			rolling += edge_hills * (2.8 + maxf(0.0, broad) * 2.8 + maxf(0.0, detail) * 1.6)
			rolling -= shore_drop * 2.4
			rolling = lerpf(rolling, 4.15 + detail * 0.08, central_pad)
			var height := lerpf(-0.5, rolling, land)

			# Shape the shoreline as a gradual wade-in instead of a ledge.
			# The profile eases from dry beach into knee-deep water over a broad band,
			# then continues to the seabed past the visible shoreline.
			var beach_approach_height := 1.45 + broad * 0.10 + detail * 0.10
			var beach_top_height := 0.95 + broad * 0.04 + detail * 0.05
			var shoreline_height := -0.55 + broad * 0.03 + detail * 0.03
			var wade_shelf_height := -1.25 + broad * 0.04 + detail * 0.05
			var shallow_water_height := -3.25 + broad * 0.08 + detail * 0.08
			var seabed_height := -6.25 + broad * 0.12 + detail * 0.12
			var beach_approach := smoothstep(0.66, 0.76, dist)
			var beach_top := smoothstep(0.74, 0.82, dist)
			var shoreline := smoothstep(0.82, 0.88, dist)
			var wade_shelf := smoothstep(0.88, 0.93, dist)
			var shallow_water := smoothstep(0.93, 1.00, dist)
			height = lerpf(height, beach_approach_height, beach_approach)
			height = lerpf(height, beach_top_height, beach_top)
			height = lerpf(height, shoreline_height, shoreline)
			height = lerpf(height, wade_shelf_height, wade_shelf)
			height = lerpf(height, shallow_water_height, shallow_water)
			# Beyond the playable shore band, keep collision well below the water surface
			# so the player visibly sinks/swims instead of standing on a near-surface shelf.
			height = lerpf(height, seabed_height, smoothstep(1.00, 1.08, dist))

			_set_generated_height(x, y, height)

	# Pass 2: write heightmap only (control map generated separately)
	var heightmap := Image.create_empty(HEIGHTMAP_SIZE, HEIGHTMAP_SIZE, false, Image.FORMAT_RF)
	for x in range(HEIGHTMAP_SIZE):
		for y in range(HEIGHTMAP_SIZE):
			var height := _get_generated_height(x, y)
			heightmap.set_pixel(x, y, Color((height - TERRAIN_MIN_HEIGHT) / HEIGHT_SCALE, 0.0, 0.0, 1.0))
	return heightmap



func _generate_control_map(_heightmap: Image) -> Image:
	var controlmap := Image.create_empty(HEIGHTMAP_SIZE, HEIGHTMAP_SIZE, false, Image.FORMAT_RF)
	for x in range(HEIGHTMAP_SIZE):
		for y in range(HEIGHTMAP_SIZE):
			var height := _get_generated_height(x, y)
			controlmap.set_pixel(x, y, Color(_control_value_for_point(x, y, height), 0.0, 0.0, 1.0))
	return controlmap

func _control_value_for_point(x: int, y: int, height: float) -> float:
	var center := Vector2((HEIGHTMAP_SIZE - 1) * 0.5, (HEIGHTMAP_SIZE - 1) * 0.5)
	var dist := Vector2(float(x), float(y)).distance_to(center) / (HEIGHTMAP_SIZE * 0.48)
	var slope := _slope_at(x, y)
	# Center build pad area — dirt
	if dist < 0.18:
		return _encode_control(DIRT_ID, GRASS_ID, 225)
	# Beach / tidal zone — pure sand near water level
	if height < 1.0:
		return _encode_control(SAND_ID, DIRT_ID, 0)
	# Occasional tide reach — sand transitioning into dirt
	if height < 2.5:
		return _encode_control(SAND_ID, DIRT_ID, 120)
	# Above normal tide — dirt transitioning into grass
	if height < 4.0:
		return _encode_control(DIRT_ID, GRASS_ID, 120)
	# Steep slopes or high peaks — rock
	if slope > 0.30 or (height > 7.4 and slope > 0.14):
		return _encode_control(ROCK_ID, DIRT_ID, 52)
	if slope > 0.16 or height > 6.8:
		return _encode_control(DIRT_ID, ROCK_ID, 82)
	# Default grass
	return _encode_control(DIRT_ID, GRASS_ID, 245)


func _encode_control(base_id: int, overlay_id: int, blend: int, hole: bool = false) -> float:
	var packed: int = ((base_id & 0x1F) << 27) | ((overlay_id & 0x1F) << 22) | ((clampi(blend, 0, 255) & 0xFF) << 14)
	if hole:
		packed |= 1 << 2
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_u32(0, packed)
	return bytes.decode_float(0)


func _slope_at(x: int, y: int) -> float:
	var xl: int = maxi(x - 1, 0)
	var xr: int = mini(x + 1, HEIGHTMAP_SIZE - 1)
	var yd: int = maxi(y - 1, 0)
	var yu: int = mini(y + 1, HEIGHTMAP_SIZE - 1)
	var dx := absf(_get_generated_height(xr, y) - _get_generated_height(xl, y)) * 0.5
	var dy := absf(_get_generated_height(x, yu) - _get_generated_height(x, yd)) * 0.5
	return sqrt(dx * dx + dy * dy)


func _set_generated_height(x: int, y: int, height: float) -> void:
	_generated_heights[y * HEIGHTMAP_SIZE + x] = height


func _get_generated_height(x: int, y: int) -> float:
	return _generated_heights[y * HEIGHTMAP_SIZE + x]


# --- Utilities ---

func _load_image(path: String) -> Image:
	var img := Image.new()
	var err := img.load(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Failed to load image: %s" % path)
	return img


func _ensure_cache_dir() -> void:
	var abs_path := ProjectSettings.globalize_path(CACHE_DIR)
	DirAccess.make_dir_recursive_absolute(abs_path)


func _position_player_on_terrain() -> void:
	var player := get_parent().get_node_or_null("Player") as CharacterBody3D
	if player == null:
		return
	var start := Vector3(100.0, 0.0, 0.0)
	start.y = terrain.data.get_height(start) + 2.5
	player.global_position = start


func _position_build_pad_on_terrain() -> void:
	var build_pad := get_parent().get_node_or_null("BuildPad") as Node3D
	if build_pad == null:
		return
	var pad_pos := Vector3(BUILD_PAD_POSITION_XZ.x, 0.0, BUILD_PAD_POSITION_XZ.y)
	pad_pos.y = terrain.data.get_height(pad_pos) + 0.12
	build_pad.global_position = pad_pos
