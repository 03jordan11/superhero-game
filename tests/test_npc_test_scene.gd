extends SceneTree

var failures: int = 0
var capture: bool = "--capture" in OS.get_cmdline_user_args()


func _initialize() -> void:
	run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func model_bounds(model: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var box := mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


func screenshot(filename: String) -> void:
	if not capture:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/hostile_mesh_audit/" + filename + ".png")


func run() -> void:
	var room = load("res://scenes/NPCTestScene.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	await process_frame
	room.select_clip(room.REST_POSE)
	check(room.actors.size() == 8, "Hero, three hostiles, and four civilian previews are registered")
	check(room.get_node("Friendlies").get_child_count() == 4, "All four civilians are in the friendly group")
	var heights := [1.8131934, 1.80, 2.30, 1.80, 1.78, 1.80, 1.72, 1.68]
	for i in room.actors.size():
		var model: Node3D = room.actors[i].get_node("Model")
		var box := model_bounds(model)
		check(absf(box.size.y - heights[i]) < 0.005, "Correct imported height for " + str(room.actors[i].name))
		check(absf(box.position.y) < 0.005, "Feet align with floor for " + str(room.actors[i].name))
		var rigs := model.find_children("*", "Skeleton3D", true, false)
		check(rigs.size() == 1, "Every preview character has one rig: " + str(room.actors[i].name))
	check(room.animations.size() == 8, "Hero, three hostiles, and four civilians have animation players")
	for index in range(1, 9):
		room.picker.item_selected.emit(index)
		check(room.selected_index == index, "Picker focuses the requested actor")
		check(room.camera.global_position.distance_to(room.focus) < 3.5, "Character inspection zoom works")
		room.get_node("CanvasLayer/Panel/Controls/Views/Hands").pressed.emit()
		check(is_equal_approx(room.camera.global_position.distance_to(room.focus), room.hand_distance), "Hand inspection zoom works")
	room.get_node("CanvasLayer/Panel/Controls/Views/Back").pressed.emit()
	check(room.camera.position.z < room.focus.z, "Back view goes behind the actor")
	room.get_node("CanvasLayer/Panel/Controls/Views/Reset").pressed.emit()
	check(room.selected_index == 0 and is_equal_approx(room.distance, room.overview_distance), "Reset restores overview")
	room.show_lineup(true)
	check(is_equal_approx(room.focus.x, 12.0), "Civilian lineup is centered on the four new models")
	await screenshot("civilian_lineup")
	for index in range(5, 9):
		room.select_actor(index)
		await screenshot("civilian_preview_" + str(index))
	room.select_actor(0)
	# One brief smoke pass, not an animation-quality or deformation test suite.
	for clip in ["UAL1/Idle", "UAL1/Walk", "Fighting/Punch_01"]:
		check(room.clips.has(clip), "Expected review clip is available: " + clip)
		room.select_clip(clip)
		room.scrub_to(0.4)
		for skeleton: Skeleton3D in room.skeletons:
			var arm := skeleton.find_bone("LeftUpperArm")
			check(arm >= 0 and skeleton.get_bone_pose(arm).is_finite(), "Animation drives a valid humanoid pose")
			if arm >= 0:
				check(not skeleton.get_bone_pose_rotation(arm).is_equal_approx(Quaternion.IDENTITY), "Animation moves the upper arm out of rest pose")
	room.select_clip("UAL1/Walk")
	room.scrub_to(0.25)
	await screenshot("npc_rig_walk")
	room.select_clip(room.REST_POSE)
	room.select_actor(3)
	room.select_clip("Fighting/Punch_01")
	room.scrub_to(0.4)
	await screenshot("npc_rig_brute_punch")
	room.toggle_playback()
	await process_frame
	check(room.playing, "Playback resumes after scrubbing")
	room.free()
	print("NPC_TEST_SCENE: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
