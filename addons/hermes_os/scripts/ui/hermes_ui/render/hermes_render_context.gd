class_name HermesRenderContext
extends RefCounted

const HermesTheme = preload("res://addons/hermes_os/scripts/ui/hermes_ui/hermes_theme.gd")
const HermesComponentFactory = preload("res://addons/hermes_os/scripts/ui/hermes_ui/hermes_component_factory.gd")
const HermesStyleResolver = preload("res://addons/hermes_os/scripts/ui/hermes_ui/style/hermes_style_resolver.gd")

var theme = null
var ui = null
var registry = null
var stylesheets: Array = []
var style_resolver = null
var state = null

func _init() -> void:
	theme = HermesTheme.new()
	ui = HermesComponentFactory.new(theme)
	style_resolver = HermesStyleResolver.new()
