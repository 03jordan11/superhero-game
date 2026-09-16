# Pirates encounter

Run `spawn pirates` in the developer console, close it, and follow the waypoint to the stationary offshore cargo ship. Like the other prototype encounters, it spawns on demand rather than being automatically added to Main.

## Objective

Defeat all seven enemies: **2 pistol thugs, 3 melee thugs, 1 machine gunner (`rifle_thug`), and 1 super**. The roster is fixed at every level. The last defeat awards **500 completion XP**, once, in addition to normal enemy defeat XP. No cash reward. The waypoint shows the remaining count.

Missing living participants, a missing ship, or player death fail the encounter without the completion bonus.

## Ship and combat

- Uses the existing oxide-red cargo ship, anchored 220 m seaward of the scheduled vessel's authored berth. It has no schedule and remains stationary through clock changes. The original ship and docking encounter retain their own vessel and movement.
- All seven enemies spawn on the open bow deck. Preparation checks the ship envelope, actual deck collision, slope, standing clearance and spacing. Failed placement creates no partial group. Only one pirate vessel may exist at a time, including its cleanup period.
- Existing combat, weapons, health, grabbing and knockdown resistance are retained. The optional `required_walk_surface` on hostiles stops ordinary pursuit/search movement over unsupported edges. City enemies leave it empty.
- Forced knockbacks and throws can still send pirates overboard. Pirates below the waterline count as defeated, preventing unreachable enemies on the seabed. Carried enemies are exempt until released.
- Cleanup begins 15 seconds after resolution, but waits while a living player remains on/over the ship. Once the player leaves, it removes only the encounter-owned ship and pirates.

## Tuning

Open `scenes/encounters/pirates.tscn`. Base reward, cleanup delay and encounter radius remain editable. `harbor_offset` is relative to the cargo berth (+X seaward, -Z bow); keep it clear of the service route. `deck_positions` contains seven ship-local X/Z positions; collision determines their height. `deck_detection_radius` defaults to 40 m and `overboard_depth` to 0.5 m below the ship's waterline origin.

## Validation and playtest

`tests/test_pirates.gd` passes against Main's actual harbor. It covers console integration, exact roster, grounded spawns, stationary ship, untouched schedule, duplicate/blocked placement, live deck pursuit, edge protection, level-independent rewards, one-time 500 XP bonus, waypoint count, safe cleanup, overboard defeat and missing-participant failure. Existing melee, pistol and super enemy tests passed. Godot Forward+ deck/harbor renders were inspected; extended manual combat feel still needs playtesting.

Run Godot `--headless --path . --script tests/test_pirates.gd`. Optional `-- --render` with a rendering display captures `artifacts/pirates-deck.png` and `artifacts/pirates-harbor.png`.

1. Start Main, open the developer console with backtick, and run `spawn pirates`.
2. Follow the waypoint and board the red cargo ship's bow. Confirm all seven enemies engage.
3. Fight, grab/throw, or knock enemies overboard; verify the remaining count decreases.
4. Defeat the last enemy: receive the 500 XP bonus and clear the waypoint.
5. Remain aboard past 15 seconds; the deck should stay. Leave the ship; it should clean up shortly afterward.

## Changed files

- `scripts/encounter-scripts/pirates.gd` and `scenes/encounters/pirates.tscn`: encounter placement, roster, lifecycle and cleanup.
- `scripts/npc-scripts/hostile_base.gd`: optional deck-edge walking restriction.
- `scripts/ui-scripts/developer_commands.gd` and `localization/powers.json`: registration, completion and help.
- `tests/test_pirates.gd`: harbor integration checks and optional rendering.
- `DEVELOPER_CONSOLE.md`, `docs/encounters.md`, this guide: controls and behavior.
- Godot-generated UIDs for the new scripts.
