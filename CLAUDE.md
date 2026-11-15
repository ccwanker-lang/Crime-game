# CLAUDE.md

**Start elke sessie met HANDOFF.md, DESIGN.md en CHANGELOG.md lezen.**

**Read DESIGN.md before every milestone.** It is the source of truth for the whole game.

## Working with the user
- The user is new to Godot/GDScript and writes in Dutch: explain each step briefly in Dutch and give
  exact editor clicks (menu > option). Do as much as possible in code / .tscn / .tres files.
- Work in small, testable steps. After each step: how to test solo, with 2 local instances
  (Debug > Customize Run Instances), and over LAN. Wait for feedback unless told "ga door".
- Commit after each working step.
- FIXED RULE (progress docs): after EVERY finished point update DESIGN.md (Roadmap status line + a Decisions entry
  for every choice made) and add a CHANGELOG.md line, in the same commit. "ga verder volgens de Roadmap" in a new
  session = read the Roadmap and continue with the first point that is not done, in the order it gives.
- Work autonomously: test yourself, commit per point, ask no questions (choose, and write the choice + why in
  DESIGN.md Decisions).
- FIXED RULE (test scenarios): every time you ask the user to test something, first make a scenario for it in
  `scripts/debug/scenarios.gd` (`Scenarios.LIST` + a `match` branch in `run`) and give them its name (F9 in the game,
  or `--scenario=<name>`). Never ask the user to test something for which they would first have to collect or make
  items, money, time of day, a place or NPCs themselves. Check every new scenario with
  `-- --scenario=<name> --scenario-quit --port=7790 --name=Tester` (headless; prints a `[ScenarioCheck]` line).

## Parallel sessions (from 2026-11-13)
- Session A = main in `C:\Users\alexc\game`; session B = branch `feature-b` in the worktree `C:\Users\alexc\game-b`.
- Split: A does Roadmap points 34-42, the map (world.tscn, gen_world.py), DESIGN.md and CHANGELOG.md. B does ranks + XP
  (Progression), never touches the map or DESIGN.md/CHANGELOG.md, tests on port 7778 (A uses 7777/7790-7795).
- Coordination in `C:\Users\alexc\game-coord\`: A writes ONLY in A.md, B ONLY in B.md. A.md holds what A works on,
  which files it touches, and every change B must know (renamed functions, changed signals, new player_data/save
  fields, HUD changes). Read the other side's file before every new point and after every commit; answer there.
- Check B's commits now and then: `git log main..feature-b --oneline` (the worktrees share the repo).
- Never touch files the other session lists as "busy"; write what you need in your own .md instead.
- Merging: when B.md says feature-b is done and rebased on main, A merges it into main, copies
  NOTES_feature-b.md into DESIGN.md (Roadmap + Decisions) and CHANGELOG.md, and runs the full self-test + netcheck.

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

- Art style (point 27, DESIGN "Art direction"): stylized low-poly. Palette `assets/palette/palette.png` + `Palette`
  (`gen_palette.py`); stylized materials (same names) in `prefabs/materials/stylized/` (`gen_materials.py`, shaders
  `stylized.gdshader` / `stylized_window.gdshader`); `ArtStyle.stylized` switches generator geometry (ProcTree,
  GrassField, Hedge, Building trim), `ArtStyle.restyle(root)` swaps materials by name. New: `ProcShrub`,
  `ProcBackdrop` (hills/tree rows around an area), `MeshBuilder.blob`, ProcGun `PISTOL` (`prefabs/weapons/
  pistol_stylized.tscn`). Art test: `scenes/art_test/style_compare.tscn`, `--style-shots [--shots=street,...]` saves
  `screenshots/style_<spot>.png`. Rolled out (27c): `prefabs/materials/` IS the stylized set, `ArtStyle.stylized` is
  on, imported Poly Haven models get painted textures (`tools/generators/gen_painted_textures.py` -> `assets/painted/`,
  swapped by `ArtStyle.restyle`); building tints via `palette_tint.ptint`. HUD (27d): theme `assets/ui/game_theme.tres`
  (Fredoka font), `HudIcon.make(kind, color, px)`, F1 help panel. `-- --scenario=<id> --scenario-quit --scenario-shot
  [--help] --port=7790` (window) saves `screenshots/scenario_<id>.png`.
- Admin mode (host only, `OS.is_debug_build()`, never in a release export; `Player.admin_allowed`): F10 noclip fly
  (`admin_noclip`, collision off, Space/Ctrl up/down, Shift x3), F11 god mode (`admin_god`: `host_damage` ignored, no
  ammo used in PlayerCombat), F12 `Wanted.clear` + every officer `on_arrested` (backs off). HUD `set_admin(text)` =
  red label top centre; keys in the F1 help. Self-test check `admin`. Debug keys in use: F1 F3 F4 F6 F7 F9 F10-F12
  (F8 = session B's +XP).
- Scenarios: `Scenarios` (static, `pending`, `run(world, id)`, `restart_into(tree, id)`) + `ScenarioMenu` (F9, in World).
  A scenario restarts the host into a FRESH game on `user://scenario_test.json` (`SaveManager.use_scenario_save`,
  `scenario_mode`); the real save is written once before and never touched; the main menu switches back
  (`use_real_save`). Helpers: `_kit(me, cash, [[id, count]...])` (exact inventory), `_place(me, pos, look_at, dn, hours)`,
  `_at_keeper(world, me, "Building", dn, hours)`.

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
  Point 29: off-navmesh straight walks `Pedestrian._go_direct` / `straight_way_clear`; `cross_road()` (jaywalk,
  `Pedestrian.jaywalk_chance`, `crossing_road` flag), police/Crows `_chase_to`; scenario road_crossing.
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
- Item models + icons: `ItemData.get_model()` (`model_scene`, else `prefabs/items/<id>.tscn`, procedural `ProcItem`) and
  `get_icon()` (`assets/icons/<id>.png`). After adding an item or changing a model run (window)
  `--path . --position 4000,40 --resolution 256x256 --script res://scripts/debug/render_icons.gd [-- --only=id,id]`,
  then `--import`. Poly Haven models: `python tools/fetch_polyhaven.py . <id>...`.
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
- Phone deals (point 34): customer text = proposal; phone buttons -> `Player.phone_reply(deal, "accept"|"decline"|"counter",
  price)` -> `Pedestrian.answer_text` (`COUNTER_STEPS`, `COUNTER_PICKY`, `force_counter` for tests, deal id "#fixed" = no
  second counter). Synced `deal_ok` (green/yellow €) + `customer_name`; `accept_deal()`; E -> `Player.open_deal` (HUD
  talk window) -> `confirm_deal()` -> host `_server_sell` (refuses without `deal_ok`; calls group "progression"
  `on_sale(seller, bags, paid, outcome)`).
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
- Placement (point 6/17/18): placeable items have `ItemData.place_scene` (+ `category` station/furniture), made by
  `tools/generators/gen_items.py` (furniture = every `prefabs/interiors/` prefab). Owner: `PlayerPlacement` (ghost, grid,
  R/wheel rotate, LMB place, hold E pick up; point 36: only while `build_mode` (B, action `build_mode`,
  `set_build_mode`, HUD `set_build_mode`)) -> `Player.request_place`/`request_pick_up` -> host re-checks with
  `Placement.check` (inside a crew-owned `Property`, on a floor, nothing in the way). World/PlacedSpawner spawns
  `GameState.world["placed"]` records (`World.host_place`/`host_remove_placed`); placed stations use station_id
  `placed/<uid>`, furniture sits in a `PlacedFurniture`. Owned properties adopt their building's furniture
  (`Property.host_adopt_furniture`). `StorageLocker` station + HUD storage window
  (point 38: `BookshelfStorage` subclass = the "bookshelf" item, gen_items `FURNITURE_STATIONS`). Tests: `World.debug_weed_corner()`.
- Trash (point 39): items `empty_box` (DeliveryBox take) / `plant_waste` (harvest), category "trash"; `TrashBin` station
  (group `trash_bins`, `host_empty`), the only `Placement.OUTDOOR` item (in front of a crew-owned building,
  `outdoor_property`, `lane_distance` LANE_MIN/MAX). World/Garbage (`Garbage.dispatch()`, 08:00) spawns
  `Traffic.spawn_garbage_truck` (`Car.garbage`, `garbage_stops`, group `garbage_trucks`). Scenario trash, check trash.
- Laundering screen (point 40): `LaunderSafe.interact()` opens `Player.open_safe` -> HUD `open_safe` (ledger,
  `LaunderSafe.ledger()`, `eta_text`, Deposit = `deposit()`); `_done` texts the player. Screenshot flag `--safe`.
- Mouse wheel (point 41): `PlayerCombat.cycle(step)` = next/previous hotbar slot (`select_slot`).
- Work effects (point 42, changed by 58): `Station.work` set in do_action -> `Player.host_work(kind, at)` -> every peer
  `_play_work` (NO body clip / kneel any more; `WORK_FX` particles at the object or else `Poof.spawn`, the can tilts).
  Placing / picking up: `World.host_poof(pos)` (all peers).
- Storage/drop (point 20): `StorageLocker.request_move(to_locker, index, count)` (count 0 = stack), HUD slot grids
  with drag (`set_drag_forwarding`); `Player.request_drop(index, count)` -> `World.spawn_loot_bag(..., dropped=true)`
  (LootBag shows the item model). Free locker at the Starter Room's `LockerSpot` (world["free_locker"]).
- Black market (point 7): `prefabs/buildings/garage.tscn` (gen_prefabs `garage_extra`), `NightGate` (NetDoor subclass,
  locked by day from the workshop side) + Shopkeeper `night_only` (Rook). "Night" = `DayNight.is_night()` (lights on).
  The screenshot tour sets 23:00 for shots whose name contains "night".
- Real estate (point 8): `Property` (`for_sale`, `price`, `description`; `host_set_owned` adopts the furniture and tells
  every peer) inside buildings; `EstateAgent` (Shopkeeper subclass, `prefabs/buildings/real_estate.tscn`) lists them in
  the shop window. South Street (z 60) holds the agent, warehouse and police; the other properties sit in
  their own neighbourhoods (point 26); gen_world `property_node(...)` adds one. Moving a property later: add its old
  spot to `World.OLD_PROPERTY_SPOTS` and bump `LAYOUT_VERSION` (`migrate_layout` carries old saves along).
- Map icons (point 35): `PhoneMap` draws owned properties (green) + `show_for_sale` pins (orange) + `focus`
  (`PhoneMap.property_spot(p)`); the estate window (`PlayerHUD._fill_estate`) embeds one with "Where?" buttons.
  Screenshot flags for `--scenario-shot`: `--help`, `--deal`, `--shop` (nearest shopkeeper), `--phone-map`.
- Sleep (point 37): World/Sleep (`Sleep`, host): `Player.request_sleep(on)` -> `Sleep.host_set` (time window, own bed =
  PlacedFurniture item "bed", not wanted); all players in bed -> `_morning()` (07:00, stations `tick(skipped)`);
  owner `sleeping` + HUD `set_sleep`. Scenario sleep, self-test check sleep.
- Laundering (point 9): player_data "cash" = dirty, "clean" = laundered (`GameState.add_cash(name, -x, legal)` pays
  from both pots, legal = clean first; `add_clean`; death drops only dirty). `LaunderSafe` station
  (`prefabs/stations/launder_safe.tscn`, `daily_max`) in `prefabs/buildings/bakery|barber|laundromat.tscn`; its
  `property()` = the building's Property (must be crew owned). HUD shows "€ dirty   clean € x".
- Police (points 10/25): `PoliceOfficer` (Pedestrian subclass, `prefabs/npc/police_officer.tscn`, Anim AIM/RUN_GUN, cap +
  pistol in the fist) spawned by `World.spawn_police`/`add_officer` at `PoliceStation` OfficerSpawn markers (`--police=N`).
  Crimes: group call `report_crime(player, pos, murder)` on "police" from PlayerCombat (every shot, every kill).
  Patrol car = `Car.police` (+ synced `siren`), `Traffic.spawn_police_car` (`--police-cars=N`). NPCs can damage players:
  `Player.host_damage(amount, attacker: Node, from)`. Default: no foot patrols, 2 patrol cars (none with --netcheck)
  with `crew_size` 2 (`Car.crew_out`, `_police_come_back`); officers have `from_car` (LEASH 60 m). Arrest:
  `PoliceOfficer.resisting(p)` (`_hostile`, `Player.host_last_shot`, weapon drawn after warning, running) else
  `_try_arrest` -> `Player.host_arrest(by)` (confiscate illegal, fine, `ReleaseSpot` marker), group call `on_arrested`.
- Wanted level (point 28): `Wanted` (`scripts/police/wanted.gd`, node World/Wanted, host logic, `Wanted.current`),
  config `WantedConfig` in `data/police/wanted.tres`. Crimes: `Wanted.report(player, kind, pos)` (kinds heard,
  kill, kill_officer, kill_rival, assault, resist; round 4: holding a gun is no crime); search phase = one timer
  `search_time[stars]` then all stars go (`Wanted.search_left(p)`); `units_per_star` = extra dispatched cars; `Wanted.clear(p, why)` on arrest/death; synced
  `Player.wanted_stars` / `wanted_seen` -> HUD stars (`PlayerHUD.set_wanted`). Officers: `_should_shoot(p)` by stars,
  group call `on_wanted_cleared`, `heavy` (SMG, `data/npc/police_heavy.tres`, spawn-synced). Cars: `Car.respond`,
  `chase`, `dispatched`, `roadblock` (`start_roadblock`/`end_roadblock`), `Traffic.nearest` / `spot_ahead`,
  `spawn_police_car(r, prog, crew, heavy)`. `Wanted.enabled = false` = no stars (selftest default, `_no_police`),
  `Wanted.dispatch` off in selftest/netcheck. Tests: `wanted.debug_set(p, stars)`; scenarios wanted_one/three/five/hide.
- Police life (point 30): `PoliceOfficer.question(npc)` / `is_busy()` / `chats`, `Pedestrian.hold_for_talk` /
  `free_for_talk` / `face`, Anim.TALK; `Car.question_in` (patrol car stops to question, `_try_question`, `_in_car`);
  World POLICE_COUNT = 2 foot officers. `PoliceOfficer.talk_time` (tests shorten it). Scenario police_life.
- Black Crows (points 11/31): `Rival` (`scripts/npc/rival.gd`, PoliceOfficer subclass, group `rivals`, `prefabs/npc/rival.tscn`,
  profiles `data/npc/rival_combat.tres` / `rival_ak.tres`), house `prefabs/buildings/crows_house.tscn` (RivalSpawn markers) in
  the turf yard. `Rival.role` YARD/STREET, `Rival.turf/on_turf/yard_point`, `memory` + `remember(p)` (shared within 25 m).
  World `_rival_loop` (fills `rival_count` 6 in the yard, sends `rival_street` 2 out at night; `--rivals=N`; 0 in
  selftest/netcheck) / `add_rival(at, ak)` / `rival_died` (respawn 60-120 s). Officer hooks: `_group`, `_head_mesh`,
  `_target_off_limits`, `_log`, `_leash_center`/`_leash_range`; synced `gun` (weapon id). `Rival.obey_daylight` (tests). Point 59: clash clock `PoliceOfficer.clash_max`/`end_clash`/`in_truce()` (truce: no NPC fights, Crows go home).
  Scenarios rivals_night, crows_turf. Round 4 (31a): `PoliceOfficer.foe` (armed NPC of the other side, `set_foe`,
  `is_enemy`, `_rally`, `_fight_foe`), group call `report_npc_crime(shooter, origin)` on "police" (officers +
  `Car.respond(null, origin, npc)`); street Crows attack officers (`Rival.spot_cop`). 31b: World `rival_night_pool`
  (20) / `rival_pool_left` / `refill_rival_pool()` at dusk, `rival_respawn`. Scenarios wanted_timer, police_vs_crows.
- Park + agora (point 46): `ParkGoer` (`scripts/npc/park_goer.gd`, `prefabs/npc/park_goer.tscn`, Pedestrian subclass,
  group `park_goers`, spawn-synced `role` DOG/SMOKER/FOOTBALL + `team`, `leaving`), `ProcDog` (local visual child),
  World `add_park_goer(at, role, team)` / `park_path()` (Markers/ParkPath) / `_park_loop` (`park_dogs`, `park_smokers`,
  Markers/ParkSmokeSpot), `Pedestrian.can_be_customer()`. `Agora` (`scripts/world/agora.gd`, @tool, node NavRegion/Agora):
  host ball sim + `_apply_ball` RPC, `kick(dir, power, by)`, `start_match(n, minutes)` / `end_match`, `football_step(p)`,
  `kicks`/`goals`/`score`. Generator: `PARK_PATHS` / `AGORA_POS` in gen_world.py (own `prng`). Scenarios park, agora.
- Own cars (point 45): `PlayerCar` (`scripts/vehicles/player_car.gd`, CharacterBody3D layer 2, arcade model, ProcCar
  visuals; driver's peer simulates -> `_drive` RPC -> host checks -> synced net_pos/net_yaw/net_speed/net_steer + `seats`
  (seat 0 drives); `host_enter(p)`/`host_exit(p)`, `request_enter/exit`, `test_drive`/`test_input` for tests, host
  `_host_hits` (people hit at speed), `honk`). `Vehicles` (node World/Vehicles, own MultiplayerSpawner, `host_spawn`,
  `nearest`, `capture`/`restore` with GameState.world["vehicles"]). `CarCatalog` (models, prices), `CarDealer`
  (Shopkeeper subclass in `prefabs/buildings/car_dealer.tscn`, `request_buy_car`, markers CarDelivery1-4), `DisplayCar`.
  Player: `vehicle`/`seat`, `enter_vehicle`/`leave_vehicle`/`_ride`/`_car_input`; actions `vehicle` (F) + `horn` (H);
  HUD `set_car`/`update_car`/`_fill_cars`. Scenarios car_dealer, driving (`--drive` shot flag); self-test check vehicles.
- Grass cover (point 61): `GrassCover` (World child, not headless): chunks round the camera, tufts where a ray hits a
  `GroundArea` (`grass` export) minus GrassField + RoadTile squares (`field_rects`, `tuft_points`). Self-test check grass.
- Border + safety net (points 56/57): gen_world `PLAY` (x -193..75, z -133..106) = the playable area; border =
  BorderHedge ring 6 m out + Backdrop trees + Bounds walls 7 m out (Quay wall at the sea); one `Ground` (+ GroundSouth).
  Host safety net: `Player.FALL_Y` (-12), `Player.safe_pos`, `_host_fall_net` (player + PlayerCar). Self-test check
  ground (hole scan, wall sweep, net). Scenario open_border.
- West side (point 47a): gen_world section "the west side" (own `wrng`, helpers `paved`/`pbox`/`fence_line`/
  `container_stack`): Main Road to x -180, Industrial Road x -114, Quay Road z 84, quay apron z 90..104, sea =
  `Sea` (water.tres) south of z 104, Bounds W/NW/Quay/WestN/WestS, `GroundWest`, `BackdropWest` (+ `skip_rects` on
  Backdrop), properties lab_warehouse / harbor_storage, traffic route 2 via the quay, junction (-114, 0).
  PhoneMap.BOUNDS/SEA. Shots 80-86 (`80_west_top`). Scenario west_side. Point 60: South Street bends at (-66, 60) down to Quay Road (T `QuayJunction` at (-114, 84)); traffic routes 3/4 = the harbour loop both ways; shots 93/94, scenario harbour_road. 47b: section "the countryside" (`frng`):
  Country Lane x -150 (T at (-150, 0)), Hollow Farm (Barn = property `barn`, Farmhouse, Silo), Field0/1; shots 87-89,
  scenario countryside. 47c: Crows' pier: `Rival.post` (&"yard"/&"harbour"), `Rival.TURF_NODES` (TurfYard /
  HarbourTurf = Node3D with meta size), `turf(tree, post)`, `yard_point(from, post)`, World `rival_harbour` (3),
  `add_rival(at, ak, post)`, `_alive_rivals(post)`, `rival_died(post)`, Markers/HarbourCrows; scenario harbour_crows,
  self-test check harbour.
- Fuel (point 48 rest): `PlayerCar.fuel` (0-1, synced, saved; `FUEL_RANGE` 3 km, `TANK_LITRES`, `FUEL_PRICE`,
  `host_use_fuel(m)`, `host_refuel()`, `litres_missing()`; empty = no throttle). `FuelPump` (`scripts/vehicles/fuel_pump.gd`,
  group `fuel_pumps`, `car_here()`, `_host_fill(peer)`), gas station QuickFuel in gen_world (FuelPump1/2, Markers/GasStation).
  Scenario gas_station, self-test check fuel.
- Cover garage (point 52): `prefabs/buildings/cover_garage.tscn` (gen_prefabs `cover_garage_extra`, node CoverGarage on
  South Street, Property "cover_garage"; gen_world `SKIP_NODES` drops the row houses it replaced). `RepairBay` station
  (`scripts/stations/repair_bay.gd`, `new_job(i)`, JOBS, item `car_parts`), `HiddenShelfDoor` (NetDoor subclass, node
  SecretShelf, marker HiddenRoomSpot). Scenario cover_garage, self-test check garage.
- Territory (point 51): `Territory` (`scripts/world/territory.gd`, node World/Territory, `Territory.current`), state in
  GameState.world["territory"] {id: inf/held/warned}, districts = `Staff.config.districts` (nearest anchor,
  `district_at`), `crew_holds(pos)`, `host_add`, `debug_set`, `send_crow(p)` -> `Rival.send_after(p)`; group hooks
  `sale_hooks.on_sale(seller, npc, bags, paid, outcome)` (Pedestrian._server_sell) and `kill_hooks.on_kill(killer,
  victim)` (PlayerCombat, Player.host_damage for NPC killers); phone app Turf (`--turf` shot flag). Scenarios
  turf_take, turf_danger; self-test check territory.
- Prison intro (point 49): `Intro` (`scripts/story/intro.gd`, node World/Intro, `Intro.current`): GameState.world["story"]
  ["intro"] "running"/"done" (`_decide`: new game only; tests/scenarios skip; `--intro` forces), player_data
  intro_step/intro_stash/intro_cell, `host_on_spawn` (World._spawn_player_for), steps WALK/TALK/DESK/BUS/BOARDED,
  `request_talk(role)` / `request_board` / `request_skip` (F2), `debug_start(p)`. Point 50: `host_on_spawn(p, new_player)`
  -> `_begin_late` (short intro after the intro is done), `debug_late_join(p)`, `--late-intro` / `late_join_in_tests`. Prefab `prefabs/buildings/prison.tscn`
  (gen_prefabs `prison()`, node Prison at gen_world PRISON_POS, markers Cell1-4/DeskSpot/BusSpot, `CellDoor`
  NetDoor subclass, `IntroNPC` roles mentor/desk/guard, `ProcBus` boardable), marker Markers/BusStop. HUD
  `set_tutorial` / `say` / `fade`. Scenario prison_intro (`--yard` shot flag), self-test check intro.
- Mountain pass (point 49b): `Mountain` (`scripts/procgen/mountain.gd`, node Mountain at the world root, StaticBody per
  part: Terrain heightmap / Road ribbon trimesh / Rails / Pines / Rocks) built from `data/mountain/mountain.json` +
  `height.bin` (made by `tools/generators/gen_mountain.py .`; export must include `data/mountain/*`). Statics
  `route_points()` (traffic route 5, `TrafficRoute.from_points`), `bus_points()`, `road_points()`, `on_road(p)`,
  `height_at(x, z)`, SNOW_LINE. Prison at gen_world PRISON_POS (-150, 0, -385); north hedge gap PASS_GAP; CAR_COUNT 6.
  Intro bus ride: `Intro._start_ride`/`_set_bus`/`bus_progress`/`ride_speed_scale` (tests), `Player.enter_bus`/
  `leave_bus`/`bus_ride`. Scenario mountain_pass, self-test check pass, shots 98/99/A0-A3.
- Bunker (map zone 8): part of `Mountain` - gen_mountain.py writes "side_road" (east off the summit at z -254) +
  "bunker" (x, y, z, yaw); `Mountain._ribbon(pts, name)` builds both roads, `_build_bunker()` the portal (node
  Mountain/Bunker, shut door), `Mountain.bunker_spot()`. Scenario bunker, self-test check bunker, shots F0-F2.
- Border mountains (map zone 9): `BorderRange` (`scripts/procgen/border_range.gd`, node BorderRange) from
  `data/border/` (`tools/generators/gen_border.py .`, LAND rects = playable land + sea; add a rect for a new zone and
  keep it in step with gen_world's Ground slabs). `BorderRange.height_at(x, z)`, `land_rects()`. Ground slabs: Ground,
  GroundSouth, GroundEast (highway strip x 83..140), GroundCity (x -72.5..140, z 114..400). Bounds walls only at the
  water (Quay, SeaEast). Map blueprint: docs/map_blueprint.png + docs/map_zones.png, shot B0_blueprint (overview).
- City (map zone 7): gen_world section "the city" (`crng`, `road_tile(x, z, arms)` picks tile + rotation, `tower(...)`,
  `block_towers`, PLAN per block, `lane_route(nodes, uturn)`), node City (not under NavRegion). `Tower`
  (`scripts/procgen/tower.gd`, prefabs/city/tower.tscn, material tower_glass), `ParkingGarage` (drivable ramps).
  Traffic: routes 6-8 from data/city/city.json (`Traffic.load_city()`, `city_first_route`, static `JUNCTIONS`/`LIGHTS` =
  `VILLAGE_JUNCTIONS`/`VILLAGE_LIGHTS` + city), `spawn_cars(n, city)`. Scenario city, self-test check city, shots C0-C3.
- Slums (map zone 3): gen_world section "the slums" (`srng`, loop SLUM_LOOP, road tiles without centre line),
  prefabs/slums/ (`Shack`, `Caravan`, `FireBarrel`), property slum_shack (SlumShack), traffic route 9 (appended to
  data/city/city.json). Scenario slums, self-test check slums, shots D0-D2. ShootingRangeSpot now (-145, -118).
- Army base (map zone 2): gen_world section "the army base" (`arng`, node ArmyBase at the root, AB rect x -104..-36,
  z -430..-350, `ab_fence`, marker ArmyBase/ArmyBaseSpot), prefabs/army/ (`Watchtower`, `ArmyTruck`). Pass road end
  (-106, -355.65). Scenario army_base, self-test check army, shots E0-E2.
- Ranks (milestone 3): `Progression` autoload (crew XP in GameState.world["progress"], host_add/host_sale/host_kill,
  item_lock/property_lock gates, off in selftest/scenarios unless `force_gates`), `RankConfig` in
  `data/progression/ranks.tres`, HUD `RankPanel`. F8 = +100 XP, `--xp=N`. Scenario ranks, self-test check ranks.
- Staff (milestone 3): `Staff` autoload (GameState.world["staff"], host tick in in-game hours, `request(...)` ->
  `answer`, `debug_hire`), `StaffConfig` in `data/staff/staff.tres` (roles, rates, districts), visuals
  `StaffViews`/`StaffNPC` (local), UI `CrewWindow` (phone app "Crew", E on a dealer). Scenarios staff_workers,
  dealers; self-test check staff.
- Meth (milestone 3): `ProcessStation` (generic timed machine, staff_load/take/attend), `CookStation` (stir at 40%),
  `CoolingPlate`; items lab_chemicals/activator/meth_tray/meth_shard/meth_bag; `PackagingTable.PACKS`; `Products`
  autoload (BAGS + prices, Rook's extra stock at runtime, `pick_customer_product`); Staff role cook (`_cook_step`),
  dealers carry `meth`. Scenarios meth_market/meth_lab/meth_cook/meth_dealer, self-test check meth.
- Cocaine (milestone 3): `CocaBed` (water at 50%), `LeafPress`, `Refinery` (vent at 60%) = ProcessStations; items
  coca_seedling/process_fluid/coca_leaves/coca_paste/cocaine/coke_bag; staff `_machine_step` (COOK_MACHINES,
  GROWER_MACHINES), dealers `DEALER_GOODS`. Scenarios coke_lab/coke_staff, self-test check cocaine.
- Courier/lawyer/bribes (milestone 3): Staff role courier (`_courier_step`, StaffConfig courier_*), `Legal` autoload
  (lawyer retainer + `on_player_arrested`, `host_bribe` -> Wanted.clear), CrewWindow tab "Services".
  Scenarios courier, bribe; self-test check services.
- Raids (milestone 3): `Raids` autoload (nightly roll from rank 2, `announce`/`start`, LIVE raid with World.add_rival
  when crew is near, else guards roll; `_lost` steals locker stock + a machine), Staff role guard (rank 4).
  Scenarios raid_live/raid_guards, self-test check raids.
- Bulk deals (milestone 3): `BulkDeals` autoload (GameState.world["bulk"], rank 4 offers every 20-30 h, `new_offer`,
  `host_sell`, `request_sell`, synced `offer`, `enabled` off in selftest), visual `BulkBuyerNPC`. Scenario bulk_deal,
  self-test check bulk. Dealers push turf (`StaffConfig.turf_per_dealer_bag`). Roadside: jerrycan to 15% (`Roadside.JERRYCAN`).
- Roadside team (milestone 3): `Roadside` (scripts/staff/roadside.gd, static: `host_tow`, `kerb_spot`, `tow_seconds`),
  CrewWindow tab "Services", request "tow". Scenario roadside, self-test check roadside.
- Traffic lights + overtaking (point 63): `Traffic.LIGHTS` (junction index -> arms, offset), `light_clock` (host
  re-sends, `_sync_lights`), `light_state(j, axis)`, `TrafficLight` (local pole visuals); `Car._junction_limit` stops at
  red/amber (blocked_by "light"); `Car._overtake` / `pass_car` / `lane_offset` / `overtakes`. CAR_COUNT 5. Check lights.
- Panic (point 32): panicking cars skip the junction limit and only crawl past people (`Car.PANIC_MIN_SPEED`);
  pedestrians `_flee_loop` until `flee_safe()` (40 m + out of sight, max 45 s). Scenario panic. Kerb check: `--only=kerb`.
- Car gunfire (points 23/24): `Car.hear_gunshot` -> `start_uturn` (Traffic.find_escape) or panic; no drivers get out;
  `abandon()` only for wrecks/tests; `honk` is rate-limited town-wide (`_last_honk_ms`). `Car.force_reaction` "panic"/"uturn".
- Players: `scenes/player/player.tscn` (`Player`), one per peer, spawned by the host via World/PlayerSpawner
  (spawn function `World._create_player`). The owner moves its body and syncs net_* state; the host checks the
  speed and corrects with `_teleport`. Crouch/look pitch on the model: `scripts/player/pose_modifier.gd`.
- Join order: a client sends `_client_world_ready` once its World is loaded; only then does the host make
  spawned nodes visible to it (`Net.limit_sync_to_world` on every synchronizer of a spawned node; players
  also have a host-owned `HostSync` for that).
