# DESIGN.md — Game design (source of truth)

Read this file before starting any milestone. Do not build features from later milestones early,
but keep code compatible with everything described here.

## Concept
Co-op crime/shooter inspired by Schedule I (economy, production, NPC selling) + Counter-Strike-style gunplay.
Fictional Belgian/European setting: a small village (chapter 1) and a big city (chapter 2) joined by a highway,
currency euro (€). Game language: English. Art: see "Art direction". Story: see "Rivals & story".
The whole map is open to explore from the start (no districts to unlock); in total a bit bigger than Schedule I.

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
Ranks unlock things to BUY and DO, never places: every area of the map can be visited from the start.
The "Area" column is where that rank's property stands.
| Rank | Property | Area | Unlocks |
|---|---|---|---|
| 0 Street Hustler | Starter room | Village: Old Town | Basic setup, sell yourself, phone, weed |
| 1 Hustler | Cover garage (see Buildings) | Village: West side | First car, gas station, 1 dealer, grower |
| 2 Dealer | Barn | Village: countryside | Meth, cook/packager, better equipment, shooting range |
| 3 Plug | Lab warehouse | Village: industrial edge | Real estate agent + front businesses, couriers, black market |
| 4 Boss | Harbor storage | Village: harbor | Cocaine, bulk deals, guards, lawyer, rivals raid you |
| 5 Kingpin | Villa | City: hillside | Bribe police, more dealers, roadside service team |
| 6 Godfather | Mountain cabin | Hills between village and city | Attack the Crows' HQ; chapter 2 story (the syndicate) |
XP from sales, deals and fights.

## Rivals & story
Rival gang (chapter 1): "The Black Crows", leader Viktor Kraal. They run the village: every district, the
harbor and a corrupt cop.

Backstory: the main character - and every co-op player - used to be a Black Crow. Viktor Kraal let them fall:
they went to prison for a job the Crows themselves walked away from, thanks to their power. Motive: revenge,
and building an empire of their own.

Start (tutorial): the last day in the PRISON (a remote complex outside both the village and the city). The
tutorial teaches walking, talking and interacting. A fellow prisoner gives you a contact in the village and
becomes your first mentor / business partner. A bus drops you at the edge of the village, without money.

Territory: at the start the Crows hold every district of the village; dealing on their turf is dangerous
(their members patrol it, see Roadmap 31). Each district has an influence meter: sales and won fights push it
towards the players; you take the village district by district. A taken district is safer to deal in and
counts for the story acts.
- Killing rivals: they drop cash, product, sometimes weapons or stash keys.
- Lab raids: rivals steal stock/machines unless guards or players defend.

Chapter 1 - the village (acts):
1. New in town (rank 0-1): selling weed in Old Town, the Crows warn you.
2. First blood (rank 2): the Crows raid your barn; you learn they pay a cop.
3. Street war (rank 3-4): take the districts one by one, move into the industrial edge, steal harbor shipments.
4. The traitor (rank 5): an OLD FRIEND of the players who is still with the Crows wants to defect; trust him or
   not -> different missions.
5. The HQ (rank 6): final assault, defeat Viktor and spare him.
Ending of chapter 1: the Crows work for the players (dealers/guards), Viktor runs the harbor for you.
Milestone 2 (test town): the Crows have a fenced yard with their house. A few roam the streets at night and attack
players; the yard is their turf. Inside a player's own property you are safe (they don't come in). Killed rivals
drop loot.

Chapter 2 - the city: a second, separate rival: an organised syndicate in suits, mafia style, hiding behind a
clean front of companies and skyscrapers. Story still to be written (the city is open to explore from the start;
its story begins after chapter 1).

Co-op in the story (max 4 players):
- All players were framed together and come out together; everyone gets the same missions. The story is the
  same whatever the number of players.
- Late join: a player who joins later also starts in the prison (a short intro), is picked up, and is then put
  on the host's story progress automatically. Missions they missed count as done, but they get no loot or money
  from them: their own cash and items start at zero (cash/inventory stay per player, see Tech decisions).

## Art direction
**Style (user decision, point 27): STYLIZED LOW-POLY, the style of the characters and the cars.**
The characters are low-poly with plain flat colours, so the whole world follows them: no photo
textures anywhere. Still a believable Belgian/European town at human scale (1 unit = 1 m, people
~1.75 m), just painted in flat, warm colours.
- Colours: ONE shared palette for the whole game, max ~40 colours, a little saturated and warm,
  in one palette texture (`assets/palette/palette.png`, made by `tools/generators/gen_palette.py`,
  names in `Palette`). World materials pick a swatch; buildings vary it with their wall/roof tint.
- Materials: flat colours, or a very simple procedural pattern on top of one base colour
  (`stylized.gdshader`): bricks = one colour with faint joints and a few slightly different
  stones, roof tiles = rows, paving = tiles with clear joints, asphalt = flat with very soft
  patches. No photo or noise textures.
- Buildings: simple shapes with clear silhouettes, slightly bevelled edges, thick window frames,
  sills, lintels, cornices and fascias, few small details (no string courses, quoins, downpipes,
  transoms). Variety comes from colour, height (2-3 floors) and roof type (gable/hip/flat).
  Windows: flat glass with a simple sky reflection + a few flat curtains; at night most glow warm
  (`stylized_window.gdshader`, global `night_lights`).
- Nature: trees with a plain tapered trunk and a crown of faceted blobs in 2-3 greens
  (`MeshBuilder.blob`), grass as a soft colour field with low, broad tufts, shrubs and hedges as
  faceted blobs (`ProcShrub`, `Hedge`).
- Roads: flat asphalt, crisp white lines, paving tiles with clear joints, light kerbs.
- Light: one look for everything: clear painted sky, warm sun, soft shadows, light ambient
  occlusion, slightly warmer colours, a light clear haze instead of grey fog. Every material uses
  the same light model (lambert wrap, matte, little specular): world shaders and the
  StandardMaterial3Ds of characters, cars, items and weapons alike.
- World edge: the map never ends in an empty plane: tree rows, bushes and two rings of soft hills
  around it (`ProcBackdrop`).
- Everything visual is a reusable prefab in `res://prefabs/` (procedural @tool scripts or imported
  models); lamps always come with their pole/mount in one prefab. Imported models must fit the
  flat style (Quaternius characters do). Imported photo-real models (Poly Haven furniture/props) are
  dressed at run time by `ArtStyle.restyle`: painted, palette-pulled colour textures
  (`assets/painted/`, `gen_painted_textures.py`), no normal/roughness maps, the shared light model.
- People: Quaternius CC0 animated characters with realistic proportions (no chibi/big-head
  packs), matte materials, random clothing colours. One prefab base (`prefabs/npc/pedestrian.tscn`)
  for pedestrians, customers, dealers, police and rivals.
- HUD: tight and in the same style (own font, icons, hotbar with clear frames); key help behind F1
  instead of a long key bar.
- Asset sources, in this order: (1) CC0 — Quaternius, Kenney, Poly Pizza (only what fits the flat
  style); (2) Sketchfab CC-BY, credits kept in `CREDITS.md`; (3) if nothing is good enough, propose
  a paid pack (e.g. Synty POLYGON) with its price and let the user decide.
  Every asset folder keeps a LICENSE.txt; every non-CC0 asset is listed in `CREDITS.md`.

### Weapons (from milestone step 4)
- Low-poly firearms with real shapes (pistol, SMG, shotgun, rifle) in the flat style: plain
  colours for metal, polymer and wood (point 27; the photo-real pistol is replaced by a procedural
  one like the AK and SMG). **No toy or sci-fi blasters** (so not the Kenney Blaster Kit).
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
  (point 25). Point 30: two officers patrol on foot from the station (80 m around it) and now and then stop a
  passer-by for a chat; a patrol car stops every 1-2 minutes next to someone on the pavement ahead (light bar on),
  one officer gets out, has a word and gets back in.
- Wanted level (point 28, replaces "heat"): 1-5 stars per player, GTA style (see Roadmap 28). Low stars = an
  arrest (illegal items + fine, released at the station), higher stars = chases and shooting, 4-5 = the whole
  force with road blocks. Stars drop out of sight / inside your own property / with a bribe (rank 5).
  Built (point 28): `Wanted` (host, under World) + `data/police/wanted.tres`. Stars: a gun heard by the police = 1
  (round 4: only holding a weapon gives nothing); kills add heat (1 kill = 1 star, 6 = 2, 12 = 3, 20 = 4,
  30 = 5); an officer killed = 3 heat and at least 2 stars; shooting at the police or resisting arrest = 2.
  Treatment: 1 star = arrest (shot only when resisting), 2 = shot when holding a weapon, 3+ = shot on sight.
  Response: police cars are sent along the roads (1 per star, crews 1/2/2/3/3, siren, 45% faster), from 4 stars
  heavy teams (dark uniform, SMG, 170 health, sharper aim) and a road block (a patrol car across the road 35-60 m
  ahead of you, its crew on guard). Round 4: out of sight ONE search timer runs (stars x 10 s: 10/20/30/40/50 s,
  3x faster inside your own property; the HUD stars blink); when it runs out ALL stars go at once, seen again = it
  starts over. Extra cars per star on top of the 2 patrol cars: 0/1/1/2/3/4; they drive off when the stars are
  gone. Arrest or death clears the stars.
- Police vs Crows (round 4, point 31a): the police are neutral. A Crow that fires is reported to the police
  (officers + patrol cars within 45 m take it on, no stars: those are for players); whoever gets shot fires back
  and calls its mates within 25 m; at night the street Crows open fire on officers within 20 m. Crows per night:
  a pool of 20 (the yard's 6 count); the dead are replaced from it, when it is empty no more Crows that night.
- Later: the corrupt cop from the story.

## Vehicles (milestone 2)
- AI traffic: procedural cars on smooth right-hand routes (curves). Gunfire: drivers stay in and flee in
  panic (U-turn or speed off, point 24; full panic through junctions with point 32); wrecks are towed.
- Car dealer (building + NPC): buy cars. Your own cars: F to get in/out, WASD drives, chase camera; other players
  can ride along as passengers. Saved in the savegame where they were parked. Done (point 45): Carlo's Cars (lot
  east of the side road at South Street), Pony Hatch €4,500 / Comet Sedan €9,000 / Mule Van €14,000 (2 seats), arcade
  driving (`PlayerCar`), H horn, Space handbrake, people hit at speed are hurt (a crime). Later: fuel, damage,
  repairs at the cover garage, shooting from a car, the van's cargo space.

## Buildings / services
Starter room, cover garage (the players' own), barn, lab warehouse, harbor containers/storage, villa, mountain cabin,
supermarket, hardware store, gas station, car garage (buy/sell/repair cars), roadside service depot
(tow truck team drives to the player), real estate agent (buy properties + front businesses), front
businesses (bakery, barber, laundromat; later car wash, restaurant), bank, police station, hospital, lawyer's
office, gun shop, black market, shooting range, bar (hire dealers), club, motel, town hall, rival HQ,
dealer hangouts per district, customer houses, car dealer.
- Cover garage (the players' own property, rank 1): a real car workshop as a front - repairing cars earns
  CLEAN money - with a hidden lab / storage room at the back. (Not the same building as Rook's garage below.)
- Prison (story start + late-join intro): a remote complex outside the village and the city, reached by bus.
- Black market: inside Rook's garage (test town), behind a fence. Open only at night (gate locked during the day). Sells
  stations and illegal goods (seeds, baggies...).
- Test town additions (milestone 2): police station, real estate agent, car dealer, the garage with the black
  market, three front businesses, the Black Crows' house, a small park behind the benches on the square at
  Mill Lane / Main Street (paths, grass, trees, benches, dog walkers, people sitting, youths smoking weed) and
  an "agora" (fenced mini football pitch with goals, sometimes NPCs playing).

## Map layout (for milestone 4 — greybox first)
Two parts, both open from the start, joined by a highway; in total a bit bigger than Schedule I:
- The VILLAGE (chapter 1, small scale): grows out of today's test map. Old Town (starter room), the Crows'
  districts, countryside with the barn, a small industrial edge with the lab warehouse and a small harbor.
- The CITY (chapter 2, big): skyscrapers and a dense downtown grid, the syndicate's company towers, hillside
  villas. Reached over the highway.
- The PRISON: remote, outside both, on the bus line (story start).
- The hills between village and city hold the mountain cabin.
The sketch below was made for one town; it is split over the village and the city as above when the map is
built (Roadmap 47 / 54). Top-down, north = up. Organic town, NOT a square grid; compact dense center.
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
  it is the link between the village and the city (open from the start).
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
11. Black Crows house: rivals roam at night, attack players, drop loot, never enter your property - done (reworked by 31: they live in the yard)
12. Park on the square (paths, trees, benches, dog walkers with dogs, sitters, youths smoking) - done (built as 46)
13. Agora: fenced mini football pitch, NPCs playing sometimes - done (built as 46)
14. Car dealer: buy cars, drive them (F in/out, WASD, chase cam, passengers), saved - done (point 45)
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
sniper scope, growing/drying/packaging, the black market, storage. Order: 27 first, then 28-42, then the round 4 reopenings of 28 and 31, then 43-48 below.
27. Art style: ONE consistent style - CHOSEN: stylized low-poly like the characters and cars (see Art direction).
    a. Comparison of 3 proposals (A/B/C) - done (superseded by the user's decision)
    b. Art test street in the new style in scenes/art_test/style_compare.tscn (--scenario=style_compare): houses,
       trees, grass, shrubs, hedge, cars, NPCs, player characters, pistol + AK, horizon hills; palette, materials,
       light, sky - done, approved by the user
    c. Rollout over all prefabs (NOT the map by hand): stylized materials written over the photo ones,
       ArtStyle.stylized on, building tints from the palette, shrubs as ProcShrub, painted textures for the
       imported Poly Haven props, new procedural pistol, ProcBackdrop around the map, stylized environment +
       sky - done
    d. HUD in the same style (Fredoka font + game theme, HudIcon icons, framed hotbar, money/clock panel top
       right), key bar replaced by F1 help - done
28. Wanted system (GTA style, replaces the current police behaviour and "heat"): 1-5 stars in the HUD.
    1 star: weapon drawn in sight of police or 1-2 kills -> one officer comes to cuff you, doesn't shoot.
    2: killed an officer or ~6+ kills -> chase, shoot if you are armed. 3: ~12+ kills -> several cars, shoot at
    once. 4-5: the whole force, road blocks, heavy teams. Stars drop when you stay out of sight, hide in your own
    property, or (later) bribe. Police react BEFORE you holster. Thresholds/times in a resource - done
    (bribes come with the corrupt cop later)
    REOPENED (feedback round 4, 2026-11-13) - done:
    a. Trigger: only holding a weapon gives NO stars and no police reaction; stars only for a shot fired, a
       wound or a kill.
    b. Losing them: as soon as the police lose sight the search phase starts: the stars blink and ONE timer runs
       (1 star 10 s, 2 = 20 s, 3 = 30 s, 4 = 40 s, 5 = 50 s). When it runs out ALL stars go at once (not one by
       one); seen again = the timer resets. All values in the resource.
    c. Police numbers scale with the stars: no stars = only 2-3 patrol cars in the whole town; every star adds
       cars and officers; 5 stars = today's numbers plus the SMG teams and road blocks. Extra units that came for
       you withdraw when the stars are gone, so the town calms down.
    Scenario wanted_timer (3 stars at once, next to a spot where you can quickly get out of sight).
29. Pedestrians and police may walk on the road (not only pavement/zebras); cars brake for them - done
30. Police life: a patrol car sometimes stops (light bar) to question an NPC; officers also patrol on foot and talk
    to passers-by - done
31. Black Crows rework: spread over their whole fenced yard (no single spawn point); they only attack on their
    turf or if a member saw you there (memory); new spawns that never saw you leave you alone outside. At night one
    small group patrols the streets (the night threat), the rest stays in the yard. The dead are replaced only
    after 1-2 minutes. Weapon variety (some carry an AK) - done
    REOPENED (feedback round 4, 2026-11-13) - done:
    a. Police vs Crows: the police are neutral: whoever shoots or murders gets them on their back, NPCs too.
       Crows shooting at night draw the police, who shoot them; a gunfight police vs Crows while you watch must
       be possible.
    b. Crows per night are limited: the turf has a fixed manning per night (e.g. 20, tunable). The dead are
       replaced until that night's pool is used up; when all are dead the Crows are out for that night and
       nobody spawns any more. The next night the pool is full again.
    Scenario police_vs_crows (night, Crows on the street, a patrol car close by).
32. Traffic + panic: cars that are shot at or hear shots flee in full panic and never stop (also not at a
    junction: right of way is dropped). Pedestrians flee until they are really away from you and out of sight - done
33. Street lamps on both sides of every street (the barber's street has none); the kerb sometimes blocks you
    stepping up from the road onto the pavement: fix (step height / collision) - done (could not be reproduced: kerb check 96/96, kept as a regression test)
34. Deals by phone: the customer sends a proposal (amount, price, place); accept, decline or counter-offer (the
    customer accepts or refuses depending on how far you go); only an accepted deal fixes the meeting. At the
    meeting a short conversation with "Confirm deal" instead of plain E. Fix the sell_weed scenario: right in front
    of a customer with a green € sign - done
35. Own properties on the map: icon + name after buying, a name plate on the building; the estate agent shows
    where a property is on the map BEFORE you buy - done
36. Build mode (B): only in build mode can furniture and stations be picked up, moved and rotated. Outside it E
    only uses things (plant, water, harvest, open a locker) (changes 6/17) - done
37. Bed: sleep to skip the night (time jumps to the morning; in co-op all players sleep / vote) - done
38. Bookcase = storage too, like the locker - done
39. Trash: throw cardboard boxes and rubbish in a bin, put the bin outside, a garbage truck comes by and empties it - done
40. Money: HUD shows dirty and clean money apart; depositing in a front business shows a message ("€5000 deposited
    -> €4500 clean tomorrow") and another one when the clean money comes in; a screen in the business with what
    is pending - done
41. Mouse wheel scrolls through the hotbar (in build mode it rotates) - done
42. Polish (later): animations for planting, watering, harvesting and packaging - done
ORDER AFTER 42 (set by the user, 2026-11-13):
  43. Ranks + XP + unlocks (Progression) - done (session B, merged 2026-11-13)
  44. Staff + dealers - done (session B, merged 2026-11-13; hiring via the phone app "Crew" until there is a bar)
  45. = point 14: car dealer + driving yourself - done
  46. = points 12-13: park, agora - done
  47. The full village (chapter 1 map, Map layout): today's test town grown to its full size, in parts:
      47a the west side: Main Road on to the west, Industrial Road (metalworks, container yard, Lab Warehouse
          property), Quay Road + the harbour (quay, Harbour Storage property, crane, moored ship, the sea) - DONE
      47b the countryside north of Main Road: a country lane, farm fields and the Barn property - DONE (Country
          Lane x -150 up to Hollow Farm: barn, farmhouse, silo, hay; two fenced fields with crop rows)
      47c the west in the game: the Crows' private pier at the harbour - DONE; a "docks" district (+ countryside) for
          dealers/turf and the rank gates of the new properties are session B's files (asked in A.md)
  48. The rest of milestone 3, in this order: meth, then cocaine; lawyer, bribes (heat = the wanted system of
      point 28); lab raids; roadside team, fuel station (territory, story and the garage moved to 49-55) - DONE
      (session B, merged 2026-11-14: meth, cocaine, courier, lawyer, bribes, Crow raids + guards, roadside team;
      session A 2026-11-14: fuel + the QuickFuel gas station on North Road)
Story + world (user, 2026-11-13; see "Rivals & story"; documented only, built after 48):
  49. Prison + tutorial intro: last day inside (walk, talk, interact), the fellow prisoner / mentor gives a
      contact, the bus drops you at the edge of the village without money - DONE (Intro, prison prefab 340 m
      north of the village, bus stop at Main Road's west end; F2 skips)
  49b. (user, 2026-11-14, changes 49 and the prison part of 62) The prison lies on the OTHER side of a mountain,
      out of sight of the farm and the village. A mountain road from the farm (top of Country Lane) winds up with
      hairpin bends; at the top snow, rocks, pines and guardrails; on the far side it goes down to the remote prison.
      The mountain blocks the view between the village and the prison. The tutorial bus drives over this pass to the
      village. Cars can drive up and down it; traffic and the navmesh work on it - todo (built right after 62)
  50. Late-join intro: a later joiner starts in the prison (short intro), is picked up and gets the host's
      story progress (missed missions done, no loot/money from them, own cash/items from zero) - DONE (short intro: cell open, desk, bus
      leaves at once; the crew gets a text)
  51. Territory per district: the Crows hold every village district at the start, dealing there is dangerous,
      influence meter (sales + won fights), take them over one by one - DONE (Territory, phone app Turf; the
      story acts can read `Territory.held_count()`)
  52. Cover garage: own garage property, repair cars for clean money, hidden lab/storage at the back - DONE
      (Corner Garage on South Street, €25,000; RepairBay car lift + Spare Parts; HiddenShelfDoor to the back room)
Feedback round 5 (user, 2026-11-14, from playing; bugs first, then in this order; BEFORE 53-55):
  56. BUG falling through the map: find holes in the collision + a safety net: below a height you are put back on
      the nearest safe spot (not killed) - DONE (host safety net: players + crew cars below y -12 go back to the
      last spot they stood on; ground slabs 4 m thick; self-test check "ground" scans the whole village for holes)
  57. BUG invisible blocks (e.g. from the centre parking through the fields to the farm): walk everywhere up to a
      border that looks natural (hills, woods, water, fences), no invisible wall in the middle of a field - DONE
      (one playable area x -193..75, z -133..106; border = hedge + tree row + hills, the quay at the sea)
  58. BUG E at cooking/placing makes the character kneel every time: no kneel/work animation for normal
      interactions any more, a short effect at the object instead (e.g. a "poof" when placing) (reverts part of 42) - DONE
      (no Interact clip, no kneel, no eye dip; drops/sparks/dust at the object, a poof on place + pick up)
  59. BUG police and Crows fight all night: it must end - the 20 pool runs out, the police call backup and win,
      or pull back after a while; a few minutes of gunfight at most (reopens 31b) - DONE (a clash lasts max
      2 min, then both sides break off and a 5 min truce follows; Crows walk back to their turf)
  60. Map: the police station's street (South Street) dead-ends: extend it to the docks - todo
  61. Map: grass everywhere it is green (no bare green planes) - todo
  62. Map: houses with driveways and parking, a rich neighbourhood with villas, a business district with tall
      office buildings. Layout: the prison (49) behind the mountain north of the farm (see 49b), the rich neighbourhood next to the farm, the business
      district on the other side of the village - todo
  63. Traffic: fewer cars, traffic lights at the big junctions, better flow: no jams or cars stuck behind each
      other, overtake / drive round when something blocks the road - todo
  64. Running people over from any angle (ragdoll, damage, a wanted star when it is murder) (extends 45) - todo
  65. Jumping onto cars and standing on them (roof + bonnet with collision) - todo
  66. Engine sound for every car (idle, accelerating, revs), traffic too, plus tyres and brakes - todo
  67. Dogs are real NPCs: the owner killed -> the dog runs off; dogs can be killed (ragdoll); owners play fetch
      (throw a ball, the dog brings it back and drops it) (extends 46) - todo
  68. Atmosphere: birds flying and sitting on roofs, other animals (cats, pigeons, ducks at the water) - todo
  53. Story missions per act (chapter 1, acts 1-5; the traitor = an old friend of the players) - todo
  54. The city + the highway link (chapter 2 map: skyscrapers, downtown, hillside) - todo
  55. The syndicate (chapter 2 rival: suits, company front, mafia style; story to be written) - todo
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
- Point 27 (art style, user decision): stylized low-poly for everything, so the A/B/C comparison and its
  run-time Stylizer (flat/toon/outline shaders) are removed. How: the stylized materials are generated with the SAME
  file names into prefabs/materials/stylized/ (gen_materials.py), so the art test swaps them by name
  (`ArtStyle.restyle`) and the rollout simply writes them over the photo materials - no prefab has to change its
  material references. Geometry that has to look different (blob tree crowns, tufts, hedges, chunky window frames)
  sits behind `ArtStyle.stylized` in the generators. Objects keep StandardMaterial3D (cars duplicate car_paint per
  car, the viewmodel copies StandardMaterial inputs) but with diffuse_mode lambert wrap, the same light model as
  the world shader. Palette = 40 swatches in an 8x5 PNG read with texelFetch (lossless import, no mipmaps), names
  in the generated `Palette` class. Bricks are drawn larger than real (0.42 x 0.14 m) so they read as a pattern,
  not as noise, and pattern lines fade out when cells get tiny on screen (no shimmering). The sky keeps the
  panorama only as a cloud mask (blurred, crisp edge) over a painted gradient, so nothing moves and no new asset is
  needed. Buildings in the art test aim their tint at a palette swatch (`_tint`: target / material colour).
- Point 27c (rollout): the stylized materials now carry the old file names in prefabs/materials/ (the photo
  versions are gone from the generator), so every prefab and the map switched without touching them. Imported
  Poly Haven props were NOT remodelled: a PIL script paints their colour textures (128 px, blurred, 12 colours,
  each pulled 35% to the nearest palette colour) and `ArtStyle.restyle` swaps them in at run time (ModelPart,
  WeaponModel) - cheap, reversible, and they read as flat painted objects next to the procedural ones. Building
  tints come from the palette via `ptint` (colour that turns the material's base colour into a swatch, in linear
  space); gen_world picks them with its own random generator (`crng`), so the map layout (all transforms) stays
  identical to before. The map edge gets a ProcBackdrop (tree row + two hill rings) and a 1000 m ground plane;
  fog affects the sky a bit (0.6) so the far ground melts into the horizon. The pistol is now a ProcGun (Kind
  PISTOL) like the AK/SMG; its WeaponModel keeps the old markers so the hand pose and viewmodel didn't change.
- Point 27d (HUD): font Fredoka (OFL, Google Fonts) in a project theme `assets/ui/game_theme.tres`, so every
  window (shop, storage, phone, menus) gets the same rounded panels and font without code changes. Icons are drawn
  in code (`HudIcon`: heart, bullet, cash, bank, clock, star) - crisp at every size, no image files. Dirty and
  clean money now sit on two lines with their own icon (part of point 40's clearer money), clock under them. The
  long key bar is gone: "F1 help" bottom left opens a 4-column controls panel. `--scenario-shot` (+ `--help`)
  saves a screenshot of a scenario for visual checks.
- Point 28 (wanted system): one host node `Wanted` keeps heat/timers per player and syncs only the result
  (Player.wanted_stars / wanted_seen in HostSync), so clients need no police logic. Every number is in
  `WantedConfig` (data/police/wanted.tres). The police sight check runs 4x a second, so drawing a gun in front of an
  officer gives the star before you can holster. The existing officer brain stays: the star count only decides
  shoot or arrest (`PoliceOfficer._should_shoot`), so point 25's arrest is simply the 1-star response. Sent cars are
  normal patrol cars (`Car.dispatched`, `chase`) spawned 75 m upstream on the nearest traffic route, so they arrive
  by road with the siren and need no new driving code; they get out at the last known spot (or when passing it,
  or when they see you) and drive off and disappear when you are no longer wanted. Road blocks are a stopped
  patrol car turned across the road (`Car.roadblock`), lifted when the stars drop below 4 or you are 130 m away.
  Kills of Crows only count when the police see it (gang fights at night shouldn't make you the town's most
  wanted). PvP kills count like civilian kills. The self-test switches the stars off for the other checks (they
  test the plain AI) and on for its own "wanted" check; scenarios without police switch them off too.
- Point 29 (walking on the road): the navmesh keeps carving the asphalt (paths still prefer pavements and zebras,
  and wandering never ends up in the middle of the road), but people can leave it on purpose with a straight walk
  (`Pedestrian._go_direct`). A wander step crosses the road with 20% chance when the pedestrian stands next to one:
  it looks for the shortest straight way over the asphalt to the opposite pavement (max 16 m, nothing solid in the
  way, the far end on the navmesh), waits at the kerb while a car is closer than 22 m (up to ~8 s), then walks
  over. Police and Crows run straight at their target / last known spot when the way is clear (`_chase_to`),
  across roads too, else over the navmesh. Cars already brake for anything in their lane (their sense boxes see
  layer 3), so no car change was needed. Rebuilding the navmesh with costly road areas was rejected: Godot bakes
  one cost per region, and joining a separate road region to the carved pavement edges is fragile.
- Point 30 (police life): a chat is a host routine on the officer (`question(npc)`): the pedestrian is held
  (`hold_for_talk`, faces the officer), the officer walks up (the last metre straight, the navmesh stops short of
  bodies), then both take turns gesturing (new Anim.TALK = the "Interact" animation; models without it stand).
  Any crime cuts the chat short (`_alert`). A patrol car only questions when it isn't chasing anyone; the other
  crew member stays in the car (`Car._in_car`), so its crew size survives. Foot patrols are back (2, not in the
  netcheck, which must stay deterministic); they use the same arrest/wanted rules as car crews.
- Point 31 (Black Crows rework): six Crows live in the fenced yard day and night (role YARD), spread over it
  (`Rival.yard_point` = random navmesh spot inside the "TurfYard" rect), strolling and chatting in pairs. At night
  the World sends 2 of them into town (role STREET = the old point-11 behaviour: attack any player in sight); at
  daybreak they walk back and become YARD again instead of disappearing, so the yard is never empty. A YARD Crow
  attacks only players standing on the turf, or players in its own `memory`; memory is filled by seeing you on the
  turf or being shot by you, and shared with Crows within 25 m at that moment (word of mouth, but no gang-wide
  hive mind: a Crow spawned later knows nobody). Memory is per Crow and not saved (a respawned yard starts fresh).
  Yard Crows stop chasing 42 m from the yard centre (`_leash_center`/`_leash_range` hooks in PoliceOfficer, which
  car crews now use too). Dead Crows are replaced 60-120 s later at the house door; 30% carry an AK-47 (own
  profile `rival_ak.tres`: bursts of 3-5, 11 damage, slightly worse aim), the weapon id is the synced `gun`
  property (PoliceOfficer, also usable for police later). In self-test/netcheck runs `rival_count` is 0, so test
  kills never trigger replacements.
- Point 32 (panic): a panicking car (not police) drops the right of way at junctions (it still claims them, so
  calm cars wait for it) and never stops for people in its lane: it honks and squeezes past at walking pace
  (PANIC_MIN_SPEED 3.5 m/s, never 0) instead of driving at full speed through them. It still brakes for a car
  right in front (it can't drive through one; overtaking is too much for this point). PANIC_TIME 6 -> 10 s.
  Pedestrians now run leg after leg (14-22 m each, away from the shot) until they are 40 m away AND a wall is
  between them and the shot, at most 45 s (so nobody runs forever when cornered). The shot's position stands in
  for "you": pedestrians don't track the shooter, which keeps it cheap with 40+ NPCs.
- Point 33 (lamps + kerb): 16 new lamps on the empty sides: the east sides of both side roads, both sides of North
  Road (z -48; on the north side on the party walls between houses, never in front of a door) and the south side
  of South Street. Placed without rng, so the rest of the generated map is unchanged. The kerb block could not be
  reproduced: a new self-test check (`kerb`) walks, sprints and crouches from the road onto the pavement at 0-70
  degrees, over tile seams and round the junction corners (96/96 pass). A more eager step-up (probing a capsule radius ahead) was tried and
  reverted: it made the walker stall inside the estate agent's door. The kerb check stays as a regression test.
- Order after point 42 (user, 2026-11-13): ranks + XP first, then staff + dealers, then the car dealer + driving
  (14), then park + agora (12-13), then the full city, then the rest of milestone 3. Art style + HUD (27) are taken
  as approved (no feedback given). The kerb fix of point 33 stays; the user reports it if it comes back.
- Feedback round 4 (user, 2026-11-13, police + Crows): recorded as reopenings of points 28 and 31 (a-c / a-b)
  instead of new numbers, because they change how those systems work. Built after point 42, before 43.
- Admin mode (user request, 2026-11-13): host-only debug keys F10 noclip / F11 god mode + endless ammo / F12 clear
  wanted. Only for the host's own player, because the host owns damage and ammo (a client's noclip would fight the
  host's speed check). Off in release builds via OS.is_debug_build(), so no separate setting is needed. Endless ammo
  = the magazine simply doesn't go down (owner and host side), so reloads and saves stay consistent.
- Point 34 (phone deals): the proposal text is the deal; the phone shows Accept / Counter... / Decline under it.
  Counter = three fixed steps (+10/25/50%, rounded to €5) instead of a free number field: quick to use with the
  mouse and easy to balance. The customer accepts with chance 1.05 - markup x 1.9 (about 86/57/10%); a refused
  counter at +40% or more makes it walk off half the time, otherwise the deal stays open at its own price (marked
  "#fixed": no second counter). Only an accepted deal fixes the meeting (green €, waits 3 more minutes); the "€"
  of an open proposal is yellow and E on it only says "text first", so walk-up selling is gone. Anyone in the crew
  can accept and anyone can meet (co-op). At the meeting E opens a small talk window at the bottom ("You got the
  2 bags? €130, like we said.") with Confirm deal / Not now; Confirm runs the old host sale with its rip-off roll.
  Deal state (`deal_ok`, `customer_name`) is synced so clients see the colour and the name. The sell_weed
  scenario was broken because the customer was made `stationary`, which keeps it out of the interactable group;
  it now stands 2 m in front of you with an accepted deal.
- Round 4 point 28a (2026-11-13): stars only for a shot the police hear, a wound or a kill; the old "weapon seen
  within 22 m" trigger is removed entirely (also for 1-star players: holding a gun near an officer while wanted
  still makes them warn you and treat it as resisting, as before).
- Round 4 point 28b: one search timer per player (`WantedConfig.search_time`, index = stars) replaces the star-by-
  star drop (`lose_star_time` is gone). The hide multiplier (3x at home) is kept: it speeds the same timer up.
- Round 4 point 28c: `units_per_star` now counts only the EXTRA (dispatched) cars after a player, not the normal
  patrol cars that happen to respond, so every star really adds units: 0/1/1/2/3/4 extra on top of the 2 patrol
  cars (5 stars = 6 cars + 2 road blocks + heavy teams, about what the town had before). Foot officers stay 2.
  Sent cars already drive off and disappear when the stars are gone (point 28), so the town calms down by itself.
- Round 4 point 31a (police vs Crows): implemented as a second target slot `PoliceOfficer.foe` (an armed NPC of
  the other side) next to the player `target`, instead of making `target` untyped: all the arrest / wanted /
  player logic stays as it was, a player target always goes first. Crows' shots are reported with a new group
  call `report_npc_crime(shooter, origin)` on "police" (officers + patrol cars). Friendly fire is off within a
  side; police bullets now hit Crows and Crow bullets hit officers (police cars still take no NPC damage). To make
  a fight possible "while you watch", the street Crows at night also open fire on officers they see within 20 m
  (yard Crows only fight back). NPC fights give no stars.
- Round 4 point 31b: the night pool counts Crows, not deaths: at dusk the pool is 20 minus the Crows alive and
  the yard is filled back up to 6 from it; every replacement (day or night) takes one from it. Kept on the host
  only, not saved (a reload simply starts with a full pool). World `rival_night_pool` / `rival_pool_left`.
- Admin mode (F10/F11/F12) was already built and committed before round 4; nothing to add.
- Point 43 (ranks, session B): XP and rank belong to the CREW, not to each player. Why: DESIGN "Host owns ... rank", and properties,
  stations and storage are already crew-shared; one rank keeps co-op simple. The +XP popup goes to the earner.
- Point 43 (ranks, session B): XP values: fair sale 10/bag + 15 per deal (every sale is an accepted phone deal since point 34; XP comes in via A's
  group hook `progression.on_sale`), short-changed sale half, customer runs 0;
  kill a Black Crow 40, an officer 10, a civilian 0. Why: selling is the main loop (~12 deals to rank 1),
  fights with the Crows are the "fights" of the design; cops give a little, civilians nothing (no reward for murder).
- Point 43 (ranks, session B): Thresholds 0 / 300 / 1000 / 2500 / 5000 / 9000 / 15000 XP. All tunable in ranks.tres.
- Point 43 (ranks, session B): Unlocks with the content that exists now (the rest of the DESIGN table is listed as "(Later: ...)"):
  0 weed + pistol + phone/webshop + Starter Room; 1 grow lamp, shotgun, Small House; 2 SMG, Bakery, Family House;
  3 AK-47, Barber + Laundromat; 4 sniper, South Warehouse; 5-6 only future content.
  The black market stays open from rank 0 (the weed stations are only sold there, a rank-3 gate would block weed).
  Ammo is never gated. Only BUYING is gated: what you already own (old saves) is never taken away.
- Point 43 (ranks, session B): Old saves start at 0 XP (rank 0); nothing is confiscated.
- Point 43 (ranks, session B): Gates are OFF in `--selftest` and in test scenarios (they hand out gear and set up purchases freely), except
  when `Progression.force_gates` is set (scenario `ranks`, the `ranks` self-test check). Reset on GameState.reset.
- Point 44 (staff, session B): Hiring happens on the phone (app "Crew", contact Benny the fixer), not in a bar: there is no bar on the map yet and
  the map is session A's. When a bar exists, a Recruiter NPC there can open the same `CrewWindow` (mode "crew",
  tab "hire"). Why: the feature works now without touching the map.
- Point 44 (staff, session B): Workers act directly on the station state (no walking AI): they stand at the station they last used. Why: robust
  in co-op (host logic only, no new networked NPCs); walking workers can come later.
- Point 44 (staff, session B): Staff NPCs are local visuals built from the synced members list on every peer (no MultiplayerSpawner). Why: no
  changes to world.tscn needed; positions are host-computed and synced in the record.
- Point 44 (staff, session B): Supplies come from the storage lockers in the property (soil, seeds, baggies), output goes to the racks / lockers.
  Why: the locker system already exists, shared by the crew, and the player sees the result by opening it.
- Point 44 (staff, session B): Room for staff = beds + storage lockers in the property (DESIGN: "need a bed/locker"). The Starter Room has room for 2
  (bed + free locker).
- Point 44 (staff, session B): Wages are paid from the employer's money (dirty first, like other illegal costs) once per in-game day; the first day
  at hiring. Unpaid = quits. Dealers have no wage, only their cut (15-30%).
- Point 44 (staff, session B): Max dealers by rank 0..6: 0, 1, 1, 2, 2, 4, 5 (DESIGN: rank 1 "1 dealer", rank 5 "more dealers").
- Point 44 (staff, session B): Districts are game data (StaffConfig), 4 for the test town: Old Town, Main Road East, North Road, South Street.
- Point 44 (staff, session B): Firing a dealer gives back their stock and the cash (what fits in your pockets).
- Point 44 (staff, session B): Cook (rank 2) and courier (rank 3) are in the list as "Not in the game yet" (meth / supply runs don't exist).
- Customers' product (for session B's meth): `Pedestrian.product` (synced, default "weed_bag") is what a customer
  wants; texts, the deal window, the sale and the stolen-bag loot use it. World.make_customer asks the `Products`
  autoload (session B) when it exists (`pick_customer_product`, `price(product, weed_price)`), so main works with and
  without it. Weed texts stay word for word the same ("2 bags"); other products read "2 bags of meth".
- Order after round 4 (user, 2026-11-13, second message): park + agora, car dealer + driving, cover garage,
  territory per district, the remote prison + tutorial intro + late-join intro, the full village map, then the
  chapter 1 story missions. Meth/cocaine (48) is being built by session B (B.md), so A skips it.
- Point 46 (park + agora): the park fills the empty lawn between the square (Mill Lane / Main Street) and the backs
  of South Street: earth paths (PavedArea "soil", 0.12 m high so ambient pedestrians count them as pavement and
  stroll there too) in a loop + a cross path to the agora, 5 benches with bins, lamps, trees, shrubs, a hedge
  towards the back gardens. Placed with its own random stream so the rest of the map keeps its exact layout.
- Point 46: park people are a Pedestrian subclass `ParkGoer` with a spawn-synced `role` (DOG, SMOKER, FOOTBALL)
  and `team`; the looks follow from the role on every peer, so the dog (`ProcDog`, procedural, on a lead) and the
  smoke puffs are local visuals with no extra network traffic. Regulars are kept by World `_park_loop`: 2 dog
  walkers 07-21 h (2-4 laps, then they go home and a new one comes), one group of 3 youths 14-02 h (stay 4-10 min).
  Sitting on benches is the existing pedestrian behaviour (the park benches are bench seats too). Only the
  smokers can become customers (`Pedestrian.can_be_customer`): they stand still, so a deal meeting works there.
- Point 46: the agora is a procedural `Agora` node (18 x 11 m pitch, boards + 3.2 m wire fence, gate on the park
  side, two small goals, score board). The ball is simulated by the host and sent as state (pos, vel, score) on
  every kick / goal and once a second; the other peers roll it the same way in between (cheap, late joiners catch
  up within a second). No physics body: players and NPCs "kick" it by walking into it (host check, 0.6 m), so the
  player controller needed no change. Matches: every 20 s between 09-20 h a 12% chance that 2 or 4 NPCs come and
  play 3-6 minutes (red / blue shirts; only models whose shirt takes the colour), then they walk off.
- Story + world (user, 2026-11-13): recorded in "Rivals & story", Map layout, Buildings and Roadmap 49-55, not built
  yet. Changed to match: the map is open from the start, so the Progression table's "District" column became
  "Area" (where the property stands) and rank 6 no longer opens a highway (it is always open; rank 6 starts the
  chapter 2 story). "Region 2" = the city of chapter 2. The rank 1 "garage property" is the cover garage; Rook's
  black market garage stays a separate building. Old point 47 ("the full city") is now the full VILLAGE; the city
  is point 54. Territory and story missions moved out of 48 into 51 and 53. The traitor of act 4 is an old friend
  of the players instead of a Crows lieutenant.
- Point 35 (properties on the map): the phone map draws every crew-owned property as a green house with its
  name (the old "Your room" landmark went: the Starter Room is now just one of your properties). The estate
  agent's window opens with the same map on top (`PhoneMap.show_for_sale`): orange pins with name + price for
  everything for sale, and a "Where?" button per listing centres the map on that building with a pulsing marker
  (`PhoneMap.focus`; the first listing is focused when the window opens). The name plate on the building existed
  already (Property Label3D: "FOR SALE" or name + owner).
- Point 36 (build mode): B toggles a per-player build mode (client side only: the host still validates every
  place / pick-up with Placement.check, so nothing new to sync). Placing new items needs build mode too, not only
  moving: one simple rule ("building = B"); outside it a selected placeable item just shows "[B] Build mode to
  place X". In build mode a short E tap still uses the thing (water a plant, open a locker), hold E picks it up.
  A blue "BUILD MODE" line sits above the hotbar while it is on.
- Point 37 (sleep): only your crew's own beds (placed furniture "bed", so every bed in an owned property, incl. the
  Starter Room's) and only from 20:00 to 06:00, never while wanted. Co-op = everyone must be in bed (no vote: a
  vote would let one player skip the night under another's feet); the sleeping players see a dark screen with
  "x/y in bed", moving gets you up. When all sleep the host jumps to 07:00, every station ticks the skipped hours
  at once (plants grow, racks dry, safes/deliveries progress) and sleepers wake healed. Logic in one host node
  World/Sleep (`scripts/world/sleep.gd`); a leaving player is dropped from the count.
- Point 38 (bookshelf storage): the "bookshelf" item now places a station `BookshelfStorage` (a StorageLocker with
  the bookshelf model, same 16 slots and window). Because adoption maps furniture to items by file name, every
  bookshelf of a house you buy (and those already adopted in saves) becomes storage automatically; bookshelves in
  houses you don't own stay plain props. gen_items.py has FURNITURE_STATIONS for more of these later.
- Point 39 (trash): two trash items (category "trash", worth nothing, not sold anywhere): an Empty Box comes with
  every delivery you take from the delivery box, Plant Waste with every harvest. They only take pocket space, so
  the pull is tidiness, not a penalty (no fines or smell - could come later). The Trash Bin (legal, €60, Marc's
  store + webshop) holds 40; E throws all trash you carry in it. It is the only placeable allowed OUTSIDE: on the
  pavement up to 7 m in front of a crew-owned building, 2.4-9 m from a traffic lane (not on the road, and close
  enough for the truck). Every morning at 08:00 World/Garbage sends one garbage truck (a green van with an orange
  beacon, `Car.garbage`) per traffic route that has an outside bin with trash, starting 45 m before the first
  bin; it stops 3.5 s next to each bin, empties it and goes off duty 50 m after the last one (5 min max). Bins
  inside a house are never emptied (that is the reason to put them outside). Sleeping to 07:00 still lets the
  08:00 pickup happen. A full bin shows its lid open with bags sticking out.
- Point 40 (laundering messages): the HUD already showed dirty and clean apart (point 9), so this point is the
  feedback. E on the safe of an owned business now opens its back-office screen (instead of depositing at once):
  rate, fee, room left, total laundered there, and every deposit waiting in the queue (first in, first out) with
  what comes back clean and when ("around 14:00 tomorrow", rounded up to the hour, computed from the queue ahead
  + the daily rate). A Deposit button puts all your dirty cash in (up to the room left). The deposit message
  reads "€5000 deposited at the Bakery -> €4500 clean (minus 10%), ready around ...". Clean money keeps coming in
  per €100 chunk (HUD clean € goes up), and when ALL of a player's deposits there are clean the business texts
  them ("All done: €4500 of your money is clean now"); a per-player `paid` tally in the safe's state feeds it.
- Point 41 (mouse wheel): the wheel steps through all 8 hotbar slots (wraps around), exactly like the number keys:
  a weapon there is drawn, an item is held, an empty slot = hands free. Before, it only jumped between weapons.
  In build mode with a placeable selected the wheel still rotates it (placement handles the input first).
- Point 42 (work animations): stations report the kind of hands-on work their E did (`Station.work`: soil, plant,
  water, harvest, hang, take, pack, throw); the host sends it to every peer (`Player.host_work`). Everyone sees
  the character's "Interact" animation (the Quaternius rig has no planting/watering clips), kneeling for low
  stations (a pot on the floor; pose crouch over a 1.2 s sine), plus a small particle burst: water drops,
  soil crumbs, leaves. First person: the eyes dip with the kneel and a held watering can tips forward to pour.
  No movement lock: walking away just cuts it short.
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
- Point 45 (car dealer + driving): arcade driving instead of VehicleBody3D (`PlayerCar` = CharacterBody3D: speed
  along the nose + a bicycle steering model, move_and_slide against walls/cars/props, height from a ray to the
  ground, collision box 0.35 m up so kerbs pass under). Why: wheel physics is twitchy on kerbs, hard to keep in sync
  over the network and can't be tested headless; this one drives the same on every machine and in the self-test.
- Point 45 network: the DRIVER's peer simulates its car (no input lag) and sends pos/yaw/speed/steer to the host
  every physics frame; the host checks the distance (1.5 x top speed + slack, else it snaps the driver back) and
  passes it on through the car's synchronizer; the others smooth towards it. Seats are host-owned (synced
  PackedInt32Array, seat 0 drives). Why: the same pattern as the players (owner moves, host checks).
- Point 45: riders are hidden inside the car (no seated animation yet) and pinned to their seat, collision off; the
  chase camera is the third-person spring arm at 6.5 m (7.5 for the van), the mouse orbits, it swings back behind
  the car after 1.5 s. No shooting from a car (yet). Why: the simplest version that works in co-op; drive-bys and
  sitting poses can come with the cover garage / story missions.
- Point 45: every car is the CREW's (like properties): anyone in the session may drive it. Cars are legal
  purchases (clean money first). No rank gate on cars yet (the DESIGN rank table says "first car" at rank 1 only as
  an unlock text; B's RankConfig has no car ids) - one line in CarDealer when wanted.
- Point 45: hitting people: the host checks a box in front of every car faster than 3 m/s (npcs + players on
  foot); damage 10 + 11 per m/s above 3, at 10 m/s or more it kills. A kill counts like a shot kill (police
  report, Wanted kill kinds, Progression.host_kill), an injury as "assault". Why: running people over must not be a
  free way to kill without heat.
- Point 45: cars are saved where they were parked (GameState.world["vehicles"]), not moved to a property: you find
  them where you left them. A bought car appears on a free CarDelivery spot on Carlo's lot (4 spots; full = no sale).
- Point 45 map: the lot replaces two trees at x 46-49 (z 52/58) and the map-edge trees east of x 37 on the south
  edge (the edge-tree rng calls stay, so the rest of the map keeps its exact layout).
- Self-test: the agora starts no random matches in --selftest/--netcheck (four extra football NPCs broke the
  pedestrian, police and regen checks of the full run); the dog-walker check starts at the last loop point (no
  random pause at the start).
- Arrest hook for session B's lawyer: `Player.host_arrest` calls group "arrest_hooks" `on_player_arrested(p, fine,
  taken_items)` after the fine (B's Legal autoload refunds part of it). Why: B owns the lawyer, A owns player.gd.
- Point 52 (cover garage): the Corner Garage replaces RowHouseB5 + RowHouseC3 on South Street (x -42..-29.6);
  gen_world `SKIP_NODES` leaves just those two nodes out while their rng calls and names still run, so every other
  house keeps its look and name. Why: one fixed spot near the estate agent without reshuffling the whole row.
- Point 52: repairs are a `RepairBay` station (one E = one work step, "repair" work animation with sparks), a
  customer car every 2-4 in-game hours once the garage is crew owned, 4 job types (3-6 steps, 0-3 Spare Parts,
  €140-600). Pay is CLEAN money to the one who finishes + 10 crew XP. Why: the garage is a front business, so it
  should give legal money like the launder shops, but it costs time at the lift instead of a daily cap.
- Point 52: Spare Parts (`car_parts`, €40, legal) come from the phone webshop only; no new shop NPC. Why: the
  webshop already delivers every legal item, and buying parts online fits a small garage.
- Point 52: the hidden room sits behind a full tool shelf (`HiddenShelfDoor`, a NetDoor subclass that slides 1.2 m
  sideways). It is part of the same Property, so build mode places stations there. Why: NetDoor already gives E,
  host authority and late-join sync; the shelf hides the room from the workshop side.
- Point 51 (territory): the districts are session B's StaffConfig districts (Old Town, Main Road East, North Road,
  South Street) and a spot belongs to the nearest anchor. Why: one list for dealers and turf, no second map data
  to keep in step; the real village map (47) only needs new anchors.
- Point 51: influence 0-100 per district: +4 per bag sold fair (+2 short, -2 when the customer runs), +6 per Crow
  killed there, -8 when a Crow kills a player there, Crow turf drifts back 0.5 per in-game hour. At 100 the crew
  takes it; it is lost again below 50. Why: about 15-25 sales take a district, so it is a goal for several
  in-game days; the gap between 100 and 50 stops a district flipping back and forth.
- Point 51: danger on Crow turf = first a warning text per district, then 30% per sale that one Crow is sent
  after the seller (by day too, `Rival.send_after`, one at a time, gives up after 90 s, at a crew property or
  on crew turf). Why: act 1 says "the Crows warn you"; one Crow is a fight a rank 0 player can win, and it
  feeds the meter (+6) when you win.
- Point 51: crew turf = no street Crows roam there at night, nobody is sent there, customers offer 15% more.
  Why: "a taken district is safer to deal in" (design) plus a money reason to take more of them.
- Point 51: sales and kills reach Territory through new group calls (`sale_hooks.on_sale(seller, npc, bags, paid,
  outcome)`, `kill_hooks.on_kill(killer, victim)`) instead of direct calls. Why: same pattern as session B's
  "progression" hook; other systems (story missions) can listen without touching pedestrian.gd / combat.
- Point 48 (meth, session B): Abstract steps only (load, stir, pour, break) - DESIGN "abstract game mechanics, no realistic procedures".
  The stir is the "cook in steps" skill moment: miss it = half the batch. Easy for co-op, readable for the player.
- Point 48 (meth, session B): One generic `ProcessStation` for all timed machines (cooling plate now; coca processing + refinery next). Why: one
  tested code path for player use, staff, save and sync.
- Point 48 (meth, session B): Supplies are added to Rook's stock at runtime instead of editing garage.tscn / gen_prefabs.py. Why: the map and
  building prefabs are session A's; A can move the ids into gen_prefabs `shopkeeper(...)` stock at merge time.
- Point 48 (meth, session B): Economy: one cook = €290 supplies (black market -10% = ~€260) -> 12 bags x ~€130 (dealer: x2.2 the district weed
  price). About 4x the money per hour of a weed pot, but €1,300 of stations and rank 2 first.
- Point 48 (meth, session B): Meth goes through the existing packaging table (no new table), dealers carry both products in one stock.
- Point 48 (cocaine, session B): Same pattern as meth (one generic machine class + one attend moment per chain: water the bed, vent the refinery).
  Why: readable, abstract (DESIGN), every machine works for players and staff alike.
- Point 48 (cocaine, session B): No grow lamp/pot reuse for coca: a bigger "grow bed" (DESIGN table) that takes seedlings + soil, so growers can
  run it from the locker without the weed pot's multi-step state machine.
- Point 48 (cocaine, session B): Economy: one chain = ~€150 supplies -> 8 bags x ~€200 over ~15 in-game hours, but €4,300 of machines and rank 4.
- Point 48 (cocaine, session B): Watering a coca bed needs no watering can (E is enough): keeps the hand-off simple; the weed pot keeps its can.
- Point 48 (courier, lawyer, bribes, session B): The courier works from a property (its locker = the warehouse) and also collects the dealers' cash. Why: DESIGN
  "fetches supplies, delivers to dealers"; collecting makes the dealer network run without driving around, and it
  keeps the dealers loyal (same rule as collecting yourself).
- Point 48 (courier, lawyer, bribes, session B): The courier only buys supplies for stations that stand in its property, and only up to small targets: no runaway
  spending. Paid at +10% (his cut). Illegal supplies are paid with dirty cash first (like the black market).
- Point 48 (courier, lawyer, bribes, session B): Lawyer and bribes are phone/crew-window services (no NPC office yet; the lawyer's building is on A's map later).
  Fine back as CLEAN money (a court refund). No jail time exists, so "shorter sentence" = goods + fine back.
- Point 48 (courier, lawyer, bribes, session B): Bribe price per star (€1,500) makes 5 stars €7,500: a Kingpin expense, not a free reset; the cooldown stops spamming.
- Point 48 (Crow raids on labs + guards, session B): Raiders never walk INTO the property (A's rule: inside your own property you are safe, Crows don't come in). The
  "break-in" is the timer: Crows still standing at the door when it runs out = they got in. Why: no changes to the
  Crow AI (A's files) and the fight happens outside where the AI works.
- Point 48 (Crow raids on labs + guards, session B): Live raids only when a crew player is close: a real fight when you can take it, a dice roll for guards when you're
  away (DESIGN: "unless guards or players defend").
- Point 48 (Crow raids on labs + guards, session B): Machines: only one ProcessStation (meth/cocaine machine) is taken and only when there are no guards: losing a
  €2,500 refinery is a big hit; guards are the insurance. Weed pots are not taken (small, starter content).
- Point 48 (Crow raids on labs + guards, session B): Raids start at rank 2 (DESIGN act 2 "First blood (rank 2): the Crows raid your barn"); guards come at rank 4 (DESIGN
  rank table "guards"); before rank 4 you defend yourself.
- Point 48 (roadside team, session B): No tow truck driving through town: the car simply appears after 30 s. Why: a driving tow truck needs Traffic/Car
  changes (A's files); the service effect (your car where you are) is what the design asks. A can add a visual
  truck later via the same `_deliver` moment.
- Point 48 (roadside team, session B): The car is dropped on the pavement, not in the lane: AI traffic would stop behind a car parked in its lane.
- Point 48 (roadside team, session B): Fee €350, clean money first (a legal service, like the lawyer).
- Point 48 (roadside team, session B): Fuel + the gas station (rest of Roadmap 48) are A's: they need PlayerCar (fuel use) and the map (station). Asked in B.md.
- Merge 2026-11-14: Rook's extra stock (meth/cocaine supplies + machines) stays in `Products.BLACK_MARKET_EXTRA` at
  runtime instead of gen_prefabs. Why: it works, is tested, and the rank gates live next to it in session B's code.
- Point 49 (prison intro): the prison is one generated prefab 340 m north of the village (outside NavRegion, own
  concrete ground), not a second scene. Why: one world for co-op (players in the intro and in the village share the
  same host), no scene switch, the bus ride is a fade + teleport.
- Point 49: four steps (walk to the cell door, talk to Marco, release desk, board the bus) in a HUD box, Marco's
  lines as subtitles and his number as a phone text. Why: DESIGN asks walking, talking and interacting; the phone
  text teaches the phone too.
- Point 49: "without money" is read as "empty pockets until the desk": everything a new player carries is held at
  the start, the desk gives back the wallet (the normal €500 start cash), Marco's "package" at the bus stop is the
  starter pistol + rounds. Why: the €500 start economy and the starter kit stay as balanced and tested; the story
  still has you walk out with nothing in your hands.
- Point 49: co-op: every player wakes in their own cell (4 cells); the bus leaves when every player in the intro
  is on board. F2 skips: the host skips it for everyone, a client only for themselves.
- Point 49: only NEW games run the intro (no player data and no saved time yet); existing saves, the self-test,
  netcheck, screenshots and scenarios skip it (`--intro` forces it, scenario prison_intro). Why: never surprise an
  ongoing game or slow the tests down.
- Point 49: the village is called Riverton (bus line 12, "Riverton State Prison"). Why: the map has a river through
  the town (Map layout); no name was chosen yet.
- Point 50 (late-join intro): a player with NO player data joining a game whose intro is done gets the short
  version: their cell door already open, Marco's text already on the phone, straight to the release desk and the
  bus, which leaves as soon as they board; the others get a text to pick them up. Their clock-free ride does not
  change the time for everyone. Why: the design's "short intro", without holding up the rest of the crew.
- Point 50: "the host's story progress" needs no copying: story state lives in GameState.world (crew-wide) and
  missions are not built yet (53); their cash/items are a normal new player's (€500 + the starter kit), per player.
- Point 48 (fuel, session A): Fuel only for crew cars (PlayerCar); town traffic never refuels. A full tank = 3 km
  (`FUEL_RANGE`), ~10 laps of the village: enough to forget it for an evening, often enough to matter. 45 L at €2/L
  (a full tank €90, small next to deals). Why: a light upkeep cost, not a chore.
- Point 48 (fuel): Fuel is burnt by distance (host, from net_pos per frame, jumps > 30 m = teleports ignored), stored in
  0.5% steps so the synced value changes rarely. An empty car keeps rolling and steering but gets no throttle: push
  it off the road or call the roadside team (B's tow). Low (15%) / empty texts to the driver.
- Point 48 (fuel): Paying at the pump is a legal purchase (clean money first, like the webshop). Filling needs the
  driver out and the car still; one E fills the whole tank (no litre picker: less UI, same result).
- Point 48 (fuel): QuickFuel sits on the north side of North Road at x 34-56 (trees/lamp there dropped via
  SKIP_NODES), a raised concrete forecourt like Carlo's lot, two pumps under a canopy, posts on the pump line so both
  lanes are free to drive through. The fuel % is in the car panel and the save record.
- Point 47a (map): The village grows WEST (x -192..-72.5), not around the whole town: the old map's north, east
  and south edges stay as they are (no layout changes, no re-done self-test spots), and the DESIGN sketch puts the
  industrial edge, harbour and countryside in the west/south-west. The tree row at x -75 stays as a green belt
  between Old Town and the industry.
- Point 47a: No river in the village for now: the sketch's river splits Old Town from Downtown, and Downtown is the
  city (chapter 2, Roadmap 54). The village gets the sea at the harbour instead. No terrain heights yet either
  (flat ground keeps the navmesh, traffic and placement simple); the backdrop hills give the height around it.
- Point 47a: One navmesh region, its baking box widened (x -194..74, z -134..106). Bake time went from ~1.0 s to
  ~3 s on the host (measured with the new "in N ms" in the bake log line); a second region would need border/edge
  tuning for the seam on Main Road. Clients still skip the bake.
- Point 47a: The sea is a water shader plane (prefabs/materials/water.tres, 3 colour bands + slow waves) below the
  quay; no swimming: an invisible wall on the quay edge (Bounds/Quay) and the outer ground split round the sea.
  The ship, crane boom and breakwater are scenery without collision.
- Point 47a: Properties in the west: Lab Warehouse (Industrial Road, €60,000) and Harbour Storage (on the quay,
  €90,000), both enterable warehouses with storage furniture (rank gates 3/4 from the Progression table: asked
  session B to add them to RankConfig.property_rank, B's file).
- Point 47a: Traffic: route 2 (Main Road end to end) now turns down Industrial Road to the quay and back instead of
  U-turning at x -66; new junction square at (-114, 0). Routes 0/1/3 unchanged.
- Point 47a: Pedestrians keep only 12% of random walk spots west of x -76 (`Pedestrian.QUIET_WEST_*`): the quay is
  paved like a square, and without this a big share of the town would wander off to the harbour.
- Point 47b: Hollow Farm sits at the top of a dead-end Country Lane (x -150), away from Main Road behind fields:
  the barn is the rank-2 hideout ("far from prying eyes"); no traffic route on the lane (a dead end with only the
  farm). The barn is an enterable corrugated hall (14 x 16 m, storage furniture), property `barn` €30,000 (rank 2
  gate asked from session B). Fields are soil with crop rows (scenery, no collision on the rows).
- Point 47b: Loading the world got slower with the bigger map (host ~18 s + ~3-5 s bake on a busy PC, was ~15 + 1.6).
  Joining a host that is still loading must not fail: the menu waits 60 s for the registration once the link is up
  (`REGISTER_TIMEOUT_SEC`, signal `Net.connected_to_host`), and `Net.PEER_TIMEOUT_MS` went 45 s -> 90 s (ENet drops a
  silent peer after half of it; a client loading the map was dropped after 22.5 s). tools/netcheck.py starts the
  client once the host has baked its navmesh instead of after a fixed 4 s.
- Point 48 (dealers + turf, session B): every bag a dealer sells adds `StaffConfig.turf_per_dealer_bag` (2.0) to its
  district's influence (Territory.host_add, "dealer"). Why: a fair street sale is worth 4; a dealer half, because
  nobody risks a fight for it.
- Point 48 (bulk deals, session B): from rank 4 "The Dutchman" texts an offer every 20-30 in-game hours: 20-40 bags of
  one product for one price (street x 0.8), waiting 6 h 7 m from a district's dealer anchor (BulkBuyerNPC, E = sell
  all). Why: volume and the risk of carrying 20-40 bags instead of a better price; XP 6 per bag; dirty cash. The meet
  spot can move to the harbour now that it exists (`BulkDeals._meet_spot`, B's file).
- Point 48 (roadside + fuel, session B): an (almost) empty crew car (fuel < 15%) can be called even when it is close;
  the tow team brings a jerrycan up to 15% (~450 m, enough to reach QuickFuel). Crew window shows each car's fuel.
- Point 47c: The Crows hold the harbour (DESIGN "They run ... the harbor"): a fenced private pier at the west end of
  the quay (HarbourTurf, x -190..-164) with 3 Crows (`World.rival_harbour`) of their own post (`Rival.post`
  &"harbour"). They behave like yard Crows (attack on their turf, remember you, leash on the pier) but never go into
  town at night and respawn outside the nightly pool (1-2 min). Why: a fixed danger spot you can plan around, next
  to the Harbour Storage you may want to buy - act 3 "steal harbor shipments" will happen there. `Rival.turf(tree,
  post)` / `on_turf` (any turf) / `yard_point(from, post)`; `World.add_rival(at, ak, post)` keeps old calls working.
- Point 56: The safety net is HOST logic (it sees every player and car): every 0.5 s it remembers the spot under a
  player/car that stands on world ground (ray on layer 1, flat), and below y -12 puts them back there (players via
  `teleport`, cars via `_correct` to the driver), with a message - never a death or a loot bag. Why: whatever hole
  someone finds (a building, a seam, a fast car), the game stays playable. Ground slabs are 4 m thick now (were 1 m)
  so fast things don't tunnel through.
- Point 57: The old test-map edges (walls at z -61, z 67, x -72.5, ...) were in the middle of the grown village. Now
  the whole village is ONE playable area PLAY = x -193..75, z -133..106 (gen_world `PLAY`), with ONE border round it:
  a 1.6 m hedge 6 m outside, the backdrop's tree row right behind it and the hills further out; the invisible walls sit
  7 m out, behind the hedge, so you never bump into air in the open. On the sea side the quay edge is the border.
  The navmesh box stops 0.5 m before the hedge. The empty land north/south of the centre is room for point 62.
- Point 58: Using a station / placing no longer moves the player's body at all (no "Interact" clip, no kneel, no eye
  dip): with many E presses in a row (cooking, packaging) the kneel felt like a stutter. The feedback is at the
  OBJECT: the station's WORK_FX (drops, sparks, dust) or else a small dust `Poof` (scripts/world/poof.gd, local
  CPUParticles3D), and placing / picking up sends `World.host_poof(pos)` to every peer. The watering can still tips
  (that is the held item, not the body). `_work_t` stays for that; `_work_low` is always 0.
- Point 49b (roadmap order): the mountain pass is built right AFTER point 62 (the map layout), as part of the map
  work (60-62), because 62 places the neighbourhoods round the farm and the pass starts there; doing it before 62
  would mean moving it again. The prison moves from its current spot to behind the mountain then.
- Point 59: A police-vs-Crows clash ends by a CLOCK, not by who dies: `PoliceOfficer.clash_max` (120 real s, from the
  first `set_foe` between the sides; a new clash starts after 40 s quiet) -> `end_clash` drops every NPC foe and
  starts a truce (`TRUCE_TIME` 300 s): no `set_foe`, no `report_npc_crime` (officers + patrol cars), `spot_cop` finds
  nobody, street Crows walk back to their turf (like at daybreak). Why a clock: NPC accuracy at night is low and both
  sides get reinforcements (pool of 20, patrol crews), so "until one side wins" could still take all night. Fights
  against PLAYERS are not touched (target/stars stay as they are).
