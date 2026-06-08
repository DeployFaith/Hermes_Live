class_name HermesEventBus
extends RefCounted

signal event_emitted(event)

var _listeners: Dictionary = {}

func on(event_type: String, callback: Callable) -> void:
	if event_type.strip_edges() == "" or not callback.is_valid():
		return
	if not _listeners.has(event_type):
		_listeners[event_type] = []
	var callbacks: Array = _listeners[event_type]
	if callbacks.has(callback):
		return
	callbacks.append(callback)
	_listeners[event_type] = callbacks

func emit_event(event) -> void:
	if event == null:
		return
	emit_signal("event_emitted", event)
	var callbacks: Array = (_listeners.get(event.type, []) as Array).duplicate()
	for callback in callbacks:
		if callback is Callable and (callback as Callable).is_valid():
			(callback as Callable).call(event)
	callbacks = (_listeners.get("*", []) as Array).duplicate()
	for callback in callbacks:
		if callback is Callable and (callback as Callable).is_valid():
			(callback as Callable).call(event)

func clear_listeners() -> void:
	_listeners.clear()
