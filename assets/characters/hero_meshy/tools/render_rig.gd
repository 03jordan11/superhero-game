extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/hero_meshy")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1200, 1200)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene = load("res://scenes/previews/meshy_rig_preview.tscn").instantiate()
	viewport.add_child(scene)
	scene.playing = false
	scene.set_process(false)
	for clip in ["Idle", "Run", "Sprint", "Jump_Charge", "Jump_Start", "Landing", "Flight_Hover", "Flight_Fast", "Punch_01", "AuthoredCombo/Hero_Hold"]:
		scene.select_clip(clip)
		scene.elapsed = scene.animation.get_animation(clip).length * 0.35
		scene.pose()
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://artifacts/hero_meshy/" + clip.replace("/", "_") + ".png")
	var skeleton: Skeleton3D = scene.player.superhero_character.find_children("*", "Skeleton3D", true, false)[0]
	scene.canvas.hide()
	for clip in ["Idle", "AuthoredCombo/Hero_Hold", "Sprint"]:
		scene.select_clip(clip)
		scene.elapsed = scene.animation.get_animation(clip).length * 0.35
		scene.pose()
		await process_frame
		for hand in ["LeftHand", "RightHand"]:
			scene.focus = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone(hand)).origin)
			scene.distance = 0.65
			scene.yaw = 1.0 if hand == "LeftHand" else -1.0
			scene.pitch = 0.25
			scene.update_camera()
			for frame in 3: await process_frame
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png("res://artifacts/hero_meshy/"+clip.replace("/", "_")+"_"+hand+".png")
	for clip in ["Idle", "Sprint", "Jump_Charge", "Flight_Hover"]:
		scene.select_clip(clip)
		scene.elapsed = scene.animation.get_animation(clip).length * 0.35
		scene.pose()
		await process_frame
		scene.focus = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin) + Vector3(0, 0.055, 0)
		scene.distance = 0.85
		scene.yaw = 1.1
		scene.pitch = 0.05
		scene.update_camera()
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://artifacts/hero_meshy/Chin_"+clip+".png")
	scene.select_clip("Idle")
	scene.elapsed = 0.5
	scene.pose()
	scene.focus = Vector3(0, 1.35, 0)
	scene.distance = 1.6
	scene.yaw = PI/2
	scene.pitch = 0.0
	scene.update_camera()
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://artifacts/hero_meshy/Chest_profile.png")
	print("MESHY_RIG_RENDER_PASS")
	quit()
