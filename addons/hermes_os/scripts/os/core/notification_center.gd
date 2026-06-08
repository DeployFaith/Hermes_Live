class_name NotificationCenter
extends RefCounted

const MAX_RECENT := 50

var _event_bus: OSEventBus
var _notifications: Array[Dictionary] = []
var _sequence: int = 0
var muted: bool = false

func setup(event_bus: OSEventBus) -> void:
	_event_bus = event_bus

func mute() -> void:
	muted = true

func unmute() -> void:
	muted = false

func _set_notification_sequence(sequence: int) -> void:
	_sequence = maxi(_sequence, sequence)

func notify(title: String, body: String = "", options: Dictionary = {}) -> Dictionary:
	var data := options.duplicate(true)
	data["title"] = title
	data["body"] = body
	return notify_from_dict(data)

func notify_from_dict(data: Dictionary) -> Dictionary:
	var app_id := str(data.get("app_id", "")).strip_edges().to_lower()
	if app_id in ["account_center", "accounts", "system_settings"]:
		return {}
	if muted:
		var level := str(data.get("level", "info")).strip_edges().to_lower()
		if level != "critical":
			return {}
	_sequence += 1
	var notification_id := "n_" + str(_sequence)
	var action_variant: Variant = data.get("action", {})
	var notification := {
		"id": notification_id,
		"title": str(data.get("title", "Notification")).strip_edges(),
		"body": str(data.get("body", "")).strip_edges(),
		"app_id": str(data.get("app_id", "system")).strip_edges(),
		"level": str(data.get("level", "info")).strip_edges().to_lower(),
		"timestamp": str(data.get("timestamp", _time_text())),
		"action": action_variant if action_variant is Dictionary else {}
	}
	if str(notification["title"]) == "":
		notification["title"] = "Notification"
	_notifications.push_front(notification)
	while _notifications.size() > MAX_RECENT:
		_notifications.pop_back()
	_emit_notification_event(OSEventBus.NOTIFICATION_CREATED, notification)
	return notification.duplicate(true)

func get_recent(limit: int = 20) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var capped_limit := mini(maxi(limit, 0), _notifications.size())
	for index in range(capped_limit):
		result.append((_notifications[index] as Dictionary).duplicate(true))
	return result

func clear() -> Array[String]:
	var dismissed_ids: Array[String] = []
	for notification in _notifications:
		var item: Dictionary = notification
		var notification_id := str(item.get("id", ""))
		if notification_id != "":
			dismissed_ids.append(notification_id)
	_notifications.clear()
	if _event_bus != null:
		_event_bus.emit_event(OSEventBus.NOTIFICATION_CLEARED, {"dismissed_ids": dismissed_ids.duplicate()})
	return dismissed_ids

func export_state() -> Array[Dictionary]:
	return get_recent(MAX_RECENT)

func import_state(items: Array) -> void:
	_notifications.clear()
	_sequence = 0
	for item in items:
		if not (item is Dictionary):
			continue
		var notification: Dictionary = (item as Dictionary).duplicate(true)
		_notifications.append(notification)
		_sequence = maxi(_sequence, int(str(notification.get("id", "0")).trim_prefix("n_")))
	while _notifications.size() > MAX_RECENT:
		_notifications.pop_back()

func reset() -> void:
	_notifications.clear()
	_sequence = 0

func _emit_notification_event(event_name: StringName, notification: Dictionary) -> void:
	if _event_bus == null:
		return
	_event_bus.emit_event(event_name, {"notification": notification.duplicate(true)})

func _time_text() -> String:
	var now := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [now.year, now.month, now.day, now.hour, now.minute, now.second]
