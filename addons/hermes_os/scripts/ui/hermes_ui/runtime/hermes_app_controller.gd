class_name HermesAppController
extends RefCounted

var app = null
var runtime = null
var manifest = null
var root_control: Control = null
var state = null
var events = null
var renderer = null
var render_context = null
var ui = null
var os = null

func _attach_runtime(app_instance, app_runtime) -> void:
	app = app_instance
	runtime = app_runtime
	manifest = app_instance.manifest if app_instance != null else null
	state = app_instance.state if app_instance != null else null
	events = app_instance.event_bus if app_instance != null else null

func app_mounted(root: Control) -> void:
	root_control = root
	if app != null:
		renderer = app.renderer
		render_context = app.render_context

func app_unmounted() -> void:
	root_control = null
	if ui != null and ui.has_method("teardown"):
		ui.teardown()
	if os != null and os.has_method("teardown"):
		os.teardown()
	ui = null
	os = null
	renderer = null
	render_context = null
	state = null
	events = null
	manifest = null
	app = null
	runtime = null
