# Frost Wall — tier 2

Select Frost and purchase tier 2 (Frost Armor & Wall). Hold Aim + Power Special (RMB + Q; controller LT + RT) to preview a pale blue rectangle on supported ground, then release Q/RT while still aiming to cast. Q alone remains unused. Armor is still planned.

The wall is 8m wide, 2m deep and 4m high, perpendicular to the horizontal direction from the player to the target. Range is 50m from the player, including height when flying. All footprint corners need near-level support; solid obstacles, low ceilings, gaps, blocked sight lines and placements overlapping the caster are rejected. Invalid placement hides the preview and release spends nothing.

Aiming plants the player or hovers in flight. Game and audio ease to 50% speed through SlowMotion, then ease back on release/cancel. Controller camera aiming uses real time. Releasing Aim, changing power, opening a menu, losing focus or dying cancels without spending Heat or cooldown. Nonfatal hits still damage health but cannot stun, interrupt, or knock the caster out of flight.

Release erects the wall immediately, costs 20 shared Heat and starts a 300-game-second cooldown. Normal overheat applies if this fills Heat. The existing HUD shows Frost Wall's remaining cooldown, which survives scene changes in the current session. `reset cooldowns` clears it too.

NPC collision shapes overlapping the rising wall take 50 damage once and launch away from the caster at 12m/s horizontally and 8m/s upward, including supers. Frozen/electrified NPCs have their immobilizing state canceled so they can launch. Grabbed/thrown hostiles are excluded from conflicting physics ownership. An overlapping helicopter takes 50 direct damage without launch or status. The player never takes the wall's hit. Dimensions, range, damage, launch speeds, duration, cost, cooldown and slow-motion multiplier are Inspector exports on `Player/PlayerFrostWall`.

The StaticBody3D blocks movement and shots for everyone from creation until expiry at six game seconds. It has no destructible health. Launched NPCs temporarily ignore this wall's movement collision until their capsules clear it; raycasts still hit the wall immediately. It grows visually over 0.2s and develops cracks before disappearing. It reuses `effects/frozen_ice.gdshader`; a hidden WallPreparation mesh prepares the material during player loading, without claiming complete pipeline warm-up.

## Changed files

- New `scripts/player-scripts/player_frost_wall.gd`, `effects/frost_wall.gd`, `tests/test_frost_wall.gd`, and Godot-generated UIDs.
- `scripts/player-scripts/player_character.gd`, `player_laser_eyes.gd`, `player_damage_receiver.gd`, `player_input_controller.gd`: cast ownership, cancellation, hit protection and controller aiming.
- `scripts/weather_controller.gd`, `scripts/ui-scripts/developer_commands.gd`: session cooldown and reset command.
- `scripts/ui-scripts/gameplay_hud.gd`, `power_menu_progression.gd`, `localization/powers.json`, `scenes/player.tscn`, `scenes/ui/gameplay_hud.tscn`: component, tier availability, hints and cooldown text.
- `tests/test_developer_console.gd`; graphical harness `tests/render_frost_wall.gd`; `CONTROLS.md`, `CURRENT_CONTROLS.md`, `docs/frost.md`, `docs/cooldowns.md`, `docs/shaders.md`, and this document.

## Validation

Godot 4.7.2 editor/import check found no GDScript parse errors. Eleven headless suites passed: Frost Wall, Frost Breath, Lightning Strike, External Combustion, developer console, power selector, localization, input snapshot, control bindings, SlowMotion and Anticipation. Existing user-data/certificate/resource-cleanup warnings remain.

The Frost Wall suite checks actual collision overlap, all four thug variants' health and launch movement, helicopter damage without displacement, two-sided shot blocking, player/enemy movement collision, six-second expiry, cast armor in flight, placement rejection, cancellation, normal overheat, HUD cooldown and scene teardown. The graphical harness uses real RMB/Q events; preview, launch, wall and expiry captures were inspected in Combat Arena.

## Playtest

Resize update: defaults are now 8m wide × 2m deep × 4m tall. Changed `scripts/player-scripts/player_frost_wall.gd`, `effects/frost_wall.gd`, `tests/test_frost_wall.gd`, `localization/powers.json`, and this document. The Frost Wall headless suite passed with targets spread across the enlarged footprint, high shots near its outer edge, and obstacle rejection at the new edge. No GDScript parse errors; this resize was not visually verified.

In Combat Arena, unlock Frost tier 2, aim the rectangle through each thug variant and release Q. Check 50 damage, upward/backward launch, collision after landing, and shots blocked from both sides. Repeat from flight, take bullets while aiming, and try unsupported/obstructed ground. Check 20 Heat, the five-minute cooldown, `reset cooldowns`, and disappearance after six seconds.
