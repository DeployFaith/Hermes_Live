class_name OSEventBus
extends RefCounted

signal event_emitted(event_name: StringName, payload: Dictionary)

const APP_LAUNCHED := &"app.launched"
const APP_CLOSED := &"app.closed"
const WINDOW_OPENED := &"window.opened"
const WINDOW_CLOSED := &"window.closed"
const WINDOW_FOCUSED := &"window.focused"
const WINDOW_MINIMIZED := &"window.minimized"
const WINDOW_RESTORED := &"window.restored"
const FILE_CREATED := &"file.created"
const FILE_UPDATED := &"file.updated"
const FILE_DELETED := &"file.deleted"
const FILE_MOVED := &"file.moved"
const FILE_OPENED := &"file.opened"
const NOTIFICATION_CREATED := &"notification.created"
const NOTIFICATION_DISMISSED := &"notification.dismissed"
const NOTIFICATION_CLEARED := &"notification.cleared"
const AGENT_OPERATION_REQUESTED := &"agent.operation_requested"
const AGENT_OPERATION_COMPLETED := &"agent.operation_completed"
const AGENT_OPERATION_FAILED := &"agent.operation_failed"
const AGENT_MESSAGE_SENT := &"agent.message_sent"
const AGENT_RESPONSE_RECEIVED := &"agent.response_received"
const AGENT_ERROR := &"agent.error"
const AGENT_STATUS_CHANGED := &"agent.status_changed"

var _subscribers: Dictionary = {}

func emit_event(event_name: StringName, payload: Dictionary = {}) -> void:
	var safe_payload := payload.duplicate(true)
	event_emitted.emit(event_name, safe_payload.duplicate(true))
	if not _subscribers.has(event_name):
		return
	var callbacks: Array = (_subscribers[event_name] as Array).duplicate()
	for callback in callbacks:
		if not (callback is Callable):
			continue
		var typed_callback := callback as Callable
		if typed_callback.is_valid():
			typed_callback.call(event_name, safe_payload.duplicate(true))

func subscribe(event_name: StringName, target: Object, method: StringName) -> void:
	if target == null:
		return
	var callback := Callable(target, method)
	if not callback.is_valid():
		return
	if not _subscribers.has(event_name):
		_subscribers[event_name] = []
	var callbacks: Array = _subscribers[event_name]
	if callbacks.has(callback):
		return
	callbacks.append(callback)

func unsubscribe(event_name: StringName, target: Object, method: StringName) -> void:
	if target == null or not _subscribers.has(event_name):
		return
	var callback := Callable(target, method)
	var callbacks: Array = _subscribers[event_name]
	callbacks.erase(callback)
	if callbacks.is_empty():
		_subscribers.erase(event_name)

func clear() -> void:
	_subscribers.clear()
