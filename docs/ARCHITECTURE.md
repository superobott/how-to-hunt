# Architecture

## Engine choice: Godot 4 with GodotSteam
- **Reviewable:** scenes, resources and project settings are text files, so diffs are readable in pull requests and CodeRabbit can review them.
- **Headless:** the same binary runs tests and exports from the command line, which keeps CI simple.
- **Lightweight:** small download, no license fees, good fit for a low-poly style and a GTX 1050-class target.
- **Steam:** GodotSteam wraps Steamworks (achievements, stats, cloud, lobbies, networking, Rich Presence).
- **Alternative considered:** Unity with Steamworks.NET. Rejected because its project files are noisier to review and CI needs a licensed editor.

## Layers
```
UI (scenes/, scripts/ui)         -> reads state, emits intents
Game logic (scripts/core, ...)   -> pure rules: economy, progression, spawns, save/load
Services (scripts/steam)         -> SteamService autoload, safe fallback when Steam is absent
Data (data/*.json)               -> animals, tools, zones, quests, prices, config
```

Rules:
- Game logic never touches UI nodes and never calls Steam directly.
- All Steam calls go through `SteamService`. When Steam is unavailable it logs once and every call becomes a safe no-op or local fallback.
- Balance values live in `data/`, not in code.
- Randomness uses a seedable `RandomNumberGenerator` so tests are deterministic.

## Configuration
A single file, `data/config/game_config.json`, holds the Steam App ID. `steam_appid.txt` at the project root must match it (a test enforces this).

## Testing
`tests/run_tests.gd` is a small SceneTree runner. It discovers `tests/test_*.gd` files and runs every method that starts with `test_`. It exits non-zero on failure, and CI runs it headless.

## Multiplayer (planned)
Host-authoritative over Steam networking, 1 to 4 players, shared island and money, per-player inventory.
