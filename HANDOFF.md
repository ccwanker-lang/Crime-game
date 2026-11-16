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

- 2026-11-14 (after the restart): feature-b merged (e787b69, B's meth/cocaine/courier/lawyer/bribes/raids/
  roadside). Point 49 (prison intro, 8dec644) and point 50 (late-join intro, 893985f) committed; targeted check
  `intro` + scenarios pass, a 2-process late-join run works (client gets its step box). Full self-test on the merge:
  see the end of this file when done. Round 4 + admin mode were already built (5da614a, c566f9c).

- 2026-11-14: rest of point 48 (fuel + QuickFuel gas station on North Road, 191fede): check `fuel` + `vehicles` and
  scenario gas_station pass. The old full self-test on the merge hung in the traffic check under CPU load (B was
  running its own self-test at the same time); a fresh full run on 191fede follows (result below when done).

- 2026-11-14: point 47a (west side: Industrial Road, metalworks, container yard, Lab Warehouse, Quay Road, harbour
  with Harbour Storage, crane, ship, sea). Full self-test on it: 604 PASS, 2 FAIL in police_life (officer never
  reached the passer-by) while B's self-test ran at the same time; police_life alone and with the checks before it
  passes - a diagnostic print ("police_life before question: ...") stays in for the next full run.
- 2026-11-14: point 47b (countryside: Country Lane x -150, Hollow Farm with the Barn for sale, fields). Next: 47c
  (west districts + Crows at the harbour; needs B's StaffConfig district + rank gates, asked in A.md), then 53. Full self-test on 47b: 606 PASS, 2 FAIL (selling: officer as customer; traffic: test spot moved by 47a) - both fixed in the test and pass. Netcheck passes after the join fixes.

- 2026-11-14: feature-b merged up to d2d7b72 (bb9810c: dealer turf, bulk deals, roadside jerrycan). Full self-test on
  the merge: 618 PASS, ALL PASSED; netcheck OK. B's 9bf3ea2 (product quality) is NOT merged yet (not released in B.md).

- 2026-11-14: point 47c (Crows' private pier at the harbour). Checks harbour + rivals pass; scenario OK.
  Next: feedback round 5 = Roadmap 56-68 (bugs 56-59 first, then 60-68 in order), THEN 53-55.

## Next steps (in order, user 2026-11-13)
1. Full self-test + netcheck on main; fix failures.
2. Merge feature-b as soon as B.md says "KLAAR OM TE MERGEN" (check after every point).
3. Roadmap in the user's order: park + agora (46 = 12-13) DONE, car dealer + driving (45 = 14) DONE, cover garage (52) DONE,
   territory per district (51) DONE, the remote prison + tutorial intro + late-join intro (49-50) DONE, fuel station (rest of 48) DONE, the full village
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
- prison_intro: a new game's start in the cell (walk to the door, Marco, desk, bus; F2 skips).
- late_join: the short intro of a friend who joins later (door open, desk, bus).
- meth_market / meth_lab / meth_cook / meth_dealer / meth_customer, coke_lab / coke_staff, courier, bribe,
  raid_live / raid_guards, roadside: session B's milestone-3 work, now in main.
- west_side: on Main Road past the tree belt with your car: drive down Industrial Road to the harbour; enter the Lab
  Warehouse and the Harbour Storage (both for sale); try to fall into the sea (you can't); phone map shows the area.
- countryside: Hollow Farm: enter the red barn (for sale), walk down Country Lane between the fields.
- bulk_deal (B): 30 bags of meth on you, the Dutchman (yellow name) next to you: E = everything sold at once.
- harbour_crows: on Quay Road by the PRIVATE PIER fence: the Crows leave you alone on the road, shoot on the pier.
- west_side / countryside: see above.
- gas_station: QuickFuel on North Road, your Comet Sedan almost empty next to pump 1: sit in it (F) -> fuel 6%,
  get out, E on the red pump -> full, €86 gone. The Mule Van at pump 2 is empty: W does nothing.
- turf_take: phone (Tab) > Turf, then E on the customer > Confirm deal -> "Old Town is yours now", Turf turns green.
- turf_danger: sell to the customer -> "Told you. Look behind you." + a Crow runs at you by day; shoot it, check Turf.
- cover_garage: E on the car on the lift (4x) -> +€260 clean; E on the tool shelf at the back -> hidden room.
- driving: next to your own Comet Sedan (+ a Mule Van): F in, WASD, Space handbrake, H horn, mouse looks around,
  F out. With 2 instances the second player presses F at the same car = passenger.
- open_border: walk/drive north-west through the fields to the farm and the hedge; F10 + Ctrl under the ground, F10 off -> back.
- no_kneel: E on pots/rack/table (V = third person): no kneeling, an effect at the object; B: place/pick up the sofa = poof.
- traffic_lights: watch the lights on Main Road; cars wait behind the broken-down car, then overtake it.
- grass: walk/drive around the open field: grass everywhere it is green, none on roads/paths/fields.
- harbour_road: drive west along South Street past the old barriers: it bends down to the harbour / Quay Road.
- police_vs_crows: they fight at most 2 minutes, then break off (the Crow walks home).
- (from before, still untested by you) trash, launder, grow (work animations + mouse wheel), sleep, bookshelf.

## Known
- The "activities" pedestrian check is random and fails now and then.
- `--only=npc_combat` needs `pedestrians` in the same run (it uses the pedestrians that check spawns).
- Push: the user made github.com/ccwanker-lang/Crime-game (PUBLIC). Setting origin + pushing was blocked by the
  permission classifier on 2026-11-14; the user runs `git remote set-url origin https://github.com/ccwanker-lang/Crime-game.git`
  + pushed main themselves. From now on A runs `git push origin main` after every commit; B pushes feature-b.
- Netcheck: after the respawn the client's 5 m crouch walk bumps into the host (both stand at the hospital spawn);
  harmless, it has always been like that.

- 2026-11-15: point 49b (mountain pass + prison behind it, real bus ride) done: checks intro, pass, traffic, ground,
  lights, vehicles, fuel, kerb PASS; netcheck 7794 both exit 0; scenarios mountain_pass + prison_intro OK.
- NEXT: the user's new map blueprint (9 zones, DESIGN "Map layout"). The blueprint IMAGE did not come through
  (only the text) - asked the user to save it in the repo (e.g. docs/map_blueprint.png). Point 62 is folded into it.
- 2026-11-15: map blueprint point 69 (rough layout) DONE: zones 9 (border mountains), 7 (city + highway), 3 (slums),
  2 (army base), 8 (bunker side road + portal) each committed + pushed with scenario, self-test check and shots.
  NEXT: point 70 = detail per zone (4-lane highway, city NPCs/navmesh/shops/syndicate tower, base guards, bunker
  inside + buyable lab, slum life); merge feature-b when B.md says done.

- 2026-11-15: points 71-74 done (71 = Southfield + Orchard Lane neighbourhoods, 72 lower city, 73 mountains one
  style, 74 bunker complex). New user feedback round = Roadmap 75-85 (DESIGN), worked in that order.
- 2026-11-15: points 75-84 committed (c3838b9, 112fd4a). feature-b parts 18-22 MERGED (zones, missions, dialogue,
  city/army life) + the flaky "sent Crow" check fixed in `Territory.spot_near` (short walking path). Point 85
  (airfield) done. All of feedback round 75-85 is DONE. NEXT: wait for user feedback / B.md; B was asked (A.md) to
  widen Zones.ARMY_RECT to the new base.
  Full self-test on the merge + Crow fix: 815 PASS, ALL PASSED; after point 85: checks army, airfield, ground, zones,
  pass, bunker, grass, lamps PASS; netcheck 7794 both exit 0.
- 2026-11-15: self-test counts SCRIPT ERRORs per check as FAIL (ScriptErrorCounter); real_estate copes with the bunker
  (no Building). Full self-test on main with point 85: 836 PASS, ALL PASSED, no script errors; netcheck 7794 both exit 0.
- 2026-11-16: playtest feedback round = Roadmap 86-97 (DESIGN). DONE: 86 (perf probe + F3 PerfOverlay), 87 (NpcStreamer:
  NPCs sleep > 300 m, MID AI, cap, pins; Car.far), 90 part 1 (WorldLod: draw distances, light fade, occluders, sun
  shadows 90 m), 91 (jets every ~4 min, sound only near the base / muffled behind rock), 92 (bunker lift moved, rooms
  furnished, walk test from stairs + garage), 94 (tyre screech only on a real skid). FPS before -> after (1920x1080,
  vsync off): docks 14-23 -> 84, city 21-27 -> 96 (125 steady), village 27 -> 76, army base 71 -> 142.
  NEXT in order: 88 (day rhythm), 89 (npc_bench), 90 part 2 (chunks / interiors / MultiMesh), 93 (prison complex),
  96 (3 gas stations); 95 DONE (grass_roads). B part 23 (ARMY_RECT) merged locally with this push.
