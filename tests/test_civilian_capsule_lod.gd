extends SceneTree
const JOURNEY := preload("res://scripts/npc-scripts/pedestrian_journey.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	seed(412)
	var city = load("res://scenes/super_city.tscn").instantiate()
	if city.has_node("Player"): city.get_node("Player").free()
	var focus := Node3D.new()
	focus.name = "LODFocus"
	focus.position = Vector3(-1286,0.03,-972)
	focus.rotation.y = PI
	city.add_child(focus)
	var crowd = city.get_node("CivilianCrowd")
	crowd.player_path = ^"../LODFocus"
	crowd.population_target = 4
	crowd.max_civilians = 16
	crowd.ground_radius = 70.0
	crowd.minimum_player_distance = 5.0
	crowd.despawn_delay = 0.25
	crowd.prefer_offscreen_spawns = false
	var lod = crowd.get_node("CapsuleLOD")
	lod.promote_distance = 30.0
	lod.demote_distance = 45.0
	lod.interaction_distance = 10.0
	lod.max_capsules = 12
	lod.view_distance = 180.0
	lod.surrounding_radius = 60.0
	lod.check_interval = 0.05
	lod.demote_delay = 0.15
	root.add_child(city)
	for frame in range(180):
		await physics_frame
		if crowd.active_count > 16:
			fail("The tiers exceeded their shared hard cap")
			return
	if lod.capsule_count < 2:
		fail("Distant population did not spawn capsules")
		return
	var capsule: Node3D
	var before_motion: Dictionary = {}
	for walker in crowd._active.get_children():
		if not walker.is_lightweight: continue
		if walker is CollisionObject3D or not walker.find_children("*","Skeleton3D",true,false).is_empty() or not walker.find_children("*","AnimationPlayer",true,false).is_empty():
			fail("A capsule contains character physics or animation")
			return
		before_motion[walker] = walker.global_position
		if crowd._promotion_clear(walker): capsule = walker
	if capsule == null:
		fail("No clear capsule candidate for handoff")
		return
	lod._timer = 100.0 # Inspect handoffs without automatic replacements interfering.
	for frame in range(60): await physics_frame
	var moved := 0
	for walker in before_motion:
		if is_instance_valid(walker) and walker.global_position.distance_to(before_motion[walker]) > 0.5: moved += 1
	if moved == 0:
		fail("Capsules did not move along their routes")
		return
	capsule._pause_remaining = 0.6
	capsule._crossing_active = true
	var state := JOURNEY.capture(capsule)
	var count: int = crowd._active.get_child_count()
	var full = lod.promote(capsule)
	if full == null:
		fail("A clear capsule failed to promote")
		return
	if not same_state(state,JOURNEY.capture(full)) or count != crowd._active.get_child_count():
		fail("Promotion changed identity, route progress, crossing wait, pose or population count")
		return
	var models = preload("res://scripts/npc-scripts/civilian_model.gd").MODELS
	if full.get_node("Superhero_Female_FullBody/Visual").scene_file_path != models[state.model_variant_index].resource_path:
		fail("Promotion instantiated a different civilian model than the capsule's saved choice")
		return
	for frame in range(3): await physics_frame
	state = JOURNEY.capture(full)
	var reduced = lod.demote(full)
	if not same_state(state,JOURNEY.capture(reduced)) or count != crowd._active.get_child_count():
		fail("Demotion changed route state or population count")
		return
	for frame in range(3): await physics_frame
	# A real obstruction must postpone promotion without deleting its visual.
	var blocker := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2,2.0,1.2)
	shape.shape = box
	shape.position.y = 1.0
	blocker.add_child(shape)
	city.add_child(blocker)
	blocker.global_position = reduced.global_position
	for frame in range(2): await physics_frame
	if lod.promote(reduced) != null or not is_instance_valid(reduced) or not reduced.promotion_blocked:
		fail("Blocked promotion did not retain the capsule safely")
		return
	blocker.free()
	for frame in range(2): await physics_frame
	var location: Vector3 = reduced.global_position
	var explosion = load("res://scripts/combat-scripts/explosion_controller.gd").new()
	explosion.radius = 0.2
	explosion.minimum_damage = 15.0
	explosion.maximum_damage = 15.0
	city.add_child(explosion)
	explosion._apply_radius_damage(location+Vector3.UP*0.8,18.0,null)
	explosion.free()
	for frame in range(3): await physics_frame
	var damaged: Node3D
	for walker in crowd._active.get_children():
		if not walker.is_lightweight and walker.get_current_health() == 85.0: damaged = walker
	if damaged == null or lod._can_demote(damaged):
		fail("Capsule damage was lost or an injured civilian could demote")
		return
	# Automatic promotion while approaching uses the same handoff.
	for walker in crowd._active.get_children():
		if walker.is_lightweight and crowd._promotion_clear(walker):
			capsule = walker
			break
	var promotions_before: int = lod.promotions
	focus.global_position = capsule.global_position+Vector3.RIGHT*4.0
	lod._timer = 0.0
	for frame in range(30): await physics_frame
	if lod.promotions <= promotions_before:
		fail("Approaching did not automatically promote capsules")
		return
	# Disable must clear the distant tier gradually without a duplicate population.
	lod.enabled = false
	focus.position = Vector3(-1286,0.03,-972)
	for frame in range(180): await physics_frame
	if lod.capsule_count != 0:
		fail("Disabling CapsuleLOD did not remove/replace the distant tier")
		return
	crowd.crowd_enabled = false
	for frame in range(120): await physics_frame
	if crowd.active_count != 0:
		fail("Crowd disable did not clear both tiers")
		return
	print("PASS: cheap moving capsules, shared cap, exact handoff state, blocked promotion, capsule damage, automatic approach and disable. No player or visual test.")
	quit()

func same_state(a: Dictionary, b: Dictionary) -> bool:
	for field in a:
		if a[field] != b[field]: return false
	return true

func fail(message: String) -> void:
	push_error(message)
	quit(1)
