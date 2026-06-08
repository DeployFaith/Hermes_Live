class_name HermesShellInputGuard
extends RefCounted

static func should_preserve_text_editing_key(viewport: Viewport, key_event: InputEventKey) -> bool:
	if viewport == null or key_event == null:
		return false
	var focus_owner: Control = viewport.gui_get_focus_owner()
	if not is_text_editing_control(focus_owner):
		return false
	# Global/meta shortcuts should still work. Plain text editing, Backspace,
	# Delete, caret movement, and Enter belong to the focused editor first.
	if key_event.alt_pressed or key_event.meta_pressed:
		return false
	if key_event.ctrl_pressed and key_event.keycode != KEY_BACKSPACE:
		return false
	if key_event.unicode > 0:
		return true
	return key_event.keycode in [
		KEY_BACKSPACE,
		KEY_DELETE,
		KEY_LEFT,
		KEY_RIGHT,
		KEY_UP,
		KEY_DOWN,
		KEY_HOME,
		KEY_END,
		KEY_ENTER,
		KEY_KP_ENTER
	]

static func is_text_editing_control(control: Control) -> bool:
	if control == null:
		return false
	if control is LineEdit or control is TextEdit:
		return true
	if control.has_meta("hermes_text_input") and bool(control.get_meta("hermes_text_input")):
		return true
	var hermes_id: String = str(control.get_meta("hermes_id", "")) if control.has_meta("hermes_id") else ""
	return hermes_id.find("search") != -1 or hermes_id.find("input") != -1 or hermes_id.find("text") != -1
