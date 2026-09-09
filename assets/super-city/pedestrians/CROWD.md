# Nearby civilian crowd

**Capsule LOD is now available under CivilianCrowd → CapsuleLOD.** See [capsule controls and tests](CAPSULE_LOD.md). The parent controls below still govern shared density, the hard maximum, and the full-only fallback. With CapsuleLOD enabled, it adds wider distant coverage and a lightweight allowance; Parent Population Target becomes the normal full-body budget rather than the combined target. Both representations count once toward the shared local and global limits.

Select `SuperCity/CivilianCrowd` for population settings. The controller scene is `scenes/npcs/civilian_crowd.tscn`, with its implementation in `scripts/npc-scripts/civilian_crowd.gd`. Runtime instances live under `CivilianCrowd/ActiveCivilians`. The existing `main.tscn` inherits the controller through Super City; it was not edited.

The default player lookup uses the existing `player` group. Set **Player Path** explicitly if your test contains multiple players or uses a different follow target. Missing players or disabled nearby routes produce no new civilians. The controller does not place or modify the player.

## Controls

| Inspector setting | Default / behavior |
| --- | --- |
| Crowd Enabled | On; turn off to gradually remove all ambient civilians and stop spawning |
| Population Target / Max Civilians | 40 population ceiling / 1,000 script-default hard maximum; saved scene overrides are preserved (Super City currently uses 200 maximum) |
| Civilians Per 100m | 4 per 100 m of eligible route length, rounded down within each local cell |
| Density Cell Size / Max Civilians Per Cell | 50 m square cells / 6 new-spawn occupancy limit per cell |
| Ground Radius / High Altitude Radius | 150 m / 30 m forward reach, still reduced by altitude |
| Nearby Circle Radius | 25 m in every direction, bounded by current forward reach |
| Forward Cone Angle | 75 degrees total width; applies beyond the nearby circle |
| Retention Angle Margin | Adds 35 degrees total width before an existing civilian becomes eligible for retirement |
| Height Reduction Start / End | 25 m / 200 m above nearby pedestrian routes, not the roof below you |
| High Altitude Population Fraction | 0; full characters reduce toward zero high in the sky |
| Despawn Margin / Delay | 40 m beyond forward reach / 1.5 seconds; the nearby retention circle grows by up to 10 m using this margin. Target reductions also retire excess distant civilians |
| Minimum Player Distance / NPC Spacing | 12 m / 1.6 m for spawning |
| Population Update Interval | 0.25 seconds |
| Spawns / Attempts / Removals Per Frame | 2 / 6 / 2, on physics frames; failed fills back off for one update interval |
| Forward Spawn Share | 0.7; 70% of attempts favor ahead, the remainder sample within the permitted circle/cone |
| Forward Distance Fraction | 0.65; prefer forward positions around 65% of the current radius |
| Movement Bias Start / Full Speed | 6 / 30 m/s horizontal speed; blend from camera direction toward travel direction |
| Prefer Offscreen Spawns | Off; allow visible filling ahead beyond Minimum Player Distance. Enable to restore the old offscreen-first preference |
| Maximum Lane Offset | 0.8 m each side; a random preference per civilian, reduced at narrow corners |
| Minimum / Maximum Walk Speed | 2.1–2.9 m/s |
| Random Skin Tones | Eight shared pale-to-deep-brown body-material tints; texture detail is retained |
| Show Civilian Status | Off; enable labels when diagnosing movement |
| Show Population Area | Off; runtime outlines: cyan nearby circle, yellow forward cone, gray retention boundaries |

The Remote inspector exposes `active_count`, `current_target`, `density_capacity`, `current_radius`, `rejected_spawns`, and `status` on the controller. Population Target is now a ceiling, not a requested number to squeeze onto whatever routes are available. Density is estimated from at-most-5 m route intervals inside the circle/cone; whole offscreen segments do not count merely because their tips enter it. Per-cell capacity is the smaller of route length × density (rounded down) and the local maximum. Height and global ceilings can reduce this further.

Local occupancy limits prevent new spawning into full cells; civilians can still walk between cells and temporarily gather. Protected reacting/nearby civilians and retirement delays can temporarily keep the active count above the current density target. A lower explicit hard cap still stops new spawning immediately and retires eligible excess characters. Zero density stops new spawning; use Crowd Enabled to clear the crowd. Variation settings apply to newly spawned civilians, while population controls update during play.

The circle and cone stay centered on the player. Population selection and density estimates use the existing update interval, not per-civilian scans. Looking straight down retains a horizontal direction; fast horizontal travel takes priority over the camera. Existing civilians outside the wider retention area retire gradually after the delay; turning back during the grace period cancels ordinary retirement. Nearby civilians remain around you. Turning the camera does not redirect civilians' journeys, but a sustained turn can now retire distant civilians behind you. At the hard cap, replacement still waits for retirement to make room. The CapsuleLOD child extends these full-only rules with wider lightweight coverage.

Keep desired districts/modules enabled under `CityPedestrianRoutes`. These checkboxes control connectivity and spawn eligibility, not one NPC per module. Current saved selections are preserved. Debug visibility is separate from enabling a route. `StartHere` markers remain navigation references for inspecting a module, not spawn commands.

## Visual check

1. Walk near enabled West Village routes. Civilians should fill gradually at different positions along segments, with varied skin tones, speeds and sideways positions. Their destinations are short connected journeys, not repeated module endpoint pairs.
2. Follow a few around corners and across roads. Offsets should join smoothly or narrow where needed. Crossing waits and temporary passing around people remain. If a full civilian cannot make progress, it should turn around after roughly 1.25–1.6 seconds; a completely enclosed civilian can still remain blocked.
3. Walk or fly to another enabled area. Older distant civilians should retire after the delay while the new area fills. Turn around near the radius boundary to check that the crowd does not repeatedly disappear and reappear.
4. Ascend past 25 m and then 200 m above the street; count/radius should decrease. Descend and check refill. With CapsuleLOD enabled, cheap street population can remain at altitude; use its transition controls to test fast descents.
5. Change target/cap while running. Check counts, then disable the crowd and compare frame time. Try a lower offset or zero to compare lane behavior without changing the routes.
6. Enable **Show Population Area**, then travel at speeds 10 and 30 without stopping to look back. New civilians should appear within the yellow cone or cyan circle; gray boundaries show retention space. Turn briefly and back, then hold a turn longer than the delay to compare retention. Forward Spawn Share zero makes selection uniform within the allowed shape; it does not disable the cone.
7. Approach the same sidewalk from the park. A short exposed route should receive a small density-based allocation rather than the whole target. Increasing only Population Target should not pack that sidewalk; increasing density/local capacity should change its allowance.

## Tuning comparisons

Change one setting at a time, repeat the same trip, and wait for the retention delay or restart between comparisons. Use the runtime Remote inspector for temporary changes; edit/save the scene's Inspector values for persistent changes. Disable the overlay when comparing performance.

| Comparison | Try | What to observe |
| --- | --- | --- |
| Default baseline | 75° cone, 25 m circle, 150 m Ground Radius, density 4, local max 6, target ceiling 40 | Smaller nearby population plus concentrated forward coverage |
| Narrower focus | Cone 75° → 60° | Fewer side streets qualify; total target may decrease, rather than the same count being squeezed ahead |
| More advance preparation | Ground Radius 150 → 220 m | Earlier forward population at speed 30; larger coverage costs more and may reach the target ceiling |
| Stronger forward allocation | Forward Spawn Share 0.7 → 0.9 | More new attempts prefer forward space, without bypassing density limits |
| Denser street | Density 4 → 8, then local max 6 → 10; raise target ceiling 40 → 80 only if it is limiting | Distinguish local density limits from the overall ceiling |
| Sparser street | Density 4 → 2, local max 6 → 3 | Fewer civilians per street, especially near the park |
| Better sudden-turn coverage | Nearby Circle Radius 25 → 35 m | More full civilians beside/behind you, using more of the budget |
| Faster trailing retirement | Despawn Delay 1.5 → 0.75 s | Frees budget sooner, with a greater chance of visible disappearance after turning |
| More stable turns | Retention Angle Margin 35° → 60°, delay 1.5 → 3 s | Retains distant civilians longer, but can delay new forward filling |

Keep Density Cell Size at 50 m during these comparisons. It changes the region over which local density is rounded and capped; larger cells can allow larger local groups. These are experiments, not performance guarantees. Empty peripherals, sharp-turn refill and visible spawning can still occur at the outermost capsule boundary. Remaining NPC sticking is tracked on CITY_TODO.md.

Full civilians expose **Stuck Recovery** on the root of `scenes/npcs/routed_civilian.tscn`. **Stuck Wait Seconds** defaults to 1.25 s, with an additional random 0–0.35 s per recovery. **Stuck Progress Distance** defaults to 0.15 m of actual horizontal movement. **Recovery Commit Seconds** defaults to 4 s before another recovery can begin accumulating; normal route turns still work. **Stuck Recovery Enabled** disables this fallback for comparison. Crossing waits, hit reactions and disabled routes do not trigger recovery. The fallback reverses the current segment without teleporting or disabling collisions.

The full-character tier now has an optional capsule substitute; pooling and new panic behavior remain deferred. Skin colors are inexpensive body-material tints for this prototype, not a new skin shader or character customization system. The automated lifecycle checks do not visually verify colors, foot placement, crowd flow or frame pacing.
