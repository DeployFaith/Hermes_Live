extends Node

## Performance-optimized Terrain3D test setup.
## Caches packed textures and generated maps to disk so subsequent loads are fast.

const HEIGHTMAP_SIZE := 513
const REGION_SIZE := 256
const TERRAIN_OFFSET := Vector3(-256.0, 0.0, -256.0)
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

var terrain: Terrain3D
var _generated_heights := PackedFloat32Array()


func _ready() -> void:
	terrain = await create_terrain()
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
	new_terrain.collision_layer = 1
	new_terrain.collision_mask = 1
	new_terrain.collision_mode = Terrain3DCollision.FULL_GAME
	add_child(new_terrain, true)
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
