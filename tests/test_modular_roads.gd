extends SceneTree
const KIT := "res://assets/super-city/modular-roads/"
const PRESETS := ["straight_12m", "straight_20m", "straight_28m", "alley_6m", "junction_cross", "junction_t", "corner_90", "dead_end", "alley_entrance"]
var failures := 0
var probes := 0
var world: Node3D

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		if failures < 30: push_error(message)

func hit_at(point: Vector3) -> Dictionary:
	probes += 1
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP, point - Vector3.UP))

func supported(point: Vector3) -> bool:
	var hit := hit_at(point)
	return not hit.is_empty() and absf(hit.position.y - 0.03) < 0.0001

func make_piece(preset: String, at := Vector3.ZERO) -> Node3D:
	var piece := load(KIT + preset + ".tscn").instantiate() as Node3D
	piece.position = at
	world.add_child(piece)
	return piece

func frames() -> void:
	await process_frame
	await physics_frame
	await physics_frame

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	# Verify exported preset meshes exist even before the @tool script runs.
	for preset in PRESETS:
		var saved := load(KIT + preset + ".tscn").instantiate() as Node3D
		check(saved.get_node("Mesh").mesh != null, "Saved mesh: " + preset)
		check(saved.get_node("Collision").shape != null, "Saved collision: " + preset)
		saved.free()
	# Exercise every city width pairing and all meaningful junction arm patterns.
	for width in [12, 20, 28]:
		for cross_width in [6, 12, 20, 28]:
			for arms in [3, 6, 9, 12, 7, 11, 13, 14, 15, 5, 10]:
				var junction := make_piece("junction_cross")
				junction.width_m = width
				junction.cross_width_m = cross_width
				junction.active_arms = arms
				junction.rebuild()
				var neighbors: Array[Node3D] = []
				for i in 4:
					if not arms & (1 << i): continue
					var direction: Vector3 = [Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT][i]
					var socket := junction.get_node("RoadSockets/" + ["North", "East", "South", "West"][i]) as Marker3D
					var street := make_piece("straight_20m", socket.position + direction * 10.0)
					street.length_m = 20.0
					street.width_m = width if i == 0 or i == 2 else cross_width
					# The neighbor's North end faces inward toward the junction.
					street.basis = Basis.looking_at(-direction)
					street.rebuild()
					neighbors.append(street)
				await frames()
				check(supported(Vector3.ZERO), "Junction center")
				var half := Vector2(width / 2.0, cross_width / 2.0)
				# Each pavement corner must support a turn, including T closed sides.
				for sx in [-1, 1]:
					for sz in [-1, 1]:
						for dx in [0.1, 2.0, 3.9]:
							for dz in [0.1, 2.0, 3.9]:
								check(supported(Vector3(sx * (half.x + dx), 0, sz * (half.y + dz))), "Sidewalk corner support")
				for i in 4:
					var dir: Vector3 = [Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT][i]
					var transverse := dir.cross(Vector3.UP)
					var across: float = width if i == 0 or i == 2 else cross_width
					var distance: float = cross_width / 2.0 if i == 0 or i == 2 else width / 2.0
					if arms & (1 << i):
						for lateral in [-across / 2.0 - 2.0, -across / 2.0 + 0.1, 0.0, across / 2.0 - 0.1, across / 2.0 + 2.0]:
							for seam in [-0.01, 0.0, 0.01]:
								check(supported(dir * (distance + 8.0 + seam) + transverse * lateral), "Road/sidewalk connection seam")
					else:
						for lateral in [-across / 2.0, 0.0, across / 2.0]:
							check(supported(dir * (distance + 2.0) + transverse * lateral), "Closed arm wraps sidewalk")
						check(hit_at(dir * (distance + 4.1)).is_empty(), "No phantom pavement beyond closed arm")
				junction.free()
				for neighbor in neighbors: neighbor.free()
	# Resizing changes both footprint and collision, without mutating another instance.
	var first := make_piece("straight_20m")
	var second := make_piece("straight_20m", Vector3(100, 0, 0))
	first.length_m = 120.0
	first.crosswalk_north = true
	first.crosswalk_south = true
	await frames()
	check(supported(Vector3(0, 0, 59.9)), "Extended road collision")
	check(supported(Vector3(12, 0, -59.9)), "Extended sidewalk collision")
	check(hit_at(Vector3(0, 0, 60.1)).is_empty(), "Collision ends at resized boundary")
	check(hit_at(Vector3(100, 0, 30)).is_empty(), "Other instance remains short")
	check(first.get_node("RoadSockets/North").position.z == -60.0, "Road socket resizes")
	check(first.get_node("SidewalkSockets/SouthLeft").position.z == 60.0, "Sidewalk socket resizes")
	check(first.scale == Vector3.ONE, "Physics body remains unscaled")
	var material: ShaderMaterial = first.get_node("Mesh").mesh.surface_get_material(0)
	check(material.get_shader_parameter("length_m") == 120.0, "Shader receives physical length")
	check(material.get_shader_parameter("crossing_north") and material.get_shader_parameter("crossing_south"), "Crosswalk controls reach shader")
	first.length_m = 16.0
	first.include_sidewalks = false
	await frames()
	check(hit_at(Vector3(0, 0, 9)).is_empty(), "Shrinking removes old collider")
	check(hit_at(Vector3(12, 0, 0)).is_empty(), "Disabling sidewalks removes collision")
	check(first.get_node("Mesh").mesh.get_surface_count() == 1, "Disabling sidewalks removes rendered pavement")
	# Save/reload non-default dimensions to catch stale editor mesh or shared-resource issues.
	var packed := PackedScene.new()
	check(packed.pack(first) == OK, "Pack resized piece")
	var restored := packed.instantiate() as Node3D
	first.free()
	world.add_child(restored)
	await frames()
	check(restored.length_m == 16.0 and supported(Vector3(0, 0, 7.9)), "Resized instance restores")
	check(hit_at(Vector3(0, 0, 8.1)).is_empty(), "Restored collision matches resized length")
	restored.free()
	second.free()
	var end := make_piece("dead_end")
	await frames()
	check(supported(Vector3(0, 0, 14)), "End cap sidewalk wraps road")
	check(not end.get_node("RoadSockets/South").get_meta("active"), "End cap has no onward connection")
	end.free()
	# Existing sidewalk kit meets a road-only module's footprint at the same height.
	var road := make_piece("straight_20m")
	road.include_sidewalks = false
	var walk := load("res://assets/super-city/modular-sidewalks/straight_adjustable.tscn").instantiate() as Node3D
	walk.position.x = 12.0
	world.add_child(walk)
	await frames()
	for x in [9.99, 10.0, 10.01, 12.0, 13.99]: check(supported(Vector3(x, 0, 0)), "Existing sidewalk kit compatibility")
	road.free()
	walk.free()
	# Fitted openings persist through serialization, rotation and later resizing.
	var fitted := load(KIT + "straight_20m.tscn").instantiate() as Node3D
	fitted.keep_sockets_at_runtime = false
	var openings: Array[Rect2] = [Rect2(-14,-3,4,6)]
	fitted.sidewalk_cutouts = openings
	fitted.rotation.y = PI/2
	world.add_child(fitted)
	await frames()
	check(not fitted.has_node("RoadSockets") and not fitted.has_node("SidewalkSockets"), "Runtime city omits connection helpers")
	check(hit_at(Vector3(0,0,12)).is_empty(), "Rotated alley opening has no pavement collision")
	check(supported(Vector3(5,0,12)) and supported(Vector3(0,0,-12)), "Pavement beside opening and opposite side remains")
	var fitted_save := PackedScene.new()
	check(fitted_save.pack(fitted)==OK, "Pack fitted road")
	var fitted_copy := fitted_save.instantiate() as Node3D
	fitted.free(); world.add_child(fitted_copy)
	fitted_copy.length_m=120
	await frames()
	check(fitted_copy.sidewalk_cutouts.size()==1 and hit_at(Vector3(0,0,12)).is_empty(), "Opening survives save/reload and resize")
	check(supported(Vector3(59,0,12)), "Road rebuilds after runtime helpers were removed")
	fitted_copy.free()
	world.free()
	print("MODULAR_ROADS: 9 saved presets, 132 junction configurations, resize/save/sidewalk checks, %d physics probes, %d failures" % [probes, failures])
	quit(1 if failures else 0)
