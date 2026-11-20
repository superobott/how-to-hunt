# Project instructions

The current prototype is the accepted gameplay baseline. Preserve existing user work.
Windows is the first release target; Linux follows Windows stability and performance.
Next milestone: 1-4 player Steam co-op, improved stylized visuals, and clearer expedition goals.

## Context
Read README.md for current behavior, docs/ARCHITECTURE.md for boundaries,
and CONTRIBUTING.md for review conventions. Older design/playtest documents contain
historical behavior; verify claims against current code before changing gameplay.
Do not restore the obsolete mandatory loot-selling loop.

## Implementation
- Keep pure rules in scripts/core; world.gd coordinates the local session.
- Route Steam calls through SteamService; preserve offline operation.
- Preserve save migration, asset references, and the user's existing progress.
- Put new balance values in data and user-facing strings in localization.
- Use seeded randomness for tests. Disable persistence before adding test worlds to the tree.
- For co-op, the host must validate combat, rewards, and purchases. Never trust client money or damage.
- Do not change engine versions, install major dependencies, publish, or modify credentials without authorization.

## Verification
Run ./tests/run_tests.ps1 on Windows (optional -Godot executable path).
Run tests/run_tests.sh on Linux. Both should cover unit, movement, hunting,
survival, UI, and vehicles. Graphical QA uses tests/render_preview.ps1.
Add regression coverage for economy, saves, combat authority, and progression changes.
Report exact checks and limitations; headless tests do not establish visual quality,
Steam connectivity, controller usability, or graphics performance.

## Performance and delivery
Provisional targets: 1080p/60 FPS, with 720p/30 FPS Low fallback on GTX 1050-class
hardware, four-core CPU and 8 GB RAM. These are unverified engineering targets.
Profile representative four-player workloads before optimizing; record hardware,
renderer, resolution, seed, frame-time percentiles, memory and loading time.
Review the final diff, preserve unrelated changes, and summarize remaining risks.
