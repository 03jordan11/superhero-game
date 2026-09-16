extends SceneTree
func _initialize() -> void:
	var scene: Node=load("res://assets/generated-buildings/commercial/commercial_skyscraper_01.tscn").instantiate()
	var mesh: Mesh=scene.get_node("MeshInstance3D").mesh
	print("BASELINE triangles=",mesh.get_faces().size()/3," bounds=",mesh.get_aabb()," surfaces=",mesh.get_surface_count())
	for s in mesh.get_surface_count():print("MATERIAL ",s," ",mesh.surface_get_material(s).resource_path)
	scene.free()
	var hospital: Node=load("res://assets/buildings/hospital/hospital.tscn").instantiate()
	for node in hospital.find_children("*","MeshInstance3D",true,false):
		if "roof" in str(node.name).to_lower() or "equipment" in str(node.name).to_lower():
			print("HOSPITAL ",hospital.get_path_to(node)," ",node.mesh.get_faces().size()/3," ",node.transform," ",node.mesh.get_aabb())
	hospital.free();quit()
