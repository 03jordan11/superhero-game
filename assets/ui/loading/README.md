# Loading screen background

Replace `background.png` here to change the loading artwork. Keep the filename
and Godot will reimport it automatically. The supplied image is used unchanged.
Landscape images work best; the screen fills the viewport while preserving the
image's proportions and cropping excess edges.

Alternatively, assign the **Background Texture** on the root of
`scenes/ui/loading_screen.tscn`. That scene also contains the loading text and bar.

The shared `LoadingScreen` autoload covers New Game, Load Game, and building
entry/exit. Resources load through Godot's threaded loader. The percentage tracks
resource loading within each stage, then advances through scene setup milestones.
Scene instantiation and scene-tree changes still run on the main thread, so the
bar may briefly hold on “Preparing…” while the loading artwork stays on screen.
It reaches 100% only after the destination and player are ready.

## Integration files

- `project.godot`: registers the persistent loading screen.
- `scenes/ui/loading_screen.tscn`: background, status text, percentage, progress bar.
- `scripts/ui-scripts/loading_screen.gd`: threaded loading, rendering checkpoints,
  input/pause protection, completion and failure handling (plus generated `.uid`).
- `scripts/ui-scripts/main_menu.gd`: awaits New Game and Load Game completion.
- `scripts/save_manager.gd`: covers startup and saved-game restoration.
- `scripts/hideout_travel.gd`: covers building entry and return to the city.
- `assets/ui/loading/background.png`, its `.import`, and this README: replaceable art.
- `tests/test_loading_screen.gd` (plus `.uid`): loading, repeated requests, progress,
  input/pause restoration and failed travel.
- `tests/test_main_menu_load.gd`, `tests/test_hideout_interior.gd`, and
  `tests/test_boxing_gym_travel.gd`: await asynchronous transitions in existing checks.

## Verification

All four focused test scripts passed in Godot 4.7.2. The loading-screen test also
ran with Forward+ rendering and its screenshot was inspected at
`artifacts/loading_screen.png`. Editor import completed without GDScript parse
errors; it also reported environment access errors, duplicate UIDs in existing
artifact copies, and MultiMesh configuration errors while reopening editor scenes.
Some test runs reported shutdown object leaks. The missing-destination error in
the loading-screen test is intentional.

In Godot, test New Game, Load Game with an existing save, and entering/exiting
both the hideout and boxing gym. Check that the artwork appears before loading,
the percentage reaches 100%, movement resumes at the correct doorway, and saved
progress remains intact. Press Escape and click repeatedly during loading to
confirm that menus and duplicate transitions do not open behind the screen.
