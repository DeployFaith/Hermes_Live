# HermesUI v0.2

HermesUI is the official native Godot UI framework for Hermes_OS.

It is not just an app framework.
It is the OS-wide UI framework for:
- shell chrome
- windows and titlebars
- taskbar / dock surfaces
- launcher / start menu surfaces
- desktop icons
- notifications / toasts
- context menus
- modals and status surfaces
- app layouts and components
- agent/MCP-visible UI metadata

HermesApp is one layer inside HermesUI, not the whole thing.

## Philosophy

HermesUI should make development feel like:
- “I compose HermesUI components and wire behavior.”

Not:
- “I hand-roll Godot nodes and manually style everything.”

HermesUI is native Godot only:
- GDScript + Control nodes
- no React
- no WebView runtime
- no JavaScript/HTML/CSS app runtime
- no virtual DOM

## Layered model

1. Theme and tokens
- HermesTheme
- token aliases over existing DesignTokens / StyleFactory
- spacing, radius, typography, motion, density helpers
- hybrid Godot Theme resource + component override approach

2. Primitives
- label
- button
- icon_button
- input
- text_area
- badge
- spacer
- divider

3. Containers
- vbox
- hbox
- flow_row
- scroll_container
- split_view

4. Surfaces and compositions
- panel
- card
- toolbar
- sidebar
- status_bar
- tabs
- list_view
- message_item
- settings_row
- form_group
- section_header
- empty_state
- alert
- loading_indicator
- progress_bar

5. Shell chrome components
- taskbar
- taskbar_item
- launcher_menu
- launcher_grid
- tray
- notification_toast
- context_menu
- desktop_icon
- window_titlebar
- window_controls

6. App framework
- HermesApp
- lifecycle bridge
- app layouts
- state sanitization
- status handling
- app-level MCP/action metadata

7. Agent/MCP metadata
- refs
- roles
- actions
- visible/enabled state
- future UI-tree export path

## Preferred API convention

Preferred call style:
- content components: component(content, options := {})
- container components: component(children := [], options := {})
- controls: component(content/value, options := {})

Examples:
```gdscript
ui.label("Gateway online", {"variant": "muted"})
ui.button("Send", {"variant": "primary", "on_pressed": Callable(self, "_send")})
ui.input({"value": text, "placeholder": "Message Hermes...", "on_submit": Callable(self, "_send")})
ui.panel([child_a, child_b], {"padding": "md"})
ui.card([row], {"variant": "elevated"})
```

Compatibility overloads still exist in some places, but current consumers should prefer the options-driven API.

## Visual clarity pass (v0.2.1)

In v0.2.1 HermesUI increased layer contrast, added shadow depth, improved
primary button readability, and fixed invisible borders. Key changes:

- BORDER darkened → visible at ~1.7:1 on panels (was ~1.3:1, effectively invisible)
- ACCENT darkened → primary button text now readable
- ON_ACCENT added → dark text token for accent-colored surfaces
- FOCUS separated from ACCENT → focus rings are now a distinct, brighter blue
- TEXT_DISABLED lightened → disabled text stays readable on active surfaces
- Layer steps widened: BG → PANEL → SURFACE → SURFACE_ACTIVE
- Shadows added: cards use small shadow, elevated panels use medium, popups/menus use large
- Status bar uses bg_elevated (darker) to separate from toolbar

### Contrast targets

| Pair                     | Before | After | Notes                          |
|--------------------------|--------|-------|--------------------------------|
| BORDER on PANEL          | 1.3:1  | 1.7:1 | Borders now visible            |
| TEXT on ACCENT (primary) | 2.3:1  | 3.3:1 | Passes WCAG AA large text      |
| TEXT on ON_ACCENT        | —      | 15.9:1 | Primary buttons use dark text  |
| TEXT_DISABLED on active  | 2.0:1  | 2.7:1 | Improved, still below AA       |
| FOCUS vs ACCENT          | 1.0:1  | 1.9:1 | Focus rings now distinct       |

### Shadows / elevation

- `panel_style` supports `elevation` option (0=none, 1=small, 2=medium, 3=large)
- `card_style` supports `elevation` option (0=none, default=0 for subtle depth)
- `elevated_style` → medium shadow for popups/dialogs
- `context_menu_style` → large shadow for floating menus
- Shadows use existing `DesignTokens.shadow_small/medium/large()` through `StyleFactory`

## Theme bridge strategy

HermesUI does not create a competing palette.
It bridges the existing Hermes_OS palette:
- `scripts/os/design_tokens.gd`
- `scripts/os/style_factory.gd`

Current mapping examples:
- `bg` -> `DesignTokens.BG`
- `surface` -> `DesignTokens.PANEL`
- `surface_2` -> `DesignTokens.SURFACE`
- `surface_3` -> `DesignTokens.SURFACE_ACTIVE`
- `accent` -> `DesignTokens.ACCENT`
- `on_accent` -> `DesignTokens.ON_ACCENT`
- `success` -> `DesignTokens.SUCCESS`
- `warning` -> `DesignTokens.WARNING`
- `danger` -> `DesignTokens.ERROR`

Synthetic tokens are only used where the old system lacks a clean equivalent.

## Theme hybrid approach

Current HermesUI theme model is hybrid:
- `HermesTheme.build_theme()` builds a real Godot `Theme`
- `HermesTheme.apply_to(control)` applies it
- component factories still use explicit StyleBox overrides for variants and composed surfaces

Target direction:
- Theme resource first
- component-level overrides only for variants/special cases

That full migration is not finished in v0.2, but the framework now documents and structures toward it.

## HermesTheme API

Core helpers:
- `color(name)`
- `spacing(name_or_value)`
- `radius(name_or_value)`
- `font_size(name_or_value)`
- `duration(name)`
- `easing(name)`
- `kind_color(kind)`
- `kind_text_color(kind)`
- `component_size(component, size := "md")`
- `size(name)`
- `refresh()`
- `build_theme()`
- `apply_to(control)`

Style helpers:
- `panel_style(options := {})`
- `card_style(options := {})`
- `elevated_style(options := {})` — panel + medium shadow
- `context_menu_style(options := {})` — panel + large shadow
- `button_style(variant := "secondary", state := "normal", options := {})`
- `input_style(state := "normal", options := {})`
- `text_area_style(state := "normal", options := {})`
- `list_row_style(state := "normal", options := {})`
- `badge_style(kind := "info", options := {})`

Unknown token behavior:
- warns with `push_warning`
- returns safe debug fallback instead of crashing

## Component list

Layout / container:
- `vbox(children := [], gap := -1, options := {})`
- `hbox(children := [], gap := -1, options := {})`
- `flow_row(children := [], options := {})`
- `spacer(size := 8, vertical := false)`
- `divider(options := {})`
- `scroll_container(content := null, options := {})`
- `split_view(left, right, sidebar_width := -1, options := {})`

Surfaces / composition:
- `panel(children := [], padding := -1, variant := "base", options := {})`
- `card(children := [], padding := -1, options := {})`
- `toolbar(children := [], options := {})`
- `sidebar(children := [], width := -1, options := {})`
- `status_bar(text := "", kind := "info", options := {})`
- `section_header(title := "", body := "", options := {})`
- `settings_row(label := "", control := null, options := {})`
- `form_group(title := "", rows := [], options := {})`
- `empty_state(title := "", body := "", options := {})`
- `alert(message := "", options := {})`
- `loading_indicator(options := {})`
- `progress_bar(options := {})`

Controls:
- `label(text := "", options := {})`
- `badge(text := "", options := {})`
- `button(text := "", options := {})`
- `icon_button(icon := "", options := {})`
- `input(options := {})`
- `text_area(options := {})`
- `dropdown(items := [], options := {})`
- `slider(options := {})`
- `toggle(text := "", options := {})`
- `radio_group(items := [], options := {})`
- `tabs(items := [], options := {})`
- `list_view(items := [], options := {})`
- `list(...)` compatibility alias
- `message_item(sender := "", text := "", options := {})`

## scroll_container vs list_view

Use `scroll_container` when:
- you already own the child column/container
- you want custom message feeds or arbitrary layouts
- you want incremental manual rendering

Use `list_view` when:
- you want a managed scrollable row list
- rows are simple selectable items
- you want list-style interaction/state

Hermes Chat should prefer `scroll_container` for message feeds.

## Shell chrome component APIs

Scaffolded in HermesUI now:
- `taskbar(options := {})`
- `taskbar_item(app_id, title, icon, options := {})`
- `launcher_menu(options := {})`
- `launcher_grid(apps := [], options := {})`
- `tray(options := {})`
- `notification_toast(message := "", options := {})`
- `context_menu(items := [], options := {})`
- `desktop_icon(label := "", icon := "", options := {})`
- `window_titlebar(title := "", options := {})`
- `window_controls(options := {})`

These are framework-level shell building blocks.
They are not a full shell migration yet.

## Child/body helpers

To avoid fragile `find_child("HermesCardBody")` patterns, HermesUI now provides:
- `body_of(container)`
- `add(control, child)`
- `add_many(control, children)`
- `clear_children(control)`

Panel/card/toolbar/list containers attach internal body metadata so app code can target the intended body cleanly.

## Stateful helpers

Current helpers:
- `get_active_tab(tab_control)`
- `set_active_tab(tab_control, id)`
- `get_selected_id(list_control)`
- `set_selected_id(list_control, id)`
- `rebuild_list(list_control, items, options := {})`

## HermesApp lifecycle

HermesApp preserves Hermes_OS lifecycle hooks:
- `os_app_init(context)`
- `os_app_focus()`
- `os_app_blur()`
- `os_app_close_requested()`
- `os_app_get_state()`
- `os_app_restore_state(state)`
- `os_app_handle_agent_action(action, args)`

Nicer override surface:
- `setup(context)`
- `render()`
- `refresh()`
- `on_focus()`
- `on_blur()`
- `on_close_requested()`
- `get_state()`
- `restore_state(state)`
- `get_mcp_actions()`
- `handle_mcp_action(action, args)`

Additional helpers:
- `clear_root()`
- `set_root(control)`
- `set_status(text, kind := "info")`
- `get_status()`
- `set_status_control(control)`
- `find_by_ref(ref)`
- `register_control_ref(control, ref, meta := {})`
- `get_serializable_state()`
- `on_event(event_name, callback)`

Rules:
- no virtual DOM
- no rebuild-on-keystroke
- `render()` is initial build
- `refresh()` is explicit major rebuild only
- state must remain serializable

## Option validation behavior

HermesComponentFactory validates option keys in debug builds:
- unknown option keys trigger `push_warning`
- warnings include the component name
- unknown options do not crash the app

## Canonical real examples

System Settings is the canonical real HermesUI app example.
It now demonstrates:
- HermesApp-based lifecycle
- HermesLayout usage
- form components
- Gateway + MCP status composition
- shell callback wiring
- preserved automation-facing control names

Hermes Chat is the chat proof.
It demonstrates:
- HermesApp lifecycle
- chat layout
- scroll_container message feed
- message_item usage
- Gateway-driven status handling
- MCP-friendly refs

## Escape hatches

Use raw Godot controls only when HermesUI truly lacks the component.
If HermesUI lacks a generally reusable component, add it to HermesUI first.
App-specific one-offs are the exception, not the rule.

## Future shell chrome migration plan

1. System Settings
2. Hermes Chat
3. Notes
4. Text Editor
5. Files
6. notifications/toasts
7. taskbar items/window buttons
8. launcher/start menu
9. desktop icons/context menus
10. Terminal special polish
11. Browser last

Why:
- Settings and chat are stable framework proofs
- Notes/Text/Files are normal app UIs next
- notifications and shell chrome benefit from shared surfaces
- Terminal needs special rendering polish
- Browser remains last because of native/runtime complexity

## Guidance for new Hermes_OS UI

New Hermes_OS UI should use HermesUI.
This includes apps and OS chrome.
Do not hand-roll raw Control trees unless HermesUI lacks the component.
If HermesUI lacks the component, add it to HermesUI first unless the use case is truly app-specific.
