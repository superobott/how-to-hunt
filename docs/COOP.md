# Experimental Windows co-op

## Progression

The user approved a host-owned expedition: 1–4 hunters, shared coins, individual equipment,
and no writes of expedition state to guests' solo saves. The host retains coins, XP, hunts
and their own equipment. Each guest starts with a knife and session equipment. A guest's
equipment is retained in memory by verified Steam identity when reconnecting to the same
running host; closing the host discards guest equipment. Connected hunters share hunt XP.
A combat defeat applies the existing coin penalty to the shared wallet. There is no host migration.

## Implementation

- `Expedition` owns wallet transactions and per-hunter state. Purchases use catalog prices.
- `CoopSession` runs guest movement, wildlife, physical arrows, knife range/occlusion,
  damage, guard, cooldowns, trader proximity and pickup on the host. Clients send inputs
  and named commands, never damage, rewards, wallet amounts or positions.
- Steam transport peers must belong to the lobby before registration. Input values must
  be finite and bounded; sequences reject stale inputs/commands. Pending commands are bounded.
- Hosts send compressed snapshots at 10 Hz in payloads of at most 1,000 bytes. Protocol
  v3 prevents older builds joining (v3 adds host-confirmed combat feedback). Reassembly accepts reordered chunks, discards stale
  and duplicate chunks, and applies only complete snapshots. Limits are 64 chunks and
  1 MiB decompressed per snapshot; an incomplete update can be superseded by the next.
- Guests interpolate host positions/rotations over 100 ms while retaining local camera
  look; spawns and moves over eight metres snap immediately. This is presentation only,
  with no client movement prediction. Twenty seconds without a complete valid snapshot
  ends the guest session and restores solo progress.
- Guests temporarily disable persistence before applying the host's state and restore
  their solo snapshot on departure or connection failure. Host saves use the existing format.
- Pause menus disable local control without pausing a network expedition. Steam calls
  remain in `SteamService`; solo play works without the extension.
- The expedition HUD shows host/guest role and hunter count, labels the shared wallet,
  and explains session-only guest equipment. Guest store saves are described as protected
  solo progress, rather than the generic disabled-save preview message.
- Reliable host-only feedback confirms guest shots/hits and announces damage/defeat.
  Feedback changes presentation only; health, rewards and coin penalties stay in host
  simulation/snapshots. Guests display warnings from replicated predator windups and
  decay hit/damage overlays without running solo healing or damage logic.

## Checks and remaining limits

`./tests/run_tests.ps1` includes unit, movement, hunting, survival, UI, vehicles, and
four-process loopback co-op. Run only networking with `./tests/run_coop.ps1`.
Use `./tests/run_coop.ps1 -Silence` to keep the host transport open while withholding
updates and verify timeout recovery. The Windows `all` and `coop` suites include both
normal departure and silent-host scenarios; silence logs use `build/test-results/coop-silence/`.
The co-op fixture binds ENet to 127.0.0.1 and uses isolated test saves. It verifies three
guest loadouts against one shared wallet, duplicate-purchase rejection, authoritative
movement, three physical-arrow kills, rewards, collection, replication, guest departure,
host departure, host persistence and unchanged guest save hashes. Lobby lifecycle tests
use a fake Steam backend. These are not proof of Steam connectivity or hostile-network resilience.
The guest fixture also forges its local coin balance, requests an unaffordable bow and
an unknown item, replays a command sequence, tries to buy away from the trader, and
repeats attacks within one cooldown. Expected host wallet/equipment and exactly three
spawned arrows verify those requests cannot bypass host rules. The firing fixture holds
positions still after movement checks; it does not establish moving-target aim under latency.

Real Steam testing is blocked: Windows Application Control rejected the approved native
extension with error 4551. Its manifest is kept as `godotsteam.gdextension.disabled` so
offline operation does not repeatedly attempt to load it. No security policy was changed.
Normal device-administrator review is required before attempting to enable it. After that,
test with separate Steam accounts and computers: host, invite/join, all four players,
disconnect/reconnect, host exit and offline fallback. The configured development App ID is
not a production release entitlement.

Snapshot payloads now stay below the tested ENet datagram budget, and the integration
runner fails on MTU warnings. Unit fixtures cover 42 animals/four hunters, reordered and
missing chunks, stale/duplicate delivery and interpolation/teleports. These deterministic
fixtures are not a live network or graphics benchmark. Real packet loss, latency,
bandwidth and wildlife workloads need profiling before release. Interpolation introduces
presentation delay; guest controls and aim need interactive playtests over realistic latency.
Linux co-op is not validated and Linux native binaries are not installed.

Provisional Windows targets remain 1080p/60 FPS with 720p/30 Low fallback on GTX 1050-class
hardware, a four-core CPU and 8 GB RAM. They are engineering targets, not measured results.
Record hardware, renderer, resolution, seed, four-player workload, frame-time percentiles,
memory and loading time before optimizing or publishing minimum requirements.

## Dependency record

Approved package: GodotSteam GDExtension **4.24**, standard Godot **4.4+**, Windows x64.
No engine replacement or editor updater installation was performed.

Source: [official Codeberg release archive](https://codeberg.org/godotsteam/godotsteam/releases/download/v4.24-gde/godotsteam-4.24-gdextension-plugin-4.4.zip).

Archive size: 27,431,841 bytes. SHA-256:
`D4358888959A03F4DF0C71AAFBCDCA8F34B8CB9D4522AA5C8454F0E9E3DEBBF7`.

Windows x64 debug/release DLLs, Steam API DLL, upstream manifest, readme and MIT notice
are under `addons/godotsteam`. The retained upstream manifest also references platforms
not installed here; only Windows x64 is staged. Archive and extraction scratch files
remain in ignored `build/dependencies`. This package is not enabled or certified for release.
