# How to Hunt

A first-person, physics-based hunting and progression game with a comedic, cartoony, low-poly look. You are stranded on a mountain island: hunt animals, sell the loot, buy better gear and climb to tougher zones. Single-player and 1 to 4 player Steam co-op.

Status: early development (milestone 2: first-person controller and the island).

## Requirements
- [Godot 4.4.x](https://godotengine.org/download) (standard build, not .NET)
- Optional: [GodotSteam](https://godotsteam.com) for Steam features. Without it the game runs with Steam disabled.

## Run
```
godot --path .
```

You spawn on the plateau at the foot of a terraced mountain. Click the window to capture the mouse, Esc to release it.

| Action | Keyboard and mouse | Gamepad |
|--------|--------------------|---------|
| Move | W A S D | Left stick |
| Look | Mouse | Right stick |
| Jump | Space | A |
| Sprint | Shift | Left stick click |
| Climb | Walk into a cliff | Walk into a cliff |

Walk into a cliff to climb it, and keep holding forward at the top to hop onto the ledge. Jump to push off the wall. Walk off the plateau edge and you fall and respawn.

## Test
```
tests/run_tests.sh
```
Runs the unit tests and a headless physics smoke test that plays the real scene with simulated input.

## Docs
- [Game design](docs/GAME_DESIGN.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Assumptions](docs/ASSUMPTIONS.md)
- [Contributing](CONTRIBUTING.md)
- [Asset licenses](ASSETS_LICENSES.md)
