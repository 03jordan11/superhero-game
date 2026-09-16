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
	assert(system.get_child_count() == 10)
	var lines := PackedStringArray([
		"# City occlusion inventory", "",
		"This lists every source mesh used by the current occlusion system. Paths are relative to `SuperCity`. There is one static occluder per region, built once when the city starts. The occluders contain the actual opaque source triangles; streets, roof setbacks and openings remain open.", "",
		"## Controls", "",
		"- Project Settings → Rendering → Occlusion Culling → Use Occlusion Culling enables the engine feature.",
		"- In the Remote scene tree, `CityOcclusion.trial_enabled` toggles all regions. Each child occluder's Visibility toggles that region.",
		"- `TrafficManager/DistantTraffic.occlusion_culling_enabled` toggles distant vehicle culling for comparisons.",
		"- Restart after editing source geometry. Run `tests/test_city_occlusion.gd` with `-- --write-inventory` to refresh this list.", "",
		"## Included and excluded", "",
		"- Districts: the main visible mesh of each placed building, excluding transparent surfaces and separate rooftop props.",
		"- Central Park: opaque terrain, houses and landmarks, including the bridge. Water, trails, trees, foliage, lanterns and fireflies are excluded.",
		"- Airport: opaque terminal, control tower and both hangars, including painted opaque window panels. Aircraft, transparent surfaces, runways, roads, fences, lights and surrounding landscape are excluded.",
		"- Vehicles, characters, physics and collision shapes are never baked into these occluders. Culling affects rendering only.", "",
		"## Summary", "", "| Region | Source meshes | Triangles |", "| --- | ---: | ---: |"])
	for region in system.inventory:
		var entry: Dictionary = system.inventory[region]
		assert(entry.triangles > 0)
		lines.append("| %s | %d | %d |" % [region,entry.sources.size(),entry.triangles])
		var blocker: OccluderInstance3D = system.get_node(NodePath(region))
		assert(blocker.occluder is ArrayOccluder3D)
		assert(blocker.occluder.get_indices().size() == entry.triangles*3)
		for source in entry.sources:
			assert(city.get_node(source.path) is MeshInstance3D)
			assert(not source.path.contains("RooftopHVAC") and not source.path.contains("AirTraffic"))
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
	print("PASS: 10 occluders, ",system.building_count," source meshes, ",system.triangle_count," triangles; source references and toggles verified.")
	quit()
