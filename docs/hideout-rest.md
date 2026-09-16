# HUD clock and hideout sleep

The player HUD shows the current game time as a zero-padded 24-hour `HH:MM` clock
in the top-right. It remains visible when control hints are hidden. It follows
the day/night cycle rather than the computer's local time and pauses with the game.

Stand beside the hideout cot and press **E** (or the rebound interact key) to
sleep for eight game hours and restore health to the current maximum. This is an
instant time skip with a short “Rested / Health restored” message. It works at
full health too. It does not add a lying-down animation or save/reload persistence.

The same time, cycle speed, day length, and running/paused clock setting transfer
between the city and hideout. Returning outside updates the sunlight and sky to
the new time. For example, sleeping at 23:30 wakes you at 07:30.

The `SleepInteraction` node is a child of `Model/Props/Cot`, so moving the cot
moves its interaction and prompt. Inspector settings expose sleep duration,
interaction distance, and marker distance. Walls block use; dead, knocked-out,
carrying, airborne, charging, action-locked or menu-busy players cannot sleep.
The two-second feedback interval prevents repeated activations during that message.

## Changed files

- `scripts/game_clock.gd`: shared time progression, formatting and state copying.
- `scripts/day_night_cycle.gd`: inherits the clock while retaining sky/lighting behavior.
- `scripts/hideout_travel.gd`: copies clock state before changing scenes.
- `scripts/hideout_bed.gd`: proximity interaction, prompt, rest and healing.
- `scripts/health_component.gd`, `scripts/player-scripts/player_damage_receiver.gd`:
  full-health restoration through the existing health-change signal.
- `scripts/player-scripts/player_character.gd`: routes the existing interact action to beds.
- `scripts/ui-scripts/gameplay_hud.gd`, `scenes/ui/gameplay_hud.tscn`: clock display
  and reconnection after scene travel, independent of control-hint visibility.
- `assets/buildings/gas_station_hideout/gas_station_interior.tscn`: indoor clock
  and cot interaction nodes; existing prop placements/collision are preserved.
- `scenes/main.tscn`: optional performance overlay moved below the clock.
- `localization/powers.json`: English bed prompt and rest feedback.
- `tests/test_hideout_sleep.gd`: new interaction/time/healing regression and render check.
- `tests/test_hideout_interior.gd`: clock and HUD persistence on repeated city/room trips.
- This guide and generated test logs/render under `artifacts/`.

## Validation

Passed sleep checks, existing day/night checks, HUD checks, two hideout round trips,
and the powers-machine test with rendering enabled. The machine test's headless
mouse-capture assertion fails on this host; its rendered run passes. No GDScript
parse errors were reported. Existing restricted-environment settings/log/certificate
warnings remain. The rendered room/HUD/bed prompt was inspected; this was an
automated run rather than a manual city playthrough.

To test in Godot: take some damage, enter the hideout, stand beside the cot and
press E. Confirm full health and an eight-hour clock jump. Leave and check the
outdoor lighting, then re-enter to confirm time continuity. Try sleeping across
midnight and with control hints hidden. The clock should still show `HH:MM`.
