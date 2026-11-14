# NOTES feature-b: ranks + XP (DESIGN "Progression")

Session B notes. To be folded into DESIGN.md (Roadmap status + Decisions) / CHANGELOG.md / CLAUDE.md by
session A when merging (B may not edit those files).

## MERGED parts 1 + 2 (A, main c95e70c, already in DESIGN/CHANGELOG/CLAUDE.md). Open for the next merge: parts 3-7
(meth, cocaine, courier/lawyer/bribes, Crow raids + guards, roadside team) below.

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
