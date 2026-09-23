# Player death and hideout respawn

After fatal damage, the existing death animation/sound starts. After 1.2 seconds,
the new death screen pauses the game, releases the cursor and focuses **Respawn**.
The button works with mouse or the normal keyboard/controller UI accept action.
Escape and gameplay/developer menu shortcuts cannot resume the dead character.
`Player/DeathScreen → Death Animation Seconds` controls the delay.

Respawn uses the existing loading screen and progress bar. The same player is
transferred to the placed gas station's hideout `PlayerSpawn`, retaining stats,
money, purchased powers and tokens. Health/stamina refill; death, knockout,
movement, targeting, combat, power heat and animation state reset. Ordinary healing
still cannot revive a dead character. There is no save reload or death penalty.

If already in the hideout, respawn uses its spawn marker and preserves the outdoor
return position/camera. Death in another interior first follows the existing city
return route, then enters the primary hideout under one loading screen. As with
normal interior travel, leaving a city scene unloads its temporary encounters.

Loading failures keep the character dead with the death screen open and retry
enabled. Repeat clicks cannot start overlapping transitions. On success the game
unpauses and recaptures the mouse; the hideout exit continues to work normally.

## Changed files

- `scenes/ui/death_screen.tscn` and `scripts/ui-scripts/death_screen.gd`: new UI and
  death/respawn button flow.
- `scenes/player.tscn`: attaches the UI to the persistent player.
- `scripts/player-scripts/player_character.gd`: explicit respawn reset, leaving
  the terminal dead state protected against ordinary movement/healing.
- `scripts/hideout_travel.gd`: respawn entry point and progress allocation when
  returning from another interior.
- `scripts/ui-scripts/pause_menu.gd`, `gameplay_menu.gd`, `developer_menu.gd`:
  prevent menu shortcuts from overriding death state.
- `scripts/pavement_chunks.gd`: cancel pending setup naturally when a rapid scene
  transition frees the city, using node-bound one-shot callbacks instead of awaits.
- `tests/test_player_respawn.gd`: integration coverage for fatal damage, focused
  UI, input locking, failed load/retry, duplicate clicks, recovery/progression,
  walking, repeated death, normal exit and respawn from the boxing gym.

## Validation and manual test

The respawn integration passed headless and in Forward+ with mouse capture checked
in the graphical run. The death UI and loading screen captures were inspected in
`artifacts/death_screen.png` and `artifacts/death_respawn_loading.png`. Existing
death-state, loading, hideout-travel, gameplay-menu, developer-console,
Start/Load and pavement checks also passed. Tests intentionally exercise a missing
destination/save path; those cases print expected errors. Existing environment
UID/cache warnings and headless renderer diagnostics remain; the graphical respawn
run completed with zero test failures.

In Godot, run Main, take lethal damage from enemies, and select **Respawn**. Verify
the loading screen appears, the hero arrives inside the hideout with full health
and stamina, and walking/camera controls work. Leave the hideout and verify the
correct gas-station exit. Repeat once to check a second death/respawn cycle.
