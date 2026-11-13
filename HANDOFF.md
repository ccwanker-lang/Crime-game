# HANDOFF (2026-11-13)

## Where we stopped
- Done and committed: points 27 (stylized art style rolled out + HUD/F1 help), 28 (wanted stars),
  29 (walking on the road), 30 (police life). Full self-test for 28: ALL PASSED; for 29/30 the targeted checks
  (`--only=pedestrians,police_life,wanted,police`) passed. The last full self-test run (with 29/30) was cut off by the
  end of the session: RERUN IT FIRST: `--headless --path . -- --selftest --port=7792`, then `python tools/netcheck.py 7793`.
- Half done: point 31 (Black Crows rework). The live code (scripts/npc/rival.gd) is still the old, working point-11
  version. A draft of the new Rival is in `docs/wip/rival_point31_draft.gd.txt` (roles YARD/STREET, turf rect from
  "TurfYard", memory + sharing, yard leash, yard chats, AK variety, World.rival_died hook).

## How to finish point 31
1. Copy the draft over scripts/npc/rival.gd.
2. PoliceOfficer: add `var gun: StringName = &""` (weapon id; `_pistol = ItemDB.get_item(gun if gun != &"" else
   (&"smg" if heavy else &"pistol"))`), and leash hooks `_leash_center()` (from_car pos or INF) / `_leash_range()`
   (LEASH) used in `_think` instead of the from_car check.
3. Sync `gun` (spawn property) in police_officer.tscn and give rival.tscn the same replication config (heavy + gun).
4. data/npc/rival_ak.tres (like rival_combat.tres, damage ~11, fire_rate ~5, burst 3-5).
5. World: rival_count 6 total, street group 2 at night (`_rival_loop` assigns role STREET), initial fill at
   `Rival.yard_point`, `rival_died()` -> respawn after 60-120 s at the house door markers, 30% AK.
6. Self-test `_check_rivals`: set role STREET for the night-attack part, daybreak = back to YARD (not freed); new checks:
   yard Crow ignores player outside turf, attacks on turf, remembers + shares, new Crow ignores, AK gun.
7. Scenarios: update rivals_night text, add crows_turf. Docs (Roadmap, Decision, CHANGELOG, CLAUDE.md), commit.

## Next 5 steps (in order)
1. Rerun full self-test + netcheck (see above), fix anything red.
2. Finish point 31 (above).
3. Point 32: panic (cars always drive away, never stop, also not at junctions; pedestrians flee until out of sight).
4. Point 33: street lamps on both sides of every street (barber shop street has none) + the kerb that sometimes blocks.
5. Point 34: phone deals (offer, counter price, Accept deal, Confirm deal at the meeting) + fix the sell_weed scenario.
Then 35-41 (property map icons/agent shows location, build mode on B, bed skips night, bookcase storage, trash bin +
garbage truck, money messages, hotbar wheel), then 12-14, then milestone 3.

## Waiting for the user's choice
- Nothing blocking. Try the new scenarios (F9): wanted_one, wanted_three, wanted_five, wanted_hide, road_crossing,
  police_life. Feedback on the art style rollout / HUD welcome.
