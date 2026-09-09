# Capsule civilian LOD

Open `scenes/super_city.tscn`, expand **CivilianCrowd**, and select its **CapsuleLOD** child. Editable children are enabled for CivilianCrowd in Super City. These settings also appear on the child in the running Remote tree. Edit the saved scene for persistent changes; Remote changes are temporary. `main.tscn` inherits the component and was not edited.

Both representations live under `CivilianCrowd/ActiveCivilians`. A distant civilian is a Node3D with a low-resolution capsule mesh, sharing the mesh and skin-tone materials. It has no character body, collision shape, skeleton, animation player or shadows. It advances along the same route data, retaining its assigned offset, speed, facing and crossing waits. Moving the capsule is its entire normal simulation; it does not probe obstacles or perform local passing.

Approaching replaces the capsule with a full civilian at the same pose and journey state. Retreating replaces an eligible full civilian with a capsule after a delay. A blocked promotion keeps the existing visual stopped until a body can fit; it does not search for a new spawn position or teleport. Damaged, dead, reacting, fleeing, airborne or actively passing full civilians do not demote. Turning the camera alone does not trigger a representation change: this first tier uses player distance in 3D, with a speed allowance for fast approaches and descents.

## Controls on CapsuleLOD

| Setting | Default | Effect |
| --- | --- | --- |
| Enabled | On | Off returns gradually to the existing full-only crowd |
| Max Capsules | 120 | Additional lightweight budget; both tiers still share the parent's hard maximum and local density |
| View Distance | 350 m | Distant coverage; never less than the parent's current reach |
| View Angle | 140° total | Wider distant coverage than the parent's full-only spawning cone |
| Surrounding Radius | 100 m | Distant coverage in every direction, bounded by View Distance |
| High Altitude Population Fraction | 0.35 | Retain some cheap street population high above the city |
| Promote Distance | 90 m | Become eligible for a full body inside this 3D distance |
| Demote Distance | 120 m | Full bodies become eligible for capsules beyond this distance; at least 10 m beyond Promote Distance |
| Interaction Distance | 25 m | Nearby promotion takes priority over the normal full-body budget |
| Approach Lead Seconds | 1 s | Increase promotion distance with player speed, including descent; adds at most 100 m |
| Demote Delay | 1 s | Must remain eligible for demotion before changing representation |
| Check Interval | 0.1 s | Frequency of tier decisions |
| Transitions Per Check | 4 | Maximum attempted conversions per check, nearest candidates first |
| Capsule Radius / Height | 0.3 / 1.75 m | Adjust the shared visual dimensions |
| Debug Tier Colors | Off | Color capsules magenta to make tier boundaries easy to observe |

The Remote inspector exposes **full_count**, **capsule_count**, **promotions**, **demotions**, and **blocked_promotions** on this child. The parent exposes the combined active count and density-limited target.

## Population accounting

There is one pool of people, not a full crowd plus an overlapping distant crowd. Parent **Population Target** supplies the normal full-body budget; **Max Capsules** adds a cheap allowance. Their sum is constrained by the parent's **Max Civilians**, altitude and existing route-length density limits. A conversion changes representation without increasing combined population or local occupancy. Nearby interactions can temporarily exceed the normal full-body budget, but never add another person. Protected full civilians may also delay budget reductions.

The user's saved settings were preserved: at implementation, Super City had Population Target 80, Max Civilians 200, and Ground Radius 220 m. With Max Capsules 120, the combined ceiling remains 200; eligible route density may produce fewer. Turning off CapsuleLOD restores the original parent-only target and spawning shape, gradually promoting or retiring remaining capsules. No new spawning continues when the parent crowd is disabled.

The parent's cyan/yellow debug outlines show its original circle/cone; capsules can populate farther and wider according to this child. Use Debug Tier Colors and the child counts to identify the distant population. The shared skin-tone index is preserved, but the untextured capsule is only an approximation of the textured character's skin appearance.

## Visual test

1. Enable **Debug Tier Colors**. Move toward several magenta capsules slowly. Each should become one full civilian without jumping position, restarting its journey or changing its skin-tone assignment. Capsules have no walking animation by design.
2. Follow one, then retreat past Demote Distance. After Demote Delay, it should become a moving capsule. Move back and forth between the entry/exit distances to check that it does not rapidly toggle.
3. Repeat your travel route at speeds 10 and 30, including turns and descents. More distant streets should already contain moving representations. Observe the shape change and whether full civilians become ready soon enough.
4. Compare **Promote/ Demote Distance 90/120 → 140/180 m** if capsules are recognizable too close. Increase **Transitions Per Check 4 → 8** only if capsules remain close while waiting for a full-body slot; watch frame pacing and full_count. If full_count is already at the parent target, the budget—not transition throughput—is limiting.
5. Compare **View Distance 350 → 450 m** and **Max Capsules 120 → 160** if distant streets are too empty. Increasing Max Capsules alone cannot exceed the parent's overall cap or local density. Wider coverage increases drawing and route-selection work even though capsules are cheap.
6. Turn off Debug Tier Colors to judge ordinary appearance. Toggle Enabled off to compare with the full-only fallback. Restart or let the removal delays settle between population comparisons.

The transition is an immediate representation swap, without a fade. Capsule silhouette changes and outer-boundary spawning can still be visible; tune distances visually before adding more rendering complexity. No measured performance claim is made by the automated checks.

## Interactions and checks

Normal melee, landing impacts and explosions retain their body queries. Small adapters additionally deliver damage to matching capsule visuals; damage is queued and the full body is created at a safe physics update, avoiding double hits or adding physics objects while collision callbacks are being flushed. A capsule blocked from promotion retains the damage and pauses until it can become a full civilian. These adapters preserve the existing damage values and movement controls.

Short checks cover full-only fallback, route/crosswalk movement, moving capsules with no physics/animation nodes, the shared cap, exact state handoff in both directions, blocked promotion, explosion damage forwarding, automatic approach promotion and disabling both tiers. No player spawning or visual test was performed. Frequent full-civilian sticking remains deferred in CITY_TODO.md. Temporary obstacles may intersect distant capsule routes because they intentionally have no local avoidance.

Implementation files: `civilian_capsule_lod.gd` (child settings and handoff), `capsule_civilian.gd` (visual movement), `pedestrian_journey.gd` (shared route construction/state), the existing crowd and routed civilian scripts, `scenes/npcs/civilian_crowd.tscn`, and the editable-child flag in Super City. Damage adapters are in the explosion, player combat and player landing-impact controllers. Tests are `test_civilian_capsule_lod.gd`, the existing crowd fallback test and the unchanged route pilot test.
