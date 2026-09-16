# Cargo vessel harbor schedule

The existing vessel at `Main/SuperCity/Sidewalks/CargoShip` sails a repeating route driven by the game's day/night clock. Its authored global position, height and heading are captured as the exact berth; the editor placement is unchanged. This is scheduled scenery movement only. No tugboat failure, pushing mechanic, encounter or reward is implemented.

## Default timetable

| Activity | Day call | Night call |
| --- | --- | --- |
| Approach from offshore | 08:30–12:00 | 20:30–00:00 |
| Remain docked | 12:00–15:00 | 00:00–03:00 |
| Depart harbor | 15:00–18:30 | 03:00–06:30 |
| Wide offshore return loop | 18:30–20:30 | 06:30–08:30 |

All times are game hours. At the default 24-minute day and 1× clock, the three-hour dock stay lasts three real minutes. The same ship remains in the world offshore, several kilometers from the berth, and returns for the next call.

Curved routes turn the bow along the course. The final berth approach and initial departure stay straight to clear the dock corners. Eased progress slows the vessel to an exact stop at the berth, with smooth starts and stops at route joins. Waterline height remains fixed. Navigation lights switch to Berthed while docked and Underway while moving; existing deck/night lighting follows the sky clock.

The ship's existing `Collision` node is now an AnimatableBody3D, preserving every collision shape and node path. It moves with the vessel and supplies platform movement for characters standing on deck. See [Godot's moving-body documentation](https://docs.godotengine.org/en/4.4/classes/class_animatablebody3d.html).

## Quick playtest

1. Run Main and fly to the outer harbor dock near `(1131, 1, 1225)`.
2. In the developer console run `time 11`, then `time resume`. Close the console. Watch the final approach and exact stop at noon, about one minute later at normal clock speed.
3. Run `time 14.9` and close the console to watch departure shortly afterward. Acceleration starts gently.
4. Run `time 23` to watch the midnight arrival. `time night` jumps directly to the docked midnight state.
5. Land on the containers/deck while the vessel is moving. Check that it carries you along, then fly away and check the route around the harbor.
6. `time pause` freezes the clock and vessel; `time resume` restarts them. The regular pause/console also freezes movement. `time speed 4` accelerates the whole schedule; restore with `time speed 1`.

Explicit time commands seek the vessel to the matching schedule position immediately. Use them while observing from shore or in flight. An uninterrupted clock follows the route continuously.

## Inspector tuning

Select `CargoShip/HarborSchedule` in Main. `first_arrival_hour` offsets both calls, twelve hours apart. `docked_hours`, `departure_hours` and `approach_hours` control durations; remaining time is the offshore loop. Durations are bounded to keep a positive offshore interval. `enabled` stops schedule updates.

The three point arrays describe the route in meters relative to the authored berth (-Z bow, +X seaward for the current placement). Edit before Play, or call `rebuild_routes()` after changing points at runtime. Moving/rotating the authored ship also moves/rotates its route, so rerun route validation after changing the berth or route. This is a fixed, validated harbor route, not general dynamic ship navigation.

## Validation and changed files

- `scripts/cargo_ship_schedule.gd`: route sampling, twice-daily timetable, clock following and light-mode selection.
- `scenes/main.tscn`: adds `HarborSchedule` beneath the existing placed ship.
- `assets/waterfront/cargo_ship/cargo_ship.tscn`: converts `Collision` to an animatable platform without changing shapes.
- `assets/waterfront/cargo_ship/cargo_ship.gd` and its README: updated asset description.
- `tests/test_cargo_ship_schedule.gd`: exact noon/midnight docking, dwell/departure times, continuous position/heading at all phase boundaries, a 24×10×156 m hull-envelope audit at 1,440 positions against the actual harbor/terrain, clock seeking, pause, lighting and a moving-deck rider check.
- `tests/render_cargo_ship_schedule.gd`: actual Main renders at dock, approach, departure, offshore and midnight. Images/logs are under `artifacts/cargo_ship_schedule/`.
- This guide and Godot-generated script UIDs.

Schedule tests pass, including zero route obstructions and a rider remaining on the moving deck. Existing cargo-ship asset/lighting/collision tests pass for all four variants; geometry remains 4,268 rendered triangles per ship. Godot renders were inspected. Extended in-game movement feel still needs a player playtest.
