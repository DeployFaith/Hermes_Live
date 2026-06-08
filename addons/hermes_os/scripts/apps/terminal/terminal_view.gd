class_name TerminalView
extends VBoxContainer

signal command_submitted(command: String)
signal history_previous_requested
signal history_next_requested
signal interrupt_requested
signal clear_requested
signal paste_requested
signal copy_requested
signal completion_requested(input: String, caret_column: int)
signal suggestion_accepted(input: String)
signal line_clear_before_requested
signal line_clear_after_requested
signal delete_word_backward_requested
signal ctrl_d_requested

const TERMINAL_BG := Color("05080d")
const TERMINAL_PANEL := Color("08111c")
const TERMINAL_BORDER := Color("1f2a3d")
const TERMINAL_TEXT := Color("d8dee9")
const TERMINAL_MUTED := Color("7f8ea3")
const TERMINAL_PROMPT := Color("7dd3fc")
const TERMINAL_CARET := Color("67e8f9")
const TERMINAL_SELECTION := Color(0.20, 0.45, 0.80, 0.36)

var _shell: Node
var _output: TextEdit
var _rich_output: RichTextLabel
var _input: LineEdit
var _completion_hint: Label
var _active_suggestion: String = ""
var _cycle_candidates: Array[String] = []
var _cycle_index: int = -1
var _focus_request_id: int = 0
var _focus_after_submit: bool = false

func terminal_view_init(context: Dictionary = {}) -> void:
	_shell = context.get("shell", null) as Node
	_build()

func set_shell(shell: Node) -> void:
	_shell = shell
	if _output != null:
		_style_output(_output)
	if _rich_output != null:
		_style_rich_output(_rich_output)
	if _input != null:
		_style_input(_input)

func focus_input() -> void:
	_focus_after_submit = false
	_request_input_focus()

func focus_input_after_submit() -> void:
	_focus_after_submit = true
	_request_input_focus()
	call_deferred("_focus_input_after_submit_frame")

func _focus_input_after_submit_frame() -> void:
	if not _focus_after_submit:
		return
	await get_tree().process_frame
	if not _focus_after_submit:
		return
	_focus_after_submit = false
	_request_input_focus()

func _request_input_focus() -> void:
	if _input == null or not is_instance_valid(_input):
		return
	_focus_request_id += 1
	var request_id := _focus_request_id
	_grab_input_focus_if_current(request_id)
	call_deferred("_grab_input_focus_if_current", request_id)

func _grab_input_focus_if_current(request_id: int) -> void:
	if request_id != _focus_request_id:
		return
	if _input == null or not is_instance_valid(_input):
		return
	if not _input.is_inside_tree() or not _input.visible:
		return
	_input.grab_focus()

func get_output() -> TextEdit:
	return _output

func get_input() -> LineEdit:
	return _input

func get_input_text() -> String:
	return _input.text if _input != null else ""

func set_input_text(text: String, move_to_end: bool = true) -> void:
	if _input == null:
		return
	_input.text = text
	if move_to_end:
		_input.caret_column = _input.text.length()

func set_prompt(prompt: String) -> void:
	if _input != null:
		_input.placeholder_text = prompt

func render_text(text: String) -> void:
	if _output != null:
		_output.text = text
	if _rich_output != null:
		_rich_output.text = _plain_to_bbcode(text)
		_rich_output.scroll_to_line(max(_rich_output.get_line_count() - 1, 0))

func render_terminal_buffer(buffer: Object) -> void:
	if buffer == null:
		render_text("")
		return
	var plain := str(buffer.call("get_text")) if buffer.has_method("get_text") else ""
	if _output != null:
		_output.text = plain
	if _rich_output != null:
		var rich := str(buffer.call("get_rich_text")) if buffer.has_method("get_rich_text") else _plain_to_bbcode(plain)
		_rich_output.text = rich
		_rich_output.scroll_to_line(max(_rich_output.get_line_count() - 1, 0))

func clear_input() -> void:
	if _input != null:
		_input.text = ""
	set_completion_hint("")
	_cycle_candidates.clear()
	_cycle_index = -1

func set_completion_hint(text: String) -> void:
	if text.strip_edges() == "":
		_active_suggestion = ""
	if _completion_hint == null:
		return
	_completion_hint.text = text
	_completion_hint.visible = text.strip_edges() != ""

func apply_completion_result(result: Dictionary) -> void:
	if _input == null:
		return
	_active_suggestion = ""
	var replacement := str(result.get("replacement", _input.text))
	if replacement != _input.text:
		set_input_text(replacement)
	var hint := str(result.get("hint", ""))
	set_completion_hint(hint)
	# Store candidates for Tab cycling.
	var raw_candidates: Array = result.get("candidates", []) if result.get("candidates", []) is Array else []
	_cycle_candidates.clear()
	for c in raw_candidates:
		_cycle_candidates.append(str(c))
	_cycle_index = -1
	if _cycle_candidates.size() > 1:
		for i in range(_cycle_candidates.size()):
			if _cycle_candidates[i] == replacement or _cycle_candidates[i] == replacement.strip_edges():
				_cycle_index = i
				break

func apply_suggestion_result(result: Dictionary) -> void:
	if _input == null:
		return
	if bool(result.get("ok", false)):
		_active_suggestion = str(result.get("suggestion", ""))
		set_completion_hint(str(result.get("hint", "")))
	else:
		_active_suggestion = ""
		set_completion_hint("")

func has_active_suggestion() -> bool:
	return _active_suggestion != ""

func accept_active_suggestion() -> bool:
	if _input == null or _active_suggestion == "":
		return false
	set_input_text(_active_suggestion)
	_active_suggestion = ""
	set_completion_hint("")
	suggestion_accepted.emit(_input.text)
	return true

func clear_before_caret() -> void:
	if _input == null:
		return
	var col: int = _input.caret_column
	if col <= 0:
		return
	_input.text = _input.text.substr(col)
	_input.caret_column = 0

func clear_after_caret() -> void:
	if _input == null:
		return
	var col: int = _input.caret_column
	_input.text = _input.text.substr(0, col)
	_input.caret_column = col

func delete_word_backward() -> void:
	if _input == null:
		return
	var text: String = _input.text
	var col: int = _input.caret_column
	if col <= 0:
		return
	var pos := col - 1
	# Skip trailing whitespace.
	while pos >= 0 and text[pos] == " ":
		pos -= 1
	# Skip word characters.
	while pos >= 0 and text[pos] != " ":
		pos -= 1
	pos += 1
	_input.text = text.substr(0, pos) + text.substr(col)
	_input.caret_column = pos

func cycle_completion_backward(prefix: String, mode_hint: String = "") -> void:
	if _cycle_candidates.is_empty():
		return
	if _cycle_candidates.size() == 1:
		set_input_text(_cycle_candidates[0])
		set_completion_hint("1 match")
		return
	_cycle_index -= 1
	if _cycle_index < 0:
		_cycle_index = _cycle_candidates.size() - 1
	var candidate: String = _cycle_candidates[_cycle_index]
	set_input_text(candidate)
	set_completion_hint("%d/%d matches" % [_cycle_index + 1, _cycle_candidates.size()])

func _surface_has_candidates() -> bool:
	return _cycle_candidates.size() > 1

func _build() -> void:
	for child in get_children():
		child.queue_free()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	add_theme_stylebox_override("panel", _terminal_stylebox(TERMINAL_BG, TERMINAL_BORDER, 10, 10))

	_rich_output = RichTextLabel.new()
	_rich_output.name = "TerminalRichOutput"
	_rich_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rich_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rich_output.bbcode_enabled = true
	_rich_output.selection_enabled = true
	_rich_output.scroll_active = true
	_rich_output.scroll_following = true
	_rich_output.fit_content = false
	_style_rich_output(_rich_output)
	_rich_output.gui_input.connect(_on_output_gui_input)
	add_child(_rich_output)

	# Compatibility mirror for existing validation/tests that read TerminalOutput.text.
	_output = TextEdit.new()
	_output.name = "TerminalOutput"
	_output.visible = false
	_output.custom_minimum_size = Vector2.ZERO
	_output.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_output.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_output.editable = false
	_output.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_output.selecting_enabled = true
	_style_output(_output)
	add_child(_output)

	_input = LineEdit.new()
	_input.name = "TerminalInput"
	_input.focus_mode = Control.FOCUS_ALL
	# Godot's default is false, which leaves the LineEdit focused but no longer
	# actively editing after text_submitted. That matches the live bug: has_focus()
	# passes, but the next typed command is ignored until the user clicks again.
	_input.keep_editing_on_text_submit = true
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_input(_input)
	_input.text_submitted.connect(func(command: String) -> void:
		command_submitted.emit(command)
	)
	_input.gui_input.connect(_on_input_gui_input)
	add_child(_input)

	_completion_hint = Label.new()
	_completion_hint.name = "TerminalCompletionHint"
	_completion_hint.visible = false
	_completion_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_completion_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_completion_hint.add_theme_color_override("font_color", TERMINAL_MUTED)
	_completion_hint.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	add_child(_completion_hint)

func _on_input_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var command_key := key_event.ctrl_pressed or key_event.meta_pressed
	if command_key:
		match key_event.keycode:
			KEY_C:
				interrupt_requested.emit()
				accept_event()
			KEY_L:
				clear_requested.emit()
				accept_event()
			KEY_A:
				if _input != null:
					_input.caret_column = 0
				accept_event()
			KEY_E:
				if _input != null:
					_input.caret_column = _input.text.length()
				accept_event()
			KEY_V:
				paste_requested.emit()
				accept_event()
			KEY_U:
				clear_before_caret()
				accept_event()
			KEY_K:
				clear_after_caret()
				accept_event()
			KEY_W:
				delete_word_backward()
				accept_event()
			KEY_D:
				if _input != null and _input.text != "":
					var col: int = _input.caret_column
					if col < _input.text.length():
						_input.text = _input.text.substr(0, col) + _input.text.substr(col + 1)
						_input.caret_column = col
				ctrl_d_requested.emit()
				accept_event()
		return
	match key_event.keycode:
		KEY_TAB:
			if key_event.shift_pressed:
				if _surface_has_candidates():
					cycle_completion_backward(_input.text if _input != null else "")
				else:
					completion_requested.emit(_input.text if _input != null else "", _input.caret_column if _input != null else -1)
			elif _input != null:
				completion_requested.emit(_input.text, _input.caret_column)
			accept_event()
		KEY_RIGHT:
			if _input != null and _input.caret_column >= _input.text.length() and accept_active_suggestion():
				accept_event()
		KEY_UP:
			history_previous_requested.emit()
			accept_event()
		KEY_DOWN:
			history_next_requested.emit()
			accept_event()

func _on_output_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if (key_event.ctrl_pressed or key_event.meta_pressed) and key_event.keycode == KEY_C:
		copy_requested.emit()
		accept_event()

func get_selected_output_text() -> String:
	if _rich_output != null:
		var selected := _rich_output.get_selected_text()
		if selected != "":
			return selected
	if _output != null:
		return _output.get_selected_text()
	return ""

func _style_output(output: TextEdit) -> void:
	if _shell != null and _shell.has_method("_style_text_edit"):
		_shell.call("_style_text_edit", output)
	output.add_theme_color_override("font_color", TERMINAL_TEXT)
	output.add_theme_color_override("font_readonly_color", TERMINAL_TEXT)
	output.add_theme_color_override("caret_color", TERMINAL_CARET)
	output.add_theme_color_override("selection_color", TERMINAL_SELECTION)
	output.add_theme_stylebox_override("normal", _terminal_stylebox(TERMINAL_PANEL, TERMINAL_BORDER, 8, 8))
	output.add_theme_stylebox_override("read_only", _terminal_stylebox(TERMINAL_PANEL, TERMINAL_BORDER, 8, 8))

func _style_rich_output(output: RichTextLabel) -> void:
	output.add_theme_color_override("default_color", TERMINAL_TEXT)
	output.add_theme_color_override("font_selected_color", Color("f8fafc"))
	output.add_theme_color_override("selection_color", TERMINAL_SELECTION)
	output.add_theme_stylebox_override("normal", _terminal_stylebox(TERMINAL_PANEL, TERMINAL_BORDER, 8, 10))

func _style_input(input: LineEdit) -> void:
	if _shell != null and _shell.has_method("_style_line_edit"):
		_shell.call("_style_line_edit", input)
	input.add_theme_color_override("font_color", Color("f8fafc"))
	input.add_theme_color_override("caret_color", TERMINAL_CARET)
	input.add_theme_color_override("font_placeholder_color", TERMINAL_PROMPT)
	input.add_theme_color_override("selection_color", TERMINAL_SELECTION)
	input.add_theme_stylebox_override("normal", _terminal_stylebox(Color("06101a"), TERMINAL_BORDER, 8, 8))
	input.add_theme_stylebox_override("focus", _terminal_stylebox(Color("071625"), TERMINAL_PROMPT, 8, 8))

func _terminal_stylebox(bg: Color, border: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func _plain_to_bbcode(text: String) -> String:
	if text == "":
		return ""
	var rendered: Array[String] = []
	for line in text.split("\n", true):
		rendered.append("[color=#d8dee9]" + _escape_bbcode(str(line)) + "[/color]")
	return "\n".join(rendered)

func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")
