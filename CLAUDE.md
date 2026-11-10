# CLAUDE.md

**Read DESIGN.md before every milestone.** It is the source of truth for the whole game.

## Working with the user
- The user is new to Godot/GDScript and writes in Dutch: explain each step briefly in Dutch and give
  exact editor clicks (menu > option). Do as much as possible in code / .tscn / .tres files.
- Work in small, testable steps. After each step: how to test solo, with 2 local instances
  (Debug > Customize Run Instances), and over LAN. Wait for feedback unless told "ga door".
- Commit after each working step.

## Conventions
- Godot 4.6 (standard, not .NET), GDScript with static typing, Forward+, Jolt physics.
- Code, comments, UI and NPC text in English. Files in snake_case; a scene's script sits next to it.
- Autoloads: Net, GameState, SaveManager, ItemDB (in `autoload/`). Items are ItemData `.tres` in `data/items/`.
- Networking: ENet, port 7777, max 4 players, HOST AUTHORITATIVE. Clients send requests via RPC,
  host validates and applies; state syncs via MultiplayerSpawner/MultiplayerSynchronizer.
  Singleplayer = host without clients.
- Greybox geometry uses `GreyboxBlock` (box mesh + collision, editable size/color in the Inspector).

## Headless checks
Godot console exe:
`C:\Users\alexc\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe`
- Import / script check: `--headless --path . --import`
- Auto host/join for tests: `--headless --path . -- --host --name=A` / `-- --join=127.0.0.1 --name=B`
