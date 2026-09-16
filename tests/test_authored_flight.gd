extends SceneTree
var failures:=0
class TestInput extends Node:
	var snapshot:=PlayerInputSnapshot.new()
	func capture() -> PlayerInputSnapshot: return snapshot
	func is_sprint_requested() -> bool: return snapshot.sprint_pressed
	func reset() -> void: snapshot=PlayerInputSnapshot.new()
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var world:=Node3D.new(); root.add_child(world)
	var player: PlayerCharacter=load("res://scenes/player.tscn").instantiate(); world.add_child(player); player.set_physics_process(false)
	var controller:=player.animation_controller
	var animations:=player.character_animation_player
	var skeleton:=player.superhero_character.find_child("GeneralSkeleton",true,false) as Skeleton3D
	check(PlayerAnimationController.FLIGHT_LIBRARY.get_animation_list().size()==3,"Exactly three authored clips")
	check(not animations.has_animation("Flying"),"Legacy Mixamo flight removed from player")
	for clip in PlayerAnimationController.FLIGHT_ANIMATIONS:
		var animation:=animations.get_animation(clip)
		check(animation!=null and animation.loop_mode==Animation.LOOP_LINEAR,"Seamless looping flight clip: "+clip)
		for track in animation.get_track_count():
			var path:=animation.track_get_path(track)
			var node:=animations.get_node(animations.root_node).get_node_or_null(NodePath(path.get_concatenated_names()))
			check(node==skeleton and skeleton.find_bone(path.get_subname(0))>=0,"Track resolves to original hero rig: "+str(path))
		animations.play(clip,0)
		var start: Array[Transform3D]=[]
		for time in [0.0,.5,1.0,animation.length]:
			animations.seek(time,true); skeleton.force_update_all_bone_transforms()
			var hips:=skeleton.get_bone_global_pose(skeleton.find_bone("Hips")).origin
			var head:=skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin
			check(hips.is_finite() and head.is_finite(),"Finite flight pose")
			check(skeleton.get_bone_pose_position(skeleton.find_bone("Root")).length()<.001,"Physics retains root motion")
			if clip=="Flight_Fast":
				check(head.z>hips.z+.45 and absf(head.y-hips.y)<.45,"Rocket torso is nearly horizontal, facing forward")
				for side in ["Left","Right"]:
					var hand:=skeleton.get_bone_global_pose(skeleton.find_bone(side+"Hand")).origin
					check(hand.distance_to(hips)<.5,"Fast-flight hands stay beside hips")
			else: check(head.y>hips.y+.5,"Hover and cruise preserve upright silhouette")
			for bone in skeleton.get_bone_count():
				var pose:=skeleton.get_bone_pose(bone)
				if time==0: start.append(pose)
				elif time==animation.length:
					check(pose.origin.distance_to(start[bone].origin)<.001,"Loop position joins")
					check(pose.basis.get_rotation_quaternion().angle_to(start[bone].basis.get_rotation_quaternion())<.002,"Loop rotation joins")
	for mode in range(3):
		controller.update_animation(true,false,false,false,Vector3.ZERO,false,false,false,mode>0,mode==2)
		check(animations.current_animation==PlayerAnimationController.FLIGHT_ANIMATIONS[mode],"Select correct flight mode")
	controller.update_animation(false,false,false,false,Vector3.ZERO,false,true,false,false)
	controller.update_animation(false,false,false,false,Vector3.ZERO,false,true,false,false)
	check(animations.has_animation("Idle") and animations.has_animation("Punch_01"),"Ground and combat clips preserved")
	# Drive the real character/state update, not just the animation selector.
	preload("res://tests/player_test_support.gd").unlock_current_powers(player)
	var input:=TestInput.new(); player.add_child(input); player.input_controller=input
	player.global_position=Vector3(0,100,0)
	player.state_machine.transition_to(&"FlyingState")
	player.velocity=Vector3.ZERO
	player._profiled_physics_process(.1)
	check(animations.current_animation=="Flight_Hover","No input selects hover through real player")
	for move in [Vector2(0,-1),Vector2(1,0),Vector2(0,1)]:
		input.snapshot.movement=move
		player._profiled_physics_process(.1)
		check(animations.current_animation=="Flight_Move","Any normal movement selects cruise")
	input.snapshot.movement=Vector2.ZERO; input.snapshot.jump_pressed=true
	for i in range(30): player._profiled_physics_process(1.0/60.0)
	check(animations.current_animation=="Flight_Move","Vertical movement selects cruise")
	check(player.superhero_character.global_basis.y.dot(Vector3.UP)>.95,"Slow vertical movement keeps model upright")
	input.snapshot.jump_pressed=false; input.snapshot.movement=Vector2(0,-1); input.snapshot.sprint_pressed=true
	player.stamina.restore_full()
	player._profiled_physics_process(.1)
	check(animations.current_animation=="Flight_Fast","Actual Shift boost selects rocket pose")
	player.abilities.set_unlocked(PlayerAbilities.FLIGHT_BOOST,false)
	player._profiled_physics_process(.1)
	check(animations.current_animation=="Flight_Move","Locked boost keeps cruise even with Shift held")
	player.flying_state.surge_remaining=.5
	player._profiled_physics_process(.1)
	check(animations.current_animation=="Flight_Fast","Existing flight surge uses rocket pose")
	world.free()
	print("AUTHORED_FLIGHT_PASS failures=",failures)
	quit(1 if failures else 0)
