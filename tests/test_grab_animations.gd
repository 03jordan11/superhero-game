extends SceneTree
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func run() -> void:
	var preview=load("res://scenes/previews/grab_animation_preview.tscn").instantiate()
	root.add_child(preview); current_scene=preview; preview.set_process(false)
	var library: AnimationLibrary=preview.LIBRARY
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animations/authored-combo/grab_manifest.json"))
	check(library.get_animation_list().size()==32,"Three original clips, 26 paired grab clips, and three charged punch clips")
	var skeletons: Array[Skeleton3D]=[]
	for role in ["Hero","Victim"]:
		skeletons.append(preview.get_node(role).find_child("GeneralSkeleton",true,false))
	for clip in manifest.clips:
		check(library.has_animation(clip.name),"Imported clip exists: "+clip.name)
		if not library.has_animation(clip.name): continue
		var animation:=library.get_animation(clip.name)
		check(absf(animation.length-clip.duration)<.02,"Duration preserved: "+clip.name)
		check(animation.loop_mode==(Animation.LOOP_LINEAR if clip.loop else Animation.LOOP_NONE),"Correct loop mode: "+clip.name)
		for index in animation.get_track_count():
			var path:=animation.track_get_path(index)
			check(preview.players[0].get_node(preview.players[0].root_node).get_node_or_null(NodePath(path.get_concatenated_names()))==skeletons[0],"Track resolves on shared rig: "+str(path))
			if path.get_subname_count()>0: check(skeletons[0].find_bone(path.get_subname(0))>=0,"Mapped bone exists")
	for pair in preview.pairs:
		preview.select_pair(pair); preview.playing=false
		var data: Dictionary=preview.clip_data[pair]
		var starts: Array=[]
		for fraction in [0.0,.2,.4,.6,.8,1.0]:
			preview.elapsed=data.duration*fraction; preview._pose()
			for s in skeletons:
				s.force_update_all_bone_transforms()
				check(s.get_bone_pose_position(s.find_bone("Root")).length()<.001,"No actor-root movement: "+pair)
				for b in s.get_bone_count():
					check(s.get_bone_global_pose(b).is_finite(),"Finite pose: "+pair)
			var poses: Array=[]
			for s in skeletons:
				for b in s.get_bone_count(): poses.append(s.get_bone_pose(b))
			if fraction==0: starts=poses
			if fraction==1 and data.loop:
				for i in poses.size():
					check(poses[i].origin.distance_to(starts[i].origin)<.002 and poses[i].basis.get_rotation_quaternion().angle_to(starts[i].basis.get_rotation_quaternion())<.02,"Loop seam: "+pair)
			if pair in ["Hold","CarryWalk","CarryRun","CarryFlightHover","CarryFlightMove","CarryFlightFast","ThrowHold"]:
				var hand:=skeletons[0].get_bone_global_pose(skeletons[0].find_bone("RightHand")).origin
				var neck:=skeletons[1].get_bone_global_pose(skeletons[1].find_bone("Neck")).origin
				check(hand.distance_to(neck)<.18,"Paired throat contact: "+pair)
		if pair.begins_with("Slam"):
			preview.elapsed=data.events.impact; preview._pose()
			skeletons[1].force_update_all_bone_transforms()
			var hips:=skeletons[1].get_bone_global_pose(skeletons[1].find_bone("Hips")).origin
			print("SLAM_HEIGHT ",pair," ",hips.y)
			check(hips.y<.35,"Slam pelvis reaches ground contact: "+pair)
	print("GRAB_ANIMATIONS_PASS failures=",failures)
	preview.free(); quit(1 if failures else 0)
