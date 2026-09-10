# SuperCity traffic — staged implementation

## Steps 1–4: implemented

`SuperCity/TrafficManager` owns the local traffic system. It is an instance of `scenes/vehicles/traffic_manager.tscn`; its settings can be overridden directly in SuperCity's Inspector. It works in Main using the player group, or in standalone SuperCity using the active preview camera. An explicit Focus Path overrides automatic player selection; the optional camera fallback applies if that focus is missing.

The city manifest, `assets/super-city/layout.json`, supplies street and junction rectangles, orientation and width. At startup the manager generates 706 straight lane records from 353 street sections, plus shared Curve3D connections through their junctions: one lane per direction, with right-hand traffic by default. There are no manually placed paths, mesh scans, per-car path searches, or Path3D nodes. Roads of different widths are supported. Alleys, pier access and pedestrian routes are excluded. Data is local to SuperCity; keep the city at unit scale. Rebuild the manifest if you change road geometry independently of the city generator.

Cars accelerate along a fixed lane, slow behind another managed car, and stop for physical obstacles. One box sweep plus an initial-overlap check per active car per physics tick handles ordinary physics bodies, with no search/retry escalation. Turns also check the next rotated box pose. Vehicle dimensions come from each scene's existing BoxShape3D. The probe is slightly shorter vertically to avoid treating the road as an obstruction. These checks can see existing pedestrian bodies, but no pedestrian scripts, collision settings, crosswalk rules or reactions were changed.

Cars pause before the junction, choose straight/left/right once, and enter in arrival order when the junction and their exit have room. One car owns a junction until its rear clears the exit. Entry checks include managed cars and physical obstacles at the exit; a new obstruction can still make a car wait during traversal. Pickup, removal, destruction or traffic disable releases the reservation. There are no U-turns or global route searches. The current layout has 688 lanes with onward connections and 18 genuine terminal lanes; cars at those road ends can stop. Long-stopped cars are recycled only out of view and away from the player.

Spawns are weighted by road length inside the local radius, with a preference for the camera direction while stationary and movement direction during fast player travel. Nearby roads retain coverage on all sides. A per-lane spawn cap reduces queues. New cars are kept outside the camera frustum by default (including their mesh bounds); this may underfill the target while looking over a large area. Ordinary distant traffic has a despawn delay and extra visible retention range. Interacted vehicles use the separate abandoned cleanup rules below. Camera-frustum checks are conservative visibility estimates, not occlusion tests.

The actual existing colored vehicle scenes are instantiated. Meshes, scales, collision boxes and damage/throw functionality are preserved. Traffic drives the frozen RigidBody3D in kinematic freeze mode; no wheel animation, suspension or VehicleBody3D is used. The supplied meshes are treated as facing local +Z. Each entry has Heading Offset Degrees (use 180 for a scene facing -Z).

## Vehicle engine audio

All seven base vehicle scenes instance `scenes/vehicles/engine_sound.tscn` as `EngineSound`; colored variants inherit it. The shared `scripts/traffic/vehicle_engine_sound.gd` starts the supplied `assets/audio/Vehicles/care_engine.mp3` automatically, loops a private resource copy, and stops on destruction. Random playback offsets prevent spawned cars from playing the recording in lockstep without changing traffic's random sequence. Pickups retain their engine sound.

Open `engine_sound.tscn` to tune all cars together: **Volume Db** defaults to -6, **Unit Size** to 12 metres, and **Max Distance** to 80 metres. AudioStreamPlayer3D supplies spatial panning and distance attenuation relative to the active camera/listener. **Engine Enabled** controls playback at spawn. Distant traffic proxies stay silent; full vehicle scenes carry the sound. Normal scene pause behavior pauses engines too.

Each model's **EngineSound → Engine Character → Base Pitch** gives it a distinct sound: SUV 0.82, cop 0.92, normal car 1 0.96, taxi 1.00, normal car 2 1.03, sports car 1 1.16, and sports car 2 1.23. Color variants inherit these values. Every spawned car adds a stable random variation of up to ±4%. **Base Pitch** replaces the native Pitch Scale for tuning, since the script updates Pitch Scale live.

**Speed Pitch Increase** raises pitch by up to 18% at **Pitch Reference Speed** (12 m/s), with **Pitch Response** smoothing acceleration and deceleration. Set the increase to zero to disable this response or variation to zero to remove per-car randomness. Godot's pitch scaling also speeds up/slows down playback of the same recording; these settings affect audio only, not driving speeds. Cars carried or thrown return to idle pitch. Engine Character controls can be tuned live in the Remote Inspector; save lasting changes in the scene Inspector.

Test beside a busy road: approaching cars should become louder, move across the stereo field, and fade as they leave. Compare the deeper SUV with the higher sports cars, and listen to traffic slow at a junction and accelerate away. Walk farther away or fly up to check distance attenuation. Destroy a vehicle to verify its engine stops. Run `tests/test_vehicle_engine_sound.gd` for scene, playback, pitch variation, speed response, looping, inheritance, reparenting, and destruction checks; these do not replace an in-game listening test.

## Vehicle explosion audio

The shared `effects/vehicle_explosion_effect.tscn` plays `assets/audio/Vehicles/explosion.mp3` at the blast location whenever a vehicle explodes. Its **Explosion Audio** Inspector group exposes **Sound Enabled**, **Sound Volume Db** (+3 dB), and **Minimum / Maximum Sound Pitch** (0.92–1.08). Pitch variation also varies playback length, roughly ±8%, independently for each explosion. The source MP3 is unchanged.

The child **ExplosionSound** exposes native 3D distance settings: Unit Size 25 m and Max Distance 180 m. A dedicated **VehicleExplosions** bus limits peaks. The sound belongs to the explosion effect, so removing the vehicle does not cut it off. Visuals still end after their configured lifetime; the hidden effect is freed once the audio finishes.

Test several vehicle explosions, listen for small variations, and step farther away to check attenuation. `tests/test_vehicle_explosion_audio.gd` verifies actual vehicle destruction, spatial placement, variation, the sound tail, and cleanup. The existing thrown-vehicle and engine-audio checks cover related behavior.

## Inspector settings

The main and pause menus now expose Low / Medium / High population presets. Inspector values remain the High baseline; see [Population settings](POPULATION_SETTINGS.md) for density/distance mappings, persistence, and testing. City rendering distance is deferred.

Select `SuperCity/TrafficManager`:

| Setting | Default | Purpose |
| --- | --- | --- |
| Traffic Enabled | On | Disables and gradually removes managed traffic; leaves interacted cars alone. |
| Population Target / Max Vehicles | 8 / 12 | Baseline full-car spawn population / physics vehicle cap including carried and released cars. LOD promotions can use headroom above the target. SuperCity currently uses 20 / 30. |
| Spawn Radius / Minimum Spawn Distance | 160 / 30 m | Horizontal distance from player or camera. |
| Despawn Radius | 230 m | Removes ordinary traffic beyond this radius; always at least Spawn Radius + 20 m. |
| Spawn Interval / Attempts | 0.5 s / 6 | At most one successful spawn per update, with bounded placement attempts. |
| Prefer Offscreen Spawns | On | Keeps new cars outside the camera view; can leave population below target. Disable for a visible spawn test. |
| Forward Spawn Bias / Surrounding Radius | 0.75 / 45 m | Prefer the direction of view or fast travel outside the nearby circle. |
| Max Vehicles Per Lane | 2 | Limits new spawns per lane; moving cars can still join a populated lane. |
| Despawn Delay / Visible Retention Margin | 2 s / 80 m | Delay retirement and retain visible cars beyond the normal radius, up to this extra range. |
| Offscreen Stopped Recycle Delay | 25 s | Recycle long-stopped traffic only outside camera view and beyond Minimum Spawn Distance. |
| Abandoned Cleanup Enabled | On | Independently cleans up eligible released traffic vehicles, including while Traffic Enabled is off. |
| Abandoned Cleanup Distance / Delay | 250 m / 30 s | Released car must remain beyond this horizontal distance, outside the camera frustum and nearly stationary for the entire delay. |
| Abandoned Max Linear / Angular Speed | 1 m/s / 0.5 rad/s | Maximum movement and spin allowed during the cleanup countdown. Frozen/carried cars are protected. |
| Minimum / Maximum Speed | 5 / 8 m/s | Approximately 18–29 km/h. Selected at spawn. |
| Acceleration / Braking | 2.5 / 6 m/s² | Smooth normal starts/stops; travel is clamped for sudden obstructions. |
| Minimum / Maximum Following Gap | 2 / 4 m | Extra bumper space sampled once per car. The following car's value controls spacing, including spawn clearance. |
| Junction Stop Margin | 2 m | Extra room before the street section ends. Applied at spawn. |
| Intersection Pause | 0.8 s | Minimum pause at the junction, followed by waiting for access if needed. |
| Minimum / Maximum Intersection Speed | 3 / 5 m/s | Junction speed limit sampled once per car, capped by cruise speed. SuperCity overrides this to 4 / 6 m/s around the user's previous 5 m/s setting. |
| Straight Ahead Weight | 3 | Straight is three times as likely as each available turn. |
| Lane Center Offset | 3 m | Distance from street centerline; limited by road width. Restart to rebuild. |
| Keep Right | On | Opposing lane placement. Restart to rebuild. |
| Road Height | 0.03 m | Lane elevation relative to SuperCity, plus collision-bottom clearance. |
| Show Lane Debug | Off | Generated orange street lines and junction curves; restart after changing. |
| Show Health Labels | Off | Applies to newly spawned cars. |

The full population stays small, with two visual tiers under `TrafficManager/DistantTraffic`: car silhouettes and farther flat colored rectangles. Defaults seed 160 visual cars inside 900 m and 200 more between 900 and 1,800 m, drawn in 250 m regional MultiMeshes. Actual 3D distance selects the representation: rectangles beyond 1,000 m return to silhouettes inside 800 m; full-car promotion retains its existing distance and approach lead. See [TRAFFIC_LOD.md](TRAFFIC_LOD.md) for settings, caps, transition safeguards and tests. Population can be underfilled when space is blocked or no road is near the focus.

## Suggested denser baseline — not applied as defaults

Select SuperCity -> TrafficManager and try the following in the Inspector. Start by changing density, then tune movement. These values are a gameplay starting point, not measured FPS guarantees. Current defaults remain unchanged except for the newly added abandoned cleanup settings.

| Setting | Current | Try | Reason |
| --- | ---: | ---: | --- |
| Population Target | 8 | 20 | Main density control: desired driving cars across all nearby roads, not per road. |
| Max Vehicles | 12 | 30 | Leave space above the driving target for carried/released cars. |
| Spawn Radius | 160 m | 140 m | Concentrates cars nearer you. Increasing radius without increasing population spreads them thinner. |
| Minimum Spawn Distance | 30 m | 35 m | Keep new cars away from the immediate interaction area. |
| Spawn Interval | 0.5 s | 0.25 s | Fill nearby roads faster; at most one successful car per update. |
| Spawn Attempts Per Update | 6 | 10 | More chances to find clear, offscreen space; additional placement work. |
| Max Vehicles Per Lane | 2 | 3 | Allow more cars to spawn on each directional street section; arrivals can exceed this spawn cap. |
| Forward Spawn Bias | 0.75 | 0.5 | More even coverage around you; 0 means no directional preference, 1 means strongest forward preference. |
| Surrounding Radius | 45 m | 60 m | No forward preference on roads sampled inside this radius. |
| Minimum / Maximum Speed | 5 / 8 m/s | 7 / 11 m/s | Roughly 25–40 km/h; random cruise speed is chosen at spawn. |
| Acceleration | 2.5 m/s² | 2 m/s² | Gentler starts. |
| Braking | 6 m/s² | 5 m/s² | Earlier, gentler planned stops; sudden obstructions still clamp travel immediately. |
| Minimum / Maximum Following Gap | 2 / 4 m | 2 / 4 m | Varied bumper spacing without rerolling during movement. |
| Intersection Pause | 0.8 s | 0.5 s | Shorter mandatory stop, without bypassing queue/exit checks. |
| Minimum / Maximum Intersection Speed | 3 / 5 m/s | 4 / 6 m/s | Varied traversal speeds, including turns; already applied in SuperCity. |
| Straight Ahead Weight | 3 | 5 | With all three exits available: 5/7 straight, 1/7 left, 1/7 right. |

Keep Prefer Offscreen Spawns on initially. Looking over many roads can keep the population below target; temporarily disable it only to distinguish placement restrictions from insufficient density. At the suggested interval, 20 cars require at least five seconds to populate an empty area, and longer when attempts fail. Keep Despawn Radius 230 m, Despawn Delay 2 s, Visible Retention Margin 80 m, Offscreen Stopped Recycle Delay 25 s, and Junction Stop Margin 2 m initially. Higher population can queue at intersections because one vehicle enters at a time. Use VehiclePerformanceMonitor to compare the same route before raising the target further.

Focus Path chooses an explicit player/camera node; leave empty for the player group, with Use Camera Without Player for standalone preview. Traffic Enabled controls ordinary driving/spawning. Layout File, Lane Center Offset, Keep Right, Road Height and Show Lane Debug affect generated roads and require a restart. Health label changes and vehicle selection changes apply to newly spawned cars. Restart after tuning for a consistent comparison; editor Inspector edits affect the next run, while the Remote Inspector is for temporary live testing.

Following gap and intersection speed are now minimum/maximum pairs. Each car samples both at spawn and keeps them while driving, waiting and turning. Changing the ranges affects newly spawned cars. Equal limits give fixed behavior; if maximum is below minimum, minimum is used. The gap also applies to obstacle stopping and outgoing-lane clearance. Intersection speed is a cap, so congestion or a lower cruise speed can make a car slower. SuperCity's other user-tuned settings are preserved; the old fixed Intersection Speed override of 5 m/s was replaced by 4–6 m/s.

## Scene array and spawn percentages

Expand Vehicle Entries. Each `TrafficVehicleEntry` keeps a Scene, Weight, Distant Color, and Heading Offset Degrees together. Add an entry and drag a Vehicle scene into its Scene field. Supported scenes have the shared Vehicle script on a unit-scale RigidBody3D root and the existing direct child CollisionShape3D with a BoxShape3D aligned along Z. Distant Color colors the box representation; it does not change the real scene's materials. Boxes also require the existing direct MeshInstance3D for bounds, measured once per entry.

There are 17 default entries, using the existing 15 paint variants, cop car and taxi. Weights sum to 100 initially:

| Type | Total weight across colors |
| --- | ---: |
| Normal car 1 | 30 |
| Normal car 2 | 25 |
| SUV | 20 |
| Sports car 1 | 7 |
| Sports car 2 | 5 |
| Taxi | 10 |
| Cop | 3 |

Actual chance is `entry weight / total enabled weight`. Weights need not sum to 100; zero disables an entry. Small local samples won't have exact percentage quotas. Adding colors separately lets you tune each color's frequency. If you want a scene-local edit without altering another manager instance, make its entry resource unique in the Inspector first.

## Pickup, release and lifetime

Pickup calls `Vehicle.leave_traffic()` before the existing carry code records the release parent. The manager moves that car under `ReleasedVehicles`, then pickup moves it under the player. Drop/throw returns it to ReleasedVehicles and unfreezes it. Traffic never resumes control or snaps it back onto a lane. Destroyed/freed cars are removed from traffic records.

Carried/released cars count toward Max Vehicles until destroyed/freed, so collecting cars cannot spawn unlimited replacements. Abandoned cleanup now frees capacity when a released car remains more than 250 horizontal metres from the focus, outside the camera frustum, moving no faster than 1 m/s and spinning no faster than 0.5 rad/s for 30 continuous seconds. Any failed condition resets its timer. A visible car is always protected by this cleanup, even at very large distances. Without a valid focus or camera, cleanup pauses and resets the timers. Frustum checks do not detect building occlusion, so a car hidden behind a building but inside the camera frustum remains protected.

Only vehicles originally spawned by this manager and handed off to ReleasedVehicles qualify. Carried, frozen, active traffic and externally reparented cars are protected; placed gallery vehicles are untouched. The weak record survives repeated pickups/drops and is discarded when the vehicle is freed. Cleanup runs independently of Traffic Enabled; use Abandoned Cleanup Enabled to disable it. Switching it off resets countdowns. No damage/explosion is triggered by cleanup. No vehicle returns to driving after a drop.

Weak references track ownership without keeping destroyed nodes alive. Cleanup scans only the small released-vehicle dictionary and uses position, velocity and camera checks, with no pathfinding or physics queries. Abandoned and ordinary traffic share a limit of one retirement per physics tick. Capacity becomes available after the queued deletion is processed and ownership is pruned on the next tick; normal spawn updates refill the population. Nearby, visible, moving or deliberately retained cars can still occupy the hard cap. Lane data is shared and per-car records are removed on release/retirement.

## Plan and remaining steps

1. **Local moving cars — complete:** generated straight lanes, weighted scenes, stopping and pickup handoff.
2. **Intersections — complete:** generated straight/curved connections from road/junction geometry. Pause, one car at a time, clear exit, rear-clear release and cleanup. No whole-city destination search.
3. **Population refinement — complete:** road-length weighting, direction preference, per-lane spawn caps, offscreen spawning and stopped-car recycling, delayed distance cleanup and visibility hysteresis.
   **Abandoned cleanup — complete:** configurable distance, continuous offscreen/stationary grace period, carry protection and hard-cap recovery.
4. **Distant silhouettes and rectangles — complete:** a shared body-and-cabin mesh at intermediate distance, a two-triangle flat mesh farther away, regional MultiMeshes, palette colors, straight-only motion without physics queries, altitude coverage, stable identity and position across all tiers, bounded spawning/full transitions and cleanup.
5. **Polish and rules:** horns with a cooldown, wheel animation, lights/signs controlling intersection access. Coordinate pedestrians only after traffic is established.

### Distant traffic

There are three representations total: full nearby cars, silhouettes, and very distant rectangles. The implemented settings and limitations are in [TRAFFIC_LOD.md](TRAFFIC_LOD.md). No shader-driven motion or pedestrian coordination has been added. Full cars finish turns before demotion; damaged, carried and thrown cars remain physical. A blocked/cap-limited promotion waits and hides inside the 35 m interaction guard, rather than creating an overlapping collider or unlimited full cars.

## Performance monitoring and validation

The existing Main/PerformanceMonitors/VehiclePerformanceMonitor includes traffic moving counts, active/retained/stopped/at-junction counts, completed crossings, occupied junctions, cumulative `abandoned_cleaned`, lane count, and `traffic_manager` / `traffic_obstacle_sweep` / `traffic_junction_movement` timings. It also reports boxes, regions, promotions/demotions, blocked promotions, hidden nearby boxes, and box simulation/render-update CPU timings. Nested times overlap. Frozen traffic can be moving despite zero rigid-body linear velocity, so the monitor also checks its traffic speed. No additional monitor is required.

Headless tests:

- `tests/test_traffic_manager.gd`: generated lane directions, weighted selection, spawn spacing, movement, obstacle stop/resume, endpoint stop, actual ray pickup/drop, retained cap bookkeeping and cleanup.
- `tests/test_super_city_traffic.gd`: real SuperCity roads, local spawning, movement, population cap, relocation and disable.
- `tests/test_traffic_intersections.gd`: real-city straight/left/right turns, pause, position continuity, blocked exit, one-car occupancy and pickup/free reservation cleanup.
- `tests/test_traffic_population.gd`: offscreen spawns, camera/travel preference, lane/population caps, despawn delay and visible retention.
- `tests/test_traffic_abandoned_cleanup.gd`: grace/reset, visibility/distance/motion/carry protection, repeated pickup/drop, toggles and missing focus/camera, one retirement per tick, freed weak-record cleanup and population refill.
- `tests/test_traffic_driving_ranges.gd`: bounded variation, equal/inverted ranges, spawn clearance using the following car's gap, and actual stopping distance with different gaps. The intersection test also checks stable choices and each car's junction speed cap.
- `tests/test_traffic_box_lod.gd`: stable handoff, batching, blocked/full-cap transitions, pickup protection, altitude/approach behavior and cleanup.
- `tests/test_super_city_traffic_lod.gd`: actual city distant coverage, descent promotion and shutdown; optional rendered capture. Full-only fixtures explicitly disable DistantTraffic.
- `tests/test_traffic_far_lod.gd`: third-tier geometry, hysteresis, stable handoff, independent radial populations, combined caps and repeated cleanup. The city LOD test also accepts `-- --tier3` to check the complete system.
- Existing player vehicle release, thrown-impact, and world-monitor tests check integration.

Manual test:

1. Restart Main and stand beside a road for several seconds, then look along nearby streets. Cars spawn outside view by default; disable Prefer Offscreen Spawns to watch them appear. They should accelerate without animated wheels and face their travel direction.
2. Watch a junction: cars should pause, take turns entering, travel straight or turn, and continue down the next street. Block a car with the player or a vehicle, then clear the road. Check stopping distance and restart, including an obstruction at an intersection exit.
3. Pick up a moving car, carry it, and drop/throw it. It must not snap back to traffic. Check damage/explosions in Main.
4. Move a few blocks; old ordinary traffic should retire and new traffic populate local roads. Check that the cap is respected.
5. Run SuperCity directly. Its preview camera initially sits over the park: fly toward a street to bring roads within the spawn radius. No Player instance is added. Hold RMB to move/look, WASD, Q/E vertically, Shift faster.
6. Adjust vehicle weights, speed and population, and enable lane debug to inspect alignment. Check several vehicle shapes and both travel directions visually.
7. Pick up and drop a spawned traffic car. For a faster test, set Abandoned Cleanup Distance to 80 m and Delay to 5 s. Move beyond 80 m and look away once it settles: it should disappear after five seconds and free population capacity. Look back or approach before five seconds: the timer should reset. Carried cars and moving throws must remain. Restore 250 m / 30 s after the test. The monitor's `abandoned_cleaned` counter confirms cleanup occurred.
8. Restart SuperCity/Main after changing gap or junction speed ranges. Watch a queue for different bumper gaps and several free junction traversals for different speeds. Each car should remain consistent; set minimum equal to maximum to compare fixed behavior.
9. Fly 400–600 m high, wait about ten seconds for distant population, then descend toward a colored box. Check long-distance coverage and its transition to a full car. See TRAFFIC_LOD.md for the complete visual checklist.

Headless tests do not establish visual quality or gameplay FPS. Existing certificate-store warnings are unrelated to traffic.

## Files

- New: `scripts/traffic/traffic_vehicle_entry.gd`, `traffic_lanes.gd`, `traffic_manager.gd`, `traffic_box_lod.gd`, `traffic_proxy_mesh.gd`.
- New: `scenes/vehicles/traffic_manager.tscn`, the nine traffic tests, this README and `TRAFFIC_LOD.md`.
- Updated: `scenes/super_city.tscn`, `scripts/vehicle.gd`, `scripts/player-scripts/player_vehicle_interactor.gd`, `scripts/ui-scripts/vehicle_performance_monitor.gd`, `tests/test_world_performance_monitors.gd`.
