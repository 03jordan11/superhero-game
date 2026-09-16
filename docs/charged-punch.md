# Charged Punch

Implemented as Strength upgrade 1, using the existing attack binding (LMB / Xbox X). Existing saves with Strength upgrade 1 or higher gain it through the normal ability sync.

## Behavior and tuning

Select `Player/PlayerCombatController` in the Inspector; settings are under **Charged Punch**.

| Setting | Default | Behavior |
| --- | --- | --- |
| Charge Start Delay | 0.25 s | Shorter clicks perform a regular punch on release. Before unlocking, ordinary punches retain their original press timing. |
| Charge Full Time | 1 s | Total hold time including the initial 0.25 s. Continues holding at full power until released. |
| Charge Range | 10 m | Distance from the player's chest to the target's chest. |
| Charge Cone Degrees | 60° | Total angle, 30° either side of forward. |
| Charge Near Distance | 2 m | Full-charge hits within this radius deal 100 damage. |
| Charge Max / Min Damage | 100 / 30 | Full charge falls linearly from 100 at 2 m to 30 at 10 m. Partial charge interpolates from 30 toward that distance-based result. |
| Charge Windup Duration | 0.4 s | Rear-back animation after crossing the hold threshold. Early release completes this motion before punching. |
| Charge Impact Delay | 0.2 s | Contact moment in the release animation; damage and the wind burst fire together. |
| Charge Sound Delay | 0 s | Sound starts with the forward punch, 0.2 seconds before impact by default. |
| Charge Recovery Duration | 0.7 s | Release duration; timed recovery prevents animation overrides from trapping combat. |
| Charge Wind Enabled / Duration | On / 0.45 s | Short expanding wind burst at impact, including missed punches. |
| Charge Wind Color | Pale blue-white, 0.5 alpha | Color and opacity of the pressure arcs and air streaks. |

Charging is a grounded, empty-handed action. Movement pauses while the punch is loaded and during release. Normal combo taps, opening dashes, airborne ground slam and held-enemy slams retain their respective routes. A new attack press survives the previous regular combo's recovery.

Each release checks hostiles once. Every living hostile in the cone can take one hit. Other hostiles don't shield each other; solid scenery blocks the cone. Uses the existing knockback reaction and respects `knockback_resistant` (supers take damage but stay standing). No forced knockdown and no extra Strength multiplier beyond the stated damage range.

Wind feedback follows the attack's orientation, range and cone angle at impact. It uses one cached 768-triangle shell and one transparent shader draw per active burst, with no particles, lights, shadows, or bloom. Broken pressure arcs and streaks travel outward and fade; the world-space burst does not turn when the player looks away. Each instance removes itself after its short duration. Normal depth testing hides the surface behind scenery; this cosmetic shell is not a damage volume or a collision simulation.

Death, knockdown, losing ground contact, starting aimed powers, opening menus/focus loss/input reset, or losing the unlock cancel charging. Bullet hits retain the existing combat interruption protection. No charge is fired by a canceled release.

## Blender animations

- `assets/animations/authored-combo/source/hero_charge_punch.blend`: editable source on the existing hero rig, retaining the 29 previous combat/grab actions plus three new clips.
- `Hero_ChargePunchWindup`: 0.4-second right-hand rear-back with planted feet and torso coil.
- `Hero_ChargePunchHold`: seamless 1.5-second loaded pose with subtle movement.
- `Hero_ChargePunchRelease`: 0.7-second forward punch, contact at 0.2 seconds, recovery to guard.
- `hero_combo.glb`: shared Godot AnimationLibrary; only the hold loops. Existing humanoid bone mapping is preserved. No actor root translation.
- `charge_punch_manifest.json`: duration, loop and contact metadata.

Rebuild with Blender `--background --python assets/animations/authored-combo/tools/build_charge_punch.py`, then Godot `--headless --path . --script assets/animations/authored-combo/tools/configure_grab_import.gd`, then editor import. The builder loads `hero_combat_grabs.blend` and appends the charge actions. Rebuilding replaces generated outputs; preserve hand-edited source changes separately.

## Validation and play test

`tests/test_charge_punch.gd` covers the unlock, tap/hold threshold, release timing, cross-combo input, controller button, indefinite hold, one-hit cone damage/falloff, geometry blocking, super resistance, cancellation, and imported animation tracks. Run it with Godot `--headless --path . --script tests/test_charge_punch.gd`. Optional `-- --render` with a rendering display saves actual player pose captures in `artifacts/charge_punch`.

Also checked: existing authored combo, grab animations, hostile grabbing, opening dash, melee dash recovery, combat audio, and gameplay menu regression tests. Blender key poses and imported Godot player poses were rendered and inspected. The manual city combat feel still needs user testing. Existing environment warnings about user storage, certificates and city resource UID fallbacks remain separate from these checks.

In Godot:

1. Open Powers with **P**, buy Strength and its first upgrade (developer console `add pp 2` if points are needed).
2. Tap LMB several times: regular punches and lock-on opening dash should still work.
3. Hold LMB for at least one second: the hero rears back and stays loaded. Release to punch forward.
4. Try several thugs spread within the front cone at different distances. Nearer enemies should take more damage; all susceptible survivors should fall. Supers should take damage without falling.
5. Try a short charge, a wall between you and an enemy, a target beside/behind you, and releasing after opening a menu or getting knocked down.

## Files changed for this feature

- `scripts/player-scripts/player_combat_controller.gd`: charge state/input classification, cone, tuning, recovery.
- `scripts/player-scripts/player_character.gd`: attack press/release and aim cancellation.
- `scripts/player-scripts/player_input_controller.gd`: charge reset on interrupted input.
- `scripts/player-scripts/player_abilities.gd`, `player_power_controller.gd`: registered Strength unlock.
- `scripts/player-scripts/player_sound_manager.gd`: existing charge-punch sound at the start of the forward swing.
- `effects/charge_punch_wind.gd`, `effects/charge_punch_wind.gdshader`: shared cone shell, animated wind shader and automatic cleanup.
- `scripts/ui-scripts/power_menu_progression.gd`, `localization/powers.json`: implemented upgrade and description.
- `assets/animations/authored-combo/hero_combo.glb`, its `.import`, `source/hero_charge_punch.blend`, `charge_punch_manifest.json`: animation assets/import configuration.
- `assets/animations/authored-combo/tools/build_charge_punch.py`, `configure_grab_import.gd`: reproducible Blender build and loop configuration.
- `tests/test_charge_punch.gd`, `tests/test_grab_animations.gd`: new behavior checks and updated combined library count.
- `CONTROLS.md`, this document, and the animation `README.md` / `GRAB_ANIMATIONS.md`: controls, tuning, rebuild order and test notes.
