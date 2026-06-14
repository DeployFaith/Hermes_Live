extends CanvasLayer

## Animated build hotbar HUD for the 3D world.
## PlacementController populates this with BlockLibrary data and drives
## selection/build-mode state.

const CATEGORY_ORDER := ["block", "item", "structure"]
const CATEGORY_TITLES := {
	"block": "Blocks",
	"item": "Items",
	"structure": "Structures",
}
const SLOT_SIZE := Vector2(86, 92)
const ICON_SIZE := Vector2(46, 46)
const DRAWER_TWEEN_SECONDS := 0.3
const DRAWER_VISIBLE_OFFSET_TOP := -270.0
const DRAWER_HIDDEN_OFFSET_TOP := 0.0

signal category_tab_pressed(category: String)

@onready var prompt_label: Label = $PromptLabel
@onready var root: Control = $Root
@onready var hotbar_anchor: Control = $Root/HotbarAnchor
@onready var hotbar_panel: PanelContainer = $Root/HotbarAnchor/HotbarPanel
@onready var category_row: HBoxContainer = $Root/HotbarAnchor/HotbarPanel/MarginContainer/VBoxContainer/CategoryRow
@onready var status_label: Label = $Root/HotbarAnchor/HotbarPanel/MarginContainer/VBoxContainer/StatusLabel

var _slots: Array[Dictionary] = []
var _tab_buttons: Dictionary = {}
var _grouped_ids: Dictionary = {}
var _ordered_ids: Array[String] = []
var _library: BlockLibrary
var _active_category: String = "block"
var _selected_index: int = -1
var _build_mode_enabled: bool = false
var _slide_tween: Tween
var _base_slot_style: StyleBoxFlat
var _selected_slot_style: StyleBoxFlat
var _section_style: StyleBoxFlat
var _tab_style: StyleBoxFlat
var _active_tab_style: StyleBoxFlat


func _ready() -> void:
	_make_styles()
	hotbar_panel.add_theme_stylebox_override("panel", _make_drawer_style())
	call_deferred("_snap_drawer_to_state")


func populate_hotbar(library: BlockLibrary, ids: Array[String]) -> void:
	_clear_slots()
	_library = library
	_ordered_ids.clear()
	for id in ids:
		_ordered_ids.append(id)
	_grouped_ids = {
		"block": [],
		"item": [],
		"structure": [],
	}
	for id in ids:
		var category := "block"
		if library != null and library.has_block(id):
			category = library.get_category(id)
		if not _grouped_ids.has(category):
			_grouped_ids[category] = []
		_grouped_ids[category].append(id)

	_make_category_tabs()
	if not _category_has_items(_active_category):
		_active_category = _first_populated_category()
	_render_active_category()
	set_selected_index(_selected_index)
	_snap_drawer_to_state()


func set_active_category(category: String) -> void:
	if not _grouped_ids.has(category):
		return
	if _active_category == category and category_row.get_child_count() > 0:
		_update_tab_styles()
		return
	_active_category = category
	_update_tab_styles()
	_render_active_category()
	set_selected_index(_selected_index)


func get_active_category() -> String:
	return _active_category


func _make_category_tabs() -> void:
	var vbox := category_row.get_parent()
	if vbox == null:
		return
	var tabs := vbox.get_node_or_null("CategoryTabs") as HBoxContainer
	if tabs == null:
		tabs = HBoxContainer.new()
		tabs.name = "CategoryTabs"
		tabs.alignment = BoxContainer.ALIGNMENT_CENTER
		tabs.add_theme_constant_override("separation", 8)
		vbox.add_child(tabs)
		vbox.move_child(tabs, category_row.get_index())
	for child in tabs.get_children():
		tabs.remove_child(child)
		child.queue_free()
	_tab_buttons.clear()

	for category in CATEGORY_ORDER:
		var button := Button.new()
		button.text = CATEGORY_TITLES.get(category, category.capitalize())
		button.toggle_mode = false
		button.disabled = not _category_has_items(category)
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(116, 32)
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(_on_category_button_pressed.bind(category))
		tabs.add_child(button)
		_tab_buttons[category] = button
	_update_tab_styles()


func _on_category_button_pressed(category: String) -> void:
	if _category_has_items(category):
		category_tab_pressed.emit(category)


func set_selected_index(index: int) -> void:
	_selected_index = index
	for i in range(_slots.size()):
		var slot := _slots[i]
		var global_index := int(slot.get("global_index", i))
		_update_slot_selection(slot, global_index == _selected_index)


func set_selected_id(id: String) -> void:
	_selected_index = -1
	for i in range(_slots.size()):
		var slot := _slots[i]
		var global_index := int(slot.get("global_index", i))
		var selected := str(slot.get("id", "")) == id
		if selected:
			_selected_index = global_index
		_update_slot_selection(slot, selected)


func _render_active_category() -> void:
	_clear_category_sections()
	if _grouped_ids.is_empty() or not _category_has_items(_active_category):
		return
	category_row.add_child(_make_category_section(_active_category, _grouped_ids[_active_category], _library))


func _category_has_items(category: String) -> bool:
	return _grouped_ids.has(category) and not _grouped_ids.get(category, []).is_empty()


func _first_populated_category() -> String:
	for category in CATEGORY_ORDER:
		if _category_has_items(category):
			return category
	return "block"


func _global_index_for_slot_id(id: String) -> int:
	for i in range(_ordered_ids.size()):
		if _ordered_ids[i] == id:
			return i
	return -1


func _update_tab_styles() -> void:
	for category in _tab_buttons.keys():
		var button := _tab_buttons[category] as Button
		if button == null:
			continue
		var active := str(category) == _active_category
		button.add_theme_stylebox_override("normal", _active_tab_style if active else _tab_style)
		button.add_theme_stylebox_override("hover", _active_tab_style if active else _tab_style)
		button.add_theme_stylebox_override("pressed", _active_tab_style)
		button.add_theme_color_override("font_color", Color(1.0, 0.86, 0.34, 1.0) if active else Color(0.72, 0.82, 1.0, 1.0))


func _update_slot_selection(slot: Dictionary, selected: bool) -> void:
	var panel := slot.get("panel") as PanelContainer
	var number_label := slot.get("number_label") as Label
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", _selected_slot_style if selected else _base_slot_style)
	panel.modulate = Color(1.18, 1.18, 1.18, 1.0) if selected else Color(0.88, 0.9, 0.95, 1.0)
	panel.scale = Vector2(1.08, 1.08) if selected else Vector2.ONE
	panel.z_index = 10 if selected else 0
	if number_label != null:
		number_label.modulate = Color(1.0, 0.86, 0.34, 1.0) if selected else Color(0.7, 0.75, 0.85, 1.0)


func set_build_mode(enabled: bool) -> void:
	if _build_mode_enabled == enabled and _slide_tween == null:
		return
	_build_mode_enabled = enabled
	_animate_drawer(enabled)


func set_status_text(text: String) -> void:
	status_label.text = text


func _clear_slots() -> void:
	_slots.clear()
	_clear_category_sections()


func _clear_category_sections() -> void:
	_slots.clear()
	for child in category_row.get_children():
		category_row.remove_child(child)
		child.queue_free()


func _make_category_section(category: String, ids: Array, library: BlockLibrary) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.name = "%sSection" % CATEGORY_TITLES.get(category, category.capitalize()).replace(" ", "")
	section.add_theme_constant_override("separation", 6)

	var label := Label.new()
	label.text = str(CATEGORY_TITLES.get(category, category.capitalize())).to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.72, 0.82, 1.0, 1.0))
	section.add_child(label)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _section_style)
	section.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var slots_row := HBoxContainer.new()
	slots_row.name = "Slots"
	slots_row.add_theme_constant_override("separation", 8)
	margin.add_child(slots_row)

	var local_index := 0
	for id in ids:
		slots_row.add_child(_make_slot(id, library, local_index))
		local_index += 1

	return section


func _make_slot(id: String, library: BlockLibrary, local_index: int) -> PanelContainer:
	var slot_panel := PanelContainer.new()
	slot_panel.name = "%sSlot" % id.capitalize().replace("_", "")
	slot_panel.custom_minimum_size = SLOT_SIZE
	slot_panel.add_theme_stylebox_override("panel", _base_slot_style)
	slot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	slot_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(top_row)

	var index_label := Label.new()
	index_label.text = str(local_index + 1) if local_index < 9 else "•"
	index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	index_label.add_theme_font_size_override("font_size", 13)
	index_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 1.0))
	top_row.add_child(index_label)

	var icon_texture := _load_icon_texture(id, library)
	if icon_texture != null:
		var icon := TextureRect.new()
		icon.texture = icon_texture
		icon.custom_minimum_size = ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vbox.add_child(icon)
	else:
		var fallback := Label.new()
		fallback.custom_minimum_size = ICON_SIZE
		fallback.text = _make_initials(_get_display_name(id, library))
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.add_theme_font_size_override("font_size", 20)
		fallback.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0, 1.0))
		vbox.add_child(fallback)

	var name_label := Label.new()
	name_label.text = _get_display_name(id, library)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0, 1.0))
	vbox.add_child(name_label)

	_slots.append({
		"id": id,
		"panel": slot_panel,
		"number_label": index_label,
		"global_index": _global_index_for_slot_id(id),
	})
	return slot_panel


func _load_icon_texture(id: String, library: BlockLibrary) -> Texture2D:
	if library == null or not library.has_block(id):
		return null
	var texture_path := library.get_texture_path(id)
	if texture_path == "":
		return null
	for suffix in ["/sides.png", "/top.png", "/bottom.png"]:
		var full_path: String = texture_path + suffix
		if ResourceLoader.exists(full_path):
			return load(full_path) as Texture2D
	if ResourceLoader.exists(texture_path):
		return load(texture_path) as Texture2D
	return null


func _get_display_name(id: String, library: BlockLibrary) -> String:
	return library.get_display_name(id) if library != null and library.has_block(id) else id.capitalize()


func _make_initials(display_name: String) -> String:
	var result := ""
	for part in display_name.split(" ", false):
		if part.length() > 0:
			result += part.substr(0, 1).to_upper()
		if result.length() >= 2:
			break
	return result if result != "" else "?"


func _animate_drawer(show: bool) -> void:
	if not is_inside_tree():
		return
	if _slide_tween != null:
		_slide_tween.kill()
	var target_offset_top := _get_shown_offset_top() if show else _get_hidden_offset_top()
	_slide_tween = create_tween()
	_slide_tween.set_trans(Tween.TRANS_SINE)
	_slide_tween.set_ease(Tween.EASE_IN_OUT)
	_slide_tween.tween_property(hotbar_anchor, "offset_top", target_offset_top, DRAWER_TWEEN_SECONDS)
	_slide_tween.finished.connect(func() -> void: _slide_tween = null)


func _snap_drawer_to_state() -> void:
	if hotbar_anchor == null:
		return
	hotbar_anchor.offset_top = _get_shown_offset_top() if _build_mode_enabled else _get_hidden_offset_top()


func _get_shown_offset_top() -> float:
	return DRAWER_VISIBLE_OFFSET_TOP


func _get_hidden_offset_top() -> float:
	return DRAWER_HIDDEN_OFFSET_TOP


func _make_styles() -> void:
	_base_slot_style = StyleBoxFlat.new()
	_base_slot_style.bg_color = Color(0.07, 0.09, 0.14, 0.88)
	_base_slot_style.border_color = Color(0.33, 0.43, 0.62, 0.85)
	_base_slot_style.border_width_left = 2
	_base_slot_style.border_width_top = 2
	_base_slot_style.border_width_right = 2
	_base_slot_style.border_width_bottom = 2
	_base_slot_style.corner_radius_top_left = 10
	_base_slot_style.corner_radius_top_right = 10
	_base_slot_style.corner_radius_bottom_right = 10
	_base_slot_style.corner_radius_bottom_left = 10
	_base_slot_style.shadow_color = Color(0, 0, 0, 0.45)
	_base_slot_style.shadow_size = 5

	_selected_slot_style = _base_slot_style.duplicate() as StyleBoxFlat
	_selected_slot_style.bg_color = Color(0.15, 0.18, 0.28, 0.96)
	_selected_slot_style.border_color = Color(1.0, 0.82, 0.28, 1.0)
	_selected_slot_style.border_width_left = 4
	_selected_slot_style.border_width_top = 4
	_selected_slot_style.border_width_right = 4
	_selected_slot_style.border_width_bottom = 4
	_selected_slot_style.shadow_color = Color(1.0, 0.66, 0.18, 0.55)
	_selected_slot_style.shadow_size = 14

	_section_style = StyleBoxFlat.new()
	_section_style.bg_color = Color(0.04, 0.055, 0.09, 0.48)
	_section_style.border_color = Color(0.25, 0.32, 0.48, 0.55)
	_section_style.border_width_left = 1
	_section_style.border_width_top = 1
	_section_style.border_width_right = 1
	_section_style.border_width_bottom = 1
	_section_style.corner_radius_top_left = 12
	_section_style.corner_radius_top_right = 12
	_section_style.corner_radius_bottom_right = 12
	_section_style.corner_radius_bottom_left = 12

	_tab_style = StyleBoxFlat.new()
	_tab_style.bg_color = Color(0.05, 0.065, 0.11, 0.72)
	_tab_style.border_color = Color(0.26, 0.36, 0.58, 0.82)
	_tab_style.border_width_left = 1
	_tab_style.border_width_top = 1
	_tab_style.border_width_right = 1
	_tab_style.border_width_bottom = 1
	_tab_style.corner_radius_top_left = 9
	_tab_style.corner_radius_top_right = 9
	_tab_style.corner_radius_bottom_right = 9
	_tab_style.corner_radius_bottom_left = 9

	_active_tab_style = _tab_style.duplicate() as StyleBoxFlat
	_active_tab_style.bg_color = Color(0.16, 0.18, 0.28, 0.95)
	_active_tab_style.border_color = Color(1.0, 0.82, 0.28, 1.0)
	_active_tab_style.border_width_left = 2
	_active_tab_style.border_width_top = 2
	_active_tab_style.border_width_right = 2
	_active_tab_style.border_width_bottom = 2


func _make_drawer_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.06, 0.15)
	style.border_color = Color(0.36, 0.48, 0.78, 0.72)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_right = 22
	style.corner_radius_bottom_left = 22
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 16
	return style
