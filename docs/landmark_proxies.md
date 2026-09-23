# Landmark distant replacements

The city now has 17 independent landmark replacements under **Main/SuperCity/LandmarkProxies**. They cover the two banks, boxing gym, City Hall, firehouse, hospital, eight parking garages, police station, gas station hideout, and Central Park. Ordinary city building chunks, traffic controls, streetlights and street benches are unchanged by this pass.

## What actually renders

Each distant landmark is a saved **ArrayMesh with one surface and one ShaderMaterial**. It is newly constructed box/tier geometry with directional facade images baked from the real landmark. City Hall additionally has newly generated low-sided drums and domes. Separate source windows, columns, furniture, roof details and similar objects are painted into those images instead of remaining separate distant meshes. The garages use an exterior shell plus a flat entrance alley.

Central Park is one two-triangle rectangle with an overhead texture of its grass, lake, paths and vegetation. There are no distant tree meshes or animated lake/firefly effects in that replacement.

When a replacement activates, the corresponding **original landmark root's Visible property becomes false**, hiding all descendant geometry and lights. Its collision shapes, scripts, doors, areas and node paths stay intact. Coming closer restores the root's previous visibility. This is a rendering optimization, not unloading or a simulation optimization.

## Switching and testing

Distance is measured from the **active camera** to each landmark's own bounds centre:

- Enter the proxy beyond `bounds radius + Near Distance M + Switching Margin M`.
- Restore the original at or inside `bounds radius + Near Distance M`.
- Defaults: **100m clearance**, **25m margin**. Bounds radius is half the world-space AABB diagonal. It is not simply 100m from the centre or an exact nearest-edge measurement.
- At current placements, City Hall enters around **235m** from its centre, hospital **217m**, and the much larger park **520m**.

Restart the game after updating the files. In the **Remote** scene tree select `Main/SuperCity/LandmarkProxies`:

1. Keep the same camera position and toggle the script's **Enabled** property. Off restores originals; on resumes distance switching. Use this for an FPS comparison.
2. Expand the node. Children named CityHall, Hospital, CentralPark, etc. are the replacement meshes; their **Visible** properties indicate which ones are active.
3. Toggling the controller's **Rendering > Visibility > Visible** only hides the replacements. Originals stay hidden where a replacement is active. This is useful to prove which geometry is being replaced, but is not an original-versus-proxy performance comparison.
4. Approach City Hall, the hospital and park; check that the original detail returns. Check landing/collision and enter/exit the gas station and gym as usual.

## Verified geometry

These are sums of stored mesh surfaces and highest-detail triangles, **not frame draw calls or FPS measurements**. Render passes, shadows, occlusion, and which landmarks are currently distant determine actual frame cost.

| Scope | Original triangles | Proxy triangles | Original surfaces | Proxy surfaces |
|---|---:|---:|---:|---:|
| Sixteen building landmarks | 43,141 | 1,224 | 424 | 16 |
| Central Park terrain and placed visuals | 58,661 | 2 | 468 | 1 |
| Total | 101,802 | 1,226 | 892 | 17 |

Each building POI's actual complete source geometry remains below the 10,000-triangle budget. The park's existing near terrain and vegetation are preserved; the new distant park mesh has two triangles. The per-landmark audit is `assets/super-city/landmark_proxies/inventory.json`.

## Files and rebaking

- `scripts/landmark_proxies.gd`: camera distance switching, root visibility restoration, loading preparation, day/night brightness.
- `assets/super-city/tools/bake_landmark_proxies.gd`: offline generation from the current main scene; no facade rendering or geometry building runs during normal gameplay.
- `assets/super-city/landmark_proxies/`: 17 compressed `.res` meshes containing their textures/material, facade/night PNG previews, `inventory.json`, and `landmark_proxy.gdshader`.
- `scenes/main.tscn`: adds the independent LandmarkProxies controller.
- `export_presets.cfg`: includes the JSON inventory in exported games.
- `tests/test_landmark_proxies.gd`: swap/hysteresis, hidden source geometry/lights, park firefly suppression, collision preservation, loading completion, saved geometry, day/night checks.
- `tests/test_corridor_hlod.gd`: isolates its ordinary-building test by disabling the new landmark controller.

To rebake after changing landmark geometry, placement-dependent materials or garage variants, run from the project directory with the graphical renderer:

```powershell
& 'D:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --path . --script assets/super-city/tools/bake_landmark_proxies.gd --log-file 'D:/Superhero Game/superhero-demo/artifacts/bake_landmarks.log' | Out-Host
```

The `.res` files embed the textures so they work immediately without an editor import pass. Editing a preview PNG alone does not update the embedded runtime texture; rebuild the bake. Building captures use 512px per direction; the park uses one 1024px image. All 17 compressed mesh resources total approximately 12.1 MiB on disk; texture memory is larger because these embedded ImageTextures are uncompressed at runtime (approximately 261 MiB including mipmaps).

## Visual limitations and validation

These are deliberately coarse distant approximations: some side/roof projection seams and a visible change in detail at the threshold are expected. The park loses its tree silhouettes and terrain height in the distant representation. Source geometry and collision return before approaching the landmark's bounding sphere.

Facade window patterns/colors are baked using seed 8421 and the bake-time occupancy settings. The distant material follows the live day/night amount and global window brightness, but does not rebake when seed, occupancy or palette changes. Near landmarks retain their original live window system.

Validated in Godot 4.7.2: landmark tests, existing city HLOD tests and loading-screen tests pass. Graphical original/proxy captures were inspected for City Hall, hospital, boxing gym, parking garage and the park, including a City Hall night capture. Screenshots are in `artifacts/landmark_proxies/`. No FPS benchmark was run.
