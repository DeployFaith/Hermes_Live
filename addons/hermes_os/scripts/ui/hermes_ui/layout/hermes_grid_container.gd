class_name HermesGridContainer
extends PanelContainer

const BODY_META := "hermes_ui_body"
const HermesGridBody = preload("res://addons/hermes_os/scripts/ui/hermes_ui/layout/hermes_grid_body.gd")

var body = null

func _init() -> void:
	name = "HermesLayoutGrid"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", _transparent_style())
	body = HermesGridBody.new()
	body.name = "HermesLayoutGridBody"
	add_child(body)
	set_meta(BODY_META, body)

func get_body() -> Control:
	return body

func set_gap(value: int) -> void:
	body.set_gap(value)

func set_template_columns_from_text(template_text: String) -> void:
	body.set_template_columns_from_text(template_text)

func _transparent_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_width_left = 0
	box.border_width_right = 0
	box.border_width_top = 0
	box.border_width_bottom = 0
	box.content_margin_left = 0
	box.content_margin_right = 0
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	return box
