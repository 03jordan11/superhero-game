extends SceneTree

var failures := 0

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(1))
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player := load("res://scenes/player.tscn").instantiate() as PlayerCharacter
	world.add_child(player)
	player.set_physics_process(false)
	var controller := player.animation_controller
	var animations := player.character_animation_player
	var skeleton := player.get_node("SuperheroCharacter").find_child("GeneralSkeleton", true, false) as Skeleton3D
	check(skeleton != null, "Hero skeleton resolves")
	check(not controller.use_authored_combo, "Original combo enabled by default")
	var library := animations.get_animation_library("AuthoredCombo")
	# The library also contains grab/carry pairs, validated separately.
	for clip in ["Hero_Cross", "Hero_Hook", "Hero_FlyingUppercut"]:
		var animation := library.get_animation(clip)
		check(animation.loop_mode == Animation.LOOP_NONE, "Combo clips must finish: " + clip)
		check(animation.length > 0.5 and animation.length < 1.1, "Expected clip duration: " + clip)
		for track in animation.get_track_count():
			var path := animation.track_get_path(track)
			var target := animations.get_node(animations.root_node).get_node_or_null(NodePath(path.get_concatenated_names()))
			check(target == skeleton, "Track resolves to player skeleton: " + str(path))
			if path.get_subname_count() > 0:
				check(skeleton.find_bone(path.get_subname(0)) >= 0, "Bone exists: " + str(path))
		# Sampling the imported curves catches flipped axes, collapsed bones and root motion.
		animations.play("AuthoredCombo/" + clip, 0.0)
		for time in [0.0, 0.1, 0.2, 0.35, animation.length]:
			animations.seek(time, true)
			skeleton.force_update_all_bone_transforms()
			var hips := skeleton.get_bone_global_pose(skeleton.find_bone("Hips")).origin
			var head := skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin
			check(hips.is_finite() and head.is_finite(), "Finite pose: " + clip)
			check(head.y > hips.y + 0.4, "Head remains above torso: " + clip)
			var root_pose := skeleton.get_bone_pose_position(skeleton.find_bone("Root"))
			check(root_pose.length() < 0.001, "Physics owns root motion: " + clip)
		animations.seek(0.2 if clip != &"Hero_FlyingUppercut" else 0.4, true)
		skeleton.force_update_all_bone_transforms()
		var hand_name := "LeftHand" if clip == &"Hero_Hook" else "RightHand"
		var hand := skeleton.get_bone_global_pose(skeleton.find_bone(hand_name)).origin
		var head := skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin
		if clip == &"Hero_FlyingUppercut":
			check(hand.y > head.y + 0.15, "Uppercut fist rises above head")
		else:
			check(hand.z > 0.4, "Punch reaches forward in the hero's +Z facing direction")
	for use_new in [true, false]:
		controller.use_authored_combo = use_new
		player.combat_controller.cancel_punch()
		player.combat_controller.request_punch()
		for index in 3:
			var original: String = PlayerCombatController.PUNCH_ANIMATIONS[index]
			check(animations.has_animation(original), "Original remains available: " + original)
			var expected: String = PlayerAnimationController.AUTHORED_COMBO_ANIMATIONS[original] if use_new else original
			check(animations.assigned_animation == expected, "Selected library plays through real combo controller")
			if index == 2:
				player.velocity = Vector3.ZERO
				player.combat_controller.punch_time = 0.24
				player.combat_controller.update_punch_momentum(player, 0.02, 10)
				check(player.velocity.y == player.combat_controller.uppercut_launch_velocity, "Existing uppercut launch remains active")
			if index < 2:
				animations.seek(animations.current_animation_length - 0.01, true)
				player.combat_controller.request_punch()
				check(player.combat_controller.is_next_punch_queued, "Combo queues next clip")
				animations.advance(0.1)
				player.combat_controller.update_punch_momentum(player, 0.01, 10)
		animations.advance(2.0)
		player.combat_controller.update_punch_momentum(player, 0.01, 10)
		check(not player.combat_controller.is_action_locked(), "Combo unlocks after finisher")
	print("PASS: authored combo import, poses, originals, switching, sequencing and uppercut launch" if failures == 0 else "FAIL: %d authored combo checks" % failures)
	world.free()
	quit(0 if failures == 0 else 1)
