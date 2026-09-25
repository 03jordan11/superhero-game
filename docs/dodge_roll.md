# Hero dodge roll

Press the rebindable `dodge_roll` action (Ctrl / B) while moving on
the ground. The initial horizontal velocity determines the committed world
direction; camera orbit, aim facing, and target lock do not redirect the roll.
Stationary presses are ignored. No power purchase is required.

Uses the existing `Roll` clip in `UAL1_Standard.glb`, registered as `Dodge_Roll`.
The clip is played once, at a speed matched to the physics duration. The body
moves through normal `move_and_slide`, with collisions enabled. Its model
faces the roll direction without forcing the camera to turn.

Movement starts at about 20 m/s and eases down to zero over the roll. The
distance curve is integrated per physics step; no burst momentum remains on
exit. Duration and distance tune both the animation timing and burst strength.
Controller defaults share B with flight descent. Binding version 4 migrates
the previous D-pad Right default to B while preserving other custom bindings.

Inspector tuning is on `PlayerStateMachine/DodgeRollState`: duration 0.6 s,
distance 6 m, stamina fraction 0.10, minimum movement speed 0.1 m/s. Cost is a
percentage of maximum capacity, charged once on successful entry. A roll can
spend the last 10% even if sprint exhaustion is active. Stamina does not drain
again or regenerate during the roll; normal recovery delay follows it.

While active, the player damage receiver rejects hits before health changes
or reaction signals. Direct slowdown, hit/knockdown animation requests, and
knockdown state entry also reject the effect. Collision remains enabled.
Existing hit slowdown is cleared on entry. Leaving a ledge or finishing the
roll ends protection. Death/respawn cleanup cannot retain the protection flag.

The roll cannot start during flight, wall running, ground slam, death,
knockdown, jump/surge charging, a committed melee attack, carrying, or ship
interaction. During the roll, ordinary movement/action snapshots are suppressed
so pickup, flight, jumping, and ranged attacks cannot compete with it. This
also prevents the shared Ctrl / B input from beginning a ground roll in flight.

Changed files:

- `project.godot`: declare the action for startup and standalone script runs.
- `scenes/player.tscn`: add the dodge state.
- `scripts/player-scripts/player_dodge_roll_state.gd`: eligibility, movement,
  animation timing, cost and cleanup.
- `player_character.gd`, `player_input_snapshot.gd` in that folder: input,
  action priority, facing, and respawn protection cleanup.
- `player_animation_controller.gd`: load Roll and protect its playback.
- `player_stamina.gd`: percentage spending and roll recovery handling.
- `player_damage_receiver.gd`, `player_status_effects.gd`,
  `player_knocked_down_state.gd`: damage and disabling-effect guards.
- `tests/test_player_dodge_roll.gd`, `tests/test_player_input_snapshot.gd`:
  regression coverage.
- `CURRENT_CONTROLS.md`, `CONTROLS.md`, and this document.

Manual review: strafe and backpedal while aiming, then press Ctrl. Check that
the body rolls along travel and the camera stays controllable. Try it while
standing still, with under 10% stamina, into a wall, and off a ledge. Roll
through gunfire/melee, then stop rolling to verify damage resumes. Fly and
hold Ctrl to check descent. Try the same actions with B on a controller.

Validation: focused dodge, damage-receiver, stamina, input-snapshot, and
directional-movement checks passed headlessly. Roll coverage includes all
movement directions sampled, camera rotation, stationary/insufficient-stamina
rejection, damage and direct disable immunity, protection expiry, walls, ledges,
and flight descent. Animation appearance and physical-controller feel have not
been visually reviewed in this pass.

Burst update validation also checks decreasing speed, no exit momentum, B input,
and migration/save/load of the shared controller binding.
