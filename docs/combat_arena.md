# Combat Arena

Open **ESC → Combat Arena** in the editor or a debug/development export. The button is absent in release builds. The scene is `res://scenes/combat_arena.tscn` and can also be run directly with F6 for development.

The arena starts empty, with a black background and a green shader grid. Walk up to a pedestal, look toward it, and press **E** (the existing Interact binding). The prompt follows keyboard/controller remapping. Each press adds one opponent; holding the key does not repeatedly spawn.

Stations:

1. Melee Thug
2. Pistol Thug
3. Rifle Thug
4. Super Thug
5. Attack Helicopter
6. Reset Arena — removes opponents, wrecks, and temporary effects, restores health/stamina, and returns the hero to the starting position.

These are the existing combat enemies, immediately alerted to the training hero. Ground enemies spawn across the open floor; helicopters spawn in the air. The default cap is 16 opponents, including thug corpses until reset. Spawn spacing, helicopter altitude, opponent limit, recovery distance, station interaction range, and cooldown are Inspector properties. Flying beyond the floor or falling below it resets the simulation.

Training uses a disposable hero with the original hero's stats, purchased powers, and developer ability overrides. Arena saves (including automatic progression saves) are blocked, and thugs award no experience. Death uses the normal death screen but Respawn resets this arena instead of returning to the hideout.

**ESC → Return from Combat Arena** restores the original hero, health, progression, pose, camera pitch, and world clock. The previous scene reloads, so its transient enemies/encounters reload as with ordinary interior travel. Drop carried objects/enemies and detach from ships before traveling. A standalone F6 session returns to the main menu.

## Verification

Run with Godot 4.7.2:

```text
--headless --path . --editor --import --quit
--headless --path . --script res://tests/test_combat_arena.gd
--headless --path . --script res://tests/test_combat_arena_travel.gd
--headless --path . --script res://tests/test_combat_arena_travel.gd -- --city
--headless --path . --script res://tests/test_player_pickup_binding.gd
--headless --path . --script res://tests/test_gameplay_menu.gd
--headless --path . --script res://tests/test_player_respawn.gd
```

Arena tests cover real interaction input, every enemy type, target acquisition, damage, held-key behavior, range, spawn cap, reset, death, save isolation, repeated travel, menu restoration, and original hero preservation. Screenshots from a graphical Godot run are in `artifacts/combat_arena.png` and `artifacts/combat_arena_enemies.png`. Combat feel still needs hands-on playtesting.

Verified on 2026-09-24: all six test runs above passed, and the editor import completed without GDScript parse errors. The arena was run graphically and its rendered layout inspected. Runs still emit the environment's user-directory/certificate/settings warnings and some shutdown resource warnings; the menu and respawn regressions also deliberately exercise failing save/load paths.

Manual check: enter from both city and hideout; activate each station with E; fight a mixed group; reset; die and respawn; return from the ESC menu. Check aiming, punching, grabbing, powers, helicopter pursuit, and that your normal hero is unchanged after returning.

## Files changed for this feature

Added:

- `scenes/combat_arena.tscn`
- `scenes/ui/pause_menu.tscn` (standalone copy of the existing pause layout)
- `scripts/combat_arena.gd`
- `scripts/combat_arena_station.gd`
- `scripts/combat_arena_session.gd`
- `effects/combat_arena_grid.gdshader`
- `tests/test_combat_arena.gd`
- `tests/test_combat_arena_travel.gd`
- This document and generated script/shader UID companions.

Updated:

- `scripts/ui-scripts/pause_menu.gd` — development-only arena travel button.
- `scripts/player-scripts/player_character.gd` — consume station interactions before pickup/grab.
- `scripts/ui-scripts/death_screen.gd` — respawn inside the arena.
- `scripts/save_manager.gd` — block temporary training saves.
- `tests/test_gameplay_menu.gd` — verify the new development-only entry without relying on an obsolete child count.
