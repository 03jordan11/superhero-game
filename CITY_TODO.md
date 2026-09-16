# City follow-up tasks

These items are deferred. This file records discussion; it does not implement or authorize all listed changes at once.

## Collision simplification

- [ ] Replace detailed concave ground/road/sidewalk collision geometry with a modest set of BoxShape3D regions where the surfaces are effectively flat.
- [ ] Preserve river and bay gaps, the pier footprint, and any meaningful elevation differences. Do not place one uninterrupted collision floor across water.
- [ ] Remove the superseded surface collisions rather than stacking new boxes over them. Keep visual meshes independent of the simplified collision layout.
- [ ] Retain more accurate collision only where its shape affects gameplay. Existing building boxes may already be sufficient.
- [ ] Compare scene size, save/load behavior and physics behavior before and after. Check walking, landings, objects and waterfront edges separately.
- [ ] If complex shapes remain, consider external binary `.res` files for those resources while retaining an editable `.tscn` scene.

## Route simplification — investigate only

- [ ] Measure routing, avoidance, animation and physics costs separately before deciding whether fewer graph points are worthwhile.
- [ ] Investigate removing redundant points on straight segments while preserving turns, crossings, district/module connections and required clearance.
- [ ] Consider caching test journeys and rebuilding only affected modules when editor selections change.
- [ ] Preserve district checkboxes, test-start markers, the civilian cap and the intentionally disconnected riverbanks.

## Crowd performance and capsule batching — investigate only

- [ ] Record frame time, physics/script time, rendering time, draw calls and full/capsule counts on the same traversal route with crowds disabled, normal settings and a heavier population. Include fast flight, wide city views and bursts of LOD transitions.
- [ ] If distant capsule draw calls are a significant cost, investigate spatially grouped MultiMeshes using the existing capsule tier. Preserve per-person route state, skin tones, population accounting and promotion/demotion; avoid one citywide batch with poor culling.
- [ ] Compare batching against the current shared-mesh capsule implementation before adopting it. Optimize full-body simulation or transition spikes separately if those are the measured bottlenecks; add another LOD tier only if appearance or profiling justifies it.

## NPC avoidance — initial soft boundary implemented

- [x] Keep the existing three-point passing maneuver; use routes as a preference rather than a hard boundary.
- [x] Allow physically supported ground beside buildings, with pavement preferred, then setbacks, then short road detours.
- [x] Retain solid-body sweeps and use shallow ground probes outside the route to reject unsupported ground and the current water placeholders.
- [x] Expose waypoint arrival tolerance (default 0.2 m) instead of requiring 0.025 m precision.
- [x] Avoid whole-route replanning for a nearby person; reuse the existing committed passing side.
- [x] Raise the cap to 1,000. It now lives on CivilianCrowd; nearby spawning replaces one civilian per enabled module.
- [x] Add nearby population, segment starts, configurable lane offsets and shared skin-tone variants; see `assets/super-city/pedestrians/CROWD.md`.
- [x] Add CapsuleLOD child settings, cheap moving visuals and state-preserving full/capsule handoff; see `assets/super-city/pedestrians/CAPSULE_LOD.md` for visual tests.
- [x] Add a small no-progress recovery for full civilians: reverse the current route segment after a short randomized delay, clear the failed passing maneuver and prevent another recovery for four seconds. Intentional crossing waits and hit reactions do not count; collisions remain enabled.
- [ ] Visually check busy corners, building setbacks and waterfront edges. Fully blocked space can still require waiting; this is not a crowd negotiation system.
- [ ] Visually evaluate the turnaround recovery at opposing walkers, corner turns and blocked destinations. Investigate remaining route/offset problems; consider temporary NPC-only collision exceptions only if turnaround recovery proves insufficient.
- [ ] NPC deadlock reported again on September 8 after testing turnaround recovery. Get the new reproduction details and investigate in a separate follow-up; leave avoidance behavior unchanged during code cleanup.

## Particle renderer errors — investigate later

- [ ] Investigate intermittent `particles_get_instance_buffer_motion_vectors_offsets: Parameter "particles" is null` (`servers/rendering/renderer_rd/storage_rd/particles_storage.cpp`). No visible defect reported; deferred at the user's request.
- [ ] Reproduce hard-landing dust/debris and vehicle-explosion fire/sparks separately with rendering enabled; correlate errors with effect creation, emission and deletion using temporary lifecycle logs.
- [ ] Determine whether this is effect initialization/cleanup or an engine renderer issue before changing behavior. Related but not confirmed identical: https://github.com/godotengine/godot/issues/122005. Headless tests cannot establish a rendering fix.

## POI rendering distance and HLOD — deferred

- [ ] Prioritize Godot visibility ranges for small POI props such as benches, tables and minor decorations: hide their visuals entirely beyond a tuned camera distance instead of creating replacement meshes.
- [ ] Expose distances by prop size/type and test street movement, rooftop views and fast flight. Tune transition margins to avoid rapid visibility toggling near the cutoff; preserve independently editable prop instances and gameplay collision.
- [ ] Keep automatic mesh LOD enabled on the buildings. Profile CPU/GPU frame time, draw calls and rendered triangles before investing in custom distant building versions.
- [ ] If profiling justifies custom building HLOD, consolidate distant geometry/materials while preserving landmark silhouettes and night-only emission. Compare one representative POI against automatic LOD before extending the approach to all buildings.

## Working constraints

- Keep each implementation change small and independently reversible.
- Preserve the user's work in `main.tscn` and existing player behavior.
- Use short targeted checks, then give the user specific visual tests. Do not begin production crowd/LOD work as part of a local avoidance fix.
