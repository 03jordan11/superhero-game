# Forest travel-boundary planning

Open `scenes/super_city.tscn` in the Godot 3D editor. Expand:

```
SuperCity
  ForestBoundaryMarkers
    Highway
      Highway_01 ... Highway_04
    Coastal
      Coastal_01 ... Coastal_04
```

The placed cyan posts now define the travel-boundary planning envelope used for the terrain trim. Select a numbered point and press **F** to focus it. Move the whole point with the Move tool (or Inspector Position). Its origin at the base of the post is the boundary location; the 300 m post makes it easy to find over terrain. Place its base at local ground height.

Use **Ctrl+D** to add points wherever the boundary bends. Keep points named in order along each boundary; use separate subgroups for disconnected stretches. Save SuperCity after positioning. The points do not automatically form a closed polygon or choose which side is playable. When handing back the layout, identify the playable side and any intended flight-height limit; those determine which distant areas can actually be seen.

The markers are editor-only and remove themselves when the game starts. They have no collision and do not enforce a travel limit. The reusable marker is `scenes/planning/forest_boundary_marker.tscn`; its runtime cleanup is `scripts/editor_boundary_marker.gd`. The approved trim keeps a 2 km backdrop buffer outside their saved envelope; see `docs/forest_boundary_trim.md`. Moving markers later does not automatically rebake terrain.

## Proposed next pass

- Keep smaller forest chunks in reachable areas and along the travel boundary.
- Use simplified 1,000 x 500 m forest meshes for visible, unreachable backdrop areas. Keep each chunk to one surface/material and replace its individual tree renderers.
- Remove trees in areas hidden from all reachable viewpoints, including allowed flight heights. Being unreachable alone does not mean an area is invisible.
- Preserve visible mountain/shoreline silhouettes and use a final forest visibility cutoff. Large backdrop chunks trade finer culling for fewer draw submissions, so keep them outside the nearby band.

The boundary trim is now applied. Forest proxy/chunk meshes remain a later pass.
