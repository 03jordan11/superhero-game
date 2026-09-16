extends SceneTree
const BASE := "res://assets/aircraft/helicopter/"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene := load(BASE+"helicopter.tscn") as PackedScene
	assert(scene != null)
	var a: Node3D = scene.instantiate()
	var b: Node3D = scene.instantiate()
	root.add_child(a)
	root.add_child(b)
	var triangles := 0
	var windshield_triangles := 0
	for part in a.find_children("*","MeshInstance3D",true,false):
		triangles += part.mesh.get_faces().size()/3
		assert(part.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV].size()>0)
		var arrays: Array = part.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		for i in range(0,verts.size(),3):
			assert((verts[i+2]-verts[i]).cross(verts[i+1]-verts[i]).normalized().dot(normals[i])>.99,"Front-face winding")
			if part.name == "Body" and verts[i].z < -2.6 and verts[i+1].z < -2.6 and verts[i+2].z < -2.6 and uv[i].x < .25 and uv[i].y > .5 and uv[i].y < .75:
				windshield_triangles += 1
				assert(normals[i].y > 0 and normals[i].z < 0,"Windshield must face outside, not inside the cabin")
	assert(windshield_triangles == 8,"Four visible front windshield panes")
	assert(triangles<6000)
	assert(a.get_node("MainRotorPivot").position.is_equal_approx(Vector3(0,4.13,-.1)))
	assert(a.get_node("TailRotorPivot").position.is_equal_approx(Vector3(-.43,3.56,7.58)))
	var body_transform: Transform3D = a.get_node("Body").transform
	await process_frame
	assert(a.get_node("MainRotorPivot").rotation==Vector3.ZERO,"Static default")
	a.advance_rotors(.017)
	assert(absf(a.get_node("MainRotorPivot").rotation.y)>.01)
	assert(absf(a.get_node("TailRotorPivot").rotation.x)>.01)
	assert(a.get_node("Body").transform==body_transform)
	assert(b.get_node("MainRotorPivot").rotation==Vector3.ZERO,"Instance isolation")
	a.reset_rotors()
	assert(a.get_node("MainRotorPivot").rotation==Vector3.ZERO)
	for i in range(4):
		a.livery=i
		assert(a.get_node("Body").material_override==load(a.LIVERY_PATHS[i]))
		assert(b.get_node("Body").material_override==load(a.LIVERY_PATHS[0]))
	var texture := GradientTexture2D.new()
	a.custom_livery_texture=texture
	assert(a.get_node("Body").material_override.albedo_texture==texture)
	assert(b.get_node("Body").material_override.albedo_texture!=texture)
	a.custom_livery_texture=null
	assert(a.get_node("LightMounts/PortRed").position.x<0)
	assert(a.get_node("LightMounts/StarboardGreen").position.x>0)
	a.parked_collision_enabled=true
	assert(a.get_node("ParkedCollision").collision_layer==1)
	await physics_frame
	await physics_frame
	var q := PhysicsRayQueryParameters3D.create(Vector3(-5,2,0),Vector3(5,2,0),1)
	var hit := a.get_world_3d().direct_space_state.intersect_ray(q)
	assert(not hit.is_empty() and absf(hit.position.x+1.2)<.05,"Cabin solid fits visible wall")
	a.parked_collision_enabled=false
	assert(a.get_node("ParkedCollision").collision_layer==0)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	assert(doc.append_from_file(BASE+"helicopter.glb",state)==OK)
	var glb := doc.generate_scene(state)
	var exported := 0
	for part in glb.find_children("*","MeshInstance3D",true,false): exported+=part.mesh.get_faces().size()/3
	assert(exported==triangles)
	glb.free()
	var preview := load(BASE+"helicopter_preview.tscn") as PackedScene
	assert(preview!=null)
	var gallery := preview.instantiate()
	assert(gallery.get_node("ForestStatic").rotors_spinning==false)
	assert(gallery.get_node("RescueSpinning").rotors_spinning==true)
	assert(gallery.get_node("CoastalStatic").livery==2)
	assert(gallery.get_node("CharcoalSpinning").livery==3)
	gallery.free()
	a.free()
	b.free()
	print("HELICOPTER_PASS: ",triangles," exported/native triangles; UVs, winding, pivots, static mode, four liveries, independent instances, custom texture, light mounts and solid collision")
	quit()
