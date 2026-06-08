class_name HermesShellContext
extends RefCounted

var _values: Dictionary = {}

func setup(values: Dictionary = {}) -> HermesShellContext:
	_values = values.duplicate(true)
	return self

func to_dictionary() -> Dictionary:
	return _values.duplicate(true)

func has_value(key: StringName) -> bool:
	return _values.has(str(key))

func value(key: StringName, default_value: Variant = null) -> Variant:
	return _values.get(str(key), default_value)

func object_value(key: StringName) -> Object:
	var item: Variant = value(key, null)
	return item as Object

func callable_value(key: StringName) -> Callable:
	var item: Variant = value(key, Callable())
	if item is Callable:
		return item as Callable
	return Callable()

func merged(extra_values: Dictionary = {}) -> HermesShellContext:
	var merged_values: Dictionary = to_dictionary()
	for key in extra_values.keys():
		merged_values[key] = extra_values[key]
	return HermesShellContext.new().setup(merged_values)

func call_action(key: StringName, args: Array = []) -> Variant:
	var action: Callable = callable_value(key)
	if not action.is_valid():
		return null
	return action.callv(args)
