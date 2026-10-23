# First expedition verification — 23 October 2026

Verified with the official Godot 4.4.1 Windows engine. This is automated gameplay and visual QA;
human game-feel, physical-controller playtesting, Steam co-op and target-hardware profiling remain pending.

## Automated checks

`./tests/run_tests.ps1` imports the project and runs all suites. The Linux CI wrapper runs the same
three game suites. Local results:

| Suite | Passed | Coverage |
|---|---:|---|
| Unit tests | 82 | Existing movement/Steam fallback plus economy, XP, upgrades, inventory, deterministic spawns, strict save validation and damaged-file recovery. |
| Movement playtest | 29 | Real-scene walking, jumping, climbing, ledge checks, turning mid-climb, cliff falls and respawn. |
| Hunting playtest | 67 | Real physical arrows, walls including cover 0.25 m from the eye, immediate turn-and-fire aim, reload, four hunts, single-use pickups, trader movement/proximity, sale, purchase and disk save roundtrips. |

All 178 checks passed with no GDScript errors. A final targeted hunting run confirmed clean audio-resource
shutdown: accelerated headless runs skip inaudible synthesis, while graphical sessions stop voices and
release streams on exit. Missing GodotSteam produces the expected offline warning.

## Visual inspection

`./tests/render_preview.ps1` rendered the actual game through OpenGL on an Intel UHD Graphics 620.
Inspected expedition, wildlife and trader PNGs in `build/previews/`. The capture stages wildlife and
shop inventory for inspection and never loads or overwrites the player's save.

Checked readable HUD text, original rabbit/boar models, golden variant coloring, bow visibility,
cliff material, camp presentation and trader layout. The capture also fails if the trader card extends
outside the viewport. An oversized trader card discovered in the first capture was corrected.

Static material batching reduces the scene's draw calls. Short capture runs are not a controlled FPS
benchmark; stable 60 FPS on the target hardware has not been verified.

## Scope still to build

Steam transport/lobbies/invites, achievements/stats/cloud, hostile-animal damage, collection log,
quests/bosses/zone gates, other movement families and weapons, settings/rebinding, and release exports.
The playable expedition currently uses local authority and local saves.
