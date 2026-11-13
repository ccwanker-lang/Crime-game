# HANDOFF (2026-11-13, session A)

## Parallel sessions
- Session A (this one) = main in C:\Users\alexc\game. Session B = feature-b in C:\Users\alexc\game-b (ranks + XP,
  already has a commit "Ranks + XP: Progression autoload ..."). Coordination: C:\Users\alexc\game-coord\A.md (mine)
  and B.md (theirs). See CLAUDE.md "Parallel sessions". When B says "done + rebased": merge, copy
  NOTES_feature-b.md into DESIGN/CHANGELOG, full self-test + netcheck. Expected merge conflict: Pedestrian._server_sell
  (B's `Progression.host_sale(...)` replaces my `call_group(&"progression", "on_sale", ...)` hook).

## Where we stopped
- Committed together ("Points 31-34 + admin mode"): 31 Black Crows rework, 32 panic, 33 lamps + kerb check,
  34 phone deals, admin mode F10/F11/F12.
- In progress: point 35 (own properties on the map). Done in code, not committed: scenes/player/phone_map.gd
  (green house icons for owned properties, `show_for_sale`, `focus`). Still to do: the estate agent window gets a
  mini PhoneMap (show_for_sale = true) above the list and a "Where?" button per listing that sets `focus`;
  scenario real_estate text; self-test (PhoneMap.property_spot inside the building); docs; commit.

## Next steps (in order)
1. Finish 35, then 36 build mode (B), 37 bed skips the night, 38 bookcase storage, 39 trash bin + garbage truck,
   40 laundering messages + pending screen, 41 mouse wheel hotbar, 42 work animations.
2. Then the round-4 reopenings (DESIGN Roadmap 28 a-c, 31 a-b): police neutral vs Crows (police_vs_crows scenario),
   Crows night pool (20), wanted: no stars for only holding a gun, search timer (stars x 10 s, all stars at once),
   police numbers scale with the stars (wanted_timer scenario).
3. Then 43-48 (43 ranks is session B's).

## Known
- The "activities" pedestrian check is random and fails now and then.
- `--only=pedestrians` used to fail (random nav point = 0,0,0 right after the bake); the check now waits.
- The kerb block the user saw could not be reproduced (kerb check 96/96). A more eager step-up broke the estate
  agent's door walk and was reverted.
