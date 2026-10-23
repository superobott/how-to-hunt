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
| Island, mountain tiers and sea | `scripts/world/island_builder.gd` | Generated from code as flat-coloured cylinders and a plane. No third-party assets. Placeholder, to be replaced by authored art. |
| Sky | `scripts/world/world.gd` | Godot's built-in procedural sky. |
| Rabbits, boars, loot and confetti | `scripts/hunting/` | Original geometry and animation generated from code; prototype art, no third-party assets. |
| Bow and hunter's hand | `scripts/hunting/bow_view.gd` | Original procedural first-person model; prototype art. |
| Trader, camp, trees and flowers | `scripts/world/camp_scenery.gd` | Original procedural geometry; prototype art. |
| Sound cues | `scripts/hunting/hunt_audio.gd` | Original synthesized waveforms; no recorded samples. |
| HUD and text | `scripts/ui/hud.gd`, `data/localization/en.json` | Original interface and English copy. Font uses Godot's bundled default; include Godot's font/license notices in release distribution. |
| Cliff strata material | `shaders/terrace.gdshader` | Original procedural shader; no texture assets. |
