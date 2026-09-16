# Flight Surge — Flight upgrade 3

Purchase through **Tab → Powers → Flight → Upgrade 3**. Uses the existing
flight action (F by default, Y on a controller), including custom bindings.

- Tap toggles ordinary flight. Holding past 0.2 seconds begins charging.
- Charging requires a full stamina bar at the initial press and at release.
- Release launches; 1.5 seconds of charging reaches maximum power. Holding
  longer waits at maximum without automatically launching.
- With floor contact, launch is straight up, including from grounded flight.
  In the air, launch follows the character mesh's forward direction, including
  pitch. No launch code changes the camera's orientation.
- The entire stamina bar is spent at launch. Existing exhaustion and recovery
  apply: ordinary flight remains available, sprint boost is unavailable until
  recovery, and holding sprint prevents regeneration.
- Interrupted charges cancel without a cost. A partial bar cannot become
  eligible merely by refilling during the same hold.

Player Inspector → Flight exposes the hold threshold, charge time, minimum
speed (45), maximum speed (120), and impulse duration (0.45 seconds). Speeds
are world units per second, affected by existing movement slowdown effects.
The impulse persists briefly before ordinary flight deceleration resumes.

## Validation

Godot 4.7.2 editor import completed without GDScript parse errors. The new
`tests/test_player_flight_surge.gd` covers purchasing/persistence, HUD feedback,
ground and air directions, camera orientation, power scaling, delayed release,
full-bar eligibility, exhaustion/recovery, tap behavior and cancellation.

Existing suites passed: input snapshots, stamina, boost recovery, flying state,
jump charge interruptions, gameplay menu, gameplay HUD, powers page and powers
localization. GPU captures inspect the real skill UI and charge meter; this is
automated simulation/render inspection, not a manual city traversal playtest.

Manual check: purchase the upgrade, hold/release F on the ground with the camera
tilted; confirm a vertical launch and empty stamina. After refilling, fly in a
chosen direction and compare a short charge against a full charge. Confirm tap F
still toggles flight, and opening a menu during a charge cancels it.

## Files changed

- `scripts/player-scripts/player_abilities.gd`
- `scripts/player-scripts/player_power_controller.gd`
- `scripts/player-scripts/player_character.gd`
- `scripts/player-scripts/player_flying_state.gd`
- `scripts/player-scripts/player_normal_movement_state.gd`
- `scripts/player-scripts/player_combat_controller.gd`
- `scripts/player-scripts/player_input_controller.gd`
- `scripts/player-scripts/player_input_snapshot.gd`
- `scripts/player-scripts/player_stamina.gd`
- `scripts/ui-scripts/power_menu_progression.gd`
- `scripts/ui-scripts/gameplay_hud.gd`
- `scenes/ui/gameplay_hud.tscn`
- `localization/powers.json`
- `tests/test_player_input_snapshot.gd`
- `tests/test_powers_page.gd`
- Added `tests/test_player_flight_surge.gd` and its Godot UID sidecar.
- Added this note; validation logs and UI captures are under `artifacts/`.
