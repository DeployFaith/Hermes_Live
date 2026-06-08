class_name DesignTokens
extends RefCounted

# HermesUI v2 design tokens.
# Single source for the calm, dark, Linux-like desktop palette used by shell chrome,
# HermesUI components, and app surfaces. Keep these values quiet and legible: use
# layer contrast, spacing, and elevation before adding outlines/glow.

# ── Surface Colors (stronger semantic luminance steps for tonal hierarchy: desktop darkest, then shell surfaces, window titlebar/chrome, app main body, subpanels/cards, interactive rows/controls) ──
static var BG := Color("0a0c11")
static var BG_ELEVATED := Color("0f1219")
static var PANEL := Color("15191f")
static var SURFACE := Color("1c212a")
static var SURFACE_HOVER := Color("22283a")
static var SURFACE_ACTIVE := Color("282e40")
static var WINDOW := Color("1f2430")
static var INPUT_BG := Color("0d1017")
static var OVERLAY := Color("04060a")

# Semantic surface levels (shell surface, window body surface, subpanel surface, elevated card/row surface, accent-selected surface)
static var SHELL_SURFACE := Color("12151c")
static var APP_BODY_SURFACE := Color("1f2430")
static var SUBPANEL_SURFACE := Color("252b38")
static var ELEVATED_CARD := Color("2a2f3d")
static var ACCENT_SELECTED_SURFACE := Color("303747")

# ── Desktop Depth (layered gradient + noise + vignette for modern dark desktop) ──
static var DESKTOP_GRADIENT_TOP := Color("0F1116")
static var DESKTOP_GRADIENT_BOTTOM := Color("161A22")
static var DESKTOP_NOISE_OPACITY := 0.025
static var DESKTOP_VIGNETTE_OPACITY := 0.18
static var DESKTOP_MICRO_PATTERN_OPACITY := 0.015
static var DESKTOP_ELEVATION := 0

# ── Brighter Wallpaper Presets (+45-60% luminance, tasteful modern, soft color variation + subtle light blooms/gradients, some carry accent influence; desktop feels like real Linux PC) ──
static var WALLPAPER_BRIGHT_PRESETS: Array[Color] = _to_color_array([
	Color("4a5f7b"),  # brighter blue-gray
	Color("5e6f8a"),  # soft teal-gray
	Color("6a7f9b"),  # muted slate
	Color("4b6a72"),  # accent-tinted green-gray
	Color("5a6a7a")   # warm neutral
])

# ── Border / Focus Colors ──
static var BORDER_SOFT := Color("252b38")
static var BORDER := Color("3b4355")
static var BORDER_ACTIVE := Color("4b556d")
static var BORDER_STRONG := Color("616d88")
static var FOCUS := Color("8cbcff")

# ── Text Colors ──
static var TEXT := Color("eceff6")
static var TEXT_MUTED := Color("9aa3b8")
# Back-compat alias used in existing shell code
static var MUTED := TEXT_MUTED
static var TEXT_FAINT := Color("737d94")
static var TEXT_DISABLED := Color("5f687d")

# ── Accent / Status Colors ──
static var ACCENT := Color("6fa8f7")
static var ACCENT_HOVER := Color("8bbcff")
static var ACCENT_PRESSED := Color("4f86d9")
# Dark text for use on accent/primary surfaces
static var ON_ACCENT := Color("08111f")
static var INFO := Color("6fa8f7")
static var SUCCESS := Color("6fbd8a")
static var WARNING := Color("d7a95f")
static var ERROR := Color("e06f7f")
static var WHITE := Color.WHITE

# ── Opacity Helpers ──
static func alpha(color: Color, a: float) -> Color:
	return Color(color.r, color.g, color.b, a)

static func accent_hover_color(accent: Color) -> Color:
	return Color(
		minf(accent.r + 0.14, 1.0),
		minf(accent.g + 0.14, 1.0),
		minf(accent.b + 0.14, 1.0),
		1.0
	)

static func accent_pressed_color(accent: Color) -> Color:
	return Color(
		maxf(accent.r - 0.14, 0.0),
		maxf(accent.g - 0.14, 0.0),
		maxf(accent.b - 0.14, 0.0),
		1.0
	)

static func set_accent(accent: Color) -> Color:
	ACCENT = Color(accent.r, accent.g, accent.b, 1.0)
	ACCENT_HOVER = accent_hover_color(ACCENT)
	ACCENT_PRESSED = accent_pressed_color(ACCENT)
	return ACCENT

# Narrow typed conversion helper at preset boundary (WALLPAPER_BRIGHT_PRESETS)
static func _to_color_array(values: Array) -> Array[Color]:
	var output: Array[Color] = []
	for value in values:
		if value is Color:
			output.append(value)
	return output

# ── Spacing ──
static var SPACE := {
	"xxs": 2,
	"xs": 4,
	"sm": 8,
	"md": 12,
	"lg": 16,
	"xl": 24,
	"xxl": 32,
	"xxxl": 48
}

# ── Corner Radii ──
static var RADIUS := {
	"xs": 4,
	"sm": 6,
	"md": 10,
	"lg": 14,
	"xl": 18,
	"full": 999
}

# ── Animation Timing ──
static var TIME := {
	"instant": 0.06,
	"fast": 0.10,
	"normal": 0.18,
	"slow": 0.28,
	"slower": 0.42
}

# ── Elevation / Shadow Presets ──
static var ELEVATION := {
	"flat": 0,
	"raised": 1,
	"floating": 2,
	"modal": 3
}

static func shadow_small() -> Dictionary:
	return {"size": 6, "color": Color(0, 0, 0, 0.22), "offset": Vector2(0, 2)}

static func shadow_medium() -> Dictionary:
	return {"size": 12, "color": Color(0, 0, 0, 0.32), "offset": Vector2(0, 4)}

static func shadow_large() -> Dictionary:
	return {"size": 22, "color": Color(0, 0, 0, 0.42), "offset": Vector2(0, 8)}

# ── Typography ──
static var TYPE := {
	"display": {"size": 22, "color": TEXT, "line_height": 28},
	"title": {"size": 16, "color": TEXT, "line_height": 22},
	"body": {"size": 13, "color": TEXT, "line_height": 19},
	"caption": {"size": 11, "color": TEXT_MUTED, "line_height": 16},
	"label": {"size": 12, "color": TEXT_MUTED, "line_height": 18},
	"mono": {"size": 13, "color": TEXT, "line_height": 19}
}
