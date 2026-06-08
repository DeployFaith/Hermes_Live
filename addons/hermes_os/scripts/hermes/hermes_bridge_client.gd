class_name HermesBridgeClient
extends Node

const HermesProtocol = preload("res://addons/hermes_os/scripts/hermes/hermes_protocol.gd")

signal connected
signal disconnected
signal message_received(message: Dictionary)
signal protocol_error(error: Dictionary)

var _peer := WebSocketPeer.new()
var _url := ""
var _was_connected := false

func connect_to_endpoint(url: String) -> String:
	var target := url.strip_edges()
	if target == "":
		return "Endpoint URL is required"
	var state := _peer.get_ready_state()
	if _url == target and (state == WebSocketPeer.STATE_CONNECTING or state == WebSocketPeer.STATE_OPEN):
		set_process(true)
		return ""
	if state == WebSocketPeer.STATE_CONNECTING or state == WebSocketPeer.STATE_OPEN:
		var should_emit_disconnect := _was_connected or state == WebSocketPeer.STATE_OPEN
		_peer.close(1000, "reconnect")
		_peer = WebSocketPeer.new()
		_was_connected = false
		if should_emit_disconnect:
			disconnected.emit()
	_url = target
	var status := _peer.connect_to_url(_url)
	if status != OK:
		return "WebSocket connect failed: %s" % str(status)
	set_process(true)
	return ""

func close_connection(code := 1000, reason := "client_close") -> void:
	if _peer.get_ready_state() == WebSocketPeer.STATE_OPEN or _peer.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		_peer.close(code, reason)

func is_connected_to_backend() -> bool:
	return _peer.get_ready_state() == WebSocketPeer.STATE_OPEN

func send_message(message: Dictionary) -> String:
	if not is_connected_to_backend():
		return "Bridge is not connected"
	var payload := JSON.stringify(message)
	var status := _peer.send_text(payload)
	if status != OK:
		return "Failed to send bridge message: %s" % str(status)
	return ""

func _process(_delta: float) -> void:
	_peer.poll()

	var state := _peer.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN and not _was_connected:
		_was_connected = true
		connected.emit()
	elif state == WebSocketPeer.STATE_CLOSED and _was_connected:
		_was_connected = false
		disconnected.emit()

	if state != WebSocketPeer.STATE_OPEN:
		if state == WebSocketPeer.STATE_CLOSED:
			set_process(false)
		return

	while _peer.get_available_packet_count() > 0:
		var packet := _peer.get_packet()
		if not _peer.was_string_packet():
			protocol_error.emit(HermesProtocol.make_error("NON_TEXT_PACKET", "Received non-text websocket packet"))
			continue
		var text := packet.get_string_from_utf8()
		var parsed: Dictionary = HermesProtocol.parse_json_message(text)
		if not bool(parsed.get("ok", false)):
			protocol_error.emit(parsed.get("error", {}))
			continue
		message_received.emit(parsed.get("message", {}))
