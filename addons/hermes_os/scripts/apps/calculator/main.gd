extends "res://addons/hermes_os/scripts/ui/hermes_ui/runtime/hermes_app_controller.gd"

var _current: String = "0"
var _operand: float = 0.0
var _operator: String = ""
var _waiting_for_operand: bool = false
var _expression: String = ""

func _app_ready() -> void:
	if state == null:
		return
	state.set_many({
		"display": "0",
		"expression": "",
	})
	call_deferred("_fix_alignment")

func _fix_alignment() -> void:
	if ui == null:
		return
	var expr_label = ui.by_id("calc-expression")
	if expr_label != null and expr_label is Label:
		expr_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var result_label = ui.by_id("calc-result")
	if result_label != null and result_label is Label:
		result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func btn_digit(event) -> void:
	var digit: String = str(event.value) if event != null and event.get("value") != null else ""
	if digit == "":
		return
	if _waiting_for_operand:
		_current = digit
		_waiting_for_operand = false
	else:
		if _current == "0" and digit != ".":
			_current = digit
		else:
			_current += digit
	_update_display()

func btn_dot(event = null) -> void:
	if _waiting_for_operand:
		_current = "0."
		_waiting_for_operand = false
	elif _current.find(".") == -1:
		_current += "."
	_update_display()

func btn_operator(event) -> void:
	var op: String = str(event.value) if event != null and event.get("value") != null else ""
	if op == "":
		return
	var current_val: float = float(_current)
	if _operator != "" and not _waiting_for_operand:
		var result: float = _calculate(_operand, current_val, _operator)
		_operand = result
		_expression = _format_number(result) + " " + _operator_symbol(op)
	else:
		_operand = current_val
		_expression = _format_number(current_val) + " " + _operator_symbol(op)
	_operator = op
	_waiting_for_operand = true
	# Show the expression with the operator, clear the main display
	_update_display()

func btn_equals(event = null) -> void:
	if _operator == "":
		return
	var current_val: float = float(_current)
	var result: float = _calculate(_operand, current_val, _operator)
	_expression = _format_number(_operand) + " " + _operator_symbol(_operator) + " " + _format_number(current_val) + " ="
	_current = _format_number(result)
	_operand = result
	_operator = ""
	_waiting_for_operand = true
	_update_display()

func btn_clear(event = null) -> void:
	_current = "0"
	_operand = 0.0
	_operator = ""
	_waiting_for_operand = false
	_expression = ""
	_update_display()

func btn_negate(event = null) -> void:
	var val: float = float(_current)
	if val != 0.0:
		_current = _format_number(-val)
	_update_display()

func btn_percent(event = null) -> void:
	var val: float = float(_current)
	_current = _format_number(val / 100.0)
	_update_display()

func _calculate(a: float, b: float, op: String) -> float:
	match op:
		"+":
			return a + b
		"-":
			return a - b
		"*":
			return a * b
		"/":
			if b == 0.0:
				return NAN
			return a / b
	return b

func _format_number(val: float) -> String:
	if is_nan(val) or is_inf(val):
		return "Error"
	if val == floor(val) and abs(val) < 1e15:
		return str(int(val))
	return "%.10g" % val

func _operator_symbol(op: String) -> String:
	match op:
		"+": return "+"
		"-": return "−"
		"*": return "×"
		"/": return "÷"
	return op

func _update_display() -> void:
	if state == null:
		return
	# When waiting for operand (just pressed operator), show empty
	# so it doesn't look like the expression is already complete
	if _waiting_for_operand and _operator != "":
		state.set_many({
			"display": "",
			"expression": _expression,
		})
	else:
		state.set_many({
			"display": _current,
			"expression": _expression,
		})
