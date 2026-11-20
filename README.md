# How to Hunt

A first-person, physics-based hunting and progression game with a comedic, cartoony, low-poly look. You are stranded on a mountain island: hunt animals, collect coins, buy better gear and climb to tougher zones. Single-player and 1 to 4 player Steam co-op.

Status: playable local hunting prototype with experimental host-authoritative co-op.

Development targets Windows first; Linux follows Windows stability and performance.
The current prototype is the accepted gameplay baseline. Four-player gameplay is tested
over local ENet networking; Steam lobbies, invitations and transport are wired through
`SteamService` but real Steam connectivity is unverified. The approved GodotSteam 4.24
Windows package is staged locally with its manifest disabled because Windows Application
Control blocked its DLL (error 4551). Solo operation remains available. See [co-op status](docs/COOP.md).

## Playable now
- Explore a continuous mountain with first-person movement, jumping, and slopes you can walk both down and back up.
- Start with a hunting knife: slash nearby ants, collect 120 coins, and buy your first bow.
- Hunt rabbits, boars, deer, foxes, goats, wolves, and bears with physical, gravity-affected arrows. Ants and birds bring the population to 42 animals across nine species. Birds take flight when approached. Aim with right mouse / LT.
- Find rare golden animals and earn bonus rewards for headshots and long-distance hits.
- Walk near spinning gold coins dropped by wildlife to collect them automatically. No pickup key, loot bag, or selling is required.
- Visit Bjorn's timber store on the summit: press E to open it, then click any affordable better bow to buy and equip it. Seven bows and five permanent equipment upgrades show prices and stats in a scrolling mouse-operated catalog. Forty ordinary ants fund the first bow; twenty ordinary rabbits fund the Hunter's Bow.
- Earn XP and hunter levels. Coins, XP, hunts, bow and purchased equipment save locally and reload on launch.
- Original procedural camp, wildlife, bow, sound cues and guided expedition HUD.
- Continuous mountain slopes, worn meadow paths, wind-animated grass and wildflowers, varied forest groves,
  a stocked campsite, warm sunlight and shadows, painted clouds, a dry mountain valley, a sandy eastern region, and two enterable rock caves.

## Requirements
- [Godot 4.4.x](https://godotengine.org/download) (standard build, not .NET)
- Optional: [GodotSteam](https://godotsteam.com) for Steam features. Without it the game runs with Steam disabled.

## Run
```
godot --path .
```

On Windows, double-click `play.cmd`, or run it from any PowerShell folder:

```powershell
& 'C:\path\to\how-to-hunt\play.cmd'
```

This launcher starts Godot directly and works when PowerShell scripts are disabled. It uses `GODOT`,
the locally downloaded 4.4.1 engine in `build/tools/godot-4.4.1/`, or Godot on PATH. The engine download
is ignored by Git and is not part of the repository. `play.ps1` remains available on systems that
permit PowerShell scripts.

You spawn in the middle of the mountain summit, beside Bjorn's store. Walk down the slopes to hunt in the forest and desert, and walk back uphill to buy gear. There is no sea. Click the window to capture the mouse, Esc to release it.

| Action | Keyboard and mouse | Gamepad |
|--------|--------------------|---------|
| Move | W A S D | Left stick |
| Look | Mouse | Right stick |
| Jump | Space | A |
| Sprint | Shift | Left stick click |
| Climb | Walk into a cliff | Walk into a cliff |
| Slash knife / fire bow | Left mouse | Right trigger |
| Aim bow / guard with knife | Right mouse | Left trigger |
| Switch knife / purchased bow | Q | Right shoulder |
| Open store | E | X |
| Collect coins | Walk nearby | Walk nearby |
| Choose and buy a bow | Click a store button | Focus button and confirm |
| Buy next bow at trader | U | Y |
| Close trader / release cursor | Esc | B |

The mountain has a flat summit and continuous walkable slopes on every side. You can return to the store without jumping or wall climbing. Falling below the world returns you to the summit.

## Test
```
tests/run_tests.sh
```
Runs unit tests plus movement, hunting, survival, UI, and vehicle smoke scenarios.

Windows: `./tests/run_tests.ps1` (optional `-Godot C:/path/to/godot_console.exe`). Both runners include
unit tests, a four-direction uphill/downhill movement regression, and a physical-arrow hunt → collect coins →
upgrade playtest with disk save roundtrips and old-save migration. Tests opt out of normal game persistence and use separate
test save filenames. Windows test logs are written to `build/test-results/`.
The Windows runner allows 180 seconds per suite (override with `-TimeoutSeconds`);
the four-direction movement scenario can exceed one minute. `-Suite` selects
`unit`, `movement`, `hunting`, `survival`, `ui`, `vehicles`, or `coop` for focused checks.
Windows `all` also runs four-process loopback scenarios for normal departure and
silent-host recovery (`./tests/run_coop.ps1`, optionally `-Silence`). They include invalid
client purchase/replay/attack requests and guest solo-save checks.

For visual QA on Windows, `./tests/render_preview.ps1` briefly runs the graphical game with saving
disabled and writes expedition/trader screenshots into `build/previews/`.
Use `-Scenario ui` to capture the camera, pause menu and co-op panel.

## Survival and progression
- New hunters start with a knife. Ants near the southern summit slope are the first source of coins; the Makeshift Bow costs 120.
- Wolves, boars and bears pursue nearby hunters and visibly wind up before attacking. Step away before the strike, or face the enemy and hold right mouse with the knife to block 75% of damage.
- Sprinting, jumping, knife attacks, and successful guards spend stamina. Rest restores it; exhausted sprinting resumes after 30 stamina.
- The summit is safe and restores health quickly. After 12 seconds without damage, health also recovers slowly in the wilderness.
- Defeat returns you to the summit and deducts 10% of coins. Purchased gear and XP are preserved.
- The HUD shows health, stamina, XP, target health, threat warnings, and directions to the store. Goals advance from earning a bow to hunter level 4 and 100 hunts.
- Expedition goals include short next-step guidance. Co-op shows host/guest role, connected
  hunter count and shared coins; the guest store explains that session gear does not alter solo saves.
- Coins have no floating labels. Walking nearby collects them automatically.
- Existing progressed saves retain their weapons. Unplayed older starter saves adopt the knife.

## Store equipment
- Trail Boots: 20% faster walking and sprinting.
- Coin Magnet: automatic pickup radius increases to 4 metres.
- Archer's Gloves: 20% shorter reload time for every bow.
- Mountain Boots: approximately 25% higher jumps.
- Lucky Charm: 25% more coins per animal.

Equipment activates on purchase, persists in your save, and cannot be bought twice. Existing version-1 saves remain compatible.

## Saves and current limits
The local save is `user://hunt_save.json` (on Windows normally
`%APPDATA%/Godot/app_userdata/How to Hunt/`). Updates use a flushed temporary file and keep the last
valid save as `.bak`; malformed main saves can recover from the backup. Uncollected ground coins and
wildlife positions reset when the expedition closes. Falling out of the world preserves your coins and gear; defeat in combat costs 10% of coins. Old saves automatically convert any carried loot to coins.

This slice has a continuous mountain, forest and desert areas, two rock shelters, nine animal species, a starter knife, seven bows, and five permanent equipment upgrades. Production Steam co-op validation, cloud saves,
achievements, quests, bosses, gated zones, full settings/rebinding, and the release/export pipeline
remain future milestones. Existing Steam initialization gracefully falls back when GodotSteam is absent.

## Docs
- [Game vision and contributor handoff (Hebrew)](GAME_VISION_HE.txt)
- [Game design](docs/GAME_DESIGN.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Assumptions](docs/ASSUMPTIONS.md)
- [Contributing](CONTRIBUTING.md)
- [Asset licenses](ASSETS_LICENSES.md)

## Share a Windows playtest
Double-click `build-game.cmd` to generate `build/How-to-Hunt-Windows.zip`. Send the ZIP; friends extract it and run `How to Hunt.exe`, keeping its PCK alongside it. Godot installation is not required. This portable prototype bundles the standard Godot engine.

Run `build-game.cmd -Watch` to rebuild after source changes while the generator stays open. Close the playtest before rebuilding on Windows. Failed builds are reported; the previous ZIP remains available.

## Vehicles
Buy the Mountain Bike (25,000), Trail Car (100,000), or Bush Airplane (500,000 coins). Ownership saves automatically. Press V outside the shop to cycle owned vehicles and On foot. WASD moves; in the airplane Space rises and Ctrl descends. These are simple arcade vehicles with block models and player-sized collision, not realistic driving physics. Dismount before hunting. Defeat returns you to walking; vehicle ownership remains.

## Camera and pause menu
C switches first-person / third-person view. Esc pauses and opens HOW TO HUNT: Return to game, Settings, Exit. Click outside the menu to resume. Settings controls camera mode, mouse sensitivity, volume, and fullscreen. Preferences save separately from hunting progress. The HUD shows one active mission with its current amount and progress bar; the first-bow amount is its purchase cost, not a reward.
