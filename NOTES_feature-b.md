# NOTES feature-b: ranks + XP (DESIGN "Progression")

Session B notes. To be folded into DESIGN.md (Roadmap status + Decisions) / CHANGELOG.md / CLAUDE.md by
session A when merging (B may not edit those files).

## MERGED parts 1 + 2 (A, main c95e70c), parts 3-7 + the anchor fix (A, merge of 0b00291), and the dealer-turf fix,
part 8 (bulk deals) + "Roadside + fuel" (A, merge of d2d7b72, 2026-11-14), parts 9-17 + 12 (A, merge 0f632ef,
2026-11-15): all already in DESIGN/CHANGELOG/CLAUDE.md. New parts go below a new "Open for the next merge" line.

## Open for the next merge: part 25 (Roadmap 88: NPC day rhythm), part 26 (Roadmap 89: npc_bench), part 27 (settings menu).

Part 24 MERGED (A, 2026-11-24): in DESIGN/CHANGELOG.

Part 23 MERGED (A, 2026-11-16): in DESIGN/CHANGELOG/CLAUDE.md.

Parts 18-22 MERGED (A, 2026-11-15): in DESIGN/CHANGELOG/CLAUDE.md. New parts go below a new "Open for the next
merge" line.

## Planned (in this order, from Curry 2026-11-14)
1. Part 9: product quality - done (below).
2. Part 11: shooting range (rank 2): practice on targets, try every gun, a small skill bonus (less spread).
3. Parts 13-17: taken over from A's list (user 2026-11-14; A doesn't do them; "E makes you crouch" is already fixed
   by A), after the range and BEFORE part 12:
   13. Engine sound for every car (idle, accelerating, revs) + tyres and brakes.
   14. Running people over from any angle (ragdoll, damage, a wanted star for murder).
   15. Jumping onto cars and standing on them (collision on the roof and bonnet).
   16. Dogs as real NPCs: flee when their owner dies, can be killed, play fetch with their owner.
   17. Birds (fly, sit on roofs), cats, pigeons, ducks by the water.
   Animals spawn from code or markers (no world.tscn / gen_world.py). A's car scripts touched -> listed in B.md.
4. Part 12 (last): staff assignment (Schedule I style):
   - E on any worker opens a menu: their locker, their stations, and the route between them.
   - A route per production chain, picked per station: meth = locker -> cooking station(s) -> cooling plate(s) ->
     packaging table; weed = locker -> pots -> drying rack -> packaging table; coke = locker -> coca bed(s) ->
     leaf press -> refinery -> packaging table. The worker takes supplies from their locker, carries them along the
     route and puts the end product back in that locker.
   - A max number of stations per worker (e.g. a cook: 2 cooking stations + 2 cooling plates), shown in the menu.
   - Staff locker: a special locker with a wage slot. Put money in; every game day each worker assigned to it takes
     their daily wage. Empty -> they stop working and text you.
   No map files.

## Status
Done: ranks 0-6 + crew XP, XP from sales / phone deals / fights, rank gates in shops + estate agent,
HUD rank panel, saved with the world, host authoritative + synced, F9 scenario `ranks`, self-test check `ranks`.

## How it works
- `Progression` (new autoload, `autoload/progression.gd`): crew XP in `GameState.world["progress"]["xp"]`
  (saved with the world). Host: `host_add(amount, reason, by)`, `host_sale(...)`, `host_kill(killer, victim)`,
  `debug_set_rank(r)`. Every peer: `xp`, `rank()`, `rank_name(r)`, `unlocks(r)`, `item_lock(id)`,
  `property_lock(id)` ("" = allowed). Signals `xp_changed`, `xp_gained` (earner only), `ranked_up`.
  Sync: host broadcasts on every change / world load; a client's HUD asks with `request_sync()`.
- `RankConfig` (`scripts/progression/rank_config.gd`, data `data/progression/ranks.tres`): names, XP thresholds,
  unlock texts, `item_rank` (id -> rank to buy), `property_rank`, XP values.
- HUD: `RankPanel` (`scripts/ui/rank_panel.gd`) bottom left above health: rank, XP bar, next unlock; "+XP" popup;
  "RANK UP!" banner with the unlocks. Shop/estate windows show "Rank N" instead of Buy for locked rows.
- Debug: F8 (host) = +100 XP. `--xp=N` = the host's crew starts with N XP (sync tests).
- Tests: `--scenario=ranks` (F9), `--selftest --only=ranks` (`scripts/debug/rank_test.gd`).

## Decisions (what + why)
- XP and rank belong to the CREW, not to each player. Why: DESIGN "Host owns ... rank", and properties,
  stations and storage are already crew-shared; one rank keeps co-op simple. The +XP popup goes to the earner.
- XP values: fair sale 10/bag + 15 per deal (every sale is an accepted phone deal since point 34; XP comes in via A's
  group hook `progression.on_sale`), short-changed sale half, customer runs 0;
  kill a Black Crow 40, an officer 10, a civilian 0. Why: selling is the main loop (~12 deals to rank 1),
  fights with the Crows are the "fights" of the design; cops give a little, civilians nothing (no reward for murder).
- Thresholds 0 / 300 / 1000 / 2500 / 5000 / 9000 / 15000 XP. All tunable in ranks.tres.
- Unlocks with the content that exists now (the rest of the DESIGN table is listed as "(Later: ...)"):
  0 weed + pistol + phone/webshop + Starter Room; 1 grow lamp, shotgun, Small House; 2 SMG, Bakery, Family House;
  3 AK-47, Barber + Laundromat; 4 sniper, South Warehouse; 5-6 only future content.
  The black market stays open from rank 0 (the weed stations are only sold there, a rank-3 gate would block weed).
  Ammo is never gated. Only BUYING is gated: what you already own (old saves) is never taken away.
- Old saves start at 0 XP (rank 0); nothing is confiscated.
- Gates are OFF in `--selftest` and in test scenarios (they hand out gear and set up purchases freely), except
  when `Progression.force_gates` is set (scenario `ranks`, the `ranks` self-test check). Reset on GameState.reset.

## Existing files changed (and why)
- project.godot: autoload `Progression`.
- scripts/npc/pedestrian.gd: NOT changed any more (A's hook `call_group(&"progression", "on_sale", ...)`;
  `Progression` is in group "progression").
- scenes/player/player_combat.gd `_host_fire` (killed branch): 1 line `Progression.host_kill(player, victim)`.
- scripts/npc/shopkeeper.gd `_server_buy`, scripts/npc/estate_agent.gd `_server_buy_property`: rank check.
- scenes/player/hud.gd: `add_child(RankPanel.new())` in `_ready`; locked rows in `open_shop` / `_fill_estate`
  + helper `_rank_lock`.
- scripts/debug/scenarios.gd: scenario `ranks`. scripts/debug/self_test.gd: `ranks` in CHECKS + `_check_ranks`.

## For CLAUDE.md (suggested lines)
- Ranks (milestone 3): `Progression` autoload (crew XP in GameState.world["progress"], host_add/host_sale/host_kill,
  item_lock/property_lock gates, off in selftest/scenarios unless `force_gates`), `RankConfig` in
  `data/progression/ranks.tres`, HUD `RankPanel`. F8 = +100 XP, `--xp=N`. Scenario ranks, self-test check ranks.


# Part 2: staff + dealers (DESIGN "Staff")

## Status
Done: grower (rank 1) + packager (rank 2) working in a crew-owned property, wages per in-game day, dealers
(rank 1; 1/1/2/2/4/5 dealers by rank) in a district with commission, stock, cash, loyalty, arrest + betrayal,
hiring/firing via the phone app "Crew" (Benny the fixer), dealer window (E on the dealer), saved + synced,
scenarios `staff_workers` + `dealers`, self-test check `staff`. Cook + courier are listed as "later".

## How it works
- `Staff` (new autoload, `autoload/staff.gd`): everything in `GameState.world["staff"]` = {members: uid -> record,
  candidates, clock, cand_clock, next}. Host `tick(hours)` from `_process` (DayNight hours, F7 speeds it up).
  Requests `Staff.request("hire"|"fire"|"give"|"collect", a, b)` -> host -> `answer(ok, text)` (host messages that
  fail start with "!"). Sync: `_set_members` RPC to every peer (throttled 0.5 s, plus on world load / request_sync).
  `debug_hire(who, role, place)` for tests/scenarios.
- Workers: use the stations IN their property (`Property.contains`): GrowPot (EMPTY -> soil from a locker ->
  seed from a locker -> water -> READY -> harvest onto DryingRacks, rest into a locker), packager (rack `dry` ->
  locker as weed_bud -> weed_bud + baggie from the locker -> weed_bag into the locker; needs a PackagingTable).
  Rates in `StaffConfig` (actions per in-game hour). Room: one worker per bed or storage locker placed in the
  property (`beds_in`). The first day's wage is paid at hiring; then every 24 in-game hours (text "Paid today's
  wages"); an unpaid worker quits.
- Dealers: `StaffConfig.districts` (id -> name, anchor, sales_per_hour, price), anchor snapped to the navmesh on the
  host. Each in-game hour they sell `sales_per_hour` bags from their stock; the cash minus their cut waits for you.
  +4 crew XP per bag. Loyalty drops while more than €600 waits uncollected, rises when you collect; below 25 they
  may run off with stock + cash. Small arrest chance per hour (stock + cash lost). Dealer texts when sold out.
- Visuals: `StaffViews` (node "StaffViews" in the World, local on every peer) with one `StaffNPC` per member
  (stationary Pedestrian model + layer-2 body + name label). Workers stand at the station they used last.
  E on a worker: toast with what they do; E on a dealer: `CrewWindow` dealer mode.
- UI: `CrewWindow` (`scripts/ui/crew_window.gd`, child of the HUD, built in code, frees the mouse, Esc/E/Tab close):
  tabs "Your crew" (Fire) and "Hire (Benny)" (candidate + property/district picker). Opened by the phone app "Crew".
- Tests: `--scenario=staff_workers`, `--scenario=dealers` (`--crew=crew|hire|dealer` + `--scenario-shot` opens the
  window for the screenshot), `--selftest --only=staff` (`scripts/debug/staff_test.gd`).

## Decisions (what + why)
- Hiring happens on the phone (app "Crew", contact Benny the fixer), not in a bar: there is no bar on the map yet and
  the map is session A's. When a bar exists, a Recruiter NPC there can open the same `CrewWindow` (mode "crew",
  tab "hire"). Why: the feature works now without touching the map.
- Workers act directly on the station state (no walking AI): they stand at the station they last used. Why: robust
  in co-op (host logic only, no new networked NPCs); walking workers can come later.
- Staff NPCs are local visuals built from the synced members list on every peer (no MultiplayerSpawner). Why: no
  changes to world.tscn needed; positions are host-computed and synced in the record.
- Supplies come from the storage lockers in the property (soil, seeds, baggies), output goes to the racks / lockers.
  Why: the locker system already exists, shared by the crew, and the player sees the result by opening it.
- Room for staff = beds + storage lockers in the property (DESIGN: "need a bed/locker"). The Starter Room has room for 2
  (bed + free locker).
- Wages are paid from the employer's money (dirty first, like other illegal costs) once per in-game day; the first day
  at hiring. Unpaid = quits. Dealers have no wage, only their cut (15-30%).
- Max dealers by rank 0..6: 0, 1, 1, 2, 2, 4, 5 (DESIGN: rank 1 "1 dealer", rank 5 "more dealers").
- Districts are game data (StaffConfig), 4 for the test town: Old Town, Main Road East, North Road, South Street.
- Firing a dealer gives back their stock and the cash (what fits in your pockets).
- Cook (rank 2) and courier (rank 3) are in the list as "Not in the game yet" (meth / supply runs don't exist).

## Existing files changed (part 2)
- project.godot: autoload `Staff`.
- scenes/player/phone.gd: home button "Crew (staff + dealers)" + match branch "crew" (closes the phone, opens CrewWindow).
- scripts/debug/scenarios.gd: scenarios staff_workers + dealers (end of LIST / match) + `--crew=` screenshot flag.
- scripts/debug/self_test.gd: "staff" at the end of CHECKS + `_check_staff`.

## For CLAUDE.md (suggested lines)
- Staff (milestone 3): `Staff` autoload (GameState.world["staff"], host tick in in-game hours, `request(...)` ->
  `answer`, `debug_hire`), `StaffConfig` in `data/staff/staff.tres` (roles, rates, districts), visuals
  `StaffViews`/`StaffNPC` (local), UI `CrewWindow` (phone app "Crew", E on a dealer). Scenarios staff_workers,
  dealers; self-test check staff.


# Part 3: meth (DESIGN "Products": buy raw materials -> cook in steps -> cool -> break)

## Status
Done (commit 399e1bf; check `meth` PASS, scenarios OK). Customers buying meth on the street needs a hook from A (B.md).

## How it works
- Items (hand-made .tres, illegal): `lab_chemicals` (€110), `activator` (€70) = supplies (black market only),
  `meth_tray` "Hot Tray", `meth_shard` "Meth Shards", `meth_bag` "Bag of Meth" (€130). Models: `ProcItem` kinds
  chem_jug / activator / meth_tray / meth_shard / meth_bag (`prefabs/items/<id>.tscn`).
- Stations (gen_items.py STATIONS, prefabs/stations/): `ProcessStation` (new generic base, scripts/stations/
  process_station.gd: inputs -> hours -> output, stages IDLE/RUNNING/DONE, `staff_load/staff_take/staff_attend`;
  cocaine reuses it). `CookStation` (`cook_station`, €900): 2 Lab Chemicals + 1 Activator -> 3 in-game hours; at 40%
  it needs a STIR (E, Label3D "STIR!"): stirred = 2 Hot Trays, never stirred = 1. `CoolingPlate` (`cooling_plate`,
  €400): 1 Hot Tray -> 1.5 h -> 6 Meth Shards. `PackagingTable.PACKS`: Meth Shards + Baggie -> Bag of Meth (and weed).
- Black market: `Products` autoload (new, autoload/products.gd) appends `BLACK_MARKET_EXTRA` to Rook's stock at
  runtime (node_added on a night_only Shopkeeper) - the garage prefab is untouched. Rank 2 gates (ranks item_rank).
- Cook (staff, rank 2, €150/day): `Staff._cook_step` - break cooled trays into shards (locker), stir, pour hot trays
  onto free cooling plates, start a cook from locker supplies. `cook_actions_per_hour` 3. Packager also bags shards.
- Dealers sell meth: record `stock` = all bags, `meth` = how many of those are meth; meth sells first at
  `Products.price("meth_bag", district price)` (x2.2). Give hands over weed + meth; firing returns both.
- Customers: A's `World.make_customer` asks `Products.pick_customer_product()` (meth 35% from rank 2, cocaine 20% from
  rank 4) + `Products.price(product, weed_price)`; `Pedestrian.product` (A, main 49ba411) drives texts + the sale.
- Since part 4 the stir is the generic `ProcessStation` "attend" moment (`attend_at`, `missed_count`, state key
  "attend"), and the cook runs every machine generically (`Staff._machine_step`: take output into the locker, attend,
  start from the locker) - hot trays go via the locker to the cooling plate.

## Decisions (what + why)
- Abstract steps only (load, stir, pour, break) - DESIGN "abstract game mechanics, no realistic procedures".
  The stir is the "cook in steps" skill moment: miss it = half the batch. Easy for co-op, readable for the player.
- One generic `ProcessStation` for all timed machines (cooling plate now; coca processing + refinery next). Why: one
  tested code path for player use, staff, save and sync.
- Supplies are added to Rook's stock at runtime instead of editing garage.tscn / gen_prefabs.py. Why: the map and
  building prefabs are session A's; A can move the ids into gen_prefabs `shopkeeper(...)` stock at merge time.
- Economy: one cook = €290 supplies (black market -10% = ~€260) -> 12 bags x ~€130 (dealer: x2.2 the district weed
  price). About 4x the money per hour of a weed pot, but €1,300 of stations and rank 2 first.
- Meth goes through the existing packaging table (no new table), dealers carry both products in one stock.

## Existing files changed (part 3)
- project.godot: autoload `Products`.
- tools/generators/gen_items.py: 2 STATIONS entries (cook_station, cooling_plate) -> data/items/*.tres.
- scripts/stations/packaging_table.gd: PACKS (weed + meth), messages "Packaged 3 Bags of Meth".
- scripts/procgen/proc_item.gd: 5 new kinds. scripts/progression/rank_config.gd: rank 2 items + unlock text.
- autoload/staff.gd, scripts/staff/staff_config.gd, scripts/staff/staff_npc.gd, scripts/ui/crew_window.gd: cook +
  meth for dealers. scripts/debug/staff_test.gd: "not in the game yet" now tests the courier.
- scripts/debug/self_test.gd: "meth" at the end of CHECKS + `_check_meth`. scenarios.gd: meth_market, meth_lab,
  meth_cook, meth_dealer (+ helper `Scenarios.meth_lab`).

## Te testen door Curry
- `meth_market` (F9): nacht bij Rook, rang 2: Lab Chemicals, Activator, Cooking Station, Cooling Plate in de lijst.
- `meth_lab`: kook zelf: E op het kookstation, F7, STIR! (E), trays pakken, koelplaat, shards, verpakken.
- `meth_cook`: een kok + packager doen het met F7 vanzelf (spullen in de locker).
- `meth_dealer`: dealer krijgt wiet + meth, verkoopt meth eerst voor ~2x de prijs.

## For CLAUDE.md (suggested lines)
- Meth (milestone 3): `ProcessStation` (generic timed machine, staff_load/take/attend), `CookStation` (stir at 40%),
  `CoolingPlate`; items lab_chemicals/activator/meth_tray/meth_shard/meth_bag; `PackagingTable.PACKS`; `Products`
  autoload (BAGS + prices, Rook's extra stock at runtime, `pick_customer_product`); Staff role cook (`_cook_step`),
  dealers carry `meth`. Scenarios meth_market/meth_lab/meth_cook/meth_dealer, self-test check meth.


# Part 4: cocaine (DESIGN "Products": grow coca plants -> process leaves -> refine; rank 4)

## Status
Done: self-test check `cocaine` PASS, scenarios coke_lab / coke_staff OK.

## How it works
- Items (illegal): `coca_seedling` (€40) + `process_fluid` (€60) = black-market supplies; `coca_leaves`, `coca_paste`,
  `cocaine`, `coke_bag` "Bag of Cocaine" (€220; dealers x3.6 the district weed price). ProcItem kinds for each.
- Stations (ProcessStation, gen_items STATIONS, black market, rank 4): `CocaBed` (`coca_bed`, €300): 2 seedlings + 1
  soil -> 10 h, WATER! at 50% (E) -> 12 leaves (dry: 6). `LeafPress` (`leaf_press`, €1,500): 12 leaves + 1 Process
  Fluid -> 2 h -> 1 Coca Paste. `Refinery` (`refinery`, €2,500): 1 paste -> 3 h, VENT! at 60% -> 8 Cocaine (5).
  `PackagingTable.PACKS`: Cocaine + Baggie -> Bag of Cocaine.
- Staff: the grower also tends coca beds (`GROWER_MACHINES`, after the weed pots), the cook runs press + refinery
  (`COOK_MACHINES`). Hand-over through the storage locker.
- Dealers: `Staff.DEALER_GOODS` [[coke_bag, "coke"], [meth_bag, "meth"]] = record keys counting the dearer bags in
  `stock` (sold first, most expensive first); `dealer_weed(rec)`; fire/give handle every kind.

## Decisions (what + why)
- Same pattern as meth (one generic machine class + one attend moment per chain: water the bed, vent the refinery).
  Why: readable, abstract (DESIGN), every machine works for players and staff alike.
- No grow lamp/pot reuse for coca: a bigger "grow bed" (DESIGN table) that takes seedlings + soil, so growers can
  run it from the locker without the weed pot's multi-step state machine.
- Economy: one chain = ~€150 supplies -> 8 bags x ~€200 over ~15 in-game hours, but €4,300 of machines and rank 4.
- Watering a coca bed needs no watering can (E is enough): keeps the hand-off simple; the weed pot keeps its can.

## Existing files changed (part 4)
- gen_items.py: 3 STATIONS entries. packaging_table.gd: PACKS + texts. proc_item.gd: 6 kinds. rank_config.gd: rank 4
  items + unlock text. products.gd: coke_bag + black-market extras. staff.gd: `_machine_step`, DEALER_GOODS.
- self_test.gd: "cocaine" at the end of CHECKS + `_check_cocaine` (scripts/debug/coke_test.gd). scenarios.gd:
  coke_lab, coke_staff, helpers `coke_lab` / `_lab`.

## Te testen door Curry
- `coke_lab` (F9): plant, F7, WATER! (E), oogsten, leaf press, refinery met VENT! (E), verpakken.
- `coke_staff`: grower + kok draaien de cocaine-keten met F7 vanzelf; cocaine komt in de locker.

## For CLAUDE.md (suggested lines)
- Cocaine (milestone 3): `CocaBed` (water at 50%), `LeafPress`, `Refinery` (vent at 60%) = ProcessStations; items
  coca_seedling/process_fluid/coca_leaves/coca_paste/cocaine/coke_bag; staff `_machine_step` (COOK_MACHINES,
  GROWER_MACHINES), dealers `DEALER_GOODS`. Scenarios coke_lab/coke_staff, self-test check cocaine.


# Part 5: courier, lawyer, bribes (DESIGN Staff "Courier" rank 3, Progression rank 4 lawyer, rank 5 bribe)

## Status
Done: self-test check `services` PASS; scenarios courier / bribe OK. The lawyer's effect after an arrest needs a
1-line hook from A in `Player.host_arrest` (see B.md); `Legal.on_player_arrested` is ready and tested.

## How it works
- Courier = a Staff worker (rank 3, €120/day, needs a bed/locker in a property like other workers).
  `Staff._courier_step` (`courier_trips_per_hour` 1): first a dealer of the same employer below
  `courier_restock_below` (50%) of capacity gets bags from the property's lockers (dearest first) and the dealer's
  cash goes to the employer (+loyalty, phone text); else it buys ONE missing supply (`courier_stock` targets, only for
  stations in the property via `courier_uses`, only items the rank allows) at base price x 1.1 into the locker.
  Station kind = `scene_file_path` basename (`_station_item`).
- `Legal` autoload (autoload/legal.gd), state GameState.world["legal"] {lawyer, clock, time}, synced `Legal.lawyer`.
  Lawyer (rank 4, Mr. Hale, €400/day, unpaid = quits): `on_player_arrested(p, fine, taken)` gives 60% of the fine
  back as clean money + half (rounded up) of every confiscated stack. Bribe (rank 5, Dekker): €1,500 per star ->
  `Wanted.clear(p, "bribe")`, cooldown 6 in-game hours per player.
- UI: CrewWindow tab "Lawyer + cop" (requests via `Staff.request("lawyer_hire"|"lawyer_fire"|"bribe")`).

## Decisions (what + why)
- The courier works from a property (its locker = the warehouse) and also collects the dealers' cash. Why: DESIGN
  "fetches supplies, delivers to dealers"; collecting makes the dealer network run without driving around, and it
  keeps the dealers loyal (same rule as collecting yourself).
- The courier only buys supplies for stations that stand in its property, and only up to small targets: no runaway
  spending. Paid at +10% (his cut). Illegal supplies are paid with dirty cash first (like the black market).
- Lawyer and bribes are phone/crew-window services (no NPC office yet; the lawyer's building is on A's map later).
  Fine back as CLEAN money (a court refund). No jail time exists, so "shorter sentence" = goods + fine back.
- Bribe price per star (€1,500) makes 5 stars €7,500: a Kingpin expense, not a free reset; the cooldown stops spamming.

## Existing files changed (part 5)
- project.godot: autoload `Legal`. staff.gd: `_courier_step`, `courier_test_trip`, request actions, Legal.sync in
  `_broadcast`. staff_config.gd: courier on (no "later") + courier settings. crew_window.gd: tab "Lawyer + cop".
- rank_config.gd: unlock texts (couriers, lawyer, bribes). staff_test.gd: courier rank check instead of "later".
- self_test.gd: "services" at the end of CHECKS (scripts/debug/services_test.gd). scenarios.gd: courier, bribe.

## Te testen door Curry
- `courier` (F9): houd F7 ingedrukt: de koerier brengt zakjes naar je dealer, haalt het geld op (sms) en koopt spullen.
- `bribe`: Tab > Crew > Lawyer + cop: koop Dekker om (3 sterren weg), huur Mr. Hale in.

## For CLAUDE.md (suggested lines)
- Courier/lawyer/bribes (milestone 3): Staff role courier (`_courier_step`, StaffConfig courier_*), `Legal` autoload
  (lawyer retainer + `on_player_arrested`, `host_bribe` -> Wanted.clear), CrewWindow tab "Lawyer + cop".
  Scenarios courier, bribe; self-test check services.


# Part 6: Crow raids on labs + guards (DESIGN "Lab raids: rivals steal stock/machines unless guards or players defend")

## Status
Code + self-test check `raids` + scenarios raid_live / raid_guards.

## How it works
- `Raids` autoload (autoload/raids.gd, host), state GameState.world["raids"] {rolled, pending {prop, at}, wins, losses,
  time}. Once per night (DayNight.is_night) with crew rank >= 2: 30% chance the Crows pick a crew-owned "lab" (property
  with production stations), text "Black Crows" warning, the raid WARN_HOURS (2 in-game hours) later.
- `start(prop)`: raiders = clamp(2 + rank/2, 2, 5); every guard there takes one down first (all down = won).
  A crew player within 35 m: LIVE raid: `World.add_rival(front spot)` with role STREET, `remember(player)`; they wait at
  the front (walk back if they stray); kill them all within 150 s = won, else lost (they go back to the yard).
  Nobody there: won with 35% per guard, else lost.
- Lost: 50% of every drug/bag/supply stack in the property's lockers (`LOOT_IDS`) is gone; without guards also one
  placed ProcessStation (`host_remove_placed`); each guard there dies with 40%. Won: +80 crew XP. Texts to the crew.
- Guard = Staff role (rank 4, €200/day, a bed/locker in the property like other workers), status "on guard".

## Decisions (what + why)
- Raiders never walk INTO the property (A's rule: inside your own property you are safe, Crows don't come in). The
  "break-in" is the timer: Crows still standing at the door when it runs out = they got in. Why: no changes to the
  Crow AI (A's files) and the fight happens outside where the AI works.
- Live raids only when a crew player is close: a real fight when you can take it, a dice roll for guards when you're
  away (DESIGN: "unless guards or players defend").
- Machines: only one ProcessStation (meth/cocaine machine) is taken and only when there are no guards: losing a
  €2,500 refinery is a big hit; guards are the insurance. Weed pots are not taken (small, starter content).
- Raids start at rank 2 (DESIGN act 2 "First blood (rank 2): the Crows raid your barn"); guards come at rank 4 (DESIGN
  rank table "guards"); before rank 4 you defend yourself.

## Existing files changed (part 6)
- project.godot: autoload `Raids`. staff_config.gd: role guard. staff.gd: guard status, candidates.
- self_test.gd: "raids" at the end of CHECKS (scripts/debug/raid_test.gd). scenarios.gd: raid_live, raid_guards.
- Uses A's `World.add_rival`, `Rival.role/home/remember/memory`, `Pedestrian._go` (read-only use, no edits).

## Te testen door Curry
- `raid_live` (F9): nacht, AK in je handen, de Crows komen naar je Starter Room: schiet ze neer binnen 2,5 minuut.
- `raid_guards`: jij bent ver weg, 2 bewakers verdedigen het lab (F7); lees de sms'jes.

## For CLAUDE.md (suggested lines)
- Raids (milestone 3): `Raids` autoload (nightly roll from rank 2, `announce`/`start`, LIVE raid with World.add_rival
  when crew is near, else guards roll; `_lost` steals locker stock + a machine), Staff role guard (rank 4).
  Scenarios raid_live/raid_guards, self-test check raids.


# Part 7: roadside team (DESIGN rank 5 "roadside service team"; Buildings "tow truck team drives to the player")

## Status
Code + self-test check `roadside` + scenario `roadside`.

## How it works
- `Roadside` (scripts/staff/roadside.gd, static helper, host): CrewWindow tab "Services" (was "Lawyer + cop") lists
  the crew's cars with "Bring it here (€350)" -> `Staff.request("tow", uid)` -> `Roadside.host_tow(p, uid)`:
  rank 5, not in a car, car empty and > 20 m away, a road within 45 m (`kerb_spot`), fee (clean first, legal).
  Text, then `tow_seconds` (30 s) later `_deliver`: the car is set on the pavement beside the nearest traffic lane
  (`KERB_OFFSET` 2.9 m right of the lane, outside junction squares, box query free of world/props/players), facing
  along the traffic, save record updated, text with the distance. Impossible at that moment = fee refunded.
- Uses A's `Vehicles.current.cars()`, `PlayerCar.seats/_save_record/net_*`, `Traffic.nearest/routes`,
  `TrafficRoute.sample`, `CarCatalog.MODELS` (read-only, no edits to A's files).

## Decisions (what + why)
- No tow truck driving through town: the car simply appears after 30 s. Why: a driving tow truck needs Traffic/Car
  changes (A's files); the service effect (your car where you are) is what the design asks. A can add a visual
  truck later via the same `_deliver` moment.
- The car is dropped on the pavement, not in the lane: AI traffic would stop behind a car parked in its lane.
- Fee €350, clean money first (a legal service, like the lawyer).
- Fuel + the gas station (rest of Roadmap 48) are A's: they need PlayerCar (fuel use) and the map (station). Asked in B.md.

## Existing files changed (part 7)
- staff.gd: request "tow". crew_window.gd: tab "Services" + `_fill_roadside`. rank_config.gd: unlock texts rank 4
  (guards) and rank 5 (roadside team) without "(Later)". self_test.gd: "roadside" at the end of CHECKS
  (scripts/debug/roadside_test.gd). scenarios.gd: roadside; bribe hint says "Services".

## Te testen door Curry
- `roadside` (F9): Tab > Crew > Services > "Bring it here": na ~30 s staat je Comet Sedan op de stoep bij de weg.

## For CLAUDE.md (suggested lines)
- Roadside team (milestone 3): `Roadside` (scripts/staff/roadside.gd, static: `host_tow`, `kerb_spot`, `tow_seconds`),
  CrewWindow tab "Services", request "tow". Scenario roadside, self-test check roadside.


# Fix (A's request 2026-11-14)
- StaffConfig district "south" anchor Vector3(-34, 0, 49.4) -> (-34, 0, 55.4): the old spot was inside the building
  row (now A's cover garage, the dealer snapped onto the workshop floor); the new one is on South Street's pavement.
- Dealers count for A's territory (point 51): every bag a dealer sells adds `StaffConfig.turf_per_dealer_bag` (2.0)
  influence to their district via `Territory.current.host_add(district, n, "dealer")` (staff.gd `_dealer_tick`).
  Why: a player's fair street sale is worth 4; a dealer half of that, because nobody risks a fight for it. Staff
  self-test checks the meter.


# Part 8: bulk deals (DESIGN rank 4 "bulk deals"; Products "selling ... bulk")

## Status
Done: self-test check `bulk` PASS, scenario `bulk_deal` OK.

## How it works
- `BulkDeals` autoload (autoload/bulk_deals.gd, host), state GameState.world["bulk"] {offer, next, time, done, missed}.
  From rank 4, every 20-30 in-game hours "The Dutchman (bulk)" texts the crew: 20/25/30/40 bags of a product the rank
  allows (Products.BAGS) for one total price (street price x `BULK_DISCOUNT` 0.8, the district's weed price), waiting
  `WAIT_HOURS` 6 on the pavement 7 m from a district's dealer anchor (`_meet_spot`, navmesh snap).
- Every peer: the synced `offer` -> `BulkBuyerNPC` (scripts/staff/bulk_buyer_npc.gd, local visual like StaffNPC, yellow
  label). E -> `BulkDeals.request_sell()` -> host `host_sell(p)`: within 4 m, all the bags in the pockets, paid as
  dirty cash, +6 XP per bag, offer gone. Missed = "Waited for nothing" text. Late join: `Staff._broadcast` /
  `_request_sync` call `BulkDeals.sync()`.
- `BulkDeals.enabled` (random offers) is off in --selftest; the bulk check turns it on.

## Decisions (what + why)
- One buyer, one offer at a time, met on foot in a district (no harbor yet - the harbor is A's map; when it exists
  the meet spot can move there). Why: the design's "bulk at the harbor" needs that map; the deal itself works now.
- 20% below street price but all at once and no rip-off: the trade-off is the volume and the risk of carrying
  20-40 bags through town (police confiscate, Crows rob loot bags), not the price.
- XP 6 per bag (a fair street sale gives 10 + 15 per deal): less per bag, much more per minute.
- Dirty cash, like every drug sale.

## Existing files changed (part 8)
- project.godot: autoload `BulkDeals`. staff.gd: `BulkDeals.sync()` in `_broadcast` / `_request_sync`.
  rank_config.gd: rank 4 text "bulk deals" without "(Later)". self_test.gd: "bulk" at the end of CHECKS
  (scripts/debug/bulk_test.gd). scenarios.gd: bulk_deal.

## Te testen door Curry
- `bulk_deal` (F9): 30 zakjes meth op zak, de Dutchman staat naast je (gele naam): E = alles in één keer verkocht.

## For CLAUDE.md (suggested lines)
- Bulk deals (milestone 3): `BulkDeals` autoload (GameState.world["bulk"], rank 4 offers every 20-30 h, `new_offer`,
  `host_sell`, `request_sell`, synced `offer`, `enabled` off in selftest), visual `BulkBuyerNPC`. Scenario bulk_deal,
  self-test check bulk.


# Roadside + fuel (after A's point 48)
- An (almost) empty crew car (`PlayerCar.fuel` < `Roadside.JERRYCAN` 0.15) can be called even when it stands close
  by; the team brings a jerrycan: fuel up to 15% (~450 m, enough for the gas station), text says so. CrewWindow shows
  each car's fuel %. Why: A's "Out of fuel" text points to the tow team; without fuel the car can't move at all.
  Roadside self-test checks it.


# Part 9: product quality (DESIGN Products "quality (better seeds/machines -> better customers)"; user 2026-11-14:
# "better seeds, machines and mixes give higher quality, better customers and higher prices; weed, meth and coke")

## Status
Done: self-test check `quality` PASS (+ growing/meth/staff/raids/bulk still PASS), scenario `quality`.

## How it works
- 3 tiers: Standard (the existing item), Good (`<id>_q2`), Premium (`<id>_q3`) = separate items for fresh_weed,
  weed_bud, weed_bag, meth_tray, meth_shard, meth_bag, cocaine, coke_bag (tools/generators/gen_quality_items.py:
  same model via model_scene, price x1.4 / x1.9, icon = base icon + 1/2 gold stars). Helper `Quality`
  (scripts/products/quality.gd): base/tier/with_tier/variants/best_with/word, `host_made` -> GameState.world["quality"].
- Where quality is made:
  - Weed: GrowPot: Premium Weed Seed (`premium_seed`, black market, rank 1, planted before normal seeds) +1, at least
    half of the growth under a grow lamp (`state.lit`) +1. DryingRack holds one quality at a time (`state.tier`).
  - Meth: CookStation (`ProcessStation.quality_step`): Pure Reagent (`pure_reagent`, rank 2, the `mix_id`, used up
    when it is in your pockets / the cook's locker) +1, a Fume Hood (`fume_hood` station, rank 3, `FumeHood.RANGE`
    2.5 m) +1. CoolingPlate passes the tray's quality on (tiered inputs: best quality first).
  - Cocaine: Refinery = quality step (Pure Solvent `pure_solvent`, rank 4, + Fume Hood).
  - PackagingTable.PACKS = every quality (`static var`), same quality in -> out.
- Selling: `Products.price` x the tier factor (A's customer price + dealers + bulk). `Products.pick_customer_product`
  -> `pick_quality`: once the crew made Good/Premium of a product, 50% of its customers ask for the best quality,
  the rest for a lower one (so standard bags still sell). Customers want that exact item (A's _server_sell unchanged).
- Dealers: `Staff.dealer_goods()` (was the const DEALER_GOODS) = every bag but standard weed, dearest first (old keys
  "meth"/"coke" for the standard bags, item id for the others). Raids steal every quality. Staff grower plants
  premium seeds first, hangs by quality; packager takes each rack's quality.

## Decisions (what + why)
- Quality as separate item ids, not a field on stacks: inventory, lockers, loot bags, dealers, police confiscation
  and A's sale code are all id based, so nothing else had to change (and mixed stacks can't happen).
- 3 tiers, +1 per source, max Premium: one "better ingredient" + one "better machine" per product, so every product
  has the same two choices (seed/lamp, reagent/hood, solvent/hood). Mixes = the reagent/solvent (consumed per run).
- Quality lives in the chain items up to the bag (fresh weed, buds, trays, shards, cocaine), not in coca leaves or
  paste: the refinery is the cocaine quality step, so the earlier steps don't need tiers.
- A rack holds one quality: drying mixed batches would need an average and lose the premium.
- Price x1.4 (Good) / x1.9 (Premium): Premium weed (€114) is still below standard meth (€132), Premium meth is above
  standard cocaine; supplies cost €45/€160/€220 per run, the hood €1,800 once.
- Customers ask for what the crew has made (world["quality"]); 50% the best, so a crew with only Premium still
  gets half its customers, and Standard keeps selling.
- The growing self-test check (A's) counts every quality now (`_count_q`): its pot stands under the lamp = Good weed.

## Existing files changed (part 9)
- process_station.gd (`_plan`, `_quality_for`, `out_id`, `hood_near`, tier in state), cook_station.gd + refinery.gd
  (quality_step + mix_id), grow_pot.gd (`plant`, `harvest_tier/harvest_id`, lit), drying_rack.gd (tier, `can_hang`,
  `hang`, `bud_id`), packaging_table.gd (PACKS), products.gd (price/short_name/bag_ids/pick_quality + black market
  stock), staff.gd (`dealer_goods()`, grower/packager), bulk_deals.gd (quality pick), raids.gd (loot), rank_config.gd
  (gates + texts), gen_items.py (fume_hood). New: quality.gd, fume_hood.gd + prefab, gen_quality_items.py, 19 items
  + icons, quality_test.gd. self_test.gd: "quality" at the end + `_count_q` in A's growing check. meth_test.gd:
  compares product bases. scenarios.gd: quality.

## Te testen door Curry
- `quality` (F9): plant de Premium Weed Seed onder de lamp (prompt toont Good/Premium), kook meth naast de Fume Hood
  met Pure Reagent = Premium (gouden sterren), en verkoop 2 Bags of Premium Meth aan de klant buiten.

## For CLAUDE.md (suggested lines)
- Product quality (milestone 3): `Quality` (scripts/products/quality.gd, tiers 1-3 = item ids `<id>_q2/_q3`,
  gen_quality_items.py), sources: GrowPot premium_seed + lamp, ProcessStation `quality_step` (`mix_id` pure_reagent /
  pure_solvent, `FumeHood`), `Products.pick_quality`, `Staff.dealer_goods()`. Scenario quality, self-test check quality.


# Part 10: A's requests after 47a/47b (districts + property ranks)
- StaffConfig.districts: "docks" (The Docks, anchor (-110.4, 0, 40) on Industrial Road's kerb, 0.8 sales/h, €75) and
  "countryside" (Countryside, anchor (-146, 0, -60) on Country Lane's pavement, 0.5 sales/h, €80). Why: quiet areas
  (A keeps few pedestrians in the west) sell slower but pay more; Territory picks them up by itself.
- RankConfig.property_rank: barn 2, lab_warehouse 3, harbor_storage 4 (as A asked, = DESIGN Progression table);
  rank texts name them.


# Part 11: the shooting range (DESIGN Progression rank 2 "shooting range"; user 2026-11-14: "practice, try weapons,
# maybe a small skill bonus")

## Status
Done: self-test check `range`, scenario `shooting_range`.

## How it works
- `ShootingRange` (scripts/range/shooting_range.gd): "Hollow Creek Gun Club", built in code on every peer (local, like
  StaffViews) by the `RangeClub` autoload at the marker `ShootingRangeSpot` if the map has one, else at
  (-100, 0, -124) facing west (the free strip north of Hollow Farm, between the tree row z -112 and the NW wall).
  3 lanes, `RangeTarget` pop-up targets at 10/20/32 m (layer 2, `host_damage`/`is_head_hit` like a person; bullseye
  9 cm), an earth berm, a covered firing line with a scoreboard per lane, the club hut with Walt (`RangeDesk`).
- `RangeClub` (autoload/range_club.gd, HOST AUTHORITATIVE): E on Walt -> `RangeWindow` (scripts/ui/range_window.gd)
  -> `request("drill"|"try"|"return", arg)` -> `host_request`. Rank 2 gate (Progression.gates_on()).
  - Drill (€40, clean money first = a legal club): 45 s on a free lane, one target up at a time (1.7 s + 0.04 s/m),
    hit 1 point, bullseye 2. Leaving the range or dying ends it. Result -> skill + best score + XP (score/2, max 10).
  - Try a gun (€25): any LOADOUT gun (also above your rank) + 2 magazines; goes back (gun, its loaded rounds, unused
    lent rounds) when you walk 45 m from the range, after 10 minutes or with "Hand it back". One at a time; not a gun
    you already carry. player_data["range_loan"].
  - Skill 0..1 per player name in GameState.world["range"]["skill"] (+ "best"), synced to every peer: gain per drill =
    min(0.06, points x 0.004) x (1 - skill/2). `RangeClub.spread_factor(name)` = 1 - 0.2 x skill.
- PlayerCombat (2 lines): `_spread` multiplies by `RangeClub.spread_factor`; `_host_fire` skips the hear_gunshot /
  report_crime / cars calls when `RangeClub.covers(origin)` (legal gunfire). Hits/kills of people still count.
- Free practice: lanes without a drill keep all targets up; hits give the normal hit marker.
- Staff._broadcast also calls `RangeClub.sync()` (late join); clients ask for targets + skill when their range spawns.

## Decisions (what + why)
- Built in code at a fallback spot instead of in the map: the map is A's (world.tscn / gen_world.py). A can add a
  Marker3D `ShootingRangeSpot` (position + yaw = shooters face its -Z) wherever it fits; the range moves there.
- Skill bonus = only less spread, max 20%: small, visible with every gun, and no change to damage balance. Diminishing
  gain so ~25-30 good drills get you most of it; it costs money (fee) and time, never free XP grinding (max 10 XP).
- Loaner guns ignore the rank gate on purpose ("test weapons" before you can buy them), but they never leave the
  range. A loaner that dies with you stays in your loot bag (rare at the range; not worth a special case).
- The range is legal: no police, panic or traffic reaction to shots there; it is far west so nobody else is near.

## Existing files changed (part 10 + 11)
- player_combat.gd (2 hooks, see above), staff.gd (`RangeClub.sync()` in `_broadcast`), staff_config.gd (2
  districts), rank_config.gd (property ranks + texts), project.godot (autoload RangeClub after BulkDeals). New:
  range_club.gd, shooting_range.gd, range_target.gd, range_desk.gd, range_window.gd, range_test.gd. self_test.gd:
  "range" at the end of CHECKS. scenarios.gd: shooting_range (before bulk_deal).

## Te testen door Curry
- `shooting_range` (F9): je staat bij Walt (rang 2). E = venster: start een drill (€40) en schiet de opduikende
  doelen op je baan; probeer een geweer (€25, bv. de sniper) en loop weg: Walt heeft hem terug. Geen politie.

## For CLAUDE.md (suggested lines)
- Shooting range (milestone 3): `RangeClub` autoload (GameState.world["range"] skill/best, drills, loaner guns
  `player_data.range_loan`, `covers(pos)` = legal gunfire, `spread_factor(name)` in PlayerCombat._spread), local build
  `ShootingRange` (marker `ShootingRangeSpot` or FALLBACK_POS) + `RangeTarget` + `RangeDesk` (Walt) + `RangeWindow`.
  Scenario shooting_range, self-test check range.


# Parts 13-15: Roadmap 66 (engine sound), 64 (running people over from any side), 65 (standing on cars)
# (taken over from A, user 2026-11-14)

## Status
Done: self-test checks `engine_sound`, `run_over`, `car_roof`; scenarios `car_sounds`, `run_over`, `car_roof`.

## How it works
- 66: `Ambience` (new autoload, autoload/ambience.gd, LOCAL on every peer) gives every Car (group "cars") and
  PlayerCar (group "player_cars") a `VehicleSound` child (scripts/vehicles/vehicle_sound.gd) - no change in the car
  scripts for sound. VehicleSound reads only the vehicle's movement (same on host and clients): speed -> simulated
  6-gear box (`rpm_for`, rpm drops at each shift) -> pitch of two seamless engine loops (engine_on under load,
  engine_off coasting/idle; crossfaded by acceleration); tyre screech loop on hard cornering (sideways accel > 7 m/s²)
  or hard braking (> 8 m/s²); a brake squeal now and then (30%) when a car stops. Engine off: wrecks, abandoned
  standing traffic cars, a PlayerCar without driver or fuel. Garbage truck lower + louder, own cars louder than
  traffic. Only within 70 m of the camera. Sounds: tools/generators/gen_engine_sounds.py (numpy + ffmpeg) ->
  assets/audio/vehicles/engine_on/engine_off/tyre_screech/brake_squeal.ogg.
- 64: `PlayerCar._host_hits` checks the whole car + 35 cm all round (was a box at the nose) and per person the
  `impact_speed`: the velocity of the car's point nearest to them, towards them (linear speed + the yaw rate's swing).
  So: front, reversing, the swinging rear in a slide - all hit; someone standing beside a car that drives past isn't.
  Same damage table as A's (HIT_SPEED 3, KILL_SPEED 10), kill = police report + Wanted kill + XP as before, plus
  the `kill_hooks` group call (territory) like a shot. Victims ragdoll away from the car (Pedestrian._die).
- 65: `CarShapes.add(body, kind, bottom)` (scripts/vehicles/car_shapes.gd) replaces the single collision box of Car
  and PlayerCar by a body box (bonnet/boot height, full length) + a cabin box (roof height between cab_f and cab_b
  of ProcCar.SPECS). A jump (1.18 m) reaches the bonnet (0.82 m sedan) and from there the roof (1.42 m). The outline
  equals the old box, so traffic sensing / kerbs / hits / ProcCar.collision_size users are unchanged.

## Decisions (what + why)
- Engine sound from the movement, not from the car scripts' throttle: one component for traffic, own cars, the host
  and clients, and A's car code stays as it is. Two loops with pitch instead of a generator per car: cheap with 10+
  cars; the gearbox model gives the "revs up, shifts, revs up" sound everyone expects.
- Hits by impact speed towards the person instead of a bigger box at the nose: "from any angle" without making
  people die from simply standing next to a passing car.
- Two boxes rather than a convex hull: cheap, exact enough to stand on, keeps the old outline.
- Traffic cars still never run people over on purpose (A's traffic stops for people).

## Existing files changed (parts 13-15)
- scripts/vehicles/player_car.gd: `_host_hits` rewritten (+ `impact_speed`, `_hit_yaw*` vars, kill_hooks call),
  `CarShapes.add` instead of the box in `_ready`. scripts/traffic/car.gd: `CarShapes.add` instead of the box
  (one line). project.godot: autoload Ambience after RangeClub. self_test.gd: checks engine_sound, run_over, car_roof
  at the end. scenarios.gd: car_sounds, run_over, car_roof (before bulk_deal).

## Te testen door Curry
- `car_sounds` (F9): je zit achter het stuur: stationair, W = optrekken door de versnellingen, hard sturen of remmen =
  piepende banden. Verkeer heeft ook motorgeluid.
- `run_over` (F9): S = achteruit de 3 mensen achter je in; degene naast de auto blijft ongedeerd als je langzaam
  langsrijdt.
- `car_roof` (F9): spring op de motorkap en daarna op het dak (ook van het busje).

## For CLAUDE.md (suggested lines)
- Car sound (Roadmap 66): `Ambience` autoload attaches `VehicleSound` (engine loops by simulated rpm `rpm_for`, tyre
  screech, brake squeal; sounds from gen_engine_sounds.py) to every Car / PlayerCar. Check engine_sound, scenario
  car_sounds. Run over (64): `PlayerCar.impact_speed` (any side), check run_over. Standing on cars (65):
  `CarShapes.add` (body + cabin boxes), check car_roof.


# Part 16: Roadmap 67 - dogs are real NPCs (taken over from A, user 2026-11-14)

## Status
Done: self-test check `dogs` (+ A's park check adapted), scenario `dogs`.

## How it works
- `Dog` (scripts/npc/dog.gd, CharacterBody3D on layer 3 = npcs, group "dogs"): `Ambience` makes one for every DOG
  ParkGoer on EVERY peer at World/Dogs/Dog_<owner name> (same path everywhere -> the host's RPCs reach it; an old
  dog with the same name goes). HOST AUTHORITATIVE: the host moves it (kinematic along navmesh paths: kerbs would stop
  a small physics body) and sends `_net(pos, yaw, state)` 10x a second; clients smooth. `Dog.of(npc)` finds it.
  Looks = ProcDog in its new `driven` mode (animation, lead while FOLLOW, ball in the mouth while `carrying`).
- States: FOLLOW (on the lead beside the owner), FETCH_OUT / FETCH_BACK, MOURN, FLEE, DEAD.
- Fetch: at a sniff stop ParkGoer._dog_step now plays fetch half the time (`Dog.auto_fetch`, off in tests):
  `host_fetch(rounds)` - the owner faces a spot 7-13 m ahead (navmesh), throws (`_throw` RPC: a parabola on every peer),
  the dog runs off the lead, picks the ball up, brings it back and drops it at the owner's feet; 2-3 rounds.
- Owner killed -> the dog stays by the body 2.5 s, then runs 35 m away (navmesh path), wanders, gone after 45 s
  (`_free_rpc`). Owner gone home -> the dog goes too.
- Killing a dog (HEALTH 30, bullets and cars): `host_damage` returns false (no person kill / murder), the attacking
  player is reported for assault; `_die(impulse)` on every peer: the visual rides a RigidBody3D "Carcass" (world layer
  only) pushed away from the hit, legs loose; removed after 60 s.

## Decisions (what + why)
- One body + local visual per peer at a fixed path instead of a networked spawn: no spawner or World change needed
  (World is A's), and the dog only exists while its owner does, which every peer sees the same.
- Kinematic movement on navmesh paths: dogs must cross kerbs and park paths; a physics box got stuck on them.
- Simple "ragdoll" = one rigid body with the dog on it: dogs have no skeleton; it falls, rolls and lies still.
- Killing a dog is assault, not murder: stars, but not the murder response.

## Existing files changed (part 16)
- scripts/npc/park_goer.gd: no ProcDog in `_ready` (the Dog brings its own), `_dog_step` sniff stop -> fetch half the
  time. scripts/npc/proc_dog.gd: `driven`, `lead_on`, `carrying` (+ ball mesh), `_animate` split out of `_process`
  (the old behaviour is unchanged when not driven). autoload/ambience.gd: makes the dogs. self_test.gd: A's park check
  uses `Dog.of(walker)`; new check "dogs". scenarios.gd: dogs.
- REQUEST for A (world.gd is yours): the netcheck line `n.has_node("Dog")` (World ~line 258) -> `Dog.of(n) != null`
  (now it prints 0 dogs; nothing fails).

## Te testen door Curry
- `dogs` (F9): in het park speelt een baasje apport met zijn hond (bal gooien, terugbrengen). Schiet het baasje neer:
  de hond blijft even en rent weg. Een hond kan ook geraakt worden (valt slap neer).

## For CLAUDE.md (suggested lines)
- Dogs (Roadmap 67): `Dog` (scripts/npc/dog.gd, layer 3, World/Dogs/Dog_<owner>, made by `Ambience` on every peer,
  host drives + `_net` RPC), `Dog.of(npc)`, `host_fetch`, `Dog.auto_fetch`, states FOLLOW/FETCH/MOURN/FLEE/DEAD,
  ProcDog `driven`. Scenario dogs, self-test check dogs.


# Part 17: Roadmap 68 - birds, pigeons, cats, ducks (taken over from A, user 2026-11-14)

## Status
Done: self-test check `animals`, scenarios `animals` (park) and `ducks` (quay). No map files touched.

## How it works
- `Wildlife` (scripts/ambient/wildlife.gd, node World/Wildlife): made by the `Ambience` autoload on EVERY peer once
  the World is loaded (`--animals=0` = none). Purely local and cosmetic: no networking, no collision, no saves.
  `Wildlife.current`, `census()`, `scare(pos, radius)` / static `scare_at(pos)`.
- Spots without markers: roof spots are worked out from every `Building` (gable/hip ridge, front gutter, flat-roof
  parapet; dropped when anything is above); cat spots = free flat ground (not a RoadTile) 1.5 m in front of and behind
  buildings; pigeon flocks on the park path (World.park_path) + shop fronts; ducks in a box of sea by the quay
  (only if the map has a `Sea`), bobbing on the same waves as water.gdshader.
- `AmbientBird` kinds BIRD (24, on roofs, flies to another roof every 25-90 s, arc + flapping + glides), PIGEON
  (flocks of 5-7: walk, peck, head bob; a player within 3.2 m / a car within 5 m -> the whole flock flies onto one roof,
  back down after 12-28 s, not at night), DUCK (7: swim, dabble, swim away from people within 6 m, fly 16-28 m
  low over the water from a gunshot). `AmbientCat` (6): sits (tail swish), strolls to another cat spot (forward ray =
  walls, down ray = ground), bolts 9-15 m from a player within 4.5 m, a car within 3 m or a gunshot.
- Gunshots: `WeaponFX.flash` calls `Wildlife.scare_at(muzzle)` (every peer sees every muzzle flash: players, police,
  Crows): everything within 45 m takes off.
- Cheap: meshes cached per look (`CritterMesh`), no shadows, animals > 110 m from the camera don't update.

## Decisions (what + why)
- Local per peer, not networked: the animals are decoration; syncing 40 animals costs bandwidth for nothing. Each
  peer reacts to the same players, cars and shots, so they behave much alike.
- Spots from Building data instead of markers: works for every house now and later without touching the map (A's).
- No collision: animals never block players, cars or NPC paths, and bullets don't hit them (dogs remain the only
  animals you can shoot).

## Existing files changed (part 17)
- scripts/weapons/weapon_fx.gd: `flash` first calls `Wildlife.scare_at` (1 line). autoload/ambience.gd: makes
  World/Wildlife. self_test.gd: check "animals". scenarios.gd: animals, ducks.

## Te testen door Curry
- `animals` (F9): in het park staat een zwerm duiven voor je, een kat rechts. Loop naar de duiven: ze vliegen op een
  dak en komen later terug. Loop naar de kat: hij rent weg. Schiet (1, linkermuis): alles in de buurt vliegt/rent weg.
  Kijk omhoog: vogeltjes op nokken en dakgoten die soms naar een ander dak vliegen.
- `ducks` (F9): eenden op het water bij de kade; ze dobberen op de golven en zwemmen van je weg; een schot = ze
  vliegen laag over het water verder.

## For CLAUDE.md (suggested lines)
- Animals (Roadmap 68): `Wildlife` (scripts/ambient/, World/Wildlife, local per peer via `Ambience`, `--animals=0`),
  `AmbientBird` BIRD/PIGEON/DUCK, `AmbientCat`, `CritterMesh`; roof spots from Building data, `Wildlife.scare_at`
  from `WeaponFX.flash`; threats = players, cars, group `wildlife_threats` (tests). Scenarios animals/ducks, check animals.


# Part 12: staff assignment (Schedule I style) + the staff locker (user 2026-11-14)

## Status
Done: self-test check `staff_assign`, scenario `staff_assign` (screenshot flags `--crew=worker` / `--crew=locker`).

## How it works
- E on one of YOUR workers (StaffNPC) opens CrewWindow mode "worker": status + wage, "Their locker" (any locker
  here / a storage locker / staff locker / bookshelf in their property), the stations they may work (tick boxes,
  `Staff.assign_kinds(role)`: grower = grow pots, coca beds, drying racks; cook = cooking stations, cooling plates,
  leaf press, refinery; packager = drying racks, packaging tables), "Stations n / max" (`StaffConfig.max_stations`:
  grower 6, cook 4, packager 3), who else uses a station, "Show" = a yellow arrow over it for 6 s, and the route
  ("Staff Locker -> Grow Pot 1 -> Drying Rack -> Staff Locker", `Staff.route_text`). Others' workers still just talk.
- Host: worker records get "locker" (station id, "" = any) and "stations" (ids, empty = automatic = the old
  behaviour: every fitting station in the property). The step functions use `_work_stations(rec, kind)` /
  `_work_lockers(rec)`, so a worker takes supplies only from their locker, works only their stations and puts the
  products back in their locker. Requests: Staff.request("assign", uid, station_id) (toggle), ("locker", uid, id).
  `station_title` numbers stations per kind ("Grow Pot 2"); `station_by_id`, `assignable_stations/lockers`.
- `StaffLocker` (scripts/stations/staff_locker.gd, StorageLocker subclass, item `staff_locker` €250, legal, sold by
  every shop that sells the storage locker via Products at runtime; counts as a bed for staff): state "wages" = the
  wage box. E = CrewWindow mode "locker": the box, wages per day, "enough for n days", Put in €100/500/1000, Take it
  all out, its workers, "Open the storage". Request ("wages", station_id, +/-amount), host checks distance.
- Wages: a worker whose locker is a staff locker takes the daily wage from the box; box short -> `unpaid`, status
  "stopped: no wage money", one text to the boss, NO work, but they don't quit. Money in (or another locker) ->
  `_try_back_to_work` takes the wage, texts "back at work". Workers without a staff locker: paid from your pocket
  as before (and quit when you can't pay).
- A worker who is moved to another station walks there (StaffNPC tween + WALK anim, local).

## Decisions (what + why)
- Station list with tick boxes instead of clicking stations in the world: no change to player.gd (A's), works the
  same for host and clients, and the "Show" arrow still points at the real object.
- Nothing ticked = automatic: old saves and existing crews keep working unchanged.
- Unpaid staff-locker workers stop instead of quitting: that's the point of the wage box (a buffer you refill).
- Several workers may share a station (Schedule I forbids it; here it only shows "also: name").

## Existing files changed (part 12)
- autoload/staff.gd (assignment, `_work_*`, wages from the box, requests), scripts/staff/staff_config.gd
  (`max_stations`, staff_locker in `bed_items`), scripts/staff/staff_npc.gd (E opens the worker window, walk tween),
  scripts/ui/crew_window.gd (modes worker + locker), scripts/placement/placement.gd (STATION_BOXES staff_locker),
  autoload/products.gd (shops with storage_locker get staff_locker), tools/generators/gen_items.py (+ staff_locker),
  self_test.gd (check staff_assign), scenarios.gd (staff_assign, `--crew=worker|locker`).
- Also fixed in part 16/17: a dog now also picks up a ball that lies just off the navmesh; a scared duck picks a
  landing spot inside the duck water far enough away.

## Te testen door Curry
- `staff_assign` (F9): E op de grower: kies hun kast, vink een pot aan (ze lopen erheen en werken alleen die),
  "Show" toont een gele pijl, onderaan de route. E op de Staff Locker: stop er €100 in. Houd F7 een speldag
  ingedrukt: het loon gaat uit de kas. Lege kas = de grower stopt en sms't je; geld erin = weer aan het werk.

## For CLAUDE.md (suggested lines)
- Staff assignment (part 12): worker rec "locker"/"stations" (empty = automatic), `Staff._work_stations/_work_lockers`,
  `assign_kinds`, `StaffConfig.max_stations`, `route_text`, requests assign/locker/wages; `StaffLocker` (wage box
  state "wages", item staff_locker), CrewWindow modes worker/locker. Scenario staff_assign, check staff_assign.


# Part 18: zone systems - Fort Halden, the slums, the city, the bunker lab (user 2026-11-15)

## How it works
- `Zones` autoload (autoload/zones.gd, after Ambience). Static `zone_at(pos)` -> &"army" / &"slums" / &"city" /
  &"bunker" / &"" from fixed rects that match A's map zones (ARMY_RECT x -104..-36 z -430..-350, SLUM_RECT, CITY_RECT)
  + `BunkerLab.inside`; `zone_name(pos)`. `army_on` / `npcs_on` are off under --selftest / --netcheck (checks turn
  them on). Host ticks every 0.5 s.
- **Fort Halden** (`Soldier`, scripts/npc/soldier.gd, prefabs/npc/soldier.tscn, PoliceOfficer subclass like Rival,
  group "soldiers", AK-47, 150 HP, camo + helmet; the scene is added to World/NPCSpawner at runtime). 8 guard posts
  (`Zones.guard_posts()`): 2 outside the gate, one on top of every Watchtower (ray down onto the platform), 2 on the
  parade ground; a dead guard comes back after 180 s. Within 16 m of the gate (`ARMY_GATE`) a player gets a toast
  "HALT! ... we open fire" (every 15 s) and the gate guards aim. Inside the fence (`in_army_base`) or shooting a
  soldier = `army_hostile(p)` (90 s): the soldiers who see you shoot (no arrests, no police stars: the army handles
  it itself), guards within 40 m come for you, and the ALARM (60 s, extended while you stay near) sends 4 heavy
  reinforcements (220 HP) out of the barracks; after the alarm they walk back and vanish (`dismiss`). Soldiers
  don't follow you further than 30 m from the base. Dead soldiers drop 7.62 ammo (15% an AK).
  `Zones.allow_army(p, seconds)` = a pass for missions.
- **Slums** (Rosehill Park): 2-3 poor residents per FireBarrel (`slum_spots()`), **city**: 3 office workers in front of
  every 3rd Tower (`city_spots()`, only 07:00-20:00). Non-wandering networked pedestrians (`add_resident`), spawned
  when a player is within 150 m of the zone, removed past 220 m (a waiting customer stays). They stand by their
  spot, chat (TALK), flee from gunfire like everyone and walk back. Every 40-90 s one of them in a zone near a
  player becomes a customer (`make_zone_customer`, one at a time per zone): slums 1-2 bags at 60% of the price,
  city 2-4 bags at 150% (`Zones.PRICE`, `customer_price(npc, price)`), product via `Products.pick_customer_product`.
  The cheap starter property is A's slum_shack (€4,000, rank 0: not in RankConfig).
- **Bunker** (A's `BunkerComplex` at Mountain/Bunker, point 74, with its `BunkerProperty` "bunker"): `Zones._setup_bunker`
  (every peer) makes it buyable: "Mountain Bunker", €250,000 (`Zones.BUNKER_PRICE`), rank 5 (RankConfig), listed by
  the estate agent. Host `_bunker_door_tick`: the blast door (`BunkerDoor.host_set_locked`) is locked while the crew
  doesn't own it, unlocked once they do (and locked again when it's sold). The lock is off in the self-test /
  netcheck / test scenarios (A's bunker checks walk in) unless GameState.world["bunker_lock"]
  (`Zones.bunker_lock_forced`, my check + scenario). Lab: stations go anywhere inside (BunkerProperty.contains,
  A's LabSpot1-6); `Raids.RAID_FREE` = [&"bunker"]: never raided. `Zones.zone_at` = &"bunker" inside.
- Soldiers chase in straight lines only (`Soldier._chase_to`: one side step round an obstacle, else hold and watch;
  a navmesh path from the base ran off to the town); tower guards stay up; gate guard 2 stands inside the gate.

## Decisions (what + why)
- Soldiers on PoliceOfficer's brain (like the Crows): aiming, bursts, sight, leash all exist already.
- No navmesh at the base (A's ArmyBase is not under NavRegion): guards stand at posts and walk straight lines; a
  blocked line puts them back on the post. Good enough for guards; ask A for a navmesh if they should patrol.
- Army = its own reaction, no Wanted stars: the user asked for "eigen zware reactie"; the police don't come up.
- Gate guards face outward; the alarm also alerts guards within 40 m (the fence blocks their view of the yard).
- Zone residents are our own pedestrians (not A's wandering ones) so the price can depend on the zone without
  touching world.gd; A's random customers keep normal prices (optional hook asked in B.md).
- First version had my own hall under the portal (teleport keypads); A then built the real complex (point 74) and
  left buying/lock/lab to me, so mine was dropped and only the sale + lock + no-raids logic stayed.

## Existing files changed (part 18)
- project.godot (autoload Zones), autoload/raids.gd (RAID_FREE); A's bunker: only property fields + door lock at runtime, scripts/progression/rank_config.gd (bunker: 5),
  self_test.gd (check zones), scenarios.gd (army_gate, slum_life, city_customers, bunker_lab + flag `--bunker-in`).

## Te testen door Curry
- `army_gate` (F9): loop naar de slagboom (waarschuwing), loop erdoor (alarm, schieten, 4 versterkingen).
- `slum_life`: bewoners rond de vuurtonnen; na ~10 s sms't er een (goedkoop, 60%).
- `city_customers`: kantoormensen voor de torens; na ~10 s een rijke klant (150%).
- `bunker_lab`: E op de staaldeur: op slot. Na 8 s koopt de crew de bunker: de deur gaat van het slot. Lift/trap
  naar beneden, B = bouwmodus, zet de Cook Station in de labhal.

## For CLAUDE.md (suggested lines)
- Zones (part 18): `Zones` autoload (`zone_at`, army_on/npcs_on), `Soldier` (PoliceOfficer subclass, group soldiers,
  `Zones.guard_posts`/`army_hostile`/`allow_army`/`alarm_on`), slum/city residents (`residents(zone)`,
  `make_zone_customer`, `PRICE`), bunker sale + door lock (`Zones.bunker`, `bunker_door()`, `BUNKER_PRICE`,
  `bunker_lock_forced`), `Raids.RAID_FREE`. Scenarios army_gate, slum_life, city_customers, bunker_lab; check zones.


# Part 19: the mission system (base for the story, user 2026-11-15)

## How it works
- Missions are DATA: every `MissionData` .tres in data/missions/ (scripts/missions/mission_data.gd: id, title,
  summary, giver, min_rank, requires, repeatable, objectives, reward_cash/xp/items, done_text). Steps are
  `MissionObjective` sub-resources (kind GO_TO / TALK_TO / DELIVER / KILL / SURVIVE, text with {count} {need} {time}
  {npc} {item}, marker + offset or position, radius, npc_id/npc_name/npc_variant/npc_yaw/lines, item_id/count,
  kill_group, spawn_enemies/enemy_post/enemy_ak, seconds). New mission in Godot: data/missions > right click > New >
  Resource > MissionData; Objectives > Add Element > New MissionObjective.
- `Missions` autoload (after Zones), HOST AUTHORITATIVE. One mission at a time for the whole crew; state in
  GameState.world["missions"] (saved): active, step, count, time, members (in the game at the start), late, done,
  enemies, rewarded. `host_start(id, by)` / `request_start`, `why_not(id)`, `available()`, `host_end(won, why)` /
  `request_abandon`. Host tick 0.25 s: go to = anyone of the crew within radius; talk to / deliver = E on the
  mission NPC (`host_talk`, deliver takes the items); kill = spawned enemies all dead (or `kill_group` kills via
  the kill_hooks group when none are spawned); survive = time runs while someone is within radius; whole crew
  dead = failed. Mission NPCs = networked non-wandering pedestrians "MissionNPC_<npc_id>" (back to their spot
  after a scare); enemies = Black Crows via World.add_rival (post harbour/yard).
- Rewards: cash + items to every MEMBER present (full pockets = loot bag), XP once for the crew; players who joined
  during the mission ("late") get the progress and the HUD but no reward ("joined late, no reward").
- Every peer gets a small `view` (`_sync`, also to late joiners via `request_view`): `MissionHUD` (objective top right
  under the money box with step n/m + distance, a gold screen waypoint clamped to the edges with an arrow, banners
  NEW MISSION / OBJECTIVE COMPLETE / MISSION COMPLETE / FAILED), `MissionTalkBox` on mission NPCs (layer 2, E,
  name tag with "!" when they are the current step), `MissionMapPin` on every PhoneMap, and the phone app
  "Missions" (`MissionLog`: running mission with ticked steps + Give up, available ones with Start, done ones).
- Two test missions: `first_contact` "A Foot in the Door" (talk to Marco by the park -> QuickFuel -> give Dex 2 bags;
  €600, 150 XP, 10 baggies) and `pier_pressure` "Pier Pressure" (after the first: the Crows' pier -> kill 3 Crows ->
  hold the pier 45 s against 3 AK Crows; €2,000, 300 XP, 36 9mm rounds).

## Decisions (what + why)
- Phone app + map pin hooked in from outside (node_added: the home screen's Crew button / every PhoneMap) instead
  of editing phone.gd (A's file). A proper hook later: see B.md.
- Own HUD CanvasLayer (MissionHUD) instead of hud.gd (A's file).
- "Late" = not in the game when the mission started: simple and fair (a rejoining member keeps the reward).
- Kill steps with spawned enemies count deaths of THOSE enemies whoever killed them (police, a car): the goal is
  "they are gone".

## Existing files changed (part 19)
- project.godot (autoload Missions), self_test.gd (check missions), scenarios.gd (mission_contact, mission_pier).

## Te testen door Curry
- `mission_contact` (F9): goud ruitje + doel rechtsboven. E op Marco -> naar de QuickFuel -> E op Dex (2 zakjes) ->
  beloning. Tab > Missions = het logboek; Map = goud pinnetje. Met 2 instanties: wie later joint ziet "joined late".
- `mission_pier`: loop naar de pier, schiet de 3 Crows neer, houd 45 s stand.

## For CLAUDE.md (suggested lines)
- Missions (part 19): `MissionData` / `MissionObjective` .tres in data/missions/, `Missions` autoload (host state
  GameState.world["missions"], `host_start`/`request_start`, `host_talk`, `host_end`, `view` + `changed`),
  `MissionHUD`, `MissionTalkBox` (NPC "MissionNPC_<id>"), `MissionMapPin`, `MissionLog` (phone app). Check missions,
  scenarios mission_contact / mission_pier.


# Part 20: dialogue system for NPCs (text box with choices that can start missions, user 2026-11-15)

## How it works
- Data: `DialogueData` (speaker + pages), `DialogueNode` (id, speaker, text, choices, next, `entry` + `show_if`),
  `DialogueChoice` (text, next page, action NONE / START_MISSION (mission) / FINISH_STEP, `show_if`). Conditions
  (`DialogueNode.Show`): ALWAYS, MISSION_AVAILABLE, MISSION_DONE, MISSION_NOT_DONE, MISSION_RUNNING,
  NO_MISSION_RUNNING (checked on every peer from `Missions.view`). A talk starts on the first `entry` page whose
  condition holds; answers whose condition fails are hidden. Example: data/dialogue/marco.tres.
- Talkers: `TalkNPCData` .tres in data/dialogue/npcs/ (npc_id, name, marker + offset or position, yaw, variant,
  dialogue). `Missions` spawns them on the host as "MissionNPC_<npc_id>" (same node a mission step can point at by
  npc_id, never despawned by missions; `talkers_on` off in self-test/netcheck). Marco stands by the park
  (ParkSmokeSpot + 3 m) and gives both test missions through his dialogue.
- E on an NPC -> `Missions.host_talk`: the running mission's step with this NPC first (TALK_TO with a dialogue opens
  it; its FINISH_STEP answer - or, when it has none, the end of the talk - finishes the step via
  `request_step_done` -> `host_step_done` (host checks the step + distance); TALK_TO with plain `lines` and DELIVER
  show the lines as pages), else the talker's own dialogue, else "Not now.". The host only sends WHICH dialogue
  (npc, mission, step, lines) to the owner (`_show_talk_rpc`); the owner shows `DialogueBox`.
- `DialogueBox` (scripts/dialogue/dialogue_box.gd, in the player's HUD layer): name, typed-out text (Space = all),
  answer buttons (mouse or keys 1-4), Continue/Bye on pages without answers; Esc, death or walking > 7 m away
  closes it. START_MISSION -> `Missions.request_start` (host checks `why_not`).
- Mission 1 now: Marco's dialogue starts it ("Got anything for me?" -> "I'm in." / "What's in it for me?" ->
  "Deal."), steps: QuickFuel -> give Dex 2 bags -> back to Marco (his report dialogue: answer = step done -> reward).
  After it Marco offers "Any bigger work?" -> Pier Pressure.

## Decisions (what + why)
- Dialogue lives on the owner's peer (only the start / finish actions go to the host): no network traffic per page,
  and the host still decides every effect.
- Talkers share the mission NPC naming so a mission can simply say npc_id "marco".
- Conditions are a fixed enum (not script expressions): easy to pick in the Inspector, safe, enough for missions.

## Existing files changed (part 20)
- autoload/missions.gd (talkers, host_talk with dialogues, step done), data/missions/first_contact.tres (new steps),
  missions_test.gd (dialogue flow), scenarios.gd (mission_contact without auto start + flag `--talk`).

## Te testen door Curry
- `mission_contact` (F9): E op Marco: tekstvak met keuzes (muis of 1-4). "Got anything for me?" -> "I'm in." start
  missie 1. Na Dex terug naar Marco, kies een antwoord -> beloning. Praat daarna weer met Marco: nieuwe klus.

## For CLAUDE.md (suggested lines)
- Dialogue (part 20): `DialogueData`/`DialogueNode`/`DialogueChoice` (.tres, conditions `DialogueNode.Show`,
  actions START_MISSION/FINISH_STEP), talkers `TalkNPCData` in data/dialogue/npcs/ (Missions.talkers, `talkers_on`),
  `DialogueBox.open_for`, `Missions.host_talk` / `_show_talk` / `host_step_done`, `last_talk` (tests). Scenario
  mission_contact (`--talk`), check missions.


# Part 21: city life + army base life (user feedback 2026-11-15 "de stad en de militaire basis voelen leeg")

## How it works
- City (`CityLife`, scripts/world/city_life.gd, static helpers used by `Zones` on the host): the city has no navmesh,
  so walkers follow a SIDEWALK GRAPH built from the road grid (CX/CZ junctions as in gen_world, 4 corner nodes per
  junction 5.4 m off the road centre, edges along the block sides + across at the junctions). Spots
  (`CityLife.spots(world)` = `Zones.city_spots()`), each with opening hours:
  - office groups of 3 in front of every 3rd `Tower` (07-20), 2 neighbours at the door of every `ApartmentBlock*`
    (A's point 76, 08-22:30), bus stop queues of 3 (A's `CityBusStop*` markers, else mid-block on the two middle
    avenues, 06-23), sitters on `TerraceSeat*` markers or the CityBench seats (2 of every 3, 08-22),
  - 26 walkers on the graph by day, 8 of them also at night (`WALKERS_DAY` / `WALKERS_NIGHT`).
  City residents wear office / business clothes (`CityLife.OFFICE_VARIANTS`). Out of hours they go (unless they are a
  customer right now). Once a player comes near the city, `Traffic.spawn_cars(CityLife.EXTRA_CARS (8), true)` adds
  cars on the city routes.
- Army base (`Zones.guard_posts()`): A's `ArmyPost*` markers when they exist (name with "Chat" = chatting), else my
  own posts: 2 at the gate, 2 at the flag, 4 chatting in front of the hangars, 3 at the helipads, 2 by the vehicle
  row; a marksman (`gun` sniper, `Soldier.MARKSMAN_PROFILE`) on top of every `Watchtower*`; 2 patrols of 2 walking a
  closed round of straight legs (`Soldier.route`, `_walk_route`; A's `ArmyPatrolA*`/`B*` markers win). Profiles
  data/npc/soldier.tres (AK, sight 60 m, accurate 5-round bursts, 14 dmg) and soldier_marksman.tres (sniper, sight
  95 m, 40 dmg). The base is manned only while a player is within `ARMY_MAN_RANGE` (220 m) and emptied (idle soldiers)
  past `ARMY_LEAVE_RANGE` (300 m): ~21 soldiers' AI only runs when someone can see them.

## Decisions (what + why)
- Sidewalk graph instead of asking A for a city navmesh: works now without touching the map; A's markers / a navmesh
  later replace it without changes elsewhere.
- Soldiers get their own profiles (the old one was the Crows' rival_ak with sight 26 m: they reacted too late), the
  tower guards sniper rifles: "zwaarder dan de politie".
- Manning by distance: 20+ soldiers + 50 city people would cost the host AI time everywhere on the map.

## Existing files changed (part 21)
- autoload/zones.gd (city spots, hours, walkers/sitters, extra traffic, army posts/patrols/marksmen/manning),
  scripts/npc/soldier.gd (profiles, route, chatty), zones_test.gd (army + city life checks), scenarios.gd.

## Te testen door Curry
- `city_life` (F9): drukke stad op een hoek: lopers op de stoepen, groepjes bij torens, wachtenden bij bushaltes,
  mensen op bankjes, meer auto's. F7: na 22:00 wordt het stil.
- `army_life` (F9): bij de poort van de basis (god mode): wachters, patrouilles, scherpschutters op de torens.
  Loop naar binnen: alarm.

## For CLAUDE.md (suggested lines)
- City life (part 21): `CityLife` (sidewalk graph, `spots`, `walk_step`, `sit`, WALKERS_DAY/NIGHT, EXTRA_CARS), markers
  CityBusStop*/TerraceSeat* optional. Army: `Zones.guard_posts()` (ArmyPost*/ArmyPatrolA*/B* optional), `Soldier.route`
  / `chatty` / MARKSMAN_PROFILE, ARMY_MAN_RANGE. Scenarios city_life, army_life; check zones.


# Part 22: more missions + dialogue (user 2026-11-15 "daarna verder met het missie- en dialoogsysteem")

## How it works
- Mission 3 "Uptown" (data/missions/uptown.tres, after mission 1, giver Marco: his new answer "Know anyone with real
  money?"): GO_TO the city (ApartmentBlock1's front door) -> TALK_TO Nadia (a dialogue with 2 answers, both finish the
  step) -> DELIVER 4 Bags of Weed to her. EUR 1400 + 250 XP.
- Mission 4 "Rosehill Shield" (data/missions/rosehill_shield.tres, after mission 2, giver Old Joe): KILL 3 Crows at the
  SlumShack -> SURVIVE 40 s against 3 with AKs -> TALK_TO Old Joe. EUR 2200 + 350 XP + 60 rifle rounds.
- Old Joe = a new talker (data/dialogue/npcs/old_joe.tres, FireBarrel1 + 3.4 m) with his own dialogue
  (data/dialogue/old_joe.tres): hello / his job (with a "what's it worth" page) / a thank-you page once the mission is
  done / "busy" while another mission runs. Nothing new in code: only .tres files (proof the data format works).

## Decisions (what + why)
- The new missions use the new zones (the city pays more, the slums need protection): the story ties the map together.
- Rosehill Shield needs Pier Pressure (you have shown you can handle the Crows), Uptown only the first job.

## Existing files changed (part 22)
- data/dialogue/marco.tres (answer + 2 pages for Uptown), missions_test.gd (both missions), scenarios.gd.

## Te testen door Curry
- `mission_uptown` (F9): E op Marco -> "Know anyone with real money?" -> "The city it is." Volg de waypoint naar de
  stad, praat met Nadia, geef haar 4 zakjes.
- `mission_rosehill` (F9): E op Old Joe bij de vuurton -> "You look worried, old man." -> "I'll deal with them."

## For CLAUDE.md (suggested lines)
- Missions 3/4 (part 22): uptown (Nadia, city), rosehill_shield (talker Old Joe, slums). Scenarios mission_uptown,
  mission_rosehill (`--talk`).


# Part 23: the airfield counts as the army base (A's point 85, user 2026-11-15)

## How it works
- `Zones.ARMY_RECT` = A's new fence: x -104..236, z -442..-350 (was x -104..-36, z -430..-350). Everything that uses it
  follows: `zone_at` (&"army"), `in_army_base` (soldiers shoot intruders, the alarm), `near_army_base` (manning range,
  soldier leash). Walking in anywhere on the airfield now sets off the alarm, not only through the gate.
- The soldiers now stand at A's ArmyPost* markers (gate, flag, garages, helipads, vehicles, control tower, apron,
  both runway ends) + a marksman on each of the 6 watchtowers + patrols A (inner yard) and B (along the airfield fence):
  30 soldiers. No code change needed for that: `guard_posts()` already preferred the markers.

## Decisions (what + why)
- A rectangle stays enough: the fence is one rectangle again.

## Existing files changed (part 23)
- autoload/zones.gd (ARMY_RECT), zones_test.gd (runway / jet hangars / towers / fence inside), scenarios.gd.

## Te testen door Curry
- `army_airfield` (F9): buiten het zuidhek bij het platform (god mode). Loop of klim het vliegveld op: alarm, ze schieten.

## For CLAUDE.md (suggested lines)
- Army base rect (part 23): `Zones.ARMY_RECT` = the whole fence incl. the airfield; scenario army_airfield.


# Part 24: Zones residents with A's NPC streaming (A's point 87, A.md 2026-11-16)

## How it works
- `Zones._residents_tick` skips `_resident_step` for a resident whose `lod` is `Pedestrian.Lod.ASLEEP` (far from every
  player): no walk / sit / chat orders for ~100 sleeping office workers. It wakes where it was and carries on.
- Checked the other B NPCs against `NpcStreamer.pinned`: mission NPCs (`MissionNPC_*`, also Marco / Old Joe) and
  mission enemies (meta "mission") are pinned already; staff, dealers and the bulk buyer are local Node3D visuals (not
  Pedestrians); soldiers are only manned within 220 m of the base and may sleep at their post; live-raid Crows only
  come while the crew is near.

## Decisions (what + why)
- Skip, don't pin: residents are scenery, so sleeping far away is exactly what point 87 wants. Before the change a
  sleeping walker was already left alone (its `_moving` flag stays set), so this is a small CPU saving, not a bug fix.

## Existing files changed (part 24)
- autoload/zones.gd (one skip), scripts/debug/zones_test.gd (check "sleeping residents stay put").

## Te testen door Curry
- Niets nieuws om te zien (alleen een interne besparing); `city_life` (F9) moet er hetzelfde uitzien als voorheen.


# Part 25: Roadmap 88 - NPC day rhythm (taken over from A, user 2026-11-24)

## How it works
- `DayRhythm` (scripts/npc/day_rhythm.gd, node World/DayRhythm, host, `DayRhythm.current`), config `DayRhythmConfig`
  in data/npc/day_rhythm.tres: blocks morning 09-12 30%, afternoon 12-16 30%, evening 16-22 30%, night 22-09 10%
  (`block_start` / `block_share`, all editable). `World.spawn_pedestrians(count)` makes it instead of a fixed crowd
  (`count` = `outside_busiest`, so the busiest block has the old 10 out); `--no-rhythm` = the old fixed crowd, never in
  the self-test. Population = outside_busiest / biggest share = 33 people, each with a block and a house.
- Homes = every residential `Building` with a front door (`door_bay`) whose step has a navmesh point, outside the
  Zones areas (army base, slums, city and bunker keep their own people): 67 on the current map (`find_homes`).
- Records (data only): INSIDE / OUT / HOMEWARD / DEAL. At its block's start a record steps out of its own front door
  (never while a player within 35 m looks at that door, or stands within 4 m); at the end `Pedestrian.call_home(door)`
  (breaks off the current walk; the wander loop walks to the door, `home_reached`) and the node is freed at the step
  (or after `go_home_timeout` out of sight; asleep in A's NpcStreamer = straight inside). The first tick puts the
  current block's people on random sidewalks as before.
- Home deliveries: `World.make_customer` asks `DayRhythm.home_customer()` with `home_deal_chance` (35%): someone at
  home whose door is 8-160 m from a player steps out (non-wandering), deals, then walks back in.
- Death: no World respawn for them (`Pedestrian._on_died` skips meta "rhythm"); the slot comes out of its door again
  after `respawn_time` (60 s). `Pedestrian.can_be_customer()` is false while going home.
- Fixed NPCs (shopkeepers, Marco / Old Joe, soldiers, mission NPCs, police, Crows, park goers, zone residents) are not
  part of it: they are never spawned by spawn_pedestrians.

## Decisions (what + why)
- "Same total" read as: the busiest block looks like the old crowd (10 out); the night is quieter (3). Literally
  splitting 10 people over the day would leave 3 people in the village by day - too empty.
- Spawn/despawn at the door instead of walking into the house: inside is data only, like the roadmap asks; no
  interior navmesh needed and no NPCs stuck behind closed doors.
- Village homes only: the zones already have their own clock (`CityLife.in_hours`) and residents.

## Existing files changed (part 25)
- scripts/npc/pedestrian.gd (`home_call`, `home_reached`, `call_home`, wander loop goes home, `can_be_customer`,
  `_on_died` skips rhythm people), scenes/world/world.gd (`spawn_pedestrians` makes DayRhythm, `make_customer` home
  deals), self_test.gd (check day_rhythm), scenarios.gd (scenario day_rhythm). New: scripts/npc/day_rhythm.gd,
  day_rhythm_config.gd, data/npc/day_rhythm.tres, scripts/debug/day_rhythm_test.gd.

## Te testen door Curry
- `day_rhythm` (F9): 11:45 op de stoep in het dorp. Om 12:00 (na 15 s) lopen de ochtendmensen naar hun eigen voordeur
  en gaan naar binnen; de middagmensen komen uit die deuren. Kom dichter dan 35 m bij een deur en kijk ernaar: er komt
  niemand uit tot je wegkijkt. F7 = tijd sneller: 's nachts maar een paar mensen buiten.

## For CLAUDE.md (suggested lines)
- Day rhythm (Roadmap 88, B part 25): `DayRhythm` (World/DayRhythm, host, `current`, config data/npc/day_rhythm.tres
  `DayRhythmConfig`), made by `World.spawn_pedestrians` (`--no-rhythm` = fixed crowd; never in the self-test); homes =
  residential Building front doors on the navmesh outside the Zones (`find_homes`); `Pedestrian.call_home` /
  `home_reached`; home deals `home_customer()`. Scenario day_rhythm, self-test check day_rhythm.


# Part 26: Roadmap 89 - npc_bench (taken over from A, user 2026-11-24)

## How it works
- `NpcBench` (scripts/debug/npc_bench.gd), started by the F9 scenario `npc_bench` (`--bench-quit` quits at the end,
  `--bench-step=S` changes the 20 s per step). Spots: city centre, slums, docks (SPOTS). Per spot it steers the number of
  awake NPCs with A's `NpcStreamer.cap_override` (0 = baseline, then 20, 40 ... 160) and spawns extra plain
  pedestrians 10-70 m round the player (they walk short straight legs, so FULL + MID levels like real ones). Each step:
  mean FPS + 1% low (99th percentile frame) over 20 s; it stops a spot at the first step that fails. Pass = 1% low
  >= 55, or >= 90% of the spot's own baseline when even the empty spot is below 55. Advice = lowest spot limit x 0.8.
  On screen (label), [NpcBench] lines, screenshots/npc_bench.txt.

## Result on this PC (RTX 5060 Ti, 1920x1080 window, vsync off; session A's self-test was running at the same time)
| spot | 0 NPCs | 20 | 40 |
|---|---|---|---|
| city centre | 117 fps / 1% low 53 | 101 / 51 | 86 / 46 |
| slums | 127 / 54 | 113 / 51 | 84 / 44 |
| docks | 75 / 43 | 62 / 37 | - |
- The 1% low is below 55 even WITHOUT NPCs (hitches from something else: streaming, GC, the other process); every 20
  awake NPCs cost ~10-25 fps mean.

## Decisions (what + why)
- `max_active_npcs` (A's data/npc/streaming.tres, now 60) is NOT changed: the numbers were taken with a second Godot
  self-test running and the 1% low is dominated by hitches that are not NPCs. The bench's advice under that load was
  20. Run `npc_bench` (F9) with nothing else open and set the value it advises; A: your call for the release value.
- Bench NPCs are plain pedestrians driven by the bench (no navmesh needed: the city has none).

## Existing files changed (part 26)
- scripts/debug/scenarios.gd (scenario npc_bench). New: scripts/debug/npc_bench.gd.

## Te testen door Curry
- `npc_bench` (F9), ~5-10 minuten, niets aanraken en niets anders open hebben. Stuur me de tabel die op het scherm
  verschijnt (staat ook in screenshots/npc_bench.txt).

## For CLAUDE.md (suggested lines)
- NPC bench (Roadmap 89, B part 26): `NpcBench` (scripts/debug/npc_bench.gd), scenario npc_bench (window; `--bench-quit`,
  `--bench-step=S`), steers `NpcStreamer.cap_override`, writes screenshots/npc_bench.txt.
