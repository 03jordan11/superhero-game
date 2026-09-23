extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	assert(not DirAccess.dir_exists_absolute("res://MeshTest"), "Retired MeshTest folder must be gone")
	for original in ["Superhero-male/Superhero_Male_FullBody.gltf", "Superhero-female/Superhero_Female_FullBody.gltf"]:
		assert(ResourceLoader.exists("res://assets/characters/" + original), "Original encounter model remains")
	var scene = load("res://scenes/hero_costumes.tscn").instantiate()
	root.add_child(scene)
	assert(scene.get_node("Costumes").get_child_count() == 2)
	var expected := {
		"Underwear": ["res://assets/characters/hero_meshy/hero_meshy.glb", 1552, 1],
		"StarterSuit": ["res://assets/characters/hero_starter_suit/hero_starter_suit_rigged.glb", 2172, 1]
	}
	for outfit in expected:
		var model: Node3D = scene.get_node("Costumes/" + outfit + "/Model")
		assert(model.scene_file_path == expected[outfit][0], "Correct retained model")
		assert(model.find_children("*", "Skeleton3D", true, false).size() == expected[outfit][2])
		var triangles := 0
		var bounds := AABB()
		var first := true
		for instance: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var box := instance.global_transform * instance.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
			for surface in instance.mesh.get_surface_count():
				triangles += instance.mesh.surface_get_array_index_len(surface) / 3
				assert(instance.get_active_material(surface) != null, "Texture/material retained")
				var material := instance.get_active_material(surface) as StandardMaterial3D
				assert(material.vertex_color_use_as_albedo, "Local lip tint is enabled after import")
				var arrays := instance.mesh.surface_get_arrays(surface)
				var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				assert(colors.size() == vertices.size(), "Lip vertex colors retained")
				var tinted := 0
				for vertex in vertices.size():
					if colors[vertex].r < 0.99:
						tinted += 1
						var point := instance.global_transform * vertices[vertex]
						assert(point.y > 1.64 and point.y < 1.72, "Tint is confined to the mouth")
				assert(tinted > 0 and tinted < vertices.size()/10, "Local tint does not alter the whole outfit")
		assert(triangles == expected[outfit][1], "Geometry preserved")
		assert(absf(bounds.position.y - 0.08) < 0.001, "Feet rest on plinth")
		assert(absf(bounds.size.y - 1.8131932) < 0.001, "Outfits use matching display heights")
	scene.select_view(1)
	assert(is_equal_approx(scene.focus.x, -1.3))
	scene.select_view(2)
	assert(is_equal_approx(scene.focus.x, 1.3))
	scene.select_view(0)
	assert(is_zero_approx(scene.focus.x))
	assert(scene.animations.size() == 2, "Both outfits have animation playback")
	var first_skeleton: Skeleton3D = scene.skeletons[0]
	var second_skeleton: Skeleton3D = scene.skeletons[1]
	for clip in scene.clips:
		if clip == scene.REST_POSE: continue
		scene.select_clip(clip)
		for fraction in [0.0, 0.37, 0.83]:
			scene.scrub_to(fraction)
			for animation: AnimationPlayer in scene.animations:
				assert(is_equal_approx(animation.current_animation_position, scene.elapsed))
				var resource := animation.get_animation(clip)
				for track in resource.get_track_count():
					var path := resource.track_get_path(track)
					assert(animation.get_node(animation.root_node).has_node(NodePath(path.get_concatenated_names())), "Animation track resolves: " + str(path))
			for bone in first_skeleton.get_bone_count():
				var other := second_skeleton.find_bone(first_skeleton.get_bone_name(bone))
				assert(first_skeleton.get_bone_pose(bone).is_equal_approx(second_skeleton.get_bone_pose(other)), "Outfit bone poses stay synchronized")
	scene.select_clip("Sprint")
	scene.scrub.value = 0.4
	assert(not scene.playing, "Dragging the timeline pauses playback")
	var paused_time: float = scene.elapsed
	scene._process(0.1)
	assert(is_equal_approx(scene.elapsed, paused_time))
	scene.play_button.pressed.emit()
	scene.speed_picker.item_selected.emit(1)
	scene._process(0.1)
	assert(is_equal_approx(scene.elapsed, paused_time + 0.025), "Quarter-speed control affects shared clock")
	scene.select_view(2)
	assert(is_equal_approx(scene.elapsed, paused_time + 0.025), "Changing view preserves playback time")
	scene.restart()
	assert(is_zero_approx(scene.elapsed))
	scene.select_clip(scene.REST_POSE)
	assert(not scene.scrub.editable and scene.play_button.disabled)
	for skeleton: Skeleton3D in scene.skeletons:
		for bone in skeleton.get_bone_count():
			var pose := skeleton.get_bone_pose(bone)
			var rest := skeleton.get_bone_rest(bone)
			assert(pose.origin.distance_to(rest.origin) < 0.00001, "Rest pose clears bone translation")
			# Imported leaf rests contain slight shear; Godot stores pose as TRS.
			assert(absf(skeleton.get_bone_pose_rotation(bone).dot(rest.basis.get_rotation_quaternion())) > 0.99999, "Rest pose clears bone rotation")
			assert(skeleton.get_bone_pose_scale(bone).distance_to(rest.basis.get_scale()) < 0.00001, "Rest pose clears bone scale")
	scene.free()
	print("HERO_COSTUMES_TESTS: PASS | two outfits | synchronized animations | playback controls | rest pose | matched scale | original encounter assets retained")
	quit()
