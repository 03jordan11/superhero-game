extends SceneTree
## Retains the original test entry point; now covers the four civilian replacements.
const MODELS = preload("res://scripts/npc-scripts/civilian_model.gd").MODELS
const TRIANGLES := [4185, 4264, 4148, 4264]
const HEIGHTS := [1.78, 1.80, 1.72, 1.68]
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var shared_meshes: Dictionary = {}
	for variant in MODELS.size():
		for scene in ["civilian", "routed_civilian", "rescue_patient"]:
			var npc = load("res://scenes/npcs/" + scene + ".tscn").instantiate()
			npc.model_variant_index = variant
			root.add_child(npc)
			npc.set_physics_process(false)
			# Keep the established node path for controller and rescue-patient consumers.
			var model: Node3D = npc.get_node("Superhero_Female_FullBody/Visual")
			check(model.scene_file_path == MODELS[variant].resource_path, "Civilian uses the selected rigged model")
			var hair: CharacterHair = npc.get_node("CharacterHair")
			check(not hair.enabled and hair.attachment == null, "No duplicate hair accessories")
			var meshes := model.find_children("*", "MeshInstance3D", true, false)
			check(meshes.size() == 1, "Single integrated body/hair mesh")
			var mesh: MeshInstance3D = meshes[0]
			if not shared_meshes.has(variant): shared_meshes[variant] = mesh.mesh
			else: check(mesh.mesh == shared_meshes[variant], "Instances of each variant share geometry")
			var triangles := 0
			for surface in mesh.mesh.get_surface_count():
				triangles += mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size() / 3
			check(triangles == TRIANGLES[variant], "Civilian retains its approved triangle count")
			check(absf(mesh.get_aabb().size.y - HEIGHTS[variant]) < 0.005, "Civilian retains its preview height")
			check(mesh.material_override == null and mesh.get_surface_override_material(0) == null, "Original textured material is retained")
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
			check(not first.is_equal_approx(skeleton.get_bone_pose_rotation(leg)), "Walk animates the civilian rig")
			npc.free()
	print("CIVILIAN_MODEL_TESTS: %s | four variants | civilian + routed + rescue patient | 7 clips" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
