extends Node3D
class_name Interactable3D

@export var interaction_id: String = ""
@export var prompt_text: String = "Press E"
@export var enabled: bool = true

func activate(player: Node) -> void:
	pass
