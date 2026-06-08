class_name HermesMarkdownDocument
extends RefCounted

const HermesMarkdownDiagnostic = preload("res://addons/hermes_os/scripts/ui/hermes_ui/markdown/hermes_markdown_diagnostic.gd")

var source_path: String = ""
var frontmatter: Dictionary = {}
var generated_hml: String = ""
var diagnostics: Array = []

func add_diagnostic(message: String, line: int = -1, severity: String = "error") -> void:
	diagnostics.append(HermesMarkdownDiagnostic.new(message, source_path, line, severity))

func has_errors() -> bool:
	for diagnostic in diagnostics:
		if diagnostic != null and str(diagnostic.severity) == "error":
			return true
	return false
