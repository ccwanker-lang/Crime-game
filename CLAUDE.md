# CLAUDE.md

**Read DESIGN.md before every milestone.** It is the source of truth for the whole game.

## Working with the user
- The user is new to Godot/GDScript and writes in Dutch: explain each step briefly in Dutch and give
  exact editor clicks (menu > option). Do as much as possible in code / .tscn / .tres files.
- Work in small, testable steps. After each step: how to test solo, with 2 local instances
  (Debug > Customize Run Instances), and over LAN. Wait for feedback unless told "ga door".
- Commit after each working step.

## Conventions
- Godot 4.6 (standard, not .NET), GDScript with static typing, Forward+, Jolt physics.
- Code, comments, UI and NPC text in English. Files in snake_case; a scene's script sits next to it.
- Autoloads: Net, GameState, SaveManager, ItemDB (in `autoload/`). Items are ItemData `.tres` in `data/items/`.
- Networking: ENet, port 7777, max 4 players, HOST AUTHORITATIVE. Clients send requests via RPC,
  host validates and applies; state syncs via MultiplayerSpawner/MultiplayerSynchronizer.
  Singleplayer = host without clients.
- Greybox geometry uses `GreyboxBlock` (box mesh + collision, editable size/color in the Inspector).

## Headless checks
Godot console exe:
`C:\Users\alexc\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe`
- Import / script check: `--headless --path . --import`
- Auto host/join for tests: `--headless --path . -- --host --name=A` / `-- --join=127.0.0.1 --name=B`
- Visual check (needs a window, not headless):
  `--path . --position 4000,40 --resolution 1600x900 -- --screenshot --port=7790` (off-screen, own port so it never
  disturbs the user's open game on 7777) hosts, takes PNGs from fixed
  camera spots (`scripts/debug/screenshot_tour.gd`, list SHOTS) into `screenshots/` (git-ignored) and quits.
  Look at them with the Read tool after map/visual changes.
- Optional `--shots=02,05` limits the tour to those shots. The tour also prints FPS + draw calls.
  `--npcs=N` changes the pedestrian count; `--env:ssil_enabled=false` overrides an Environment property.
- Map self-test (headless): `--headless --path . -- --selftest --port=7791` (`scripts/debug/self_test.gd`):
  lamps on poles, walk + navmesh through every door, debug labels hidden, pedestrians stay off the
  road (except zebras) and keep moving, player jump/speed/crouch. Run it after map/door/NPC/player
  changes; it prints PASS/FAIL. The door/player checks use `player.tscn` with `auto_walk`.
- Network check (headless): `-- --host --port=7792 --netcheck --name=Host`, then 4 s later
  `-- --join=127.0.0.1 --port=7792 --netcheck --name=B`: the client walks crouched 5 m, both print what they see.

## Map / prefabs
- Everything visual is a reusable prefab in `res://prefabs/` (procedural @tool scripts in `scripts/procgen/`).
- `tools/generators/*.py` regenerate materials, prefabs and the test map `world.tscn`; edit the generator, not the output.
- Markers that belong to a building (PotSpot, StoreSpot, ContactSpot...) live inside its prefab; find them with
  `world.get_marker(name)`.
- Doors and other networked props: group `net_state` (`get_net_state`/`apply_net_state`), synced to late joiners.
- Navmesh: cell 0.1 m (coarser cells left corners too tight -> NPCs stuck). Physics layers: 1 world (navmesh bakes from it), 2 doors (not baked), 3 npcs, 4 players. Debug-only nodes (marker
  labels): group `debug_only`, hidden in game, F3 toggles.
- NPCs: `prefabs/npc/pedestrian.tscn` (`Pedestrian`): host runs AI/physics, clients get net_pos/net_yaw/
  anim_state via MultiplayerSynchronizer; spawned by World/NPCSpawner. Road tiles carve the asphalt (minus
  zebras) out of the navmesh with NavigationObstacle3D. Moving meshes: no SDFGI (environment uses SSIL).
- Players: `scenes/player/player.tscn` (`Player`), one per peer, spawned by the host via World/PlayerSpawner
  (spawn function `World._create_player`). The owner moves its body and syncs net_* state; the host checks the
  speed and corrects with `_teleport`. Crouch/look pitch on the model: `scripts/player/pose_modifier.gd`.
- Join order: a client sends `_client_world_ready` once its World is loaded; only then does the host make
  spawned nodes visible to it (`Net.limit_sync_to_world` on every synchronizer of a spawned node; players
  also have a host-owned `HostSync` for that).
