extends SceneTree
func _initialize() -> void:
	var city: Node3D=load("res://artifacts/river_mouth/before/scenes/super_city.tscn").instantiate()
	var result:={"meshes":[],"buildings":[],"props":[],"south_walls":[]}
	for category in ["Ground","Roads","Sidewalks"]:
		for body in city.get_node(category).get_children():
			if not body.has_node("MeshInstance3D"):continue
			var node: MeshInstance3D=body.get_node("MeshInstance3D")
			var surfaces:=[]
			for s in node.mesh.get_surface_count():
				var a: Array=node.mesh.surface_get_arrays(s);var vertices:=[]
				var indices: PackedInt32Array=a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
				if indices.is_empty():
					for i in a[Mesh.ARRAY_VERTEX].size():indices.append(i)
				for i in indices:
					var v: Vector3=body.transform*a[Mesh.ARRAY_VERTEX][i]
					var n: Vector3=a[Mesh.ARRAY_NORMAL][i];var uv:=Vector2.ZERO
					if a[Mesh.ARRAY_TEX_UV]!=null:uv=a[Mesh.ARRAY_TEX_UV][i]
					vertices.append([v.x,v.y,v.z,n.x,n.y,n.z,uv.x,uv.y])
				var material: Material=node.mesh.surface_get_material(s)
				surfaces.append({"v":vertices,"material":material.resource_path})
			result.meshes.append({"body":str(city.get_path_to(body)),"origin":[body.position.x,body.position.y,body.position.z],"surfaces":surfaces})
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/super-city/layout.json"))
	for row in layout.buildings:
		var node: Node3D=city.get_node(row.node);var bounds:=AABB();var first:=true
		for mesh in node.find_children("*","MeshInstance3D",true,false):
			var pose: Transform3D=mesh.transform;var parent: Node=mesh.get_parent()
			while parent!=city:
				if parent is Node3D:pose=parent.transform*pose
				parent=parent.get_parent()
			var b: AABB=pose*mesh.get_aabb()
			bounds=b if first else bounds.merge(b);first=false
		var collider: CollisionShape3D=node.get_node_or_null("CollisionShape3D")
		if collider!=null and collider.shape is BoxShape3D:
			var size: Vector3=collider.shape.size
			bounds=bounds.merge((node.transform*collider.transform)*AABB(-size*.5,size))
		result.buildings.append({"path":row.node,"rect":[bounds.position.x,bounds.position.z,bounds.size.x,bounds.size.z]})
	for container in city.get_node("CityLife").get_children():print("CityLife group ",container.name," count ",container.get_child_count())
	for node in city.get_node("Waterfront/Riverbanks").get_children():
		if str(node.name).begins_with("HarborLamp"):
			result.props.append({"path":"Waterfront/Riverbanks/"+str(node.name),"p":[node.position.x,node.position.y,node.position.z],"lamp":true})
		if str(node.name).begins_with("QuayWall") and node.position.z>799:
			result.south_walls.append({"path":"Waterfront/Riverbanks/"+str(node.name),"position":[node.position.x,node.position.y,node.position.z],"transform":var_to_str(node.transform)})
	for base in [city.get_node("CityLife"),city.get_node("Waterfront/Riverbanks")]:
		for node in base.find_children("*","Node3D",true,false):
			if not (str(node.name).begins_with("StreetLamp") or str(node.name).begins_with("QuayLamp") or str(node.name).begins_with("Bench") or str(node.name).begins_with("Hydrant") or str(node.name).begins_with("Trash") or str(node.name).begins_with("Planter")):continue
			var pose: Transform3D=node.transform;var parent: Node=node.get_parent()
			while parent!=city:
				if parent is Node3D:pose=parent.transform*pose
				parent=parent.get_parent()
			result.props.append({"path":str(city.get_path_to(node)),"p":[pose.origin.x,pose.origin.y,pose.origin.z]})
	FileAccess.open("res://artifacts/river_mouth/source.json",FileAccess.WRITE).store_string(JSON.stringify(result))
	city.free();quit()
