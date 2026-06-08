class_name HermesGridBody
extends Container

var column_specs: Array = []
var gap: int = 0
var fallback_width: int = 600

func _init() -> void:
	name = "HermesGridBody"
	column_specs = [{"mode": "fr", "value": 1.0}, {"mode": "fr", "value": 1.0}]
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func set_gap(value: int) -> void:
	gap = max(value, 0)
	queue_sort()
	queue_redraw()

func set_template_columns_from_text(template_text: String) -> void:
	var parsed: Array = []
	for token in template_text.split(" ", false):
		var clean: String = token.strip_edges()
		if clean == "":
			continue
		if clean.ends_with("px"):
			parsed.append({"mode": "px", "value": float(clean.trim_suffix("px"))})
		elif clean.ends_with("fr"):
			parsed.append({"mode": "fr", "value": max(float(clean.trim_suffix("fr")), 1.0)})
	if not parsed.is_empty():
		column_specs = parsed
	queue_sort()
	queue_redraw()

func get_column_widths() -> Array:
	if column_specs.is_empty():
		return [fallback_width]
	var available_width: float = max(size.x, custom_minimum_size.x, float(fallback_width))
	var fixed_total: float = 0.0
	var fr_total: float = 0.0
	for spec in column_specs:
		if str(spec.get("mode", "")) == "px":
			fixed_total += float(spec.get("value", 0.0))
		else:
			fr_total += float(spec.get("value", 1.0))
	var gaps_total: float = float(max(column_specs.size() - 1, 0) * gap)
	var remaining: float = max(available_width - fixed_total - gaps_total, 0.0)
	var widths: Array = []
	for spec in column_specs:
		if str(spec.get("mode", "")) == "px":
			widths.append(int(round(float(spec.get("value", 0.0)))))
		else:
			var ratio: float = float(spec.get("value", 1.0)) / max(fr_total, 1.0)
			widths.append(int(round(remaining * ratio)))
	return widths

func _get_minimum_size() -> Vector2:
	var widths: Array = get_column_widths()
	var total_width: float = 0.0
	for width_value in widths:
		total_width += float(width_value)
	if widths.size() > 1:
		total_width += float((widths.size() - 1) * gap)
	var children: Array = _control_children()
	var row_count: int = int(ceil(float(children.size()) / max(widths.size(), 1)))
	var total_height: float = 0.0
	for row in range(row_count):
		var row_height: float = 0.0
		for column in range(widths.size()):
			var index: int = row * widths.size() + column
			if index >= children.size():
				break
			var child: Control = children[index] as Control
			row_height = max(row_height, child.get_combined_minimum_size().y)
		if row > 0:
			total_height += gap
		total_height += row_height
	return Vector2(total_width, total_height)

func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_layout_children()

func _layout_children() -> void:
	var widths: Array = get_column_widths()
	var children: Array = _control_children()
	if widths.is_empty() or children.is_empty():
		return
	var y: float = 0.0
	var row_index: int = 0
	while true:
		var start_index: int = row_index * widths.size()
		if start_index >= children.size():
			break
		var row_height: float = 0.0
		for column in range(widths.size()):
			var child_index: int = start_index + column
			if child_index >= children.size():
				break
			var child_min: Vector2 = (children[child_index] as Control).get_combined_minimum_size()
			row_height = max(row_height, child_min.y)
		var x: float = 0.0
		for column in range(widths.size()):
			var child_index2: int = start_index + column
			if child_index2 >= children.size():
				break
			var child_control: Control = children[child_index2] as Control
			fit_child_in_rect(child_control, Rect2(x, y, float(widths[column]), row_height))
			x += float(widths[column]) + gap
		if row_index > 0:
			y += gap
		y += row_height
		row_index += 1

func _control_children() -> Array:
	var controls: Array = []
	for child in get_children():
		if child is Control and (child as Control).visible:
			controls.append(child)
	return controls
