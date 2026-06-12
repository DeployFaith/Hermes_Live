extends Node3D
class_name DeskPCController

const DESKTOP_PREVIEW_SCENE := preload("res://scenes/desktop_preview.tscn")

@export var computer_id: String = "main_pc"
@export var prompt_text: String = "Press E to use PC"
@export var screen_size := Vector2(0.8, 0.5)
@export var viewport_size := Vector2i(800, 450)

@onready var screen_mesh: MeshInstance3D = $MonitorScreen
@onready var desktop_viewport: SubViewport = $DesktopViewport

func _ready() -> void:
	add_to_group("interactable")
	_setup_viewport()
	_setup_screen_mesh()
	_setup_interaction_collision()

func _setup_viewport() -> void:
	desktop_viewport.size = viewport_size
	desktop_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	desktop_viewport.transparent_bg = false
	if desktop_viewport.get_child_count() == 0:
		var preview := DESKTOP_PREVIEW_SCENE.instantiate()
		desktop_viewport.add_child(preview)

func _setup_screen_mesh() -> void:
	var plane := PlaneMesh.new()
	plane.size = screen_size
	screen_mesh.mesh = plane
	screen_mesh.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = desktop_viewport.get_texture()
	material.emission_enabled = true
	material.emission_texture = desktop_viewport.get_texture()
	material.emission_energy_multiplier = 1.15
	screen_mesh.material_override = material

func _setup_interaction_collision() -> void:
	if has_node("InteractionArea"):
		return
	var area := Area3D.new()
	area.name = "InteractionArea"
	area.add_to_group("interactable")
	area.collision_layer = 1
	area.collision_mask = 1
	# Center on the monitor screen position
	area.position = screen_mesh.position
	add_child(area)
	var shape := CollisionShape3D.new()
	shape.name = "InteractionShape"
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 4.0, 2.2)
	shape.shape = box
	area.add_child(shape)
