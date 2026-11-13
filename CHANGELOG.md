# Changelog

One line per finished part.

- Milestone 2 point 1: smooth car curves.
- Milestone 2 point 2: stairs walkable for players and NPCs.
- Point 15 (A): railing round the stairwell opening on the top floor.
- Point 16 (B): fuller procedural interiors (18 new CC0 furniture models, no overlaps, every floor furnished).
- Point 19 (F): balcony doors (E) and safe balconies.
- Point 3: cars react to gunfire (panic, horn, swerve, driver bails and returns, shot cars stop, wrecks towed).
- Point 4 (E): item models (ProcItem) and rendered icons in the hotbar.
- Point 5: held items in the hand (first + third person, synced); netcheck: longer ENet timeout while a peer loads.
- Points 6/17/18: placement mode for stations + furniture (ghost, grid, rotate, hold E to pick up), empty Starter Room with movable furniture, Resell phone app, storage lockers.
- Point 7: the garage with the black market (chain-link gate locked by day, Rook sells only at night).
- Point 8: South Street with a real estate agent (Mrs. Vos) selling a small house, a family house and a warehouse; production stations only at the black market.
- Point 9: money laundering - dirty cash vs clean money, bakery/barber/laundromat sold by Mrs. Vos, back-office safes launder up to a daily maximum (10% fee).
- Point 10: police station on South Street, officers on foot + a patrol car (light bar) who chase and shoot players that fire guns or kill nearby.
- Point 20: storage window with slot grids (click one, Shift/drag stack), free locker in the Starter Room, drop items with G / right click and pick them up again.
- Points 21+22: weaker, tunable police (NpcCombatProfile: reaction time, spread by range/movement, bursts, 7 damage) and health regeneration after 8 s.
- Points 23+24: quieter, shorter, rarer horns; drivers no longer get out at gunfire - cars turn round or speed away and drive on, wrecks are towed after 20 s.
- Point 25: police belong to their patrol car (crew of 2 gets out, stays within 60 m, walks back and drives on); a player who doesn't resist is cuffed instead of shot: illegal items confiscated, fine, released at the police station.
- Point 26: the properties for sale are spread over four neighbourhoods (none next to the police station); old saves carry the contents of an owned property along.
- Point 11: the Black Crows' house in their yard; at night Crows roam the town and attack players they see (safe inside your own property), dropping cash and loot when killed, going home at daybreak.
- Test scenarios: F9 menu / --scenario=<id> sets you up for a manual check (items, money, time, place, NPCs) in a separate test game; the real save stays untouched.
- Roadmap: feedback round 3 added as points 27-41 (art style, wanted stars, police life, Crows rework, panic, lamps/kerbs, phone deals, property map icons, build mode, bed, bookcase storage, trash, money messages, hotbar wheel); stale statuses corrected.
- Point 27: art style comparison scene (F9 / --scenario=style_compare, keys 1-6): three proposals side by side on the same street, car, NPC and pistol + AK; the real map is unchanged until a style is chosen.
