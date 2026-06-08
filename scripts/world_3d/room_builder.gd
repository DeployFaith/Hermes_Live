extends Node3D
class_name RoomBuilder3D

const ROOM_SIZE := 8.0
const ROOM_HEIGHT := 3.0
const WALL_THICKNESS := 0.2

var _floor_material := _make_material(Color(0.08, 0.08, 0.09, 1.0), 0.75)
var _wall_material := _make_material(Color(0.14, 0.14, 0.16, 1.0), 0.7)
var _desk_material := _make_material(Color(0.24, 0.16, 0.10, 1.0), 0.65)
var _metal_material := _make_material(Color(0.05, 0.05, 0.06, 1.0), 0.45)

var _ceiling_light: OmniLight3D
var _ceiling_light_fixture: CSGBox3D
var _desk_light: OmniLight3D
var _ceiling_light_energy_on: float = 0.4
var _desk_light_energy_on: float = 1.7

func _ready() -> void:
	_build_room()
	_build_desk()
	_build_window()
	_build_bed()
	_build_shelf()
	_build_floor_details()
	_build_ceiling_light()
	_build_wall_decor()
	_build_desk_items()
	_build_door()
	_build_lighting()
	_register_devices()
	_connect_device_signals()

func _build_room() -> void:
	_add_csg_box("Floor", Vector3(ROOM_SIZE, WALL_THICKNESS, ROOM_SIZE), Vector3(0.0, 0.0, 0.0), _floor_material)
	_add_csg_box("Ceiling", Vector3(ROOM_SIZE, WALL_THICKNESS, ROOM_SIZE), Vector3(0.0, ROOM_HEIGHT, 0.0), _floor_material)

	_add_csg_box("BackWall", Vector3(ROOM_SIZE, ROOM_HEIGHT, WALL_THICKNESS), Vector3(0.0, ROOM_HEIGHT * 0.5, -ROOM_SIZE * 0.5), _wall_material)
	_add_csg_box("FrontWall", Vector3(ROOM_SIZE, ROOM_HEIGHT, WALL_THICKNESS), Vector3(0.0, ROOM_HEIGHT * 0.5, ROOM_SIZE * 0.5), _wall_material)
	_add_csg_box("LeftWall", Vector3(WALL_THICKNESS, ROOM_HEIGHT, ROOM_SIZE), Vector3(-ROOM_SIZE * 0.5, ROOM_HEIGHT * 0.5, 0.0), _wall_material)
	_add_csg_box("RightWall", Vector3(WALL_THICKNESS, ROOM_HEIGHT, ROOM_SIZE), Vector3(ROOM_SIZE * 0.5, ROOM_HEIGHT * 0.5, 0.0), _wall_material)

func _build_desk() -> void:
	var desk_origin := Vector3(0.0, 0.0, -1.55)
	_add_csg_box("Desktop", Vector3(2.0, 0.05, 1.0), desk_origin + Vector3(0.0, 0.75, 0.0), _desk_material)

	var leg_size := Vector3(0.08, 0.75, 0.08)
	for x in [-0.9, 0.9]:
		for z in [-0.4, 0.4]:
			_add_csg_box("DeskLeg", leg_size, desk_origin + Vector3(x, 0.375, z), _desk_material)

	_add_csg_box("MonitorStand", Vector3(0.14, 0.55, 0.14), desk_origin + Vector3(0.0, 1.05, -0.05), _metal_material)
	_add_csg_box("MonitorBase", Vector3(0.45, 0.04, 0.30), desk_origin + Vector3(0.0, 0.80, 0.02), _metal_material)

func _build_window() -> void:
	var glass_color := Color(0.6, 0.7, 0.9, 1.0)
	var recess_material := _make_material(Color(0.035, 0.04, 0.055, 1.0), 0.8)
	var glass_material := _make_emissive_material(glass_color, 0.3, 0.35)

	_add_csg_box("WindowRecess", Vector3(0.3, 1.2, 1.5), Vector3(-3.9, 1.5, -1.0), recess_material, false)

	var glass := MeshInstance3D.new()
	glass.name = "WindowGlass"
	var glass_mesh := PlaneMesh.new()
	glass_mesh.size = Vector2(1.5, 1.2)
	glass.mesh = glass_mesh
	glass.material_override = glass_material
	glass.position = Vector3(-3.83, 1.5, -1.0)
	glass.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	add_child(glass)

	_add_csg_box("WindowFrameTop", Vector3(0.08, 0.06, 1.62), Vector3(-3.78, 2.13, -1.0), _metal_material, false)
	_add_csg_box("WindowFrameBottom", Vector3(0.08, 0.06, 1.62), Vector3(-3.78, 0.87, -1.0), _metal_material, false)
	_add_csg_box("WindowFrameLeft", Vector3(0.08, 1.26, 0.06), Vector3(-3.78, 1.5, -1.78), _metal_material, false)
	_add_csg_box("WindowFrameRight", Vector3(0.08, 1.26, 0.06), Vector3(-3.78, 1.5, -0.22), _metal_material, false)

	var window_light := OmniLight3D.new()
	window_light.name = "WindowCoolLight"
	window_light.position = Vector3(-3.5, 1.5, -1.0)
	window_light.light_color = glass_color
	window_light.light_energy = 0.3
	window_light.omni_range = 5.0
	add_child(window_light)

func _build_bed() -> void:
	var mattress_material := _make_material(Color(0.35, 0.35, 0.4, 1.0), 0.8)
	var pillow_material := _make_material(Color(0.85, 0.85, 0.9, 1.0), 0.7)
	var blanket_material := _make_material(Color(0.15, 0.15, 0.25, 1.0), 0.85)

	# Bed against right wall, long axis along Z (depth)
	var bed_x := 2.5
	var bed_z := 0.5
	_add_csg_box("BedFrame", Vector3(1.2, 0.35, 2.0), Vector3(bed_x, 0.175, bed_z), _desk_material)
	_add_csg_box("BedMattress", Vector3(1.1, 0.08, 1.9), Vector3(bed_x, 0.39, bed_z), mattress_material)
	# Pillow at the head end (negative Z, toward back wall)
	_add_csg_box("BedPillow", Vector3(0.5, 0.1, 0.3), Vector3(bed_x, 0.48, bed_z - 0.75), pillow_material)
	# Blanket covering the body area, aligned with bed
	_add_csg_box("BedBlanket", Vector3(0.9, 0.04, 1.4), Vector3(bed_x, 0.46, bed_z + 0.2), blanket_material)

func _build_shelf() -> void:
	var shelf_position := Vector3(2.0, 0.9, -3.8)
	_add_csg_box("BookcaseFrame", Vector3(1.2, 1.8, 0.35), shelf_position, _wall_material)

	for shelf_y in [0.4, 0.9, 1.4]:
		_add_csg_box("BookcaseDivider", Vector3(1.1, 0.03, 0.3), Vector3(2.0, shelf_y, -3.58), _desk_material)

	var book_specs := [
		{"pos": Vector3(1.55, 0.535, -3.42), "size": Vector3(0.10, 0.24, 0.2), "color": Color(0.35, 0.06, 0.05, 1.0)},
		{"pos": Vector3(1.67, 0.56, -3.42), "size": Vector3(0.12, 0.29, 0.2), "color": Color(0.06, 0.10, 0.24, 1.0)},
		{"pos": Vector3(1.80, 0.53, -3.42), "size": Vector3(0.09, 0.23, 0.2), "color": Color(0.08, 0.22, 0.12, 1.0)},
		{"pos": Vector3(2.20, 1.035, -3.42), "size": Vector3(0.14, 0.24, 0.2), "color": Color(0.28, 0.17, 0.08, 1.0)},
		{"pos": Vector3(2.36, 1.06, -3.42), "size": Vector3(0.10, 0.29, 0.2), "color": Color(0.22, 0.22, 0.23, 1.0)},
		{"pos": Vector3(1.62, 1.545, -3.42), "size": Vector3(0.15, 0.26, 0.2), "color": Color(0.12, 0.16, 0.28, 1.0)},
		{"pos": Vector3(1.80, 1.525, -3.42), "size": Vector3(0.11, 0.22, 0.2), "color": Color(0.23, 0.08, 0.10, 1.0)},
		{"pos": Vector3(1.93, 1.55, -3.42), "size": Vector3(0.08, 0.27, 0.2), "color": Color(0.10, 0.22, 0.16, 1.0)}
	]
	for book in book_specs:
		_add_csg_box("ShelfBook", book["size"], book["pos"], _make_material(book["color"], 0.75))

func _build_floor_details() -> void:
	var rug_material := _make_material(Color(0.25, 0.08, 0.08, 1.0), 0.9)
	_add_csg_box("DeskRug", Vector3(2.5, 0.02, 2.0), Vector3(0.0, 0.01, -1.0), rug_material, false)
	_add_csg_box("TrashCan", Vector3(0.2, 0.35, 0.2), Vector3(-1.5, 0.175, -2.5), _metal_material)

func _build_ceiling_light() -> void:
	_ceiling_light_fixture = CSGBox3D.new()
	_ceiling_light_fixture.name = "CeilingLightFixture"
	_ceiling_light_fixture.size = Vector3(0.6, 0.05, 0.6)
	_ceiling_light_fixture.position = Vector3(0.0, 2.97, 1.0)
	_ceiling_light_fixture.material = _metal_material
	add_child(_ceiling_light_fixture)

	_ceiling_light = OmniLight3D.new()
	_ceiling_light.name = "CeilingWarmLight"
	_ceiling_light.position = Vector3(0.0, 2.85, 1.0)
	_ceiling_light.light_color = Color(1.0, 0.9, 0.7, 1.0)
	_ceiling_light.light_energy = _ceiling_light_energy_on
	_ceiling_light.omni_range = 6.0
	add_child(_ceiling_light)

func _build_wall_decor() -> void:
	var frame_material := _make_material(Color(0.15, 0.1, 0.06, 1.0), 0.7)
	var canvas_material := _make_material(Color(0.2, 0.25, 0.3, 1.0), 0.85)
	_add_csg_box("BackWallPictureFrame", Vector3(0.5, 0.7, 0.03), Vector3(-1.5, 1.8, -3.85), frame_material, false)
	_add_csg_box("BackWallPictureCanvas", Vector3(0.4, 0.6, 0.01), Vector3(-1.5, 1.8, -3.825), canvas_material, false)

func _build_desk_items() -> void:
	var mug_material := _make_material(Color(0.9, 0.9, 0.9, 1.0), 0.65)
	var phone_material := _make_material(Color(0.05, 0.05, 0.06, 1.0), 0.35)
	var paper_material := _make_material(Color(0.95, 0.95, 0.92, 1.0), 0.8)

	_add_csg_box("CoffeeMug", Vector3(0.08, 0.12, 0.08), Vector3(0.6, 0.82, -1.3), mug_material, false)
	_add_csg_box("Phone", Vector3(0.07, 0.01, 0.14), Vector3(-0.5, 0.78, -1.4), phone_material, false)
	_add_csg_box("DeskPaperA", Vector3(0.2, 0.005, 0.28), Vector3(0.3, 0.78, -1.2), paper_material, false)
	_add_csg_box("DeskPaperB", Vector3(0.2, 0.005, 0.28), Vector3(0.43, 0.785, -1.08), paper_material, false)
	_add_csg_box("DeskPaperC", Vector3(0.2, 0.005, 0.28), Vector3(0.18, 0.79, -1.35), paper_material, false)

func _build_door() -> void:
	# The hallway connects directly to the room at the front wall. Keep this
	# intentionally empty so no room-side door panel, frame, handle, or
	# interaction area overlaps the hallway entrance.
	pass

func _build_lighting() -> void:
	_desk_light = OmniLight3D.new()
	_desk_light.name = "DeskOmniLight"
	_desk_light.position = Vector3(0.0, 2.25, -1.35)
	_desk_light.light_color = Color(1.0, 0.82, 0.62, 1.0)
	_desk_light.light_energy = _desk_light_energy_on
	_desk_light.omni_range = 4.0
	add_child(_desk_light)

	var ambient_light := DirectionalLight3D.new()
	ambient_light.name = "DimDirectionalLight"
	ambient_light.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	ambient_light.light_color = Color(0.42, 0.48, 0.62, 1.0)
	ambient_light.light_energy = 0.18
	add_child(ambient_light)

func _register_devices() -> void:
	var controller := get_node_or_null("/root/HomeDeviceController")
	if controller == null:
		push_warning("[RoomBuilder] HomeDeviceController autoload NOT FOUND")
		return
	# Check if already registered (state may have been set by a previous scene visit)
	var existing_state: Dictionary = controller.call("get_device_state", "ceiling_light")
	if existing_state.is_empty():
		controller.call("register_device", "ceiling_light", "light", {"is_on": true, "color": "white"}, self)
		print("[RoomBuilder] Registered ceiling_light with default state (on, white)")
	else:
		controller.call("register_device", "ceiling_light", "light", existing_state, self)
		_apply_ceiling_light_state(existing_state)
		print("[RoomBuilder] Restored ceiling_light state: %s" % existing_state)

func _connect_device_signals() -> void:
	var controller := get_node_or_null("/root/HomeDeviceController")
	if controller != null and controller.has_signal("device_state_changed"):
		if not controller.device_state_changed.is_connected(_on_device_state_changed):
			controller.device_state_changed.connect(_on_device_state_changed)

func _on_device_state_changed(device_id: String, new_state: Dictionary) -> void:
	if device_id == "ceiling_light":
		_apply_ceiling_light_state(new_state)

func _apply_ceiling_light_state(state: Dictionary) -> void:
	var is_on: bool = bool(state.get("is_on", true))
	var color_name: String = str(state.get("color", "white"))
	# Get the actual color from HomeDeviceController
	var light_color: Color = Color(1.0, 0.9, 0.7)  # default warm white
	var controller := get_node_or_null("/root/HomeDeviceController")
	if controller != null and controller.has_method("get_color_value"):
		light_color = controller.call("get_color_value", color_name)
	# Control ceiling light
	if _ceiling_light != null:
		_ceiling_light.light_energy = _ceiling_light_energy_on if is_on else 0.0
		_ceiling_light.light_color = light_color
	# Control desk light (main room illumination)
	if _desk_light != null:
		_desk_light.light_energy = _desk_light_energy_on if is_on else 0.0
		_desk_light.light_color = light_color
	# Dim the fixture emissive to match
	if _ceiling_light_fixture != null:
		var fixture_mat: StandardMaterial3D = _metal_material.duplicate()
		if is_on:
			fixture_mat.emission_enabled = true
			fixture_mat.emission = light_color
			fixture_mat.emission_energy_multiplier = 0.15
		_ceiling_light_fixture.material = fixture_mat

func _add_csg_box(node_name: String, size: Vector3, position: Vector3, material: StandardMaterial3D, use_collision: bool = true) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.name = node_name
	box.size = size
	box.position = position
	box.material = material
	box.use_collision = use_collision
	add_child(box)

	if use_collision:
		var body := StaticBody3D.new()
		body.name = "%sStaticBody" % node_name
		body.position = position
		add_child(body)

		var shape := CollisionShape3D.new()
		shape.name = "%sCollisionShape" % node_name
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)

	return box

static func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

static func _make_emissive_material(color: Color, energy: float, roughness: float) -> StandardMaterial3D:
	var material := _make_material(color, roughness)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
