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
| 9 | The island is built from code as flat-coloured placeholder cylinders. | No assets to license, easy to replace. Collision layout (tier radii and heights) must stay in sync with any authored mesh. | Visual polish, milestone 9. |
