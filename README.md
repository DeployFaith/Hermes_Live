# Hermes Live

A 3D interactive world environment for HermesOS — the in-game operating system platform.

Hermes Live provides the physical space where HermesOS runs: rooms, hallways, player movement, device control, and an in-game desktop monitor.

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
scenes/              3D world scenes (room, hallway, world root)
scripts/
  world_3d/          Player controller, room/hallway builders, interaction
  core/              SceneBridge, HomeDeviceController (device state)
assets/
  audio/             Ambient music tracks
addons/              HermesOS integration (coming soon)
```

## Architecture

Hermes Live is designed as a standalone 3D world that integrates with HermesOS:

- **SceneBridge** — Manages transitions between 3D world and OS
- **HomeDeviceController** — Single source of truth for in-game device state (lights, etc.)
- **Room/Hallway Builders** — CSG-based geometry for the apartment environment
- **Player Controller** — First-person CharacterBody3D with WASD + mouse
- **Interaction System** — Raycast + Area3D for doors, monitors, devices

HermesOS (the desktop shell, apps, and agent) is incorporated as an addon.

## License

[MIT](LICENSE)
