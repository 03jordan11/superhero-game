extends SceneTree

func _initialize() -> void:
	var prop: Node3D = load("res://assets/props/subway_entrance/subway_entrance.tscn").instantiate()
	var triangles := 0
	var bounds := AABB()
	for mesh: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
		triangles += mesh.mesh.get_faces().size()/3
		bounds = bounds.merge(mesh.transform * mesh.mesh.get_aabb())
	assert(triangles == 386 and triangles < 500)
	assert(bounds.size.is_equal_approx(Vector3(3.8,3.5675,5.1)))
	assert(prop.get_node("Approach").position == Vector3(0,0,3.2))
	assert(prop.find_children("*", "Label3D", true, false).is_empty())
	assert(prop.find_children("*", "CollisionShape3D", true, false).size() == 12)
	assert(prop.get_script() == null)
	for node in prop.find_children("*", "Node", true, false):
		assert(node.get_script() == null)
	print("SUBWAY_PASS: 386 triangles, bounds, 12 collision shapes, blank signage and no runtime scripts")
	prop.free()
	quit()
