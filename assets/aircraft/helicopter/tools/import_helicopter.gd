extends SceneTree
const BASE := "res://assets/aircraft/helicopter/"
func v3(p: Array) -> Vector3: return Vector3(p[0],p[1],p[2])
func owned(parent: Node, child: Node, scene: Node) -> void:
	parent.add_child(child)
	child.owner = scene
func _initialize() -> void:
	call_deferred("build")
func build() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/helicopter/mesh_data.json"))
	for name in data.liveries:
		var image := Image.load_from_file(BASE+"textures/"+name+".png")
		image.generate_mipmaps()
		var texture := ImageTexture.create_from_image(image)
		assert(ResourceSaver.save(texture,BASE+"textures/"+name+".res")==OK)
		texture.take_over_path(BASE+"textures/"+name+".res")
		var mat := StandardMaterial3D.new()
		mat.resource_name = name
		mat.albedo_texture = texture
		mat.roughness = 0.65
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		assert(ResourceSaver.save(mat,BASE+"materials/"+name+".tres")==OK)
		mat.take_over_path(BASE+"materials/"+name+".tres")
	var scene := Node3D.new()
	scene.name = "UtilityHelicopter"
	scene.set_script(load(BASE+"helicopter.gd"))
	var total := 0
	for part_name in data.parts:
		var row: Dictionary = data.parts[part_name]
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var uvs := PackedVector2Array()
		for p in row.vertices: vertices.append(v3(p))
		for p in row.normals: normals.append(v3(p))
		for p in row.uv: uvs.append(Vector2(p[0],p[1]))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0,load(BASE+"materials/forest_cream.tres"))
		assert(ResourceSaver.save(mesh,BASE+"meshes/"+part_name.to_snake_case()+".res")==OK)
		mesh.take_over_path(BASE+"meshes/"+part_name.to_snake_case()+".res")
		var node := MeshInstance3D.new()
		node.name = part_name
		node.mesh = mesh
		if part_name == "Body": owned(scene,node,scene)
		else:
			var pivot := Node3D.new()
			pivot.name = part_name+"Pivot"
			pivot.position = v3(data.pivots[part_name])
			owned(scene,pivot,scene)
			owned(pivot,node,scene)
		total += mesh.get_faces().size()/3
	var mounts := Node3D.new()
	mounts.name = "LightMounts"
	owned(scene,mounts,scene)
	for entry in [["PortRed",Vector3(-1.37,2,.98)],["StarboardGreen",Vector3(1.37,2,.98)],["TailWhite",Vector3(0,3.08,8.13)],["TopBeacon",Vector3(0,3.72,1.1)],["LandingLight",Vector3(0,1.54,-3.65)]]:
		var marker := Marker3D.new()
		marker.name = entry[0]
		marker.position = entry[1]
		owned(mounts,marker,scene)
	var collision := StaticBody3D.new()
	collision.name = "ParkedCollision"
	collision.collision_layer = 0
	collision.collision_mask = 0
	owned(scene,collision,scene)
	# Convex parts use the actual Blender geometry; excludes visual panes and rotors.
	# Cabin hull is deliberately solid; skids/boom/fin use separate narrow volumes.
	var source := JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/helicopter/collision_data.json")) as Array
	for i in source.size():
		var shape := ConvexPolygonShape3D.new()
		var points := PackedVector3Array()
		for p in source[i]: points.append(v3(p))
		shape.points = points
		var c := CollisionShape3D.new()
		c.name = "Solid%d" % i
		c.shape = shape
		owned(collision,c,scene)
	var packed := PackedScene.new()
	assert(packed.pack(scene)==OK)
	assert(ResourceSaver.save(packed,BASE+"helicopter.tscn")==OK)
	scene.free()
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	assert(doc.append_from_file(BASE+"helicopter.glb",state)==OK)
	var glb := doc.generate_scene(state)
	var exported := 0
	for node in glb.find_children("*","MeshInstance3D",true,false): exported += node.mesh.get_faces().size()/3
	glb.free()
	assert(total==exported and total<6000)
	FileAccess.open(BASE+"triangle_audit.json",FileAccess.WRITE).store_string(JSON.stringify({"godot_triangles":total,"glb_triangles":exported,"limit":6000,"rotors_included":true,"collision_excluded":true},"\t"))
	print("HELICOPTER_IMPORT_PASS triangles=",total)
	quit()
