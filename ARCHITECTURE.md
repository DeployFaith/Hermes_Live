# Architecture

Hermes Live is a 3D interactive world that integrates HermesOS as an in-game desktop environment. The project spans three repositories with clear separation of concerns.

## Repository Map

```
┌─────────────────────────────────────────────────────────┐
│                     Hermesverse                          │
│              github.com/DeployFaith/Hermesverse          │
│                                                          │
│  3D World (player, rooms, devices, interaction)          │
│                                                          │
│  ┌─────────────────────────────────────────────────┐    │
│  │              HermesOS (addon)                    │    │
│  │       github.com/DeployFaith/Hermes_OS           │    │
│  │                                                  │    │
│  │  OS Shell, Apps, HermesUI, Agent Service         │    │
│  │                                                  │    │
│  │  ┌─────────────────────────────────────────┐    │    │
│  │  │         WorldWeb (submodule)             │    │    │
│  │  │   github.com/DeployFaith/world-web       │    │    │
│  │  │                                          │    │    │
│  │  │  In-game internet sites & content        │    │    │
│  │  └─────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

## Repositories

### Hermesverse (Main Project)
**URL:** `git@github.com:DeployFaith/Hermesverse.git`  
**Purpose:** 3D game world — the main Godot project that players run.

Contains:
- `scripts/world_3d/` — Player controller, room/hallway builders, interaction system, monitor
- `scripts/core/` — SceneBridge (3D ↔ OS transitions), HomeDeviceController (device state)
- `scenes/` — world_3d.tscn, room.tscn, hallway.tscn, HUD, desktop preview
- `assets/audio/` — Ambient music tracks
- `addons/hermes_os/` — HermesOS addon (from Hermes_OS repo)
- `addons/hermes_os/content/hermes_internet/` — WorldWeb submodule

### Hermes_OS (Addon)
**URL:** `git@github.com:DeployFaith/Hermes_OS.git`  
**Purpose:** In-game operating system platform — consumed as a Godot addon.

Contains:
- `addons/hermes_os/scripts/os/` — Shell, window manager, agent service, design tokens
- `addons/hermes_os/scripts/apps/` — Built-in apps (chat, browser, terminal, files, etc.)
- `addons/hermes_os/scripts/ui/hermes_ui/` — Declarative UI framework (HML/HSS)
- `addons/hermes_os/scripts/hermes/` — Kernel, bridge client, protocol
- `addons/hermes_os/addons/godot_wry/` — WebView plugin (pre-built)
- `addons/hermes_os/plugin.cfg` — Godot plugin registration

### WorldWeb (Content)
**URL:** `git@github.com:DeployFaith/world-web.git`  
**Purpose:** In-game internet content — shared by Hermes_OS and Hermesverse via submodule.

Contains:
- `sites/` — Static bundled websites (home.hermes, pythia.com, agora, etc.)
- `apps/` — Source apps (Svelte/Vite) for framework-built sites
- `registry.json` — Domain/site registry
- `tools/` — Build, export, validation tooling

## Autoloads

Hermesverse registers four autoloads in `project.godot`:

| Autoload | Source | Purpose |
|----------|--------|---------|
| `SceneBridge` | Hermesverse | Manages 3D ↔ OS scene transitions |
| `HomeDeviceController` | Hermesverse | Single source of truth for device state (lights, etc.) |
| `HermesOSKernel` | HermesOS addon | OS kernel and core services |
| `McpInteractionServer` | HermesOS addon | MCP integration for AI agent control |

## Data Flow

### 3D World → OS
1. Player approaches PC monitor in 3D room
2. InteractionSystem detects E key press
3. `SceneBridge.enter_os()` changes scene to `os_shell.tscn`
4. Player state (position, rotation) saved for return

### OS → 3D World
1. User presses Esc in OS (or shuts down)
2. `SceneBridge.exit_to_world()` restores 3D scene
3. Player position restored from saved state
4. OS skips boot sequence if returning (not shutdown)

### Chat → Devices
1. User types command in Hermes Chat (e.g., "turn lights red")
2. `HermesAgentService` intercepts message
3. `HomeDeviceController.try_handle_chat_message()` parses intent
4. Device state updated → signal emitted
5. Room controller applies visual changes (light color, energy)

### Browser → WorldWeb
1. User navigates to a domain (e.g., `home.hermes`)
2. `HermesInternetResolver` checks registry for domain
3. `HermesInternetDocumentLoader` loads HTML from `content/hermes_internet/sites/`
4. Assets (CSS, JS) injected inline for local rendering
5. WebView renders the page

### Agent → MCP
1. Docker container (hermesos-gateway) connects on port 9090
2. `McpInteractionServer` receives commands
3. Operations routed to OS services (file ops, app control, device control)
4. Results returned to agent

## HermesUI Framework

Declarative UI system for building OS apps:

```
manifest.json    ← App metadata
main.hml         ← HermesLang (component tree, bindings, events)
main.hss         ← HermesStyle (layout, colors, spacing)
main.gd          ← Controller (state, events, OS bridge)
```

## File-Based Persistence

Data that survives scene changes and restarts:

| Data | Location | Format |
|------|----------|--------|
| User accounts | `user://hermes_os_files.json` | JSON filesystem tree |
| Shell state | `user://hermes_os_shell_state.cfg` | Godot ConfigFile |
| Chat history | `user://hermes_chat_history.json` | JSON messages |
| Browser settings | `user://browser_settings.cfg` | Godot ConfigFile |

`user://` is per-project and per-machine — not shared between Hermes_OS standalone and Hermesverse.

## Docker Integration

The Hermes Gateway runs in Docker and connects to the game via MCP:

```bash
# Start gateway
docker start hermesos-gateway

# API key configured in
runtime/hermes_gateway/compose.env
```

Environment variables:
- `HERMES_GATEWAY_PORT` — Gateway port (default: 8643)
- `HERMES_GATEWAY_API_KEY` — Authentication key
- `HERMES_GATEWAY_MODEL_NAME` — Model name (hermesos)

## Development Workflow

### Updating WorldWeb Content
```bash
# Edit in world-web repo
cd Hermes_OS-worldweb
# Make changes, commit, push

# Update submodules
cd Hermes_OS && git submodule update --remote addons/hermes_os/content/hermes_internet
cd Hermesverse && git submodule update --remote addons/hermes_os/content/hermes_internet
```

### Updating HermesOS
```bash
# Edit in Hermes_OS repo
cd Hermes_OS
# Make changes, commit, push

# Copy updated addon to Hermesverse
cp -r Hermes_OS/addons/hermes_os Hermesverse/addons/hermes_os
cd Hermesverse && git add -A && git commit -m "Update HermesOS addon"
```

### Adding a New Room
1. Create builder script in `scripts/world_3d/`
2. Add Node3D to `world_3d.tscn` with builder script
3. Register devices with `HomeDeviceController`
4. Connect doors via Area3D + tween (not scene transitions)

### Adding a New App
1. Create app directory in `addons/hermes_os/scripts/apps/`
2. Add `manifest.json`, `main.hml`, `main.hss`, `main.gd`
3. Register in `AppRegistry`
4. Add launcher entry

## Requirements

- Godot 4.6.3 (standard build, not Flatpak)
- Jolt Physics engine
- Docker (optional, for Hermes Gateway)
