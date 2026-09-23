# City occlusion inventory

This lists source meshes used by the current city occlusion system. Paths are relative to `SuperCity`. Static occluders use actual opaque source triangles; streets, ramps, roof setbacks and openings remain open. The gym also owns an inset 12-triangle box occluder in its reusable exterior scene.

## Controls

- Project Settings → Rendering → Occlusion Culling → Use Occlusion Culling enables the engine feature.
- In the Remote scene tree, `CityOcclusion.trial_enabled` toggles all regions. Each child occluder's Visibility toggles that region.
- `TrafficManager/DistantTraffic.occlusion_culling_enabled` toggles distant vehicle culling for comparisons.
- Restart after editing source geometry. Run `tests/test_city_occlusion.gd` with `-- --write-inventory` to refresh this list.

## Included and excluded

- Districts: the main visible mesh of each placed building, excluding transparent surfaces and separate rooftop props. Standalone POIs and garages are discovered automatically under the city root.
- Central Park: opaque terrain, houses and landmarks, including the bridge. Water, trails, trees, foliage, lanterns and fireflies are excluded.
- Airport: opaque terminal, control tower and both hangars. Additional city coverage includes POIs, garages, bridges, harbor, prison, broad road/sidewalk surfaces, northern ground, coastal terrain and real mountain geometry.
- Four large land meshes use offline clipped render tiles, preserving materials, UVs, normals, shape and original collision. Hidden tiles can be culled independently. Rebuild with assets/occlusion/build_terrain_chunks.gd after editing their source meshes; stale bakes safely fall back to the source geometry.
- The distant mountain image strip is excluded as both an occluder and an occlusion target. Trees, tiny props, transparent effects, moving actors and vehicles remain eligible targets, but are not baked into solid blockers. Visible land beyond the gameplay area remains visible: this does not impose an artificial distance cutoff.
- Vehicles, characters, physics and collision shapes are never baked into these occluders. Culling affects rendering only.

## Summary

| Region | Source meshes | Triangles |
| --- | ---: | ---: |
| WestVillage | 519 | 37496 |
| CivicCenter | 229 | 8590 |
| NorthHeights | 512 | 25110 |
| Parkside | 118 | 5464 |
| FinancialQuarter | 106 | 3736 |
| Eastbank | 359 | 15992 |
| Docklands | 46 | 2624 |
| FoundryWard | 66 | 3998 |
| CentralPark | 173 | 25680 |
| Airport | 31 | 460 |
| Land_MeshInstance3D | 1 | 14109 |
| Land_NorthernGround | 1 | 6961 |
| Land_CoastalTerrain | 1 | 52883 |
| Land_PinePassMountains | 1 | 756 |
| Ground | 107 | 5292 |
| Roads | 1 | 10 |
| CityLife_Highway | 16 | 4700 |
| CityLife_Baseball | 5 | 120 |
| Waterfront_Harbor | 40 | 480 |
| Waterfront_PrisonIsland | 79 | 3188 |
| Waterfront_Riverbanks | 3 | 36 |
| SouthRiverBridge | 7 | 6616 |
| CityHallBridge | 5 | 1868 |
| NorthRiverBridge | 5 | 1292 |
| RiverFrontage | 4 | 2474 |
| MountainRiver | 2 | 983 |
| CityHall | 43 | 4208 |
| Hospital | 18 | 2502 |
| PoliceStation | 17 | 314 |
| Bank1 | 24 | 692 |
| Bank2 | 20 | 684 |
| Firehouse | 20 | 630 |
| ParkingGarage | 5 | 2680 |
| ParkingGarage2 | 5 | 4208 |
| ParkingGarage3 | 5 | 1486 |
| ParkingGarage4 | 5 | 970 |
| ParkingGarage5 | 5 | 2680 |
| ParkingGarage6 | 5 | 4208 |
| ParkingGarage7 | 5 | 1572 |
| ParkingGarage8 | 5 | 1486 |
| **Total** | **2619** | **259238** |

## WestVillage

Occluder: `CityOcclusion/WestVillage`

| Source mesh | Triangles |
| --- | ---: |
| `Districts/WestVillage/WestVillage_0001/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0002/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0003/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0004/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0005/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0006/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0007/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0008/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0009/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0010/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0011/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0012/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0013/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0014/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0015/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0016/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0017/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0018/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0019/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0020/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0021/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0022/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0023/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0024/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0025/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0026/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0027/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0028/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0029/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0030/MeshInstance3D` | 52 |
| `Districts/WestVillage/WestVillage_0031/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0032/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0033/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0034/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0035/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0036/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0037/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0038/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0039/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0040/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0041/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0042/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0043/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0044/MeshInstance3D` | 52 |
| `Districts/WestVillage/WestVillage_0045/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0046/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0047/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0048/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0049/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0050/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0051/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0052/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0053/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0054/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0055/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0056/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0057/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0058/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0059/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0060/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0061/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0062/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0063/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0064/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0065/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0066/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0067/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0068/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0069/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0070/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0071/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0072/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0073/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0074/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0075/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0076/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0077/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0078/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0079/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0080/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0081/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0082/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0083/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0084/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0085/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0086/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0087/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0088/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0089/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0090/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0091/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0092/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0093/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0094/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0095/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0096/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0097/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0098/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0099/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0100/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0101/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0102/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0103/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0104/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0105/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0106/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0107/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0108/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0109/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0110/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0111/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0112/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0113/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0114/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0115/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0116/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0117/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0118/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0119/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0120/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0121/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0122/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0123/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0124/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0125/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0126/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0127/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0128/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0129/MeshInstance3D` | 52 |
| `Districts/WestVillage/WestVillage_0130/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0131/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0132/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0133/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0134/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0135/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0136/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0137/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0138/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0139/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0140/MeshInstance3D` | 52 |
| `Districts/WestVillage/WestVillage_0141/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0142/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0143/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0144/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0145/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0146/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0147/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0148/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0149/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0150/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0151/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0152/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0153/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0154/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0155/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0156/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0157/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0158/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0159/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0160/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0161/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0162/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0163/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0164/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0165/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0166/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0167/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0168/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0169/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0170/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0171/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0172/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0173/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0174/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0175/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0176/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0177/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0178/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0206/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0207/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0208/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0209/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0210/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0211/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0212/MeshInstance3D` | 52 |
| `Districts/WestVillage/WestVillage_0213/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0214/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0215/MeshInstance3D` | 52 |
| `Districts/WestVillage/WestVillage_0216/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0217/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0218/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0219/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0220/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0221/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0222/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0223/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0224/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0225/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0226/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0227/MeshInstance3D` | 52 |
| `Districts/WestVillage/WestVillage_0228/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0229/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0230/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0231/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0232/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0233/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0234/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0235/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0236/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0237/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0238/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0239/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0240/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0241/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0242/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0243/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0244/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0245/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0246/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0247/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0251/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0252/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0253/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0257/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0258/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0259/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0260/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0261/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0262/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0263/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0264/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0265/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0266/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0267/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0268/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0269/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0270/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0271/MeshInstance3D` | 52 |
| `Districts/WestVillage/WestVillage_0272/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0273/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0274/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0275/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0276/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0277/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0278/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0279/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0280/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0281/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0282/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0283/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0284/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0285/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0286/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0287/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0288/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0289/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0290/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0291/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0292/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0293/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0294/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0295/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0296/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0297/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0298/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0299/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0300/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0301/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0302/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0303/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0304/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0305/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0306/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0307/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0308/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0309/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0310/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0311/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0312/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0313/MeshInstance3D` | 52 |
| `Districts/WestVillage/WestVillage_0314/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0315/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0316/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0317/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0318/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0319/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0320/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0321/MeshInstance3D` | 52 |
| `Districts/WestVillage/WestVillage_0322/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0323/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0324/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0325/MeshInstance3D` | 52 |
| `Districts/WestVillage/WestVillage_0326/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0327/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0328/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0329/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0330/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0331/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0332/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0333/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0334/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0335/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0337/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0338/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0339/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0340/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0341/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0342/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0343/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0344/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0345/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0346/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0347/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0348/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0349/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0350/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0351/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0352/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0353/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0354/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0355/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0356/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0357/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0358/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0359/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0360/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0361/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0362/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0363/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0364/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0365/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0366/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0367/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0368/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0369/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0370/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0371/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0372/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0373/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0374/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0375/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0376/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0377/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0378/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0379/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0380/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0381/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0411/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0412/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0413/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0414/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0415/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0416/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0417/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0418/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0419/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0420/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0421/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0422/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0423/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0424/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0425/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0426/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0427/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0428/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0429/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0430/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0431/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0432/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0433/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0434/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0435/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0436/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0437/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0438/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0439/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0440/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0441/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0442/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0443/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0444/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0445/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0446/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0447/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0448/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0449/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0450/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0451/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0452/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0453/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0454/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0455/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0456/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0457/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0458/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0459/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0460/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0461/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0462/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0463/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0464/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0465/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0466/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0467/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0468/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0469/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0470/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0471/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0472/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0473/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0474/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0475/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0476/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0477/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0478/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0479/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0480/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0481/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0482/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0483/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0484/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0485/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0486/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0487/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0488/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0489/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0490/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0491/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0492/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0493/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0494/MeshInstance3D` | 52 |
| `Districts/WestVillage/WestVillage_0495/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0496/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0497/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0498/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0499/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0500/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0501/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0502/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0503/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0504/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0505/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0506/MeshInstance3D` | 52 |
| `Districts/WestVillage/WestVillage_0507/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0508/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0509/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0510/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0511/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0512/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0513/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0514/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0515/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0516/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0517/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0518/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0519/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0520/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0521/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0522/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0523/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0524/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0525/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0526/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0527/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0528/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0529/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0530/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0531/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0532/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0533/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0534/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0535/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0536/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0537/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0538/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0539/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0540/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0541/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0542/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0543/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0544/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0545/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0546/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0547/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0548/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0549/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0552/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0553/MeshInstance3D` | 52 |
| `Districts/WestVillage/WestVillage_0554/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0555/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0556/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0558/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0559/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0560/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0561/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0562/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0564/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0565/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0566/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0567/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0568/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0569/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0570/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0571/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0572/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0573/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0574/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0575/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0576/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0577/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0578/MeshInstance3D` | 72 |
| `Districts/WestVillage/WestVillage_0579/MeshInstance3D` | 60 |
| `Districts/WestVillage/WestVillage_0580/MeshInstance3D` | 186 |
| `Districts/WestVillage/WestVillage_0581/MeshInstance3D` | 86 |
| `Districts/WestVillage/WestVillage_0582/MeshInstance3D` | 56 |
| `Districts/WestVillage/WestVillage_0583/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0584/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0585/MeshInstance3D` | 40 |
| `Districts/WestVillage/WestVillage_0586/MeshInstance3D` | 72 |

## CivicCenter

Occluder: `CityOcclusion/CivicCenter`

| Source mesh | Triangles |
| --- | ---: |
| `Districts/CivicCenter/CivicCenter_0179/MeshInstance3D` | 66 |
| `Districts/CivicCenter/CivicCenter_0180/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0181/MeshInstance3D` | 40 |
| `Districts/CivicCenter/CivicCenter_0182/MeshInstance3D` | 22 |
| `Districts/CivicCenter/CivicCenter_0183/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0184/MeshInstance3D` | 54 |
| `Districts/CivicCenter/CivicCenter_0185/MeshInstance3D` | 38 |
| `Districts/CivicCenter/CivicCenter_0186/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0187/MeshInstance3D` | 66 |
| `Districts/CivicCenter/CivicCenter_0188/MeshInstance3D` | 66 |
| `Districts/CivicCenter/CivicCenter_0189/MeshInstance3D` | 22 |
| `Districts/CivicCenter/CivicCenter_0190/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0191/MeshInstance3D` | 22 |
| `Districts/CivicCenter/CivicCenter_0192/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0193/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0194/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0195/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0196/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0197/MeshInstance3D` | 40 |
| `Districts/CivicCenter/CivicCenter_0198/MeshInstance3D` | 54 |
| `Districts/CivicCenter/CivicCenter_0199/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0200/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0201/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0202/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0203/MeshInstance3D` | 40 |
| `Districts/CivicCenter/CivicCenter_0204/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0205/MeshInstance3D` | 40 |
| `Districts/CivicCenter/CivicCenter_0382/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0383/MeshInstance3D` | 54 |
| `Districts/CivicCenter/CivicCenter_0384/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0385/MeshInstance3D` | 66 |
| `Districts/CivicCenter/CivicCenter_0386/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0387/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0388/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0389/MeshInstance3D` | 40 |
| `Districts/CivicCenter/CivicCenter_0390/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0391/MeshInstance3D` | 40 |
| `Districts/CivicCenter/CivicCenter_0392/MeshInstance3D` | 54 |
| `Districts/CivicCenter/CivicCenter_0393/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0394/MeshInstance3D` | 22 |
| `Districts/CivicCenter/CivicCenter_0395/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0396/MeshInstance3D` | 22 |
| `Districts/CivicCenter/CivicCenter_0397/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0398/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0399/MeshInstance3D` | 54 |
| `Districts/CivicCenter/CivicCenter_0400/MeshInstance3D` | 38 |
| `Districts/CivicCenter/CivicCenter_0401/MeshInstance3D` | 54 |
| `Districts/CivicCenter/CivicCenter_0402/MeshInstance3D` | 46 |
| `Districts/CivicCenter/CivicCenter_0403/MeshInstance3D` | 38 |
| `Districts/CivicCenter/CivicCenter_0404/MeshInstance3D` | 38 |
| `Districts/CivicCenter/CivicCenter_0405/MeshInstance3D` | 66 |
| `Districts/CivicCenter/CivicCenter_0406/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0407/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0408/MeshInstance3D` | 22 |
| `Districts/CivicCenter/CivicCenter_0409/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0410/MeshInstance3D` | 40 |
| `Districts/CivicCenter/CivicCenter_0587/MeshInstance3D` | 40 |
| `Districts/CivicCenter/CivicCenter_0588/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0589/MeshInstance3D` | 40 |
| `Districts/CivicCenter/CivicCenter_0590/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0591/MeshInstance3D` | 54 |
| `Districts/CivicCenter/CivicCenter_0592/MeshInstance3D` | 46 |
| `Districts/CivicCenter/CivicCenter_0593/MeshInstance3D` | 32 |
| `Districts/CivicCenter/CivicCenter_0594/MeshInstance3D` | 22 |
| `Districts/CivicCenter/CivicCenter_0595/MeshInstance3D` | 40 |
| `Districts/CivicCenter/CivicCenter_0596/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0597/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0598/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0599/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0600/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0601/MeshInstance3D` | 40 |
| `Districts/CivicCenter/CivicCenter_0602/MeshInstance3D` | 38 |
| `Districts/CivicCenter/CivicCenter_0603/MeshInstance3D` | 66 |
| `Districts/CivicCenter/CivicCenter_0604/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0605/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0606/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0607/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0608/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0609/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0610/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0611/MeshInstance3D` | 40 |
| `Districts/CivicCenter/CivicCenter_0612/MeshInstance3D` | 40 |
| `Districts/CivicCenter/CivicCenter_0613/MeshInstance3D` | 40 |
| `Districts/CivicCenter/CivicCenter_0614/MeshInstance3D` | 40 |
| `Districts/CivicCenter/CivicCenter_0615/MeshInstance3D` | 54 |
| `Districts/CivicCenter/CivicCenter_0616/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0663/MeshInstance3D` | 54 |
| `Districts/CivicCenter/CivicCenter_0664/MeshInstance3D` | 32 |
| `Districts/CivicCenter/CivicCenter_0665/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0666/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0667/MeshInstance3D` | 22 |
| `Districts/CivicCenter/CivicCenter_0668/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0669/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0670/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0671/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0672/MeshInstance3D` | 54 |
| `Districts/CivicCenter/CivicCenter_0673/MeshInstance3D` | 46 |
| `Districts/CivicCenter/CivicCenter_0674/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0675/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0676/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0677/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0678/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0679/MeshInstance3D` | 40 |
| `Districts/CivicCenter/CivicCenter_0680/MeshInstance3D` | 54 |
| `Districts/CivicCenter/CivicCenter_0681/MeshInstance3D` | 38 |
| `Districts/CivicCenter/CivicCenter_0682/MeshInstance3D` | 46 |
| `Districts/CivicCenter/CivicCenter_0683/MeshInstance3D` | 46 |
| `Districts/CivicCenter/CivicCenter_0684/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0685/MeshInstance3D` | 46 |
| `Districts/CivicCenter/CivicCenter_0686/MeshInstance3D` | 66 |
| `Districts/CivicCenter/CivicCenter_0687/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0688/MeshInstance3D` | 22 |
| `Districts/CivicCenter/CivicCenter_0689/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0690/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0691/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0692/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0693/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0694/MeshInstance3D` | 38 |
| `Districts/CivicCenter/CivicCenter_0695/MeshInstance3D` | 46 |
| `Districts/CivicCenter/CivicCenter_0696/MeshInstance3D` | 66 |
| `Districts/CivicCenter/CivicCenter_0697/MeshInstance3D` | 38 |
| `Districts/CivicCenter/CivicCenter_0698/MeshInstance3D` | 66 |
| `Districts/CivicCenter/CivicCenter_0699/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0700/MeshInstance3D` | 22 |
| `Districts/CivicCenter/CivicCenter_0701/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0702/MeshInstance3D` | 40 |
| `Districts/CivicCenter/CivicCenter_0703/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0704/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0705/MeshInstance3D` | 40 |
| `Districts/CivicCenter/CivicCenter_0706/MeshInstance3D` | 54 |
| `Districts/CivicCenter/CivicCenter_0707/MeshInstance3D` | 54 |
| `Districts/CivicCenter/CivicCenter_0708/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0709/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0710/MeshInstance3D` | 22 |
| `Districts/CivicCenter/CivicCenter_0711/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0712/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0713/MeshInstance3D` | 54 |
| `Districts/CivicCenter/CivicCenter_0714/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0715/MeshInstance3D` | 54 |
| `Districts/CivicCenter/CivicCenter_0716/MeshInstance3D` | 54 |
| `Districts/CivicCenter/CivicCenter_0717/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0718/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0719/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0720/MeshInstance3D` | 22 |
| `Districts/CivicCenter/CivicCenter_0721/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0722/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0723/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0724/MeshInstance3D` | 40 |
| `Districts/CivicCenter/CivicCenter_0725/MeshInstance3D` | 46 |
| `Districts/CivicCenter/CivicCenter_0726/MeshInstance3D` | 40 |
| `Districts/CivicCenter/CivicCenter_0727/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0728/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0729/MeshInstance3D` | 40 |
| `Districts/CivicCenter/CivicCenter_0730/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0731/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0732/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0733/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0734/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0735/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0736/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0737/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0738/MeshInstance3D` | 38 |
| `Districts/CivicCenter/CivicCenter_0739/MeshInstance3D` | 38 |
| `Districts/CivicCenter/CivicCenter_0740/MeshInstance3D` | 38 |
| `Districts/CivicCenter/CivicCenter_0741/MeshInstance3D` | 66 |
| `Districts/CivicCenter/CivicCenter_0742/MeshInstance3D` | 22 |
| `Districts/CivicCenter/CivicCenter_0743/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0744/MeshInstance3D` | 22 |
| `Districts/CivicCenter/CivicCenter_0745/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0746/MeshInstance3D` | 38 |
| `Districts/CivicCenter/CivicCenter_0847/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0848/MeshInstance3D` | 40 |
| `Districts/CivicCenter/CivicCenter_0849/MeshInstance3D` | 40 |
| `Districts/CivicCenter/CivicCenter_0850/MeshInstance3D` | 40 |
| `Districts/CivicCenter/CivicCenter_0851/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0852/MeshInstance3D` | 46 |
| `Districts/CivicCenter/CivicCenter_0853/MeshInstance3D` | 22 |
| `Districts/CivicCenter/CivicCenter_0854/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0855/MeshInstance3D` | 22 |
| `Districts/CivicCenter/CivicCenter_0856/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0857/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0858/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0861/MeshInstance3D` | 38 |
| `Districts/CivicCenter/CivicCenter_0862/MeshInstance3D` | 46 |
| `Districts/CivicCenter/CivicCenter_0863/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0864/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0866/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0867/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0868/MeshInstance3D` | 40 |
| `Districts/CivicCenter/CivicCenter_0869/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0870/MeshInstance3D` | 54 |
| `Districts/CivicCenter/CivicCenter_0871/MeshInstance3D` | 40 |
| `Districts/CivicCenter/CivicCenter_0872/MeshInstance3D` | 54 |
| `Districts/CivicCenter/CivicCenter_0873/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0874/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0875/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0933/MeshInstance3D` | 22 |
| `Districts/CivicCenter/CivicCenter_0934/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0935/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0936/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0937/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0938/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0939/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0940/MeshInstance3D` | 38 |
| `Districts/CivicCenter/CivicCenter_0941/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0942/MeshInstance3D` | 22 |
| `Districts/CivicCenter/CivicCenter_0943/MeshInstance3D` | 22 |
| `Districts/CivicCenter/CivicCenter_0944/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0945/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0946/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0947/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0948/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0949/MeshInstance3D` | 54 |
| `Districts/CivicCenter/CivicCenter_0950/MeshInstance3D` | 40 |
| `Districts/CivicCenter/CivicCenter_0951/MeshInstance3D` | 54 |
| `Districts/CivicCenter/CivicCenter_0952/MeshInstance3D` | 22 |
| `Districts/CivicCenter/CivicCenter_0953/MeshInstance3D` | 66 |
| `Districts/CivicCenter/CivicCenter_0954/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0955/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0956/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0957/MeshInstance3D` | 22 |
| `Districts/CivicCenter/CivicCenter_0958/MeshInstance3D` | 40 |
| `Districts/CivicCenter/CivicCenter_0959/MeshInstance3D` | 42 |
| `Districts/CivicCenter/CivicCenter_0960/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0961/MeshInstance3D` | 30 |
| `Districts/CivicCenter/CivicCenter_0962/MeshInstance3D` | 54 |
| `Districts/CivicCenter/CivicCenter_0963/MeshInstance3D` | 38 |
| `Districts/CivicCenter/CivicCenter_0964/MeshInstance3D` | 38 |
| `Districts/CivicCenter/CivicCenter_2060/MeshInstance3D` | 38 |

## NorthHeights

Occluder: `CityOcclusion/NorthHeights`

| Source mesh | Triangles |
| --- | ---: |
| `Districts/NorthHeights/NorthHeights_0617/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_0618/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_0619/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0620/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0621/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_0622/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0623/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0624/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_0625/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_0626/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_0627/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_0628/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0629/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0630/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0631/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0632/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0633/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_0634/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_0635/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0636/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_0637/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0638/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0639/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_0640/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_0641/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_0642/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_0643/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0644/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_0645/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0646/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_0647/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_0648/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0649/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0650/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_0651/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_0652/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0653/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_0654/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0655/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_0656/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0657/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_0658/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_0659/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_0660/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0661/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0662/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_0747/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0748/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0749/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0750/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0751/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_0752/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_0753/MeshInstance3D` | 56 |
| `Districts/NorthHeights/NorthHeights_0754/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0755/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0756/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0757/MeshInstance3D` | 86 |
| `Districts/NorthHeights/NorthHeights_0758/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_0759/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0760/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0761/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0762/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0763/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_0764/MeshInstance3D` | 86 |
| `Districts/NorthHeights/NorthHeights_0765/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0766/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0767/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0768/MeshInstance3D` | 66 |
| `Districts/NorthHeights/NorthHeights_0769/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_0770/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0771/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0772/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_0773/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_0774/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_0775/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0776/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0777/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0778/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_0779/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0780/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0781/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_0782/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0783/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0784/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0785/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0786/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_0876/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0877/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_0878/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_0879/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0880/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_0881/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0882/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_0883/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0884/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_0885/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_0886/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_0887/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0888/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0889/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_0890/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_0891/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_0892/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0893/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0894/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0895/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0896/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0897/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_0898/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_0899/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_0900/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_0901/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0902/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0903/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_0904/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_0905/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_0906/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_0907/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0908/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0909/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_0910/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0911/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0912/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0913/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_0914/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0915/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_0916/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0917/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_0918/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_0919/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_0920/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0965/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_0966/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0967/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0968/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0969/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_0970/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0971/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0972/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_0973/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0974/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0975/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0976/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0977/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_0978/MeshInstance3D` | 56 |
| `Districts/NorthHeights/NorthHeights_0979/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_0980/MeshInstance3D` | 56 |
| `Districts/NorthHeights/NorthHeights_0981/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_0982/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0983/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0984/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_0985/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_0986/MeshInstance3D` | 86 |
| `Districts/NorthHeights/NorthHeights_0987/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_0988/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0989/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0990/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_0991/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_0992/MeshInstance3D` | 86 |
| `Districts/NorthHeights/NorthHeights_0993/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0994/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_0995/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_0996/MeshInstance3D` | 86 |
| `Districts/NorthHeights/NorthHeights_0997/MeshInstance3D` | 66 |
| `Districts/NorthHeights/NorthHeights_0998/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_0999/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1000/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1001/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1002/MeshInstance3D` | 86 |
| `Districts/NorthHeights/NorthHeights_1003/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1004/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1005/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1006/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1007/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1008/MeshInstance3D` | 86 |
| `Districts/NorthHeights/NorthHeights_1052/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1053/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1054/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1055/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1056/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_1057/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1058/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1059/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1060/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1061/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1062/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1063/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1064/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1065/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_1066/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1067/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1068/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1069/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1070/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1071/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1072/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1073/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1074/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1075/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1076/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1077/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1078/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1079/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1080/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1081/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1082/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1083/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_1084/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1085/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1086/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1087/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1088/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1089/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1090/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1091/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_1092/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1093/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_1094/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1095/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1096/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1097/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1137/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1139/MeshInstance3D` | 66 |
| `Districts/NorthHeights/NorthHeights_1140/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_1142/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1143/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1148/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1149/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1152/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1153/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1156/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1157/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1160/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1161/MeshInstance3D` | 86 |
| `Districts/NorthHeights/NorthHeights_1163/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1164/MeshInstance3D` | 66 |
| `Districts/NorthHeights/NorthHeights_1165/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_1166/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1167/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1244/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1245/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1246/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1247/MeshInstance3D` | 56 |
| `Districts/NorthHeights/NorthHeights_1248/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_1249/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1278/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1279/MeshInstance3D` | 86 |
| `Districts/NorthHeights/NorthHeights_1280/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1281/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1282/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1283/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1284/MeshInstance3D` | 66 |
| `Districts/NorthHeights/NorthHeights_1285/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_1286/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1287/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1288/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1289/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1290/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1291/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_1292/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1293/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1294/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1295/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1296/MeshInstance3D` | 86 |
| `Districts/NorthHeights/NorthHeights_1297/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1298/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1299/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1300/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1301/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1302/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1303/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1304/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1305/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1306/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1307/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1308/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_1309/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1310/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1311/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1312/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1313/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1314/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1315/MeshInstance3D` | 86 |
| `Districts/NorthHeights/NorthHeights_1316/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_1317/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1318/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1319/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1320/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1321/MeshInstance3D` | 66 |
| `Districts/NorthHeights/NorthHeights_1322/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_1402/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1403/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1404/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1405/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1406/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1407/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1408/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1409/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1410/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1411/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1412/MeshInstance3D` | 56 |
| `Districts/NorthHeights/NorthHeights_1413/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_1414/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1415/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1416/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1417/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1418/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_1419/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1420/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1421/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1422/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1423/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1424/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1425/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1426/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1427/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1428/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1429/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1430/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1431/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1432/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1433/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1434/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1435/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1436/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1437/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1438/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1439/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1440/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1441/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1442/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1443/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_1444/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1445/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1537/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1538/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1539/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1540/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1541/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1542/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1543/MeshInstance3D` | 86 |
| `Districts/NorthHeights/NorthHeights_1544/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_1545/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1546/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1547/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1548/MeshInstance3D` | 66 |
| `Districts/NorthHeights/NorthHeights_1549/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_1550/MeshInstance3D` | 66 |
| `Districts/NorthHeights/NorthHeights_1551/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_1552/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1553/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1554/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1555/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1556/MeshInstance3D` | 86 |
| `Districts/NorthHeights/NorthHeights_1557/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1558/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1559/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1560/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1561/MeshInstance3D` | 66 |
| `Districts/NorthHeights/NorthHeights_1562/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1563/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1564/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1565/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1566/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1567/MeshInstance3D` | 86 |
| `Districts/NorthHeights/NorthHeights_1568/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1569/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1570/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1571/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1572/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1573/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1574/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1575/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1576/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1577/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1578/MeshInstance3D` | 66 |
| `Districts/NorthHeights/NorthHeights_1579/MeshInstance3D` | 56 |
| `Districts/NorthHeights/NorthHeights_1580/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1680/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1681/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1682/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1683/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1684/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1685/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1686/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1687/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1688/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1689/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1690/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1691/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1692/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1693/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_1694/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1695/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1696/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1697/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1698/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_1699/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1700/MeshInstance3D` | 56 |
| `Districts/NorthHeights/NorthHeights_1701/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_1702/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1703/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1704/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1705/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_1706/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1707/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1708/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1709/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1710/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1711/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1712/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1713/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1714/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1715/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1716/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1717/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1718/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1719/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1720/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1721/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1722/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1723/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1724/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1818/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1819/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1820/MeshInstance3D` | 86 |
| `Districts/NorthHeights/NorthHeights_1821/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_1822/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1823/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1824/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1825/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1826/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1827/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1828/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1829/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1830/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1831/MeshInstance3D` | 66 |
| `Districts/NorthHeights/NorthHeights_1832/MeshInstance3D` | 56 |
| `Districts/NorthHeights/NorthHeights_1833/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1834/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1835/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1836/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1837/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1838/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1839/MeshInstance3D` | 66 |
| `Districts/NorthHeights/NorthHeights_1840/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_1842/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1843/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1844/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1845/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1846/MeshInstance3D` | 86 |
| `Districts/NorthHeights/NorthHeights_1847/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1848/MeshInstance3D` | 86 |
| `Districts/NorthHeights/NorthHeights_1849/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1850/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1851/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1852/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1853/MeshInstance3D` | 56 |
| `Districts/NorthHeights/NorthHeights_1854/MeshInstance3D` | 86 |
| `Districts/NorthHeights/NorthHeights_1855/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1856/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1857/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1858/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1859/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1860/MeshInstance3D` | 86 |
| `Districts/NorthHeights/NorthHeights_1861/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1862/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1940/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1941/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1942/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1943/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1944/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1945/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1946/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1947/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1948/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1949/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1950/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1951/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1952/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1953/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1954/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1955/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1956/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1957/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1958/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1959/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1960/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_1961/MeshInstance3D` | 56 |
| `Districts/NorthHeights/NorthHeights_1962/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_1963/MeshInstance3D` | 42 |
| `Districts/NorthHeights/NorthHeights_1964/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1965/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1966/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1967/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1968/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1969/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1970/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1971/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1972/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1973/MeshInstance3D` | 78 |
| `Districts/NorthHeights/NorthHeights_1974/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1975/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1976/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1977/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1978/MeshInstance3D` | 30 |
| `Districts/NorthHeights/NorthHeights_1979/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1980/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1981/MeshInstance3D` | 54 |
| `Districts/NorthHeights/NorthHeights_1982/MeshInstance3D` | 40 |
| `Districts/NorthHeights/NorthHeights_1983/MeshInstance3D` | 52 |
| `Districts/NorthHeights/NorthHeights_1984/MeshInstance3D` | 54 |

## Parkside

Occluder: `CityOcclusion/Parkside`

| Source mesh | Triangles |
| --- | ---: |
| `Districts/Parkside/Parkside_0787/MeshInstance3D` | 30 |
| `Districts/Parkside/Parkside_0788/MeshInstance3D` | 30 |
| `Districts/Parkside/Parkside_0789/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_0790/MeshInstance3D` | 40 |
| `Districts/Parkside/Parkside_0791/MeshInstance3D` | 54 |
| `Districts/Parkside/Parkside_0792/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_0793/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_0794/MeshInstance3D` | 54 |
| `Districts/Parkside/Parkside_0795/MeshInstance3D` | 54 |
| `Districts/Parkside/Parkside_0796/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_0797/MeshInstance3D` | 30 |
| `Districts/Parkside/Parkside_0798/MeshInstance3D` | 30 |
| `Districts/Parkside/Parkside_0799/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_0800/MeshInstance3D` | 30 |
| `Districts/Parkside/Parkside_0801/MeshInstance3D` | 66 |
| `Districts/Parkside/Parkside_0802/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_0803/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_0804/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_0805/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_0806/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_0807/MeshInstance3D` | 66 |
| `Districts/Parkside/Parkside_0808/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_0809/MeshInstance3D` | 66 |
| `Districts/Parkside/Parkside_0810/MeshInstance3D` | 66 |
| `Districts/Parkside/Parkside_0811/MeshInstance3D` | 54 |
| `Districts/Parkside/Parkside_0812/MeshInstance3D` | 30 |
| `Districts/Parkside/Parkside_0813/MeshInstance3D` | 54 |
| `Districts/Parkside/Parkside_0814/MeshInstance3D` | 30 |
| `Districts/Parkside/Parkside_0815/MeshInstance3D` | 30 |
| `Districts/Parkside/Parkside_0816/MeshInstance3D` | 22 |
| `Districts/Parkside/Parkside_0817/MeshInstance3D` | 66 |
| `Districts/Parkside/Parkside_0818/MeshInstance3D` | 54 |
| `Districts/Parkside/Parkside_0819/MeshInstance3D` | 40 |
| `Districts/Parkside/Parkside_0820/MeshInstance3D` | 54 |
| `Districts/Parkside/Parkside_0821/MeshInstance3D` | 54 |
| `Districts/Parkside/Parkside_0822/MeshInstance3D` | 54 |
| `Districts/Parkside/Parkside_0823/MeshInstance3D` | 66 |
| `Districts/Parkside/Parkside_0824/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_0825/MeshInstance3D` | 54 |
| `Districts/Parkside/Parkside_0826/MeshInstance3D` | 30 |
| `Districts/Parkside/Parkside_0827/MeshInstance3D` | 30 |
| `Districts/Parkside/Parkside_0828/MeshInstance3D` | 66 |
| `Districts/Parkside/Parkside_0829/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_0830/MeshInstance3D` | 66 |
| `Districts/Parkside/Parkside_0831/MeshInstance3D` | 54 |
| `Districts/Parkside/Parkside_0832/MeshInstance3D` | 66 |
| `Districts/Parkside/Parkside_0833/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_0834/MeshInstance3D` | 30 |
| `Districts/Parkside/Parkside_0835/MeshInstance3D` | 66 |
| `Districts/Parkside/Parkside_0836/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_0837/MeshInstance3D` | 54 |
| `Districts/Parkside/Parkside_0838/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_0839/MeshInstance3D` | 66 |
| `Districts/Parkside/Parkside_0840/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_0841/MeshInstance3D` | 30 |
| `Districts/Parkside/Parkside_0842/MeshInstance3D` | 40 |
| `Districts/Parkside/Parkside_0843/MeshInstance3D` | 40 |
| `Districts/Parkside/Parkside_0844/MeshInstance3D` | 66 |
| `Districts/Parkside/Parkside_0845/MeshInstance3D` | 54 |
| `Districts/Parkside/Parkside_0846/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_0921/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_0922/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_0923/MeshInstance3D` | 66 |
| `Districts/Parkside/Parkside_0925/MeshInstance3D` | 54 |
| `Districts/Parkside/Parkside_0926/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_0928/MeshInstance3D` | 54 |
| `Districts/Parkside/Parkside_0931/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_0932/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_1099/MeshInstance3D` | 30 |
| `Districts/Parkside/Parkside_1100/MeshInstance3D` | 66 |
| `Districts/Parkside/Parkside_1102/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_1103/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_1106/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_1107/MeshInstance3D` | 66 |
| `Districts/Parkside/Parkside_1108/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_1109/MeshInstance3D` | 54 |
| `Districts/Parkside/Parkside_1110/MeshInstance3D` | 66 |
| `Districts/Parkside/Parkside_1170/MeshInstance3D` | 66 |
| `Districts/Parkside/Parkside_1171/MeshInstance3D` | 66 |
| `Districts/Parkside/Parkside_1172/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_1173/MeshInstance3D` | 30 |
| `Districts/Parkside/Parkside_1178/MeshInstance3D` | 54 |
| `Districts/Parkside/Parkside_1179/MeshInstance3D` | 30 |
| `Districts/Parkside/Parkside_1180/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_1182/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_1183/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_1184/MeshInstance3D` | 66 |
| `Districts/Parkside/Parkside_1186/MeshInstance3D` | 30 |
| `Districts/Parkside/Parkside_1187/MeshInstance3D` | 40 |
| `Districts/Parkside/Parkside_1188/MeshInstance3D` | 40 |
| `Districts/Parkside/Parkside_1189/MeshInstance3D` | 66 |
| `Districts/Parkside/Parkside_1190/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_1191/MeshInstance3D` | 30 |
| `Districts/Parkside/Parkside_1193/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_1194/MeshInstance3D` | 54 |
| `Districts/Parkside/Parkside_1195/MeshInstance3D` | 30 |
| `Districts/Parkside/Parkside_1196/MeshInstance3D` | 30 |
| `Districts/Parkside/Parkside_1197/MeshInstance3D` | 54 |
| `Districts/Parkside/Parkside_1199/MeshInstance3D` | 66 |
| `Districts/Parkside/Parkside_1200/MeshInstance3D` | 30 |
| `Districts/Parkside/Parkside_1201/MeshInstance3D` | 66 |
| `Districts/Parkside/Parkside_1203/MeshInstance3D` | 66 |
| `Districts/Parkside/Parkside_1204/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_1205/MeshInstance3D` | 54 |
| `Districts/Parkside/Parkside_1206/MeshInstance3D` | 54 |
| `Districts/Parkside/Parkside_1207/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_1208/MeshInstance3D` | 66 |
| `Districts/Parkside/Parkside_1209/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_1210/MeshInstance3D` | 30 |
| `Districts/Parkside/Parkside_1211/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_1212/MeshInstance3D` | 30 |
| `Districts/Parkside/Parkside_1213/MeshInstance3D` | 40 |
| `Districts/Parkside/Parkside_1214/MeshInstance3D` | 40 |
| `Districts/Parkside/Parkside_1265/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_1266/MeshInstance3D` | 30 |
| `Districts/Parkside/Parkside_1267/MeshInstance3D` | 22 |
| `Districts/Parkside/Parkside_1268/MeshInstance3D` | 42 |
| `Districts/Parkside/Parkside_1269/MeshInstance3D` | 54 |

## FinancialQuarter

Occluder: `CityOcclusion/FinancialQuarter`

| Source mesh | Triangles |
| --- | ---: |
| `Districts/FinancialQuarter/FinancialQuarter_1024/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1025/MeshInstance3D` | 40 |
| `Districts/FinancialQuarter/FinancialQuarter_1026/MeshInstance3D` | 40 |
| `Districts/FinancialQuarter/FinancialQuarter_1027/MeshInstance3D` | 40 |
| `Districts/FinancialQuarter/FinancialQuarter_1035/MeshInstance3D` | 32 |
| `Districts/FinancialQuarter/FinancialQuarter_1036/MeshInstance3D` | 32 |
| `Districts/FinancialQuarter/FinancialQuarter_1037/MeshInstance3D` | 46 |
| `Districts/FinancialQuarter/FinancialQuarter_1038/MeshInstance3D` | 40 |
| `Districts/FinancialQuarter/FinancialQuarter_1039/MeshInstance3D` | 38 |
| `Districts/FinancialQuarter/FinancialQuarter_1040/MeshInstance3D` | 40 |
| `Districts/FinancialQuarter/FinancialQuarter_1041/MeshInstance3D` | 40 |
| `Districts/FinancialQuarter/FinancialQuarter_1042/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1043/MeshInstance3D` | 40 |
| `Districts/FinancialQuarter/FinancialQuarter_1044/MeshInstance3D` | 40 |
| `Districts/FinancialQuarter/FinancialQuarter_1045/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1046/MeshInstance3D` | 40 |
| `Districts/FinancialQuarter/FinancialQuarter_1047/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1048/MeshInstance3D` | 38 |
| `Districts/FinancialQuarter/FinancialQuarter_1049/MeshInstance3D` | 38 |
| `Districts/FinancialQuarter/FinancialQuarter_1050/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1051/MeshInstance3D` | 38 |
| `Districts/FinancialQuarter/FinancialQuarter_1111/MeshInstance3D` | 46 |
| `Districts/FinancialQuarter/FinancialQuarter_1112/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1113/MeshInstance3D` | 46 |
| `Districts/FinancialQuarter/FinancialQuarter_1114/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1115/MeshInstance3D` | 46 |
| `Districts/FinancialQuarter/FinancialQuarter_1116/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1117/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1118/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1119/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1120/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1123/MeshInstance3D` | 46 |
| `Districts/FinancialQuarter/FinancialQuarter_1124/MeshInstance3D` | 36 |
| `Districts/FinancialQuarter/FinancialQuarter_1125/MeshInstance3D` | 36 |
| `Districts/FinancialQuarter/FinancialQuarter_1127/MeshInstance3D` | 36 |
| `Districts/FinancialQuarter/FinancialQuarter_1128/MeshInstance3D` | 46 |
| `Districts/FinancialQuarter/FinancialQuarter_1130/MeshInstance3D` | 46 |
| `Districts/FinancialQuarter/FinancialQuarter_1131/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1132/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1133/MeshInstance3D` | 46 |
| `Districts/FinancialQuarter/FinancialQuarter_1134/MeshInstance3D` | 46 |
| `Districts/FinancialQuarter/FinancialQuarter_1135/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1136/MeshInstance3D` | 46 |
| `Districts/FinancialQuarter/FinancialQuarter_1215/MeshInstance3D` | 46 |
| `Districts/FinancialQuarter/FinancialQuarter_1216/MeshInstance3D` | 46 |
| `Districts/FinancialQuarter/FinancialQuarter_1217/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1218/MeshInstance3D` | 46 |
| `Districts/FinancialQuarter/FinancialQuarter_1219/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1220/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1221/MeshInstance3D` | 46 |
| `Districts/FinancialQuarter/FinancialQuarter_1222/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1223/MeshInstance3D` | 46 |
| `Districts/FinancialQuarter/FinancialQuarter_1224/MeshInstance3D` | 46 |
| `Districts/FinancialQuarter/FinancialQuarter_1225/MeshInstance3D` | 46 |
| `Districts/FinancialQuarter/FinancialQuarter_1226/MeshInstance3D` | 46 |
| `Districts/FinancialQuarter/FinancialQuarter_1228/MeshInstance3D` | 38 |
| `Districts/FinancialQuarter/FinancialQuarter_1231/MeshInstance3D` | 36 |
| `Districts/FinancialQuarter/FinancialQuarter_1234/MeshInstance3D` | 46 |
| `Districts/FinancialQuarter/FinancialQuarter_1236/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1237/MeshInstance3D` | 46 |
| `Districts/FinancialQuarter/FinancialQuarter_1238/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1239/MeshInstance3D` | 36 |
| `Districts/FinancialQuarter/FinancialQuarter_1270/MeshInstance3D` | 32 |
| `Districts/FinancialQuarter/FinancialQuarter_1271/MeshInstance3D` | 32 |
| `Districts/FinancialQuarter/FinancialQuarter_1272/MeshInstance3D` | 38 |
| `Districts/FinancialQuarter/FinancialQuarter_1273/MeshInstance3D` | 40 |
| `Districts/FinancialQuarter/FinancialQuarter_1274/MeshInstance3D` | 40 |
| `Districts/FinancialQuarter/FinancialQuarter_1275/MeshInstance3D` | 46 |
| `Districts/FinancialQuarter/FinancialQuarter_1276/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1277/MeshInstance3D` | 46 |
| `Districts/FinancialQuarter/FinancialQuarter_1384/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1385/MeshInstance3D` | 40 |
| `Districts/FinancialQuarter/FinancialQuarter_1386/MeshInstance3D` | 40 |
| `Districts/FinancialQuarter/FinancialQuarter_1387/MeshInstance3D` | 40 |
| `Districts/FinancialQuarter/FinancialQuarter_1388/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1389/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1391/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1392/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1397/MeshInstance3D` | 40 |
| `Districts/FinancialQuarter/FinancialQuarter_1401/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1511/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1512/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1513/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1514/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1515/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1516/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1517/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1518/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1519/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1520/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1521/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1522/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1523/MeshInstance3D` | 22 |
| `Districts/FinancialQuarter/FinancialQuarter_1524/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1525/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1526/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1527/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1528/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1529/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1530/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1531/MeshInstance3D` | 22 |
| `Districts/FinancialQuarter/FinancialQuarter_1532/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1533/MeshInstance3D` | 30 |
| `Districts/FinancialQuarter/FinancialQuarter_1534/MeshInstance3D` | 22 |
| `Districts/FinancialQuarter/FinancialQuarter_1535/MeshInstance3D` | 22 |
| `Districts/FinancialQuarter/FinancialQuarter_1536/MeshInstance3D` | 30 |

## Eastbank

Occluder: `CityOcclusion/Eastbank`

| Source mesh | Triangles |
| --- | ---: |
| `Districts/Eastbank/Eastbank_1250/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1251/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1252/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1253/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1257/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1258/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1259/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1260/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1262/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1263/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1264/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1323/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1324/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1325/MeshInstance3D` | 78 |
| `Districts/Eastbank/Eastbank_1326/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1327/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1328/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1329/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1330/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1331/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1332/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1333/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1334/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1335/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1336/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1337/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1338/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1339/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1340/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1341/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1342/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1343/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1344/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1345/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1346/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1347/MeshInstance3D` | 52 |
| `Districts/Eastbank/Eastbank_1348/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1349/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1350/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1351/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1352/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1353/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1354/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1355/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1356/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1357/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1358/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1359/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1360/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1361/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1364/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1365/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1368/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1369/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1372/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1373/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1376/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1377/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1378/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1379/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1380/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1381/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1382/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1383/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1446/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1447/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1448/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1449/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1450/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1451/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1452/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1453/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1454/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1455/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1456/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1457/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1458/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1459/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1460/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1461/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1462/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1463/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1464/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1465/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1466/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1467/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1468/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1469/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1470/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1471/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1472/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1473/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1474/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1475/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1476/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1477/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1478/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1479/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1480/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1481/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1482/MeshInstance3D` | 78 |
| `Districts/Eastbank/Eastbank_1483/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1484/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1485/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1486/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1487/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1488/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1489/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1490/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1491/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1492/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1493/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1494/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1495/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1496/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1497/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1498/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1499/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1500/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1501/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1502/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1503/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1504/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1505/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1506/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1507/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1508/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1509/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1510/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1581/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1582/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1583/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1584/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1585/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1586/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1587/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1588/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1589/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1590/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1591/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1592/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1593/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1594/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1595/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1596/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1597/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1598/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1599/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1600/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1601/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1602/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1603/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1604/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1605/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1606/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1607/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1608/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1609/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1610/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1611/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1612/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1613/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1614/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1615/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1616/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1617/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1618/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1619/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1620/MeshInstance3D` | 78 |
| `Districts/Eastbank/Eastbank_1621/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1622/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1623/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1624/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1625/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1626/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1627/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1628/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1629/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1630/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1631/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1632/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1633/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1634/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1635/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1636/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1637/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1638/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1639/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1640/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1641/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1642/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1643/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1644/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1645/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1646/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1647/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1648/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1649/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1650/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1651/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1652/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1653/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1654/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1655/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1656/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1657/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1658/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1659/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1660/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1661/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1662/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1663/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1664/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1665/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1666/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1667/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1668/MeshInstance3D` | 52 |
| `Districts/Eastbank/Eastbank_1669/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1670/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1671/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1672/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1673/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1674/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1675/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1676/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1677/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1678/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1679/MeshInstance3D` | 52 |
| `Districts/Eastbank/Eastbank_1725/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1726/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1727/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1728/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1729/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1730/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1731/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1732/MeshInstance3D` | 52 |
| `Districts/Eastbank/Eastbank_1733/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1734/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1735/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1736/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1737/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1738/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1739/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1740/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1741/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1742/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1743/MeshInstance3D` | 52 |
| `Districts/Eastbank/Eastbank_1744/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1745/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1746/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1747/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1748/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1749/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1750/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1751/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1752/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1753/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1754/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1755/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1756/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1757/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1758/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1760/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1761/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1762/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1763/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1764/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1765/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1766/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1767/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1768/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1769/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1770/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1771/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1772/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1773/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1774/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1775/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1776/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1777/MeshInstance3D` | 52 |
| `Districts/Eastbank/Eastbank_1778/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1779/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1780/MeshInstance3D` | 52 |
| `Districts/Eastbank/Eastbank_1781/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1782/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1783/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1784/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1785/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1786/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1787/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1788/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1789/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1790/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1791/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1792/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1793/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1794/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1795/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1796/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1797/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1798/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1799/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1800/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1801/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1802/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1803/MeshInstance3D` | 78 |
| `Districts/Eastbank/Eastbank_1863/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1864/MeshInstance3D` | 78 |
| `Districts/Eastbank/Eastbank_1865/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1866/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1867/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1868/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1869/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1870/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1871/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1872/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1873/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1874/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1875/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1876/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1877/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1878/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1879/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1880/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1881/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1882/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1883/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1884/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1885/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1886/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1887/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1888/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1889/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1985/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1986/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1987/MeshInstance3D` | 52 |
| `Districts/Eastbank/Eastbank_1988/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1989/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1990/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1991/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1992/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_1993/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_1994/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1995/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_1996/MeshInstance3D` | 66 |
| `Districts/Eastbank/Eastbank_1997/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1998/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_1999/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_2000/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_2001/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_2002/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_2003/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_2004/MeshInstance3D` | 40 |
| `Districts/Eastbank/Eastbank_2005/MeshInstance3D` | 54 |
| `Districts/Eastbank/Eastbank_2006/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_2007/MeshInstance3D` | 78 |
| `Districts/Eastbank/Eastbank_2008/MeshInstance3D` | 42 |
| `Districts/Eastbank/Eastbank_2009/MeshInstance3D` | 30 |
| `Districts/Eastbank/Eastbank_2010/MeshInstance3D` | 30 |

## Docklands

Occluder: `CityOcclusion/Docklands`

| Source mesh | Triangles |
| --- | ---: |
| `Districts/Docklands/Docklands_1804/MeshInstance3D` | 66 |
| `Districts/Docklands/Docklands_1805/MeshInstance3D` | 46 |
| `Districts/Docklands/Docklands_1806/MeshInstance3D` | 44 |
| `Districts/Docklands/Docklands_1807/MeshInstance3D` | 46 |
| `Districts/Docklands/Docklands_1808/MeshInstance3D` | 44 |
| `Districts/Docklands/Docklands_1809/MeshInstance3D` | 46 |
| `Districts/Docklands/Docklands_1810/MeshInstance3D` | 66 |
| `Districts/Docklands/Docklands_1811/MeshInstance3D` | 46 |
| `Districts/Docklands/Docklands_1812/MeshInstance3D` | 46 |
| `Districts/Docklands/Docklands_1813/MeshInstance3D` | 66 |
| `Districts/Docklands/Docklands_1814/MeshInstance3D` | 40 |
| `Districts/Docklands/Docklands_1815/MeshInstance3D` | 206 |
| `Districts/Docklands/Docklands_1816/MeshInstance3D` | 206 |
| `Districts/Docklands/Docklands_1817/MeshInstance3D` | 66 |
| `Districts/Docklands/Docklands_1924/MeshInstance3D` | 44 |
| `Districts/Docklands/Docklands_1925/MeshInstance3D` | 44 |
| `Districts/Docklands/Docklands_1926/MeshInstance3D` | 40 |
| `Districts/Docklands/Docklands_1927/MeshInstance3D` | 66 |
| `Districts/Docklands/Docklands_1928/MeshInstance3D` | 46 |
| `Districts/Docklands/Docklands_1929/MeshInstance3D` | 24 |
| `Districts/Docklands/Docklands_1930/MeshInstance3D` | 44 |
| `Districts/Docklands/Docklands_1931/MeshInstance3D` | 46 |
| `Districts/Docklands/Docklands_1932/MeshInstance3D` | 46 |
| `Districts/Docklands/Docklands_1933/MeshInstance3D` | 46 |
| `Districts/Docklands/Docklands_1934/MeshInstance3D` | 44 |
| `Districts/Docklands/Docklands_1935/MeshInstance3D` | 46 |
| `Districts/Docklands/Docklands_1936/MeshInstance3D` | 24 |
| `Districts/Docklands/Docklands_1937/MeshInstance3D` | 66 |
| `Districts/Docklands/Docklands_1938/MeshInstance3D` | 206 |
| `Districts/Docklands/Docklands_1939/MeshInstance3D` | 24 |
| `Districts/Docklands/Docklands_2044/MeshInstance3D` | 46 |
| `Districts/Docklands/Docklands_2045/MeshInstance3D` | 46 |
| `Districts/Docklands/Docklands_2046/MeshInstance3D` | 66 |
| `Districts/Docklands/Docklands_2047/MeshInstance3D` | 44 |
| `Districts/Docklands/Docklands_2048/MeshInstance3D` | 56 |
| `Districts/Docklands/Docklands_2049/MeshInstance3D` | 44 |
| `Districts/Docklands/Docklands_2050/MeshInstance3D` | 40 |
| `Districts/Docklands/Docklands_2051/MeshInstance3D` | 36 |
| `Districts/Docklands/Docklands_2052/MeshInstance3D` | 44 |
| `Districts/Docklands/Docklands_2053/MeshInstance3D` | 24 |
| `Districts/Docklands/Docklands_2054/MeshInstance3D` | 46 |
| `Districts/Docklands/Docklands_2055/MeshInstance3D` | 66 |
| `Districts/Docklands/Docklands_2056/MeshInstance3D` | 46 |
| `Districts/Docklands/Docklands_2057/MeshInstance3D` | 44 |
| `Districts/Docklands/Docklands_2058/MeshInstance3D` | 40 |
| `Districts/Docklands/Docklands_2059/MeshInstance3D` | 46 |

## FoundryWard

Occluder: `CityOcclusion/FoundryWard`

| Source mesh | Triangles |
| --- | ---: |
| `Districts/FoundryWard/FoundryWard_1890/MeshInstance3D` | 36 |
| `Districts/FoundryWard/FoundryWard_1891/MeshInstance3D` | 44 |
| `Districts/FoundryWard/FoundryWard_1892/MeshInstance3D` | 44 |
| `Districts/FoundryWard/FoundryWard_1893/MeshInstance3D` | 56 |
| `Districts/FoundryWard/FoundryWard_1894/MeshInstance3D` | 44 |
| `Districts/FoundryWard/FoundryWard_1895/MeshInstance3D` | 46 |
| `Districts/FoundryWard/FoundryWard_1896/MeshInstance3D` | 118 |
| `Districts/FoundryWard/FoundryWard_1897/MeshInstance3D` | 44 |
| `Districts/FoundryWard/FoundryWard_1898/MeshInstance3D` | 56 |
| `Districts/FoundryWard/FoundryWard_1899/MeshInstance3D` | 40 |
| `Districts/FoundryWard/FoundryWard_1900/MeshInstance3D` | 36 |
| `Districts/FoundryWard/FoundryWard_1901/MeshInstance3D` | 206 |
| `Districts/FoundryWard/FoundryWard_1902/MeshInstance3D` | 46 |
| `Districts/FoundryWard/FoundryWard_1903/MeshInstance3D` | 44 |
| `Districts/FoundryWard/FoundryWard_1904/MeshInstance3D` | 46 |
| `Districts/FoundryWard/FoundryWard_1905/MeshInstance3D` | 46 |
| `Districts/FoundryWard/FoundryWard_1906/MeshInstance3D` | 46 |
| `Districts/FoundryWard/FoundryWard_1907/MeshInstance3D` | 44 |
| `Districts/FoundryWard/FoundryWard_1908/MeshInstance3D` | 46 |
| `Districts/FoundryWard/FoundryWard_1909/MeshInstance3D` | 24 |
| `Districts/FoundryWard/FoundryWard_1910/MeshInstance3D` | 66 |
| `Districts/FoundryWard/FoundryWard_1911/MeshInstance3D` | 36 |
| `Districts/FoundryWard/FoundryWard_1913/MeshInstance3D` | 24 |
| `Districts/FoundryWard/FoundryWard_1914/MeshInstance3D` | 24 |
| `Districts/FoundryWard/FoundryWard_1915/MeshInstance3D` | 118 |
| `Districts/FoundryWard/FoundryWard_1916/MeshInstance3D` | 118 |
| `Districts/FoundryWard/FoundryWard_1917/MeshInstance3D` | 56 |
| `Districts/FoundryWard/FoundryWard_1918/MeshInstance3D` | 66 |
| `Districts/FoundryWard/FoundryWard_1919/MeshInstance3D` | 36 |
| `Districts/FoundryWard/FoundryWard_1920/MeshInstance3D` | 56 |
| `Districts/FoundryWard/FoundryWard_1921/MeshInstance3D` | 44 |
| `Districts/FoundryWard/FoundryWard_1922/MeshInstance3D` | 36 |
| `Districts/FoundryWard/FoundryWard_1923/MeshInstance3D` | 118 |
| `Districts/FoundryWard/FoundryWard_2011/MeshInstance3D` | 56 |
| `Districts/FoundryWard/FoundryWard_2012/MeshInstance3D` | 66 |
| `Districts/FoundryWard/FoundryWard_2013/MeshInstance3D` | 36 |
| `Districts/FoundryWard/FoundryWard_2014/MeshInstance3D` | 44 |
| `Districts/FoundryWard/FoundryWard_2015/MeshInstance3D` | 36 |
| `Districts/FoundryWard/FoundryWard_2016/MeshInstance3D` | 44 |
| `Districts/FoundryWard/FoundryWard_2017/MeshInstance3D` | 46 |
| `Districts/FoundryWard/FoundryWard_2018/MeshInstance3D` | 46 |
| `Districts/FoundryWard/FoundryWard_2019/MeshInstance3D` | 46 |
| `Districts/FoundryWard/FoundryWard_2020/MeshInstance3D` | 66 |
| `Districts/FoundryWard/FoundryWard_2021/MeshInstance3D` | 46 |
| `Districts/FoundryWard/FoundryWard_2022/MeshInstance3D` | 56 |
| `Districts/FoundryWard/FoundryWard_2023/MeshInstance3D` | 44 |
| `Districts/FoundryWard/FoundryWard_2024/MeshInstance3D` | 40 |
| `Districts/FoundryWard/FoundryWard_2025/MeshInstance3D` | 46 |
| `Districts/FoundryWard/FoundryWard_2026/MeshInstance3D` | 24 |
| `Districts/FoundryWard/FoundryWard_2027/MeshInstance3D` | 46 |
| `Districts/FoundryWard/FoundryWard_2028/MeshInstance3D` | 206 |
| `Districts/FoundryWard/FoundryWard_2029/MeshInstance3D` | 206 |
| `Districts/FoundryWard/FoundryWard_2030/MeshInstance3D` | 24 |
| `Districts/FoundryWard/FoundryWard_2031/MeshInstance3D` | 46 |
| `Districts/FoundryWard/FoundryWard_2032/MeshInstance3D` | 46 |
| `Districts/FoundryWard/FoundryWard_2033/MeshInstance3D` | 66 |
| `Districts/FoundryWard/FoundryWard_2034/MeshInstance3D` | 46 |
| `Districts/FoundryWard/FoundryWard_2035/MeshInstance3D` | 206 |
| `Districts/FoundryWard/FoundryWard_2036/MeshInstance3D` | 40 |
| `Districts/FoundryWard/FoundryWard_2037/MeshInstance3D` | 40 |
| `Districts/FoundryWard/FoundryWard_2038/MeshInstance3D` | 66 |
| `Districts/FoundryWard/FoundryWard_2039/MeshInstance3D` | 118 |
| `Districts/FoundryWard/FoundryWard_2040/MeshInstance3D` | 56 |
| `Districts/FoundryWard/FoundryWard_2041/MeshInstance3D` | 44 |
| `Districts/FoundryWard/FoundryWard_2042/MeshInstance3D` | 44 |
| `Districts/FoundryWard/FoundryWard_2043/MeshInstance3D` | 46 |

## CentralPark

Occluder: `CityOcclusion/CentralPark`

| Source mesh | Triangles |
| --- | ---: |
| `Landmarks/CentralPark/Terrain/Ground/MeshInstance3D` | 22994 |
| `Landmarks/CentralPark/Houses/WillowHermitage/Floor` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/BackWall` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/SideWall` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/SideWall2` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/FrontWall` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/FrontWall2` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/DoorLintel` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/GabledRoof` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/LitWindow` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/WindowMullion` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/WindowMullion2` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/Shutter` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/GabledRoof2` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/LitWindow2` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/WindowMullion3` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/WindowMullion4` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/Shutter2` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/Gable` | 1 |
| `Landmarks/CentralPark/Houses/WillowHermitage/Gable2` | 1 |
| `Landmarks/CentralPark/Houses/WillowHermitage/BrickChimney` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/Porch` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/EntryRamp` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/Bench/Seat` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/Bench/Back` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/Bench/Leg` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/Bench/Leg2` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/BedFrame` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/Blanket` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/Table` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/Books` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/Books2` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/Books3` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/Books4` | 12 |
| `Landmarks/CentralPark/Houses/WillowHermitage/Firewood` | 48 |
| `Landmarks/CentralPark/Houses/WillowHermitage/Firewood2` | 48 |
| `Landmarks/CentralPark/Houses/WillowHermitage/Firewood3` | 48 |
| `Landmarks/CentralPark/Houses/WillowHermitage/Firewood4` | 48 |
| `Landmarks/CentralPark/Houses/WillowHermitage/Firewood5` | 48 |
| `Landmarks/CentralPark/Houses/BirchHideaway/Floor` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/BackWall` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/SideWall` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/SideWall2` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/FrontWall` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/FrontWall2` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/DoorLintel` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/GabledRoof` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/LitWindow` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/WindowMullion` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/WindowMullion2` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/Shutter` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/GabledRoof2` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/LitWindow2` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/WindowMullion3` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/WindowMullion4` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/Shutter2` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/Gable` | 1 |
| `Landmarks/CentralPark/Houses/BirchHideaway/Gable2` | 1 |
| `Landmarks/CentralPark/Houses/BirchHideaway/BrickChimney` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/Porch` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/EntryRamp` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/Bench/Seat` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/Bench/Back` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/Bench/Leg` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/Bench/Leg2` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/BedFrame` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/Blanket` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/Table` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/Books` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/Books2` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/Books3` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/Books4` | 12 |
| `Landmarks/CentralPark/Houses/BirchHideaway/Firewood` | 48 |
| `Landmarks/CentralPark/Houses/BirchHideaway/Firewood2` | 48 |
| `Landmarks/CentralPark/Houses/BirchHideaway/Firewood3` | 48 |
| `Landmarks/CentralPark/Houses/BirchHideaway/Firewood4` | 48 |
| `Landmarks/CentralPark/Houses/BirchHideaway/Firewood5` | 48 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/Floor` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/BackWall` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/SideWall` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/SideWall2` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/FrontWall` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/FrontWall2` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/DoorLintel` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/GabledRoof` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/LitWindow` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/WindowMullion` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/WindowMullion2` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/Shutter` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/GabledRoof2` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/LitWindow2` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/WindowMullion3` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/WindowMullion4` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/Shutter2` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/Gable` | 1 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/Gable2` | 1 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/BrickChimney` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/Porch` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/EntryRamp` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/Bench/Seat` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/Bench/Back` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/Bench/Leg` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/Bench/Leg2` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/BedFrame` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/Blanket` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/Table` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/Books` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/Books2` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/Books3` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/Books4` | 12 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/Firewood` | 48 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/Firewood2` | 48 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/Firewood3` | 48 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/Firewood4` | 48 |
| `Landmarks/CentralPark/Houses/MosskeeperCottage/Firewood5` | 48 |
| `Landmarks/CentralPark/Landmarks/BowBridge/Pier` | 12 |
| `Landmarks/CentralPark/Landmarks/BowBridge/Pier2` | 12 |
| `Landmarks/CentralPark/Landmarks/BowBridge/Pier3` | 12 |
| `Landmarks/CentralPark/Landmarks/BowBridge/Pier4` | 12 |
| `Landmarks/CentralPark/Landmarks/BowBridge/Pier5` | 12 |
| `Landmarks/CentralPark/Landmarks/BowBridge/Pier6` | 12 |
| `Landmarks/CentralPark/Landmarks/BowBridge/Pier7` | 12 |
| `Landmarks/CentralPark/Landmarks/BowBridge/Pier8` | 12 |
| `Landmarks/CentralPark/Landmarks/BowBridge/Pier9` | 12 |
| `Landmarks/CentralPark/Landmarks/BowBridge/Pier10` | 12 |
| `Landmarks/CentralPark/Landmarks/BowBridge/Pier11` | 12 |
| `Landmarks/CentralPark/Landmarks/BowBridge/Pier12` | 12 |
| `Landmarks/CentralPark/Landmarks/BowBridge/Pier13` | 12 |
| `Landmarks/CentralPark/Landmarks/BowBridge/Pier14` | 12 |
| `Landmarks/CentralPark/Landmarks/BowBridge/Pier15` | 12 |
| `Landmarks/CentralPark/Landmarks/BowBridge/Pier16` | 12 |
| `Landmarks/CentralPark/Landmarks/BowBridge/Pier17` | 12 |
| `Landmarks/CentralPark/Landmarks/BowBridge/Pier18` | 12 |
| `Landmarks/CentralPark/Landmarks/BowBridge/Deck/MeshInstance3D` | 160 |
| `Landmarks/CentralPark/Landmarks/MoonwaterDock/Boardwalk` | 12 |
| `Landmarks/CentralPark/Landmarks/MoonwaterDock/ShoreRamp` | 12 |
| `Landmarks/CentralPark/Landmarks/MoonwaterDock/LakePlatform` | 12 |
| `Landmarks/CentralPark/Landmarks/MoonwaterDock/Piling` | 12 |
| `Landmarks/CentralPark/Landmarks/MoonwaterDock/Piling2` | 12 |
| `Landmarks/CentralPark/Landmarks/MoonwaterDock/Piling3` | 12 |
| `Landmarks/CentralPark/Landmarks/MoonwaterDock/Piling4` | 12 |
| `Landmarks/CentralPark/Landmarks/MoonwaterDock/Piling5` | 12 |
| `Landmarks/CentralPark/Landmarks/MoonwaterDock/Piling6` | 12 |
| `Landmarks/CentralPark/Landmarks/MoonwaterDock/Piling7` | 12 |
| `Landmarks/CentralPark/Landmarks/MoonwaterDock/Piling8` | 12 |
| `Landmarks/CentralPark/Landmarks/MoonwaterDock/Bench/Seat` | 12 |
| `Landmarks/CentralPark/Landmarks/MoonwaterDock/Bench/Back` | 12 |
| `Landmarks/CentralPark/Landmarks/MoonwaterDock/Bench/Leg` | 12 |
| `Landmarks/CentralPark/Landmarks/MoonwaterDock/Bench/Leg2` | 12 |
| `Landmarks/CentralPark/Landmarks/Bench/Seat` | 12 |
| `Landmarks/CentralPark/Landmarks/Bench/Back` | 12 |
| `Landmarks/CentralPark/Landmarks/Bench/Leg` | 12 |
| `Landmarks/CentralPark/Landmarks/Bench/Leg2` | 12 |
| `Landmarks/CentralPark/Landmarks/Bench2/Seat` | 12 |
| `Landmarks/CentralPark/Landmarks/Bench2/Back` | 12 |
| `Landmarks/CentralPark/Landmarks/Bench2/Leg` | 12 |
| `Landmarks/CentralPark/Landmarks/Bench2/Leg2` | 12 |
| `Landmarks/CentralPark/Landmarks/Bench3/Seat` | 12 |
| `Landmarks/CentralPark/Landmarks/Bench3/Back` | 12 |
| `Landmarks/CentralPark/Landmarks/Bench3/Leg` | 12 |
| `Landmarks/CentralPark/Landmarks/Bench3/Leg2` | 12 |
| `Landmarks/CentralPark/Landmarks/Bench4/Seat` | 12 |
| `Landmarks/CentralPark/Landmarks/Bench4/Back` | 12 |
| `Landmarks/CentralPark/Landmarks/Bench4/Leg` | 12 |
| `Landmarks/CentralPark/Landmarks/Bench4/Leg2` | 12 |
| `Landmarks/CentralPark/Landmarks/ParkGate/StonePier` | 12 |
| `Landmarks/CentralPark/Landmarks/ParkGate/StonePier2` | 12 |
| `Landmarks/CentralPark/Landmarks/ParkGate2/StonePier` | 12 |
| `Landmarks/CentralPark/Landmarks/ParkGate2/StonePier2` | 12 |
| `Landmarks/CentralPark/Landmarks/ParkGate3/StonePier` | 12 |
| `Landmarks/CentralPark/Landmarks/ParkGate3/StonePier2` | 12 |
| `Landmarks/CentralPark/Landmarks/ParkGate4/StonePier` | 12 |
| `Landmarks/CentralPark/Landmarks/ParkGate4/StonePier2` | 12 |

## Airport

Occluder: `CityOcclusion/Airport`

| Source mesh | Triangles |
| --- | ---: |
| `CoastalRegion/Airport/Terminal/TerminalHall` | 12 |
| `CoastalRegion/Airport/Terminal/GlassFront` | 12 |
| `CoastalRegion/Airport/Terminal/FloatingRoof` | 12 |
| `CoastalRegion/Airport/Terminal/WindowMullion` | 12 |
| `CoastalRegion/Airport/Terminal/WindowMullion2` | 12 |
| `CoastalRegion/Airport/Terminal/WindowMullion3` | 12 |
| `CoastalRegion/Airport/Terminal/WindowMullion4` | 12 |
| `CoastalRegion/Airport/Terminal/WindowMullion5` | 12 |
| `CoastalRegion/Airport/Terminal/WindowMullion6` | 12 |
| `CoastalRegion/Airport/Terminal/WindowMullion7` | 12 |
| `CoastalRegion/Airport/Terminal/WindowMullion8` | 12 |
| `CoastalRegion/Airport/Terminal/WindowMullion9` | 12 |
| `CoastalRegion/Airport/Terminal/WindowMullion10` | 12 |
| `CoastalRegion/Airport/Terminal/WindowMullion11` | 12 |
| `CoastalRegion/Airport/Terminal/WindowMullion12` | 12 |
| `CoastalRegion/Airport/Terminal/WindowMullion13` | 12 |
| `CoastalRegion/Airport/Terminal/Concourse` | 12 |
| `CoastalRegion/Airport/Terminal/ConcourseWindows` | 12 |
| `CoastalRegion/Airport/Terminal/HallConnector` | 12 |
| `CoastalRegion/Airport/ControlTower/TowerStem` | 12 |
| `CoastalRegion/Airport/ControlTower/ControlCab` | 12 |
| `CoastalRegion/Airport/ControlTower/CabRoof` | 12 |
| `CoastalRegion/Airport/ControlTower/Antenna` | 60 |
| `CoastalRegion/Airport/Hangar/SideWall` | 12 |
| `CoastalRegion/Airport/Hangar/SideWall2` | 12 |
| `CoastalRegion/Airport/Hangar/RearWall` | 12 |
| `CoastalRegion/Airport/Hangar/HangarRoof3890` | 32 |
| `CoastalRegion/Airport/Hangar2/SideWall` | 12 |
| `CoastalRegion/Airport/Hangar2/SideWall2` | 12 |
| `CoastalRegion/Airport/Hangar2/RearWall` | 12 |
| `CoastalRegion/Airport/Hangar2/HangarRoof3750` | 32 |

## Land_MeshInstance3D

Occluder: `CityOcclusion/Land_MeshInstance3D`

| Source mesh | Triangles |
| --- | ---: |
| `Ground/GroundMesh/MeshInstance3D` | 14109 |

## Land_NorthernGround

Occluder: `CityOcclusion/Land_NorthernGround`

| Source mesh | Triangles |
| --- | ---: |
| `CityLife/Highway/NorthernGround` | 6961 |

## Land_CoastalTerrain

Occluder: `CityOcclusion/Land_CoastalTerrain`

| Source mesh | Triangles |
| --- | ---: |
| `CoastalRegion/Landscape/CoastalTerrain` | 52883 |

## Land_PinePassMountains

Occluder: `CityOcclusion/Land_PinePassMountains`

| Source mesh | Triangles |
| --- | ---: |
| `CityLife/Highway/PinePassMountains` | 756 |

## Ground

Occluder: `CityOcclusion/Ground`

| Source mesh | Triangles |
| --- | ---: |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch01` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch02` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch03` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch04` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch05` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch06` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch07` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch08` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch09` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch10` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch11` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch12` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch13` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch14` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch15` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch16` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch17` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch18` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch19` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch20` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch21` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch22` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch23` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch24` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch25` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch26` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch27` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch28` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch29` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch30` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch31` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch32` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch33` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch34` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch35` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch36` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch37` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch38` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch39` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch40` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch41` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch42` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch43` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch44` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch45` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch46` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch47` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch48` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch49` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch50` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch51` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch52` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch53` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch54` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch55` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch56` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch57` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch58` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch59` | 2 |
| `Ground/Sidewalks3_2GroundInfill/GroundPatch60` | 2 |
| `Ground/CitySidewalkGroundInfill/sidewalks_0_0/Mesh` | 106 |
| `Ground/CitySidewalkGroundInfill/sidewalks_1_0/Mesh` | 104 |
| `Ground/CitySidewalkGroundInfill/sidewalks_2_0/Mesh` | 110 |
| `Ground/CitySidewalkGroundInfill/sidewalks_3_0/Mesh` | 108 |
| `Ground/CitySidewalkGroundInfill/sidewalks_4_0/Mesh` | 110 |
| `Ground/CitySidewalkGroundInfill/sidewalks_5_0/Mesh` | 98 |
| `Ground/CitySidewalkGroundInfill/sidewalks_0_1/Mesh` | 126 |
| `Ground/CitySidewalkGroundInfill/sidewalks_1_1/Mesh` | 120 |
| `Ground/CitySidewalkGroundInfill/sidewalks_2_1/Mesh` | 118 |
| `Ground/CitySidewalkGroundInfill/sidewalks_3_1/Mesh` | 114 |
| `Ground/CitySidewalkGroundInfill/sidewalks_4_1/Mesh` | 132 |
| `Ground/CitySidewalkGroundInfill/sidewalks_5_1/Mesh` | 118 |
| `Ground/CitySidewalkGroundInfill/sidewalks_0_2/Mesh` | 126 |
| `Ground/CitySidewalkGroundInfill/sidewalks_1_2/Mesh` | 126 |
| `Ground/CitySidewalkGroundInfill/sidewalks_2_2/Mesh` | 108 |
| `Ground/CitySidewalkGroundInfill/sidewalks_4_2/Mesh` | 132 |
| `Ground/CitySidewalkGroundInfill/sidewalks_5_2/Mesh` | 116 |
| `Ground/CitySidewalkGroundInfill/sidewalks_0_3/Mesh` | 74 |
| `Ground/CitySidewalkGroundInfill/sidewalks_1_3/Mesh` | 80 |
| `Ground/CitySidewalkGroundInfill/sidewalks_2_3/Mesh` | 82 |
| `Ground/CitySidewalkGroundInfill/sidewalks_3_3/Mesh` | 58 |
| `Ground/CitySidewalkGroundInfill/sidewalks_4_3/Mesh` | 76 |
| `Ground/CitySidewalkGroundInfill/sidewalks_5_3/Mesh` | 76 |
| `Ground/RoadGroundInfill/Ground_0_0/Mesh` | 66 |
| `Ground/RoadGroundInfill/Ground_1_0/Mesh` | 68 |
| `Ground/RoadGroundInfill/Ground_2_0/Mesh` | 72 |
| `Ground/RoadGroundInfill/Ground_3_0/Mesh` | 332 |
| `Ground/RoadGroundInfill/Ground_4_0/Mesh` | 72 |
| `Ground/RoadGroundInfill/Ground_5_0/Mesh` | 62 |
| `Ground/RoadGroundInfill/Ground_0_1/Mesh` | 88 |
| `Ground/RoadGroundInfill/Ground_1_1/Mesh` | 86 |
| `Ground/RoadGroundInfill/Ground_2_1/Mesh` | 56 |
| `Ground/RoadGroundInfill/Ground_3_1/Mesh` | 401 |
| `Ground/RoadGroundInfill/Ground_4_1/Mesh` | 96 |
| `Ground/RoadGroundInfill/Ground_5_1/Mesh` | 84 |
| `Ground/RoadGroundInfill/Ground_0_2/Mesh` | 88 |
| `Ground/RoadGroundInfill/Ground_1_2/Mesh` | 86 |
| `Ground/RoadGroundInfill/Ground_2_2/Mesh` | 58 |
| `Ground/RoadGroundInfill/Ground_3_2/Mesh` | 412 |
| `Ground/RoadGroundInfill/Ground_4_2/Mesh` | 96 |
| `Ground/RoadGroundInfill/Ground_5_2/Mesh` | 82 |
| `Ground/RoadGroundInfill/Ground_0_3/Mesh` | 44 |
| `Ground/RoadGroundInfill/Ground_1_3/Mesh` | 46 |
| `Ground/RoadGroundInfill/Ground_2_3/Mesh` | 48 |
| `Ground/RoadGroundInfill/Ground_3_3/Mesh` | 221 |
| `Ground/RoadGroundInfill/Ground_4_3/Mesh` | 48 |
| `Ground/RoadGroundInfill/Ground_5_3/Mesh` | 42 |

## Roads

Occluder: `CityOcclusion/Roads`

| Source mesh | Triangles |
| --- | ---: |
| `Roads/roads_4_0/alley_6m/MeshInstance3D` | 10 |

## Sidewalks

Occluder: `CityOcclusion/Sidewalks`

| Source mesh | Triangles |
| --- | ---: |

## CityLife_Highway

Occluder: `CityOcclusion/CityLife_Highway`

| Source mesh | Triangles |
| --- | ---: |
| `CityLife/Highway/CountyHighway` | 378 |
| `CityLife/Highway/HighwayMarkings` | 1764 |
| `CityLife/Highway/HighwayEmbankments` | 756 |
| `CityLife/Highway/HighwayGuardrails` | 1512 |
| `CityLife/Highway/HighwaySign` | 12 |
| `CityLife/Highway/HighwaySign2` | 12 |
| `CityLife/Highway/HighwaySign3` | 12 |
| `CityLife/Highway/HighwaySign4` | 12 |
| `CityLife/Highway/HighwaySign5` | 12 |
| `CityLife/Highway/HighwaySign6` | 12 |
| `CityLife/Highway/PinePassTunnel/TunnelArch` | 144 |
| `CityLife/Highway/PinePassTunnel/PortalPier` | 12 |
| `CityLife/Highway/PinePassTunnel/TunnelWall` | 12 |
| `CityLife/Highway/PinePassTunnel/PortalPier2` | 12 |
| `CityLife/Highway/PinePassTunnel/TunnelWall2` | 12 |
| `CityLife/Highway/PinePassTunnel/TunnelDarkness` | 26 |

## CityLife_Baseball

Occluder: `CityOcclusion/CityLife_Baseball`

| Source mesh | Triangles |
| --- | ---: |
| `CityLife/Baseball/SandlotGrass` | 12 |
| `CityLife/Baseball/SandlotInfield` | 32 |
| `CityLife/Baseball/InfieldGrassDiamond` | 4 |
| `CityLife/Baseball/PitchersMound` | 60 |
| `CityLife/Baseball/Scoreboard` | 12 |

## Waterfront_Harbor

Occluder: `CityOcclusion/Waterfront_Harbor`

| Source mesh | Triangles |
| --- | ---: |
| `Waterfront/Harbor/QuayWall` | 12 |
| `Waterfront/Harbor/QuayWall2` | 12 |
| `Waterfront/Harbor/Container` | 12 |
| `Waterfront/Harbor/Container2` | 12 |
| `Waterfront/Harbor/Container3` | 12 |
| `Waterfront/Harbor/Container4` | 12 |
| `Waterfront/Harbor/Container5` | 12 |
| `Waterfront/Harbor/Container6` | 12 |
| `Waterfront/Harbor/Container7` | 12 |
| `Waterfront/Harbor/Container8` | 12 |
| `Waterfront/Harbor/Container9` | 12 |
| `Waterfront/Harbor/Container10` | 12 |
| `Waterfront/Harbor/Container11` | 12 |
| `Waterfront/Harbor/Container12` | 12 |
| `Waterfront/Harbor/Container13` | 12 |
| `Waterfront/Harbor/Container14` | 12 |
| `Waterfront/Harbor/Container15` | 12 |
| `Waterfront/Harbor/Container16` | 12 |
| `Waterfront/Harbor/Container17` | 12 |
| `Waterfront/Harbor/Container18` | 12 |
| `Waterfront/Harbor/Container19` | 12 |
| `Waterfront/Harbor/Container20` | 12 |
| `Waterfront/Harbor/Container21` | 12 |
| `Waterfront/Harbor/Container22` | 12 |
| `Waterfront/Harbor/Container23` | 12 |
| `Waterfront/Harbor/Container24` | 12 |
| `Waterfront/Harbor/DockCrane/Foot` | 12 |
| `Waterfront/Harbor/DockCrane/Cab` | 12 |
| `Waterfront/Harbor/DockCrane/CabGlass` | 12 |
| `Waterfront/Harbor/DockCrane2/Foot` | 12 |
| `Waterfront/Harbor/DockCrane2/Cab` | 12 |
| `Waterfront/Harbor/DockCrane2/CabGlass` | 12 |
| `Waterfront/Harbor/HarborOffice/Building` | 12 |
| `Waterfront/Harbor/HarborOffice/Roof` | 12 |
| `Waterfront/Harbor/HarborOffice/OfficeWindow` | 12 |
| `Waterfront/Harbor/HarborOffice/OfficeWindow2` | 12 |
| `Waterfront/Harbor/HarborOffice/OfficeWindow3` | 12 |
| `Waterfront/Harbor/HarborOffice/OfficeWindow4` | 12 |
| `Waterfront/Harbor/HarborOffice/OfficeWindow5` | 12 |
| `Waterfront/Harbor/PierSign` | 12 |

## Waterfront_PrisonIsland

Occluder: `CityOcclusion/Waterfront_PrisonIsland`

| Source mesh | Triangles |
| --- | ---: |
| `Waterfront/PrisonIsland/IslandTerrain` | 800 |
| `Waterfront/PrisonIsland/CoastalOutcrop` | 56 |
| `Waterfront/PrisonIsland/CoastalOutcrop2` | 56 |
| `Waterfront/PrisonIsland/CoastalOutcrop3` | 56 |
| `Waterfront/PrisonIsland/CoastalOutcrop4` | 56 |
| `Waterfront/PrisonIsland/CoastalOutcrop5` | 56 |
| `Waterfront/PrisonIsland/CoastalOutcrop6` | 56 |
| `Waterfront/PrisonIsland/CoastalOutcrop7` | 56 |
| `Waterfront/PrisonIsland/CoastalOutcrop8` | 56 |
| `Waterfront/PrisonIsland/CoastalOutcrop9` | 56 |
| `Waterfront/PrisonIsland/CoastalOutcrop10` | 56 |
| `Waterfront/PrisonIsland/CoastalOutcrop11` | 56 |
| `Waterfront/PrisonIsland/CoastalOutcrop12` | 56 |
| `Waterfront/PrisonIsland/CoastalOutcrop13` | 56 |
| `Waterfront/PrisonIsland/CoastalOutcrop14` | 56 |
| `Waterfront/PrisonIsland/CoastalOutcrop15` | 56 |
| `Waterfront/PrisonIsland/CoastalOutcrop16` | 56 |
| `Waterfront/PrisonIsland/CoastalOutcrop17` | 56 |
| `Waterfront/PrisonIsland/CoastalOutcrop18` | 56 |
| `Waterfront/PrisonIsland/CoastalOutcrop19` | 56 |
| `Waterfront/PrisonIsland/CoastalOutcrop20` | 56 |
| `Waterfront/PrisonIsland/CoastalOutcrop21` | 56 |
| `Waterfront/PrisonIsland/CoastalOutcrop22` | 56 |
| `Waterfront/PrisonIsland/CoastalOutcrop23` | 56 |
| `Waterfront/PrisonIsland/CoastalOutcrop24` | 56 |
| `Waterfront/PrisonIsland/CoastalOutcrop25` | 56 |
| `Waterfront/PrisonIsland/CoastalOutcrop26` | 56 |
| `Waterfront/PrisonIsland/CoastalOutcrop27` | 56 |
| `Waterfront/PrisonIsland/CoastalOutcrop28` | 56 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/Yard` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/PerimeterWall` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/PerimeterWall2` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/SouthWall` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/NorthWall` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/NorthWall2` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/GateLintel` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/GatePillar` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/GatePillar2` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/CellBlock/Building` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/CellBlock/Roof` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/CellBlock/RoofVent` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/CellBlock/RoofVent2` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/CellBlock2/Building` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/CellBlock2/Roof` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/CellBlock2/RoofVent` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/CellBlock2/RoofVent2` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/Administration` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/AdminRoof` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/AdminWindow` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/AdminWindow2` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/AdminWindow3` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/AdminWindow4` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/AdminWindow5` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/AdminWindow6` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/AdminWindow7` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/AdminWindow8` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/AdminWindow9` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/ExerciseCourt` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/GuardTower/Shaft` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/GuardTower/ObservationRoom` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/GuardTower/Roof` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/GuardTower2/Shaft` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/GuardTower2/ObservationRoom` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/GuardTower2/Roof` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/GuardTower3/Shaft` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/GuardTower3/ObservationRoom` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/GuardTower3/Roof` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/GuardTower4/Shaft` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/GuardTower4/ObservationRoom` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/GuardTower4/Roof` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/WallWalk` | 12 |
| `Waterfront/PrisonIsland/BlackwaterPenitentiary/WallWalk2` | 12 |
| `Waterfront/PrisonIsland/IslandAccessRamp` | 2 |
| `Waterfront/PrisonIsland/GateApproach` | 12 |
| `Waterfront/PrisonIsland/IslandBeacon/Tower` | 60 |
| `Waterfront/PrisonIsland/IslandBeacon/RedBand` | 60 |
| `Waterfront/PrisonIsland/IslandBeacon/LanternDeck` | 60 |
| `Waterfront/PrisonIsland/IslandBeacon/Lantern` | 60 |
| `Waterfront/PrisonIsland/IslandBeacon/Roof` | 50 |

## Waterfront_Riverbanks

Occluder: `CityOcclusion/Waterfront_Riverbanks`

| Source mesh | Triangles |
| --- | ---: |
| `Waterfront/Riverbanks/QuayWall171` | 12 |
| `Waterfront/Riverbanks/QuayWall172` | 12 |
| `Waterfront/Riverbanks/QuayWall173` | 12 |

## SouthRiverBridge

Occluder: `CityOcclusion/SouthRiverBridge`

| Source mesh | Triangles |
| --- | ---: |
| `SouthRiverBridge/DeckStructure` | 864 |
| `SouthRiverBridge/Foundations` | 144 |
| `SouthRiverBridge/Guardrails` | 1872 |
| `SouthRiverBridge/Hangers` | 840 |
| `SouthRiverBridge/MainCables` | 1168 |
| `SouthRiverBridge/TowerRecesses` | 96 |
| `SouthRiverBridge/Towers` | 1632 |

## CityHallBridge

Occluder: `CityOcclusion/CityHallBridge`

| Source mesh | Triangles |
| --- | ---: |
| `CityHallBridge/Arches` | 428 |
| `CityHallBridge/Guardrails` | 1032 |
| `CityHallBridge/Hangers` | 264 |
| `CityHallBridge/Supports` | 72 |
| `CityHallBridge/TieBeams` | 72 |

## NorthRiverBridge

Occluder: `CityOcclusion/NorthRiverBridge`

| Source mesh | Triangles |
| --- | ---: |
| `NorthRiverBridge/Arches` | 428 |
| `NorthRiverBridge/Guardrails` | 576 |
| `NorthRiverBridge/Hangers` | 168 |
| `NorthRiverBridge/Supports` | 48 |
| `NorthRiverBridge/TieBeams` | 72 |

## RiverFrontage

Occluder: `CityOcclusion/RiverFrontage`

| Source mesh | Triangles |
| --- | ---: |
| `RiverFrontage/Quay` | 702 |
| `RiverFrontage/Ground` | 692 |
| `RiverFrontage/Stone` | 720 |
| `RiverFrontage/Bed` | 360 |

## MountainRiver

Occluder: `CityOcclusion/MountainRiver`

| Source mesh | Triangles |
| --- | ---: |
| `MountainRiver/Rock` | 603 |
| `MountainRiver/Bed` | 380 |

## CityHall

Occluder: `CityOcclusion/CityHall`

| Source mesh | Triangles |
| --- | ---: |
| `CityHall/Model/Central block` | 12 |
| `CityHall/Model/Central entablature` | 12 |
| `CityHall/Model/Central green dome` | 284 |
| `CityHall/Model/Central pediment` | 9 |
| `CityHall/Model/Cornices` | 300 |
| `CityHall/Model/Courtyard lawn beds` | 24 |
| `CityHall/Model/Dome cornice` | 188 |
| `CityHall/Model/Dome drum` | 92 |
| `CityHall/Model/Dome pedestal` | 140 |
| `CityHall/Model/Dome ribs` | 120 |
| `CityHall/Model/Dome support cap` | 12 |
| `CityHall/Model/Door frames` | 72 |
| `CityHall/Model/Door surrounds` | 120 |
| `CityHall/Model/Drum columns` | 576 |
| `CityHall/Model/East link` | 12 |
| `CityHall/Model/East wing` | 12 |
| `CityHall/Model/Entrance base` | 12 |
| `CityHall/Model/Entrance columns` | 360 |
| `CityHall/Model/Entrance doors` | 27 |
| `CityHall/Model/Entrance esplanade` | 10 |
| `CityHall/Model/Entrance terrace slab` | 12 |
| `CityHall/Model/Front setback wall 1` | 12 |
| `CityHall/Model/Front setback wall -1` | 12 |
| `CityHall/Model/Garden edging` | 96 |
| `CityHall/Model/Grand staircase` | 480 |
| `CityHall/Model/Green roofs` | 48 |
| `CityHall/Model/Landing piers` | 72 |
| `CityHall/Model/Lantern base` | 68 |
| `CityHall/Model/Lantern core` | 44 |
| `CityHall/Model/Lantern pillars` | 160 |
| `CityHall/Model/Lantern roof` | 68 |
| `CityHall/Model/Raised terrace` | 12 |
| `CityHall/Model/Rear door` | 12 |
| `CityHall/Model/Retaining wall coping` | 24 |
| `CityHall/Model/Small dome caps` | 88 |
| `CityHall/Model/Small dome drums` | 120 |
| `CityHall/Model/Small domes` | 312 |
| `CityHall/Model/Stair cheek walls` | 96 |
| `CityHall/Model/Terrace lawn` | 12 |
| `CityHall/Model/West link` | 12 |
| `CityHall/Model/West wing` | 12 |
| `CityHall/Model/Wing pediments` | 18 |
| `CityHall/Model/Wing portico entablature` | 24 |

## Hospital

Occluder: `CityOcclusion/Hospital`

| Source mesh | Triangles |
| --- | ---: |
| `Hospital/Model/Arched surrounds` | 360 |
| `Hospital/Model/Bay piers` | 144 |
| `Hospital/Model/Bollards` | 144 |
| `Hospital/Model/Canopy` | 194 |
| `Hospital/Model/Carved stonework` | 84 |
| `Hospital/Model/Central tower` | 12 |
| `Hospital/Model/Entrance apron` | 12 |
| `Hospital/Model/Entrance doors` | 72 |
| `Hospital/Model/Entrance pavilion` | 12 |
| `Hospital/Model/Front lantern bays` | 20 |
| `Hospital/Model/Lower central hall` | 12 |
| `Hospital/Model/Outer pavilions` | 24 |
| `Hospital/Model/Roof equipment` | 240 |
| `Hospital/Model/Roof terraces` | 592 |
| `Hospital/Model/Stepped wings` | 48 |
| `Hospital/Model/Tower ribs` | 252 |
| `Hospital/Model/Wayfinding` | 24 |
| `Hospital/RescueDropOff/@MeshInstance3D@30` | 256 |

## PoliceStation

Occluder: `CityOcclusion/PoliceStation`

| Source mesh | Triangles |
| --- | ---: |
| `PoliceStation/Model/Blue entrance canopy` | 12 |
| `PoliceStation/Model/Equipment caps` | 24 |
| `PoliceStation/Model/Five storey main block` | 12 |
| `PoliceStation/Model/Front rear parapets` | 24 |
| `PoliceStation/Model/Main roof` | 12 |
| `PoliceStation/Model/Parapet coping` | 48 |
| `PoliceStation/Model/Precinct shield` | 2 |
| `PoliceStation/Model/Public doors` | 12 |
| `PoliceStation/Model/Public doors frame` | 24 |
| `PoliceStation/Model/Public entrance wing` | 12 |
| `PoliceStation/Model/Raised entrance tower` | 12 |
| `PoliceStation/Model/Rear service doors` | 12 |
| `PoliceStation/Model/Rear service doors frame` | 24 |
| `PoliceStation/Model/Rooftop equipment` | 24 |
| `PoliceStation/Model/Side base` | 24 |
| `PoliceStation/Model/Side parapets` | 24 |
| `PoliceStation/Model/Wing roof` | 12 |

## Bank1

Occluder: `CityOcclusion/Bank1`

| Source mesh | Triangles |
| --- | ---: |
| `Bank1/Model/Banking hall` | 12 |
| `Bank1/Model/Corner pilasters` | 24 |
| `Bank1/Model/Crown cap` | 12 |
| `Bank1/Model/Crown sign block` | 12 |
| `Bank1/Model/Door frame` | 36 |
| `Bank1/Model/Entrance columns` | 72 |
| `Bank1/Model/Entrance doors` | 12 |
| `Bank1/Model/Entrance pavilion` | 12 |
| `Bank1/Model/Foundation` | 12 |
| `Bank1/Model/Front cornices` | 48 |
| `Bank1/Model/Great arch jambs` | 24 |
| `Bank1/Model/Great arch surround` | 32 |
| `Bank1/Model/Main roof` | 12 |
| `Bank1/Model/Portico base` | 24 |
| `Bank1/Model/Portico entablature` | 24 |
| `Bank1/Model/Portico roof` | 12 |
| `Bank1/Model/Raised crest` | 12 |
| `Bank1/Model/Rear cornices` | 48 |
| `Bank1/Model/Rear door surround` | 36 |
| `Bank1/Model/Roof parapets` | 48 |
| `Bank1/Model/Roof vent caps` | 24 |
| `Bank1/Model/Roof vents` | 24 |
| `Bank1/Model/Side cornices` | 96 |
| `Bank1/Model/Split column entablature` | 24 |

## Bank2

Occluder: `CityOcclusion/Bank2`

| Source mesh | Triangles |
| --- | ---: |
| `Bank2/Model/Banking podium` | 12 |
| `Bank2/Model/Crown louver bands` | 120 |
| `Bank2/Model/Crown ventilation` | 24 |
| `Bank2/Model/Entrance doors` | 12 |
| `Bank2/Model/Entrance frames` | 36 |
| `Bank2/Model/First setback terrace` | 12 |
| `Bank2/Model/Floating canopy` | 12 |
| `Bank2/Model/Main tower core` | 12 |
| `Bank2/Model/Podium coping` | 12 |
| `Bank2/Model/Podium piers` | 24 |
| `Bank2/Model/Podium terrace` | 12 |
| `Bank2/Model/Rear frame` | 36 |
| `Bank2/Model/Rear service door` | 12 |
| `Bank2/Model/Second setback terrace` | 12 |
| `Bank2/Model/Setback corner fins` | 48 |
| `Bank2/Model/Setback edge rails` | 96 |
| `Bank2/Model/Side steel fins` | 72 |
| `Bank2/Model/Sloped crown` | 12 |
| `Bank2/Model/Upper setback core` | 12 |
| `Bank2/Model/Vertical steel fins` | 96 |

## Firehouse

Occluder: `CityOcclusion/Firehouse`

| Source mesh | Triangles |
| --- | ---: |
| `Firehouse/Model/Engine house masonry` | 12 |
| `Firehouse/Model/Front brick piers` | 60 |
| `Firehouse/Model/Hose tower masonry` | 12 |
| `Firehouse/Model/Main cornices` | 48 |
| `Firehouse/Model/Main roof` | 12 |
| `Firehouse/Model/Parapet caps` | 48 |
| `Firehouse/Model/Rain downpipes` | 24 |
| `Firehouse/Model/Rear cornices` | 48 |
| `Firehouse/Model/Rear door frame` | 36 |
| `Firehouse/Model/Rear sash windows` | 8 |
| `Firehouse/Model/Return cornices` | 96 |
| `Firehouse/Model/Roof parapets` | 48 |
| `Firehouse/Model/Side sash windows` | 8 |
| `Firehouse/Model/Stone foundation` | 36 |
| `Firehouse/Model/Tower cornices` | 48 |
| `Firehouse/Model/Tower crown` | 48 |
| `Firehouse/Model/Tower foundation` | 12 |
| `Firehouse/Model/Tower louvers` | 8 |
| `Firehouse/Model/Tower roof` | 12 |
| `Firehouse/Model/Upper sash windows` | 6 |

## ParkingGarage

Occluder: `CityOcclusion/ParkingGarage`

| Source mesh | Triangles |
| --- | ---: |
| `ParkingGarage/GeneratedGarage/large_06_Asphalt` | 42 |
| `ParkingGarage/GeneratedGarage/large_06_Concrete` | 972 |
| `ParkingGarage/GeneratedGarage/large_06_Paint` | 936 |
| `ParkingGarage/GeneratedGarage/large_06_Teal` | 720 |
| `ParkingGarage/GeneratedGarage/large_06_Yellow` | 10 |

## ParkingGarage2

Occluder: `CityOcclusion/ParkingGarage2`

| Source mesh | Triangles |
| --- | ---: |
| `ParkingGarage2/GeneratedGarage/large_10_Asphalt` | 74 |
| `ParkingGarage2/GeneratedGarage/large_10_Concrete` | 1500 |
| `ParkingGarage2/GeneratedGarage/large_10_Paint` | 1560 |
| `ParkingGarage2/GeneratedGarage/large_10_Teal` | 1056 |
| `ParkingGarage2/GeneratedGarage/large_10_Yellow` | 18 |

## ParkingGarage3

Occluder: `CityOcclusion/ParkingGarage3`

| Source mesh | Triangles |
| --- | ---: |
| `ParkingGarage3/GeneratedGarage/small_05_Asphalt` | 34 |
| `ParkingGarage3/GeneratedGarage/small_05_Concrete` | 744 |
| `ParkingGarage3/GeneratedGarage/small_05_Paint` | 160 |
| `ParkingGarage3/GeneratedGarage/small_05_Teal` | 540 |
| `ParkingGarage3/GeneratedGarage/small_05_Yellow` | 8 |

## ParkingGarage4

Occluder: `CityOcclusion/ParkingGarage4`

| Source mesh | Triangles |
| --- | ---: |
| `ParkingGarage4/GeneratedGarage/small_03_Asphalt` | 18 |
| `ParkingGarage4/GeneratedGarage/small_03_Concrete` | 480 |
| `ParkingGarage4/GeneratedGarage/small_03_Paint` | 96 |
| `ParkingGarage4/GeneratedGarage/small_03_Teal` | 372 |
| `ParkingGarage4/GeneratedGarage/small_03_Yellow` | 4 |

## ParkingGarage5

Occluder: `CityOcclusion/ParkingGarage5`

| Source mesh | Triangles |
| --- | ---: |
| `ParkingGarage5/GeneratedGarage/large_06_Asphalt` | 42 |
| `ParkingGarage5/GeneratedGarage/large_06_Concrete` | 972 |
| `ParkingGarage5/GeneratedGarage/large_06_Paint` | 936 |
| `ParkingGarage5/GeneratedGarage/large_06_Teal` | 720 |
| `ParkingGarage5/GeneratedGarage/large_06_Yellow` | 10 |

## ParkingGarage6

Occluder: `CityOcclusion/ParkingGarage6`

| Source mesh | Triangles |
| --- | ---: |
| `ParkingGarage6/GeneratedGarage/large_10_Asphalt` | 74 |
| `ParkingGarage6/GeneratedGarage/large_10_Concrete` | 1500 |
| `ParkingGarage6/GeneratedGarage/large_10_Paint` | 1560 |
| `ParkingGarage6/GeneratedGarage/large_10_Teal` | 1056 |
| `ParkingGarage6/GeneratedGarage/large_10_Yellow` | 18 |

## ParkingGarage7

Occluder: `CityOcclusion/ParkingGarage7`

| Source mesh | Triangles |
| --- | ---: |
| `ParkingGarage7/GeneratedGarage/medium_04_Asphalt` | 26 |
| `ParkingGarage7/GeneratedGarage/medium_04_Concrete` | 660 |
| `ParkingGarage7/GeneratedGarage/medium_04_Paint` | 376 |
| `ParkingGarage7/GeneratedGarage/medium_04_Teal` | 504 |
| `ParkingGarage7/GeneratedGarage/medium_04_Yellow` | 6 |

## ParkingGarage8

Occluder: `CityOcclusion/ParkingGarage8`

| Source mesh | Triangles |
| --- | ---: |
| `ParkingGarage8/GeneratedGarage/small_05_Asphalt` | 34 |
| `ParkingGarage8/GeneratedGarage/small_05_Concrete` | 744 |
| `ParkingGarage8/GeneratedGarage/small_05_Paint` | 160 |
| `ParkingGarage8/GeneratedGarage/small_05_Teal` | 540 |
| `ParkingGarage8/GeneratedGarage/small_05_Yellow` | 8 |
