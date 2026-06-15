# Hermesverse

A local/offline 3D world for HermesOS — single-player building and exploration.

Hermesverse provides the physical space where HermesOS runs: rooms, hallways, player movement, device control, an in-game desktop monitor, and a voxel building system with blocks, items, structures, and a hotbar HUD with category tabs.

This repository is the local/offline version. **Hermesverse_Online** will be the multiplayer version.

## Requirements

- [Godot 4.6.3](https://godotengine.org/download/) (standard build, not Flatpak)

## Running

1. Clone this repository
2. Open the project folder in Godot 4.6.3
3. Press **F5** to run

## Controls

| Action | Key |
|--------|-----|
| Move | WASD |
| Look | Mouse |
| Interact | E |
| Escape (release mouse) | Esc |

## Project Structure

```
scenes/              Main world scenes and HUD scenes
  world_3d.tscn      Main 3D world scene
  world_3d_hud.tscn  Hotbar/category HUD
scripts/
  world_3d/          Player, building, interaction, room/hallway scripts
  core/              SceneBridge, HomeDeviceController (device state)
  world_3d/items/    Placeable item scenes/scripts
  world_3d/structures/ Structure scenes for placement
resources/           Voxel block library resources
assets/              Audio and block textures
addons/              HermesOS integration addon
```

## Architecture

Hermesverse is a standalone 3D world that integrates with HermesOS:

- **SceneBridge** — Manages transitions between the 3D world and HermesOS
- **HomeDeviceController** — Single source of truth for in-game device state (lights, etc.)
- **Room/Hallway Builders** — Generate apartment geometry
- **Player Controller** — First-person CharacterBody3D with WASD + mouse
- **Interaction System** — Raycast + Area3D for doors, monitors, and devices
- **Voxel Building System** — `block_library.gd`, `block_world.gd`, `placement_controller.gd`, and `world_3d_hud.gd` provide blocks, items, structures, placement, and hotbar category tabs

HermesOS (the desktop shell, apps, and agent) is incorporated through the addon under `addons/`.

## License

[MIT](LICENSE)
