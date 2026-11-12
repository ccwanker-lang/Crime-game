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
- Houses: `Building.upper_floors` (slabs + stacked open-step stairwell along the left wall + railing) and
  `furnish` ("home"/"storage", `furnish_from_floor`) instance furniture from `prefabs/interiors/` + a ceiling light per
  floor; the zone behind the front door stays free. Hand-furnished buildings (starter room, store, hospital, gun shop)
  keep `upper_floors` off (the stairwell would cut through their furniture).
- Map self-test (headless): `--headless --path . -- --selftest --port=7791` (`scripts/debug/self_test.gd`):
  lamps on poles, walk + navmesh through every door, debug labels hidden, pedestrians stay off the
  road (except zebras) and keep moving, player jump/speed/crouch, combat (ammo, reload, damage, death,
  loot bag, respawn), stairs (walker up/down every flight + NPC navmesh to every top floor). Run it after
  map/door/NPC/player/combat changes; it prints PASS/FAIL. `--only=stairs,traffic` runs just those checks
  (names = `CHECKS` in self_test.gd). The door/player checks use `player.tscn` with `auto_walk`.
- Network check: `python tools/netcheck.py [port]` runs both sides and kills both process trees afterwards
  (a shell `timeout` only kills the console wrapper: the real Godot keeps the port). Manual form (headless):
  `-- --host --port=7792 --netcheck --name=Host`, then 4 s later
  `-- --join=127.0.0.1 --port=7792 --netcheck --name=B`: the client shoots the host dead, takes the loot bag,
  sees the respawn, then walks crouched 5 m; both print what they see. The host runs ~40 s: wait for it to
  quit before starting another run on the same port. Clients don't bake the navmesh (host-only AI). Under heavy CPU load
  (e.g. the user's game open) the client can load too late for the host's 40 s window: rerun before debugging.
- Viewmodel check (window): `-- --vmpreview --port=7790 [--reload=0.5] [--fire] [--model=1]` saves
  `screenshots/vm_view.png` (player view) + `vm_side.png` (side view) of the first-person arms + weapon.
  `--script res://scripts/debug/model_preview.gd -- --scene=res://... --size=0.3` renders any scene (no autoloads).

## Map / prefabs
- Everything visual is a reusable prefab in `res://prefabs/` (procedural @tool scripts in `scripts/procgen/`).
- `tools/generators/*.py` regenerate materials, prefabs and the test map `world.tscn`; edit the generator, not the output.
- Markers that belong to a building (PotSpot, StoreSpot, ContactSpot...) live inside its prefab; find them with
  `world.get_marker(name)`.
- Doors and other networked props: group `net_state` (`get_net_state`/`apply_net_state`), synced to late joiners.
- Navmesh: cell 0.1 m (coarser cells left corners too tight -> NPCs stuck). Physics layers: 1 world (navmesh bakes from it), 2 doors + props like loot bags (not baked), 3 npcs, 4 players (players do not collide with npcs for now). Debug-only nodes (marker
  labels): group `debug_only`, hidden in game, F3 toggles.
- NPCs: `prefabs/npc/pedestrian.tscn` (`Pedestrian`): host runs AI/physics, clients get net_pos/net_yaw/
  anim_state via MultiplayerSynchronizer; spawned by World/NPCSpawner. Road tiles carve the asphalt (minus
  zebras) out of the navmesh with NavigationObstacle3D. Moving meshes: no SDFGI (environment uses SSIL).
- Weapons: `WeaponData` (extends ItemData) in `data/items/` (pistol.tres); visual model `prefabs/weapons/*.tscn`
  (`WeaponModel`, origin = grip, barrel -Z, markers Muzzle/Ejection/RightHand/Support/MagazineDir). Shooting lives
  in Player/Combat (`PlayerCombat`): owner predicts + plays effects, host validates, raycasts, applies damage,
  sends effects to the others. First person = `Viewmodel` (copy of the player's character, gloved, arms by
  `ViewmodelIK`, procedural recoil/reload/draw, `viewmodel.gdshader` keeps it in front of walls). Effects:
  `WeaponFX` (flash, casings, impact decal/particles/sound per surface). Sounds: `tools/generators/gen_weapon_sounds.py`.
- Weapons are inventory items (pistol, smg, ak47, shotgun, sniper; `PlayerCombat.LOADOUT` = index order, models
  `prefabs/weapons/`, AK/SMG/shotgun procedural via `ProcGun`). Number keys 1-8 = hotbar slot (`select_slot`): a
  weapon there is drawn. Spare rounds are ammo items (`WeaponData.ammo_id`: ammo_9mm/762/12g/308); only magazines
  live in PlayerCombat (`_h_mags` on the host). New player/respawn: `GameState.give_starter_kit` (pistol + 24 9mm).
  Death: `host_unload` puts loaded rounds back as items before the loot bag. Gun shop: `prefabs/buildings/gun_shop.tscn`
  (Vince, `ItemData.pack_size` = ammo per box). F6 = debug +€1000. Third person aims at the camera's centre ray.
- Ragdoll: `Ragdoll` (`scripts/npc/ragdoll.gd`, SkeletonModifier3D) builds capsule RigidBody3Ds + ConeTwist joints
  from the pose on death (every peer, world layer only), drives the bones; host sends the shot push (`_ragdoll_push`).
- NPC combat: `Pedestrian.host_damage`/`is_head_hit`; dead -> anim DEAD (ragdoll), removed after `corpse_time`, World
  `respawn_pedestrian_later` spawns a new one after `respawn_time` (60 s). `hear_gunshot` (group call per shot) -> flee.
- Inventory: host-owned in GameState.player_data (8 slots, stacks up to ItemData.max_stack; `give` returns what
  didn't fit). The owner gets cash + items via `Player.send_wallet()` (call it after every change) -> HUD bar.
- Shops: `prefabs/npc/shopkeeper.tscn` (`Shopkeeper`, a stationary Pedestrian + layer-2 body) placed in building
  prefabs by `gen_prefabs.py` (`shopkeeper(...)`, stock = item ids). E opens the HUD shop window; `request_buy`
  -> host checks distance/stock/cash/space -> `buy_result`.
- Stations (`scripts/stations/`, prefabs in `prefabs/stations/`): `Station` base = StaticBody3D on layer 2,
  host-owned `state` Dictionary stored in GameState.world["stations"][station_id], E -> `do_action(player)` on
  the host, `tick(hours)` runs on every peer in in-game hours (DayNight.hours_per_second, F7 speeds it up), host
  re-sends every 3 s + late-join snapshot. GrowPot (soil -> seed -> water -> grow -> harvest Fresh Weed),
  GrowLamp (boost), DryingRack (Fresh Weed -> Dried Weed `weed_bud`). Plant visual: `WeedPlant` (procedural,
  atlas from `tools/generators/gen_weed_atlas.py`). `Player.show_message()` = host -> owner toast.
- Selling (step 7): `PackagingTable` station (weed_bud + baggie -> weed_bag). Customers are pedestrians with
  `wants`/`offer` (synced, group `customer` + `interactable`, "€" Label3D); World `_customer_loop`/`make_customer`
  (host), E -> `Pedestrian._server_sell` rolls fair/short/run (`Pedestrian.force_outcome` for tests). The interact
  ray hits layer 3 (npcs) too; clients enable a customer's collision only for that ray.
- Phone (step 8): `Phone` (scenes/player/phone.gd, built in code, in the HUD) + `PhoneMap`; Tab = action `phone`.
  Host -> owner texts via `Player.phone_message(contact, text, deal)` / `World.phone_all`; answers go back with
  `Player.phone_reply` -> `Pedestrian.answer_text`. Webshop: `Player.webshop_buy` (legal items only) ->
  `DeliveryBox.order` (station in the Starter Room, group `delivery_box`).
- Save (step 9): `SaveManager` (JSON with `JSON.from_native` state, so ints/Vector3 survive), autosave + on Leave/
  quit; World `capture_for_save` / `_restore_from_save`, saved player pos/health/mags applied in `_spawn_player_for`.
  Test flags disable saving; `--save=user://x.json` (own file) + `--autosave=N` for save tests. Never touch the real save.
- Health/death: host-owned `health`/`dead` on Player (HostSync). Death -> `LootBag` (`prefabs/props/loot_bag.tscn`,
  World/LootSpawner) with the cash + carried items from GameState, respawn at a free hospital spawn point.
- In .tscn files a Transform3D basis is written as ROWS (x.x, y.x, z.x, x.y, ...), not columns.
- Traffic: World/Traffic (`scripts/traffic/traffic.gd`) holds the closed `TrafficRoute`s (corners + fillet radii,
  right-hand lanes at +-1.75 m) and spawns `prefabs/vehicles/car.tscn` (`Car`, AnimatableBody3D on layer 2, mesh by
  `ProcCar`) via World/CarSpawner. Host drives (sense boxes along the route ahead, junction reservation per square
  in `Traffic.JUNCTIONS`), clients smooth net_pos/net_yaw. `--cars=N` changes the count; the self-test spawns its own.
- Players: `scenes/player/player.tscn` (`Player`), one per peer, spawned by the host via World/PlayerSpawner
  (spawn function `World._create_player`). The owner moves its body and syncs net_* state; the host checks the
  speed and corrects with `_teleport`. Crouch/look pitch on the model: `scripts/player/pose_modifier.gd`.
- Join order: a client sends `_client_world_ready` once its World is loaded; only then does the host make
  spawned nodes visible to it (`Net.limit_sync_to_world` on every synchronizer of a spawned node; players
  also have a host-owned `HostSync` for that).
