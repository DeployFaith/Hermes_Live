extends Control
class_name DesktopPreview

@onready var clock_label: Label = $ClockLabel

func _ready() -> void:
	_update_clock()
	var timer := Timer.new()
	timer.name = "ClockTimer"
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_update_clock)
	add_child(timer)

func _update_clock() -> void:
	var now := Time.get_datetime_dict_from_system()
	clock_label.text = "%02d:%02d" % [now.hour, now.minute]
