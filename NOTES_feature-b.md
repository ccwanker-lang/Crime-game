# NOTES feature-b: ranks + XP (DESIGN "Progression")

Session B notes. To be folded into DESIGN.md (Roadmap status + Decisions) / CHANGELOG.md / CLAUDE.md by
session A when merging (B may not edit those files).

## SESSION END (2026-11-13) - where we stopped
- DONE + committed: part 1 ranks + XP, part 2 staff + dealers (both complete, targeted checks ranks + staff pass).
- feature-b is rebased on main f4df907 (point 38). Full self-test after the FIRST rebase (on c566f9c): ALL PASSED
  (417). Full self-test after the SECOND rebase was stopped by the user at 118 checks, 0 FAIL so far.
- Half done: nothing in code. Open: A should add 1 line in scripts/world/sleep.gd `_morning()`:
  `get_tree().call_group(&"hours_skipped", "on_hours_skipped", skipped)` (staff catch up on slept nights).
- NEXT STEP: rebase on main if A committed more (`git log feature-b..main`; conflicts are only in
  self_test.gd CHECKS / scenarios.gd: keep both sides, ours at the end), run the full self-test
  (`--headless --path . -- --selftest --port=7778`), netcheck on 7778, then put "KLAAR OM TE MERGEN" in B.md.

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
