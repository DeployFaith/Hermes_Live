class_name HermesTheme
extends RefCounted

const DesignTokens = preload("res://addons/hermes_os/scripts/os/design_tokens.gd")
const StyleFactory = preload("res://addons/hermes_os/scripts/os/style_factory.gd")

const DEBUG_FALLBACK_COLOR := Color(1.0, 0.0, 1.0, 1.0)

# Kept for compatibility with audits/tests; color() uses _design_token_aliases()
# so shell theme-mode mutations of DesignTokens are reflected immediately.
static var DESIGN_TOKEN_ALIASES: Dictionary = {}
static var SYNTHETIC_COLORS: Dictionary = {}

static var SEMANTIC_KIND_MAP: Dictionary = {
	"info": "info",
	"success": "success",
	"warning": "warning",
	"danger": "danger",
	"error": "danger",
	"busy": "warning",
	"muted": "text_muted",
	"offline": "text_muted",
	"online": "success",
	"checking": "info",
	"unauthorized": "warning"
}

const SPACING: Dictionary = {
	"space_0": 0, "space_1": 4, "space_2": 8, "space_3": 12, "space_4": 16,
	"space_5": 20, "space_6": 24, "space_8": 32, "space_10": 40, "space_12": 48,
	"space_16": 64, "xs": 4, "sm": 8, "md": 12, "lg": 16, "xl": 24, "xxl": 32,
	"app_outer": 16, "panel": 16, "card": 14, "toolbar_gap": 8, "form_row_gap": 10,
	"section_gap": 16, "content_gap": 20, "major_gap": 24, "window_margin": 12
}

const RADII: Dictionary = {
	"radius_sm": 6, "radius_md": 10, "radius_lg": 14, "radius_xl": 18, "radius_pill": 999,
	"sm": 6, "md": 10, "lg": 14, "xl": 18, "pill": 999, "full": 999
}

const FONT_SIZES: Dictionary = {
	"text_xs": 11, "text_sm": 12, "text_base": 14, "text_md": 15, "text_lg": 18,
	"text_xl": 22, "text_title": 26, "app_title": 22, "toolbar_title": 18,
	"section_heading": 15, "body": 14, "helper": 12, "status": 12, "terminal": 13
}

const COMPONENT_SIZES: Dictionary = {
	"button": {"sm": 28, "md": 34, "lg": 40},
	"input": {"sm": 28, "md": 34, "lg": 40},
	"toolbar": {"md": 44},
	"status_bar": {"md": 28},
	"tab": {"md": 36},
	"sidebar": {"sm": 180, "md": 220},
	"list_row": {"md": 34},
	"table_row": {"md": 32},
	"icon": {"sm": 16, "md": 20, "lg": 28},
	"taskbar": {"md": 52},
	"window_titlebar": {"md": 36}
}

const SIZES: Dictionary = {
	"button_height_sm": 28,
	"button_height": 34,
	"button_height_lg": 40,
	"input_height": 34,
	"toolbar_height": 44,
	"status_bar_height": 28,
	"tab_height": 36,
	"sidebar_width": 220,
	"sidebar_width_sm": 180,
	"list_row_height": 34,
	"table_row_height": 32,
	"icon_size_sm": 16,
	"icon_size": 20,
	"icon_size_lg": 28,
	"taskbar_height": 52,
	"window_titlebar_height": 36
}

const DURATIONS: Dictionary = {
	"duration_fast": 0.10, "duration_normal": 0.18, "duration_slow": 0.28,
	"fast": 0.10, "normal": 0.18, "slow": 0.28
}

const EASINGS: Dictionary = {
	"in": Tween.EASE_IN,
	"out": Tween.EASE_OUT,
	"in_out": Tween.EASE_IN_OUT,
	"normal": Tween.EASE_IN_OUT
}

var _theme_resource: Theme

func refresh() -> void:
	_theme_resource = null

func _design_token_aliases() -> Dictionary:
	return {
		"bg": DesignTokens.BG,
		"desktop_bg": DesignTokens.BG,
		"bg_elevated": DesignTokens.BG_ELEVATED,
		"window": DesignTokens.WINDOW,
		"surface": DesignTokens.PANEL,
		"surface_2": DesignTokens.SURFACE,
		"surface_3": DesignTokens.SURFACE_ACTIVE,
		"surface_hover": DesignTokens.SURFACE_HOVER,
		"input_bg": DesignTokens.INPUT_BG,
		"overlay": DesignTokens.OVERLAY,
		"border": DesignTokens.BORDER_ACTIVE,
		"border_soft": DesignTokens.BORDER,
		"border_subtle": DesignTokens.BORDER_SOFT,
		"border_active": DesignTokens.BORDER_ACTIVE,
		"border_strong": DesignTokens.BORDER_STRONG,
		"focus": DesignTokens.FOCUS,
		"focus_ring": DesignTokens.FOCUS,
		"text": DesignTokens.TEXT,
		"text_muted": DesignTokens.TEXT_MUTED,
		"text_faint": DesignTokens.TEXT_FAINT,
		"text_disabled": DesignTokens.TEXT_DISABLED,
		"accent": DesignTokens.ACCENT,
		"accent_hover": DesignTokens.ACCENT_HOVER,
		"accent_pressed": DesignTokens.ACCENT_PRESSED,
		"on_accent": DesignTokens.ON_ACCENT,
		"info": DesignTokens.INFO,
		"success": DesignTokens.SUCCESS,
		"warning": DesignTokens.WARNING,
		"danger": DesignTokens.ERROR,
		"error": DesignTokens.ERROR
	}

func _synthetic_colors() -> Dictionary:
	return {
		"accent_soft": DesignTokens.alpha(DesignTokens.ACCENT, 0.15),
		"selection_bg": DesignTokens.alpha(DesignTokens.ACCENT, 0.16),
		"terminal_bg": Color("0D1117"),
		"terminal_text": Color("D6DEE8"),
		"terminal_prompt": DesignTokens.ACCENT,
		"terminal_muted": Color("7D8796"),
		"terminal_error": Color("F87171"),
		"terminal_success": Color("4ADE80")
	}

func has_color(name: String) -> bool:
	var clean: String = name.strip_edges()
	var aliases: Dictionary = _design_token_aliases()
	return aliases.has(clean) or _synthetic_colors().has(clean)

func color(name: String, warn_on_missing: bool = true) -> Color:
	var clean: String = name.strip_edges()
	var aliases: Dictionary = _design_token_aliases()
	var synthetic: Dictionary = _synthetic_colors()
	if aliases.has(clean):
		return aliases[clean]
	if synthetic.has(clean):
		return synthetic[clean]
	if warn_on_missing:
		_warn_unknown("color", clean)
	return DEBUG_FALLBACK_COLOR

func kind_color(kind: String) -> Color:
	return color(str(SEMANTIC_KIND_MAP.get(kind.strip_edges(), "info")))

func kind_text_color(kind: String) -> Color:
	var clean: String = kind.strip_edges()
	if clean == "muted" or clean == "offline":
		return color("text_muted")
	return kind_color(clean)

func spacing(name_or_value: Variant) -> int:
	if name_or_value is int:
		return int(name_or_value)
	if name_or_value is float:
		return int(round(float(name_or_value)))
	var key: String = str(name_or_value)
	if SPACING.has(key):
		return int(SPACING[key])
	_warn_unknown("spacing", key)
	return 0

func radius(name_or_value: Variant) -> int:
	if name_or_value is int:
		return int(name_or_value)
	if name_or_value is float:
		return int(round(float(name_or_value)))
	var key: String = str(name_or_value)
	if RADII.has(key):
		return int(RADII[key])
	_warn_unknown("radius", key)
	return 0

func font_size(name_or_value: Variant) -> int:
	if name_or_value is int:
		return int(name_or_value)
	if name_or_value is float:
		return int(round(float(name_or_value)))
	var key: String = str(name_or_value)
	if FONT_SIZES.has(key):
		return int(FONT_SIZES[key])
	_warn_unknown("font_size", key)
	return int(FONT_SIZES["text_base"])

func duration(name: String) -> float:
	if DURATIONS.has(name):
		return float(DURATIONS[name])
	_warn_unknown("duration", name)
	return float(DURATIONS["duration_normal"])

func easing(name: String) -> int:
	if EASINGS.has(name):
		return int(EASINGS[name])
	_warn_unknown("easing", name)
	return Tween.EASE_OUT

func size(name: String) -> int:
	if SIZES.has(name):
		return int(SIZES[name])
	_warn_unknown("size", name)
	return 0

func component_size(component: String, p_size: String = "md") -> int:
	var sizes: Dictionary = COMPONENT_SIZES.get(component, {}) if COMPONENT_SIZES.get(component, {}) is Dictionary else {}
	if sizes.has(p_size):
		return int(sizes[p_size])
	_warn_unknown("component_size", component + "." + p_size)
	return 0

func build_theme() -> Theme:
	if _theme_resource != null:
		return _theme_resource
	var theme := Theme.new()
	theme.set_color("font_color", "Label", color("text"))
	theme.set_color("font_color", "Button", color("text"))
	theme.set_color("font_hover_color", "Button", color("text"))
	theme.set_color("font_pressed_color", "Button", color("text"))
	theme.set_color("font_disabled_color", "Button", color("text_disabled"))
	theme.set_color("font_color", "LineEdit", color("text"))
	theme.set_color("font_placeholder_color", "LineEdit", color("text_faint"))
	theme.set_color("font_color", "TextEdit", color("text"))
	theme.set_color("font_placeholder_color", "TextEdit", color("text_faint"))
	theme.set_color("font_color", "OptionButton", color("text"))
	theme.set_color("font_color", "CheckBox", color("text"))
	theme.set_font_size("font_size", "Label", font_size("text_base"))
	theme.set_font_size("font_size", "Button", font_size("text_base"))
	theme.set_font_size("font_size", "LineEdit", font_size("text_base"))
	theme.set_font_size("font_size", "TextEdit", font_size("text_base"))
	theme.set_stylebox("panel", "PanelContainer", panel_style())
	theme.set_stylebox("normal", "Button", button_style("secondary", "normal"))
	theme.set_stylebox("hover", "Button", button_style("secondary", "hover"))
	theme.set_stylebox("pressed", "Button", button_style("secondary", "pressed"))
	theme.set_stylebox("disabled", "Button", button_style("secondary", "disabled"))
	theme.set_stylebox("focus", "Button", button_style("secondary", "focused"))
	theme.set_stylebox("normal", "LineEdit", input_style("normal"))
	theme.set_stylebox("focus", "LineEdit", input_style("focused"))
	theme.set_stylebox("read_only", "LineEdit", input_style("disabled"))
	theme.set_stylebox("normal", "TextEdit", text_area_style("normal"))
	theme.set_stylebox("focus", "TextEdit", text_area_style("focused"))
	theme.set_stylebox("read_only", "TextEdit", text_area_style("disabled"))
	# Common Godot controls used by HermesUI primitives. These overrides keep raw
	# controls visually aligned when a component cannot fully wrap the widget.
	theme.set_stylebox("normal", "OptionButton", input_style("normal"))
	theme.set_stylebox("hover", "OptionButton", input_style("normal"))
	theme.set_stylebox("focus", "OptionButton", input_style("focused"))
	theme.set_stylebox("disabled", "OptionButton", input_style("disabled"))
	theme.set_stylebox("panel", "PopupMenu", option_popup_style())
	theme.set_color("font_hover_color", "PopupMenu", color("text"))
	theme.set_color("font_color", "PopupMenu", color("text"))
	theme.set_color("font_disabled_color", "PopupMenu", color("text_disabled"))
	theme.set_stylebox("scroll", "VScrollBar", scrollbar_track_style())
	theme.set_stylebox("scroll", "HScrollBar", scrollbar_track_style())
	theme.set_stylebox("grabber", "VScrollBar", scrollbar_grabber_style())
	theme.set_stylebox("grabber_highlight", "VScrollBar", scrollbar_grabber_style("hover"))
	theme.set_stylebox("grabber_pressed", "VScrollBar", scrollbar_grabber_style("pressed"))
	theme.set_stylebox("grabber", "HScrollBar", scrollbar_grabber_style())
	theme.set_stylebox("grabber_highlight", "HScrollBar", scrollbar_grabber_style("hover"))
	theme.set_stylebox("grabber_pressed", "HScrollBar", scrollbar_grabber_style("pressed"))
	theme.set_stylebox("background", "ProgressBar", progress_bg_style())
	theme.set_stylebox("fill", "ProgressBar", progress_fill_style("info"))
	theme.set_color("font_color", "ProgressBar", color("text"))
	theme.set_stylebox("slider", "HSlider", slider_track_style())
	theme.set_stylebox("grabber_area", "HSlider", slider_track_style())
	theme.set_stylebox("grabber_area_highlight", "HSlider", slider_track_style())
	theme.set_stylebox("grabber", "HSlider", slider_grabber_style())
	theme.set_stylebox("grabber_highlight", "HSlider", slider_grabber_style("hover"))
	theme.set_stylebox("grabber_disabled", "HSlider", slider_grabber_style("disabled"))
	theme.set_stylebox("panel", "ItemList", panel_style({"bg": color("input_bg"), "border": color("border_soft"), "radius": "md"}))
	theme.set_stylebox("selected", "ItemList", list_row_style("selected"))
	theme.set_stylebox("selected_focus", "ItemList", list_row_style("selected"))
	theme.set_stylebox("panel", "Tree", panel_style({"bg": color("input_bg"), "border": color("border_soft"), "radius": "md"}))
	theme.set_stylebox("selected", "Tree", list_row_style("selected"))
	theme.set_stylebox("selected_focus", "Tree", list_row_style("selected"))
	_theme_resource = theme
	return _theme_resource

func apply_to(control: Control) -> void:
	if control == null:
		return
	control.theme = build_theme()

func panel_style(options: Dictionary = {}) -> StyleBoxFlat:
	# Major app containers: calm panel surface, usually one border max.
	var bg: Color = options.get("bg", color("surface"))
	var border: Color = options.get("border", color("border_soft"))
	var style := _base_style(bg, border, int(options.get("border_width", 1)), radius(options.get("radius", "lg")))
	_set_padding(style, int(options.get("padding", spacing("panel"))))
	var elevation: int = int(options.get("elevation", 0))
	if elevation > 0:
		_apply_shadow(style, elevation)
	return style

func card_style(options: Dictionary = {}) -> StyleBoxFlat:
	# Cards sit one layer above panels; use subtle depth and softer borders.
	var bg: Color = options.get("bg", color("surface_2"))
	var border: Color = options.get("border", color("border_soft"))
	var style := _base_style(bg, border, int(options.get("border_width", 1)), radius(options.get("radius", "lg")))
	_set_padding(style, int(options.get("padding", spacing("card"))))
	# Cards get elevation 1 by default for visual depth
	var elevation: int = int(options.get("elevation", 1))
	_apply_shadow(style, elevation)
	return style

func elevated_style(options: Dictionary = {}) -> StyleBoxFlat:
	var bg: Color = options.get("bg", color("surface_2"))
	var border: Color = options.get("border", color("border"))
	var style := _base_style(bg, border, int(options.get("border_width", 1)), radius(options.get("radius", "lg")))
	_set_padding(style, int(options.get("padding", spacing("panel"))))
	# Elevated surfaces get medium shadow
	_apply_shadow(style, 2)
	return style

func context_menu_style(options: Dictionary = {}) -> StyleBoxFlat:
	var style := panel_style(options)
	_apply_shadow(style, 2)
	return style

func button_style(variant: String = "secondary", state: String = "normal", options: Dictionary = {}) -> StyleBoxFlat:
	var radius_value: int = radius(options.get("radius", "md"))
	var bg: Color = color("surface_2")
	var border: Color = color("border_soft")
	var border_width: int = 1
	var text_color_override: Color = Color()  # zero = use default theme text color
	match variant:
		"primary":
			bg = color("accent")
			border = color("accent_hover")
			text_color_override = color("on_accent")
		"ghost":
			bg = Color.TRANSPARENT
			border = Color.TRANSPARENT
		"danger":
			bg = DesignTokens.alpha(color("danger"), 0.24)
			border = DesignTokens.alpha(color("danger"), 0.52)
		"success":
			bg = DesignTokens.alpha(color("success"), 0.22)
			border = DesignTokens.alpha(color("success"), 0.50)
		_:
			bg = DesignTokens.alpha(color("surface_2"), 0.92)
			border = color("border_soft")
	match state:
		"hover":
			if variant == "primary":
				bg = color("accent_hover")
			elif variant == "ghost":
				bg = DesignTokens.alpha(color("surface_3"), 0.55)
			else:
				bg = color("surface_3")
			border = color("border")
		"pressed":
			bg = color("accent_pressed") if variant == "primary" else DesignTokens.alpha(bg, 0.74)
		"disabled":
			bg = DesignTokens.alpha(color("surface"), 0.34)
			border = DesignTokens.alpha(color("border_soft"), 0.45)
		"focused":
			bg = Color.TRANSPARENT if variant == "ghost" else bg
			border = color("focus_ring")
			border_width = 2
	var style := _base_style(bg, border, border_width, radius_value)
	style.content_margin_left = int(options.get("padding_h", 12))
	style.content_margin_right = int(options.get("padding_h", 12))
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	if text_color_override != Color():
		style.set_meta("hermes_ui_text_color", text_color_override)
	return style

func input_style(state: String = "normal", options: Dictionary = {}) -> StyleBoxFlat:
	var bg: Color = color("input_bg")
	var border: Color = color("border")
	var border_width: int = 1
	if state == "focused":
		border = color("focus_ring")
		border_width = 2
	elif state == "disabled":
		bg = DesignTokens.alpha(color("bg_elevated"), 0.55)
		border = color("border_soft")
	var style := _base_style(bg, border, border_width, radius(options.get("radius", "md")))
	style.content_margin_left = int(options.get("padding_h", 10))
	style.content_margin_right = int(options.get("padding_h", 10))
	style.content_margin_top = int(options.get("padding_v", 6))
	style.content_margin_bottom = int(options.get("padding_v", 6))
	return style

func text_area_style(state: String = "normal", options: Dictionary = {}) -> StyleBoxFlat:
	var style := input_style(state, options)
	_set_padding(style, int(options.get("padding", 10)))
	return style

func list_row_style(state: String = "normal", options: Dictionary = {}) -> StyleBoxFlat:
	var bg: Color = Color.TRANSPARENT
	var border: Color = Color.TRANSPARENT
	var border_width: int = 0
	match state:
		"hover":
			bg = DesignTokens.alpha(color("surface_3"), 0.45)
		"selected":
			bg = color("accent_soft")
			border = DesignTokens.alpha(color("accent"), 0.35)
			border_width = 1
		"disabled":
			bg = DesignTokens.alpha(color("surface"), 0.28)
		_:
			bg = options.get("bg", Color.TRANSPARENT)
	var style := _base_style(bg, border, border_width, radius(options.get("radius", "sm")))
	style.content_margin_left = int(options.get("padding_h", 10))
	style.content_margin_right = int(options.get("padding_h", 10))
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func badge_style(kind: String = "info", options: Dictionary = {}) -> StyleBoxFlat:
	var c: Color = kind_color(kind)
	# Badges are subtle status indicators - use low alpha for calm, non-distracting appearance
	var bg_alpha: float = 0.10
	var border_alpha: float = 0.24
	match kind:
		"success":
			bg_alpha = 0.11
			border_alpha = 0.28
		"danger", "error", "warning":
			bg_alpha = 0.12
			border_alpha = 0.30
	var style := _base_style(DesignTokens.alpha(c, bg_alpha), DesignTokens.alpha(c, border_alpha), 1, radius(options.get("radius", "pill")))
	style.content_margin_left = int(options.get("padding_h", 8))
	style.content_margin_right = int(options.get("padding_h", 8))
	style.content_margin_top = int(options.get("padding_v", 3))
	style.content_margin_bottom = int(options.get("padding_v", 3))
	return style

func scrollbar_grabber_style(state: String = "normal") -> StyleBoxFlat:
	var bg: Color = DesignTokens.alpha(color("border_active"), 0.70)
	if state == "hover":
		bg = DesignTokens.alpha(color("accent"), 0.55)
	elif state == "pressed":
		bg = DesignTokens.alpha(color("accent"), 0.72)
	return _base_style(bg, Color.TRANSPARENT, 0, radius("pill"))

func scrollbar_track_style() -> StyleBoxFlat:
	return _base_style(DesignTokens.alpha(color("bg"), 0.24), Color.TRANSPARENT, 0, radius("pill"))

func progress_bg_style() -> StyleBoxFlat:
	return _base_style(color("input_bg"), color("border_soft"), 1, radius("pill"))

func progress_fill_style(kind: String = "info") -> StyleBoxFlat:
	return _base_style(kind_color(kind), Color.TRANSPARENT, 0, radius("pill"))

func slider_track_style() -> StyleBoxFlat:
	var style := _base_style(color("border_soft"), Color.TRANSPARENT, 0, radius("pill"))
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func slider_grabber_style(state: String = "normal") -> StyleBoxFlat:
	var c: Color = color("accent") if state != "disabled" else color("text_disabled")
	return _base_style(c, DesignTokens.alpha(color("on_accent"), 0.24), 1, radius("pill"))

func option_popup_style() -> StyleBoxFlat:
	var style := panel_style({"bg": color("surface"), "border": color("border"), "radius": "md", "padding": spacing("space_2"), "elevation": 2})
	return style

func divider_color() -> Color:
	return DesignTokens.alpha(color("border_soft"), 0.72)

func _base_style(bg: Color, border: Color, border_width: int, radius_value: int) -> StyleBoxFlat:
	return StyleFactory.build(bg, border, border_width, radius_value)

func _apply_shadow(style: StyleBoxFlat, elevation: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var shadow: Dictionary
	match elevation:
		0:
			shadow = DesignTokens.shadow_small()
		1:
			shadow = DesignTokens.shadow_medium()
		_:
			shadow = DesignTokens.shadow_large()
	style.shadow_size = shadow["size"]
	style.shadow_color = shadow["color"]
	style.shadow_offset = shadow["offset"]

func _set_padding(style: StyleBoxFlat, padding: int) -> void:
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding

func _warn_unknown(kind: String, name: String) -> void:
	push_warning("HermesTheme unknown %s token: %s" % [kind, name])
