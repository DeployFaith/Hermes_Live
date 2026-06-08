class_name HermesFlexContainer
extends PanelContainer

const BODY_META := "hermes_ui_body"

var direction: String = "column"
var body = null

func _init(p_direction: String = "column") -> void:
	direction = p_direction
	name = "HermesFlexContainer"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", _transparent_style())
	_build_body()

func _build_body() -> void:
	body = HBoxContainer.new() if direction == "row" else VBoxContainer.new()
	body.name = "HermesLayoutRowBody" if direction == "row" else "HermesLayoutColumnBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	set_meta(BODY_META, body)

func get_body() -> Control:
	return body

func set_gap(value: int) -> void:
	if body is BoxContainer:
		(body as BoxContainer).add_theme_constant_override("separation", max(value, 0))

func set_main_alignment(value: String) -> void:
	if not (body is BoxContainer):
		return
	match value.strip_edges().to_lower():
		"center":
			(body as BoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
		"end", "right", "bottom":
			(body as BoxContainer).alignment = BoxContainer.ALIGNMENT_END
		_:
			(body as BoxContainer).alignment = BoxContainer.ALIGNMENT_BEGIN

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
