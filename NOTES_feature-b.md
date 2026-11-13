# NOTES feature-b: ranks + XP (DESIGN "Progression")

Session B notes. To be folded into DESIGN.md (Roadmap status + Decisions) / CHANGELOG.md / CLAUDE.md by
session A when merging (B may not edit those files).

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
- XP values: fair sale 10/bag, phone deal (accepted text) +15, short-changed sale half, customer runs 0;
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
- scripts/npc/pedestrian.gd `_server_sell`: 1 line `Progression.host_sale(...)` (sale XP; uses `_meet_accepted`
  for the phone-deal bonus). Point 34 (phone deals) should keep this call where a deal completes.
- scenes/player/player_combat.gd `_host_fire` (killed branch): 1 line `Progression.host_kill(player, victim)`.
- scripts/npc/shopkeeper.gd `_server_buy`, scripts/npc/estate_agent.gd `_server_buy_property`: rank check.
- scenes/player/hud.gd: `add_child(RankPanel.new())` in `_ready`; locked rows in `open_shop` / `_fill_estate`
  + helper `_rank_lock`.
- scripts/debug/scenarios.gd: scenario `ranks`. scripts/debug/self_test.gd: `ranks` in CHECKS + `_check_ranks`.

## For CLAUDE.md (suggested lines)
- Ranks (milestone 3): `Progression` autoload (crew XP in GameState.world["progress"], host_add/host_sale/host_kill,
  item_lock/property_lock gates, off in selftest/scenarios unless `force_gates`), `RankConfig` in
  `data/progression/ranks.tres`, HUD `RankPanel`. F8 = +100 XP, `--xp=N`. Scenario ranks, self-test check ranks.
