# Bounding

Super Jump's sequential upgrades are now **Greater Jump → Air Jump → Bounding**. All three are implemented. Power Jump remains the free starter core. UI text lives in `localization/powers.json`.

**Todo:** Revisit gameplay feel based on user playtest feedback. Further changes are deferred; specific adjustments remain to be defined. Tracked in [the player rework backlog](PLAYER_ARCHITECTURE_REVIEW.md#gameplay-tuning-todo).

## Behavior

Press the bound Jump action shortly after a qualifying landing to immediately leap again. A small early-input buffer also accepts a tap just before contact. Bounding uses the full charged Super Jump's upward launch velocity, including Greater Jump, and retains most of the player's horizontal velocity without adding another forward boost. It costs no stamina and has no fixed limit on consecutive bounds.

Both horizontal speed and downward speed at contact must meet their thresholds. This applies to charged jumps, Air Jumps, and ordinary falls such as running off a roof at super speed. Merely having used a Super Jump does not bypass the speed requirements. Dive Bomb landings do not qualify, including impacts that have just ended the slam state. Active flight, wall running, knockdown, death, and locked combat actions also block Bounding.

With Bounding unlocked, fast movement in ordinary airborne states preserves momentum instead of slowing toward walking speed. Existing air steering remains, reverse input brakes, and a small drag steadily reduces speed. A successful bound loses another 10%. The landing window briefly preserves momentum while waiting for the tap; after it expires, ordinary ground movement resumes. Collisions and hit slowdown still remove speed. No cached landing velocity can restore momentum lost to a wall.

An uninterrupted chain therefore ends below the minimum speed. Sprinting or using Air Jump can supply additional momentum through those existing mechanics. Bounding itself never supplies a fresh horizontal boost.

## Inspector tuning

Select **Player → PlayerBoundingController** in `scenes/player.tscn`.

| Setting | Default | Purpose |
| --- | --- | --- |
| Landing Window | 0.25 s | Latest tap after landing |
| Input Buffer | 0.12 s | How early a tap may anticipate landing |
| Minimum Horizontal Speed | 16 m/s | Minimum speed to enter or continue a chain |
| Minimum Downward Speed | 12 m/s | Required downward velocity immediately before contact |
| Momentum Retention | 0.90 | Horizontal velocity retained on each bound |
| Air Drag | 1 m/s² | Gradual loss during fast airborne coasting and the landing window |

Vertical strength follows existing Super Jump tuning rather than introducing a separate height setting. With default Greater Jump tuning, the upward launch is approximately 49.50 m/s. The momentum-retention Inspector range stays below 1 to ensure every bound loses some speed.

## Input and progression details

- Space / Xbox A are the defaults; remapped Jump inputs work automatically.
- A fresh tap near a predicted qualifying floor contact is reserved for Bounding. The prediction uses a sweep of the player's collision shape, only on that tap. Otherwise Air Jump remains immediate. A missed prediction expires rather than firing a delayed Air Jump.
- A held button never automatically repeats a bound, starts charging on the next landing, or jumps on release. Each bound requires a new press. Normal quick-jump and charged-jump controls remain available after an expired or ineligible window.
- Each actual landing replenishes Air Jump normally. Bounding does not consume it.
- Pause, focus loss, controller disconnect, binding changes, progression loads, and console reset clear transient Bounding timing.
- Saves retain the existing purchased tier count: tier 2 now grants Air Jump, and tier 3 grants both Air Jump and Bounding. No points are refunded or added. The save schema is unchanged; ability flags remain derived from purchased tiers.

## Files changed

- Added `scripts/player-scripts/player_bounding_controller.gd` and its Godot UID for timing, qualification, momentum, and input handling.
- Updated `scenes/player.tscn` to attach the controller without changing existing node paths.
- Updated `scripts/player-scripts/player_character.gd` to call the controller around movement and preserve pre-collision landing measurements.
- Updated `scripts/player-scripts/player_normal_movement_state.gd` for bound input priority and fast airborne coasting.
- Updated `scripts/player-scripts/player_abilities.gd` and `player_power_controller.gd` for the new ability and reordered tier requirements.
- Updated `scripts/ui-scripts/power_menu_progression.gd` and `localization/powers.json` for implemented tiers and descriptions.
- Updated `scripts/ui-scripts/developer_commands.gd` to clear Bounding on reset.
- Added `tests/test_player_bounding.gd` and its UID; updated `tests/test_player_air_jump.gd` to test tier 2 independently.
- Updated `GAMEPLAY_MENU.md`, `POWERS_MENU.md`, and `POWERS_DESIGN.md` to reflect the current tree.

## Validation and playtest

Godot editor import completed without GDScript parse errors. The 49 selected regression scripts pass, including Bounding tests using actual physics frames and floor collisions. Coverage includes tier gating, a full charged jump entering a chain, speed/force thresholds, momentum loss and termination, late/early/expired taps, Air Jump priority, held input, Dive Bomb exclusion, pause/load resets, Xbox A, and a remapped keyboard Jump. The test starting at a 40 m/s horizontal landing produces four bounds before slowing below the cutoff. Headless execution still reports the environment's log/settings/certificate warnings. Gameplay feel has not been visually verified.

In Godot:

1. From a fresh player, run `add pp 3` in the console and buy all three Super Jump upgrades. Confirm Air Jump is second and Bounding third.
2. Fully charge a forward Super Jump. Tap Jump just before landing, then shortly after landing on a separate attempt. Both should launch immediately with most momentum retained.
3. Keep timing taps on each landing without sprinting or using Air Jump. Check that several bounds are possible and that the chain eventually runs out of speed. Hold Jump through a whole landing to verify it does not repeat automatically.
4. Unlock super speed, run off a roof, and use Bounding when you land. Compare with a low-speed or shallow landing, which should not qualify.
5. Unlock Dive Bomb and perform it from height. It should not offer a bound. Far above the ground, tapping Jump should still use Air Jump normally.
6. Repeat with Xbox A or a remapped Jump input. Tune timing, retention, drag, and thresholds on PlayerBoundingController based on feel.
