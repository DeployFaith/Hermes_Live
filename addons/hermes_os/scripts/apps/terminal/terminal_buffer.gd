class_name TerminalBuffer
extends RefCounted

const DEFAULT_MAX_LINES := 800
const ESC := ""

var _lines: Array[String] = []
var _entries: Array[Dictionary] = []
var _max_lines: int = DEFAULT_MAX_LINES

func terminal_buffer_init(options: Dictionary = {}) -> void:
	_max_lines = maxi(int(options.get("max_lines", DEFAULT_MAX_LINES)), 1)
	var intro := str(options.get("intro", "")).strip_edges()
	if intro != "":
		append_line(intro, "system")

func clear() -> void:
	_lines.clear()
	_entries.clear()

func append_prompt_command(prompt: String, command: String) -> void:
	var clean_command := command.strip_edges()
	var line := prompt
	if clean_command != "":
		line += " " + command
	_lines.append(line)
	_entries.append({
		"kind": "prompt",
		"prompt": prompt,
		"command": command,
		"text": line
	})
	_trim_scrollback()

func append_output(text: String, kind: String = "stdout") -> void:
	var decoded: Dictionary = _decode_ansi(text)
	if bool(decoded.get("clear_screen", false)):
		clear()
	var plain := str(decoded.get("text", ""))
	if plain == "":
		return
	var parts := plain.split("\n", true)
	for part in parts:
		append_line(str(part), kind)

func append_line(text: String, kind: String = "stdout") -> void:
	var clean_kind := _normalize_kind(kind)
	_lines.append(text)
	_entries.append({
		"kind": clean_kind,
		"text": text
	})
	_trim_scrollback()

func append_lines(lines: Array, kind: String = "stdout") -> void:
	for line in lines:
		append_line(str(line), kind)

func get_text() -> String:
	return "\n".join(_lines)

func get_lines() -> Array[String]:
	var result: Array[String] = []
	for line in _lines:
		result.append(line)
	return result

func get_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _entries:
		result.append(entry.duplicate(true))
	return result

func get_rich_text() -> String:
	var rendered: Array[String] = []
	for entry in _entries:
		rendered.append(_entry_to_bbcode(entry))
	return "\n".join(rendered)

func line_count() -> int:
	return _lines.size()

func _trim_scrollback() -> void:
	if _lines.size() <= _max_lines:
		return
	_lines = _lines.slice(_lines.size() - _max_lines, _lines.size())
	_entries = _entries.slice(_entries.size() - _max_lines, _entries.size())

func _normalize_kind(kind: String) -> String:
	match kind:
		"prompt", "stdout", "stderr", "system", "hint":
			return kind
		_:
			return "stdout"

func _entry_to_bbcode(entry: Dictionary) -> String:
	var kind := _normalize_kind(str(entry.get("kind", "stdout")))
	if kind == "prompt":
		var prompt := _escape_bbcode(str(entry.get("prompt", "")))
		var command := _escape_bbcode(str(entry.get("command", "")))
		if command.strip_edges() == "":
			return "[color=#7dd3fc]" + prompt + "[/color]"
		return "[color=#7dd3fc]" + prompt + "[/color] [color=#f8fafc]" + command + "[/color]"
	var text := _escape_bbcode(str(entry.get("text", "")))
	match kind:
		"stderr":
			return "[color=#ff7b72]" + text + "[/color]"
		"system":
			return "[color=#c4b5fd]◆ " + text + "[/color]"
		"hint":
			return "[color=#7f8ea3]" + text + "[/color]"
		_:
			return "[color=#d8dee9]" + text + "[/color]"

func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")

func _decode_ansi(text: String) -> Dictionary:
	var clear_screen := false
	var output := ""
	var index := 0
	while index < text.length():
		var ch := text[index]
		if ch == ESC and index + 1 < text.length() and text[index + 1] == "[":
			var sequence_start := index
			index += 2
			while index < text.length():
				var code := text.unicode_at(index)
				if code >= 64 and code <= 126:
					var command := text[index]
					var params := text.substr(sequence_start + 2, index - sequence_start - 2)
					if command == "J" and (params == "2" or params == "3"):
						clear_screen = true
					index += 1
					break
				index += 1
			continue
		output += ch
		index += 1
	return {"clear_screen": clear_screen, "text": output}
