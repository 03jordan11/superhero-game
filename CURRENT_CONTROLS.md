# Current controls and skill reference

Source-checked September 24, 2026. This describes the current implementation, including skills that are still placeholders. It is not the planned final design.

These are **default bindings**. Your saved rebindings and Hold/Toggle preferences may differ; check **Escape → Settings → Controls** for your actual assignments. Keyboard keys refer to physical key positions. Xbox labels also describe compatible gamepads.

## Quick controls

| Action | Keyboard / mouse | Xbox |
| --- | --- | --- |
| Move | W / A / S / D | Left stick |
| Look / camera | Mouse | Right stick |
| Jump / charge jump / ascend in flight | Space | A |
| Sprint / flight boost | Hold Shift | Hold L3 / left-stick click |
| Toggle flight / charge Flight Surge | F | Y |
| Attack / active power / dive bomb / held-enemy slam | Left mouse | X |
| Aim / zoom / camera-facing strafe | Hold right mouse | Hold LT |
| Power Special (selected power's special action) | Q | RT |
| Descend in flight | Ctrl | B |
| Dodge Roll | Left Ctrl | B |
| Pick up / drop / charge throw / mission interaction | E | RB |
| Power selector | Hold Left Alt | Hold LB |
| Lock onto enemy / cycle target | Tap Tab | Tap D-pad Left |
| Release target lock | Hold Tab for 0.5 seconds | Hold D-pad Left for 0.5 seconds |
| Gameplay menu: Powers, Gear, Attributes, Journal, Map | P | R3 / right-stick click |
| Pause | Escape | Menu |
| Developer console | Backtick (`) | View |

**P opens the gameplay menu; Tab is target lock.** Older documentation used Tab for the menu. Custom assignments survive default-binding migrations.

## The most important distinction: Attack changes with context

| Situation | What Attack does |
| --- | --- |
| Standing on the ground, not aiming | Punch; timed additional presses continue the three-hit combo, ending in an uppercut. One follow-up press can be buffered. |
| Grounded, empty-handed, Charged Punch unlocked | A quick click punches on release. Hold to charge, then release for the cone attack. |
| Aiming | Reserved for the selected ranged power. A locked or unimplemented selected power does nothing; it does not fall back to punching. |
| Flying or in an active jump, not aiming | Attempts Dive Bomb, if unlocked and a valid target is below you. An already-running punch combo retains priority. |
| Holding a hostile | Requests a ground slam on that enemy. Requires being on the ground and not flying. Further presses can queue the three-slam sequence. |

Dodge Roll and Descend share Ctrl / B for ground and flight contexts. There is no separate block, counter, thunderclap, or telekinesis button at present.

**Dodge Roll:** while moving on the ground, press Left Ctrl / B. Roll in your current movement direction, including sideways or backward while aiming or locked on. Standing still does nothing. Each roll costs **10% of maximum stamina**; insufficient stamina prevents it. All damage, hit slowdown, hit reactions, and knockdown are blocked during the roll. Wall collisions still apply, and leaving the ground ends the roll and its protection. Default tuning is 6 m over 0.6 seconds, with a quick initial burst that tapers to a stop; no roll momentum carries into normal movement. Dodge is available without a power purchase; it cannot start while carrying, already knocked down, charging a jump/surge, or committed to an attack. Ctrl / B still descends while flying.

## Selecting and firing powers

Hold **Left Alt / LB**, point with the mouse / right stick, and release to equip:

| Wheel direction | Power | Current status |
| --- | --- | --- |
| Up | Laser Eyes | Working; requires core purchase |
| Right | Frost | Frost Breath at tier 1: Aim + hold Attack |
| Down | Fire | Working; core and two upgrades |
| Left | Electricity | Working core attack |

The center retains the current selection. Escape cancels. The wheel does **not** pause the world; it suppresses your movement, attacks, and camera input while open. Selecting a power does not unlock it. Release Attack after switching, then press it again to fire.

**Power Special (Q / RT)** uses the selected power's special action. Fire upgrade 2: hold Aim + Power Special for Dragon Breath. Electricity upgrade 2: press Power Special without aiming to summon a Thunderstorm. During any storm, Electricity upgrade 3 uses hold/release for an aimed Lightning Strike, or a quick tap for a pulse around the grounded hero. A fresh press is required; holding the button never automatically recasts.

Manual weather is available through the developer console: `weather thunderstorm`, `weather clear`, `weather lightning`, and `weather` for status. Close the console to resume the effects. Summoned storms persist until `weather clear`; clearing does not reset the five-minute power cooldown. See [weather controls and behavior](docs/weather.md).

| Skill | Purchase needed | How to use | What it currently does |
| --- | --- | --- | --- |
| Laser Eyes | Laser Eyes core | Select Laser Eyes; hold Aim + Attack | Continuous beam, 25 damage/sec, up to 180 m; blocked by cover. |
| Fireball | Fire core | Select Fire; hold Aim and tap Attack | Projectile; 40 damage, 3 m blast, 20 Heat per shot. |
| Charged Fireball | Fire upgrade 1 | Hold Aim + Attack, then release **Attack while keeping Aim held** | Charges over 1.5 seconds; up to 80 center damage, 40 edge damage, 6 m blast. Quick release gives a small fireball. |
| Dragon Breath | Fire upgrade 2 | Select Fire; hold Aim + Q / LT + RT | Continuous 12 m cone, 20 damage/sec. Cover blocks it. Breath takes priority over fireball input. |
| Electric Shock | Electricity core | Select Electricity; hold Aim + Attack | Continuous single-target shock, 30 damage/sec, up to 30 m. Cover blocks it; it is not a chain-lightning or storm attack. |
| Thunderstorm | Electricity upgrade 2 | Select Electricity; press Q / RT, no Aim needed | Brief spell cast summons cosmetic weather. Five-minute cooldown starts on release. Existing storms block activation. Works grounded, airborne, or flying; no indoor gate yet. Hits interrupt the cast. |
| Lightning Strike | Electricity upgrade 3 | Grounded during a storm: hold Q / RT to aim, release to strike; tap for self pulse | 9m diameter, 50m aim range. 25 impact damage + Electrified (40 more). 60s cooldown and full Heat without explosion. 50% game/audio speed while holding through impact; hits damage but do not interrupt casting. |

These figures are current default tuning, not final balance. Fire damage does not currently apply a lingering burn status. Laser Eyes, Fire, and Electricity share one Heat meter; switching powers does not reset it.

### Heat and interrupted attacks

- Beam, shock, Dragon Breath, and fireball charging build 20 Heat/sec; Frost Breath builds 15 Heat/sec. Fireball launch adds another 20 Heat. A fully charged fireball **keeps building Heat** until released.
- At 100 Heat, the existing overheat response causes an area explosion, knocks you down, and damages you for 30% of maximum health. With Fire tier 3 selected and External Combustion ready, a safe full-strength eruption replaces that penalty; during its cooldown normal overheat still applies.
- Heat cools after a short delay. After overheating, it must reach zero before you can fire again.
- Changing powers, menus, focus loss, and other input resets can require a fresh release/press before firing.
- Ranged attacks are blocked during jump/flight charging, ground slam, combat action locks, hostile-grab animations, death, and knockdown.
- Aim cancels enemy lock-on and returns you to manual aiming. Releasing Aim does not automatically restore the lock.

## Movement skills

| Skill | Purchase needed | How to use | Limits / details |
| --- | --- | --- | --- |
| Ordinary jump | None | Tap Space / A on the ground | Ground jump launches on release. |
| Power Jump / Super Leap | Super Leap core; starter power | Hold Space / A on the ground, then release | Charging starts after about 0.2 seconds; charge meter fills over 1.5 seconds. Adds upward and forward launch. |
| Greater Jump | Super Leap upgrade 1 | Same charged-jump input | Automatically increases charged-jump output; no extra button. |
| Air Jump | Super Leap upgrade 2 | Tap Space / A again in the air | One extra jump before landing, including while falling. Half of full charged-jump launch output, including Greater Jump. Not while flying, wall-running, or ground-slamming. |
| Bounding | Super Leap upgrade 3 | Tap Jump just before or shortly after a fast, hard landing | Full-height rebound retaining 90% of horizontal momentum. Default timing: 0.12 s before landing or 0.25 s after. Needs at least 16 m/s horizontal and 12 m/s downward speed. Dive Bomb landings do not qualify. |
| Boosted sprint | Super Speed core | Move + Shift / L3 | Adds the core's +5 Speed bonus and enables stamina-consuming sprint. Ordinary movement remains available without it. |
| Endurance | Super Speed upgrade 1 | Automatic during sprint | Halves boosted-running stamina drain. Does not halve flight-boost drain. |
| Wall Running | Super Speed upgrade 3 | Move into a near-vertical wall while sprinting | Automatic entry on wall contact. Runs upward; A/D or lateral stick steers sideways. Tap Jump to leap away. No entry while carrying something, flying, or ground-slamming. Stop movement to leave the wall. |
| Flight | Flight core | Tap F / Y | Toggle flight. Move with WASD / left stick; Space / A ascends, Ctrl / B descends. With no movement input, settle into hover. |
| Flight Boost | Flight upgrade 1 | While flying, move + Shift / L3 | Uses stamina; separate unlock from ground sprint. |
| Dive Bomb / ground slam | Flight upgrade 2 | While flying or in an active jump, release Aim and press Attack | Needs a valid landing target at least 4 m below you. Cannot activate while carrying anything. Simply walking off a ledge is not the same as an active jump in the current input logic. |
| Flight Surge | Flight upgrade 3 | At **full stamina**, hold F / Y, then release | Uses the entire stamina bar. Launches straight up from the ground, or along character facing in the air. Longer hold increases launch strength. A short tap still toggles flight. |

Wall Running is upgrade 3: tiers must be purchased in order, including the currently planned Fast Reflexes tier before it.

### Stamina

Boosted running and flight drain stamina; normal movement and normal flight do not. Release Sprint/Boost (or toggle it off) to recover. Continuing to request boost prevents recovery even when exhausted or blocked by a wall. Ordinary jumping/falling freezes stamina recovery; recovery works while grounded or in unboosted flight. Exhaustion clears after reaching 20% of capacity; Flight Surge requires 100%.

## Physical combat and target lock

- **Regular punches:** use Attack without Aim. Repeated presses chain the combo; the third hit is an uppercut. Ordinary punch damage scales with Strength.
- **Lock-on:** tap Tab / D-pad Left to acquire or cycle visible aggressive enemies. Hold for 0.5 seconds to release. It acquires within 60 m and breaks beyond 80 m or after sustained obstruction. Manual camera look is suppressed while locked. Ordinary civilians are not lock-on targets.
- **Opening punch dash:** a normal opening punch can automatically close distance to a suitable locked enemy. This is contextual, not a separate key.
- **Charged Punch:** requires Strength upgrade 1, grounded and empty-handed. Hold Attack without Aim; charging starts at 0.25 seconds and reaches full power at 1 second total hold. Release for a forward cone attack. Nearby targets take more damage than distant ones; walls block it. Supers resist its knockdown.
- **Strength core:** passive +5 Strength. It does not itself grant vehicle pickup; that requires upgrade 2.

## E / RB: pickup, throws, rescues, and ships

The same interaction button changes behavior according to what is nearby or already held. Ship interactions are checked first. Otherwise, with empty hands, pickup checks rescue patients, then eligible hostiles, then vehicles.

| Target / situation | Input | Current behavior |
| --- | --- | --- |
| Nearby rescue patient | Press E / RB | Pick up the injured civilian; no Vehicle Throw unlock required. Must be within 4 m and unobstructed. |
| Carrying rescue patient | Press E / RB again | Safely set them down; they cannot be thrown. Set down inside the hospital's green ring to complete the rescue. |
| Nearby normal hostile | Press E / RB | Grab a living, grabbable enemy in front of you, roughly within 2.5 m and clear line of sight. Supers/brutes cannot be grabbed. |
| Holding hostile | Tap E / RB | Drop them; a hold shorter than 0.2 seconds counts as a drop. |
| Holding hostile | Hold E / RB, then release | Charge and throw; full charge at 1.2 seconds. |
| Holding hostile while grounded | Attack | Slam them; further presses chain up to three slams. |
| Vehicle | Point camera at it and press E / RB | Pick up with **Strength upgrade 2: Vehicle Throw**. The camera ray must hit a Vehicle within its 12 m range. |
| Holding vehicle | Tap E / RB | Drop it. |
| Holding vehicle | Hold E / RB, then release | Throw in camera-facing direction; at least 0.2 s hold, full charge at 1.2 s. |
| Ship-docking mission interaction point | Press E / RB | Attach to the push/reel interaction. While attached, forward movement applies push effort; backward movement applies reel effort. Press E / RB to detach. Pushing requires flight. |

You cannot pick up another person or vehicle while already carrying one. Pickup is contextual: ordinary wandering civilians are not rescue patients. Carrying allows traversal, but prevents Wall Running and Dive Bomb entry. Hard landings while carrying a rescue patient subtract five seconds from the mission's preview timer; reaching zero currently does not fail the rescue.

## Skills that are listed but do not work yet

**Purchasing a PLANNED tier currently reserves that tier; it does not implement the move.** The progression system permits these purchases, which is why owning a tier can still produce no new behavior.

| Branch | Working now | Planned / inactive |
| --- | --- | --- |
| Super Leap | Core, Greater Jump, Air Jump, Bounding | Strength-based jump scaling |
| Super Speed | Core, Endurance, Wall Running; manual Dodge Roll is available independently | Upgrade 2: Fast Reflexes has no additional effect yet |
| Flight | Core, Boost, Dive Bomb, Flight Surge | Strength-based Dive Bomb damage scaling |
| Strength | Core bonus, Charged Punch, Vehicle Throw | Upgrade 3: Thunderclap |
| Mind | Core Trouble Sense: passive pointer toward active encounters | Anticipation/counter, Telekinesis, Bullet Reversal |
| Laser Eyes | Core beam | Efficient Beam, Focused Beam, Laser Spin |
| Frost | Frost Breath, Frost Wall | Frost fists/core, Frost Armor, Frost Trails |
| Fire | Core Fireball, Charged Fireball, Dragon Breath, External Combustion | Lingering burn status |
| Electricity | Core Electric Shock, Reactive Shock, Thunderstorm, Lightning Strike | — |

Trouble Sense needs an active encounter to point toward; it is not a manually fired Mind attack. Developer-spawned encounters can display their debug waypoint even without this unlock.

Attributes currently affect physical punch damage (Strength), boosted movement (Speed), and health/stamina/flight-knockdown resistance (Resilience). Shared Heat capacity does not yet scale with Resilience. Planned hidden abilities such as water running or general bullet immunity should not be expected from high stats alone.

## Menus, map, and settings

- **P / R3:** open the gameplay menu. Purchase powers in Powers; view progression in Attributes; inspect the world in Map.
- **Map tab:** mouse wheel zooms; hold left mouse and drag to pan; double-click left mouse resets the view.
- **Escape / Menu:** pause. Settings → Controls shows actual current bindings and lets you rebind actions.
- Sprint/Boost and power aiming have Hold/Toggle preferences. If using toggle mode, a press enables the intent and another press disables it. This does not turn Attack into a toggle.
- The minimap can be enabled/disabled in Gameplay settings; it has no separate default gameplay key.
- Controller menus use D-pad navigation, A to confirm, B to go back. LB/RB switch settings tabs. Menu navigation is separate from gameplay controls.

## Quick troubleshooting

| Symptom | Check |
| --- | --- |
| Attack does nothing | Release Aim for melee. If aiming, verify the selected power is implemented and purchased. Check Heat, knockdown, and other active charge/combat animations. |
| Power Special (Q / RT) does nothing | Fire: select Fire, buy Dragon Breath, and hold Aim. Electricity in clear weather: tier 2 summons, blocked by its five-minute cooldown. During a storm: tier 3 requires ground contact, no Heat lockout, and its own 60-second cooldown; release then press Q. Aimed strikes need valid ground within 50m. |
| Fireball charges but never fires | Release Attack while keeping Aim active; releasing Aim cancels the charge. Do not hold through overheat. |
| Shift / L3 does nothing | Ground sprint requires Super Speed core; airborne flight boost requires Flight upgrade 1. Recover stamina with boost released. |
| Holding F / Y does not surge | Flight upgrade 3 and a full stamina bar are required. Use a short tap for ordinary flight toggle. |
| Clicking in the air does not slam | Buy Flight upgrade 2; release Aim; empty your hands; ensure a valid target at least 4 m below and flight/active-jump state. |
| E / RB does not pick up a car | Buy Strength upgrade 2, empty your hands, and point the camera directly at a nearby vehicle. Mind/Telekinesis is not implemented. |
| Purchased upgrade has no visible effect | Check the PLANNED table above. Some working upgrades are passive and have no activation button. |
| Mouse will not freely orbit | Release target lock with a 0.5 s hold of Tab / D-pad Left, or activate Aim for manual aiming. |
| Controls differ from this sheet | Check saved rebindings in Settings → Controls. This file lists defaults, not your private saved settings. |

## Optional developer testing

Open the console with Backtick / View. It pauses gameplay while open. `help` lists commands; Tab completes; Up/Down browse history. Escape/B closes it.

- `add pp 20`: adds purchase points so you can buy tiers in the Powers menu; does not directly activate all skills.
- `spawn melee_thug 1`, `spawn pistol_thug 1`, or `spawn super_thug 1`: compare melee, ranged, and super enemies.
- `spawn rescue`: test rescue pickup/carry/drop-off with a random civilian.
- `status`: inspect current stats/progression information.

Purchases and explicit saves can persist progression. Use these commands only when you want to change your test/save state.

## What this reference was checked against

Runtime bindings: [input_bindings.gd](scripts/input_bindings.gd). Implemented tiers and purchases: [power_menu_progression.gd](scripts/ui-scripts/power_menu_progression.gd). Ability gates: [player_power_controller.gd](scripts/player-scripts/player_power_controller.gd). Inputs and action priority: [player_character.gd](scripts/player-scripts/player_character.gd), plus the input, movement, combat, target-lock, ranged-power, stamina, pickup, and ship-interaction scripts in `scripts/player-scripts/`. Menu labels: [powers.json](localization/powers.json).

This was a source review for documentation. No gameplay behavior was changed or visually retested for this document.

External Combustion (Fire tier 3): without aiming, hold Q / RT to charge shared Heat at 50% per second, hold safely at 100%, then release. 10–100% Heat gives a 1–8m radius and 10–70 damage, knocking back enemies including supers. Every eruption vents Heat and starts a 300-second cooldown. Aim + Q / LT + RT remains Dragon Breath. Charging is stationary, works in flight, and takes damage without flinching. The explosion slows game/audio to 50%; this and other power slowdowns now ease in/out through the shared helper.

Frost tier 1: select Frost with Alt, then hold RMB + LMB (controller LT + X) for Frost Breath. Uses the same 12m cone / 3m end radius as Dragon Breath and builds 15 Heat/sec. It slows movement and attacks, freezing regular enemies after 3s and supers after 5s. Frozen damage is 10/sec for 5s; continued breath refreshes duration. Three melee hits or a grab break the ice. Tier 2 adds Frost Wall: hold RMB + Q (LT + RT), then release Q to cast within 50m, grounded or flying. Adds 20 Heat and a 300s cooldown. See `docs/frost.md` and `docs/frost_wall.md`.
