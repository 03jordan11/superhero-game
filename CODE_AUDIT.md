# Code Audit

This audit covers the player combat and impact systems, civilians, vehicles, animation loading, and obstacle avoidance. Its objectives are readability, reusability, and runtime efficiency.

## Recommended cleanup order

1. ~~Remove dead code and fix the civilian death/flee state inconsistency.~~ Completed.
2. ~~Extract vehicle explosion and radial-impact logic from `player.gd`.~~ Completed.
3. ~~Introduce a common damage and health interface.~~ Completed.
4. Cache civilian animation libraries.
5. Optimize obstacle avoidance when NPC counts increase.

## High-priority findings

### 1. ~~Vehicle explosions are owned by the player~~ Completed

`player.gd` previously connected every existing vehicle to player-owned explosion logic. Dynamically spawned cars, or cars used in another scene, could reach zero health without exploding because the player never connected them.

Vehicle destruction, blast queries, chain reactions, and explosion visuals now live in the reusable root-level `ExplosionController`.

### 2. ~~Damage uses two different interfaces~~ Completed

Civilians and vehicles now receive a shared damage payload through `apply_damage(...)`. Punches, landing impacts, thrown vehicles, explosions, and chain explosions all use this common entry point.

The reusable damage structure contains:

- Damage amount
- Impact origin
- Impact direction
- Reaction type
- Damage source
- Impact speed

Both civilians and vehicles use the shared health component for health reduction, clamping, health-change notifications, and depletion notifications.

### 3. ~~The old ground-slam damage path is dead code~~ Completed

The following members in `scripts/player_combat_controller.gd` were no longer called after decal impacts replaced the original ground-slam damage behavior:

- `ground_slam_damage_multiplier`
- `ground_slam_hit_radius`
- `apply_ground_slam_hit()`

Removed so Inspector values cannot be tuned without affecting gameplay.

### 4. ~~Explosion queries are duplicated~~ Completed

Vehicle explosions now use one reusable radial query that handles civilians and explodables in a single pass, including chain reactions.

### 5. Civilian animations are rebuilt for every NPC

Every `CivilianAnimationController` creates and duplicates its animation library, while every loader instance revalidates the complete animation catalog.

This is acceptable with one civilian, but wastes startup time and memory with a crowd. Build the civilian animation library once and share or cache it. Catalog validation should also run once rather than once per controller.

### 6. Avoidance will be the primary crowd-performance cost

`scripts/character_obstacle_avoidance.gd` performs four forward shape queries per moving civilian and up to twelve when an obstacle is detected. It also creates new query parameters for every probe.

The current implementation works for a small NPC count and should remain unchanged for now. When NPC counts increase, consider:

- Updating avoidance less frequently than every physics frame
- Staggering updates between civilians
- Reducing the number of probes
- Reusing query objects where possible

## Smaller cleanup items

- ~~Rename `_try_hit_civilian()` to `_try_hit_target()` because it now hits civilians and vehicles.~~ Completed.
- ~~Update civilian health text only when health changes instead of every physics frame.~~ Completed.
- Replace dynamic `.call()` usage on typed animation-controller references with direct method calls for parser and type checking.
- Remove the reaction debug `print()` from `scripts/civilian_animation_controller.gd` when it is no longer needed.
- ~~Prevent `start_flee()` from changing a dead civilian's internal state from `DEAD` back to `FLEE` after a lethal punch.~~ Completed.
- ~~Replace the hardcoded vehicle punch multiplier with the same shared player damage multiplier used for civilian punches.~~ Completed.
- Consider replacing the dynamically created vehicle health label with a reusable health-display component if more world objects gain health.
- If many vehicles are displayed at once, give health labels a visibility range or show them only after damage to reduce clutter and rendering cost.

## Suggested first extraction

`player.gd` is now large enough that these are the clearest systems to move first:

1. Vehicle pickup, throwing, impact tracking, and explosions
2. Landing-impact detection, radial damage, and hard-landing effects

These extractions would reduce the player's responsibilities without requiring a broad framework or rewriting working traversal code.

## Current validation status

- `git diff --check` passes.
- Godot 4.7.2 completes a headless editor parse and a short headless game run without script errors.
