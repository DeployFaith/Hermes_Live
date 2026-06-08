class_name HermesMarkdownDiagnostic
extends RefCounted

var severity: String = "error"
var message: String = ""
var source_path: String = ""
var line: int = -1

func _init(p_message: String = "", p_source_path: String = "", p_line: int = -1, p_severity: String = "error") -> void:
	message = p_message
	source_path = p_source_path
	line = p_line
	severity = p_severity
