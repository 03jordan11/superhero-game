# Crowd system review — September 17, 2026

## Recommendation

Keep the current crowd system. Its architecture is appropriate for the game;
targeted improvements are preferable to a rewrite. This review examined source
code and imported character geometry, rather than measuring a new FPS baseline.
Performance recommendations must be confirmed by profiling.

## Sources and lessons

- [Living City in Mafia II — Jan Kratochvíl, GDC Europe 2010](https://www.gdcvault.com/play/1013728/Living-City-in-Mafia)
  ([official slides](https://media.gdcvault.com/gdceurope2010/slides/J_Kratochvil_Technology_Living%20City%20in%20Mafia%20II.pdf)):
  player-centered population, visibility and involvement in actions when spawning
  or retiring pedestrians, and planning how ambient city life connects to gameplay.
- [Crowds in Hitman: Absolution — Kasper Fauerby, GDC 2012](https://www.gdcvault.com/play/1015315/Crowds-in-Hitman)
  ([official slides](https://media.gdcvault.com/gdceurope2012/Presentations/Programming/Kasper_Fauerby_Programming_CrowdsInHitman.pdf)):
  lightweight agents promoted to full NPCs on demand, spatial lookup, speed-aware
  steering, animation costs, and profiling. The reported 1,200 agents depended on
  specialized engine/hardware work and is not a direct benchmark for this game.
- [The AI of Hitman (2016) — Tommy Thompson](https://www.gamedeveloper.com/design/the-ai-of-hitman-2016-):
  describes reduced distant AI/animation work and shared behavior zones and
  evacuation information. Those ideas are relevant to superhero impacts.

The official slide decks and article were read; this review does not claim to
have watched the recordings.

## What the current game already does well

| Area | Current implementation | Assessment |
| --- | --- | --- |
| Bounded population | Local density, distance, altitude and population limits | Avoids simulating the entire city |
| Representation tiers | Full animated physics characters nearby; capsules without physics, skeletons or shadows farther away | Removes whole categories of work |
| Stable transitions | Separate promotion/demotion distances, delay, and speed-based anticipation | Suits fast flight and descent |
| Shared navigation | Full and capsule civilians retain the same journey; ambient routes use short graph walks | Avoids repeated citywide path searches |
| Spatial lookup | Cells index routes, walkable surfaces and capsule damage queries | Already avoids several global searches |
| Work budgets | Population at 0.25 s, spacing at 0.2 s, tier decisions at 0.1 s | Management work is already staggered |

At review time, SuperCity's saved managed-crowd cap is **100**, and the normal
full-character target is **40** before quality settings. Close interactions can
override the normal full-character budget. Older documents describing 80/200
are historical, not the current saved defaults.

Implementation: `scripts/npc-scripts/civilian_crowd.gd`,
`civilian_capsule_lod.gd`, `capsule_civilian.gd`, `routed_civilian.gd`,
`pedestrian_journey.gd`, and `city_pedestrian_network.gd`.

## Prioritized improvements

### 1. Rebuild routes against the actual sidewalks

The old generated network predates changed roads, bridges, City Hall frontage
and harbor geometry. Invalid routes cause visible mistakes, failed spawns,
blocked promotions and repeated recovery. Correct geometry comes before steering
tuning. Crossing behavior currently waits a fixed **1.2 seconds**, without signal
or safe-gap coordination; changing that behavior is a separate follow-up.

### 2. Profile full-character animation and rendering

The instantiated imported civilian, including selected hair, has **15,890–18,344
triangles at highest detail**, **65 bones**, and **four visible mesh surfaces**
with shadow casting enabled. These are geometry counts, not actual GPU workload
at every viewing distance. The three sampled hair variants yielded 17,966,
18,344 and 15,890 triangles.

There is no explicit intermediate distance/visibility animation update tier
between a full civilian and a capsule. Animation-library sharing saves resource
duplication but does not remove each character's pose evaluation. Test lower
animation update rates for less important full civilians and shorter shadow
ranges. Lower-poly characters can help a rendering/skinning bottleneck; they
will not fix expensive spawning or movement logic.

### 3. Make representation changes cheaper and fairer

Promotion instantiates a full scene; demotion creates a capsule; the previous
representation is freed. A small reusable pool may reduce transition spikes,
but should be justified by profiling and must correctly reset health, reactions,
appearance, signals and journey state.

Failed promotions consume the four-attempt transition budget. Several blocked
nearby capsules can repeatedly delay other candidates. Retry cooldowns and
priority for urgent interactions are targeted improvements worth testing.

### 4. Cache static walking-corridor validation

Journey construction samples offset paths at approximately 0.75 m intervals and
can retry several offsets. Once sidewalk geometry is settled, cache valid
corridors or a few validated lane offsets to avoid rechecking the same pavement.
Preserve checks needed for dynamic obstacles and active characters.

### 5. Batch distant visuals if measurement justifies it

Capsules share meshes/materials, but retain individual nodes, mesh instances and
per-frame movement callbacks. Regional MultiMeshes and slower simulation with
interpolation are possible later improvements. At the current population cap,
measure full characters and transition spikes first.

## Gameplay and visual concerns

- **Popping:** offscreen spawning preference is disabled; retirement does not
  explicitly protect every visible civilian. Better concealment would improve
  perceived persistence.
- **Panic:** current fleeing primarily moves away from the threat using obstacle
  avoidance, rather than selecting a safe sidewalk escape route. Shared local
  reactions could support landings and explosions without continuous sensing by
  every pedestrian. This is future behavior work, not part of the route refresh.
- **Overlapping levels:** bridges sit above riverside sidewalks. Hitman's
  documented 2.5D crowd grid assumes no overlapping walkable heights, so copying
  that assumption would be unsuitable. Our routes must preserve height and avoid
  connecting the upper bridge to the lower promenade. Capsules also need height
  support when traversing elevated paths.
- **Animation:** individual walking speeds vary, but the walking clip is not
  matched to each person's speed in the current controller. Speed matching and
  varied animation phase are smaller changes to try before a new animation system.

## Validation plan

First refresh sidewalk/crossing geometry while retaining current behavior. Then
profile a repeatable walking, flying and landing route using
`scripts/ui-scripts/civilian_crowd_performance_monitor.gd`. Its nested timing
categories overlap and must not be summed. Compare population, route work,
movement, spawning and transitions separately, and use rendering/animation
profilers for costs not captured by those script timers. Optimize measured
bottlenecks; do not promise an FPS gain from triangle counts alone.

No gameplay code was changed for the review itself. The subsequently authorized
navigation refresh is documented separately in the pedestrian asset directory.
