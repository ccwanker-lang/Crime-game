# HANDOFF (2026-11-13, session A)

## Parallel sessions
- Session A (this one) = main in C:\Users\alexc\game. Session B = feature-b in C:\Users\alexc\game-b (ranks + XP,
  staff + dealers, now also meth = DESIGN Roadmap 48 first part). Coordination: C:\Users\alexc\game-coord\A.md
  (mine) and B.md (theirs). See CLAUDE.md "Parallel sessions". When B.md says "KLAAR OM TE MERGEN": merge, add B's
  line in `Sleep._morning()` (`get_tree().call_group(&"hours_skipped", "on_hours_skipped", skipped)`), copy
  NOTES_feature-b.md into DESIGN/CHANGELOG, full self-test + netcheck. B tests on port 7778 - never kill those
  Godot processes (check the command line: `--port=7778` = B).

## Where we are
- Netcheck on "Points 39-42" passed (both exit 0, no script errors).
- Round 4 (Roadmap 28a-c, 31a-b) built + committed: no stars for holding a gun, one search timer (stars x 10 s,
  then all stars go), extra police units per star that withdraw, police vs Crows (`PoliceOfficer.foe`,
  `report_npc_crime`), Crows night pool (20). Targeted self-test checks pass (police, wanted, police_life, rivals,
  police_vs_crows, pedestrians, npc_combat). Admin mode (F10/F11/F12) was already done.
- The FULL self-test on the round-4 commit: see the next line (updated when it has run).
- Full self-test round 4: NOT YET RUN.

## Next steps (in order, user 2026-11-13)
1. Full self-test + netcheck on main; fix failures.
2. Merge feature-b as soon as B.md says "KLAAR OM TE MERGEN" (check after every point).
3. Roadmap in the user's order: park + agora (46 = 12-13), car dealer + driving (45 = 14), cover garage (52),
   territory per district (51), the remote prison + tutorial intro + late-join intro (49-50), the full village
   map (47), then the chapter 1 story missions (53). Meth/cocaine (48) is session B's for now.

## Te testen door Curry (F9 in the game, or --scenario=<name>)
- wanted_one: drawing the pistol near an officer does nothing any more; a shot = 1 star.
- wanted_timer: 3 stars at once; go through the Small House door behind you and stay out of sight 30 s -> all
  stars go at once, the extra police cars drive off.
- wanted_three / wanted_hide: the new search timer (30 s / ~7 s at home), all stars at once.
- police_vs_crows: 23:00 on South Street, just watch: a Crow and an officer shoot it out, the patrol car crew
  joins; no stars for you.
- (from before, still untested by you) trash, launder, grow (work animations + mouse wheel), sleep, bookshelf.

## Known
- The "activities" pedestrian check is random and fails now and then.
- `--only=npc_combat` needs `pedestrians` in the same run (it uses the pedestrians that check spawns).
- Netcheck: after the respawn the client's 5 m crouch walk bumps into the host (both stand at the hospital spawn);
  harmless, it has always been like that.
