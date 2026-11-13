# HANDOFF (2026-11-13, session A)

## Parallel sessions
- Session A (this one) = main in C:\Users\alexc\game. Session B = feature-b in C:\Users\alexc\game-b (ranks + XP,
  already has a commit "Ranks + XP: Progression autoload ..."). Coordination: C:\Users\alexc\game-coord\A.md (mine)
  and B.md (theirs). See CLAUDE.md "Parallel sessions". When B says "done + rebased": merge, copy
  NOTES_feature-b.md into DESIGN/CHANGELOG, full self-test + netcheck. Expected merge conflict: Pedestrian._server_sell
  (B's `Progression.host_sale(...)` replaces my `call_group(&"progression", "on_sale", ...)` hook).

## Where we stopped (user's limit, 2026-11-13)
- Committed: "Points 39-42" (trash bin + garbage truck, laundering screen + messages, mouse wheel hotbar, work
  animations). Targeted self-test checks passed (held, laundering, growing, trash, storage, sleep, placement);
  scenarios trash / launder / grow checked with screenshots.
- NOT yet run on this commit: the FULL self-test (the run in progress was stopped on purpose) and the netcheck.
  First thing next session: `--selftest --port=7791` + `python tools/netcheck.py 7793`, fix whatever fails.
- Nothing is half-built. No git remote (nothing pushed).
- Police/Crows feedback round 4, admin mode and the new story are all in DESIGN.md (Roadmap 28a-c, 31a-b,
  Decisions, Rivals & story, Roadmap 49-55). Admin mode is built and committed; round 4 and the story are not built.

## Next steps (in order)
1. Full self-test + netcheck on main (see above).
2. Round-4 reopenings (DESIGN Roadmap 28 a-c, 31 a-b): police neutral vs Crows (scenario police_vs_crows),
   Crows night pool (20), wanted: no stars for only holding a gun, search timer (stars x 10 s, all stars at once),
   police numbers scale with the stars (scenario wanted_timer).
3. Merge feature-b when B.md says "done + rebased" (see CLAUDE.md Parallel sessions; A.md lists what changed for B).
4. Then 45+ in Roadmap order (43 ranks / 44 staff are session B's).

## Known
- The "activities" pedestrian check is random and fails now and then.
- `--only=pedestrians` used to fail (random nav point = 0,0,0 right after the bake); the check now waits.
- The kerb block the user saw could not be reproduced (kerb check 96/96). A more eager step-up broke the estate
  agent's door walk and was reverted.
