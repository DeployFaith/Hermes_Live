class_name HermesEvent
extends RefCounted

var type: String = ""
var target_id: String = ""
var target = null
var value = null
var app = null
var raw_event = null

func configure(event_type: String, event_target, event_value = null, app_instance = null, event_raw = null):
	type = event_type
	target = event_target
	target_id = event_target.id if event_target != null else ""
	value = event_value
	app = app_instance
	raw_event = event_raw
	return self
