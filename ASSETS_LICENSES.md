# Asset licenses

Every third-party asset used in the game must be listed here with its source and license.
Placeholder assets must be marked as such so they are easy to find and replace.

| Asset | Path | Source | License | Placeholder? |
|-------|------|--------|---------|--------------|
| _(none yet)_ | | | | |

## Tools and engine
| Component | Version | License |
|-----------|---------|---------|
| Godot Engine | 4.4.x | MIT |
| GodotSteam (planned) | TBD | MIT |

## Placeholder content
| Content | Where | Note |
|---------|-------|------|
| Island, mountain tiers and sea | `scripts/world/island_builder.gd` | Original generated faceted terraces, cylinder colliders and sea plane; prototype art. No third-party assets. |
| Sky | `scripts/world/world_atmosphere.gd` | Original procedural cloud sky and distance atmosphere. |
| Rabbits, boars, loot and confetti | `scripts/hunting/` | Original geometry and animation generated from code; prototype art, no third-party assets. |
| Bow and hunter's hand | `scripts/hunting/bow_view.gd` | Original procedural first-person model; prototype art. |
| Trader, camp, trees and flowers | `scripts/world/camp_scenery.gd` | Original procedural geometry; prototype art. |
| Sound cues | `scripts/hunting/hunt_audio.gd` | Original synthesized waveforms; no recorded samples. |
| HUD and text | `scripts/ui/hud.gd`, `data/localization/en.json` | Original interface and English copy. Font uses Godot's bundled default; include Godot's font/license notices in release distribution. |
| Cliff strata material | `shaders/terrace.gdshader` | Original procedural shader; no texture assets. |
| Faceted terrain and meadow paths | `scripts/world/terrain_mesh.gd`, `shaders/meadow.gdshader` | Original generated mesh and procedural material; no third-party assets. |
| Meadow plants and wind | `scripts/world/meadow_details.gd`, `shaders/foliage.gdshader` | Original instanced grass, flowers, seed heads and ferns; no texture assets. |
| Sky, sea and atmosphere | `scripts/world/world_atmosphere.gd`, `shaders/painted_sky.gdshader`, `shaders/water.gdshader` | Original procedural sky/water and generated distant silhouettes. |
