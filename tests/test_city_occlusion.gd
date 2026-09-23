extends SceneTree
## Checks occluder sources and optionally refreshes the complete source inventory.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var city: Node3D = load("res://scenes/super_city.tscn").instantiate()
	city.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(city)
	await process_frame
	var system: Node3D = city.get_node("CityOcclusion")
	assert(system.get_child_count() > 10)
	for key: String in ["CityHall","Hospital","PoliceStation","Bank1","Bank2","Firehouse","ParkingGarage","ParkingGarage8","SouthRiverBridge","CityHallBridge","NorthRiverBridge","Waterfront_Harbor","Waterfront_PrisonIsland","Land_NorthernGround","Land_CoastalTerrain","Land_PinePassMountains"]:
		assert(system.inventory.has(key) and system.inventory[key].triangles>0,"Missing solid occluder: "+key)
	var gym := city.get_node("BoxingGymExterior/Occluder") as OccluderInstance3D
	assert(gym.occluder is BoxOccluder3D)
	assert(gym.position.is_equal_approx(Vector3(0,4.05,0)))
	assert((gym.occluder as BoxOccluder3D).size.is_equal_approx(Vector3(24.6,8,22.6)))
	assert(system.terrain_inventory.size()==4)
	for path: String in system.terrain_inventory:
		var source := city.get_node(path) as MeshInstance3D
		assert(source.mesh == null and source.has_meta("occlusion_source_mesh"))
		assert(source.get_node("RenderChunks").get_child_count() == system.terrain_inventory[path])
		for piece: MeshInstance3D in source.get_node("RenderChunks").get_children():
			assert(not piece.ignore_occlusion_culling)
			assert(piece.material_override == source.material_override)
	assert(city.get_node("CoastalRegion/DistantLandscape").ignore_occlusion_culling)
	var terrain_audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/occlusion/terrain/audit.json"))
	for key: String in terrain_audit:
		var entry: Dictionary = terrain_audit[key]
		assert(FileAccess.get_sha256(entry.source)==entry.sha256,"Terrain bake must match current source")
		var tiles: Node3D = load("res://assets/occlusion/terrain/"+key+".scn").instantiate()
		var area := 0.0
		var count := 0
		for tile: MeshInstance3D in tiles.get_children():
			var bounds := tile.mesh.get_aabb()
			assert(bounds.size.x<=entry.cell_metres+.01 and bounds.size.z<=entry.cell_metres+.01)
			var faces := tile.mesh.get_faces()
			count += faces.size()/3
			for i in range(0,faces.size(),3): area += (faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).length()*.5
		assert(count==entry.render_triangles)
		assert(absf(area-entry.source_area)/entry.source_area<.00001,"Exported terrain preserves surface area")
		tiles.free()
	var lines := PackedStringArray([
		"# City occlusion inventory", "",
		"This lists source meshes used by the current city occlusion system. Paths are relative to `SuperCity`. Static occluders use actual opaque source triangles; streets, ramps, roof setbacks and openings remain open. The gym also owns an inset 12-triangle box occluder in its reusable exterior scene.", "",
		"## Controls", "",
		"- Project Settings → Rendering → Occlusion Culling → Use Occlusion Culling enables the engine feature.",
		"- In the Remote scene tree, `CityOcclusion.trial_enabled` toggles all regions. Each child occluder's Visibility toggles that region.",
		"- `TrafficManager/DistantTraffic.occlusion_culling_enabled` toggles distant vehicle culling for comparisons.",
		"- Restart after editing source geometry. Run `tests/test_city_occlusion.gd` with `-- --write-inventory` to refresh this list.", "",
		"## Included and excluded", "",
		"- Districts: the main visible mesh of each placed building, excluding transparent surfaces and separate rooftop props. Standalone POIs and garages are discovered automatically under the city root.",
		"- Central Park: opaque terrain, houses and landmarks, including the bridge. Water, trails, trees, foliage, lanterns and fireflies are excluded.",
		"- Airport: opaque terminal, control tower and both hangars. Additional city coverage includes POIs, garages, bridges, harbor, prison, broad road/sidewalk surfaces, northern ground, coastal terrain and real mountain geometry.",
		"- Four large land meshes use offline clipped render tiles, preserving materials, UVs, normals, shape and original collision. Hidden tiles can be culled independently. Rebuild with assets/occlusion/build_terrain_chunks.gd after editing their source meshes; stale bakes safely fall back to the source geometry.",
		"- The distant mountain image strip is excluded as both an occluder and an occlusion target. Trees, tiny props, transparent effects, moving actors and vehicles remain eligible targets, but are not baked into solid blockers. Visible land beyond the gameplay area remains visible: this does not impose an artificial distance cutoff.",
		"- Vehicles, characters, physics and collision shapes are never baked into these occluders. Culling affects rendering only.", "",
		"## Summary", "", "| Region | Source meshes | Triangles |", "| --- | ---: | ---: |"])
	for region in system.inventory:
		var entry: Dictionary = system.inventory[region]
		if entry.triangles == 0: continue
		lines.append("| %s | %d | %d |" % [region,entry.sources.size(),entry.triangles])
		var blocker: OccluderInstance3D = system.get_node(NodePath(region))
		assert(blocker.occluder is ArrayOccluder3D)
		assert(blocker.occluder.get_indices().size() == entry.triangles*3)
		for source in entry.sources:
			assert(city.get_node(source.path) is MeshInstance3D)
			assert(not source.path.contains("RooftopHVAC") and not source.path.contains("AirTraffic"))
			assert(not source.path.contains("DistantLandscape"))
	lines.append("| **Total** | **%d** | **%d** |" % [system.building_count,system.triangle_count])
	for region in system.inventory:
		lines.append_array(["","## " + region,"","Occluder: `CityOcclusion/%s`" % region,"", "| Source mesh | Triangles |", "| --- | ---: |"])
		for source in system.inventory[region].sources:
			lines.append("| `%s` | %d |" % [source.path,source.triangles])
	if "--write-inventory" in OS.get_cmdline_user_args():
		FileAccess.open("res://docs/occlusion-inventory.md",FileAccess.WRITE).store_string("\n".join(lines)+"\n")
	system.trial_enabled = false
	for blocker in system.get_children(): assert(not blocker.is_visible_in_tree())
	system.trial_enabled = true
	for blocker in system.get_children(): assert(blocker.is_visible_in_tree())
	print("PASS: ",system.get_child_count()," city occluders plus gym, ",system.building_count," source meshes, ",system.triangle_count," triangles; ",system.terrain_inventory," render tiles; source references and toggles verified.")
	quit()
