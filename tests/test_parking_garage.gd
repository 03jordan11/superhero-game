extends SceneTree
## Actual imported mesh counts and physics queries across every supported bake.
const ROOT := "res://assets/buildings/parking_garage/"
var failures: Array[String] = []
var checked := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func ray(world: World3D, start: Vector3, finish: Vector3) -> Dictionary:
	return world.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start, finish))

func _run() -> void:
	var maximum := 0
	for size: String in ["small", "medium", "large"]:
		for floors in range(3, 11):
			var label := "%s_%02d" % [size, floors]
			var node := (load(ROOT + "baked/" + label + ".tscn") as PackedScene).instantiate() as Node3D
			root.add_child(node)
			await physics_frame
			await physics_frame
			var triangles := 0
			for mesh_node: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
				triangles += mesh_node.mesh.get_faces().size() / 3
				check(mesh_node.mesh.resource_path.begins_with(ROOT+"baked/"),label+" external shared mesh")
				for surface in mesh_node.mesh.get_surface_count():
					check(mesh_node.mesh.surface_get_material(surface).resource_path.begins_with(ROOT+"materials/"),label+" shared material")
			check(triangles > 0 and triangles <= 10000, label + " actual triangle budget")
			check(triangles == node.get_meta("rendered_triangles"), label + " audit metadata")
			maximum = maxi(maximum, triangles)
			var width: float = node.get_meta("width_metres")
			var entrance_x: float = node.get_meta("entrance_x")
			var ramp_x := width/2-4
			var world := node.get_world_3d()
			for level in floors:
				var height := level*3.6
				# Flat aisle and both ramp landings exist at the stated height.
				for spot: Vector2 in [Vector2(entrance_x,0),Vector2(ramp_x,-19),Vector2(ramp_x,19)]:
					var hit := ray(world,Vector3(spot.x,height+1,spot.y),Vector3(spot.x,height-1,spot.y))
					check(not hit.is_empty(), label + " missing floor/landing")
					if not hit.is_empty():
						check(absf(hit.position.y-height)<.025, label + " floor height mismatch")
				# Standing clearance across the drive aisle.
				check(ray(world,Vector3(entrance_x,height+.15,-24),Vector3(entrance_x,height+2.5,-24)).is_empty(), label+" aisle headroom")
				if level == floors-1:
					continue
				for z: float in [-15.05,-14.95,-10,0,10,14.95,15.05]:
					var ramp_y := height + clampf((z+15)*.12, 0, 3.6)
					var hit := ray(world,Vector3(ramp_x,ramp_y+.6,z),Vector3(ramp_x,ramp_y-.6,z))
					check(not hit.is_empty(),label+" ramp/landing continuity")
					if not hit.is_empty():
						check(absf(hit.position.y-ramp_y)<.025,label+" ramp slope mismatch")
					check(ray(world,Vector3(ramp_x,ramp_y+.06,z),Vector3(ramp_x,ramp_y+2.6,z)).is_empty(),label+" blocked ramp/headroom")
			# Entrance must stay clear; the side facade must block traversal.
			check(ray(world,Vector3(entrance_x,1,-29),Vector3(entrance_x,1,-24)).is_empty(),label+" blocked entrance")
			check(not ray(world,Vector3(-width/2-1,.5,5),Vector3(-width/2+1,.5,5)).is_empty(),label+" missing barrier collision")
			node.free()
			checked += 1
	# Exercise exported parameter clamping and replacement without duplicate bodies.
	var configurable := (load(ROOT+"parking_garage.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(configurable)
	configurable.floors = 99
	configurable.width_preset = 2
	await process_frame
	await process_frame
	check(configurable.floors == 10,"maximum floor clamp")
	check(configurable.get_child_count() == 1,"one generated garage after parameter changes")
	check(configurable.get_node("GeneratedGarage").get_meta("parking_levels") == 10,"baked variant matches parameters")
	configurable.floors = 0
	configurable.width_preset = -1
	await process_frame
	await process_frame
	check(configurable.floors == 3 and configurable.width_preset == 0,"minimum parameter clamps")
	configurable.free()
	print("GARAGE_VALIDATION: ", checked," configurations; max ",maximum," triangles; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
