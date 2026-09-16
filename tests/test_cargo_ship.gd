extends SceneTree
const BASE := "res://assets/waterfront/cargo_ship/"
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "manifest.json"))
	var report := {"variants":[],"triangle_limit":4999}
	var ships: Array[Node3D] = []
	for variant: String in ["ocean_blue","oxide_red","deep_teal","graphite"]:
		var ship: Node3D = load(BASE + "cargo_ship_" + variant + ".tscn").instantiate()
		ship.follow_day_night_cycle = false
		ship.position.x = ships.size()*220
		root.add_child(ship)
		ships.append(ship)
		var count := 0
		var imported := 0
		for part: MeshInstance3D in ship.find_children("*","MeshInstance3D",true,false):
			for surface in part.mesh.get_surface_count():
				var indices: int = part.mesh.surface_get_array_index_len(surface)
				var triangles := int((indices if indices > 0 else part.mesh.surface_get_array_len(surface))/3)
				count += triangles
				if ship.get_node("Model").is_ancestor_of(part): imported += triangles
				check(part.get_active_material(surface) != null,"Missing material on " + String(part.name))
		check(count < 5000, "Over triangle budget: " + variant)
		check(imported == int(manifest.exported_glb_triangles),"GLB/import triangle mismatch")
		for slot: String in ["Hull","Deck","Superstructure","ContainerA","ContainerB","ContainerC","ContainerD"]:
			var part := ship.get_node("Model").find_child(slot,true,false) as MeshInstance3D
			check(part != null,"Missing modular slot " + slot)
			if part: check(part.material_override.resource_name.begins_with(variant),"Wrong palette " + slot)
		ship.apply_night(1.0)
		var lamps: Node3D = ship.get_node("NavigationLights")
		check(lamps.get_child_count() == 7,"Incorrect lamp fixture count")
		for lamp: MeshInstance3D in lamps.get_children():
			check(lamp.visible == (lamp.get_meta("mode") == "underway"),"Underway light mode")
		check(lamps.get_node("Port").position.x < 0 and lamps.get_node("Starboard").position.x > 0,"Port/starboard reversed")
		check(lamps.get_node("AftMasthead").position.y-lamps.get_node("ForwardMasthead").position.y >= 4.5,"Masthead vertical separation")
		check(lamps.get_node("AftMasthead").position.z-lamps.get_node("ForwardMasthead").position.z >= manifest.length_m/2,"Masthead horizontal separation")
		check(lamps.get_node("ForwardMasthead").position.z+78 <= manifest.length_m/4,"Forward mast too far aft")
		for entry: Dictionary in manifest.lights:
			var mat: ShaderMaterial = lamps.get_node(entry.name).material_override
			check(is_equal_approx(float(mat.get_shader_parameter("arc_degrees")),entry.arc),"Wrong sector: " + String(entry.name))
		ship.navigation_mode = 1
		ship.deck_lights_enabled = false
		for lamp: MeshInstance3D in lamps.get_children():
			check(lamp.visible == (lamp.get_meta("mode") == "anchored"),"Anchor lights must replace underway lights")
		check(lamps.get_node("ForwardAnchor").position.y-lamps.get_node("AftAnchor").position.y >= 4.5,"Anchor light heights")
		check(ship.get_node("DeckLights").get_child(0).visible,"Anchor mode must illuminate >100m decks")
		ship.apply_night(0)
		check(ship.get_node("AnchorDayBall").visible,"Missing anchor day shape")
		for lamp: MeshInstance3D in lamps.get_children():check(not lamp.visible,"Navigation lamps on during day")
		ship.navigation_mode = 2
		ship.apply_night(1)
		for lamp: MeshInstance3D in lamps.get_children():check(not lamp.visible,"Berthed ship displays underway/anchor lights")
		report.variants.append({"variant":variant,"imported_glb_triangles":imported,"complete_scene_triangles":count})
	# An individual ship's light settings must not mutate other instances.
	ships[0].navigation_mode = 0
	ships[0].apply_night(1)
	ships[1].navigation_mode = 0
	ships[1].apply_night(0)
	var first: ShaderMaterial = ships[0].get_node("NavigationLights/Port").material_override
	var second: ShaderMaterial = ships[1].get_node("NavigationLights/Port").material_override
	check(first != second and float(first.get_shader_parameter("intensity")) > 0 and is_zero_approx(float(second.get_shader_parameter("intensity"))),"Ship illumination leaked between instances")
	await physics_frame
	await physics_frame
	var space := ships[0].get_world_3d().direct_space_state
	for sample: Vector3 in [Vector3(0,50,-68),Vector3(0,50,62),Vector3(0,50,4)]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(sample,sample-Vector3(0,70,0)))
		check(not hit.is_empty(),"Missing collision at " + str(sample))
		if not hit.is_empty():check(hit.position.y >= 4.9,"Ray missed deck/roof/container top")
	# Verify real day/night synchronization, including a late-spawned ship.
	var preview: Node3D = load(BASE + "cargo_ship_preview.tscn").instantiate()
	root.add_child(preview)
	await process_frame
	await process_frame
	preview.set_night(true)
	var late: Node3D = load(BASE + "cargo_ship.tscn").instantiate()
	root.add_child(late)
	await process_frame
	await process_frame
	check(late.get_node("NavigationLights/Port").visible,"Night spawn did not synchronize")
	preview.set_night(false)
	check(not late.get_node("NavigationLights/Port").visible,"Clock did not disable daylight navigation emission")
	report["failures"] = failures
	report["passed"] = failures.is_empty()
	FileAccess.open(BASE + "validation_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CARGO_SHIP_VALIDATION ",JSON.stringify(report))
	preview.free()
	late.free()
	for ship in ships:ship.free()
	quit(0 if failures.is_empty() else 1)
