class_name HermesScrollView
extends PanelContainer

const BODY_META := "hermes_ui_body"

var scroll = null
var body = null

func _init() -> void:
	name = "HermesLayoutScrollView"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", _transparent_style())
	scroll = ScrollContainer.new()
	scroll.name = "HermesLayoutScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body = VBoxContainer.new()
	body.name = "HermesLayoutScrollBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	add_child(scroll)
	set_meta(BODY_META, body)

func get_body() -> Control:
	return body

func get_scroll_container() -> ScrollContainer:
	return scroll

func set_gap(value: int) -> void:
	body.add_theme_constant_override("separation", max(value, 0))

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
