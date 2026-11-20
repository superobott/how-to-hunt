# First expedition verification — 23 October 2026

## Guest combat feedback — 16 November 2026

Separated presentation decay/predator warnings from solo survival simulation. Guests now
receive reliable host-confirmed shot/hit audio, hit markers, damage flashes and defeat
notices; feedback never changes health or progression. Protocol v3 rejects older peers.
Notifications were moved below target health and predator warnings after visual QA found
an overlap. Existing solo health, damage, cooldown and reward rules are unchanged.

The full Windows suite passed: 96 unit tests, 20 movement, 122 hunting, 38 survival,
UI, vehicles, normal co-op and silent-host recovery. All three guests observed real
network hit/damage feedback. Final focused UI tests also passed feedback decay, unchanged
health/progression and predator-warning appearance/clearing. Graphical UI preview passed
on Intel UHD Graphics 620, OpenGL Compatibility, 1280×720; `combat-feedback.png` was
inspected after the notification-layout fix. The initial predator test needed positioning
after normal spawn-bound clamping; that fixture correction does not change game spawning.
Audio playback is wired and exercised but not assessed by listening. Steam/WAN, moving
target responsiveness and target-hardware performance remain unverified.

## Expedition HUD — 16 November 2026

Added localized host/guest role, hunter count, shared-wallet labels, guest session/save
explanation and next-step goal guidance. Goal thresholds, prices and rewards are unchanged.
The 1280×720 OpenGL Compatibility render on Intel UHD Graphics 620 was inspected:
the goal and party cards fit without overlap and remain readable over the world.
Screenshot: `build/previews/coop-expedition.png`. This establishes layout only, not FPS.
UI coverage checks solo/host transitions; the real four-process fixture checks four-player
guest labels and distinguishes session gear from disabled-save preview mode.
The complete Windows run passed import, 96 unit tests, 20 movement, 122 hunting,
38 survival checks, UI and vehicles. The co-op fixture initially exposed a teardown
race: a guest could miss the final unreliable reward update before host departure.
A test-only reliable acknowledgement now ensures all guests have observed rewards and
entered the departure check before the host stops. Both co-op scenarios passed after
adding the handshake; production networking and progression remain unchanged.

## Invalid requests and silent-host recovery — 16 November 2026

Expanded the four-process fixture with a forged client wallet, unaffordable/unknown
purchases, replayed command sequence, purchases away from the trader, and repeated
attack commands. Host wallet/equipment remain correct and exactly three arrows spawn.
The silent-host variant leaves the transport open but stops sending snapshots: remaining
guests time out, disconnect, restore solo state/persistence and retain their original
solo save hashes. Both variants are included in `./tests/run_tests.ps1 -Suite coop`.

The first expanded run stalled with missed shots after hunters drifted between aiming
and host execution. The fixture now holds firing positions still after separately
checking movement. This isolates combat authority; moving-target accuracy and delayed
aim remain unresolved interactive playtest concerns, not claimed as passing.
No production gameplay or balance was changed in this verification pass.

## Snapshot transport and presentation — 15 November 2026

After protocol v2, the full Windows runner passed: 96 unit tests, movement, hunting,
survival, UI, vehicles and all four co-op processes. No oversized ENet packet warning
occurred; the co-op runner now treats that warning as a failure. Existing shared-wallet,
combat and guest-save checks passed with interpolated presentation enabled.

A deterministic serialization fixture (seed 42115, 42 animals and four hunter records)
measured 10,068 raw bytes versus 1,327 compressed bytes in two payloads, each at most
1,000 bytes. This excludes RPC/transport headers and is not a live bandwidth benchmark.
Tests exercise reordered/missing/duplicate/stale chunks, metadata bounds, midpoint
interpolation, shortest-angle rotation, no overshoot and teleport snapping.

New guest motion is interpolated over 100 ms without movement prediction. Real network
latency, aim responsiveness and visual motion quality still require interactive QA;
these headless results establish behavior, not visual quality or target FPS.
The Steam native-extension blocker below is unchanged.

## Experimental co-op verification — 15 November 2026

Godot 4.4.1 on Windows: `./tests/run_tests.ps1` completed successfully after co-op
integration: 92 unit tests, 20 movement checks, 122 hunting checks, 38 survival checks,
UI/camera/pause/co-op-menu checks, vehicle checks, and four-process ENet co-op.
The final localized Steam error changes also passed a focused unit rerun.

The co-op scenario verifies one host plus three guests, shared wallet purchases,
individual equipment, host-authoritative movement and physical arrows, shared rewards,
single collection, host persistence, guest departure, host departure and unchanged guest
solo save hashes. The UI scenario checks that a network menu does not pause the host
and leaving restores the solo pause state.

`./tests/render_preview.ps1 -Scenario ui` passed using OpenGL Compatibility on
Intel UHD Graphics 620 at 1280×720. The co-op menu screenshot was visually inspected:
copy and controls fit within the viewport. This is layout QA, not an FPS benchmark.

Steam connectivity remains blocked by Windows Application Control (DLL error 4551).
The approved GodotSteam package is staged with its manifest disabled; no OS policy was
changed. Snapshot MTU warnings were observed in ENet and are recorded in [COOP.md](COOP.md).
WAN loss/latency, full wildlife bandwidth, interpolation, physical controllers, Linux
and target-hardware performance are unverified. No release was published.

The reports below are historical.

## Harness verification — 14 November 2026

The current Windows prototype passed all six headless suites with Godot 4.4.1:
83 unit tests, 20 mountain movement checks, 122 hunting checks, 34 survival checks,
and the UI/camera/pause and vehicle purchase/movement/save scenarios.
After adding Steam lobby lifecycle coverage, the unit suite passed 88 tests.
An added knife-switch regression failed on both damage and reload before the fix,
then the expanded survival suite passed all 37 checks. Melee now uses knife stats
even when a high-tier bow remains the owned/equipped progression tool.
The movement test was progressing but exceeded the former 60-second process timeout;
it passed with a 180-second budget, without reducing its assertions or frame bounds.
UI and vehicle tests now disable wildlife, and both Windows/Linux runners include
the same six suites. Linux execution has not been verified in this Windows session.

Steam lobby tests use a fake backend. Real Steam connectivity, synchronized co-op,
target-hardware performance and current graphical appearance remain unverified.
The older reports below describe historical versions, not the current suite counts.

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

## Windows launcher follow-up

`play.cmd` was verified from `C:\Windows\System32` using Windows PowerShell with a process execution
policy of `Restricted`. It started the actual game in headless mode and exited successfully after two
frames, forwarding the command-line flags. No execution-policy setting was changed. Use this launcher
when PowerShell blocks `play.ps1`.

## Graphics verification — 25 October 2026

The graphics pass adds faceted layered rock, dirt trails, varied trees and campsite props, six instanced
plant groups, shader wind, painted clouds, animated water, directional shadows and refined animal/bow/loot
models. All content remains generated from original code. Collider dimensions and game rules stay the same.

A fresh Godot import and all 178 checks passed. The original local generated editor cache stalled during
the first import; it was preserved in `build/godot-cache-before-graphics/` and regenerated successfully.
No player save files were changed. OpenGL previews were rendered on the Intel UHD 620 and inspected for
readable foliage, intact wildlife/equipment, shadow placement and the trader card's viewport bounds.

Baseline captures are retained locally in `build/graphics-baseline/build/previews/`. Updated captures
include `first-expedition.png`, `wildlife.png`, `trader.png`, and `island-overview.png` in `build/previews/`.
The richer scene increases draw calls relative to the baseline; this capture is visual QA rather than a
controlled FPS benchmark. A stable 60 FPS on the GTX 1050-class target is still unverified.
