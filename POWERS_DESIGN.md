# Powers, upgrades, and attributes — working design

Created September 10, 2026. **Design reference.** The later user-authorized gameplay-menu pass implements purchase locks for existing abilities; see [GAMEPLAY_MENU.md](GAMEPLAY_MENU.md). Unimplemented mechanics and unresolved balance rules below remain proposals.

This is the reference for the player's proposed power trees. The user's outline below is recorded as the requested direction, not as implemented or fully balanced behavior. Recommendations and unresolved decisions are explicitly separated. Update this document as decisions are made.

Related references: [current powers-menu prototype](POWERS_MENU.md), [player architecture review and deferred findings](PLAYER_ARCHITECTURE_REVIEW.md), and [player audio/speed feedback](PLAYER_AUDIO_AND_SPEED_FEEDBACK.md).

## Current implementation scope

The TAB menu now contains Powers, Gear, Attributes, Journal, and Map. Existing moves follow the documented purchase paths, including wall running at Speed upgrade 3, car lifting at Strength upgrade 2, and the existing ground slam as Flight upgrade 2 (Dive Bomb). The existing encounter marker is Mind's core. Power Jump is the free starter core; other cores start locked. Temporary one-token costs and console point grants are retained. Earlier unfinished tiers remain sequential purchases, explicitly marked planned. Attributes supports spending one point for +1 to a chosen stat, with one point earned per new XP level and no retroactive grants to old saves. Strength/Speed cores grant +5 respective attribute points, shown separately as (+bonus). Speed affects boosted running/flight targets and acceleration; walking and normal flight remain fixed. Stamina, running-only Endurance, Greater Jump (Super Jump upgrade 1), Air Jump (upgrade 2), and Bounding (upgrade 3) are implemented; see GAMEPLAY_MENU.md for tuning and tests.

## Requested power trees

Each listed power has a core unlock and three upgrades. **Upgrades must be purchased in the listed order. Any power core can be purchased when the player can afford it, without unlocking another branch first.** Players can eventually own every power, but doing so should be difficult over the long term and is not the expected progression path. Costs, how points are earned, and starting unlocks remain undecided.

## Confirmed foundations

- Keep exactly three attributes: **Strength, Speed, and Resilience**. Do not add a Power, Mind, or elemental attribute.
- Strength scales **physical attack damage**, including **dive-bomb and landing damage**, and increases both Super Jump's forward distance and height. It does not scale mental/energy attack damage merely because it is an offensive attribute.
- For now, mental/energy attacks use **fixed base damage improved through their power upgrades**, without automatic player-level damage scaling.
- Super Jump upgrade 1 **doubles both distance and height and raises their caps**. Absolute values remain unset; doubling each original cap alongside its target is the proposed calculation below.
- Resilience increases **health, boosted-movement stamina capacity, and shared heat capacity**. Recovery/cooling rates and frost overhealth scaling are not yet assigned to it.
- Hidden powers unlock **automatically at attribute thresholds, and stat bonuses count** toward those thresholds. Water running and bullet immunity are the initial examples. Exact thresholds, reveal rules, and what happens if a qualifying bonus is later lost remain open.
- Stamina limits **boosted movement only**. Ordinary movement and normal flight do not consume it. Bounding has no stamina cost. The exact classification of wall running and frost sliding remains open.
- **Electric, Fire, and Laser Eyes share one heat meter.** Shared heat should make choosing and combining these powers consequential; changing powers must not provide a fresh meter.
- Overheating **disables all three heat powers until cooled and damages the player**. Fire upgrade 3, External Combustion, dissipates heat: it **explodes automatically at maximum heat and can also be activated manually before maximum**. Exact vent amount, damage/lockout resolution, and retrigger rules remain to be finalized.
- Upgrades are sequential within each branch. Core purchases are open across branches, subject to affordability.
- Owning all powers is possible but difficult over the long term. **Overlap between powers is acceptable**, since players are not expected to acquire everything. Differentiation can add flavor but is not a prerequisite for retaining an ability.
- The point-earning system is deliberately deferred while the user considers it. No costs or earning rates are locked in.

### Movement

| Power | Core unlock | Upgrade 1 | Upgrade 2 | Upgrade 3 |
| --- | --- | --- | --- | --- |
| Super Jump | Unlock super jumping. Each Strength point increases forward distance and height, with capped scaling; exact caps remain unset. | Double jump distance **and height**, and raise their caps. | **Air Jump:** jump again while in the air. | **Bounding:** jump immediately after landing to preserve momentum. |
| Speed | Unlock boosted sprint and gain **+5 Speed attribute points**, affecting boosted running and flight. | Halve boosted-running stamina drain; flight drain is unchanged. | Fast reflexes allow the player to dodge attacks. | Run up walls. |
| Flight | Normal flight. Directly influenced by the Speed attribute. | Sprint while flying. | Dive bomb; damage scales with Strength. | **TBD** — intentionally unassigned. |

### Body

| Power | Core unlock | Upgrade 1 | Upgrade 2 | Upgrade 3 |
| --- | --- | --- | --- | --- |
| Strength | Constant **+5 Strength** above the player's underlying Strength attribute. | Charged punch hits a cone in front of the player and knocks enemies back. | Pick up and throw cars. | Thunderclap. |
| Mind | Know where trouble is. | Anticipate attacks before they happen, creating a counter window. | Pick up cars with the mind. | Stop bullets in front of the player, then push them back at attackers. |
| Laser Eyes | Normal laser eyes using the shared Fire/Electric/Laser heat meter. | Decrease heat buildup. | **Focused Beam:** damage increases the longer the beam stays on an enemy. | Spin and damage everything around the player. |

### Elemental

| Power | Core unlock | Upgrade 1 | Upgrade 2 | Upgrade 3 |
| --- | --- | --- | --- | --- |
| Frost | Frost fists: encase fists in ice for increased damage. | Frost breath slows/freezes enemies and extinguishes fires. | Frost armor grants overhealth on a cooldown, **and a wall**. Whether these are two moves granted together needs confirmation. | Create frost trails ahead of the player and slide on them, inspired by Frozone. |
| Fire | Fireball that builds heat, **shared with Laser Eyes and Electric**. | Charged fireball: larger projectile and blast radius. | Dragon breath. | **External Combustion:** dissipate shared heat through an explosion around the player that ignites enemies. Automatic at maximum heat; can also be activated manually before maximum. |
| Electric | Continuous arc lightning, inspired by the Emperor in Star Wars. Uses the shared Fire/Laser/Electric heat meter. | Enemies hitting the player have a chance to be shocked. | Summon a thunderstorm. | During a thunderstorm, call lightning down onto a circular target area. |

No resource cost has been specified for Mind or Frost; only boosted movement is confirmed to consume stamina. No effects, prices, or numbers beyond the user's recorded decisions are approved.

## Implementation snapshot before the gameplay-menu pass

Source review: `player_stats.gd`, `player_character.gd`, `player_movement_motor.gd`, `player_combat_controller.gd`, `player_flying_state.gd`, `player_vehicle_interactor.gd`, `player_abilities.gd`, and the menu progression model. These are current implementation facts, not proposed balance rules.

| System | Current behavior | Implication for this design |
| --- | --- | --- |
| Strength | Minimum 1; no gameplay maximum. Ordinary punch damage is `2 × Strength`; the uppercut doubles that against non-explodable targets. The player scene currently sets Strength to 10. | A +5 bonus currently changes ordinary punch damage from 20 to 30 at the scene's starting value. At Strength 1 it would change 2 to 12. Starting attributes and costs matter. |
| Jump | Charge selects vertical launch velocity from 8–35 m/s and adds up to 30 m/s of forward velocity. Existing momentum, gravity, and air control affect travel. Strength is not used in this calculation. | “Each point adds distance” requires a new, clearly defined distance/height rule rather than simply increasing a velocity value. |
| Speed | Sprint target is `20 + 5 × (Speed − 1)` m/s. Walking defaults to half that. Speed also affects acceleration and other traversal calculations. No gameplay maximum is imposed. | A flat +5 m/s sprint unlock is equivalent to one current Speed point in sprint velocity, whereas the Strength unlock grants five attribute points. They are not numerically equivalent rewards. |
| Flight | Normal flight and boosted flight derive their targets from the same walking/running calculations. Flight sprint already works in the prototype. | A sprint-only Speed-power bonus must not accidentally increase flight or walking unless that is intended. Flight boost needs its own upgrade gate. |
| Resilience | Maximum health is `100 × Resilience` at current defaults. Resilience also reduces flight knockdown chance, reaching immunity at the configured value of 10. The scene sets Resilience to 10. | The design now also assigns stamina and heat capacity to Resilience. Their formulas are new work; cooling/recovery and frost overhealth scaling remain undecided. |
| Resources | No player stamina or heat system was found in the reviewed scripts. | Resource capacity, drain, regeneration, overheating, and feedback must be designed. “Twice as long” needs a baseline. |
| Progression | XP increases level; the current stat resource does not award attribute points or power tokens on level-up. | How players earn attributes and powers is still an open design decision. |
| Locks and menu | Gameplay ability flags and saved powers-menu purchases are separate. The gameplay defaults mark the listed ability flags unlocked; the menu starts only Super Leap unlocked and does not grant moves. | The current menu's one-token costs, prerequisites, and starter should not silently become final progression rules. Flags for future powers do not mean those powers are implemented. |

The existing menu has Movement / Elemental / Physical, including Ground Slam and Telekinesis as standalone powers. This proposal uses Movement / Body / Elemental, introduces the Strength and Mind branches, changes Frost's starting move, and places dive bomb under Flight. The future implementation must deliberately reconcile those names, unlocks, and saved IDs. No menu or save IDs have been changed here.

## Attribute rules and proposed calculations

**Distinguish purchased moves, attribute scaling, and hidden attribute rewards.** Purchased power upgrades grant their listed actions; attributes determine specified magnitudes and also grant selected hidden abilities. Keep the hidden reward list explicit rather than assuming high attributes unlock every related purchased move. For example, physical car lifting remains listed under Strength upgrade 2; no attribute-based bypass has been specified.

**Keep base attributes separate from power bonuses.** For the Strength core, use the design rule `effective Strength = base Strength + 5 while unlocked`. Punches and future Strength-scaled jumps would read effective Strength. Loading a save or reopening a menu must not repeatedly add five to the base attribute. Show the contribution clearly, such as `Strength 15 (10 base + 5 power)`.

**Confirmed attribute jobs:** Strength governs physical attack damage, dive-bomb/landing damage, and jump output. Speed governs traversal. Resilience increases health, boosted-movement stamina capacity, and shared heat capacity. Strength is not a general multiplier for lasers, elemental attacks, or mental power damage.

**Confirmed for now:** nonphysical attacks have fixed, individually tuned base damage and improve through their power upgrades. They do not automatically gain damage from Strength or player level. Exact values and each upgrade's damage/effectiveness changes remain unset. Resilience helps heat-based builds sustain attacks for longer without increasing damage per hit. Charge, focused-beam duration, and similar explicitly designed attack mechanics can still change an attack's output; fixed base damage does not mean every use must deal the same amount.

Mixed attacks need clear definitions. Frost fists may combine a Strength-scaled physical punch with a separately tuned frost bonus. A car thrown telekinetically needs a decision about whether impact damage follows object physics alone or an attribute rule; do not silently treat all Mind damage as Strength-scaled because one move uses a physical object.

Dive-bomb and landing damage must include Strength. Their exact relationship to impact speed, jump height, blast radius, and damage caps remains open. Since Strength also raises jump height, verify the combined result rather than unintentionally multiplying several uncapped Strength bonuses together.

For Resilience, health/stamina/heat capacity scaling is confirmed. Stamina now gains 10 capacity per point, while heat tuning remains unset. **Recommendation:** keep regeneration and cooling rates separately tuned initially. Decide whether cooling removes a fixed amount of heat per second or a percentage of capacity: increased capacity otherwise also increases the time to cool a full meter.

### Hidden powers from attribute upgrades

**Confirmed:** hidden abilities unlock automatically when attribute thresholds are reached, and bonuses count toward qualification. Running on water and ignoring bullet damage are the user's initial examples. These are additional progression rewards, not new attributes or separate purchases in the nine branches.

| Hidden ability | Confirmed concept | Proposed association; details still open |
| --- | --- | --- |
| Run on water | Can be gained through stat upgrades. | Speed is the natural candidate. Define the attribute threshold, minimum actual running speed, and behavior when slowing down. |
| Ignore bullet damage | Can be gained through stat upgrades. | Resilience is the natural candidate. Define the threshold and what counts as a bullet, including whether all bullet weapons qualify. Immunity to explosions, melee, or other damage is not implied. |

**Confirmed qualification rule:** use the qualifying attribute with its bonuses included, rather than invested/base points alone. A bonus that crosses a hidden-power threshold must therefore be able to trigger the unlock. The earlier recommendation to exclude bonuses was not accepted.

Whether a discovered reward stays permanently unlocked after a bonus expires or only functions while the threshold is met remains undecided. This matters if temporary bonuses or stat reductions are introduced. How rewards are revealed to the player also remains open. No numeric thresholds or additional hidden powers have been selected; Speed for water running and Resilience for bullet immunity remain the proposed associations.

### Super Jump: define the measurement before choosing numbers

A useful design target is **full-charge forward distance on flat ground under a specified starting condition**, with height tuned separately. A candidate rule is:

`target distance = min(distance cap, base distance + distance per point × (effective Strength − 1))`

Strength must increase both distance and height. Use a separate capped height target so both gains can be tuned deliberately. The per-point gains, base distance/height, and caps remain unset. These are tuning targets, not implementation formulas for launch velocity. Upgrade 1 is confirmed to double both target distance and height and raise their caps.

Real travel also depends on starting speed, elevation, air control, bounding, and a second jump. Decide whether the cap limits the power's contribution or the entire real-world jump. **Recommendation:** cap the power's contribution while allowing earned traversal momentum to matter; a hard cap on all travel could undermine bounding. Since Strength increases both height and distance, tune to those outcomes rather than multiplying both launch-velocity components by the same amount: more airtime already adds distance.

**Greater Jump is now implemented for the existing charged jump:** multiply upward launch velocity and the power's added forward boost by `sqrt(2)`. With unchanged gravity, this doubles height and the power's ballistic forward-distance contribution, including full-charge maxima. Base Inspector tuning stays unchanged; charge is clamped to full charge. Quick jumps are unchanged. Strength-based targets and their absolute caps remain future work. Do not simply double upward velocity: that would produce four times the jump height. **Bounding is implemented at tier 3:** tap within 0.25 seconds after landing, or buffer a tap up to 0.12 seconds before a predicted qualifying landing. Require at least 16 m/s horizontally and 12 m/s downward, excluding Dive Bomb. Launch with full charged vertical velocity and 90% retained horizontal velocity, without adding forward boost. While unlocked, fast normal airborne movement coasts with 1 m/s² drag and existing steering; chains end below the horizontal threshold. These are Inspector defaults for playtesting, not final balance. See BOUNDING.md. **Air Jump is implemented:** one immediate tap per airborne trip, replenished only on landing. It uses half the current fully charged launch velocity and added forward boost, including Greater Jump; existing horizontal momentum remains and vertical velocity is replaced. It works while falling regardless of how the player became airborne, including after flight ends, but not during active flight. Holding Jump does not charge it or repeat it.

### Speed and Flight: distinguish the attribute from the unlock bonus

**Implemented following the request to hook in stat attributes from both cores:** Speed grants +5 **Speed attribute points**, while Strength grants +5 Strength points. This supersedes the earlier proposed +5 m/s sprint-only interpretation. The later stamina pass restricts the ordinary running/flight acceleration and speed benefits to boosting. At base Speed 1, effective Speed 6 gives a boosted target of 45 m/s, while walking/normal flight remain 10 m/s under current defaults. Bonuses are derived from core ownership and never added to saved base attributes.

**Implemented movement rule:** normal flight uses a fixed target, with Speed-scaled flight boosting gated by Flight upgrade 1. Ground boosting requires the Speed core. Walking and normal flight are 10 m/s at the default tuning.

### Resources and defensive scaling

- **Stamina — implemented:** capacity = 10 × Resilience; boosted running/flight drain 20 per second. Regenerate 20 per second after a 1-second delay once sprint is released or toggled off, including during normal flight. Holding sprint blocks all regeneration, even during exhaustion or coasting. Exhaustion prevents boost until 20% capacity recovers. Speed upgrade 1 halves running drain only. Ordinary traversal and normal flight are free. Bounding is free. Wall running and frost sliding resource costs remain open.
- **Shared heat — confirmed rules:** Fire, Laser Eyes, and Electric use one persistent pool, with capacity increased by Resilience. Heat from a sustained laser beam leaves less headroom for a charged fireball or lightning burst; switching does not reset it. Overheating damages the player and disables all three powers until cooled. Damage amount, a single hit versus ongoing damage, cooling delay/rate, and the unlock temperature remain open. Continuing to fire while overheated is not the chosen baseline.
- **External Combustion — confirmed trigger rules:** Fire upgrade 3 dissipates shared heat in a fiery explosion, automatically at maximum heat or through manual activation before maximum. Heat can originate from any of the three powers; no source-specific restriction has been specified. Manual venting lets the player choose when and where to release the heat instead of always waiting for the maximum.
- **External Combustion — remaining tuning:** full versus partial venting, damage/radius versus stored heat, minimum heat for a manual cast, and any retrigger limit remain open. The working proposal is for a successful automatic vent to resolve before ordinary overheat self-damage and lockout; those exact protections have not been separately confirmed. Do not apply the automatic explosion and default overheat penalties together accidentally. A heat-scaled explosion is an attack mechanic within Fire's fixed-base/upgraded damage design, not Strength or level scaling.
- **Resilience and armor:** health, stamina capacity, and heat capacity scaling are confirmed. Frost overhealth is a separate possible defensive benefit; whether it scales with Resilience or maximum health is still open. Define whether overhealth expires and whether refreshing replaces or stacks it before tuning armor.

## Optional branch identity and acceptable overlap

The user is comfortable with overlapping powers. Players choose branches freely and are not expected to acquire them all; full completion is a difficult long-term possibility. The suggestions below are optional ways to give moves their own feel, **not required redesigns or reasons to impose extra prerequisites, costs, or restrictions**.

| Potential overlap | Suggested distinction to discuss |
| --- | --- |
| Speed dodging vs. Mind counters | Speed helps avoid a hit through movement; Mind reveals a readable attack cue and rewards a timed counter. Decide whether the dodge is player-triggered or automatic before assigning chances. |
| Strength lifting vs. Mind lifting | Strength physically carries and throws; Mind manipulates at range. Both can serve similar purposes in different builds. Range, commitment, and control can distinguish their feel without requiring one to be deliberately weakened. |
| Charged punch vs. Thunderclap | Charged punch could be a focused directional impact; Thunderclap a broader crowd-control blast with a different reach or recovery. Thunderclap's actual shape is unassigned. |
| Dive bomb vs. existing ground slam | Decide whether these are the same move with a new unlock location or separate moves. If distinct, an aimed forward dive versus a vertical slam could separate them. |
| Fire vs. Frost vs. Electric | Suggested identities: Fire for sustained damage/ignition, Frost for control/protection/traversal, Electric for chaining and area denial. Similar attack shapes are acceptable; these identities can inform presentation and secondary effects. |
| Flight vs. jump/wall run/frost sliding | Keep each traversal mode useful through responsiveness, momentum, control, or situational advantages. Avoid making the alternatives relevant only because ordinary flight is unpleasant to sustain. |

Upgrade bundles also differ in scope: Frost armor plus a wall grants more than one move, while reduced laser heat is a numerical improvement. Costs do not necessarily need to be identical across all upgrades.

## Questions for the next discussion

Automatic hidden unlocks with bonuses included, both combustion triggers, and fixed nonphysical base damage plus power upgrades are now confirmed. Next, clarify the consequences of those decisions; remaining power-token earning rules and combat numbers can wait:

1. **Hidden reward persistence:** once unlocked, does a hidden power remain permanently available if a qualifying bonus is lost, or does it require the effective attribute to stay above the threshold? Bonus eligibility itself is already confirmed.
2. **Manual combustion strength:** should an early vent produce a smaller/weaker explosion, with maximum heat giving the strongest version? A heat-scaled result would give the player a choice between venting early and saving heat for a larger attack. Minimum heat and exact curves remain unselected.
3. **Resolved — Speed's stamina upgrade:** halves boosted-running drain only; flight is unaffected.

Further heat details: one self-damage event on entering overheat versus damage over time; whether it can be lethal; the cooling level at which powers recover; and any vent retrigger limit. These remain design questions, not implemented restrictions.

Point earning remains deliberately deferred. Starting powers, attribute earning, individual costs, and expected completion time also remain unset. The prototype's cross-branch prerequisites must be removed or revised when implementing open core purchases; no such code change is being made during this discussion.

### Later decisions to work through by branch

- Super Jump: charge timing, bounding input window/buffering, maximum preserved speed, extra-jump strength, and recharge conditions.
- Speed: automatic dodge chance versus active dodge; attacks that can be dodged; wall-run stamina and corner behavior.
- Flight: normal/boost speed relationship, dive-bomb targeting and exit behavior, and upgrade 3. Possible candidates are an aerial dash, tighter high-speed maneuvering, or carrying/rescuing someone in flight. These are suggestions, not selections.
- Strength: cone range/angle, charge/damage/knockback caps, lifting mass limits, throw scaling, and Thunderclap's purpose.
- Mind: trouble detection presentation/range; counter timing; telekinetic carry versus throw; bullet-capture capacity, duration, release aim, and limits against non-bullet attacks.
- Laser Eyes: sustained versus pulsed fire, heat reduction amount, focused-damage cap, target-loss grace period, and spin duration/control.
- Frost: fists as a toggle or timed buff; additive damage versus a melee multiplier; freeze buildup, duration and break conditions; fire interactions; whether armor and wall are both granted; sliding controls and persistence of trails.
- Fire: charge cost, breath duration/range, burning duration/stacking, and combustion vent amount, strength, protection, and recovery. Automatic-at-max and manual-before-max activation are already confirmed.
- Electric: arc range/chaining/target count, reactive-shock chance and retrigger limit, storm area/duration/cooldown, and targeted-strike cost while the storm is active.
- Shared combat: which powers can be used in flight, while sprinting, while carrying, or together; how the player selects powers without overloading controls; interruption rules and how enemies communicate resistances.

## Decision log

| Date | Status | Record |
| --- | --- | --- |
| 2026-09-10 | User-provided direction | Recorded all nine cores and their three upgrade slots, including Flight's unassigned third slot. |
| 2026-09-10 | Confirmed task scope | Discuss and document only; no code, gameplay tuning, menus, localization, or save changes. |
| 2026-09-10 | Confirmed by user | Exactly three attributes: Strength, Speed, Resilience. No fourth attribute. |
| 2026-09-10 | Confirmed by user | Strength affects jump distance and height. Super Jump upgrade 1 doubles both and raises their caps. Absolute caps and gains remain unset. |
| 2026-09-10 | Confirmed by user | Stamina applies only to boosted movement. Electric, Fire, and Laser Eyes share one heat meter to create meaningful combined-use decisions. |
| 2026-09-10 | Confirmed by user | Upgrades are bought in order. Any core power can be bought when affordable. All powers can eventually be acquired, but this is difficult long term and not expected for a typical player. Overlapping powers are acceptable. |
| 2026-09-10 | Deliberately deferred by user | How power-purchase points are earned. |
| 2026-09-10 | Confirmed by user | Strength scales physical attack damage, including dive-bomb and landing damage; it does not directly scale mental/energy attacks. |
| 2026-09-10 | Confirmed by user | Resilience increases stamina and shared heat capacity alongside health. |
| 2026-09-10 | Confirmed by user | Hidden powers unlock automatically at attribute thresholds, and stat bonuses count. Examples are water running and ignoring bullet damage. Thresholds, associations, and persistence after losing a bonus remain to be defined. |
| 2026-09-10 | Confirmed by user | Overheating disables all three heat powers until cooled and damages the player. Fire upgrade 3 dissipates heat through an automatic explosion at maximum heat and also permits manual activation before maximum. Exact vent amount and damage/lockout protection remain to be clarified. |
| 2026-09-10 | Confirmed by user, current design | Nonphysical attacks use fixed base damage improved through power upgrades; no automatic player-level damage scaling for now. |
| 2026-09-10 | Open | Specific attribute scaling, resource limits, caps, starting powers, costs, and numeric balance await discussion. Unconfirmed recommendations above remain proposals. |

| 2026-09-10 | Confirmed and implemented | One attribute point per new XP level; spend one point for +1 chosen base attribute. No retroactive grants. Stamina tuning: 10 per Resilience, 20/s drain and recovery, 1-second delay, 20% exhaustion recovery threshold. Endurance halves running drain only. Normal walking and flight ignore Speed. |

| 2026-09-10 | Confirmed and implemented | Stamina cannot regenerate while sprint is held or toggled on, even while exhausted/coasting. Release starts the recovery delay. Greater Jump (upgrade 1 after the Super Jump core) doubles charged-jump height and the power's ballistic distance contribution; quick jumps are unchanged. |

| 2026-09-10 | Confirmed and implemented | Developer console replaces the button menu and pauses gameplay. `reset` uses attributes 1/1/1, clears level/XP/point balances and all powers except the starter Power Jump core. Console grants require explicit save; normal menu purchases retain autosaves. |

| 2026-09-10 | Confirmed and implemented | Air Jump originally at Super Jump upgrade 3 (now tier 2): one fresh tap per airborne trip, reset on landing, no charge or stamina cost. Half of current full-jump launch stats, including Greater Jump. Falling is eligible; active flight is not. |

| 2026-09-10 | Confirmed and implemented | Reordered Super Jump to Greater Jump → Air Jump → Bounding. Bounding uses buffered landing taps, full vertical launch, gradual momentum loss, horizontal/downward speed thresholds, and no stamina cost or fixed chain count. Dive Bomb does not qualify. Earlier tier-3 Air Jump placement is superseded; saved tier counts are preserved. |
