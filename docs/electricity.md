# Electric Shock core

Buy the Electric core in the Powers menu (one token), then select Electricity
in the Alt wheel. Aim with right mouse and hold left mouse to channel lightning.
Controller: LT + X. Existing Aim/Attack rebinding and aim-toggle accessibility
settings apply. The existing Electricity save ID and selector slot are reused.

Default tuning on `PlayerElectricity` in `scenes/player.tscn`:

| Setting | Value |
| --- | --- |
| Damage | 30 per second, tagged `electricity` |
| Range | 30 meters, measured from the hand |
| Heat | 20 per second, including misses |
| Cooling | Shared 0.75-second delay, then 25 Heat/sec |

The shock hits one aimed target through the existing damage interface:
civilians, enemies, and damageable objects. Lightweight civilian capsules
participate through the existing ray lookup. A camera ray resolves aim, then a
hand ray enforces range and cover. Forked lines are decorative; they do not
chain damage to extra targets. The animated RightHand bone anchors the effect.
The core channel does not apply Electrified. Reactive Shock, Thunderstorm, and Lightning Strike are implemented upgrades.

The core uses the same Heat pool and overheat behavior as Fire and Laser Eyes.
At 100 Heat: stop the shock, explode, knock down, cancel flight, and apply
floor(30% of maximum health) damage. Final damage is clamped to the time left
before overheat. Fully cool and release Attack before resuming. Aim release,
power switching, selector/menu opening, focus loss, death, and input reset stop
the effect. Switching powers does not clear Heat.

Lightning is built in code from two flickering ribbons and decorative forks,
with a contact spark/light. One ImmediateMesh holds the ribbons; geometry and
materials are reused and no per-segment nodes, new textures, or third-party
addons are introduced. This basic effect does not add a new audio asset.

## Reactive Shock

Buy the first Electric upgrade. It is passive only while Electricity is selected and does not use Heat. Each accepted melee hit from a `MeleeHostile` independently rolls 20%, or 5% for `SuperHostile`. Bullets, ranged characters, ignored dodge/counter hits, and lethal hits that kill the hero do not trigger it. The triggering hit still damages the hero.

On success the attacker enters `HostileBase.State.ELECTRIFIED`, its current combo is interrupted, movement stops, and its current animation pose freezes. Blue-white procedural lightning sheets surround the body, with a small flickering light. The effect does not overwrite the enemy's materials or debug tint. Supers receive the same status/damage schedule with the lower trigger chance; their existing exclusive melee turn rules remain in place.

| Time after trigger | Damage |
| --- | --- |
| 1 second | 15 |
| 2 seconds | 15 |
| 2.5 seconds / natural expiry | 10 |
| Full duration | 40 |

Time follows the game clock, including Anticipation slow motion and pause. No fractional damage is applied. Long frames catch up the scheduled ticks. The status cannot stack or refresh while active. Death ends it and restores animation playback before the death animation.

Any damaging player attack—including melee, active Electric, Fire, Laser Eyes, or explosions—or a successful player grab cancels the effect immediately. Already dealt damage stays; every remaining tick and the final 10 are discarded. The interrupting attack applies normally, and a grab restores playback before the paired animation takes control.

Tune chances, duration, per-second tick damage, and expiry damage on `Player/PlayerElectricity`. Defaults are 0.20, 0.05, 2.5, 15, and 10. For easy visual testing, temporarily set the relevant chance to 1.0, then restore the defaults.

The effect scene is preloaded and instantiated hidden during player loading to expose its mesh/material combination to Forward+ before the first hit. See [shader inventory and loading notes](shaders.md). This is preparation during player/scene loading, not a universal warm-up of every shader at application launch.

`tests/test_reactive_shock.gd` covers purchase/save gating, chance defaults, accepted and ignored hits, actual enemy swing interruption, frozen animation/movement, exact damage timing, long frames, super behavior, player attack/grab cancellation, death, pause, and visual cleanup. Run with `--render` in graphical Godot for `artifacts/reactive_shock.png`.

Validation: Reactive Shock passed headless and graphical runs; the rendered blue arcs were inspected. Existing Electric core, Anticipation, hostile grabs, melee/super thugs, Powers page, and localization checks passed. Editor import reported no GDScript parse errors, and the Forward+ run compiled the effect without shader errors. Existing command-line user-data/cache/certificate, duplicate UID, and some test shutdown resource warnings remain.

Playtest: unlock Electric and Reactive Shock in Combat Arena, spawn a melee thug, and let it land punches. On a trigger it should freeze with blue arcs, lose 15 HP twice, then 10 HP and resume. Repeat with a super (rarer triggers), punch or grab during the stun, and verify no later ticks occur. Evaded hits and gunshots must not trigger it.

## Thunderstorm

Buy Electricity upgrade 2 and select Electricity in the Alt wheel. A fresh press of Power Special (Q / RT by default, following normal rebinding) begins the cast; Aim is not needed. Holding the button never queues another summon. The control hint shows ready, casting, already-active weather, or cooldown time.

`PlayerThunderstorm` uses UAL1 `Spell_Simple_Enter` (0.533 seconds), a 0.35-second portion of `Spell_Simple_Idle`, `Spell_Simple_Shoot` (0.5 seconds), and `Spell_Simple_Exit` (0.433 seconds). The storm and five-minute cooldown start halfway through Shoot, about 1.13 seconds after pressing Q; the complete sequence takes about 1.82 seconds. A small blue arc uses the existing Electric arc material at the casting hand. No new custom shader or animation asset is added.

The hero plants on the ground or hovers during flight; ordinary airborne casts still fall under gravity. There is no indoor check for this MVP. Other committed actions (roll/counter, melee, charge, slam, wall run, carrying/grabbing, or ship interaction) must finish first. Movement and attack inputs cannot take over during the cast; camera look remains available. Normal shared Heat cooling continues, and summoning adds no Heat or stamina cost.

Accepted damage, death, changing powers, opening menus, focus loss, or losing the unlock cancels casting. Interruption before release starts no cooldown. After release, the storm and cooldown remain even if recovery is interrupted. There is no summon invulnerability and no storm damage, Electrified status, targeted strikes, or other combat effect.

Weather and cooldown belong to the `Weather` autoload and survive scene transfers/player replacement for the session. Cooldown uses scaled gameplay seconds, pauses with the game, and is not saved to disk. An existing storm blocks summoning regardless of cooldown. Storms last until the developer command `weather clear`; Q does not toggle them off. Clearing weather does not reset cooldown, and manual storms do not consume cooldown.

Inspector tuning: `Player/PlayerThunderstorm.cooldown_seconds` (300) and `hold_seconds` (0.35).

Validation: `tests/test_thunderstorm_power.gd` covers tier/selection gating, fresh presses, all four animation phases, release timing, normal damage and interruption before/after release, manual storms, cooldown expiry, menus/power switching/death, shared Heat cooling, actual Q input in flight, no indoor gate, scene transfer, pause, and indefinite weather. Existing Electricity, Reactive Shock, Fire upgrades, Anticipation, input snapshot, weather, day/night, HUD, Powers page, and localization checks pass. The real gym travel test also checks cooldown persistence across two city/interior round trips. Forward+ city captures were inspected with the raised-hand casting gesture/spark, the HUD status, and the resulting rain/clouds; the run confirmed storm activation and a counting cooldown. The command-line environment still reports its existing user-data/cache/certificate and some shutdown resource warnings.

Playtest: buy tier 2, select Electricity, and press Q while standing outside; repeat in flight after clearing weather and allowing cooldown to expire (or temporarily lowering the Inspector cooldown before a cast). Confirm the hand gesture, blue spark, weather fade, and normal movement resuming. Get hit before release to check cancellation without cooldown, and during recovery to check the already-summoned storm persists. Check the HUD after `weather clear`, and hold Q through cooldown expiry to verify it requires another press.

Files for this upgrade: `scripts/player-scripts/player_thunderstorm.gd` and UID; `scenes/player.tscn`; player character, input snapshot, Laser Eyes cancellation, and Anticipation eligibility scripts; `scripts/weather_controller.gd`; gameplay HUD, power progression, and `localization/powers.json`; `tests/test_thunderstorm_power.gd` and UID, Electricity/input/Powers-page/gym-travel tests; `CONTROLS.md`, `CURRENT_CONTROLS.md`, and electricity/weather/shader documentation.

## Lightning Strike

Unlock Electricity tier 3, select Electricity, and stand on the ground during any active thunderstorm (summoned or manual). Q / RT remains the remappable Power Special action. Clear weather still routes Q to Thunderstorm. Strike activation requires a fresh press, no current Heat lockout, and an expired Lightning Strike cooldown. Flight and ordinary airborne casts are blocked.

- Hold at least 0.25 real seconds: a white 9m-diameter circle follows the center-camera ground hit, up to 50m from the hero. Walkable slopes and rooftops are valid; walls, sky, out-of-range points, and targets occluded from the hero are invalid. Release locks that position and plays Spell Simple Shoot, striking halfway through it (0.25 scaled seconds later), then Exit.
- Tap under 0.25 real seconds: the strike/pulse is centered on the ground below the hero. The ground shader radiates outward across the same 4.5m radius. Taps do not slow time.
- A held cast requests 50% speed through the shared `SlowMotion` autoload until impact. The helper changes both `Engine.time_scale` and `AudioServer.playback_speed_scale` together, affecting all music, sound effects, voices, and UI audio. There is no separate audio multiplier or additional audio processing. Overlapping requests use the strongest slowdown; releasing one request leaves other active requests intact. See [helper API](slow_motion.md). Camera look stays responsive, including controller look. The previous time scale is restored on impact, cancellation, pause, menus/focus loss, death, power switching, weather clearing, losing ground contact, and scene teardown. The input threshold uses real time; animation/impact timing uses scaled time.
- Casting is stationary and ignores flinch, movement stagger, and knockdown from incoming hits. Health damage, regeneration delay, damage audio, death, and Reactive Shock remain normal. This armor applies to Lightning Strike, not the existing Thunderstorm summon. Death cancels an unfinished strike.
- Each living, ungrabbed/unthrown `HostileBase` within a horizontal 4.5m radius, on the same elevation (2.5m tolerance) and unobstructed by world geometry, takes 25 impact damage and guaranteed Electrified, including supers, pistol and rifle thugs. The existing 15/15/10 schedule totals another 40 damage. The hero, civilians and ground vehicles are excluded. Helicopters above the ground circle, within the bolt's 80m height, take 25 direct damage with no Electrified status or subsequent tick damage; overhead world geometry blocks the sky strike. A lethal impact does not apply the status. Already-electrified enemies take impact damage without resetting their existing status timer; follow-up player attacks/grabs still cancel remaining ticks as before.
- Impact consumes a 60-second cooldown and fills shared Heat to 100 with the normal full-cooling lockout, but no overload explosion, self-damage, or self-knockdown. Invalid/canceled casts consume neither. Ground electricity lasts one scaled second; its effect remains fixed at the strike position when the hero moves. The sky bolt flashes for about 0.22 seconds with a short light flash and an existing thunder placeholder.

Inspector tuning on `Player/PlayerLightningStrike`: `aiming_time_scale` (0.5), `tap_seconds` (0.25), `strike_radius` (4.5), `target_range` (50), `initial_damage` (25), `cooldown_seconds` (60), `ground_effect_seconds` (1). Electrified continues using the shared Reactive Shock tuning on PlayerElectricity. Both cooldowns remain in the Weather autoload as session state and follow game time/pause; they are not serialized. A [plain-text cooldown area](cooldowns.md) below the Heat/charge indicators shows active timers independently of power selection. The Q hint switches between summon and strike instructions.

Validation: `tests/test_lightning_strike.gd` covers gating, tap/hold, range/sky/wall checks, 9m marker size, all four thug variants, radius/elevation exclusions, 25+40 damage, existing-status preservation, follow-up cancellation, immunity exclusions, safe Heat fill, independent cooldown, effect lifetime/world anchoring, hit armor, adjustable slowdown, and cancellation/restore paths. `tests/render_lightning_strike.gd` exercises physical Q events in Forward+; target, bolt, and one-second ground discharge captures were inspected. Existing summon/core/reactive/fire/counter/input/menu/localization/weather tests pass; real gym travel also checks both cooldowns.

Playtest: unlock all Electricity tiers in Combat Arena, run `weather thunderstorm`, close the console, and spawn mixed thugs. Hold Q and move the camera over the floor, then release; verify the white circle is 9m across and the group receives impact damage followed by Electrified. Quick-tap near enemies for the self pulse. Try targets beyond 50m, sky, flight, and a second press during cooldown. Let bullets hit during aiming to confirm HP drops while the gesture continues. Change `aiming_time_scale` in the Remote Inspector and repeat; open ESC during aiming and confirm normal time on return.

Files for tier 3: new `scripts/player-scripts/player_lightning_strike.gd`, `effects/lightning_strike.gd`, `effects/lightning_ground.gdshader`, and generated UIDs; `scenes/player.tscn`; player character, damage receiver, input snapshot/controller, Laser Eyes, Thunderstorm and Anticipation scripts; weather controller, gameplay HUD, progression and localization; Lightning Strike/input/Powers/Electricity/travel tests; controls and electricity/weather/shader docs. The rendering helper writes only to ignored `artifacts/`.

## Files changed

- `scripts/player-scripts/player_electricity.gd` (new): core damage and tuning.
- `effects/electric_arc.gd` (new): animated lightning and impact visuals.
- `scenes/player.tscn`: PlayerElectricity component.
- `scripts/player-scripts/player_laser_eyes.gd`: shared aiming, Heat, cancellation.
- `scripts/player-scripts/player_power_controller.gd`: Electric core unlock.
- `scripts/ui-scripts/power_menu_progression.gd`: mark core and Reactive Shock implemented.
- `scripts/ui-scripts/gameplay_hud.gd`, `localization/powers.json`: Heat/hints/UI.
- `tests/test_electricity.gd`, `tests/render_electricity.gd` (new),
  `tests/test_powers_page.gd` (updated), and generated Godot UIDs.
- `docs/electricity.md`, `docs/power_selector.md`.

Reactive Shock additions/updates: `effects/electrified.gdshader`, `effects/electrified.gd`, `effects/electrified.tscn`, `scripts/npc-scripts/hostile_electrified.gd`, `hostile_base.gd`, `melee_hostile.gd`, `scripts/player-scripts/player_hostile_grab.gd`, `player_electricity.gd`, progression/localization, `tests/test_reactive_shock.gd`, existing Electricity/Powers page tests, `docs/shaders.md`, and the shader inventory maintenance note in `AGENTS.md`. Generated script/shader UIDs accompany new resources.

## Validation and playtest

Electricity tests cover purchase and saved unlock restoration, gating, held
input, exact damage/Heat at different tick rates, range, hand-relative cover,
misses, lightweight civilians, cancellation, cooling, flying overheat and the
exact health cost. Fire, Fire upgrades, Laser Eyes, selector, HUD, input
snapshot, Powers page/localization and power-attribute regressions passed.
Lightning and the Powers menu were rendered and inspected in the test arena;
full-city manual gameplay remains a player check.

In Godot, unlock Electric, equip Electricity with Alt, and hold RMB + LMB on a
civilian/enemy or damageable object. Check a target behind cover and one beyond
30m. Release either mouse button and switch powers while firing. While flying,
fill Heat and verify the existing explosion, fall, and full-cooling lockout.

Reactive Shock selection fix: `scripts/player-scripts/player_electricity.gd` now checks the active power before rolling a proc. `tests/test_reactive_shock.gd` checks Fire, Frost and Laser Eyes cannot trigger it even with guaranteed proc chance, then verifies it works after selecting Electricity. Updated localization to match.
