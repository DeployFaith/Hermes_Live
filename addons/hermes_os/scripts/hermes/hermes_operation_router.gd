class_name HermesOperationRouter
extends RefCounted

const HermesProtocol = preload("res://addons/hermes_os/scripts/hermes/hermes_protocol.gd")

var _kernel: Node

func setup(kernel: Node) -> void:
	_kernel = kernel

func execute(op: String, args: Dictionary, request_id := "") -> Dictionary:
	if _kernel == null:
		return {
			"ok": false,
			"error": HermesProtocol.make_error("KERNEL_UNAVAILABLE", "Kernel is not attached to operation router")
		}
	if op.strip_edges() == "":
		return {
			"ok": false,
			"error": HermesProtocol.make_error("MISSING_OPERATION", "Operation name is required")
		}
	if not _kernel.is_operation_declared(op):
		if not _kernel.should_allow_undeclared_operation(op, args):
			return {
				"ok": false,
				"error": HermesProtocol.make_error("UNDECLARED_OPERATION", "Operation is not declared in manifest: " + op)
			}
	if op.begins_with("os."):
		return _kernel.route_os_operation(op, args, request_id)
	if op.begins_with("game."):
		return _kernel.route_game_operation(op, args, request_id)
	return _kernel.route_shell_operation(op, args, request_id)
