extends SceneTree
## Exercise the actual Player scene, skin seams, legacy bone rests and tracks.
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var player: PlayerCharacter = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var animation := player.character_animation_player
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var skeleton: Skeleton3D = player.superhero_character.find_children("*", "Skeleton3D", true, false)[0]
	var original = load("res://assets/characters/Superhero-male/Superhero_Male_FullBody.gltf").instantiate()
	root.add_child(original)
	var reference: Skeleton3D = original.find_children("*", "Skeleton3D", true, false)[0]
	check(skeleton.get_bone_count() == 65, "All existing player bones retained")
	check(player.superhero_character.scene_file_path == "res://assets/characters/hero_starter_suit/hero_starter_suit_rigged.glb", "Player uses rigged superhero costume")
	for i in reference.get_bone_count():
		var name := reference.get_bone_name(i)
		var index := skeleton.find_bone(name)
		check(index >= 0, "Missing bone " + name)
		if index < 0: continue
		check(reference.get_bone_rest(i).is_equal_approx(skeleton.get_bone_rest(index)), "Rest changed: " + name)
		var parent := reference.get_bone_parent(i)
		var other_parent := skeleton.get_bone_parent(index)
		check((parent < 0 and other_parent < 0) or (parent >= 0 and other_parent >= 0 and reference.get_bone_name(parent) == skeleton.get_bone_name(other_parent)), "Hierarchy changed: " + name)
	var meshes := player.superhero_character.find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() == 1, "One skinned body, without duplicate hair shells")
	var mesh: MeshInstance3D = meshes[0]
	check(mesh.skin != null, "Mesh is bound to player rig")
	var triangle_count := 0
	for surface in mesh.mesh.get_surface_count():
		var arrays := mesh.mesh.surface_get_arrays(surface)
		triangle_count += arrays[Mesh.ARRAY_INDEX].size()/3
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per_vertex: int = weights.size()/vertices.size()
		check(per_vertex == 4, "Four-influence skin format")
		check(arrays[Mesh.ARRAY_TEX_UV].size() == vertices.size(), "UVs present")
		var seam_weights := {}
		for vertex in vertices.size():
			var total := 0.0
			var head_weight := 0.0
			var signature := {}
			for influence in per_vertex:
				var offset := vertex*per_vertex+influence
				check(is_finite(weights[offset]) and weights[offset] >= 0, "Finite nonnegative skin weight")
				total += weights[offset]
				var bind_index := bones[offset]
				var bone_name := mesh.skin.get_bind_name(bind_index)
				if bone_name.is_empty() and mesh.skin.get_bind_bone(bind_index) >= 0:
					bone_name = skeleton.get_bone_name(mesh.skin.get_bind_bone(bind_index))
				if bone_name == &"Head": head_weight += weights[offset]
				if weights[offset] > 0.00001: signature[bones[offset]] = weights[offset]
			check(absf(total-1.0) < 0.001, "Normalized vertex weights")
			var point := vertices[vertex]
			if point.y >= 1.54 and absf(point.x) < 0.17:
				check(is_equal_approx(head_weight, 1.0), "Entire chin and face must follow Head rigidly")
			if seam_weights.has(vertices[vertex]):
				check(seam_weights[vertices[vertex]] == signature, "UV seam skin weights match")
			else: seam_weights[vertices[vertex]] = signature
	check(triangle_count == 2172, "Suit retains its original triangle count")
	check(not player.get_node("CharacterHair").enabled, "Integrated hair accessory setting")
	var reference_player := AnimationPlayer.new()
	original.add_child(reference_player)
	reference_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var clips := ["Idle", "Run", "Sprint", "Jump_Charge", "Jump_Start", "Jump_Fall", "Landing", "Flight_Hover", "Flight_Move", "Flight_Fast", "Punch_01", "AuthoredCombo/Hero_Hold", "AuthoredCombo/Hero_Cross", "Death"]
	var library := AnimationLibrary.new()
	for clip in clips:
		check(animation.has_animation(clip), "Existing animation loaded: " + clip)
		if not animation.has_animation(clip): continue
		var source := animation.get_animation(clip)
		for track in source.get_track_count():
			var path := source.track_get_path(track)
			var target := player.superhero_character.get_node_or_null(NodePath(path.get_concatenated_names()))
			check(target != null, "Animation target resolves: " + str(path))
			if target is Skeleton3D and path.get_subname_count() > 0:
				check(target.find_bone(path.get_subname(0)) >= 0, "Animation bone resolves")
		library.add_animation(clip.replace("/", "_"), source.duplicate(true))
	reference_player.add_animation_library("", library)
	for clip in clips:
		if not animation.has_animation(clip): continue
		animation.play(clip, 0)
		reference_player.play(clip.replace("/", "_"), 0)
		for fraction in [0.0, 0.25, 0.5, 0.75]:
			var time: float = animation.get_animation(clip).length * fraction
			animation.seek(time, true); animation.advance(0)
			reference_player.seek(time, true); reference_player.advance(0)
			skeleton.force_update_all_bone_transforms()
			reference.force_update_all_bone_transforms()
			for i in reference.get_bone_count():
				var index := skeleton.find_bone(reference.get_bone_name(i))
				if index >= 0: check(reference.get_bone_global_pose(i).is_equal_approx(skeleton.get_bone_global_pose(index)), "Animated pose differs: " + clip)
	print("MESHY_PLAYER_TESTS: %s | %d triangles | %d bones | %d clips, four samples each" % ["PASS" if failures == 0 else "FAIL", triangle_count, skeleton.get_bone_count(), clips.size()])
	player.free(); original.free()
	quit(0 if failures == 0 else 1)
