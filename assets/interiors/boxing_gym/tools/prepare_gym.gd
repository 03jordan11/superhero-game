extends SceneTree
## Offline preparation. Preserve placed nodes/materials; refresh only revised props.
const BASE := "res://assets/interiors/boxing_gym/"
const REFRESH := ["boxing_ring", "front_window", "bathroom_exterior", "back_door", "exit_sign"]
var materials := {}
var scenes := {}

func _initialize() -> void:
	prepare.call_deferred()

func v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])

func owned(parent: Node, child: Node, owner_node: Node) -> void:
	parent.add_child(child, true)
	child.owner = owner_node

func save_scene(node: Node, path: String) -> void:
	var packed := PackedScene.new()
	assert(packed.pack(node) == OK)
	assert(ResourceSaver.save(packed, path) == OK)

func count_triangles(node: Node) -> int:
	var count := 0
	var player := node.get_node_or_null("Player")
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if player != null and player.is_ancestor_of(mi): continue
		count += mi.mesh.get_faces().size() / 3
	return count

func reown(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		reown(child, owner_node)

func prepare_shelves() -> PackedScene:
	var path := BASE + "props/hideout_storage_rack.tscn"
	if FileAccess.file_exists(path): return load(path)
	var hideout := (load("res://assets/buildings/gas_station_hideout/gas_station_interior.tscn") as PackedScene).instantiate()
	var source := hideout.get_node("Model/Props/StorageRack1") as Node3D
	var rack := Node3D.new()
	rack.name = "HideoutStorageRack"
	for child: Node in source.get_children():
		if String(child.name).begins_with("Rack1Crate"):
			var box := child.duplicate() as Node3D
			var placement := box.transform
			box.transform = Transform3D.IDENTITY
			reown(box, box)
			var box_path := BASE + "props/hideout_" + String(child.name).to_snake_case() + ".tscn"
			save_scene(box, box_path)
			box.free()
			var instance := (load(box_path) as PackedScene).instantiate() as Node3D
			instance.transform = placement
			owned(rack, instance, rack)
		else:
			var copy := child.duplicate()
			owned(rack, copy, rack)
			reown(copy, rack)
	rack.set_meta("rendered_triangles", count_triangles(rack))
	save_scene(rack, path)
	rack.free()
	hideout.free()
	return load(path)

func prepare() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "source/manifest.json"))
	DirAccess.make_dir_recursive_absolute(BASE + "materials")
	for key: String in data.materials:
		var path := BASE + "materials/" + key.to_snake_case() + ".tres"
		if FileAccess.file_exists(path):
			materials[key] = load(path)
			continue
		var spec: Dictionary = data.materials[key]
		var mat := StandardMaterial3D.new()
		mat.resource_name = key
		mat.albedo_color = Color(spec.color[0], spec.color[1], spec.color[2])
		mat.roughness = .48 if spec.metallic else .85
		mat.metallic = spec.metallic
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if not spec.texture.is_empty():
			mat.albedo_texture = load("res://" + spec.texture)
		if spec.emission:
			mat.emission_enabled = true
			mat.emission = mat.albedo_color
			mat.emission_energy_multiplier = spec.emission
		assert(ResourceSaver.save(mat, path, ResourceSaver.FLAG_CHANGE_PATH) == OK)
		mat.take_over_path(path)
		materials[key] = mat
	for key: String in data.assets:
		if FileAccess.file_exists(BASE + "props/" + key + ".tscn") and key not in REFRESH:
			scenes[key] = load(BASE + "props/" + key + ".tscn")
			continue
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		assert(doc.append_from_file(BASE + "source/" + key + ".glb", state) == OK)
		var imported := doc.generate_scene(state)
		var prop := Node3D.new()
		prop.name = key.to_pascal_case()
		for mi: MeshInstance3D in imported.find_children("*", "MeshInstance3D", true, false):
			var mesh := mi.mesh as ArrayMesh
			for surface in mesh.get_surface_count():
				mesh.surface_set_material(surface, materials[mesh.surface_get_material(surface).resource_name])
			var path := BASE + "meshes/" + mi.name + ".res"
			assert(ResourceSaver.save(mesh, path, ResourceSaver.FLAG_CHANGE_PATH) == OK)
			mesh.take_over_path(path)
			var instance := MeshInstance3D.new()
			instance.name = mi.name
			instance.mesh = mesh
			instance.transform = mi.transform
			owned(prop, instance, prop)
		if not data.assets[key].collision.is_empty():
			var body := StaticBody3D.new()
			body.name = "Collision"
			owned(prop, body, prop)
			for item: Dictionary in data.assets[key].collision:
				var shape := CollisionShape3D.new()
				if item.has("points"):
					var convex := ConvexPolygonShape3D.new()
					var points := PackedVector3Array()
					for point: Array in item.points: points.append(v(point))
					convex.points = points
					shape.shape = convex
				else:
					var box := BoxShape3D.new()
					box.size = v(item.size)
					shape.shape = box
					shape.position = v(item.center)
				owned(body, shape, prop)
		if key in ["pendant", "wall_light"]:
			var lamp := OmniLight3D.new()
			lamp.name = "Light"
			lamp.position = Vector3(0,-1,0) if key == "pendant" else Vector3(0,0,.35)
			lamp.light_color = Color(1,.83,.63)
			lamp.light_energy = 2.8 if key == "pendant" else 1.5
			lamp.omni_range = 10 if key == "pendant" else 6
			lamp.omni_attenuation = .7
			lamp.shadow_enabled = key == "pendant"
			owned(prop, lamp, prop)
		prop.set_meta("rendered_triangles", count_triangles(prop))
		save_scene(prop, BASE + "props/" + key + ".tscn")
		scenes[key] = load(BASE + "props/" + key + ".tscn")
		prop.free()
		imported.free()
	var shelf_scene := prepare_shelves()
	var gym := (load(BASE + "boxing_gym.tscn") as PackedScene).instantiate() as Node3D if FileAccess.file_exists(BASE + "boxing_gym.tscn") else Node3D.new()
	gym.name = "BoxingGym"
	gym.set_script(load(BASE + "boxing_gym.gd"))
	var categories := {}
	for key: String in ["Architecture", "Training", "Props", "Lighting"]:
		if gym.has_node(key):
			categories[key] = gym.get_node(key)
			continue
		var group := Node3D.new()
		group.name = key
		owned(gym, group, gym)
		categories[key] = group
	for spec: Dictionary in data.placements:
		if categories[spec.category].has_node(spec.name): continue
		var node := (scenes[spec.kind] as PackedScene).instantiate() as Node3D
		node.name = spec.name
		node.position = v(spec.position)
		node.rotation.y = spec.yaw
		owned(categories[spec.category], node, gym)
	var env := WorldEnvironment.new()
	env.name = "WorldEnvironment"
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.055,.07,.085)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(.60,.68,.76)
	env.environment.ambient_light_energy = .45
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.ssao_enabled = true
	env.environment.ssao_radius = 1.2
	env.environment.ssao_intensity = 1.5
	env.environment.glow_enabled = true
	if gym.has_node("WorldEnvironment"): env.free()
	else: owned(gym, env, gym)
	for spec: Array in [["PlayerSpawn", Vector3(0,1.05,8.3)], ["RingSpawn", Vector3(0,2.05,1)], ["OpponentSpawn", Vector3(0,2.05,-1)]]:
		if gym.has_node(spec[0]): continue
		var marker := Marker3D.new()
		marker.name = spec[0]
		marker.position = spec[1]
		owned(gym, marker, gym)
	for spec: Array in [["StorageShelvesLeft", Vector3(-6.65,0,-10.2), PI/2], ["StorageShelvesRight", Vector3(11.35,0,-4.5), 0.0]]:
		if gym.has_node("Props/" + spec[0]): continue
		var shelf := shelf_scene.instantiate() as Node3D
		shelf.name = spec[0]
		shelf.position = spec[1]
		shelf.rotation.y = spec[2]
		owned(categories.Props, shelf, gym)
	if not gym.has_node("Player"):
		var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Node3D
		player.name = "Player"
		player.position = Vector3(0,1.05,9.1)
		owned(gym, player, gym)
	if not gym.has_node("Training/RingAccess"):
		var access := Node3D.new()
		access.name = "RingAccess"
		access.set_script(load(BASE + "ring_access.gd"))
		owned(categories.Training, access, gym)
		var label := Label3D.new()
		label.name = "Prompt"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 32
		label.pixel_size = .002
		label.visible = false
		owned(access, label, gym)
	# Compact interaction labels stay readable without covering the ring.
	gym.get_node("Training/RingAccess/Prompt").font_size = 32
	gym.get_node("Training/RingAccess/Prompt").pixel_size = .002
	if not gym.get_meta("playable_revision", false):
		gym.get_node("PlayerSpawn").position = Vector3(0,1.05,9.1)
		gym.get_node("Training/RingSteps").position = Vector3(-2.2,0,4.7)
		gym.get_node("RingSpawn").position = Vector3(-2.2,2.05,3.2)
		gym.set_meta("playable_revision", true)
	var audit: Array = []
	for category: String in categories:
		for piece: Node3D in categories[category].get_children():
			var triangles := count_triangles(piece)
			if triangles == 0: continue
			piece.set_meta("rendered_triangles", triangles)
			audit.append({"node":category+"/"+piece.name,"scene":piece.scene_file_path,"triangles":triangles})
	var total := count_triangles(gym)
	assert(total <= 50000, "Complete interior exceeds user budget")
	gym.set_meta("rendered_triangles", total)
	gym.set_meta("ring_clear_width_metres", 6.1)
	save_scene(gym, BASE + "boxing_gym.tscn")
	var output := FileAccess.open(BASE + "TRIANGLE_AUDIT.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"complete_interior_triangles":total,"limit":50000,"counts_each_placed_instance":true,"excludes":"player character, interaction UI and non-rendered collision","placements":audit},"\t")+"\n")
	gym.free()
	print("BOXING_GYM_PREPARED actual_imported_triangles=",total," props=",data.placements.size())
	quit()
