# How to Hunt

A first-person, physics-based hunting and progression game with a comedic, cartoony, low-poly look. You are stranded on a mountain island: hunt animals, sell the loot, buy better gear and climb to tougher zones. Single-player and 1 to 4 player Steam co-op.

Status: playable local hunting prototype. Steam online co-op is planned and is **not implemented yet**.

## Playable now
- Explore the mountain island with first-person movement, jumping and climbing.
- Hunt roaming rabbits and boars with physical, gravity-affected arrows. Aim with right mouse / LT.
- Find rare golden animals and earn bonus rewards for headshots and long-distance hits.
- Collect glowing loot satchels into an eight-item bag. Visit the amber-awning trader near camp,
  sell your loot and buy two successive bow upgrades. Four ordinary rabbits fund the first upgrade.
- Earn XP and hunter levels. Coins, XP, hunts, bow and carried loot save locally and reload on launch.
- Original procedural camp, wildlife, bow, sound cues and guided expedition HUD.

## Requirements
- [Godot 4.4.x](https://godotengine.org/download) (standard build, not .NET)
- Optional: [GodotSteam](https://godotsteam.com) for Steam features. Without it the game runs with Steam disabled.

## Run
```
godot --path .
```

On Windows, `./play.ps1` uses `GODOT`, Godot on PATH, or the locally downloaded 4.4.1 engine in
`build/tools/godot-4.4.1/`. The engine download is ignored by Git and is not part of the repository.

You spawn on the plateau at the foot of a terraced mountain. Click the window to capture the mouse, Esc to release it.

| Action | Keyboard and mouse | Gamepad |
|--------|--------------------|---------|
| Move | W A S D | Left stick |
| Look | Mouse | Right stick |
| Jump | Space | A |
| Sprint | Shift | Left stick click |
| Climb | Walk into a cliff | Walk into a cliff |
| Fire bow | Left mouse | Right trigger |
| Aim | Right mouse | Left trigger |
| Collect / trade / sell | E | X |
| Buy next bow at trader | U | Y |
| Close trader / release cursor | Esc | B |

Walk into a cliff to climb it, and keep holding forward at the top to hop onto the ledge. Jump to push off the wall. Walk off the plateau edge and you fall and respawn.

## Test
```
tests/run_tests.sh
```
Runs the unit tests and a headless physics smoke test that plays the real scene with simulated input.

Windows: `./tests/run_tests.ps1` (optional `-Godot C:/path/to/godot_console.exe`). Both runners include
unit tests, the original movement regression suite, and a physical-arrow hunt → collect → sell →
upgrade playtest with disk save roundtrips. Tests opt out of normal game persistence and use separate
test save filenames. Windows test logs are written to `build/test-results/`.

For visual QA on Windows, `./tests/render_preview.ps1` briefly runs the graphical game with saving
disabled and writes expedition/trader screenshots into `build/previews/`.

## Saves and current limits
The local save is `user://hunt_save.json` (on Windows normally
`%APPDATA%/Godot/app_userdata/How to Hunt/`). Updates use a flushed temporary file and keep the last
valid save as `.bak`; malformed main saves can recover from the backup. Uncollected ground loot and
wildlife positions reset when the expedition closes. Falling preserves your carried loot and gear.

This slice has one hunting region and three bows. Multiplayer, Steam invites/lobbies, cloud saves,
achievements, quests, bosses, gated zones, full settings/rebinding, and the release/export pipeline
remain future milestones. Existing Steam initialization gracefully falls back when GodotSteam is absent.

## Docs
- [Game design](docs/GAME_DESIGN.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Assumptions](docs/ASSUMPTIONS.md)
- [Contributing](CONTRIBUTING.md)
- [Asset licenses](ASSETS_LICENSES.md)
