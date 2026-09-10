# Player architecture review and rework backlog

Updated: 2026-09-10. This replaces the earlier migration plan with the current audit, the user's decisions, and the limited fixes authorized afterward.

## Gameplay tuning todo

- [ ] **Revisit Bounding's gameplay feel.** User playtest feedback: the ability needs more work; defer implementation changes until a later tuning pass. Review landing timing, input buffering, momentum retention/drag, and chain eligibility during playtesting; specific problems and preferred adjustments have not yet been defined. Current implementation and tuning reference: [BOUNDING.md](BOUNDING.md).

## Scope and current architecture

Reviewed all 26 scripts in `scripts/player-scripts`, `scenes/player.tscn`, and the player-facing parts of animation loading, health/damage, vehicles/explosions, lightweight civilian damage, HUDs, powers, saves, developer tools, and tests. The project targets Godot 4.7 with Jolt Physics and Forward Plus; validation uses the installed Godot 4.7.2.

At the initial audit, `player_character.gd` had 407 lines (327 nonblank/noncomment lines), including 45 exported properties. The player directory contained 3,103 lines across 26 scripts. These are historical audit measurements, before this cleanup.

The player is already substantially decomposed:

- Coordinator/body: `player_character.gd`.
- Movement: state machine/base state, normal movement base, movement motor, grounded, airborne, jump charging, flight, ground slam, wall run, knockdown, and death states.
- Gameplay components: stats, ability flags, combat, damage receiver, status effects, vehicle interactor, and landing impact controller.
- Presentation: animation controller, camera effects, sound manager, landing target, and encounter indicator.
- Outside the player directory: developer readouts (`player_hud.gd`), gameplay HUD, camera testing, power menu/progression, saving, shared health/damage, vehicle explosions, and civilian representation handoff.

File length is not the primary problem. States still share mutable flags/timers on the body; action permissions, movement writes, animation decisions, and transition side effects can disagree. Keep the existing components and improve ownership incrementally instead of adding abstractions solely to reduce line counts.

## Authorized work completed in this pass

### Jump charging: cancel on lost contact and block punches

`PlayerJumpChargingState` now checks actual floor contact both before its physics update and after movement. Lost contact transitions to Airborne; the existing exit clears charge, hold time, the charging flag, and its HUD event. Charging is not automatically turned into a jump when support disappears.

Player mouse routing and `PlayerCombatController.request_punch()` both reject punches while charging. Ordinary grounded punching and released charged jumps remain available. Other action-permission decisions are deferred.

Files: `player_jump_charging_state.gd`, `player_character.gd`, `player_combat_controller.gd`.

### XP overflow protection

Godot integers are signed 64-bit values. The largest supported positive value is 9,223,372,036,854,775,807. The previous formula multiplied `100 * 2^(level - 1)` without checking this limit. At level 58 it overflowed and returned a negative requirement; higher values could also break the level-up loops.

The implementation now uses exact integer shifts while the result fits. From level 58 onward, the requirement saturates at the largest supported positive integer. Existing progression through level 57 is unchanged. XP grants avoid overflowing accumulated XP, and the level counter cannot wrap at the integer storage limit. This does not cap Strength, Speed, or Resilience as a gameplay design choice.

Save-number conversion now rejects nonfinite floats and clamps values at signed integer boundaries before conversion. This matters because JSON parsing may round a large saved integer to a floating-point value just outside the integer range.

Files: `player_stats.gd`, `save_manager.gd`.

### Lightweight civilian damage lookup

The lightweight population now has an incremental spatial lookup with 8-metre horizontal cells. Capsule creation, movement/teleports, representation replacement, and tree exit update membership. Ordinary attacks retrieve overlapping cells, then perform the existing exact 3D capsule-distance check. Large-radius queries inspect occupied cells instead of iterating an enormous empty rectangle.

The lookup includes only lightweight civilians. Full bodies continue through the normal physics query, preserving the existing protection against double hits during representation handoff. Melee candidates retain scene order so overlapping-target selection is unchanged. Pending damage still waits for the existing safe promotion path.

A focused regression with 202 civilians returned only two nearby candidates for a small attack. This verifies reduced candidate work, not a measured rendered-FPS improvement.

Files: `civilian_capsule_lod.gd`, `capsule_civilian.gd`.

### Hidden debug HUD

Hidden diagnostic controls no longer format strings or update bars. The HUD keeps the latest raw movement/charge/landing events, reads current health and XP on show, and refreshes all controls when its CanvasLayer becomes visible. Visible readouts continue to update normally. Developer controls, camera testing, performance monitors, and the gameplay HUD remain available.

File: `scripts/ui-scripts/player_hud.gd`.

### Unused material removed

Reference searches covered scripts, scenes, and tests before removal:

- Hidden placeholder `Player/MeshInstance3D` and its unused capsule mesh resource. The real character model and `CollisionShape3D` remain.
- Test-only `PlayerCharacter.get_stats()` and `_get_run_speed()` wrappers. Tests now access the existing stats resource directly; the active speed helpers on `PlayerState` remain.
- Test-only `PlayerVehicleInteractor.get_throw_charge_percent()`. Tests check the underlying reset state; HUD charge calculations remain active.
- Empty production `PlayerState.handle_input()` hook and its per-tick state-machine dispatch. All gameplay state input already arrives with physics updates.
- Unconsumed `PlayerCharacter.health_depleted` and state-machine `state_changed` signals. Damage receiver death requests and real health signals remain. State tests still verify transition ordering through enter/exit callbacks.
- Bypassed state-machine `initial_state` export. Initialization still uses its explicit starting state, or the first registered state when omitted.
- Unused `force` argument on the vehicle throw-charge publisher.
- Obsolete `project.godot` reference to missing `localization/powers.en.translation`. Powers/HUD text continues to load from `localization/powers.json`.

No entire player script was unused. Ability placeholders, developer ability toggles, the power-menu prototype, stored money, diagnostic HUD, landing marker, and camera testing were retained: they have live development/UI/save uses and are not dead code.

The pre-existing unindented assertion in `tests/test_player_scene.gd` was also corrected so scene validation can run.

## Correctness backlog: preserve these decisions

The numbers below match the original audit discussion. Do not interpret this backlog as authorization to implement every item.

| ID | Priority | Finding | User decision / status |
| --- | --- | --- | --- |
| C1 | P1 | Lethal damage during a transition can fail to enter death | Still open. Not included in the requested fixes; prioritize when the next implementation scope is chosen. |
| C2 | P2 | Interrupted jump charging leaves stale state or loses release input | Fixed in this pass: cancel on lost floor contact and prevent punches while charging. |
| C3 | P2 | Landing effects retain earlier downward speed / pending slam | Deferred to today's player rework. |
| C4 | P2 | Ground slam can overshoot and oscillate around a vanished target | User marked N/A. Left unchanged; retain evidence below. |
| C5 | P2 | Action permissions overlap across flight, combat, vehicle interaction, etc. | User will define the rules later today. Only C2's explicit punching rule changed. |
| C6 | P2 | Developer UI keyboard input leaks into gameplay; slam ray runs from input callback | Leave for now; developer menu is temporary testing UI. No input-routing rework performed. |
| C7 | P2 | Invalid Inspector values can create nonfinite movement | User marked N/A. Left unchanged. |
| C8 | P2 | XP requirement overflow | Protected in this pass. |
| C9 | P2 | Physics shape-result cap can omit damage targets | Explanation requested; no masks or result limits changed. |

### C1: Death can be lost during knockdown entry

Reproduced in an isolated headless world using a real Vehicle and ExplosionController:

1. Enter flight-collision KnockedDownState.
2. Its entry spawns a hard-landing effect and applies radius damage.
3. A nearby vehicle is destroyed and immediately explodes.
4. Explosion damage depletes player health while `_transition_in_progress` is true.
5. The state machine rejects DeadState; the player logs "Player could not enter DeadState."
6. Knockdown recovery returns to GroundedState with health 0 and `is_dead == false`.

Further damage is rejected by the already-depleted health component. Possible fixes include a pending transition with death priority or moving damage-producing effects outside the transition lock. Merely removing the guard would introduce reentrancy/order risks.

Inspect: `player_state_machine.gd::transition_to_state`, `player_knocked_down_state.gd::enter`, `player_landing_impact_controller.gd::spawn_hard_landing_effect`, `explosion_controller.gd::_apply_radius_damage`, `player_character.gd::_die`.

### C3: Landing lifetime and interruption cleanup

Flight entry resets normal landing classification but not `max_effect_downward_speed`. The initial probe retained 60 m/s, then a zero-velocity landing spawned an impact with maximum camera shake. `ground_slam_impact_pending` can also survive an obstacle-ending slam and affect a later landing; flight/death do not explicitly clear it.

The rework should establish whether impact strength means actual contact speed or an intentionally accumulated power, then give both tracking paths explicit start/reset/finish rules. This pass intentionally does not change that behavior.

### C4: Ground-slam target loss

Ground slam stores a world position and moves toward it at full speed. Completion checks collision or distance <= 0.1 metres. If a targeted vehicle moves or a surface disappears, the player can overshoot the point every tick; the initial movement probe alternated between about 1 and 20.33 metres from the target. Slamming also blocks the ordinary flight toggle.

Future options: detect target crossing, clamp the final step, revalidate the target, and/or provide a timeout/cancellation rule. User marked this N/A for the current pass.

### C5: Permissions still to define

Flight can begin during an active punch; punch momentum runs after flight movement and can overwrite it. Wall-run entry lacks a combat lock. Pickup/throw is gated by death but can still run during knockdown or ground slam. Turning off an already-active flight ability does not stop existing flight.

Define which actions are allowed together, which interrupt others, and what happens to charge/carry/animation state on each interruption. Do not build a generalized permissions framework before these rules are chosen.

### C6: Input timing and developer UI

Developer-menu filtering blocks mouse events but not physics-polled keyboard actions. Focused UI controls can therefore share keys with movement/powers. Ground-slam targeting also queries physics space from `_input()`; Godot recommends direct queries during `_physics_process()` because the space may otherwise be locked. The latter is an engine-timing concern independent of whether the menu is retained.

Both remain unchanged in this pass per the user's instruction to leave item 6. Source: https://docs.godotengine.org/en/stable/tutorials/physics/ray-casting.html

### C7: Unsafe tuning values

Setting `max_jump_charge_time` to 0 produced `(nan, nan, nan)` launch velocity. The HUD protects its division; `_release_jump()` does not. Other unrestricted rate/threshold exports permit contradictory or negative settings. Use Inspector ranges and runtime numeric guards when this tuning surface is revisited. User marked this N/A for the current pass.

### C9: What the 32-result limit means

`intersect_shape(query)` defaults to at most 32 overlapping physics-shape results. It does not promise 32 enemies, nor all enemies inside the radius. A result can belong to scenery, a vehicle, or one of multiple shapes on the same body.

For example, if an impact overlaps 40 damageable actors plus nearby scenery, only up to 32 shape hits are returned. The code then ignores scenery and deduplicates bodies, but the omitted results never reach that filtering code. Some actors inside the advertised radius can therefore receive no damage.

This affects the existing landing and explosion queries; melee also uses a capped shape query. The new lightweight-civilian spatial lookup fixes a separate whole-population scan and does not remove the physics result cap for full bodies.

A future fix should use intentional collision layers/masks to exclude irrelevant shapes, choose a result budget suitable for the intended crowd size, and handle/test saturation. Raising the limit alone only moves the cutoff. No result-limit or collision-layer changes were authorized here.

Source: https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate3d.html

## Performance backlog

| ID | Finding | Decision / status |
| --- | --- | --- |
| P1 | Missed punches retry allocating queries and searching until the animation ends; late hits are possible | Deferred to player/combat rework. |
| P2 | Lightweight civilian damage scans the entire active population | Replaced with incremental nearby-cell lookup in this pass. |
| P3 | Encounter marker scans encounters and formats distance text every render frame | Leave unchanged; encounters will be rewritten. |
| P4 | Hidden diagnostic HUD performs presentation work | Fixed: cache raw values while hidden; refresh controls when visible. |
| P5 | Landing/explosion bursts allocate effects, materials and meshes; decals remain for several seconds | Explanation requested; no pooling or effect changes made. |
| P6 | Animation setup duplicates clips and retargets flight tracks during player creation | Deferred to today's workup. This is startup work, not per-frame retargeting. |

### What profiling effects means

Yes: exercise heavy landings and explosion chains and measure whether they slow the game down. Profiling adds evidence about which part is expensive, instead of relying only on how it feels or average FPS.

Use a rendered game and Godot's profiler/visual profiler. Compare idle, one impact, repeated impacts, and several simultaneous/chained vehicle explosions. Watch CPU frame time, GPU frame time, frame-time spikes, draw calls, and live effect counts. At 60 FPS the total frame budget is about 16.7 ms; occasional long frames can cause visible stutter even when average FPS looks fine.

Current landing effects allocate particle materials/meshes and keep their decal/effect node for about eight seconds. They do have cleanup; this audit did not establish a permanent gameplay leak. A burst could still cost more than a single effect. Measure before introducing pooling, prebuilt shared resources, reduced particle counts, or stricter effect budgets.

The custom player timing monitor reports selected CPU callbacks, with overlapping categories. It does not measure complete rendering, GPU particle cost, skeletal evaluation, or UI layout. Headless regression tests cannot settle these visual performance questions.

## Architecture and integration recommendations for the rework

- Keep PlayerCharacter as the body/coordinator: initialize collaborators, order updates, expose actual public APIs, and call `move_and_slide()` once.
- Move state-specific timers/temporary values into their owning states. Convert compatibility booleans to derived/read-only state information incrementally.
- Preserve the small Grounded/Airborne types; their distinct identities remain meaningful despite tiny files.
- Consider moving mouse look and visual facing to the existing presentation layer when camera behavior is revisited.
- Type known collaborators instead of using string calls when a concrete class already exists (for example LandingTargetIndicator).
- Revisit the nine-argument animation update and combat's dependency on whichever clip is currently playing. A compact animation intent may help after gameplay permissions are settled.
- Visually check flight hover selection (currently tied to the forward key), immediate sprint-clip selection despite acceleration, and the mesh orientation when entering knockdown/death from steep flight.
- The menu progression remains intentionally isolated from PlayerAbilities and movement tuning. `super_leap` and `power_jump` use different IDs; `super_speed` has no matching ability flag; elemental/other future powers are flags/UI placeholders. Do not silently wire prototype purchases to gameplay before defining their effects.
- Saves still write directly over the existing file and record, but do not validate, a save version. Atomic replacement/backup/version migration remain future persistence work; only numeric conversion was changed here.
- Uncapped Speed remains intentional. Characterize high-speed collisions, wall retention, camera motion, and target crossing with actual physics rather than testing formulas alone.

## Validation and manual checks

Initial audit baseline: 29 of 30 existing checks reported passes. `test_player_scene.gd` had a parse error at its unindented assertion, and startup logged a missing translation file. Both specific cleanup issues were addressed in this pass. Initial bug probes ran from temporary files outside the project; no rendered gameplay was observed.

Post-change validation: **34/34 regression scripts passed** on Godot 4.7.2 using headless mode and a fixed 60 FPS simulation. This includes all 25 `test_player*.gd` scripts, the focused civilian lookup test, existing capsule handoff and lane-spacing tests, gameplay HUD, power-token persistence, powers page, camera testing, combat/wind audio, and thrown-vehicle impact checks. The player scene and its referenced scripts loaded successfully; the earlier scene-test parse error and obsolete translation startup error are gone. `git diff --check` also passed.

The sandbox still reports certificate-store/settings-access warnings, and some existing test teardowns report ObjectDB/resource warnings. The save test deliberately exercises a failed write to a temporary path. These are not reported as new gameplay failures. No visual gameplay or GPU/FPS performance verification was performed.

Manual checks for this pass:

1. Hold Space on the ground; left-click repeatedly. No punch should start or interrupt charging. Release Space and verify the charged jump still launches.
2. Charge on a support that disappears or moves out from under the player. Charge should clear immediately, normal airborne control should resume, and charging should work again after landing.
3. After cancelling/releasing charge, land and verify ordinary punching works.
4. Hide diagnostic readouts, change health/XP, charge, fly, and throw. Show diagnostics: values should catch up immediately. Hide/show repeatedly and verify developer tools still work.
5. Hit lightweight civilians near cell boundaries, after movement, and with radius attacks. Verify pending damage transfers once to the full representation; nearby full civilians still use physics damage.
6. Use ordinary XP grants to verify unchanged low-level progression. Extreme integer/storage boundaries are covered by automated checks rather than a practical manual grind.

## Files changed by the implementation pass

Gameplay/configuration: `project.godot`, `scenes/player.tscn`, `scripts/player-scripts/player_character.gd`, `player_jump_charging_state.gd`, `player_combat_controller.gd`, `player_stats.gd`, `player_state.gd`, `player_state_machine.gd`, `player_vehicle_interactor.gd`, `scripts/save_manager.gd`, `scripts/ui-scripts/player_hud.gd`, `scripts/npc-scripts/civilian_capsule_lod.gd`, and `capsule_civilian.gd`.

Validation: new `tests/test_player_charge_interruptions.gd` and `tests/test_civilian_damage_lookup.gd`; updated player stats, scene, state-machine, vehicle-interactor, grounded, flying, jump-charging, landing-impact, HUD-events, and performance-monitor tests. Godot may generate corresponding script UID sidecars.

Documentation: this `PLAYER_ARCHITECTURE_REVIEW.md`.

Existing unrelated working-tree changes were preserved. The open/deferred findings above were documented rather than broadly implemented.


## Follow-up: player audio and speed feedback (September 10, 2026)

Implemented the requested super-jump charging loop, movement/falling wind, death cue, and successful-heavy-pickup grunt as replaceable `_AI` WAV assets. The wind drives subtle trails and edge distortion through a separate `PlayerSpeedFeedback` component; no additional code was added to `player_character.gd`. Death and successful pickup now emit presentation events. Actual speed thresholds replace the old sprint/flight-only wind condition.

See [PLAYER_AUDIO_AND_SPEED_FEEDBACK.md](PLAYER_AUDIO_AND_SPEED_FEEDBACK.md) for defaults, changed files, tests, sound replacement, and the listening/traversal checklist. All 29 relevant regression scripts passed, and the shaders were rendered and inspected with Direct3D 12. The deferred findings and decisions above remain unchanged.
