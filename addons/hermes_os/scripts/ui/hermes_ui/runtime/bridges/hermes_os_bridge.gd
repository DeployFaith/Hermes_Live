class_name HermesOSBridge
extends RefCounted

const HermesAppBridge = preload("res://addons/hermes_os/scripts/ui/hermes_ui/runtime/bridges/hermes_app_bridge.gd")
const HermesWindowBridge = preload("res://addons/hermes_os/scripts/ui/hermes_ui/runtime/bridges/hermes_window_bridge.gd")
const HermesGatewayBridge = preload("res://addons/hermes_os/scripts/ui/hermes_ui/runtime/bridges/hermes_gateway_bridge.gd")
const HermesNotificationBridge = preload("res://addons/hermes_os/scripts/ui/hermes_ui/runtime/bridges/hermes_notification_bridge.gd")
const HermesSettingsBridge = preload("res://addons/hermes_os/scripts/ui/hermes_ui/runtime/bridges/hermes_settings_bridge.gd")
const HermesFileBridge = preload("res://addons/hermes_os/scripts/ui/hermes_ui/runtime/bridges/hermes_file_bridge.gd")

var apps: HermesAppBridge
var windows: HermesWindowBridge
var gateway: HermesGatewayBridge
var notifications: HermesNotificationBridge
var settings: HermesSettingsBridge
var files: HermesFileBridge
var context: Dictionary = {}

func setup(os_context: Dictionary) -> HermesOSBridge:
	context = os_context.duplicate(true)
	apps = HermesAppBridge.new().setup(context)
	windows = HermesWindowBridge.new().setup(context)
	gateway = HermesGatewayBridge.new().setup(context)
	notifications = HermesNotificationBridge.new().setup(context)
	settings = HermesSettingsBridge.new().setup(context)
	files = HermesFileBridge.new().setup(context)
	return self

func teardown() -> void:
	context.clear()
	apps = null
	windows = null
	gateway = null
	notifications = null
	settings = null
	files = null
