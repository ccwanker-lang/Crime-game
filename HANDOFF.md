# HANDOFF (2026-11-14, session A)

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
- Point 46 (park + agora) built + committed: targeted check `park` passes, netcheck passes (client sees dog
  walkers with dogs, smokers, the ball at the same spot).
- Feature-b (ranks + staff) merged; full self-test on the merge found: park lamps 0.12 m in the air (fixed) and
  random agora matches adding 4 NPCs to other checks (fixed: no random matches in --selftest/--netcheck).
- Point 45 (car dealer + driving) built: Carlo's Cars on the lot east of the side road (x 36-58, z 50-63),
  `PlayerCar` + `Vehicles` + `CarDealer`. Check `vehicles` passes, netcheck: the client drives, the host sees it.
  Full self-test on the point-45 commit: see the line below (update it when it is done).

- 2026-11-14: point 52 (cover garage) was uncommitted after the hard shutdown; finished (scenario cover_garage,
  car_parts icon) and committed (e8aa5a6). Full self-test on it: ALL PASSED (502). Netcheck 7794: both exit 0
  (the first two runs had the client too late while the self-test ran alongside - rerun fixed it).
- Asked B (A.md) to move StaffConfig "south" anchor to the pavement (z 55.4): it now snaps into the garage.
- feature-b NOT yet "KLAAR OM TE MERGEN" (B works on raids, uncommitted in game-b).

- Point 51 (territory) committed (50f96a7): targeted checks + netcheck pass; full self-test: see below.

## Next steps (in order, user 2026-11-13)
1. Full self-test + netcheck on main; fix failures.
2. Merge feature-b as soon as B.md says "KLAAR OM TE MERGEN" (check after every point).
3. Roadmap in the user's order: park + agora (46 = 12-13) DONE, car dealer + driving (45 = 14) DONE, cover garage (52) DONE,
   territory per district (51) DONE, the remote prison + tutorial intro + late-join intro (49-50), the full village
   map (47), then the chapter 1 story missions (53). Meth/cocaine (48) is session B's for now.

## Te testen door Curry (F9 in the game, or --scenario=<name>)
- wanted_one: drawing the pistol near an officer does nothing any more; a shot = 1 star.
- wanted_timer: 3 stars at once; go through the Small House door behind you and stay out of sight 30 s -> all
  stars go at once, the extra police cars drive off.
- wanted_three / wanted_hide: the new search timer (30 s / ~7 s at home), all stars at once.
- police_vs_crows: 23:00 on South Street, just watch: a Crow and an officer shoot it out, the patrol car crew
  joins; no stars for you.
- park: 15:00 at the park entrance: paths, benches, dog walkers with dogs, youths smoking in a circle.
- agora: 15:00 on the pitch, a 2-against-2 match; walk into the ball to kick it, GOAL! + score board.
- car_dealer: in Carlo's office with €20,000 clean: E on Carlo, buy a car, it waits on the lot outside.
- turf_take: phone (Tab) > Turf, then E on the customer > Confirm deal -> "Old Town is yours now", Turf turns green.
- turf_danger: sell to the customer -> "Told you. Look behind you." + a Crow runs at you by day; shoot it, check Turf.
- cover_garage: E on the car on the lift (4x) -> +€260 clean; E on the tool shelf at the back -> hidden room.
- driving: next to your own Comet Sedan (+ a Mule Van): F in, WASD, Space handbrake, H horn, mouse looks around,
  F out. With 2 instances the second player presses F at the same car = passenger.
- (from before, still untested by you) trash, launder, grow (work animations + mouse wheel), sleep, bookshelf.

## Known
- The "activities" pedestrian check is random and fails now and then.
- `--only=npc_combat` needs `pedestrians` in the same run (it uses the pedestrians that check spawns).
- Push: the user made github.com/ccwanker-lang/Crime-game (PUBLIC). Setting origin + pushing was blocked by the
  permission classifier on 2026-11-14; the user runs `git remote set-url origin https://github.com/ccwanker-lang/Crime-game.git`
  + pushed main themselves. From now on A runs `git push origin main` after every commit; B pushes feature-b.
- Netcheck: after the respawn the client's 5 m crouch walk bumps into the host (both stand at the hospital spawn);
  harmless, it has always been like that.
