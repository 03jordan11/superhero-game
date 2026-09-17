# Modular city roads

Open **`res://scenes/previews/modular_road_test.tscn`** and press **F6**.
The scene contains saved, individually selectable kit instances: loose samples,
connected 20/28/12 m streets, 40 m and 120 m texture comparisons, and a road
flanked by pieces from the existing sidewalk kit. F4 switches to the player;
Home returns the player to the start. In overview, right-drag orbits,
middle-drag pans, and the wheel zooms.

The initial conversion of all **24 `Roads/roads_*` chunks** used **780 editable road instances**.
**657** include fitted sidewalks; **55** independent paving pieces remain under
`Sidewalks/sidewalks_*` for custom areas. Long straight runs share a road body
with their pavement. The continuous riverside promenade, bridges outside these
chunks, airport roads and Pine Pass highway retain their existing geometry.

After the user's first editing pass, **751 road instances remain**. The later
[river cleanup](../river-cleanup/README.md) removes old bridge remnants and adds
ground beneath former road footprints. Conversion counts and footprint audits
below describe the original 780-piece rollout, before those manual edits.

## City layout and editing

Open `res://scenes/super_city.tscn`, expand `Roads/roads_x_z`, and select the
module root. Its mesh, pavement and collision move together. Resize with
**Length M**, keeping the node Scale at (1, 1, 1). Textures and lane markings
retain their metre scale. Junctions own their 8 m approaches; adjoining
straights exclude those lengths.

**Sidewalk Cutouts** are local X/Z rectangles that preserve alley entrances,
frontage gaps and river edges. They move with their road; review them when
changing a fitted piece's dimensions. **Trim To Bounds** clips a piece to its
original chunk, including intersections straddling two chunks. Disable it when
reusing the complete preset elsewhere. Hidden sockets outside clipped geometry
are inactive. Independent `FittedPaving_*` pieces can still be resized directly.

There is one pavement layer, with the original surface at Y = 0.03 m. Exact
road and sidewalk footprints are retained, including the earlier waterfront
stub removal and ground infill. All 6,404 unrelated scene node blocks were
compared with the pre-rollout scene and are identical. Chunk roots retain their
node IDs and paths, including now-empty Sidewalks chunks.

`city_conversion.json` is the current footprint/placement and count audit.
`roads_2_1_conversion.json` and the sidewalk kit's conversion JSON files are
historical source audits. Traffic layout is byte-identical: 700 lanes and 1,830
turn connections. Pedestrian routes retain 262 modules and their two riverbanks;
only the scene fingerprint changed. Moving roads later still requires a separate
route update. Traffic's existing 2 m junction stop margin is unchanged; vehicles
may stop past the new painted stop bars at 6–6.5 m from the junction.

## Performance of the city conversion

Native Godot inventory of these 48 road/sidewalk chunk branches, including
chunk roots and excluding unrelated city geometry:

| Metric | Before | After |
| --- | ---: | ---: |
| Runtime nodes | 12,472 | **2,718** (-78.2%) |
| Mesh instances / static bodies | 1,846 | **835** (-54.8%) |
| Collision shapes | 3,022 | **835** (-72.4%) |
| Mesh surfaces | 2,217 | **1,492** (-32.7%) |
| Rendered triangles | 38,996 | 47,940 (+22.9%) |

The comparison starts with 23 old merged road meshes, the approved modular road
trial, and the already consolidated sidewalk kit. Triangles increase because
individually editable modules have their own slab edges. Mesh surfaces are not
the same as draw calls: shared meshes/materials can instance, and visibility
changes which surfaces render.

City instances have **Keep Sockets At Runtime** disabled: alignment markers
remain in the editor but are omitted from the running scene. Editor node count
is 13,638, versus 12,472 before. The reduced runtime count includes removing those
helpers. Every paved road shares the existing sidewalk material; only asphalt
parameters vary per module. No geometry is regenerated each frame.

The combined trial needed 34 bodies instead of 91 for fully separate modular
roads and sidewalks. Full-city measurements below compare the final saved city
against the actual pre-rollout scene, alternating before/after twice per view
in the same running Main scene. Godot 4.7.2, RTX 4090, Forward+/D3D12, 1920x1080,
VSync off; simulation frozen to isolate rendering. Each number is the mean of
two sample medians. This is a short rendering comparison, not gameplay FPS.

| View | Frame time before -> after | Draw calls before -> after |
| --- | ---: | ---: |
| West street | 1.905 -> 1.807 ms | 983 -> 923 |
| East avenue | 1.873 -> 1.754 ms | 1,184 -> 1,032 |
| River overhead | 3.482 -> 3.487 ms | 1,713 -> 1,743 |
| Skyline | 3.965 -> 4.071 ms | 1,966 -> 2,022 |

The street views benefit, the overhead view is approximately unchanged, and
the skyline pays a small cost for finer mesh granularity. The principal win is
fewer runtime objects and collision shapes while keeping the city editable.
Existing building occluders still cull these mesh instances; road and sidewalk
slabs are not added as occluders themselves.

## Presets

| Scene in this folder | Default configuration | Rendered triangles including sidewalks |
| --- | --- | ---: |
| `straight_12m.tscn` | 12 m road, 40 m long | 30 |
| `straight_20m.tscn` | 20 m road, 40 m long | 30 |
| `straight_28m.tscn` | 28 m road, 40 m long | 30 |
| `alley_6m.tscn` | 6 m unmarked road, 40 m long | 30 |
| `junction_cross.tscn` | Four-way, 20 m Ã— 20 m center | 170 |
| `junction_t.tscn` | North / East / West open | 150 |
| `corner_90.tscn` | North / East open, 20 m roads | 130 |
| `dead_end.tscn` | 20 m road, 24 m long, sidewalk closes South | 40 |
| `alley_entrance.tscn` | North/South 20 m road with an East 6 m alley | 150 |

These are presets of one simple `@tool` script. Their saved meshes and static
collision resources are in `meshes/`; their Inspector settings reconstruct
geometry once on load and when edited. There is no per-frame generator.
Each piece has one mesh (asphalt and optional sidewalk surfaces), one static
concave collision shape, and connection markers. No addons are required.
Generated collision has a 1 mm horizontal overlap to avoid numerical cracks
at shared boundaries; the rendered footprint and surface height stay exact.

## Resizing and connecting

1. Drag a prefab into a scene, then select its root.
2. Keep **Scale = (1, 1, 1)**. Change **Length M** for a straight, alley or
   dead end. Length starts at 0.1 m for boundary fragments and can exceed the
   200 m slider range. Use enough length for any enabled end crosswalks.
   Geometry, collision, end crosswalks and markers update together. Length M
   has no effect on a junction: its dimensions follow its two street widths.
3. **Width M** selects the North/South road width. On a junction,
   **Cross Width M** selects the East/West road width. Width presets are
   6, 12, 20 and 28 m. The 6 m preset has no longitudinal lane markings.
4. **Active Arms** sets the open junction approaches: North = local -Z,
   East = +X, South = +Z, West = -X. Rotate the whole piece in 90-degree steps.
   North/South-only and East/West-only connectors are also supported.
5. Align two active **RoadSockets** at the same position, with their outward
   directions facing each other and matching widths. Markers point outward
   along local -Z. Use a 1 m translation grid; half-metre lengths may require
   a finer grid or entering the exact position. Sockets are alignment guides,
   not automatic magnetic snapping.

The root pivot is at the road center. Straight sockets sit at Â±Length M / 2.
Junctions include **8 m of approach beyond each open edge of the center box**:
North/South sockets are Cross Width M / 2 + 8 m from the center, and East/West
sockets are Width M / 2 + 8 m away. For example, a 20 Ã— 28 m junction has
North/South sockets at Z Â±22 m and East/West sockets at X Â±18 m.

Extending a piece moves both ends equally. To keep one end fixed, move its
center by half the length change along the road. Neighboring pieces do not
automatically move when this piece changes length or width.

## Sidewalk connections

**Include Sidewalks** defaults to on. The sidewalks are 4 m wide, share the
existing kit's material, and meet its surface at **Y = 0.03 m**. The root stays
at Y = 0. Sidewalks remain flush with roads, matching the current city.

Junction pavement turns around every corner. A closed arm receives a continuous
sidewalk across that edge. Open arms expose two **SidewalkSockets**, aligned
with the 4 m sidewalks on the next road. Left and Right are relative to looking
outward from that arm. Hidden markers with `active = false` are not connections.

Included sidewalks belong to the road module and resize with it. To arrange
pavement independently, disable Include Sidewalks and use the existing
`modular-sidewalks` kit. The preview includes an example. Do not place a second
sidewalk over an included sidewalk. The alley also offers optional sidewalks;
turn them off when matching existing city alleys, which lack dedicated sidewalks.

## Markings and texture scale

Asphalt repeats in world space every 4 m. Paving uses the existing world-space
4 m texture. Lane lines use physical metre coordinates: white dashes are 3 m
long on an 8 m repeat, and retain their dimensions at every road length.
Their world-aligned phase matches across cardinally rotated connected pieces.
**Dash Offset M** provides a manual phase adjustment if needed.

**Crosswalk Arms** controls crossings independently on junction approaches.
Straight and dead-end pieces have **Crosswalk North/South** toggles. Crosswalks
are 3 m deep and sit 2â€“5 m from the center junction edge (or straight endpoint);
their stripes repeat every 1.2 m. Length edits add asphalt and marking repeats
rather than stretching a single painted texture. Junction centers remain clear,
consistent with the current city style.

Enabled crosswalks also include a white stop bar on the approaching half of the
road, following right-hand traffic. The bar is 0.5 m thick with a 1 m gap before
the crossing. Longitudinal white and yellow markings stop at its outer edge;
they do not resume between the crosswalk and the intersection. This applies to
both junction approaches and straight-piece end crossings, including rotated
pieces. Disabling that crosswalk also removes its stop bar and marking setback.

## Validation and review

- `tests/test_city_modular_roads.gd`: 24 chunks, 835 instances, actual mesh area,
  openings, seam support, moving collision and historical ground infill;
  **131,509 probes, zero failures**.
- `tests/test_modular_roads.gd`: nine saved presets, 132 junction configurations,
  resizing, save/reload, rotated cutouts and optional runtime helpers;
  **10,711 probes, zero failures**.
- The older sidewalk and roads_2_1 regression entry points now select the
  corresponding chunks in the combined road/pavement validator.
- City POI integration, pedestrian network, traffic controls, traffic spawning
  and movement, and river-mouth regression checks pass. The latter samples
  276 bridge positions and 4,204 pedestrian route positions.
- Main was rendered and inspected at street level, over the river and from the
  skyline. No manual player traversal was performed. Existing host log,
  certificate and resource UID warnings are unrelated to this conversion.

In Godot, reopen the source city scene, select/move/undo a road piece, and change
Length M on a straight. Run Main, walk across intersections and chunk seams,
check alley openings and waterfronts, then observe cars turning and pedestrians
crossing. Existing roads leading outside the city remain a separate editing task.

Rollout files: `scenes/super_city.tscn`, `road_module.gd`, `city_conversion.json`,
both kit READMEs, `assets/super-city/pedestrians/network.json` (fingerprint only),
`tests/test_city_modular_roads.gd`, `tests/test_modular_roads.gd`, and the three
older chunk regression entry points. Profiling, screenshots, one-off authoring
scripts and the pre-rollout backup remain in ignored `artifacts/`.
