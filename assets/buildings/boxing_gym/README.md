# Boxing gym exterior

Place `boxing_gym_exterior.tscn` in the city. Its origin sits at ground level in the centre of the building; **+Z is the front entrance**. Keep scale at `(1, 1, 1)` to match the existing gym interior, and rotate/translate the root to suit the lot.

The wall footprint is **24.8 × 22.8 m**, enclosing the interior's 24 × 22 m hall. Allow **25.12 × 24.526 m** for all projecting details, plus pedestrian space in front of the doors. The roof deck is 8.2 m high, parapet 8.88 m, and roof equipment reaches 9.35 m.

## Appearance and editing

The building uses muted brown-red brick, cool gray concrete, dark blue-gray metal and glass, a subdued green base, and a small bronze glove emblem. These follow the [Superhero City Color Palette Guide](https://docs.google.com/document/d/1Ei42N1fOiKi5Oz9Ini6oioNT8moRGq8uQoVhiqnsWQY/edit). The sign has no name or lettering.

The double doors, front windows, boarded upper side windows and rear door match the interior's locations and dimensions. Eighteen placed components are separate scene instances under the root; doors, windows, lamps, canopy, sign and roof equipment can be moved or replaced independently. Shared materials live in `materials/`, and original tiling textures in `textures/`. Lamps have editable warm lights and currently remain on.

The front `GymEntrance` uses the existing hideout travel system. Stand within 2.4 m and look at the double doors, then press **E** (or the remapped interaction key). It loads the separate gym interior and retains the current player, progress, menus and city clock. Looking away, standing behind the wall, or an obstruction blocking the door prevents entry. The inside front door returns to `FrontReturn`, following the exterior's placed position and rotation, and restores outdoor movement/camera settings. As with the hideout, returning reloads the city and its encounters. The rear door remains scenery. New Game still starts at the hideout.

The exterior contains solid building/roof collision and roof equipment collision, with no nested interior, player, preview camera or environment. `GymEntrance` exposes interaction distance, door target size and destination in the Inspector. Move `FrontReturn` if the placed building needs a different safe return position.

`Occluder` is a 24.6 × 8 × 22.6 m box inset inside the solid shell. It hides fully blocked city geometry without changing the building's rendered triangles or collision. It moves with the placed exterior.

## Source and rebuild

Blender source: `source/boxing_gym_exterior.blend`. The source folder is excluded from automatic Godot import with `.gdignore`; gameplay uses the native meshes and component scenes.

From the project root:

```powershell
& 'D:\SteamLibrary\steamapps\common\Blender\blender.exe' --background --python assets/buildings/boxing_gym/tools/build_exterior.py
```

Then run Godot headless with `--path` pointing at the project and `--script res://assets/buildings/boxing_gym/tools/prepare_exterior.gd`. Reimport changed textures in Godot before preparing native resources. These offline tools regenerate this exterior's source, textures, meshes, materials, component scenes and assembled scene. Preserve any manual edits before rebuilding.

## Validation

`TRIANGLE_AUDIT.json` records **4,128 actual imported rendered triangles**, counting every placed component instance; the complete exterior limit is 10,000. Collision shapes and editor markers do not contribute to that count.

Run `res://tests/test_boxing_gym_exterior.gd` with Godot headless to check the imported triangle count, dimensions, door/window alignment, roof/wall collision, entry clearances, and attached equipment collision. Day, entrance, rear and night GPU renders were inspected during creation.

`tests/test_boxing_gym_travel.gd` exercises E entry/exit twice using the actual placed gym in the city, checks looking-away/behind-wall rejection, and verifies player identity, clock, spawn, camera and movement preservation.

After placement, run the city, face the front doors and press E. Confirm the gym entrance spawn and shoulder camera; turn around and press E at the same doors to return outside. Check sidewalk alignment and roof landing.
