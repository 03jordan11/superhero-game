# Urban night lighting

> **Current status:** The commercial window shader/occupancy rollout below was reverted.
> Production towers now use [seeded copies of the original emission maps](seeded_city_windows.md),
> with roughly 40% fewer lit windows. The original shapes, colors and material energy remain.
> The updated sky, environment, fog, bloom, and street lighting are retained unchanged.
> The historical window controls below are inactive; use the CityWindows controls instead.

## Previous window implementation (reverted)

Commercial towers 01–20 now separate the facade's window outlines from occupancy.
The old 64×64 emission PNGs painted a lit/dark pattern over four floors and four
bays, repeating that pattern across the whole tower. They remain as source assets,
but runtime lighting uses an architectural coverage mask and a separate office
atlas. No building mesh, door, collision or triangle count changed.

## Occupied offices

`scripts/office_occupancy.gd` creates one 128×64 RGB atlas per building placement.
It covers 64 floors, 16 bays and eight facade orientations. Whole floor bands can
be vacant, while rectangular groups of adjacent windows represent office suites.
The generator selects mostly dark, moderate and busy profiles with weights of
40%, 45% and 15%. A stable seed comes from the asset path and initial world X/Z
position, or an explicit Inspector seed. Loading the same placement gives the
same tenants. Camera motion and time of day do not regenerate the pattern.

Each building uses a mostly warm-white or neutral-white palette, with cool-white
buildings uncommon. Brightness and subtle tint vary by office group, not by random
RGB values per window. The shader retains the original albedo, window frames and
roughness, and adds emission only inside window glass. The source emission PNG's
old repeating on/off pattern is not multiplied back into the new occupancy.

All commercial assets share `commercial_skyscraper_01.gd`; each placement shares
its room atlas between its facade materials. The existing DayNightCycle signal
still fades emission through dusk and dawn. Buildings spawned after dark bind
the current clock and global tuning settings immediately.

## Main Inspector controls

Select `SuperCity/DayNightCycle` (or `Main/SuperCity/DayNightCycle` during play).

| Control | Default | Effect |
| --- | ---: | --- |
| Window Occupancy Scale | 1.0 | Scale tenant occupancy; 0 closes every office. Rebuilds atlases only when changed. |
| Window Brightness Scale | 1.0 | Scale commercial emission without changing tenants. |
| Star Density | 0.08 | Reject faint stars from the existing cubemap. |
| Star Intensity | 0.18 | Brightness of the remaining stars; previously 1.5. |
| Milky Way Intensity | 0.0 | The galaxy band is suppressed for an urban sky; previously 1.3. |
| Horizon Light Pollution | 0.12 | Gentle warm skyglow concentrated near the horizon. |
| Night Fog Density | 0.00055 | Mild distance haze; previously 0.0002. |
| Bloom Intensity | 0.18 | Restrained glow; previously 0.65. |
| Bloom Threshold | 1.8 | Keep ordinary surfaces out of bloom; previously 1.2. |

Night ambient energy remains 0.28 and moonlight energy remains 0.22 to preserve
nearby surface/player readability. Daytime sunlight and ambient defaults remain
unchanged. Skyglow fades toward the zenith, and star visibility falls near the
horizon. Fog gently reduces contrast over long distances without a near-camera
fog wall. These controls apply while the clock is paused as well as running.

Per-building controls include `occupancy_seed`, `occupancy_override` (-1 uses the
automatic profile), `dark_floor_fraction` (0.24), and `window_emission_energy`
(1.25, previously 2.0). Set per-building profile controls before instantiation;
use the clock's occupancy/brightness controls for live tuning.

## Street level and budgets

`SuperCity/NightLights` adds 373 supported corner fixtures around actual junctions,
checking sidewalk support, roads and separation from existing poles. Fixtures
remain batched MultiMeshes. The original real-light pool remains capped at 96.

A separate pool of at most 24 shadowless spotlights serves the 702 front/rear
commercial entrances. Pools are selected near the camera at the existing 0.2 s
interval, fading toward their selection boundary. Frontage selection uses 3D
distance, so high flight does not spend the entrance-light budget below the player.
The default frontage energy is 2.4, range 12 m and selection radius 100 m.
Warm or neutral light reaches doors, nearby storefront surfaces and pavement.

There are no per-window lights, timers or per-frame random numbers. Occupancy
textures are generated on initial load or explicit occupancy tuning only. At
351 placements the atlases contain approximately 8.2 MiB of raw RGB texels;
actual GPU allocation differs by renderer. No new mesh passes or building
triangles are added. The street/entrance subsystem has at most 120 real lights;
existing vehicle, POI and gameplay lights are separate. No GPU frame-time
benchmark is claimed.

## Validation and review

Passed in Godot 4.7.2:

- `tests/test_urban_night.gd`: 64 deterministic occupancy samples, adjacent-office
  grouping, dark floors, no four-floor repetition, profile range, tuning restore,
  midnight spawning, daylight shutoff, sky/fog/bloom controls, and bounded pools.
- Commercial 01, 02 and 03–20 regression checks: geometry budgets, masks,
  doors, city placements, collision and clock binding.
- Existing city night-light integration and day/night clock tests.
- Headless editor import completed with no GDScript parse errors; existing
  MultiMesh editor and local environment warnings remain.

The sample occupancy audit ranges from approximately 1.2% to 39.3% lit office
cells; these are atlas cells, not a measurement of each rendered facade.
Actual Forward+ city renders were inspected in `artifacts/urban_night/before/`
and `after/`: skyline, offices, entrance, intersection and sky. They show the
lighting result in the real city, without a manual movement playtest. Existing
road UID fallbacks and Windows certificate/user-directory warnings remain outside
this lighting work.

For a manual check: run Main, use `time night` and `time pause`, walk past a
commercial doorway and intersection, then fly toward distant towers. Check
visibility, haze and stable office groups. Try Window Occupancy Scale 0, then 1:
the same office layout should return. Use `time day` to check daylight shutoff.

## Changed files

- `scripts/day_night_cycle.gd`, `scripts/city_night_lights.gd`.
- New `scripts/office_occupancy.gd` and generated UID.
- `assets/sky/hero_sky.gdshader`.
- `assets/generated-buildings/commercial/commercial_skyscraper_01.gd`.
- New `assets/generated-buildings/commercial/materials/occupied_windows.gdshader`
  and generated UID.
- `scenes/super_city.tscn`: saved sky/glow fallback values.
- `assets/super-city/pedestrians/network.json`: source-scene hash only.
- New `assets/sky/tools/render_urban_night.gd` and generated UID.
- New `tests/test_urban_night.gd` and generated UID.
- Updated commercial 01/02/batch tests and `tests/test_day_night_cycle.gd` (its
  optional legacy fill-light node had already been removed from Main).
- This guide and `artifacts/urban_night/` comparisons, audit and validation logs.

The offline Asset Dashboard does not execute building scripts; its authored
material preview is not a preview of the new runtime occupancy shader. Use the
Godot captures or run the city to review this lighting change.
