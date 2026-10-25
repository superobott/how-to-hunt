# Assumptions

Decisions made without asking, recorded so they can be revisited.

| # | Assumption | Why | Revisit when |
|---|-----------|-----|--------------|
| 1 | Engine is Godot 4.4 with GodotSteam. | Text-based project files, easy code review, headless export. | Never, unless GodotSteam blocks a Steam feature. |
| 2 | Windows 64-bit is the primary target, Linux is a bonus. | Matches the brief. | Final platform answer. |
| 3 | Steam App ID is the test ID 480 until the real one is provided. | Matches the brief. | Real App ID arrives. |
| 4 | Tests use a small in-repo GDScript runner, not a third-party test addon. | No dependency to vet or pin. | The suite outgrows it. |
| 5 | Pull requests are split by concern, not by milestone, to stay near 400 lines. | Keeps CodeRabbit reviews readable. | n/a |
| 6 | GodotSteam is not vendored into the repo yet. | It is a large binary addon; Steam code runs behind a fallback until it is added. | Milestone 8, or when real Steam testing starts. |
| 7 | Cliffs are climbed by walking into them, with no stamina limit yet. | Keeps the controller simple; stamina belongs to the skill tree (milestone 6). | Skill tree work. |
| 8 | Movement numbers (walk 5 m/s, sprint 8, jump about 1.3 m, climb 3 m/s) are untuned. | Checked numerically only; needs a human playtest. | First playtest. |
| 9 | The island uses generated faceted terraces with cylinder colliders. | Original prototype art; level tops and cliff edges stay close to the original tier radii and heights. | Authored terrain or zone-layout work. |
| 10 | First expedition is a local playable slice: two animals, three bows, one trader and one hunting annulus. | Establish and verify the full economy loop before expanding scope. | Co-op and zone milestones. |
| 11 | Arrows are unlimited; bow upgrades change damage, speed and reload. | Avoid an ammunition cost that could strand a new player without income. | Weapon balance and durability work. |
| 12 | First bow upgrade costs 48 coins; ordinary rabbits sell for 12. Bag capacity is eight. | Four successful hunts provide a visible early goal. | Human playtesting. |
| 13 | Falling preserves gear and carried loot; wildlife and uncollected drops reset on relaunch. | Keep the prototype forgiving while persisting the earned economy. | Difficulty and world-save design. |
| 14 | No Steam multiplayer or cloud claim is made for this slice. Rewards pass through one world controller and pure rules. | Keep authority decisions explicit for future Steam host replication. | Multiplayer milestone. |
| 15 | Ground loot pauses wildlife replenishment at 48 drops; already living animals may still drop loot. | Bound unattended world growth without discarding earned rewards. | Multiplayer/shared-world lifecycle. |
| 16 | Tests use persistence-disabled worlds and separate `test_*.json` saves. | Automated runs must never overwrite the player's expedition. | Test infrastructure changes. |
