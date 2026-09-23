# Boxing gym interior

Open **boxing_gym.tscn** and press **F6**. The scene itself includes the existing
player and spawns them just inside the front door, facing the gym. There is no
separate test scene. WASD and mouse move/look; Shift sprints; Space jumps.
The over-the-shoulder camera matches the hideout: 1.5 m distance, (0.6, 0.75, 0)
offset, -8 degree pitch, 0.3 m clearance sphere and 0.25 m margin.
The root script exposes camera settings and indoor walk/sprint speeds (3.3/6 m/s).

At the corner stairway, press **E** to enter the ring. At the same corner inside,
press **E** to return to the floor beside the stairs. It uses the existing
interaction action and displays its current binding if remapped. Interaction
is proximity/grounded-state gated, clears momentum and takes priority over
grabbing. Holding E does not repeat the teleport.

The placed exterior's front door now loads this room with E while looking at
the door. The interior front door returns to the placed exterior with E.
Travel preserves the current player, progress, menus and city time. Direct F6
play remains supported; its exit cannot travel without an originating city.
The rear exit and bathroom door remain closed scenery. `PlayerSpawn`,
`RingSpawn` and `OpponentSpawn` allow for the current centre-origin player capsule.

## Layout

- One 24 × 22 m hall, 8 m high, with a closed ceiling and boarded windows.
- Ring: **6.10 × 6.10 m clear inside the ropes**, 7.4 × 7.4 m platform,
  canvas surface 1 m above the floor. Four 4 cm ropes at 0.4/0.7/1.0/1.3 m
  above the canvas. Based on the dimensions in World Boxing's published rules:
  https://worldboxing.org/wp-content/uploads/2024/11/World-Boxing-Competition-Rules-Nov-2024-Approved.pdf
- All four sides have continuous ropes and collision. The steps sit at the
  near-left corner; E transfers the player past the ropes into that corner.
- Rear catwalk and open office at 3.6 m, reached by stairs on the left.
- Exactly two heavy bags, one wall-mounted speed bag and one dumbbell rack.
- Eight lockers, three benches, five rubber mats, wordless glove posters,
  an office desk/chair, two small crates, a kit bag, towels and water bottles.
- Two wide metal-grid front windows, a bathroom exterior beneath the office,
  a rear door with an illuminated EXIT sign, and two storage racks with boxes
  reused directly from the hideout's meshes and materials.

Equipment is static scenery for now. No enemies, tutorial, bag interaction,
bathroom interior or power machine are included.

## Editing

Expand `Architecture`, `Training`, `Props` or `Lighting` in the interior scene.
Every placed physical object is an instance of a reusable scene under `props/`.
Move/rotate/remove these roots normally; their collision and attached lights
move with them. Ring and ring steps are separate objects. Enable **Editable
Children** only when changing a specific instance's internals; edit the source
prop scene when a change should apply to all its instances. Reused shelf boxes
are nested scene instances too. `RingAccess` references the stairs and ring by
NodePath; moving either piece also moves its respective interaction/destination.

The `materials/` folder contains shared editable materials. The five original,
seamlessly tiled procedural texture maps are under `textures/`. There is no
lettering on the posters or equipment. EXIT is the only authored sign lettering.

## Blender source and rebuild

`source/boxing_gym.blend` contains the assembled editable model with packed
textures and named object parents. Its ceiling, front wall and entrance door
are hidden in the Blender viewport for a convenient cutaway; unhide them to
inspect the enclosure. They remain present in the Godot scene.

`source/` has `.gdignore`: Godot uses the prepared native scenes/meshes rather
than launching Blender during import. Separate GLBs and `manifest.json` retain
the source geometry, placements and collision definitions.

Offline rebuild order (back up asset edits first):

1. Run Blender in background with `--python tools/build_gym.py` (full file path).
2. Run Godot `--headless --editor --import --quit` to import the textures.
3. Run Godot with `--headless --script res://assets/interiors/boxing_gym/tools/prepare_gym.gd`.

The preparation tool preserves existing scene placements and materials, adds
missing pieces, and refreshes only the prop scenes in its `REFRESH` list.
It extracts the hideout rack/boxes into reusable gym prop scenes without
modifying the hideout. Their native mesh references remain shared. The one-time
playable revision moves the ring stairs and spawn markers to the new layout.
The player script has a small interaction hook for the ring's existing E action.

## Verification

`TRIANGLE_AUDIT.json` counts actual imported highest-detail meshes, including
each of the 62 placed instances. The complete interior has **16,940 triangles**,
below the requested 50,000-triangle limit. The player character, interaction UI
and invisible collision are excluded.

Run `tests/test_boxing_gym.gd` with Godot `--headless --fixed-fps 60 --script`.
It checks the actual triangle count, separate scene instances, equipment
inventory, floors and ring/catwalk heights, movable prop collision, capsule
ascent, direct player spawn/camera, closed ropes, E entry/exit and held-key
debouncing, and the existing player walking up to the catwalk.
Godot renders were also inspected from the entrance, ring, equipment wall,
office, cutaway and player camera.

For an in-editor acceptance check: run the gym scene, approach the corner steps
and press E, circle the canvas, return to that corner and press E again. Inspect
the front windows, rear exit and bathroom exterior; climb the left staircase
and walk across the rear catwalk to the office. Move a prop and rerun F6 to
check the changed arrangement.
