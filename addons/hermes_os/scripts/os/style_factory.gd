class_name StyleFactory
extends RefCounted

const Tokens := preload("res://addons/hermes_os/scripts/os/design_tokens.gd")

static func build(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.anti_aliasing = true
	return style

static func _apply_shadow(style: StyleBoxFlat, preset: Dictionary, alpha_scale: float = 1.0) -> void:
	# shadow_size assignment can crash Godot headless in this project; keep style
	# construction parse/smoke-safe and only apply shadows in live rendering.
	if DisplayServer.get_name() == "headless":
		return
	style.shadow_size = int(preset.get("size", 0))
	var color: Color = preset.get("color", Color(0, 0, 0, 0.0))
	style.shadow_color = Color(color.r, color.g, color.b, color.a * alpha_scale)
	style.shadow_offset = preset.get("offset", Vector2.ZERO)

static func _padding(style: StyleBoxFlat, h: int, v: int) -> StyleBoxFlat:
	style.content_margin_left = h
	style.content_margin_right = h
	style.content_margin_top = v
	style.content_margin_bottom = v
	return style

static func glass_panel(bg_alpha: float, border_color_override: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var bg := Tokens.alpha(Tokens.PANEL, bg_alpha)
	var border := border_color_override
	if border == Color.TRANSPARENT:
		border = Tokens.alpha(Tokens.WHITE, 0.07)
	var style := build(bg, border, border_width, radius)
	_apply_shadow(style, Tokens.shadow_medium())
	return style

static func solid_panel(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	return build(bg, border, border_width, radius)

static func elevated_panel(elevation: int, bg_alpha: float, radius: int) -> StyleBoxFlat:
	var bg := Tokens.alpha(Tokens.PANEL, bg_alpha)
	var border := Tokens.alpha(Tokens.BORDER_ACTIVE, 0.36 + elevation * 0.08)
	var style := build(bg, border, 1 if elevation > 0 else 0, radius)
	match elevation:
		0:
			_apply_shadow(style, Tokens.shadow_small(), 0.70)
		1:
			_apply_shadow(style, Tokens.shadow_medium(), 0.85)
		2:
			_apply_shadow(style, Tokens.shadow_large(), 0.95)
		_:
			_apply_shadow(style, Tokens.shadow_medium(), 0.85)
	return style

static func window_active(radius: int) -> StyleBoxFlat:
	# Focused/inactive via subtle shadow/titlebar opacity. No multiple nested full-rect borders.
	var style := build(Tokens.alpha(Tokens.WINDOW, 0.98), Color.TRANSPARENT, 0, radius)
	_apply_shadow(style, Tokens.shadow_large())
	return style

static func window_inactive(radius: int) -> StyleBoxFlat:
	# Inactive: muted, softer shadow
	var style := build(Tokens.alpha(Tokens.WINDOW, 0.92), Color.TRANSPARENT, 0, radius)
	_apply_shadow(style, Tokens.shadow_medium(), 0.65)
	return style

static func title_bar(active: bool, radius: int) -> StyleBoxFlat:
	# Titlebar integrated (border=0). Focused/inactive via subtle shadow/titlebar opacity.
	# Bottom radius 0 to blend with body, one primary outer background.
	var bg := Tokens.alpha(Tokens.PANEL, 0.92 if active else 0.78)
	var style := build(bg, Color.TRANSPARENT, 0, radius)
	style.border_width_bottom = 0
	style.content_margin_bottom = 2
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	# Softer shadow hint for titlebar elevation
	if active:
		_apply_shadow(style, Tokens.shadow_small(), 0.6)
	return style

static func body_panel(active: bool, radius: int) -> StyleBoxFlat:
	# Content no square backplates around rounded corners. Use spacing/fill contrast.
	# Transparent nested, margins for rounded corner backing safety.
	# Top radius 0 to integrate with titlebar, one primary outer background.
	var bg := Color.TRANSPARENT
	var style := build(bg, Color.TRANSPARENT, 0, radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	return style

static func button_normal(radius: int) -> StyleBoxFlat:
	return build(Tokens.alpha(Tokens.SURFACE, 0.92), Tokens.alpha(Tokens.BORDER, 0.70), 1, radius)

static func button_hover(radius: int) -> StyleBoxFlat:
	return build(Tokens.SURFACE_HOVER, Tokens.alpha(Tokens.BORDER_ACTIVE, 0.82), 1, radius)

static func button_pressed(radius: int) -> StyleBoxFlat:
	return build(Tokens.SURFACE_ACTIVE, Tokens.alpha(Tokens.BORDER, 0.70), 1, radius)

static func button_selected(radius: int) -> StyleBoxFlat:
	var style := build(Tokens.alpha(Tokens.ACCENT, 0.14), Tokens.alpha(Tokens.ACCENT, 0.38), 1, radius)
	style.border_width_left = 3
	return style

static func button_focus(radius: int) -> StyleBoxFlat:
	return build(Color.TRANSPARENT, Tokens.FOCUS, 2, radius)

static func button_disabled(radius: int) -> StyleBoxFlat:
	return build(Tokens.alpha(Tokens.PANEL, 0.42), Tokens.alpha(Tokens.BORDER, 0.35), 1, radius)

static func icon_button_normal(radius: int) -> StyleBoxFlat:
	return build(Color.TRANSPARENT, Color.TRANSPARENT, 0, radius)

static func icon_button_focus_clear(radius: int) -> StyleBoxFlat:
	return build(Color.TRANSPARENT, Color.TRANSPARENT, 0, radius)

static func icon_button_hover(radius: int) -> StyleBoxFlat:
	return build(Tokens.alpha(Tokens.SURFACE_HOVER, 0.62), Color.TRANSPARENT, 0, radius)

static func icon_button_pressed(radius: int) -> StyleBoxFlat:
	return build(Tokens.alpha(Tokens.SURFACE_ACTIVE, 0.80), Color.TRANSPARENT, 0, radius)

static func icon_button_focus(radius: int) -> StyleBoxFlat:
	return build(Color.TRANSPARENT, Tokens.FOCUS, 2, radius)

static func traffic_light_default() -> StyleBoxFlat:
	return _padding(build(Tokens.alpha(Tokens.TEXT_MUTED, 0.24), Color.TRANSPARENT, 0, 15), 0, 0)

static func traffic_light_close() -> StyleBoxFlat:
	return _padding(build(Tokens.ERROR, Color.TRANSPARENT, 0, 15), 0, 0)

static func traffic_light_maximize() -> StyleBoxFlat:
	return _padding(build(Tokens.SUCCESS, Color.TRANSPARENT, 0, 15), 0, 0)

static func window_control(symbol: String = "", destructive: bool = false, state: String = "normal") -> StyleBoxFlat:
	var bg := Tokens.alpha(Tokens.TEXT_MUTED, 0.18)
	if state == "hover":
		bg = Tokens.ERROR if destructive else Tokens.alpha(Tokens.WHITE, 0.13)
	elif state == "pressed":
		bg = Tokens.alpha(Tokens.ERROR if destructive else Tokens.WHITE, 0.22)
	elif state == "focused":
		return build(Color.TRANSPARENT, Tokens.FOCUS, 2, 999)
	return _padding(build(bg, Color.TRANSPARENT, 0, 999), 0, 0)

static func input_normal(radius: int) -> StyleBoxFlat:
	return build(Tokens.INPUT_BG, Tokens.alpha(Tokens.BORDER, 0.78), 1, radius)

static func input_focus(radius: int) -> StyleBoxFlat:
	return build(Tokens.BG_ELEVATED, Tokens.FOCUS, 2, radius)

static func list_panel(radius: int) -> StyleBoxFlat:
	return build(Tokens.BG, Tokens.alpha(Tokens.BORDER, 0.54), 1, radius)

static func list_selected() -> StyleBoxFlat:
	# list_row_selected: subtle filled highlight + 1px accent edge left, no inner box
	var style := build(Tokens.alpha(Tokens.ACCENT, 0.11), Tokens.alpha(Tokens.ACCENT, 0.55), 0, 6)
	style.border_width_left = 2
	style.border_color = Tokens.ACCENT
	return style

static func list_row(state: String = "normal", radius: int = 8) -> StyleBoxFlat:
	match state:
		"selected":
			return list_selected()
		"hover":
			return build(Tokens.alpha(Tokens.SURFACE_HOVER, 0.56), Color.TRANSPARENT, 0, radius)
		"pressed":
			return build(Tokens.alpha(Tokens.SURFACE_ACTIVE, 0.76), Color.TRANSPARENT, 0, radius)
		_:
			return build(Color.TRANSPARENT, Color.TRANSPARENT, 0, radius)

static func sidebar_panel(radius: int = 0) -> StyleBoxFlat:
	var style := build(Tokens.alpha(Tokens.BG_ELEVATED, 0.92), Color.TRANSPARENT, 0, radius)
	style.border_width_right = 1
	style.border_color = Tokens.alpha(Tokens.BORDER, 0.56)
	return style

static func divider(vertical: bool = false) -> StyleBoxFlat:
	var style := build(Tokens.alpha(Tokens.BORDER_SOFT, 0.72), Color.TRANSPARENT, 0, 0)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

static func context_menu(radius: int) -> StyleBoxFlat:
	var style := build(Tokens.PANEL, Tokens.alpha(Tokens.BORDER_ACTIVE, 0.70), 1, radius)
	_apply_shadow(style, Tokens.shadow_large())
	return style

static func toast(level: String, radius: int) -> StyleBoxFlat:
	var border_color: Color
	match level:
		"success": border_color = Tokens.SUCCESS
		"warning": border_color = Tokens.WARNING
		"error", "danger": border_color = Tokens.ERROR
		_: border_color = Tokens.INFO
	var style := build(Tokens.alpha(Tokens.SURFACE, 0.96), Tokens.alpha(border_color, 0.58), 1, radius)
	_apply_shadow(style, Tokens.shadow_medium())
	style.border_width_left = 4
	return style

static func dock_pill(radius: int) -> StyleBoxFlat:
	# Refined glassy dock: stronger elevation/shadow, translucent fake glass
	var style := build(Tokens.alpha(Tokens.PANEL, 0.90), Tokens.alpha(Tokens.BORDER_ACTIVE, 0.42), 1, radius)
	_apply_shadow(style, Tokens.shadow_large())
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	# Active indicator (accent dot/underline) and hover to be applied per-icon in dock mounting if safe
	return style

static func top_panel() -> StyleBoxFlat:
	# Subtle black glass so wallpapers remain visible while topbar controls stay legible.
	# Alpha 0.25 = roughly 75% transparent.
	var style := build(Color(0, 0, 0, 0.25), Color.TRANSPARENT, 0, 0)
	style.border_width_bottom = 1
	style.border_color = Tokens.alpha(Tokens.BORDER_ACTIVE, 0.35)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

static func desktop_icon_selected(radius: int) -> StyleBoxFlat:
	return build(Tokens.alpha(Tokens.ACCENT, 0.18), Tokens.alpha(Tokens.ACCENT, 0.48), 1, radius)

static func desktop_icon_hover(radius: int) -> StyleBoxFlat:
	return build(Tokens.alpha(Tokens.SURFACE_HOVER, 0.36), Tokens.alpha(Tokens.BORDER, 0.24), 1, radius)

# ── Designer cleanup target styles: glass_surface_*, list_*, input_field, quiet_button ──
# Inner styles use border_width=0 or alpha<=0.05. Margins for rounded corner safety.
# Transparent children, no square backplates over rounded parents. Fake glass only.

static func glass_surface_outer(radius: int = 16) -> StyleBoxFlat:
	# Outer translucent + highlight + soft shadow. Keep for launcher/dock.
	# Larger margin for scroll/list padding, child containment inside rounded card.
	var bg := Tokens.alpha(Tokens.PANEL, 0.90)
	var border := Tokens.alpha(Tokens.WHITE, 0.07)
	var style := build(bg, border, 1, radius)
	_apply_shadow(style, Tokens.shadow_large())
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style

static func glass_surface_inner(radius: int = 10) -> StyleBoxFlat:
	# border=0, transparent/near for nested. Prevents opaque rectangular children cutting corners.
	var style := build(Color.TRANSPARENT, Color.TRANSPARENT, 0, radius)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

static func list_section(radius: int = 8) -> StyleBoxFlat:
	# Categories: no border
	return build(Color.TRANSPARENT, Color.TRANSPARENT, 0, radius)

static func list_row_hover(radius: int = 6) -> StyleBoxFlat:
	# hover: subtle fill
	return build(Tokens.alpha(Tokens.SURFACE_HOVER, 0.42), Color.TRANSPARENT, 0, radius)

static func list_row_selected(radius: int = 6) -> StyleBoxFlat:
	# selected: subtle filled highlight + 1px accent edge left, no inner box
	var style := build(Tokens.alpha(Tokens.ACCENT, 0.11), Tokens.alpha(Tokens.ACCENT, 0.55), 0, radius)
	style.border_width_left = 2
	style.border_color = Tokens.ACCENT
	return style

static func input_field(radius: int = 8) -> StyleBoxFlat:
	# Search: subtle border alpha=0.1 idle; focus ring only
	return build(Tokens.INPUT_BG, Tokens.alpha(Tokens.BORDER, 0.10), 1, radius)

static func input_field_focus(radius: int = 8) -> StyleBoxFlat:
	return build(Tokens.BG_ELEVATED, Tokens.FOCUS, 2, radius)

static func quiet_button(radius: int = 6) -> StyleBoxFlat:
	# Footer: border=0
	return build(Color.TRANSPARENT, Color.TRANSPARENT, 0, radius)

static func quiet_button_hover(radius: int = 6) -> StyleBoxFlat:
	return build(Tokens.alpha(Tokens.SURFACE_HOVER, 0.30), Color.TRANSPARENT, 0, radius)

static func quiet_button_pressed(radius: int = 6) -> StyleBoxFlat:
	return build(Tokens.alpha(Tokens.SURFACE_ACTIVE, 0.45), Color.TRANSPARENT, 0, radius)

# ── Semantic surface levels (stronger separation, shell/app tonal distinction, no border soup) ──
static func shell_surface(radius: int = 0) -> StyleBoxFlat:
	return build(Tokens.SHELL_SURFACE, Color.TRANSPARENT, 0, radius)

static func app_body_surface(radius: int = 0) -> StyleBoxFlat:
	return build(Tokens.APP_BODY_SURFACE, Color.TRANSPARENT, 0, radius)

static func subpanel_surface(radius: int = 6) -> StyleBoxFlat:
	return build(Tokens.SUBPANEL_SURFACE, Tokens.alpha(Tokens.BORDER, 0.25), 0, radius)

static func elevated_card_surface(radius: int = 8) -> StyleBoxFlat:
	var style := build(Tokens.ELEVATED_CARD, Color.TRANSPARENT, 0, radius)
	_apply_shadow(style, Tokens.shadow_small(), 0.7)
	return style

static func accent_selected_surface(radius: int = 6) -> StyleBoxFlat:
	# matte low-opacity accent fill + subtle edge, guides eye without flooding
	var style := build(Tokens.alpha(Tokens.ACCENT, 0.12), Tokens.alpha(Tokens.ACCENT, 0.45), 0, radius)
	style.border_width_left = 2
	style.border_color = Tokens.ACCENT
	return style

# ── Improved accent token usage, clearer focus/selected states, primary/secondary distinction ──
static func primary_button(radius: int = 8) -> StyleBoxFlat:
	# Primary: matte accent fill, low border opacity
	return build(Tokens.ACCENT, Tokens.alpha(Tokens.ACCENT, 0.35), 1, radius)

static func secondary_button(radius: int = 8) -> StyleBoxFlat:
	# Secondary: surface based, distinct from primary
	return build(Tokens.alpha(Tokens.SURFACE, 0.92), Tokens.alpha(Tokens.BORDER, 0.70), 1, radius)

static func dock_active_item(radius: int = 12) -> StyleBoxFlat:
	# Accent on active dock item (subtle)
	return build(Tokens.alpha(Tokens.ACCENT, 0.18), Color.TRANSPARENT, 0, radius)

static func focused_input_ring(radius: int = 8) -> StyleBoxFlat:
	# Clearer accent ring on focus
	return build(Tokens.BG_ELEVATED, Tokens.FOCUS, 2, radius)

static func selected_list_row(radius: int = 6) -> StyleBoxFlat:
	# Clearer selected with accent edge
	var style := build(Tokens.alpha(Tokens.ACCENT, 0.13), Tokens.alpha(Tokens.ACCENT, 0.5), 0, radius)
	style.border_width_left = 3
	style.border_color = Tokens.ACCENT
	return style
