# Player Architecture Review

## Scope

This review covers the current Player implementation and the scripts that directly collaborate with it. No gameplay code or scene structure was changed as part of this review.

Files inspected:

- `player.gd`
- `scripts/player_animation_controller.gd`
- `scripts/player_combat_controller.gd`
- `scripts/player_camera_effects.gd`
- `scripts/player_hud.gd`
- `scripts/landing_target_indicator.gd`
- `scripts/health_component.gd`
- `scripts/damage_info.gd`
- `scripts/developer_menu.gd`
- The Player subtree in `scenes/main.tscn`
- Relevant input and autoload configuration in `project.godot`

## Refactor progress — September 3, 2026

This document began as a snapshot of the pre-refactor Player. Struck items are complete. Items marked **partially complete** have working scaffolding or delegated calculations, but still rely on compatibility methods or fields in `player.gd`.

Completed:

- ~~Remove stale Player properties and the disconnected developer flight toggle.~~
- ~~Add an explicit `PlayerStateMachine` with enter/exit hooks and guarded transitions.~~
- ~~Add `Grounded`, `JumpCharging`, `Airborne`, `Flying`, `GroundSlam`, `WallRun`, `KnockedDown`, and `Dead` state objects.~~
- ~~Add unlockable ability guards for Flight, Wall Run, Ground Slam, and Power Jump.~~
- ~~Move Strength, Speed, Resilience, maximum health, movement scaling, and knockdown-chance formulas into `PlayerStats`.~~
- ~~Move shared walking, sprinting, air control, gravity, flight, hover, ground-slam, wall-run, and jump-launch calculations into `PlayerMovementMotor`.~~
- ~~Implement `PlayerInputSnapshot`, capture one snapshot per physics frame, and pass it through the state machine.~~
- ~~Migrate flight-toggle, vehicle-interaction, and animation-input consumers to `PlayerInputSnapshot`.~~
- ~~Migrate Flying-state input to `PlayerInputSnapshot` and replace hard-coded Ctrl descent with the `flight_descend` Input Map action.~~
- ~~Migrate ground movement, sprint, air-control, and jump charging/release input to `PlayerInputSnapshot`.~~
- ~~Migrate wall-run eligibility, entry, lateral movement, exit, and wall-jump input to `PlayerInputSnapshot`.~~
- ~~Remove the broad `_handle_normal_movement()` compatibility path and give Grounded, Airborne, and JumpCharging explicit update sequences.~~
- ~~Remove boolean-based physics dispatch and update the active state exactly once per physics frame.~~
- ~~Activate `PlayerCharacter` as the typed coordinator contract and replace state-side string method dispatch with direct calls.~~
- ~~Finish the movement migration by giving states a typed `PlayerCharacter` body-mutation API backed by `PlayerMovementMotor`.~~
- ~~Add retained headless tests for the state machine, every current Player state, stats, and movement-motor calculations.~~

Remaining, in recommended order:

1. Extract the Player subtree into a reusable `scenes/player.tscn` and make `player_character.gd` the final concrete implementation.
2. Make `PlayerCombatController` authoritative for action locks instead of querying animation state.
3. Implement `PlayerStatusEffects` and move hit-slowdown timing and movement modifiers into it.
4. Implement `PlayerDamageReceiver` and move health consequences, hit reactions, knockdown requests, and death requests into it.
5. Implement `PlayerVehicleInteractor`; move released-vehicle impact ownership to the vehicle or a thrown-object component.
6. Implement `PlayerLandingImpactController` for landing tracking, damage, effects, and camera requests.
7. Make animation and HUD updates event-driven and type the remaining concrete dependencies.
8. Remove compatibility booleans, wrapper methods, and superseded code from `player.gd` after every caller has migrated.

`PlayerDamageReceiver`, `PlayerStatusEffects`, `PlayerVehicleInteractor`, and `PlayerLandingImpactController` currently exist only as scaffolds. `PlayerCharacter` is now the typed coordinator contract implemented by `player.gd`, and `PlayerInputSnapshot` is functional.

## Executive summary

The Player works, but `player.gd` has become the game's central gameplay object. It currently owns locomotion, flight, jumping, wall-running, ground slams, damage reactions, knockdown recovery, death, attributes, health presentation, vehicle pickup/throwing, thrown-vehicle impact monitoring, landing damage, input, camera rotation, and coordination of animation and combat.

At the time of this review, `player.gd` contains approximately 1,113 physical lines, 52 functions, 66 exported tuning properties, and at least 11 boolean state flags. The size alone is not the core problem. The larger problem is that several flags represent mutually exclusive states while others represent simultaneous actions or status effects. Those concepts are updated in different methods and duplicated inside the animation controller, so legal transitions are implicit rather than enforced.

The recommended direction is:

1. Make the Player a reusable scene rather than defining its full subtree inside `main.tscn`.
2. ~~Introduce one explicit state machine for mutually exclusive locomotion/life states.~~
3. Keep combat as an orthogonal action layer instead of adding every combat combination to the locomotion state machine.
4. Extract stats, damage/status effects, vehicle interaction, and landing impacts into focused objects.
5. Make animation and HUD consumers of gameplay state rather than sources of gameplay truth.

This should be an incremental migration. Rewriting every mechanic at once would create unnecessary risk and make it difficult to identify which extraction changed the gameplay feel.

## What is already working well

- `HealthComponent` and `DamageInfo` already establish a useful composition-based damage model shared by multiple actor types.
- Combat, animation, HUD, camera effects, and landing targeting have already begun moving into focused scripts.
- Gameplay values are generally exported for rapid Inspector tuning.
- The state machine now establishes locomotion/life precedence and receives exactly one physics update per frame.
- Damage, knockdown, and death behavior have automated runtime checks from recent development, even though those checks are not yet retained in the repository.
- The uncapped Speed formula is centralized in `_get_run_speed()` and `_get_speed_attribute_multiplier()`, which gives future states a common source of movement scaling.

## Prioritized findings

### ~~P0 — Remove stale serialized Player data before restructuring~~ — Completed

`scenes/main.tscn:356` still contains:

```text
flight_hit_knockdown_chance = 0.5
```

That exported property no longer exists. Knockdown chance is now derived from Resilience. This is scene-data drift and should be removed before moving the Player into its own scene, otherwise the stale override may be carried into the new scene or produce misleading editor behavior.

### P1 — Explicit state machine added; compatibility flags remain

The Player currently combines flags such as:

- `is_flying`
- `is_ground_slamming`
- `is_knocked_out`
- `is_dead`
- `is_wall_running`
- `is_charging_jump`
- `is_jump_active`
- `has_knockout_landed`
- `ground_slam_impact_pending`

Some combinations are intentional, such as dead and knocked out both being true. Other combinations should never occur. The code relies on assignment order and branch precedence to keep them valid. For example, death must clear flight, ground slam, wall run, charge, and jump flags manually in `_die()` (`player.gd:202-221`). A future state added in another section can easily be omitted from that reset list.

Recommendation: create a single authoritative locomotion/life state machine with explicit `enter`, `exit`, `handle_input`, and `physics_update` responsibilities. State transitions should be requested in one place, and each state's `enter()` method should establish its invariants.

Recommended top-level states:

| State | Responsibility | Typical transitions |
| --- | --- | --- |
| `Grounded` | Walking, sprint ramp, ordinary grounded movement | `JumpCharging`, `Airborne`, `Flying`, `WallRun`, `Dead` |
| `JumpCharging` | Charge timing and planted behavior | `Airborne`, `Grounded`, `Flying`, `Dead` |
| `Airborne` | Gravity, air control, jump ascent/fall | `Grounded`, `Flying`, `GroundSlam`, `WallRun`, `Dead` |
| `Flying` | Flight input, acceleration, hover, visual facing | `Grounded`/`Airborne`, `GroundSlam`, `KnockedDown`, `Dead` |
| `GroundSlam` | Targeted descent and impact completion | `Grounded`, `Dead` |
| `WallRun` | Wall validation, vertical/lateral motion, wall jump | `Airborne`, `Grounded`, `Flying`, `Dead` |
| `KnockedDown` | Airborne fall, landing detection, grounded stun | `Grounded`, `Dead` |
| `Dead` | Terminal input lock, fall to ground, death pose | No normal transition |

Landing impact does not need to become a state unless it eventually locks input. It can remain an event produced by the `Airborne -> Grounded` or `GroundSlam -> Grounded` transition.

Sprint and hover also do not need top-level states. They are modes internal to `Grounded` and `Flying` respectively.

### P1 — `player.gd` owns too many unrelated responsibilities

The Player currently performs all of the following:

- Samples raw input.
- Moves the physics body.
- Selects high-level movement behavior.
- Calculates attribute-derived values.
- Receives damage and rolls knockdown chance.
- Owns death and stun timing.
- Updates HUD widgets every physics frame.
- Picks up and reparents vehicles.
- Tracks released vehicles after they leave the Player.
- Applies landing-area damage.
- Spawns landing effects.
- Drives camera rotation.
- Coordinates animation and combat controllers.

Recommendation: keep the root Player object as a coordinator and physics-body owner, but move each cohesive policy to a collaborating object. Object-oriented design here should favor composition over a deep inheritance hierarchy.

Suggested scene and script layout:

```text
PlayerCharacter (CharacterBody3D, player_character.gd)
├── StateMachine (player_state_machine.gd)
│   ├── GroundedState
│   ├── JumpChargingState
│   ├── AirborneState
│   ├── FlyingState
│   ├── GroundSlamState
│   ├── WallRunState
│   ├── KnockedDownState
│   └── DeadState
├── MovementMotor (player_movement_motor.gd)
├── Stats (PlayerStats resource or player_stats.gd)
├── DamageReceiver (player_damage_receiver.gd)
├── StatusEffects (player_status_effects.gd)
├── CombatController
├── VehicleInteractor (player_vehicle_interactor.gd)
├── LandingImpactController (player_landing_impact_controller.gd)
├── AnimationController
├── CameraEffects
├── LandingTarget
├── SpringArm3D
└── Character model

PlayerHUD (CanvasLayer, outside the physics body)
```

The exact number of nodes is less important than ownership. The Player root should answer “what state am I in?” and “what is my resulting velocity?” without also knowing how HUD text is formatted or how a released vehicle detects an impact.

### P1 — Gameplay logic currently depends on animation state

The normal locomotion state update paths call `_stop_horizontal_movement_if_fighting()`, which still checks `animation_controller.is_fighting`, and `apply_damage()` also reads it. This makes the animation controller a source of gameplay truth. Animation should present the gameplay state, not decide whether the Player is allowed to move or react.

The same combat concept is tracked in two places:

- `PlayerCombatController.is_punch_active`
- `PlayerAnimationController.is_fighting`

Those values can drift apart. The combat controller should own the action state (`FREE`, `PUNCHING`, potentially later `BLOCKING`, `THROWING`, and so on). The animation controller should receive an animation request or a read-only action snapshot.

Recommendation: keep combat as a second, orthogonal action layer. A Player can then be:

```text
Locomotion: Grounded
Action: Punching
Status effects: Slowed
```

This avoids states such as `GroundedPunchingSlowed`, `AirbornePunchingSlowed`, and similar combinations.

### P1 — Player scene ownership is too brittle

The entire Player subtree exists directly inside `scenes/main.tscn`; there is no reusable `player.tscn`. The root script also assumes a sibling `../ExplosionController` and exact child names such as `$ChargeUI`, `$PlayerAnimationController`, and `$LandingTarget` (`player.gd:118-127`).

This contributed to the earlier null HUD-node error: script and scene structure can drift independently. It also makes isolated tests and future level scenes harder to create.

Recommendation:

1. Extract the current subtree into `scenes/player.tscn` without changing behavior.
2. Rename the broadly purposed `ChargeUI` node to `PlayerHUD` during a later controlled migration.
3. Use typed exported node references, unique-name access, or setup injection for external dependencies.
4. Move world-owned services such as explosion/effect spawning out of a hard-coded sibling path.

### P1 — Released vehicle lifecycle is owned by the wrong object

The Player stores released vehicles in `armed_thrown_vehicles` and polls the entire collection every physics frame (`player.gd:501-523`). A vehicle that never registers a qualifying collision can remain in this array indefinitely. A low-speed collision also does not disarm it. This creates a potential long-session performance and ownership problem.

The Player should stop owning a vehicle after release. A vehicle or reusable `ThrownObjectComponent` should own:

- Armed/disarmed state.
- Previous speed.
- Contact detection.
- Minimum impact speed.
- Timeout or first-contact cleanup.
- The damage source responsible for the throw.

It can emit an impact signal or directly request the world effect service. This removes per-frame released-object polling from the Player.

### P2 — The animation controller contains a second partial state machine

`PlayerAnimationController` maintains `is_fighting`, `is_hit_reacting`, `is_knocked_down`, `is_playing_death`, `is_playing_landing_animation`, and `was_on_floor`. Its `update_animation()` method also receives eight gameplay parameters.

This duplicates decisions made by the Player and forces ordering dependencies between the two objects. For example, dead must be checked before knocked down in both systems.

Recommendation: have gameplay states publish a small animation intent, such as:

```text
base locomotion: idle/run/sprint/jump/fly
one-shot action: punch/hit/landing
terminal override: knocked_down/dead
movement blend: 0.0–1.0
```

The animation controller should resolve and play that intent, but not own gameplay permissions.

### P2 — Movement input centralized; mouse action routing remains

Movement and physics-action input is now captured once per frame by `PlayerInputSnapshot` and passed through the state machine. Mouse-button attack and ground-slam routing remains in `_input()` and will move with the action-layer cleanup.

Specific issues:

- ~~`KEY_CTRL` is read directly for descending flight instead of using an Input Map action.~~
- ~~Movement input is recalculated several times during the same physics frame.~~
- Flight toggle eligibility relies indirectly on `is_knocked_out` also being true when dead (`player.gd:310`).
- A dead player can still execute some generic mouse-mode behavior because input permissions are not centralized.

~~Build one `PlayerInputSnapshot` per physics frame and pass it to the active state controller. Use Input Map actions for movement controls.~~ Mouse action permissions still need to move to the authoritative combat/action layer.

### ~~P2 — The developer “Enable Flying” setting appears disconnected~~ — Completed

`DeveloperMenu` writes `DebugManager.flying_enabled`, but the Player never reads that value. A project-wide search found no gameplay use of `DebugManager.flying_enabled`.

Recommendation: decide whether this option means “unlock flight” or “force flight.” Give that decision to a capability object or the state machine's transition guard. Remove the option if it is obsolete.

### P2 — Some animation choices do not reflect actual movement

`PlayerAnimationController.update_animation()` chooses flight hover by checking only whether `move_forward` is pressed. Strafing, reversing, ascending, or descending can therefore use the hover animation even when the Player is moving (`scripts/player_animation_controller.gd:152-157`).

Ground animation switches to `Sprint` immediately when the sprint key is held (`scripts/player_animation_controller.gd:177-180`), even though the new sprint-speed mechanic ramps gradually. This reduces the visual impact of that acceleration curve.

Recommendation: provide actual flight-input magnitude and sprint percentage as animation parameters. Eventually, an AnimationTree blend value would express the walk-to-sprint ramp better than an immediate clip switch.

### P2 — HUD updates do unnecessary work every physics frame

Jump charge, vehicle throw charge, sprint percentage, and flight percentage are pushed to the HUD every physics frame (`player.gd:347-349`, `player.gd:385`). The HUD then rebuilds strings and writes control values even when they have not changed.

This is not currently a major bottleneck, but it is avoidable and will matter more as the HUD grows.

Recommendation: use signals for discrete changes and dirty checking for continuously changing values. For example, only emit sprint percentage when it changes beyond a small threshold. The Player HUD should subscribe to Player/component signals rather than be called directly by the physics body.

### P2 — Untyped and dynamic calls hide dependency errors

Examples include:

- Untyped `health_component`.
- `camera_effects.call("setup", ...)`.
- `landing_target.call("get_landing_hit")`.
- `explosion_controller.get("minimum_impact_speed")`.
- Generic `collider.call("apply_damage", damage_info)`.

Dynamic calls are useful for prototype interfaces such as “anything damageable,” but several current collaborators are known concrete types and can be typed. The missing HUD-node failure demonstrates why earlier validation is valuable.

Recommendation:

- Give `HealthComponent`, `DamageInfo`, camera effects, and other concrete collaborators `class_name` types where appropriate.
- Type known node references.
- Keep capability-style checks for world targets, but consider a shared `Damageable` convention or component lookup.
- Validate required dependencies once in `_ready()` with clear errors.

### P2 — Vehicle eligibility depends on a scene-tree name

`_try_pick_up_vehicle()` accepts a rigid body only if its parent is named `Vehicles` (`player.gd:412-414`). This is structural coupling rather than object-oriented capability checking.

Recommendation: use a `carryable` group, `CarryableComponent`, or typed base script. The Player should ask whether an object can be carried rather than where it is parented.

### P3 — Temporary physics query objects can be reused

The punch and landing-impact paths allocate shape/query objects when executed. These are not high-frequency enough to be an urgent optimization, but reusable shapes can be cached by their owning controllers after responsibilities are extracted.

Do not optimize this before addressing state ownership, released-vehicle polling, and redundant HUD updates.

### P3 — Uncapped attributes require high-value physics characterization

Uncapped Speed is an intentional gameplay choice. At large values it produces very large movement, wall-run, flight, acceleration, and ground-slam numbers. The state refactor should preserve the uncapped stat, but automated tests should characterize behavior at representative extreme values.

Risks to test rather than assume:

- Reliable collision and landing detection at very large per-frame motion.
- Camera stability and visual-character rotation.
- Wall contact retention.
- Ground-slam target overshoot.
- Impact damage saturation.
- Floating-point precision far from the world origin.

If technical safeguards become necessary, they should protect collision processing without silently capping the displayed Speed attribute.

## Recommended object model

### `PlayerCharacter`

Owns the `CharacterBody3D`, references its components, exposes a small public API, and performs the final `move_and_slide()`. It should not contain the detailed behavior of every state.

Suggested public surface:

- `apply_damage(damage_info)`
- `request_state(state_id, context)`
- `get_current_health()`
- `get_max_health()`
- `get_stats()`
- Signals such as `state_changed`, `health_changed`, and `died`

### `PlayerStateMachine`

Owns exactly one active locomotion/life state. It is the only object allowed to commit a locomotion transition.

Suggested base-state contract:

```gdscript
class_name PlayerState
extends Node

var player: PlayerCharacter
var machine: PlayerStateMachine

func enter(previous_state: PlayerState, context: Dictionary = {}) -> void:
	pass

func exit(next_state: PlayerState) -> void:
	pass

func handle_input(input: PlayerInputSnapshot) -> void:
	pass

func physics_update(delta: float, input: PlayerInputSnapshot) -> void:
	pass
```

The eventual implementation does not need to use this exact signature, but it should provide explicit entry/exit hooks and a single transition owner.

### ~~`PlayerMovementMotor`~~ — Implemented

Contains reusable movement calculations without deciding the active state:

- Attribute-derived run/walk speed.
- Acceleration helpers.
- Gravity.
- Camera-relative direction.
- Horizontal velocity approach.
- Speed multipliers from status effects.

States choose which motor operations to use. This prevents formulas such as Speed scaling from being reimplemented separately in grounded, flight, wall-run, and ground-slam states.

### ~~`PlayerStats`~~ — Implemented

A resource or component should own Strength, Speed, Resilience, and their derived values. It should emit `stat_changed` and provide methods such as:

- `get_max_health()`
- `get_run_speed()`
- `get_speed_multiplier()`
- `get_flight_knockdown_chance()`

This makes the uncapped scaling policy independently testable and removes attribute formulas from the physics body.

### `PlayerDamageReceiver` and `PlayerStatusEffects`

The damage receiver should use the shared health component, translate damage into Player-specific consequences, and request state transitions. The status-effects object should own timed modifiers such as the 0.5-second hit slowdown.

Suggested flow:

```text
Weapon/Damage source
  -> PlayerDamageReceiver.apply_damage(DamageInfo)
  -> HealthComponent
  -> StatusEffects.add_speed_modifier(...)
  -> optional StateMachine transition to KnockedDown
  -> StateMachine transition to Dead when depleted
```

Knockdown probability belongs here or in `PlayerStats`, not in the locomotion state itself.

### `PlayerCombatController`

Continue using a dedicated combat object, but let it own the authoritative action state. It can expose capabilities such as:

- `is_action_locked()`
- `can_start_attack()`
- `get_movement_modifier()`
- `cancel_for_knockdown()`
- `cancel_for_death()`

Animation should be commanded from this state, not queried to determine whether combat is active.

### `PlayerVehicleInteractor`

Own pickup targeting, carry/drop/throw state, and charge timing. Transfer post-release impact ownership to the thrown object itself.

### `PlayerLandingImpactController`

Own landing-speed tracking, impact classification, area damage, camera-effect requests, and visual-effect requests. It should react to state/ground-contact events rather than be called from several places in the Player loop.

## Recommended transition rules

Centralize guards so each rule has one definition:

- `Dead` overrides every other state and cannot exit through normal input.
- `KnockedDown` blocks input until landing plus stun duration.
- `GroundSlam` cannot start without a valid landing target and required height.
- `Flying` can only be entered when the flight capability is enabled.
- `WallRun` requires an eligible wall, movement input, and sprint intent.
- Death cancels combat, vehicle carry/charge, jump charge, wall run, ground slam, and flight through explicit component/state exit calls.
- A nonlethal hit adds slowdown regardless of locomotion state.
- A nonlethal hit does not interrupt a fighting animation unless it also causes an airborne knockdown.

These rules should be tested at the state-machine boundary rather than inferred from several boolean assignments.

## Incremental migration plan

### Phase 0 — Characterization and cleanup — Partially complete

1. ~~Remove the stale `flight_hit_knockdown_chance` scene override.~~
2. **Partially complete:** retained tests now cover state transitions, stats, and movement formulas; damage/status characterization remains.
3. **Partially complete:** movement values are characterized in tests; landing, damage, and stun coverage remains incomplete.
4. ~~Resolve the developer “Enable Flying” control by removing the disconnected option.~~

No architecture should move until these tests protect the current feel.

### Phase 1 — Extract the Player scene

Move the existing Player subtree from `main.tscn` into `scenes/player.tscn` with no behavior change. Instantiate that scene from `main.tscn`. This immediately improves reuse and isolates future node restructuring.

### ~~Phase 2 — Introduce a state machine as a thin wrapper~~ — Completed

~~Create `PlayerStateMachine` and initial state objects, but initially let those states call the existing Player methods. This changes transition ownership before changing movement math.~~

Suggested first migration order:

1. ~~`Dead`~~
2. ~~`KnockedDown`~~
3. ~~`Flying`~~
4. ~~`GroundSlam`~~
5. ~~`WallRun`~~
6. ~~`Grounded`/`JumpCharging`/`Airborne`~~

Dead and KnockedDown are good first candidates because their permissions and exit behavior are sharply defined.

### ~~Phase 3 — Extract movement and stats~~ — Completed

~~Move the shared speed formulas and velocity helpers into `PlayerStats` and `PlayerMovementMotor`. Remove the broad `_handle_normal_movement()` routing method. Give states a typed `PlayerCharacter` API for the remaining body mutations.~~

### Phase 4 — Separate action and status layers

Make `PlayerCombatController` authoritative for fighting state. Move hit slowdown into `PlayerStatusEffects`. Stop querying the animation controller for gameplay permission.

### Phase 5 — Extract vehicle and landing systems

Move carry/throw logic to `PlayerVehicleInteractor`, post-release tracking to vehicles, and impact logic to `PlayerLandingImpactController`.

### Phase 6 — Make presentation event-driven

Have animation and HUD react to state/component signals. Reduce per-frame HUD string updates and replace the eight-argument animation update call with a smaller animation intent or snapshot.

### Phase 7 — Remove compatibility flags and old methods

Only after every behavior is owned by a state/component should the old booleans and wrapper methods be removed. This prevents a risky “big bang” rewrite.

## Testing requirements for the refactor

At minimum, retain automated checks for:

- Speed 1, 10, 100, and a much larger value across run, walk, flight, wall-run, and ground-slam calculations.
- Sprint and flight acceleration percentages over fixed simulated time.
- Quick jump versus charged jump.
- Flight entry/exit and hover behavior.
- Ground-slam eligibility, target loss, collision completion, and impact damage.
- Wall-run entry, wall loss, lateral motion, and wall jump.
- Hit slowdown duration and refresh behavior.
- Fighting-animation immunity to ordinary hit reactions.
- Resilience-derived flight knockdown chance endpoints.
- Airborne knockdown fall, landing, and full stun duration.
- Death from grounded and airborne states.
- Death while fighting, charging a jump, ground slamming, wall-running, flying, and carrying a vehicle.
- Vehicle drop/throw state and post-release cleanup.
- HUD node-path validity and initial values.
- State transitions never leave more than one locomotion state active.

Manual feel tests remain necessary for animation blending, camera behavior, acceleration feel, and very high Speed values.

## Recommended immediate implementation boundary

For the next coding pass, stop after these three outcomes:

1. A reusable `player.tscn` exists.
2. ~~A state machine owns the current locomotion/life state.~~
3. ~~`Dead` and `KnockedDown` are real state objects using the existing behavior.~~

Do not extract every remaining component in that same pass. Once these states are tested, migrate one behavior at a time while preserving the prototype's existing traversal feel.
