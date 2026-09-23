extends SceneTree
## Offline asset preparation; placeable exterior with its front-door interaction.
const BASE := "res://assets/buildings/boxing_gym/"
var materials := {}
var parts := {}

func _initialize() -> void:
	prepare.call_deferred()

func v(a: Array) -> Vector3:
	return Vector3(a[0],a[1],a[2])

func owned(parent: Node, child: Node, owner_node: Node) -> void:
	parent.add_child(child,true)
	child.owner = owner_node

func save_scene(node: Node, path: String) -> void:
	var packed := PackedScene.new()
	assert(packed.pack(node) == OK)
	assert(ResourceSaver.save(packed,path) == OK)

func triangles(node: Node) -> int:
	var result := 0
	for mi: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
		result += mi.mesh.get_faces().size()/3
	return result

func prepare() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE+"source/manifest.json"))
	DirAccess.make_dir_recursive_absolute(BASE+"materials")
	for key: String in data.materials:
		var spec: Dictionary = data.materials[key]
		var mat := StandardMaterial3D.new()
		mat.resource_name = key
		mat.albedo_color = Color.from_string("#"+spec.color,Color.WHITE)
		mat.roughness = spec.roughness
		mat.metallic = spec.metallic
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if not spec.texture.is_empty(): mat.albedo_texture = load(BASE+spec.texture)
		if spec.emission:
			mat.emission_enabled = true
			mat.emission = mat.albedo_color
			mat.emission_energy_multiplier = spec.emission
		var path := BASE+"materials/"+key.to_snake_case()+".tres"
		assert(ResourceSaver.save(mat,path,ResourceSaver.FLAG_CHANGE_PATH) == OK)
		mat.take_over_path(path)
		materials[key] = mat
	for key: String in data.parts:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_file(BASE+"source/"+key+".glb",state) == OK)
		var imported := document.generate_scene(state)
		var part := Node3D.new()
		part.name = key.to_pascal_case()
		for mi: MeshInstance3D in imported.find_children("*","MeshInstance3D",true,false):
			var mesh := mi.mesh as ArrayMesh
			for surface in mesh.get_surface_count():
				mesh.surface_set_material(surface,materials[mesh.surface_get_material(surface).resource_name])
			var path := BASE+"meshes/"+mi.name+".res"
			assert(ResourceSaver.save(mesh,path,ResourceSaver.FLAG_CHANGE_PATH) == OK)
			mesh.take_over_path(path)
			var instance := MeshInstance3D.new()
			instance.name = mi.name
			instance.mesh = mesh
			if key == "roof_unit":
				instance.visibility_range_end = 100.0
			instance.transform = mi.transform
			owned(part,instance,part)
		if not data.parts[key].collision.is_empty():
			var body := StaticBody3D.new()
			body.name = "Collision"
			owned(part,body,part)
			for box: Dictionary in data.parts[key].collision:
				var shape := BoxShape3D.new()
				shape.size = v(box.size)
				var collision := CollisionShape3D.new()
				collision.shape = shape
				collision.position = v(box.center)
				owned(body,collision,part)
		if key == "wall_lamp":
			var light := OmniLight3D.new()
			light.name = "WarmLight"
			light.position = Vector3(0,0,.3)
			light.light_color = Color("e4c58a")
			light.light_energy = .65
			light.omni_range = 4
			light.shadow_enabled = false
			owned(part,light,part)
		part.set_meta("rendered_triangles",triangles(part))
		save_scene(part,BASE+"props/"+key+".tscn")
		parts[key] = load(BASE+"props/"+key+".tscn")
		part.free()
		imported.free()
	var building := Node3D.new()
	building.name = "BoxingGymExterior"
	var report: Array = []
	for spec: Dictionary in data.placements:
		var piece := (parts[spec.kind] as PackedScene).instantiate() as Node3D
		piece.name = spec.name
		piece.position = v(spec.position)
		piece.rotation.y = spec.yaw
		owned(building,piece,building)
		report.append({"name":spec.name,"scene":piece.scene_file_path,"triangles":triangles(piece)})
	for spec: Array in [["FrontEntry",Vector3(0,1.05,12.6),0.0],["FrontReturn",Vector3(0,1.05,13.3),0.0],["RearEntry",Vector3(-8.65,1.05,-12.6),PI]]:
		var marker := Marker3D.new()
		marker.name = spec[0]
		marker.position = spec[1]
		marker.rotation.y = spec[2]
		owned(building,marker,building)
	var count := triangles(building)
	var entrance := preload("res://assets/buildings/boxing_gym/gym_entrance.tscn").instantiate()
	owned(building, entrance, building)
	var occluder := OccluderInstance3D.new()
	occluder.name = "Occluder"
	occluder.position = Vector3(0,4.05,0)
	var occluder_shape := BoxOccluder3D.new()
	occluder_shape.size = Vector3(24.6,8,22.6)
	occluder.occluder = occluder_shape
	owned(building,occluder,building)
	assert(count <= 10000,"Complete exterior exceeds POI limit")
	building.set_meta("rendered_triangles",count)
	building.set_meta("wall_footprint_metres",Vector2(24.8,22.8))
	building.set_meta("front_direction","+Z")
	building.set_meta("exterior_only",true)
	save_scene(building,BASE+"boxing_gym_exterior.tscn")
	var output := FileAccess.open(BASE+"TRIANGLE_AUDIT.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"complete_exterior_triangles":count,"limit":10000,"method":"actual imported mesh faces, every placed instance counted","placements":report},"\t")+"\n")
	building.free()
	print("GYM_EXTERIOR_PREPARED actual_triangles=",count," placed_parts=",report.size())
	quit()
