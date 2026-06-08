extends Node3D
class_name HallwayBuilder

## Hallway that connects to the room's front wall (z=3.9).
## Builds geometry extending in the +Z direction.

const HALL_LENGTH := 8.0
const HALL_WIDTH := 3.0
const HALL_HEIGHT := 3.0
const WALL_THICKNESS := 0.2
const ROOM_FRONT_Z := 3.9

var _floor_material: StandardMaterial3D
var _wall_material: StandardMaterial3D
var _ceiling_material: StandardMaterial3D
var _door_material: StandardMaterial3D
var _metal_material: StandardMaterial3D
var _hall_door_panel: CSGBox3D
var _hall_door_open: bool = false

func _ready() -> void:
	print("[HallwayBuilder] _ready() called")
	_floor_material = _make_material(Color(0.12, 0.10, 0.08, 1.0), 0.8)
	_wall_material = _make_material(Color(0.08, 0.07, 0.07, 1.0), 0.75)
	_ceiling_material = _make_material(Color(0.06, 0.06, 0.07, 1.0), 0.8)
	_door_material = _make_material(Color(0.25, 0.18, 0.10, 1.0), 0.65)
	_metal_material = _make_material(Color(0.05, 0.05, 0.06, 1.0), 0.45)

	_remove_room_front_wall()
	_build_hallway()
	_build_doors()
	_build_lighting()

func _remove_room_front_wall() -> void:
	print("[HallwayBuilder] _remove_room_front_wall() start")
	# Remove the room's front wall and any original doorway pieces so the
	# hallway entrance is a clean, open passage.
	var room := get_parent().get_node_or_null("Room")
	if room == null:
		return
	var to_remove: Array[Node] = []
	for child in room.get_children():
		var cname: String = child.name
		if "FrontWall" in cname or "DoorPanel" in cname or "DoorFrame" in cname or "DoorHandle" in cname or "DoorInteraction" in cname:
			to_remove.append(child)
	for child in to_remove:
		child.queue_free()

func _build_hallway() -> void:
	print("[HallwayBuilder] _build_hallway() start")
	var start_z := ROOM_FRONT_Z
	var center_z := start_z + HALL_LENGTH * 0.5
	var far_z := start_z + HALL_LENGTH

	# Floor — continuous with room floor
	_add_box("HallFloor", Vector3(HALL_WIDTH, WALL_THICKNESS, HALL_LENGTH), Vector3(0.0, 0.0, center_z), _floor_material)
	# Ceiling
	_add_box("HallCeiling", Vector3(HALL_WIDTH, WALL_THICKNESS, HALL_LENGTH), Vector3(0.0, HALL_HEIGHT, center_z), _ceiling_material)
	# Left wall
	_add_box("HallLeftWall", Vector3(WALL_THICKNESS, HALL_HEIGHT, HALL_LENGTH), Vector3(-HALL_WIDTH * 0.5, HALL_HEIGHT * 0.5, center_z), _wall_material)
	# Right wall
	_add_box("HallRightWall", Vector3(WALL_THICKNESS, HALL_HEIGHT, HALL_LENGTH), Vector3(HALL_WIDTH * 0.5, HALL_HEIGHT * 0.5, center_z), _wall_material)
	# Far wall. Use the CSG collision instead of an extra full-wall StaticBody3D
	# so the visual doorway is also a walkable opening.
	var far_wall := _add_box("HallFarWall", Vector3(HALL_WIDTH, HALL_HEIGHT, WALL_THICKNESS), Vector3(0.0, HALL_HEIGHT * 0.5, far_z), _wall_material, false)
	far_wall.use_collision = true
	# Cut door opening in far wall. This position is local to the far wall,
	# whose origin is at y=1.5, so center the opening at y=1.2 globally.
	var door_hole := CSGBox3D.new()
	door_hole.name = "FarDoorHole"
	door_hole.size = Vector3(1.1, 2.4, 0.5)
	door_hole.position = Vector3(0.0, -0.3, 0.0)
	door_hole.operation = 2  # Subtraction
	door_hole.use_collision = false
	far_wall.add_child(door_hole)

	# Fill walls — connect room side walls to hallway side walls
	# Left fill (room wall at x=-4, hallway wall at x=-1.5)
	_add_box("FillWallLeft", Vector3(2.5, HALL_HEIGHT, WALL_THICKNESS), Vector3(-2.75, HALL_HEIGHT * 0.5, start_z), _wall_material)
	# Right fill (room wall at x=+4, hallway wall at x=+1.5)
	_add_box("FillWallRight", Vector3(2.5, HALL_HEIGHT, WALL_THICKNESS), Vector3(2.75, HALL_HEIGHT * 0.5, start_z), _wall_material)

	# Runner rug (no collision)
	_add_box("HallRug", Vector3(1.2, 0.01, HALL_LENGTH - 1.0), Vector3(0.0, 0.01, center_z), _make_material(Color(0.2, 0.06, 0.06, 1.0), 0.9), false)

func _build_doors() -> void:
	var far_z := ROOM_FRONT_Z + HALL_LENGTH - 0.1
	var door_pos := Vector3(0.0, 0.0, far_z)

	_add_box("HallDoorFrameL", Vector3(0.08, 2.4, 0.1), door_pos + Vector3(-0.45, 1.2, 0.0), _door_material, false)
	_add_box("HallDoorFrameR", Vector3(0.08, 2.4, 0.1), door_pos + Vector3(0.45, 1.2, 0.0), _door_material, false)
	_add_box("HallDoorFrameT", Vector3(0.98, 0.08, 0.1), door_pos + Vector3(0.0, 2.44, 0.0), _door_material, false)
	_hall_door_panel = _add_box("HallDoorPanel", Vector3(0.8, 2.3, 0.06), door_pos + Vector3(0.0, 1.15, -0.02), _door_material, false)
	_hall_door_panel.rotation = Vector3.ZERO
	_add_box("HallDoorHandle", Vector3(0.03, 0.06, 0.06), door_pos + Vector3(0.3, 1.0, -0.06), _metal_material, false)

	# Interaction area for the hallway door
	var area := Area3D.new()
	area.name = "HallDoorArea"
	area.add_to_group("interactable")
	area.collision_layer = 1
	area.collision_mask = 1
	area.position = door_pos + Vector3(0.0, 1.2, 0.0)
	add_child(area)

	var shape := CollisionShape3D.new()
	shape.name = "HallDoorShape"
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 2.4, 1.5)
	shape.shape = box
	area.add_child(shape)

	area.set_meta("door_name", "HallDoor")
	area.set_meta("is_door", true)

func _build_lighting() -> void:
	var start_z := ROOM_FRONT_Z
	for i in range(3):
		var z := start_z + 1.5 + i * 2.5
		var light := OmniLight3D.new()
		light.name = "HallLight_%d" % i
		light.position = Vector3(0.0, HALL_HEIGHT - 0.3, z)
		light.light_color = Color(0.9, 0.85, 0.7, 1.0)
		light.light_energy = 0.7
		light.omni_range = 4.0
		add_child(light)

	# Light near the far door
	var far_light := OmniLight3D.new()
	far_light.name = "HallFarLight"
	far_light.position = Vector3(0.0, HALL_HEIGHT - 0.3, ROOM_FRONT_Z + HALL_LENGTH - 1.0)
	far_light.light_color = Color(0.9, 0.85, 0.7, 1.0)
	far_light.light_energy = 0.4
	far_light.omni_range = 3.0
	add_child(far_light)

func _add_box(box_name: String, size: Vector3, pos: Vector3, material: StandardMaterial3D, collision: bool = true) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.name = box_name
	box.size = size
	box.position = pos
	box.material = material
	box.use_collision = collision
	add_child(box)

	if collision:
		var body := StaticBody3D.new()
		body.name = "%sStaticBody" % box_name
		body.position = pos
		add_child(body)

		var shape := CollisionShape3D.new()
		shape.name = "%sCollisionShape" % box_name
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


