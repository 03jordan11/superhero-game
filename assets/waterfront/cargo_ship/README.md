# Cargo ship

Original Blender-built container ship inspired by the supplied reference. No names,
registration numbers, logos, flags or container identifiers are painted on the asset.

## Open and test

- Open `cargo_ship_preview.tscn` in Godot and press **F6**.
- **1–4** select Ocean Blue, Oxide Red, Deep Teal and Graphite.
- **N** switches day/night; **A** cycles Underway, Anchored and Berthed lighting.
- Left-drag orbits, right-drag pans, mouse wheel zooms, **B** views the stern, **R** resets.
- For a player test, instance any `cargo_ship_<variant>.tscn` in your test level.
  Align its root Y to the water surface. Land on the forecastle, containers and bridge roof.
  Collision covers hull, deck, all 147 containers and major superstructure; thin fittings
  and rails are decorative. A standalone instance stays still; the vessel placed in
  Main now follows a twice-daily harbor schedule. See [cargo_ship_schedule.md](../../../docs/cargo_ship_schedule.md).

The root is at the waterline, the bow points **−Z**, and **+X is starboard**.
Length is 156 m, beam 24 m, draft approximately 6 m. The scheduled Main instance uses
its authored placement as the berth; independent instances are ready to place.

## Modular materials

`cargo_ship.blend` contains four scenes selectable from Blender's Scene dropdown.
Their geometry and texture images are shared; each scene has object-level material
assignments. The clean GLB exports only the Ocean Blue ship, without preview lighting.

Godot variants share that GLB. Each has a palette Resource in `materials/`, with seven
editable slots: hull, deck, superstructure and four container colors. The individual
StandardMaterial3D resources use shared grayscale panel/weathering textures. Assign a
different palette on the ship root, or use **Make Unique** before changing a single
ship. Navigation colors are kept separate from cosmetic palettes.

## Lighting

Underway: red port and green starboard lights (112.5° each), two forward-facing white
masthead lights (225°), and a white sternlight (135°). The aft masthead is 6 m higher;
mastheads are 119 m apart. Directional shader sectors rotate with the ship. Sidelights
have black inboard screens. The bow mast is ahead of cargo and the after mast clears
the bridge/funnel. These lenses have no omnidirectional colored spill.

Anchored: two all-round white lights, forward higher than aft, plus deck illumination;
a black ball is displayed in daylight. Berthed: navigation/anchor lamps are off, with
optional working lights. Six downward deck floodlights use shadowless SpotLight3D nodes.
These are game-scale lights; nautical-mile photometric visibility is not simulated.

Ships follow `day_night_cycle.night_lighting_changed`, including night-time spawns.
Without a clock, use `standalone_night_amount`. Per-instance light materials prevent
one ship's settings affecting another. The Inspector exposes mode and brightness.

Reference: [USCG Rules 21, 23 and 30](https://www.navcen.uscg.gov/navigation-rules-amalgamated)
and [International Annex I](https://www.navcen.uscg.gov/annex1-international-positioning-technical-details-lights-shapes).

## Triangle audit and verification

- Blender triangulated geometry: **4,204**.
- Actual exported GLB and Godot imported geometry: **4,204**.
- Seven native 8-triangle lenses + 8-triangle day ball: **64**.
- **Complete scene: 4,268 triangles per variant**, counting every placed container and
  every lens, including mutually exclusive lighting modes. Under the strict 5,000 limit.
- Preview ocean and non-rendered collision are excluded. No LOD reduction is needed.

`validation_report.json` records all four imported scenes. Tests cover triangle counts,
palette assignments, navigation sectors/positions/modes, independent emission, clock
updates/night spawns, and collision rays on deck, containers and bridge roof. Blender
and actual Godot Forward+ renders are in `artifacts/cargo_ship/`. The superhero controller
has not been manually playtested on the ship.

Full editor import also reports existing city resource UID/MultiMesh warnings and sandbox
certificate/user-folder warnings; the cargo ship tests and rendering complete separately.

## Files and rebuilding

All asset additions live in this folder; the test is `tests/test_cargo_ship.gd`.
Existing gameplay and harbor scenes are not modified.

1. Blender: `--background --python assets/waterfront/cargo_ship/tools/build_cargo_ship.py`
2. Godot: `--headless --editor --import --path .`
3. Godot: `--headless --path . --script res://assets/waterfront/cargo_ship/tools/prepare_cargo_ship.gd`
4. Godot: `--headless --path . --script res://tests/test_cargo_ship.gd`
5. Godot: `--path . --script res://assets/waterfront/cargo_ship/tools/render_cargo_ship.gd`

Generators overwrite this asset's generated geometry, palettes and scenes. Preserve any
manual asset edits before rebuilding. No third-party addons are required.
