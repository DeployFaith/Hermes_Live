extends Node
class_name BlockLibrary

## Defines buildable things for the building system.
## Blocks are cube/grid materials. Items are one-cell scene instances.
## Each definition may include: id, display_name, category, color, solid,
## interactable, behavior_id, scene_path, grid_size, texture_path

var _blocks: Dictionary = {}
var _texture_cache: Dictionary = {}

func _ready() -> void:
	_register_default_blocks()

func _register_default_blocks() -> void:
	register_block({
		"id": "stone",
		"display_name": "Stone",
		"category": "block",
		"color": Color(0.55, 0.55, 0.58),
		"roughness": 0.9,
		"solid": true,
		"interactable": false,
		"texture_path": "res://assets/textures/blocks/stone",
	})
	register_block({
		"id": "dirt",
		"display_name": "Dirt",
		"category": "block",
		"color": Color(0.36, 0.22, 0.12),
		"roughness": 0.95,
		"solid": true,
		"interactable": false,
	})
	register_block({
		"id": "wood",
		"display_name": "Wood",
		"category": "block",
		"color": Color(0.65, 0.4, 0.2),
		"roughness": 0.85,
		"solid": true,
		"interactable": false,
		"texture_path": "res://assets/textures/blocks/wood",
	})
	register_block({
		"id": "glass",
		"display_name": "Glass",
		"category": "block",
		"color": Color(0.7, 0.85, 1.0, 0.3),
		"roughness": 0.1,
		"solid": true,
		"interactable": false,
		"transparent": true,
		"texture_path": "res://assets/textures/blocks/glass",
	})
	register_block({
		"id": "smart_lamp",
		"display_name": "Smart Lamp",
		"category": "block",
		"color": Color(1.0, 0.9, 0.55),
		"roughness": 0.5,
		"emissive": true,
		"emission_color": Color(1.0, 0.9, 0.7),
		"emission_energy": 0.45,
		"solid": true,
		"interactable": true,
		"behavior_id": "smart_lamp",
		"texture_path": "res://assets/textures/blocks/smart_lamp",
	})
	register_block({
		"id": "grass",
		"display_name": "Grass",
		"category": "block",
		"color": Color(0.4, 0.6, 0.3),
		"roughness": 0.95,
		"solid": true,
		"interactable": false,
		"texture_path": "res://assets/textures/blocks/grass",
		"per_face_textures": true,
	})

	# Items
	register_block({
		"id": "door",
		"display_name": "Door",
		"category": "item",
		"scene_path": "res://scripts/world_3d/items/door_item.tscn",
		"interactable": true,
		"behavior_id": "door",
	})
	register_block({
		"id": "bed",
		"display_name": "Bed",
		"category": "item",
		"scene_path": "res://scripts/world_3d/items/bed_item.tscn",
		"interactable": true,
		"behavior_id": "bed",
	})
	register_block({
		"id": "computer",
		"display_name": "Computer",
		"category": "item",
		"scene_path": "res://scripts/world_3d/items/computer_item.tscn",
		"interactable": true,
		"behavior_id": "computer",
	})
	register_block({
		"id": "desk_lamp",
		"display_name": "Desk Lamp",
		"category": "item",
		"scene_path": "res://scripts/world_3d/items/desk_lamp_item.tscn",
		"interactable": true,
		"behavior_id": "desk_lamp",
	})

	# Structures
	register_block({
		"id": "small_apartment",
		"display_name": "Small Apartment",
		"category": "structure",
		"scene_path": "res://scripts/world_3d/structures/small_apartment.tscn",
		"grid_size": Vector3i(4, 3, 4),
		"interactable": true,
		"behavior_id": "small_apartment",
	})
	register_block({
		"id": "building_facade",
		"display_name": "Building Facade",
		"category": "structure",
		"scene_path": "res://scripts/world_3d/structures/building_facade.tscn",
		"grid_size": Vector3i(3, 4, 2),
		"interactable": false,
		"behavior_id": "building_facade",
	})

func register_block(def: Dictionary) -> void:
	var id: String = str(def.get("id", ""))
	if id == "":
		return
	if not def.has("category"):
		def["category"] = "block"
	_blocks[id] = def

func get_block(id: String) -> Dictionary:
	return _blocks.get(id, {})

func get_display_name(id: String) -> String:
	return str(_blocks.get(id, {}).get("display_name", id.capitalize()))

func has_block(id: String) -> bool:
	return _blocks.has(id)

func get_category(id: String) -> String:
	return str(_blocks.get(id, {}).get("category", "block"))

func is_item(id: String) -> bool:
	return get_category(id) == "item"

func is_structure(id: String) -> bool:
	return get_category(id) == "structure"

func is_interactable(id: String) -> bool:
	return bool(_blocks.get(id, {}).get("interactable", false))

func get_behavior_id(id: String) -> String:
	return str(_blocks.get(id, {}).get("behavior_id", ""))

func get_scene_path(id: String) -> String:
	return str(_blocks.get(id, {}).get("scene_path", ""))

func get_grid_size(id: String) -> Vector3i:
	var value = _blocks.get(id, {}).get("grid_size", Vector3i.ONE)
	return value if value is Vector3i else Vector3i.ONE

func get_block_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _blocks.keys():
		ids.append(id)
	return ids

func get_texture_path(id: String) -> String:
	return str(_blocks.get(id, {}).get("texture_path", ""))

## Returns true if block has different textures for top/sides/bottom
func has_per_face_textures(id: String) -> bool:
	return bool(_blocks.get(id, {}).get("per_face_textures", false))

## Create materials for per-face textured blocks (grass, logs, etc.)
## Returns array: [top_mat, side_mat, bottom_mat]
func make_face_materials(id: String) -> Array:
	var block := get_block(id)
	if block.is_empty():
		return []

	var texture_path: String = block.get("texture_path", "")
	if texture_path == "":
		return []

	var roughness: float = block.get("roughness", 0.8)
	var top_mat := StandardMaterial3D.new()
	var side_mat := StandardMaterial3D.new()
	var bottom_mat := StandardMaterial3D.new()

	top_mat.roughness = roughness
	side_mat.roughness = roughness
	bottom_mat.roughness = roughness

	var top_tex := _load_texture(texture_path + "/top.png")
	var side_tex := _load_texture(texture_path + "/sides.png")
	var bottom_tex := _load_texture(texture_path + "/bottom.png")

	if top_tex != null:
		top_mat.albedo_texture = top_tex
	else:
		top_mat.albedo_color = block.get("color", Color.WHITE)

	if side_tex != null:
		side_mat.albedo_texture = side_tex
	else:
		side_mat.albedo_color = block.get("color", Color.WHITE)

	if bottom_tex != null:
		bottom_mat.albedo_texture = bottom_tex
	else:
		bottom_mat.albedo_color = block.get("color", Color.WHITE)

	# Transparency
	if block.get("transparent", false):
		for mat in [top_mat, side_mat, bottom_mat]:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Emission
	if block.get("emissive", false):
		for mat in [top_mat, side_mat, bottom_mat]:
			mat.emission_enabled = true
			mat.emission = block.get("emission_color", Color.WHITE)
			mat.emission_energy_multiplier = block.get("emission_energy", 0.5)

	return [top_mat, side_mat, bottom_mat]

## Single material for blocks with same texture on all faces
func make_material(id: String) -> StandardMaterial3D:
	var block := get_block(id)
	if block.is_empty():
		return null

	var mat := StandardMaterial3D.new()
	mat.roughness = block.get("roughness", 0.8)

	# Try to load texture
	var texture_path: String = block.get("texture_path", "")
	if texture_path != "":
		var side_texture := _load_texture(texture_path + "/sides.png")
		if side_texture != null:
			mat.albedo_texture = side_texture
		else:
			mat.albedo_color = block.get("color", Color.WHITE)
	else:
		mat.albedo_color = block.get("color", Color.WHITE)

	# Transparency
	if block.get("transparent", false):
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Emission
	if block.get("emissive", false):
		mat.emission_enabled = true
		mat.emission = block.get("emission_color", Color.WHITE)
		mat.emission_energy_multiplier = block.get("emission_energy", 0.5)

	return mat

func _load_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	if not ResourceLoader.exists(path):
		_texture_cache[path] = null
		return null
	var tex: Texture2D = load(path)
	_texture_cache[path] = tex
	return tex
