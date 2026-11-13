# DESIGN.md — Game design (source of truth)

Read this file before starting any milestone. Do not build features from later milestones early,
but keep code compatible with everything described here.

## Concept
Co-op crime/shooter inspired by Schedule I (economy, production, NPC selling) + Counter-Strike-style gunplay.
Fictional Belgian/European town, currency euro (€). Game language: English. Art: see "Art direction".

## Tech decisions
- Godot 4.x (standard, GDScript, static typing), Forward+.
- Host-client co-op, ENet, port 7777, max 4 players, host authoritative.
- Host owns: world, savegame, properties, labs, rank, story, staff, dealers, territory.
- Every player owns: own cash + carried inventory (saved on host per player name).
- Camera: first-person with toggle to third-person (V).
- PC only; local testing first, Steam later.
- Git + Git LFS.

## Core rules
- ALL buying/selling happens via NPCs. Customers can rip you off (steal part or all).
- Legal items: bought via the webshop on the in-game phone, delivered to your property.
- Illegal items (seeds, chemicals, weapons, workers): ONLY physically, at NPCs / black market.
  Production stations (grow pot, grow lamp, drying rack, packaging table) are illegal items too: they are sold
  ONLY at the black market (see Buildings) and placed by the player in properties they own.
- Money: every player has dirty cash (sales, loot) and clean money (laundered through front businesses).
  Both are tracked separately in the code from milestone 2 on; for now both can be spent everywhere.
- In-game phone: Telegram-style chat app (own name) for customers/dealers, webshop, map,
  calling the roadside service team.
- Death: drop a loot bag with cash + carried items, respawn at the hospital. Anyone (incl. rivals)
  can take the bag.

## Products (abstract game mechanics, no realistic procedures)
| Product | Unlock | Flow | Stations |
|---|---|---|---|
| Weed | Rank 0 | Seeds → plant → water/soil → harvest → dry | Pot, grow lamp, drying rack |
| Meth | Rank 2 | Buy raw materials → cook in steps → cool → break | Cooking station, cooling plate |
| Cocaine | Rank 4 | Grow coca plants → process leaves → refine | Grow bed, processing machine, refinery |

For all products: mixing (supermarket ingredients add effects → custom variants, higher price),
quality (better seeds/machines → better customers), packaging (baggies small, bricks bulk),
selling (yourself, via dealers, or bulk at the harbor).

## Staff (automation)
| Worker | Does | Unlock |
|---|---|---|
| Grower | Waters and harvests plants | Rank 1 |
| Cook | Operates machines | Rank 2 |
| Packager | Packages product | Rank 2 |
| Courier | Fetches supplies, delivers to dealers | Rank 3 |
Workers cost a daily wage and need a bed/locker in the property. Bigger property = more stations + staff.
Dealers: hired in the bar, assigned to a district, take a commission, can be arrested or betray you.

## Progression
| Rank | Property | District | Unlocks |
|---|---|---|---|
| 0 Street Hustler | Starter room | Old Town | Basic setup, sell yourself, phone, weed |
| 1 Hustler | Garage property | West side | First car, gas station, 1 dealer, grower |
| 2 Dealer | Barn | Countryside | Meth, cook/packager, better equipment, shooting range |
| 3 Plug | Lab warehouse | Industrial | Real estate agent + front businesses, couriers, black market |
| 4 Boss | Harbor storage | Harbor | Cocaine, bulk deals, guards, lawyer, rivals raid you |
| 5 Kingpin | Villa | Hillside | Bribe police, more dealers, roadside service team |
| 6 Godfather | Mountain cabin | Whole city | Attack rival HQ, highway to region 2 |
XP from sales, deals and fights.

## Rivals & story
Rival gang: "The Black Crows", leader Viktor Kraal. They control the city, harbor and a corrupt cop.
- Killing rivals: they drop cash, product, sometimes weapons or stash keys.
- Lab raids: rivals steal stock/machines unless guards or players defend.
- Territory: each district has an influence meter (sales + won fights push it to the player).
Acts:
1. New in town (rank 0–1): selling weed in Old Town, Crows warn you.
2. First blood (rank 2): Crows raid your barn; you learn they pay a cop.
3. Street war (rank 3–4): take districts one by one, move to Industrial, steal harbor shipments.
4. The traitor (rank 5): a Crows lieutenant wants to defect; trust him or not → different missions.
5. The HQ (rank 6): final assault, defeat Viktor and spare him.
Milestone 2 (test town): the Crows have a house. At night some of them come out, walk the streets and
attack players. Inside a player's own property you are safe (they don't come in). Killed rivals drop loot.
Ending: the Crows work for the player (dealers/guards), Viktor runs the harbor. Highway to region 2
opens with a new rival.

## Art direction
**Style: low-poly but detailed and grounded — NOT Roblox-like, not toy-like, not cartoon-bright.**
A believable Belgian/European town at human scale (1 unit = 1 m, people ~1.75 m).
- Architecture: Belgian row houses (brick in red/yellow/white, plaster, bluestone plinths, sills,
  string courses, dormers, bay windows), narrow plots, shops with awnings, cobbled squares,
  raised sidewalks with curbs, zebra crossings, cast-iron street lamps, street-name signs.
- Materials: PBR (albedo/normal/roughness) from CC0 sources, slightly desaturated, real-world scale.
  Lighting: HDRI sky, sun with shadows, SSAO + SSIL (no SDFGI: it smears dark blocks on moving
  characters), light fog for depth.
- Everything visual is a reusable prefab in `res://prefabs/` (procedural @tool scripts or imported
  models); lamps always come with their pole/mount in one prefab.
- People: Quaternius CC0 animated characters with realistic proportions (no chibi/big-head
  packs), matte materials, random clothing colours. One prefab base (`prefabs/npc/pedestrian.tscn`)
  for pedestrians, customers, dealers, police and rivals.
- Asset sources, in this order: (1) CC0 — Quaternius, Poly Haven, ambientCG, Kenney (only packs that
  fit the grounded style); (2) Sketchfab CC-BY, credits kept in `CREDITS.md`; (3) if nothing is good
  enough, propose a paid pack (e.g. Synty POLYGON) with its price and let the user decide.
  Every asset folder keeps a LICENSE.txt; every non-CC0 asset is listed in `CREDITS.md`.

### Weapons (from milestone step 4)
- Realistic low-poly firearms: pistol, SMG, shotgun, rifle. PBR textures with metal, wear and
  scratches. **No toy or sci-fi blasters** (so not the Kenney Blaster Kit).
- Sources: CC0 first (Quaternius, Poly Haven); otherwise Sketchfab CC-BY with credits in
  `CREDITS.md`. If nothing is good enough: propose a paid pack (e.g. Synty POLYGON Military /
  Gang Warfare, roughly US$ 40–100 per pack, check the current price) before buying anything.
- First person: viewmodel with arms/hands; animations for shoot, reload and weapon switch;
  recoil (camera kick + viewmodel kick), muzzle flash, ejected shell casings, impact effects
  (decals + particles per surface) and sound (shot, reload, casing, impact).
- Third person / other players: the same weapon held in the character model's hand (bone
  attachment), with matching shoot/reload animations.

## Properties & furnishing (milestone 2)
- Properties are bought at the real estate agent (NPC in an office). Several at once is fine. Each has a price
  and a furnishing area (the interior floors). Upgrade path: Starter Room -> 2-floor apartment/house ->
  full house -> warehouse (big labs). The Starter Room is the free first property.
- Furnishing: stations are inventory items. Select one in the hotbar -> placement mode: ghost preview (green =
  can place, red = can't), snaps to the floor on a 0.25 m grid, R/scroll rotates, LMB places. E on a placed
  station's "pick up" action puts it back in the inventory (contents must be empty). Placing only works inside
  properties owned by the crew. New saves start with an empty Starter Room.
- Everything a player owns (properties, placed furniture/stations, cars, businesses) is in the savegame.

## Money laundering (milestone 2)
- Front businesses (bakery, barber, laundromat) are bought at the real estate agent.
- Deposit dirty cash in a business (E at its counter). Each in-game day it turns up to its daily maximum into
  clean money for the owner, minus a small fee (e.g. 10%).

## Police and the wanted level
- Police station; patrol cars with a crew of 2 who get out for a call and never leave their car behind
  (point 25); foot patrols and police life on the street come back with point 30.
- Wanted level (point 28, replaces "heat"): 1-5 stars per player, GTA style (see Roadmap 28). Low stars = an
  arrest (illegal items + fine, released at the station), higher stars = chases and shooting, 4-5 = the whole
  force with road blocks. Stars drop out of sight / inside your own property / with a bribe (rank 5).
- Later: the corrupt cop from the story.

## Vehicles (milestone 2)
- AI traffic: procedural cars on smooth right-hand routes (curves). Gunfire: drivers stay in and flee in
  panic (U-turn or speed off, point 24; full panic through junctions with point 32); wrecks are towed.
- Car dealer (building + NPC): buy cars. Your own cars: F to get in/out, WASD drives (VehicleBody3D), chase
  camera; other players can ride along as passengers. Saved in the savegame, they spawn at your property.

## Buildings / services
Starter room, garage property, barn, lab warehouse, harbor containers/storage, villa, mountain cabin,
supermarket, hardware store, gas station, car garage (buy/sell/repair cars), roadside service depot
(tow truck team drives to the player), real estate agent (buy properties + front businesses), front
businesses (bakery, barber, laundromat; later car wash, restaurant), bank, police station, hospital, lawyer's
office, gun shop, black market, shooting range, bar (hire dealers), club, motel, town hall, rival HQ,
dealer hangouts per district, customer houses, car dealer.
- Black market: inside the garage, behind a fence. Open only at night (gate locked during the day). Sells
  stations and illegal goods (seeds, baggies...).
- Test town additions (milestone 2): police station, real estate agent, car dealer, the garage with the black
  market, three front businesses, the Black Crows' house, a small park behind the benches on the square at
  Mill Lane / Main Street (paths, grass, trees, benches, dog walkers, people sitting, youths smoking weed) and
  an "agora" (fenced mini football pitch with goals, sometimes NPCs playing).

## Map layout (for milestone 4 — greybox first)
Top-down, north = up. Organic town, NOT a square grid; compact dense center.
- Water: sea/bay along the south-west and south; a river flows from the northern hills
  southwards, curving south-west into the bay. It splits Old Town (west) from Downtown (east).
  2–3 bridges.
- Downtown (center, east of river): dense grid of ~4x4 blocks with many buildings.
  Town hall on a small square, police station, bank, supermarket, gun shop, hardware store,
  bar, club. Main avenue runs north-south through downtown; a main east-west road crosses
  the whole map over a bridge.
- Old Town (north-west, west of river): curved streets, cheap houses, the player's starter room.
- Countryside (far north-west): farm fields, the barn.
- Industrial (south-west, west of river): large warehouses, factory, lab warehouse, black market.
- Harbor (south-west coast/bay): piers, stacked containers, harbor storage, rival presence.
- South (below downtown): car garage, gas station, motel, shooting range, park with a pond,
  roadside service depot.
- East side / Hillside (east of downtown, on a hill): curvy streets, suburbs with houses, villa,
  hospital near downtown.
- Northern hills: forested hills/mountains with a winding serpentine road up to the mountain cabin.
- Highway: enters from the north-east edge and connects to the north end of the main avenue;
  later continues to region 2 (map edge = blocked for now).
- Rival HQ: in the harbor/industrial area.
Terrain should have real height differences (hills up, down to the river and harbor).

## Roadmap
First playable (co-op weed loop in a small test town):
1. Project setup, autoloads, main menu with host/join - done
2. Greybox test map with navigation - done
3. Networked player controller (first/third person) - done
4. Health, pistol, loot bag on death - done
5. Inventory and buying from NPC shopkeepers - done
6. Growing weed in the starter room (pots, grow light, drying rack) - done
7. Packaging + selling to street customers (rip-offs) - done
8. Phone: chat app, map, webshop with delivery - done
9. Save/load (host, autosave, continue/new game) - done
Extras done along the way: more weapons + gun shop, ragdolls, day/night, enterable houses, AI traffic.

Milestone 2 (feedback after playing milestone 1). Ranks don't exist yet: everything below is available from
the start for now; rank gates (see Progression) come later.
1. Smooth car curves (Curve3D routes, heading along the axles, steered front wheels, brake before / accelerate after bends) - done
2. Stairs work for players and NPCs (invisible ramp over each flight, furniture keeps the stair way free, walker climbs every stair + navmesh path to every top floor) - done
3. Cars react to gunfire and murders (speed up, honk, swerve; shot car flees; wreck towed + replaced) - done (drivers getting out: replaced by 24, panic reworked again in 32)
4. Item icons (renders of the 3D models) with counts in hotbar/inventory (asked again as E) - done
5. Held items visible in first and third person (seeds, watering can, soil, baggies...) - done
6. Furnishing: buy stations as items, place/rotate/pick up in your own properties; empty Starter Room - done
7. Black market in the garage, behind a fence, open only at night; sells stations + illegal goods - done
8. Real estate agent: buy properties (Starter Room -> 2-floor house -> full house -> warehouse) - done
9. Money laundering: bakery, barber, laundromat; dirty vs clean money - done
10. Police station + patrolling police reacting to gunfire and murder - done (since 25: patrol cars with a crew of 2, no foot patrols; reworked by 28 + 30)
11. Black Crows house: rivals roam at night, attack players, drop loot, never enter your property - done (reworked by 31)
12. Park on the square (paths, trees, benches, dog walkers with dogs, sitters, youths smoking) - todo
13. Agora: fenced mini football pitch, NPCs playing sometimes - todo
14. Car dealer: buy cars, drive them (F in/out, WASD, chase cam, passengers), saved - todo
Added after playing (A-F; E = point 4, C extends point 6):
15. (A) Railings round every stairwell opening, also on the top floor where no next flight starts - done
16. (B) Every house is furnished by the interior generator (no empty houses): dining corner, nightstands, wardrobes, study floors, footprint check - done
17. (C) Own properties: ALL furniture can be picked up, moved, rotated, sold or stored (placement system of point 6) - done
18. (D) Storage lockers: buy + place in a property, own inventory (put in / take out), several allowed, saved, shared in co-op - reopened as 20
19. (F) Balconies: a door (E opens) onto every balcony, walkable, solid railing without gaps (1.6 m collision wall) - done
Feedback round 2 (MUST first, then balance, traffic, police, map):
20. Storage that really works: locker/shelf with own slots, E opens inventory (left) + storage (right), click or drag
    to move, Shift+click = whole stack, host validates, saved + synced; a free locker in every Starter Room (old
    saves too); drop items (G / right click in the inventory) and pick them up again - done
21. Police balance: reaction time, big spread (more at range and when you move), pauses between bursts, lower
    damage; all values in a tunable resource (accuracy, reaction_time, damage, fire_rate) - done
22. Health regeneration: after ~8 s without damage HP slowly heals back to 100 (tunable) - done
23. Car horns: much quieter, shorter, less often, not all cars at once - done
24. Traffic and gunfire: drivers never get out any more; cars speed away from the shooting (turn round / other
    route), then go back to their normal route; no abandoned cars left on the street (replaces part of point 3) - done
25. Police and their car: officers get out to shoot or arrest, never leave the car behind, walk back and patrol on
    when it's over (dead / arrested / escaped). Arrest: a player who doesn't resist and is close gets cuffed
    instead of shot -> illegal items confiscated + fine, released at the police station - done
26. Spread the properties for sale over the map: at least a street apart, different neighbourhoods, not next to
    the police station; agent list + existing saves follow (owned property moves with its contents) - done
Test scenarios (F9 / --scenario=<id>, one per feature, real save never touched) - done
Feedback round 3 (after playing every scenario). APPROVED, don't change how they work: all weapons incl. the
sniper scope, growing/drying/packaging, the black market, storage. Order: 27 first, then 28-41, then 12-14.
27. Art style: ONE consistent style. Comparison scene scenes/art_test/style_compare.tscn (--scenario=style_compare)
    with 3 proposals side by side (A stylized low-poly flat/soft textures, B low-poly + PBR, C own proposal), each a
    piece of street with 3 houses, a car, an NPC and pistol + AK viewmodels; screenshots to the user. The real map
    is NOT changed until the user has chosen; then everything is pulled into that style - comparison: todo,
    conversion: waiting for the user's choice
28. Wanted system (GTA style, replaces the current police behaviour and "heat"): 1-5 stars in the HUD.
    1 star: weapon drawn in sight of police or 1-2 kills -> one officer comes to cuff you, doesn't shoot.
    2: killed an officer or ~6+ kills -> chase, shoot if you are armed. 3: ~12+ kills -> several cars, shoot at
    once. 4-5: the whole force, road blocks, heavy teams. Stars drop when you stay out of sight, hide in your own
    property, or (later) bribe. Police react BEFORE you holster. Thresholds/times in a resource - todo
29. Pedestrians and police may walk on the road (not only pavement/zebras); cars brake for them - todo
30. Police life: a patrol car sometimes stops (light bar) to question an NPC; officers also patrol on foot and talk
    to passers-by - todo
31. Black Crows rework: spread over their whole fenced yard (no single spawn point); they only attack on their
    turf or if a member saw you there (memory); new spawns that never saw you leave you alone outside. At night one
    small group patrols the streets (the night threat), the rest stays in the yard. The dead are replaced only
    after 1-2 minutes. Weapon variety (some carry an AK) - todo
32. Traffic + panic: cars that are shot at or hear shots flee in full panic and never stop (also not at a
    junction: right of way is dropped). Pedestrians flee until they are really away from you and out of sight - todo
33. Street lamps on both sides of every street (the barber's street has none); the kerb sometimes blocks you
    stepping up from the road onto the pavement: fix (step height / collision) - todo
34. Deals by phone: the customer sends a proposal (amount, price, place); accept, decline or counter-offer (the
    customer accepts or refuses depending on how far you go); only an accepted deal fixes the meeting. At the
    meeting a short conversation with "Confirm deal" instead of plain E. Fix the sell_weed scenario: right in front
    of a customer with a green € sign - todo
35. Own properties on the map: icon + name after buying, a name plate on the building; the estate agent shows
    where a property is on the map BEFORE you buy - todo
36. Build mode (B): only in build mode can furniture and stations be picked up, moved and rotated. Outside it E
    only uses things (plant, water, harvest, open a locker) (changes 6/17) - todo
37. Bed: sleep to skip the night (time jumps to the morning; in co-op all players sleep / vote) - todo
38. Bookcase = storage too, like the locker - todo
39. Trash: throw cardboard boxes and rubbish in a bin, put the bin outside, a garbage truck comes by and empties it - todo
40. Money: HUD shows dirty and clean money apart; depositing in a front business shows a message ("€5000 deposited
    -> €4500 clean tomorrow") and another one when the clean money comes in; a screen in the business with what
    is pending - todo
41. Mouse wheel scrolls through the hotbar (in build mode it rotates) - todo
Then the rest of milestone 2: 12 park, 13 agora, 14 car dealer + driving.
Then (milestone 3, in this order): ranks + XP + unlocks; staff + dealers; meth, then cocaine; lawyer, bribes
(heat = the wanted system of point 28); rival territories, lab raids, story missions (acts 1-5); the full city
(Map layout); roadside team, fuel station, garage.
Polish, later: animations for planting, watering, harvesting and packaging.

## Decisions
Choices made while working autonomously (what + why).
- Point 6 (corrected after point 7): production stations are illegal (core rules), so ONLY Rook's black market
  sells them (at night). The Store and QuickShip sell the storage locker and (QuickShip) all furniture: legal.
  A new game therefore starts with an empty Starter Room and the first night is the first chance to buy a pot.
- Point 6: hold E (0.6 s) picks a placed thing up, a short tap keeps the normal E action. Why: stations already
  use E; one key for both, and no accidental pickups.
- Point 6: big furniture only stands on the floor; small things (footprint up to 0.7 m: TV, plant, pots,
  register) may stand on table tops. Why: TVs on cabinets like the generated houses, no sofas on chairs.
- Point 17: furniture is "adopted" (becomes placed objects) the moment a property is owned; the Starter Room's
  furniture is adopted in every new game. Old saves: their Starter Room stations become placed stations at the
  same spots with the same state. Why: one system for everything that can be moved.
- Point 17: selling furniture/stations happens in the phone app "Resell" for 50% of the price (pick it up first).
  Why: works anywhere, no extra NPC needed; storing = keep it in your pockets or put it in a storage locker.
- Point 18: a storage locker holds 16 stacks and is shared by the whole crew (like all owned things in co-op).
- Point 7: the garage stands on the side street (x 30, south); "night" = while the street lights are on
  (DayNight.is_night, about 20:15-07:00), so the market follows the lamps players see. The gate always opens
  from the market side (nobody gets locked in) and closes by itself at dawn. Rook sells 10% below the store
  price: seeds, baggies and all current stations; meth/cocaine supplies are added there in milestone 3.
- Point 8: the test town got "South Street" (z 60, branching west off the south road, dead end at x -60) for
  the milestone 2 buildings; traffic route 3 now drives it (U-turn at the dead end). For sale at Mrs. Vos:
  Small House (2 floors, €8,000), Family House (3 floors, €20,000), Warehouse (16x12 m, €45,000). Prices are
  a few days of weed sales apart. Bought by the crew (co-op shares everything); the buyer pays.
- Point 9 (laundering): all income is dirty cash; laundered money is "clean" (a bank balance). Paying takes
  from both (DESIGN: both can be spent everywhere for now), but legal purchases (webshop, real estate, legal
  shop items) use clean money first and illegal ones dirty cash first. On death only the dirty cash goes into
  the loot bag: clean money is in the bank. That is the reason to launder until heat/police checks arrive.
- Point 9: each front business has a back-office safe (LaunderSafe). E (crew must own the business) puts your
  dirty cash in, up to 2 days of turnover. The daily maximum is booked evenly over the in-game day (not all at
  midnight: steady feedback), paid out per €100 as €90 clean to whoever deposited it, first in first out.
  Bakery €12,000 / €1,500 a day (the old bakery on the main road), Barber Shop €20,000 / €2,500, Laundromat
  €35,000 / €4,000 (both on South Street). Their furniture is adopted like a house's (movable, sellable).
- Point 10 (police): station on South Street; 2 officers on foot patrol within 45 m of it, 1 patrol car on
  traffic route 3. Any shot a player fires is a crime heard within 45 m, a kill within 70 m (no heat/witness
  logic yet: that is the heat system in milestone 3). The officer runs there, and when it sees the shooter
  (32 m, line of sight) it stops and fires (12 damage, ~0.75 s, some spread) until the culprit is dead or out
  of sight for 25 s. Shooting an officer makes you its target. The patrol car stops with its light bar on and
  the officer gets out; afterwards it gets back in. Dead officers come back at the station after 60 s.
  Officers don't flee and don't drop loot.
- Point 20: the storage window is two slot grids (8 pockets, 16 locker). Plain click moves ONE item, Shift+click
  or dragging moves the whole stack, right click on a pocket slot drops it. G drops the selected hotbar stack
  (Shift+G one item). A dropped item is a LootBag that shows the item's own model ("Pick up 2x Soil"), saved
  like loot bags; anybody can pick it up. The free locker (LockerSpot, against the Starter Room's left wall) is
  placed once per world (flag world["free_locker"]), so old saves get it too.
- Point 21: police combat values live in `data/npc/police_combat.tres` (NpcCombatProfile, reused for rivals):
  accuracy 0.55, reaction 1.2 s (again after losing sight), 7 damage, bursts of 2-4 at 2 shots/s, 1.8 s pause.
  The cone grows 0.004 rad per metre and up to +0.09 rad against a running target (~20% hits at 12 m standing).
- Points 23/24: horns are -12 dB with a short range, cut to 0.45 s (startled) / 0.2 s (impatient), only 35% of
  the time and never two within 1.8 s in the whole town. Gunfire: nobody gets out any more. A shot ahead within
  30 m -> the car turns round (2.2 s left-hand U-turn onto the nearest opposite lane of any route that heads
  away, Traffic.find_escape) and speeds off; otherwise it just speeds off. A hit car does the same. Only a wreck
  stops; it is towed after 20 s and replaced. After the panic the car follows whatever route it is on now.
- Point 22: health regenerates 4 HP/s after 8 s without damage (Player exports regen_delay/regen_per_second).
- Point 25: no foot patrols by default any more (`--police=N` still adds them): all police come from 2 patrol
  cars with a crew of 2. A crime within hearing range stops the car (siren), both officers get out and go after the
  culprit, but never further than 60 m from their car. When nobody of the crew has a target any more they walk
  back to the doors, get in and the car patrols on; a crew that is all dead -> the car is towed after 20 s.
  Resisting = shot at the police, fired in the last 3 s, running off (> 4.6 m/s), or weapon still drawn 2.5 s
  after "Put your weapon away!". Otherwise the officer walks up and cuffs (2 s within 2.6 m, only with the weapon
  away). Arrest: loaded rounds go back into the pockets, then every illegal item is confiscated (weapons, ammo,
  drugs, production gear), fine = 10% of all money (min €200, max €5000, never more than you have, clean money
  first), full health, released at the station's ReleaseSpot. Why: being caught should hurt but not end a run,
  and weapons are illegal items anyway. Officers are never drug customers.
- Point 26: properties per neighbourhood - Laundromat: West End (main road north, x -60); Small House: Old Town on
  the square (south side of the main road, x -20); Barber: North Road behind the hospital (x 0); Family House: East
  End at the top road (x 65); Bakery: shop row (main road east); Warehouse: South Street west end (40+ m from the
  police). South Street is now ordinary row houses + the agent + the police station. Old saves (World.migrate_layout,
  world["layout"] 1 -> 2): placed things, loot bags and saved player positions inside a moved building's old
  footprint move along with the same offset/rotation, so an owned property keeps its contents.
- Point 11: the Black Crows' house is a dark corner house in their fenced yard (Rival Turf), front to the gate.
  At night up to 3 Crows (`--rivals=N`) come out one by one (every 5 s) and roam the whole town (75 m around the
  house). They attack any player they see within 22 m - no warning, no arrest - with their own weak profile
  (`data/npc/rival_combat.tres`: 8 damage, bursts of 2, 1 s reaction). A player inside a crew-owned property is
  safe: they never pick or follow you there. Killed Crows drop a bag with €40-220 dirty cash, 50% 1-3 weed bags,
  35% 9mm rounds, 10% a pistol; they don't respawn by themselves, the night loop sends new ones. At daybreak they
  walk home and disappear. The first Crow of each night sends everyone a warning text. Police and Crows ignore
  each other for now (the corrupt-cop story comes in milestone 3). Rival = PoliceOfficer subclass (same armed
  brain), so balance changes to one apply to both.
- Test scenarios (user request, after point 11): F9 menu / `--scenario=<id>` (scripts/debug/scenarios.gd). A scenario
  restarts the host into a fresh game on a separate file (user://scenario_test.json) after saving the real game once,
  so real progress can never be changed by a test. Co-op clients are disconnected by it (it is a solo check tool).
  One scenario per feature; every manual check asked of the user gets one first (rule in CLAUDE.md).
- Feedback round 3: "approved" (weapons incl. sniper scope, growing/drying/packaging, black market, storage) means
  their mechanics, feel and UI stay as they are. The art style conversion (point 27) may still change how their
  models look, so everything matches the chosen style. Point 25's arrest stays: it becomes the 1-star response of
  the wanted system (28). Point 41 + 36 together: the mouse wheel scrolls the hotbar, and rotates only in build mode.

## Known issues / later
- Bullet decals on a car stay where it was hit when the car drives on (decals are not parented to the car).
- NPCs walk through each other: NavigationAgent avoidance is off because RVO pushed them into
  walls. Turn avoidance back on (and tune it) in milestone 4, with the big city map.
- Players and NPCs pass through each other (NPCs walking into players used to shove them metres
  away). Make them collide again together with the avoidance work in milestone 4.
- Weapons + ammo are inventory items, sold by Vince in the gun shop (temporary spot in the shop row).
  Every new player and every respawn gets a free loaded service pistol + 24 rounds (until earning money
  works); later this should go. F6 = debug +€1000 to test buying.
- Pedestrians die (ragdoll) and respawn after 60 s (corpse 20 s); no police/witnesses yet.
  Shopkeepers can't be shot. Ragdolls are cosmetic and local per peer (bodies may lie slightly
  differently on each screen).
- Aiming down sights with the long guns: the left (sleeve) arm still crosses the lower left of the view.
- No lag compensation: the host hits what it sees (fine on LAN).
- First-person hands wear dark gloves; the third-person body shows bare hands.
- The pedestrian self-test "activities" check is random and fails now and then (nobody sat/visited).
- Houses: every floor walkable with an open-step stairwell along the left wall and simple procedural
  furniture (living room / bedrooms, shop shelves, warehouse storage). Rooms are open plan (no inner walls
  or doors yet); the starter room, store, hospital and gun shop are ground floor only. Private houses are
  not on the NPC navmesh (only public buildings are visited).
- AI traffic: 8 procedural cars (sedan/hatchback/van, random paint) drive fixed right-hand routes
  (`Traffic` routes, U-turns before the map-edge barriers). They brake for cars, pedestrians and players
  in their lane and take junctions one car at a time (no traffic lights yet). Cars can't be entered,
  damaged or hit people yet (they just stop); later: player cars, car garage, collisions.
- Step 7 (packaging + selling): the packaging table in the starter room turns 1 Dried Weed + 1 Baggie into
  1 Bag of Weed. Every ~35 s a random pedestrian becomes a customer (max 2, "€" over the head, gives up
  after 5 min) wanting 1-3 bags at ~€51-78 each; E sells. Outcomes (host roll): fair 73%, pays short
  (35-70%) 15%, runs off with the bags 12% (kill it -> loot bag with the bags). Customers find you on the
  street for now; the phone (step 8) adds messages and meet points.
- Step 8 (phone, Tab): own chat app "Hush" (customers text name, bags, price and where they are; "On my
  way" makes them wait 3 more minutes, "Not now" sends them off), a map centred on you (roads, buildings,
  shops, players, customers) and QuickShip, the webshop for legal items (soil, watering can) delivered to
  the delivery box in the Starter Room after 1 in-game hour. Messages live on each client (not saved yet).
  Later: dealer contacts, calling the roadside service team, more apps.
- Step 9 (save/load): host only, `user://savegame.json` (+ `.bak`), autosave every 2 min and on Leave/quit.
  Saves cash/inventory per player name, their position/health/loaded magazines, station states (plants,
  rack, delivery box), time of day and loot bags. Not saved: NPCs, customers, phone messages, cars.
  Main menu: "Host - continue" / "Host - new game" (the old save stays as backup until the next save).
