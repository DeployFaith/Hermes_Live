class_name IconAtlas
extends RefCounted

const BASE_SVG_SIZE: float = 24.0

const ICON_PATHS: Dictionary = {
	"folder": "res://addons/hermes_os/assets/icons/folder.svg",
	"files": "res://addons/hermes_os/assets/icons/folder.svg",
	"file": "res://addons/hermes_os/assets/icons/file-text.svg",
	"text": "res://addons/hermes_os/assets/icons/file-text.svg",
	"notes": "res://addons/hermes_os/assets/icons/sticky-note.svg",
	"browser": "res://addons/hermes_os/assets/icons/globe.svg",
	"web": "res://addons/hermes_os/assets/icons/globe.svg",
	"network": "res://addons/hermes_os/assets/icons/globe.svg",
	"terminal": "res://addons/hermes_os/assets/icons/terminal.svg",
	"console": "res://addons/hermes_os/assets/icons/terminal.svg",
	"code": "res://addons/hermes_os/assets/icons/code-2.svg",
	"programming": "res://addons/hermes_os/assets/icons/code-2.svg",
	"settings": "res://addons/hermes_os/assets/icons/settings.svg",
	"system": "res://addons/hermes_os/assets/icons/settings.svg",
	"command_palette": "res://addons/hermes_os/assets/icons/grid-2x2.svg",
	"command": "res://addons/hermes_os/assets/icons/grid-2x2.svg",
	"hermes_chat": "res://addons/hermes_os/assets/icons/circle-help.svg",
	"hermes": "res://addons/hermes_os/assets/icons/circle-help.svg",
	"start": "res://addons/hermes_os/assets/icons/start.svg",
	"home": "res://addons/hermes_os/assets/icons/home.svg",
	"wifi": "res://addons/hermes_os/assets/icons/wifi.svg",
	"volume": "res://addons/hermes_os/assets/icons/volume-2.svg",
	"bluetooth": "res://addons/hermes_os/assets/icons/bluetooth.svg",
	"battery": "res://addons/hermes_os/assets/icons/battery.svg",
	"notification": "res://addons/hermes_os/assets/icons/bell.svg",
	"bell": "res://addons/hermes_os/assets/icons/bell.svg",
	"session": "res://addons/hermes_os/assets/icons/power.svg",
	"power": "res://addons/hermes_os/assets/icons/power.svg",
	"lock": "res://addons/hermes_os/assets/icons/lock.svg",
	"user": "res://addons/hermes_os/assets/icons/user.svg",
	"account": "res://addons/hermes_os/assets/icons/user.svg",
	"placeholder": "res://addons/hermes_os/assets/icons/circle-help.svg",
}

var _cache: Dictionary = {}
var _missing_warnings: Dictionary = {}
var _icon_color: Color = Color("e8eaf0")

func set_icon_color(color: Color) -> void:
	if _icon_color.is_equal_approx(color):
		return
	_icon_color = color
	_cache.clear()

func get_icon(name: String, size: int = 20) -> Texture2D:
	var clean_name: String = name.strip_edges().to_lower()
	var clean_size: int = maxi(size, 12)
	var key: String = "%s_%d" % [clean_name, clean_size]
	if _cache.has(key):
		return _cache[key]

	var tex: Texture2D = _load_asset_icon(clean_name, clean_size)
	if tex == null:
		_warn_missing(clean_name)
		tex = _make_fallback_icon(clean_size)
	_cache[key] = tex
	return tex

func has_asset(name: String) -> bool:
	var clean_name: String = name.strip_edges().to_lower()
	var path: String = str(ICON_PATHS.get(clean_name, ""))
	return path != "" and FileAccess.file_exists(path)

func _load_asset_icon(name: String, size: int) -> Texture2D:
	var path: String = str(ICON_PATHS.get(name, ""))
	if path == "" or not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var svg_text: String = _tint_svg(file.get_as_text())
	var image: Image = Image.new()
	var scale: float = float(size) / BASE_SVG_SIZE
	var err: Error = image.load_svg_from_string(svg_text, scale)
	if err != OK or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)

func _tint_svg(svg_text: String) -> String:
	var hex_color: String = _color_to_hex(_icon_color)
	var tinted: String = svg_text.replace("currentColor", hex_color)
	tinted = tinted.replace("stroke=\"#000000\"", "stroke=\"" + hex_color + "\"")
	tinted = tinted.replace("stroke=\"#000\"", "stroke=\"" + hex_color + "\"")
	return tinted

func _color_to_hex(color: Color) -> String:
	var r: int = int(round(clampf(color.r, 0.0, 1.0) * 255.0))
	var g: int = int(round(clampf(color.g, 0.0, 1.0) * 255.0))
	var b: int = int(round(clampf(color.b, 0.0, 1.0) * 255.0))
	return "#%02x%02x%02x" % [r, g, b]

func _warn_missing(name: String) -> void:
	if _missing_warnings.has(name):
		return
	_missing_warnings[name] = true
	push_warning("Missing HermesOS icon asset for key: " + name)

func _make_fallback_icon(size: int) -> Texture2D:
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var pad: int = maxi(1, int(size * 0.16))
	var rect: Rect2i = Rect2i(pad, pad, size - pad * 2, size - pad * 2)
	var bg: Color = Color(0.85, 0.25, 0.35, 0.92)
	var fg: Color = Color(1, 1, 1, 0.95)
	image.fill_rect(rect, bg)
	for i in range(rect.size.x):
		var x1: int = rect.position.x + i
		var y1: int = rect.position.y + i
		var y2: int = rect.position.y + rect.size.y - 1 - i
		if y1 >= rect.position.y and y1 < rect.position.y + rect.size.y:
			image.set_pixel(x1, y1, fg)
		if y2 >= rect.position.y and y2 < rect.position.y + rect.size.y:
			image.set_pixel(x1, y2, fg)
	return ImageTexture.create_from_image(image)
