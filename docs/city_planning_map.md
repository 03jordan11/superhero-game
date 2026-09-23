# City planning map

Outputs are in `artifacts/city_planning_map/`:

- `city_overhead.png`: 3800 × 2800 overhead map.
- `city_overhead_grid_250m.png`: the same layout with a candidate 250 m grid.
- `layout.json`: current saved placements, polygons and source scene hashes.

The September 22, 2026 snapshot contains 1,955 regular buildings and 16 landmark sites. It reads `scenes/main.tscn` with its saved SuperCity overrides, without adding Main to the tree or running city gameplay.

Regular buildings show transformed main-mesh bounds. Landmarks include their grounds and placed props in their bounds. Roads use the authored road rectangles and bridge profiles. The river uses its actual mesh triangles; the park and ocean use bounds. Hidden branches, small props, actors and outer terrain are omitted. Coordinates are relative to SuperCity, in metres, with negative Z upward. The cross marks the recorded FPS test position at X −1286.5, Z −478.6.

The grid is a comparison aid, not implemented HLOD chunks. Cell counts in the interactive map assign buildings by their footprint centres; they are not draw-call counts. Final chunks can follow roads and should keep whole buildings together. The distance rings measure horizontal map distance.

## Regenerate

From the project directory in PowerShell (substitute your Godot and Python paths):

```powershell
& 'D:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . --log-file 'D:/Superhero Game/superhero-demo/artifacts/city_map_export.log' --script benchmarks/export_city_planning_map.gd | Out-Host
python benchmarks/build_city_planning_map.py
```

The Python script requires Pillow. Wait for `CITY_MAP` and successful Godot exit before running Python. An optional `--fragment <path>` refreshes the embedded dataset in the existing conversation map.

Validation: Godot export completed without GDScript errors; duplicate building roots and empty exports are checked. The generated images were inspected. Browser checks covered grid changes, zoom, distance rings, click selection and narrow layout; light and dark appearances were inspected. No in-game test is required for these offline map tools.
