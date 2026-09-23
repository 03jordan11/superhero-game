extends SceneTree
## Offline bake: shared materials, six mesh groups, simple static collision.
const FOLDER := "res://assets/buildings/parking_garage/"
var materials: Dictionary = {}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER + "baked")
	DirAccess.make_dir_recursive_absolute(FOLDER + "materials")
	for spec: Array in [
		["Concrete", Color.WHITE, "concrete"], ["Asphalt", Color.WHITE, "asphalt"],
		["Paint", Color(.86,.85,.76), ""], ["Teal", Color(.035,.18,.21), ""],
		["Yellow", Color(.87,.57,.13), ""], ["Signs", Color(.86,.85,.76), ""]]:
		var mat := StandardMaterial3D.new()
		mat.resource_name = "Garage" + spec[0]
		mat.albedo_color = spec[1]
		mat.roughness = .87
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if not spec[2].is_empty():
			mat.albedo_texture = load(FOLDER + "textures/" + spec[2] + ".png")
		assert(ResourceSaver.save(mat, FOLDER + "materials/" + spec[0].to_lower() + ".tres", ResourceSaver.FLAG_CHANGE_PATH) == OK)
		mat.take_over_path(FOLDER + "materials/" + spec[0].to_lower() + ".tres")
		materials[mat.resource_name] = mat
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string(FOLDER + "source/manifest.json"))
	var report: Array = []
	for entry: Dictionary in manifest:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		assert(doc.append_from_file(FOLDER + "source/" + entry.name + ".glb", state) == OK)
		var imported := doc.generate_scene(state)
		var garage := Node3D.new()
		garage.name = "GarageGeometry"
		var triangle_count := 0
		for node: Node in imported.find_children("*", "MeshInstance3D", true, false):
			var mesh_node := node as MeshInstance3D
			var mesh := mesh_node.mesh as ArrayMesh
			for surface in mesh.get_surface_count():
				var old_material := mesh.surface_get_material(surface)
				assert(materials.has(old_material.resource_name), old_material.resource_name)
				mesh.surface_set_material(surface, materials[old_material.resource_name])
			triangle_count += mesh.get_faces().size() / 3
			var path: String = FOLDER + "baked/" + entry.name + "_" + node.name + ".res"
			assert(ResourceSaver.save(mesh, path, ResourceSaver.FLAG_CHANGE_PATH) == OK)
			mesh.take_over_path(path)
			var instance := MeshInstance3D.new()
			instance.mesh = mesh
			instance.name = node.name
			garage.add_child(instance)
			instance.transform = mesh_node.transform
			instance.owner = garage
		assert(triangle_count <= 10000, "Garage over POI triangle budget: " + entry.name)
		var body := StaticBody3D.new()
		body.name = "StructureCollision"
		garage.add_child(body)
		body.owner = garage
		for item: Dictionary in entry.collision:
			var shape := CollisionShape3D.new()
			if item.has("points"):
				var convex := ConvexPolygonShape3D.new()
				var points := PackedVector3Array()
				for p: Array in item.points:
					points.append(Vector3(p[0],p[1],p[2]))
				convex.points = points
				shape.shape = convex
			else:
				var box := BoxShape3D.new()
				box.size = Vector3(item.size[0],item.size[1],item.size[2])
				shape.shape = box
				shape.position = Vector3(item.center[0],item.center[1],item.center[2])
			body.add_child(shape, true)
			shape.owner = garage
		garage.set_meta("rendered_triangles", triangle_count)
		garage.set_meta("width_metres", entry.width)
		garage.set_meta("parking_levels", entry.floors)
		garage.set_meta("entrance_x", entry.entrance_x)
		var packed := PackedScene.new()
		assert(packed.pack(garage) == OK)
		assert(ResourceSaver.save(packed, FOLDER + "baked/" + entry.name + ".tscn") == OK)
		report.append({"configuration":entry.name,"triangles":triangle_count,"collision_shapes":entry.collision.size()})
		print("GARAGE_BAKED ", entry.name, " triangles=", triangle_count)
		garage.free()
		imported.free()
	var audit := FileAccess.open(FOLDER + "TRIANGLE_AUDIT.json", FileAccess.WRITE)
	audit.store_string(JSON.stringify(report,"\t") + "\n")
	quit()
