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

## Player and world
- `scripts/core/player_motion.gd`: pure movement rules (walk, jump, climb, mantle, look). No nodes, so it is unit-tested directly.
- `scripts/core/island_bounds.gd`: cliff edge, kill height, outer clamp, respawn point.
- `scripts/core/input_setup.gd`: keyboard and gamepad actions, created in code and never overwriting player rebinds.
- `scripts/player/player.gd`: the `CharacterBody3D`. Gathers input, asks `PlayerMotion` what to do, applies it.
- `scripts/world/island_builder.gd`: builds the terraced island from code. Cliff sides are in the `climbable` group.
- `scripts/world/world.gd`: assembles island, player, light and sky.

Climbing: a short ray at 0.5 m height checks for a wall. Walking into a `climbable` wall grabs it; when the wall ends under the player a small hop carries them onto the ledge.

## Configuration
A single file, `data/config/game_config.json`, holds the Steam App ID. `steam_appid.txt` at the project root must match it (a test enforces this).

## Testing
`tests/run_tests.gd` is a small SceneTree runner. It discovers `tests/test_*.gd` files and runs every method that starts with `test_`. It exits non-zero on failure or when it finds no tests.

`tests/smoke_world.gd` loads the real main scene and plays it with simulated input actions (stand, walk, jump, climb, outer clamp, fall and respawn). It runs with `--fixed-fps 60` so every frame is exactly 1/60 s, which makes the physics deterministic and fast.

`tests/run_tests.sh` runs both suites and is what contributors and CI run. Godot 4.4 gives a runner no hook to catch script errors, so a test that hits a runtime error (such as calling a method on null) would print `SCRIPT ERROR` yet still report PASS. The wrapper fails on that output.

## Multiplayer (planned)
Host-authoritative over Steam networking, 1 to 4 players, shared island and money, per-player inventory.

## Playable hunting slice
- `data/gameplay.json` defines animals, bow tiers, economy, XP thresholds, and spawn settings.
- `HuntState` is a pure RefCounted model. A defeat grants XP; a separate pickup grants a sale item.
  Selling consumes the inventory, and purchasing atomically checks and deducts its price.
- `SpawnRules` owns seeded random animal/rare choices and area-uniform annulus sampling.
- `SaveStore` validates the complete schema before mutating state, flushes a temporary JSON file,
  preserves the previous valid main as a backup, and recovers main → backup → temporary file.
- `world.gd` owns the local session and action entry points. It connects entity defeats to rewards,
  validates pickup/trader proximity, debounces autosaves, and bounds wildlife replenishment.
  This is a single-player authority, not a network transport or multiplayer implementation.
- `scripts/hunting/` contains wildlife presentation/AI, swept physical arrows, loot presentation,
  transient effects, the camera-local bow and original synthesized audio. Arrows start at the
  camera and exclude their shooter's collider, so nearby cover is included in collision checks.
- Player physics runs before weapon resolution so current look input determines each shot.
- `MeshBatch` combines static primitive geometry by material using local transforms. Camp props
  and each animal model retain their appearance while using fewer draw calls; colliders and lights
  stay independent. The terrace shader gives cliff sides rock strata and keeps the walkable tops green.
- The HUD reads session state and uses `GameText` with keyed English JSON and per-key English fallback.
  World interactions remain outside UI code. Trading disables movement and firing.

`tests/smoke_hunt.gd` loads the real scene, shoots real colliders, collects drops, sells four rabbits,
buys a better bow and roundtrips both a full bag and upgraded gear through disk. Both test runners
also retain the original climbing and respawn regression suite. `tests/preview_hunt.gd` is a graphical
QA capture script and is intentionally excluded from headless CI.

## Graphics pass
`TerrainMesh` supplies level meadow caps and faceted rock faces close to the existing cylinder
colliders. Gameplay still uses the original tier radii/heights. Procedural meadow, cliff and water
materials use world coordinates and work in the GL Compatibility renderer.

`CampScenery` batches its static props and forest by material. `MeadowDetails` builds six MultiMeshes
for 5,190 seeded plant instances; wind runs in the vertex shader and these small plants do not cast
shadows. Explicit white instance colors preserve vertex colors in the Compatibility renderer.
Plant color ramps keep double-sided blades readable. The first-person bow does not cast world shadows.

`WorldAtmosphere` contains a static cloud sky, warm directional sunlight using one orthographic shadow
map, ambient fill, distance haze and distant silhouettes. Sky shaders omit `TIME`, so water/plant animation
does not force the sky's radiance cubemap to update every frame. The project enables 2x MSAA and a
2048-pixel directional shadow atlas. Target-hardware FPS profiling remains pending.
