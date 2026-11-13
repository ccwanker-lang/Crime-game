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
- Car dealer (building + NPC): buy cars. Your own cars: F to get in/out, WASD drives (VehicleBody3D), chase
  camera; other players can ride along as passengers. Saved in the savegame, they spawn at your property.

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
  43. Ranks + XP + unlocks (Progression) - todo
  44. Staff + dealers - todo
  45. = point 14: car dealer + driving yourself - todo
  46. = points 12-13: park, agora - todo
  47. The full village (chapter 1 map, Map layout): today's test town grown to its full size - todo
  48. The rest of milestone 3, in this order: meth, then cocaine; lawyer, bribes (heat = the wanted system of
      point 28); lab raids; roadside team, fuel station (territory, story and the garage moved to 49-55) - todo
Story + world (user, 2026-11-13; see "Rivals & story"; documented only, built after 48):
  49. Prison + tutorial intro: last day inside (walk, talk, interact), the fellow prisoner / mentor gives a
      contact, the bus drops you at the edge of the village without money - todo
  50. Late-join intro: a later joiner starts in the prison (short intro), is picked up and gets the host's
      story progress (missed missions done, no loot/money from them, own cash/items from zero) - todo
  51. Territory per district: the Crows hold every village district at the start, dealing there is dangerous,
      influence meter (sales + won fights), take them over one by one - todo
  52. Cover garage: own garage property, repair cars for clean money, hidden lab/storage at the back - todo
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
