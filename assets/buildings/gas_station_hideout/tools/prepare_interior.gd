extends SceneTree
## Update the existing room, preserving custom placement, doors and lighting.
const BASE := "res://assets/buildings/gas_station_hideout/"
const MESH_DIR := BASE + "interior_meshes/"

func _initialize() -> void:
	prepare.call_deferred()

func prepare() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "interior_manifest.json"))
	assert(data.has("props"), "Rebuild the separated Blender export first")
	var packed := load(BASE + "gas_station_interior.tscn") as PackedScene
	assert(packed != null, "An existing room is required")
	var room := packed.instantiate() as Node3D
	root.add_child(room)
	var imported := (load(BASE + "gas_station_interior.glb") as PackedScene).instantiate()
	var sources := {}
	DirAccess.make_dir_recursive_absolute(MESH_DIR)
	for part: MeshInstance3D in imported.find_children("*", "MeshInstance3D", true, false):
		var path := MESH_DIR + String(part.name) + ".res"
		assert(ResourceSaver.save(part.mesh, path) == OK)
		sources[String(part.name)] = load(path)
	var first_conversion := not room.has_meta("editable_interior_props")
	if first_conversion:
		convert_room(room, data, sources)
	else:
		# Refresh geometry only; preserve edited transforms, parenting and collision.
		for mesh: MeshInstance3D in room.get_node("Model").find_children("*", "MeshInstance3D", true, false):
			var source_name: String = mesh.get_meta("interior_mesh", "")
			if sources.has(source_name): mesh.mesh = sources[source_name]
	room.set_meta("editable_interior_props", true)
	room.set_meta("rendered_triangles", count_triangles(room))
	var result := PackedScene.new()
	assert(result.pack(room) == OK)
	assert(ResourceSaver.save(result, BASE + "gas_station_interior.tscn") == OK)
	print("EDITABLE_INTERIOR_PREPARED props=", data.props.size(), " triangles=", count_triangles(room), " converted=", first_conversion)
	imported.free()
	room.free()
	quit()

func convert_room(room: Node3D, data: Dictionary, sources: Dictionary) -> void:
	var old_model := room.get_node("Model") as Node3D
	var old_transform := old_model.transform
	old_model.free()
	var model := Node3D.new()
	model.name = "Model"
	add_owned(room, model, room)
	model.transform = old_transform
	var shell := Node3D.new()
	shell.name = "Shell"
	add_owned(model, shell, room)
	var props_root := Node3D.new()
	props_root.name = "Props"
	add_owned(model, props_root, room)
	var prop_nodes := {}
	for source_name: String in sources:
		if data.props.has(source_name): continue
		var mesh := mesh_node(source_name, sources[source_name])
		mesh.name = source_name
		add_owned(shell, mesh, room)
	for prop_name: String in data.props:
		var definition: Dictionary = data.props[prop_name]
		var node := Node3D.new()
		node.name = prop_name
		node.set_meta("interior_prop", prop_name)
		node.set_meta("_edit_group_", true)
		var parent: Node3D = props_root if definition.parent == null else prop_nodes[String(definition.parent)]
		add_owned(parent, node, room)
		var pivot := vector(definition.pivot)
		node.position = pivot if definition.parent == null else pivot - vector(data.props[String(definition.parent)].pivot)
		prop_nodes[prop_name] = node
		add_owned(node, mesh_node(prop_name, sources[prop_name]), room)
		if definition.has("light_node"):
			var lamp := room.get_node_or_null(String(definition.light_node)) as Node3D
			if lamp != null:
				lamp.reparent(node, true)
				lamp.owner = room
	# Reparent original collision shapes so no invisible obstacles remain behind.
	var old_collision := room.get_node("RoomCollision")
	for entry: Dictionary in data.collision_boxes:
		if not entry.has("prop"): continue
		var node: Node3D = prop_nodes[String(entry.prop)]
		var body := StaticBody3D.new()
		body.name = "Collision"
		add_owned(node, body, room)
		var original: CollisionShape3D = null
		for shape: CollisionShape3D in old_collision.get_children():
			if shape.position.is_equal_approx(vector(entry.center)):
				original = shape
				break
		assert(original != null, "Original prop collision missing: " + String(entry.name))
		original.reparent(body, true)
		original.owner = room
		original.name = "Shape"
	# One-time layout adjustment; preserve the user's exact machine transform.
	if room.has_node("power_machine"):
		prop_nodes.Workbench.position.x += 3.3
		prop_nodes.Toolboard.position.x += 3.3

func mesh_node(source_name: String, mesh: Mesh) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = "Mesh"
	node.mesh = mesh
	node.set_meta("interior_mesh", source_name)
	return node

func add_owned(parent: Node, child: Node, owner_node: Node) -> void:
	parent.add_child(child)
	child.owner = owner_node

func vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

func count_triangles(node: Node) -> int:
	var triangles := 0
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var indices: int = mesh.mesh.surface_get_array_index_len(surface)
			triangles += int((indices if indices else mesh.mesh.surface_get_array_len(surface)) / 3)
	return triangles

