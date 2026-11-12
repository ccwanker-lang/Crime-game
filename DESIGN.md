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

## Police (basic, milestone 2) and heat (later)
- Police station with officers who patrol on foot or in a police car.
- Basic reaction: an officer who sees a murder or hears gunshots nearby comes to look and shoots the culprit.
- Later: heat/wanted level per player (rises with crimes seen, decays over time), searches, arrests, bribes
  (rank 5), the corrupt cop from the story.

## Vehicles (milestone 2)
- AI traffic: procedural cars on smooth right-hand routes (curves), react to gunfire (speed up, honk,
  swerve or stop and the driver flees on foot); a car that is shot stops.
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
3. Cars react to gunfire and murders (speed up, honk, swerve or stop + driver flees and comes back; shot car stops, wreck towed + replaced) - done
4. Item icons (renders of the 3D models) with counts in hotbar/inventory (asked again as E) - done
5. Held items visible in first and third person (seeds, watering can, soil, baggies...) - todo
6. Furnishing: buy stations as items, place/rotate/pick up in your own properties; empty Starter Room - todo
7. Black market in the garage, behind a fence, open only at night; sells stations + illegal goods - todo
8. Real estate agent: buy properties (Starter Room -> 2-floor house -> full house -> warehouse) - todo
9. Money laundering: bakery, barber, laundromat; dirty vs clean money - todo
10. Police station + patrolling police (foot / car) reacting to gunfire and murder - todo
11. Black Crows house: rivals roam at night, attack players, drop loot, never enter your property - todo
12. Park on the square (paths, trees, benches, dog walkers with dogs, sitters, youths smoking) - todo
13. Agora: fenced mini football pitch, NPCs playing sometimes - todo
14. Car dealer: buy cars, drive them (F in/out, WASD, chase cam, passengers), saved - todo
Added after playing (A-F; E = point 4, C extends point 6):
15. (A) Railings round every stairwell opening, also on the top floor where no next flight starts - done
16. (B) Every house is furnished by the interior generator (no empty houses): dining corner, nightstands, wardrobes, study floors, footprint check - done
17. (C) Own properties: ALL furniture can be picked up, moved, rotated, sold or stored (placement system of point 6) - todo
18. (D) Storage lockers: buy + place in a property, own inventory (put in / take out), several allowed, saved, shared in co-op - todo
19. (F) Balconies: a door (E opens) onto every balcony, walkable, solid railing without gaps (1.6 m collision wall) - done
Then (milestone 3, in this order): ranks + XP + unlocks; staff + dealers; meth, then cocaine; heat, lawyer, bribes;
rival territories, lab raids, story missions (acts 1-5); the full city (Map layout); roadside team, fuel station, garage.

## Decisions
Choices made while working autonomously (what + why).

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
