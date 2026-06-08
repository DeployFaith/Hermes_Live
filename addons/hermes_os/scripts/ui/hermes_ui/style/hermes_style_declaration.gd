class_name HermesStyleDeclaration
extends RefCounted

const HermesStyleValue = preload("res://addons/hermes_os/scripts/ui/hermes_ui/style/hermes_style_value.gd")

var property_name: String = ""
var value = null
var source_line: int = -1

func configure(p_property_name: String, raw_value: String, line: int = -1):
	property_name = p_property_name.strip_edges()
	value = HermesStyleValue.new().configure(raw_value)
	source_line = line
	return self
