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

## Buildings / services
Starter room, garage property, barn, lab warehouse, harbor containers/storage, villa, mountain cabin,
supermarket, hardware store, gas station, car garage (buy/sell/repair cars), roadside service depot
(tow truck team drives to the player), real estate agent (buy front businesses), front businesses
(laundromat, car wash, restaurant), bank, police station, hospital, lawyer's office, gun shop,
black market, shooting range, bar (hire dealers), club, motel, town hall, rival HQ,
dealer hangouts per district, customer houses.

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

## Known issues / later
- NPCs walk through each other: NavigationAgent avoidance is off because RVO pushed them into
  walls. Turn avoidance back on (and tune it) in milestone 4, with the big city map.
- Players and NPCs pass through each other (NPCs walking into players used to shove them metres
  away). Make them collide again together with the avoidance work in milestone 4.
- Every player gets the service pistol for testing; it is not an inventory item yet and is not
  dropped in the loot bag. From the gun shop / black market it becomes a real (illegal) item.
- Ammo is per player (8 + 32, refilled on respawn); buying ammo comes with the shops.
- Shooting pedestrians shows a hit but they don't react yet (flee / police later).
- No lag compensation: the host hits what it sees (fine on LAN).
- First-person hands wear dark gloves; the third-person body shows bare hands.
