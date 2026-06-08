class_name HermesStyleBoxFactory
extends RefCounted

func build(computed_style) -> StyleBoxFlat:
	if computed_style == null:
		return null
	if not _has_visual_properties(computed_style):
		return null
	var box := StyleBoxFlat.new()
	box.anti_aliasing = true
	if computed_style.has_property("background-color"):
		box.bg_color = computed_style.get_color("background-color", Color.TRANSPARENT)
	elif computed_style.has_property("background"):
		box.bg_color = computed_style.get_color("background", Color.TRANSPARENT)
	var border_width: int = int(round(computed_style.get_number("border-width", 0.0)))
	if border_width > 0:
		box.border_width_left = border_width
		box.border_width_right = border_width
		box.border_width_top = border_width
		box.border_width_bottom = border_width
	_apply_edge_border_width(box, computed_style, "left", border_width)
	_apply_edge_border_width(box, computed_style, "right", border_width)
	_apply_edge_border_width(box, computed_style, "top", border_width)
	_apply_edge_border_width(box, computed_style, "bottom", border_width)
	if box.border_width_left > 0 or box.border_width_right > 0 or box.border_width_top > 0 or box.border_width_bottom > 0:
		box.border_color = computed_style.get_color("border-color", Color.TRANSPARENT)
	var radius: int = int(round(computed_style.get_number("border-radius", 0.0)))
	if radius > 0:
		box.corner_radius_top_left = radius
		box.corner_radius_top_right = radius
		box.corner_radius_bottom_left = radius
		box.corner_radius_bottom_right = radius
	var padding_default: int = int(round(computed_style.get_number("padding", -1.0)))
	_apply_edge_margin(box, computed_style, "left", padding_default)
	_apply_edge_margin(box, computed_style, "right", padding_default)
	_apply_edge_margin(box, computed_style, "top", padding_default)
	_apply_edge_margin(box, computed_style, "bottom", padding_default)
	return box

func _apply_edge_margin(box: StyleBoxFlat, computed_style, edge: String, padding_default: int) -> void:
	var property_name: String = "padding-" + edge
	var value: int = padding_default
	if computed_style.has_property(property_name):
		value = int(round(computed_style.get_number(property_name, float(padding_default))))
	match edge:
		"left":
			box.content_margin_left = max(value, 0)
		"right":
			box.content_margin_right = max(value, 0)
		"top":
			box.content_margin_top = max(value, 0)
		"bottom":
			box.content_margin_bottom = max(value, 0)

func _apply_edge_border_width(box: StyleBoxFlat, computed_style, edge: String, border_default: int) -> void:
	var value: int = border_default
	for property_name in ["border-" + edge + "-width", "border-width-" + edge]:
		if computed_style.has_property(property_name):
			value = int(round(computed_style.get_number(property_name, float(border_default))))
	match edge:
		"left":
			box.border_width_left = max(value, 0)
		"right":
			box.border_width_right = max(value, 0)
		"top":
			box.border_width_top = max(value, 0)
		"bottom":
			box.border_width_bottom = max(value, 0)

func _has_visual_properties(computed_style) -> bool:
	for property_name in ["background", "background-color", "border-color", "border-width", "border-left-width", "border-right-width", "border-top-width", "border-bottom-width", "border-width-left", "border-width-right", "border-width-top", "border-width-bottom", "border-radius", "padding", "padding-left", "padding-right", "padding-top", "padding-bottom"]:
		if computed_style.has_property(property_name):
			return true
	return false
