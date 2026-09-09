# Civilian crowd implementation plan

Status: nearby population tuning was accepted; a moving capsule LOD tier is implemented and awaiting visual assessment. The historical checkpoints below record earlier stages. Pooling and further rendering tiers remain deferred. See `assets/super-city/pedestrians/CAPSULE_LOD.md` for current tier controls and tests.

## Current checkpoint: capsule LOD

The CapsuleLOD child of CivilianCrowd exposes distant coverage, capsule budget, visual dimensions and transition settings. Capsules share a simple mesh/material palette and move along shared journey data without character physics, animation, shadows or local avoidance. Full/capsule handoffs preserve world pose, route index, offset, speed, skin-tone index and crossing waits. Occupancy/density and the hard maximum count each person once. Full-body creation is deferred if blocked; interacting or damaged full civilians retain their representation. Melee, landing and explosion adapters forward damage to capsules and queue safe full-body handoff.

Defaults: 350 m distant coverage, 140-degree cone, 100 m surrounding radius, 120-capsule allowance; promote at 90 m, demote beyond 120 m after 1 second, with speed-based approach allowance. Parent Population Target supplies the ordinary full-body budget, constrained with capsules by the existing hard maximum and local density. Saved user tuning and main.tscn are preserved. Disable the child to return gradually to the prior full-only setup.

Focused checks pass for lightweight movement, shared caps, exact state transfer, blocked promotion, explosion forwarding, automatic approach and disabling; route/crosswalk and full-only crowd checks also pass. The user must assess capsule appearance, representation swapping and performance. No animation tier or pooling is needed for this chosen prototype. Existing sticking remains a separate TODO.

## Current checkpoint: nearby ambient population

Latest refinement: a 25 m nearby circle plus a 75-degree forward cone, reaching 150 m at ground level. New spawning uses local route-length density (default 4 per 100 m, capped at 6 per 50 m cell), and Population Target is an overall ceiling. Route lengths inside the shape are approximated with intervals no longer than 5 m. Existing characters may walk between cells; occupancy limits govern spawning, not steering. A wider retention cone (+35 degrees), distance margin and 1.5-second grace period allow gradual trailing retirement. Controls are runtime-adjustable; an optional population boundary overlay supports visual tuning. The user's saved scene caps and player settings are preserved. Frequent sticking remains deferred in CITY_TODO.md.

The cone/density geometry, retention margin, overlay generation and existing crowd lifecycle pass focused headless checks. Travel feel and population density require the user's visual assessment. Earlier paragraphs/checkpoints below describe the progression; the former unrestricted-radius spawning and 3-second default retirement have been superseded by this refinement.

`CivilianCrowd` owns spawning/removal under `ActiveCivilians`; the district route network owns only topology and debug overlays. Existing route checkboxes remain authoritative. The standalone one-civilian pilot remains available as a fallback, but the city graph no longer creates test walkers. Population target defaults to 40 with a configurable cap of 1,000, independent of module count.

The controller indexes enabled sidewalk/alley segments once per graph rebuild, selects nearby segments by length, and spawns at clear positions along them. It updates population periodically and budgets creation/removal per physics frame, backing off failed spawn attempts. Full characters decrease gradually with height above nearby street routes; a larger removal radius and delay reduce boundary churn. Existing hit reactions and nearby non-walking civilians are protected from ordinary retirement. Runtime settings use the same exported values intended for a later settings menu.

Each civilian follows short connected journeys with a persistent signed lane offset. Offsets join at turns and shrink where pavement is narrow; existing temporary passing detours remain available. Eight shared body-material tints provide pale-to-deep-brown skin variation without modifying source materials, eyes, or hair. Full physics, animation and existing reactions are reused. No pool, new panic system, persistent distant population, lightweight representation or LOD tier is introduced.

Short headless checks cover spawning, varied offsets/materials, walking, caps, altitude removal, moving/refilling, and graph disable without instantiating the player into the scene tree. Visual corner behavior, skin appearance and fast-flight popping remain user tests. The old hard-pavement statements in historical stages are superseded: pavement is preferred, supported setbacks and brief road detours are allowed for passing.

Next: visually assess this population step, then measure crowd cost before choosing pooling, flight preparation or lightweight LOD. Disable `CivilianCrowd/Crowd Enabled` for an immediate baseline; test the preserved standalone route pilot separately if needed.

Forward-fill refinement: new spawn attempts now favor camera-forward routes (default 70% forward / 30% anywhere), with a preferred distance of 65% of the current radius. Horizontal speed blends the preference toward movement from 6 to 30 m/s. Offscreen-first spawning defaults off. This reuses the current radius, cap, update interval and work budgets; turning the camera does not retire or redirect civilians. Focused checks passed for forward fill, movement blending, turn retention and the existing lifecycle. Visual travel feel remains pending; no speed-based radius expansion or distant LOD is added.

## Outcome

Make Super City appear populated during walking, rooftop traversal and fast flight, while keeping expensive civilian simulation within a measured budget. Calm civilians use sidewalks and alleys, and enter roads only at designated crossings. Panic may permit escape across roads, but never routes through buildings or into the river/bay.

Implement one stage at a time. Test and record its results before enabling the next stage. Preserve the user's player placement, controls, city edits, existing NPC reactions and hostile behavior. Do not regenerate the city scene to add pedestrian data.

## What exists today

- `scripts/npc-scripts/civilian.gd`: random-direction wandering and directional fleeing; destination walking and panic states are placeholders.
- `scripts/npc-scripts/npc_base.gd`: every active NPC performs physics movement each physics tick, including damage and hit reactions.
- `scripts/npc-scripts/character_obstacle_avoidance.gd`: repeated shape queries for steering around static obstacles; no sidewalk boundaries or civilian separation. This helper is shared, so civilian-specific changes should not silently alter hostile movement.
- `scripts/npc-scripts/civilian_animation_controller.gd`: shares animation resources, but each character still has animation/skeleton processing.
- `scenes/npcs/civilian.tscn`: full character model, physics body and inherited health label.
- `assets/super-city/layout.json`: authored building footprints, sidewalk rectangles, alleys and roads. It is a source for graph generation, not proof that later manual scene edits match it.

Hiding a mesh does not switch off these simulation costs. Rendering, animation, movement, routing and collision need separate budgets.

## Route graph versus navigation mesh

| Question | Route graph | Navigation mesh |
| --- | --- | --- |
| What is authored? | Points connected by permitted routes | Polygons describing walkable space |
| Example | Sidewalk corner → crosswalk entrance → opposite corner → alley entrance | Find a path through connected sidewalk and crossing polygons |
| Movement freedom | Follow a route corridor with controlled sideways variation | Move throughout the allowed polygon area |
| Street rules | Only crossing edges connect opposite sidewalks | Exclude road polygons from normal navigation, except crossing strips |
| Best fit here | Repeated city blocks, explicit crossings, cheap distant walkers | Irregular plazas, complex interiors or local movement around obstacles |
| Work still required | Route authoring, corridor widths, corner handling and local avoidance | Correct source geometry, baking, area rules and local avoidance |
| What it does not solve | Physics, crowd LOD, animation or reactions | Physics, crowd LOD, animation or reactions |

Recommendation: start with one shared route graph using Godot's native `AStar3D`. We provide points and connections; Godot finds a route between them. An edge can store a sidewalk/alley/crossing type, length, usable corridor and permitted travel direction alongside the AStar data. The graph is shared data, not thousands of scene nodes or a separate graph per civilian. [Godot AStar3D documentation](https://docs.godotengine.org/en/stable/classes/class_astar3d.html)

For example, a civilian wanting to reach the opposite block walks to a crossing entrance, follows the crossing corridor, then continues along the opposite sidewalk. Two points being close together is not enough to connect them: a road, wall or water can lie between them.

A point path alone does not keep a body on the sidewalk. The movement layer must respect corridor boundaries after steering, account for capsule radius and follow corners without cutting diagonally through forbidden space. Lateral offsets provide variety within the corridor; they are not arbitrary offsets applied to every path point.

A navigation mesh is also a valid solution, not inherently too slow. It provides continuous walkable space, but still needs semantic restrictions to distinguish road from sidewalk. Navigation layers can restrict which regions a path query may use. Agent avoidance must still be integrated with movement; it is not a guarantee that a character stays within the intended pedestrian corridor. [Godot navigation layers](https://docs.godotengine.org/en/4.7/tutorials/navigation/navigation_using_navigationlayers.html), [NavigationAgents](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationagents.html)

Do not build both systems initially. If corridor following later struggles in an irregular area, evaluate a small local navigation mesh there while retaining the graph for block-to-block routing. That is an optional later decision, not a prerequisite.

## Incremental stages

### 0. Establish a reversible baseline

**Change:** Add a separate crowd test scene that instances the current city, with a disabled-by-default crowd controller. The user supplies the player. Record a fixed test route and seed. Capture frame time, physics time, rendering time, draw calls, memory and active NPC counts with crowds disabled and with a small existing-civilian sample. Inspect the current scene before relying on the layout manifest.

**Pass:** The test setup reproduces the city and current NPC behavior without changing the main scene or movement controls. Record the machine, resolution, renderer and target frame rate. Set an acceptable crowd cost from the measured remaining frame budget; do not promise a civilian count before profiling.

**Fallback:** Disable/remove only the test-scene crowd instance. Preserve a named Git checkpoint or scoped backup of touched files; never reset unrelated user changes. Use this same checkpoint procedure before every subsequent stage.

### 1. Draw a graph for a few blocks, without civilians

**Change:** Choose adjacent residential blocks with an alley and an intersection. Generate a small pedestrian graph and a toggleable debug overlay. Show sidewalk, alley and crossing routes in distinct colors. Keep generation separate from the city generator. Merge contiguous walkable patches before creating routes; mesh chunk boundaries and rectangle fragments are not street corners.

**Pass:** Inspect every pilot connection. Routes have body-width clearance, crossings align with marked crosswalks, and no edge cuts through buildings, ordinary road space or water. Validate connected components and deliberately unreachable destinations. Start/end projection must use a reachable corridor, not merely the nearest point across a barrier.

**Fallback:** Disable the overlay and unload graph data. No civilian behavior has changed.

### 2. Make one civilian follow a fixed sidewalk route

**Change:** Implement destination walking for one opted-in civilian. Retain existing physics and reactions. Follow a known sidewalk/alley path, with arrival handling and a stationary fallback when no route exists. Recompute paths on destination changes or invalidation, not every physics tick. Leave legacy wandering available for existing developer-spawned NPCs outside this experiment.

**Pass:** Repeat straight segments, right-angle corners, alley entrances and both travel directions. The character reaches the destination without oscillation, wall clipping or leaving its corridor. A missing path produces a controlled stop, not random road wandering.

**Fallback:** Turn off route following for that test civilian and restore its previous behavior. Do not enable a citywide crowd using the legacy wander behavior.

### 3. Add explicit road crossings

**Change:** Add approach, optional brief wait, crossing and exit phases. Calm civilians may occupy road surfaces only inside an active crossing corridor. On completion, continue to a sidewalk destination. Full vehicle/traffic-light simulation is outside this stage.

**Pass:** Cross in both directions, traverse successive intersections and approach from each sidewalk. Test a blocked crossing and a destination across an unconnected road. Civilians wait or replan without walking along the carriageway. Waiting happens on the sidewalk, not halfway across the road.

**Fallback:** Disable crossing links and restrict destinations to each connected sidewalk component. Keep successful sidewalk movement.

### 4. Add a small, believable local crowd

**Change:** Increase to roughly 20–40 full civilians in the pilot area. Add destination selection, small speed differences, pauses and corridor-safe lateral variation. Use a nearby-neighbor spatial grid for simple separation/yielding. Limit static obstacle probes to relevant nearby characters and stagger decisions; retain physics-tick movement. Show health labels only through the appropriate debug option.

**Pass:** Run opposing streams through the same sidewalk, corners and alley entrances. Civilians do not permanently jam, overlap heavily or use the road to pass each other. A blocking object causes waiting or a valid reroute. Record CPU and animation costs versus stage 0.

**Fallback:** Disable separation/variation independently or lower the population cap. Keep routing and crossing rules intact. If separation is unreliable, use conservative spacing while diagnosing it.

### 5. Introduce a bounded nearby population and pooling

**Change:** Manage civilians by block-sized spatial cells around the player. Enforce a hard cap on full characters and a per-frame activation budget. Reuse instances with explicit reset of health, reaction state, route, animation, velocity and signals. Populate valid corridors out of direct view where possible; never remove an interacting civilian merely because the camera turns.

**Pass:** Repeatedly enter/leave the pilot area and turn the camera rapidly. Counts remain bounded, reused characters have no stale state or duplicated signals, and activation does not create large frame spikes. Disabling the crowd returns to baseline behavior.

**Fallback:** Disable streaming/pooling and use the fixed pilot population from stage 4. Pooling should not be a dependency of route correctness.

### 6. Add lightweight midrange walkers

**Change:** Add an actual lightweight representation without `NPCBase` physics, health labels or per-tick obstacle probes. Store route edge, progress, speed, appearance and animation phase as compact state. Stagger route/behavior updates around 5–10 Hz and interpolate visible movement. Reduce animation and shadows separately. Transfer state when promoting to or demoting from a full civilian.

**Pass:** Follow a civilian across both LOD boundaries in both directions. No duplicates, resets, backwards motion or large position jumps occur. Promotion places the full body in a valid unoccupied spot; if unavailable, defer safely. Keep hit-reacting or otherwise interacting civilians full until safe to demote. Measure savings rather than assuming lower-frequency scripts make skeletal animation cheap.

**Fallback:** Disable midrange walkers and use the bounded full-character population. Keep this tier's data separate enough that it can be removed without changing routing.

### 7. Handle fast flight and abrupt landings

**Change:** Prepare population ahead of velocity and likely landing areas. Use camera distance/projected size for visual importance and player proximity plus interaction reach for full simulation. Use different promotion/demotion thresholds and a short dwell time. Budget activations across frames and reserve capacity for interactions.

**Pass:** Test sustained fast flight, sharp reversals, looking behind, steep dives and sudden landings. The nearby crowd is ready when gameplay can affect it, frame times stay within the stage-0 target, and representation changes are not conspicuous. Test any existing ranged/area effects that can reach beyond the full-simulation radius; define promotion or coarse handling before allowing those interactions to miss distant civilians.

**Fallback:** Disable prediction and use conservative fixed ranges plus strict caps. Reduce density or speed of activation before removing the caps.

### 8. Add far visuals only if profiling and appearance justify them

**Change:** Experiment with simple meshes, impostors or baked animation for distant pedestrians. Consider one MultiMesh per small spatial cell and appearance group, not one for the entire city. Distant visuals have no individual physics. They still follow pedestrian routes and promote consistently when approached. Ordinary independent skeletal animation is not supplied automatically by MultiMesh.

**Pass:** Compare quality, draw calls, animation cost and GPU time against stage 7. Inspect street views and high-altitude views. Keep the tier only if it noticeably improves perceived population at an acceptable cost. MultiMesh culling operates on the batch, which is why spatial subdivision matters. [Godot MultiMesh guidance](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html)

**Fallback:** Disable far visuals. Keep full and midrange walkers, and district population records outside the visible area.

### 9. Add panic and recovery

**Change:** Give nearby affected civilians safe escape destinations. Initially flee along existing pedestrian routes; add explicitly validated emergency road routes as a separate option. Keep normal and emergency permissions separate so one fleeing civilian cannot globally open roads to calm walkers. Threats notify nearby cells instead of every civilian scanning every threat. Add a safe-duration/recovery rule before returning to pedestrian routes.

**Pass:** Trigger panic near a crossing, building corner, alley, bridge and pier. Civilians can escape across allowed emergency road corridors without entering buildings or water. Calm bystanders still obey crossing rules. Recovery rejoins a reachable sidewalk without teleporting. Stress-test many simultaneous reactions and LOD transitions.

**Fallback:** Disable emergency road access and retain sidewalk-only fleeing. Disable the new panic controller separately if necessary; preserve existing damage and hit reactions. Ordinary full civilians must never be demoted mid-reaction during earlier stages either.

### 10. Expand across districts and tune density

**Change:** Validate the graph district by district, then enable one district at a time. Add higher density around commercial frontage and park edges, moderate residential density, and sparse alley/industrial populations. Store population targets in distant cells rather than simulating persistent full characters everywhere. Limit destinations to authored walkable routes; filling the park interior is a separate decision while it remains a placeholder.

**Pass:** Check all intended sidewalk components, river crossings, waterfront routes and district seams. Reject stale graph data when relevant geometry changes; rebuild only pedestrian data and preserve scene edits. Repeat the fixed performance route and worst-case crowded landing with each expansion. Confirm global full/mid/far budgets remain bounded as enabled city area grows.

**Fallback:** Disable the most recently enabled district or reduce its density. Retain previously accepted districts and their proven limits.

## Initial tuning hypotheses

These are starting experiments, not guaranteed capacities. Expose relevant settings in the Inspector when their stage is implemented.

| Setting | Initial experiment |
| --- | --- |
| Full simulation | About 60 m, with an initial cap around 80; begin below this in the pilot |
| Lightweight walkers | About 60–180 m, initial cap around 300 |
| Far visuals | About 180–400 m, only after measuring a benefit |
| Midrange decisions | Staggered 5–10 Hz; interpolate movement between updates |
| LOD thresholds | Separate entry/exit distances; tune margins for flight speed |
| District density | Express as pedestrians per usable route length, constrained by global budgets |

Do not lower `move_and_slide()` frequency on full interactive characters merely to achieve an LOD target. Use the lightweight representation for that saving. Offscreen nearby interactions still need correct simulation. No-distance-limit crowds and unrestricted per-agent repathing are excluded from the initial design.

## Checkpoint record

Copy this record for each implemented stage:

```text
Stage:
Status: not started / in progress / accepted / rolled back
Checkpoint or scoped backup:
Files changed:
Enabled settings, seed and crowd counts:
Godot version, renderer, hardware and resolution:
Test route and duration:
GDScript/scene validation result:
Observed behavior and remaining defects:
Baseline versus current frame/physics/render time, including spikes:
Animation, path-query, active-body and draw-call counts where available:
Fallback exercised and result:
Next stage permitted by these results:
```

Use targeted automated checks for graph connectivity, forbidden-surface intersections, route-state transitions and representation handoff. Use actual playtesting for crowd believability, foot sliding, popping and frame pacing. Do not claim a visual or gameplay test passed based solely on a headless check. Player spawning itself is user-owned and is not a requested test.

## Current checkpoint: one-civilian pilot

The user authorized the graph and one walking civilian, including the existing walking animation, and requested only short safety checks before their own visual test. A separate removable pilot component is instanced into Super City; the player's placement and other city edits are preserved. It implements a small authored graph, fixed destinations, sidewalk/alley walking, crossing waits and conservative stopping when blocked. A short headless scene-load/movement check passed. This covers the pilot functionality of stages 1–3, but visual acceptance is still pending. Stage 0's crowd performance baseline remains deferred until population work begins; no full benchmark or player-spawn test was performed.

Do not mark stages 1–3 visually accepted or begin population/LOD work until the user has assessed the pilot. The immediate next step is their walkthrough, then any corrections to the single civilian.

First walkthrough feedback: the user confirmed the pilot works, then requested passing people instead of waiting, uninterrupted corner movement, and crosswalks before junctions. These refinements are implemented for a second visual check. Crosswalks now occupy 3 m bands with a 2 m setback on approach roads, with the pilot crossing aligned. Passing is limited to valid walkable pavement and may still wait if no safe space exists. Only the crossing has a scheduled pause. A short character-obstruction check passed; full crowd behavior and LOD are still deferred. The user's active `main.tscn` file was preserved.

## Current checkpoint: district-organized coverage

The user accepted the pilot including crosswalk passing, then authorized modular citywide coverage with per-district route checkboxes and one test civilian per selected route. River crossings remain excluded until bridges exist. Implemented 260 selectable modules, 5,261 points and 6,133 segments, connected into two separate banks. Super City now instances the new route component; the old pilot remains available separately. Eight modules are enabled initially, one per district, under a global test cap of 16. District checkboxes, enable/disable-all buttons, debug visibility, module StartHere markers and root population counts support the next walkthrough.

Generation and short control/movement checks passed, including actual graph connectivity and saved disabled checkbox state. `main.tscn` and the player's placement/code were preserved. This is a routing coverage test, not implementation of production crowd behavior, streaming or LOD. See `assets/super-city/pedestrians/README.md` for the next tests and `INVENTORY.md` for the route list. User visual acceptance of the expanded network is pending.
