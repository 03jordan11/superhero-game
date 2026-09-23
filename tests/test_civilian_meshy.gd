extends SceneTree
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var shared_mesh: Mesh
	for scene in ["civilian", "routed_civilian", "rescue_patient"]:
		var npc = load("res://scenes/npcs/" + scene + ".tscn").instantiate()
		root.add_child(npc)
		npc.set_physics_process(false)
		# Keep the established node path for controller and rescue-patient consumers.
		var model: Node3D = npc.get_node("Superhero_Female_FullBody")
		check(model.scene_file_path == "res://assets/characters/hero_meshy/hero_meshy.glb", "Civilian uses the same approved player asset")
		var hair: CharacterHair = npc.get_node("CharacterHair")
		check(not hair.enabled and hair.attachment == null, "No duplicate hair accessories")
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		check(meshes.size() == 1, "Single integrated body/hair mesh")
		var mesh: MeshInstance3D = meshes[0]
		if shared_mesh == null: shared_mesh = mesh.mesh
		else: check(mesh.mesh == shared_mesh, "Crowd instances share geometry")
		var triangles := 0
		for surface in mesh.mesh.get_surface_count():
			triangles += mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size() / 3
		check(triangles == 1552, "Civilian retains 1,552 triangles")
		var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
		check(skeleton.get_bone_count() == 65 and mesh.skin != null, "Existing humanoid skeleton and skin")
		if scene == "rescue_patient":
			check(npc.skeleton == skeleton and npc.get_carry_anchor_position().is_finite(), "Rescue carry anchor resolves on the replacement rig")
			check(not npc.animation_controller.animation_player.is_playing(), "Rescue patient starts in its paused injured pose")
		var animation: AnimationPlayer = npc.animation_controller.animation_player
		animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for clip in ["Idle", "Walk", "Run", "Hit_Chest", "Death01", "Hit_Knockback", "Hit_Knockback_RM"]:
			check(animation.has_animation(clip), "Civilian clip available: " + clip)
			var resource := animation.get_animation(clip)
			for track in resource.get_track_count():
				var path := resource.track_get_path(track)
				var target := model.get_node_or_null(NodePath(path.get_concatenated_names()))
				check(target != null, "Civilian track target resolves: " + str(path))
				if target is Skeleton3D and path.get_subname_count() > 0:
					check(target.find_bone(path.get_subname(0)) >= 0, "Civilian track bone resolves")
			animation.play(clip, 0)
			for fraction in [0.0, 0.25, 0.5, 0.75]:
				animation.seek(resource.length * fraction, true)
				animation.advance(0)
				skeleton.force_update_all_bone_transforms()
				for bone in skeleton.get_bone_count():
					check(skeleton.get_bone_global_pose(bone).is_finite(), "Finite animated bone pose")
		animation.play("Walk", 0)
		animation.seek(0.1, true)
		animation.advance(0)
		var leg := skeleton.find_bone("LeftUpperLeg")
		var first := skeleton.get_bone_pose_rotation(leg)
		animation.seek(animation.get_animation("Walk").length * 0.55, true)
		animation.advance(0)
		check(not first.is_equal_approx(skeleton.get_bone_pose_rotation(leg)), "Walk animates the Meshy rig")
		npc.free()
	print("CIVILIAN_MESHY_TESTS: %s | civilian + routed + rescue patient | 7 clips | 1552 triangles" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
