extends "res://assets/super-city/tools/bake_landmark_proxies.gd"
## Reuses directional texture capture; geometry below is deliberately much simpler.
func run() -> void:
	output_dir = "res://assets/super-city/regional_proxies/"
	proxy_shader_path = output_dir+"regional_proxy.gdshader"
	paths = ["Waterfront/PrisonIsland", "Sidewalks/CargoShip", "CoastalRegion/Airport",
		"CoastalRegion/Airport/AirTraffic/Flight1", "CoastalRegion/Airport/AirTraffic/Flight2"]
	await super.run()

func include_visual(source: Node3D, visual: GeometryInstance3D) -> bool:
	return not (source.name == &"Airport" and str(source.get_path_to(visual)).begins_with("AirTraffic/"))

func build_custom_geometry(source: Node3D, _path: String, _bounds: AABB) -> bool:
	if source.name == &"CargoShip":
		for name in ["Hull","Antifouling","BootStripe","Deck"]:
			project_mesh(source.get_node("Model/"+name),source)
		var cargo: MeshInstance3D = source.get_node("Model/ContainerA")
		_box(source.global_transform.affine_inverse()*cargo.global_transform*cargo.get_aabb())
		for shape: CollisionShape3D in source.get_node("Collision").get_children():
			if not shape.shape is BoxShape3D or str(shape.name).begins_with("Cargo"): continue
			if str(shape.name) in ["Hull","Deck","Antifouling","BootStripe"]: continue
			_box(source.global_transform.affine_inverse()*shape.global_transform*AABB(-shape.shape.size/2,shape.shape.size))
		return true
	for visual: MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
		if visual.mesh==null or not include_visual(source,visual): continue
		var name := str(visual.name)
		var pose := source.global_transform.affine_inverse()*visual.global_transform
		var mesh := visual.mesh
		if source.name.to_lower().begins_with("flight"):
			if name in ["Fuselage","Wings","TailFin","Tailplane","Tailplane2","Engine","Engine2"]:
				project_mesh(visual,source)
		elif mesh is BoxMesh:
			var size: Vector3 = mesh.size
			if size.max_axis_index() == 1 and size.y>7 or maxf(size.x,size.z)>10:
				if size.y<0.3:
					var p := -size/2
					var e := size/2
					_quad([pose*Vector3(p.x,e.y,e.z),pose*e,pose*Vector3(e.x,e.y,p.z),pose*Vector3(p.x,e.y,p.z)],Vector3.UP,4)
				else: _box(pose*visual.get_aabb())
		elif name in ["IslandTerrain","IslandSurf","IslandAccessRamp","AirportAccessRoad","AccessRoadEdges"] or name.begins_with("HangarRoof"):
			project_mesh(visual,source)
		elif mesh is CylinderMesh and mesh.height>6 and mesh.bottom_radius>1:
			var reduced := mesh.duplicate() as CylinderMesh
			reduced.radial_segments = 8
			reduced.rings = 1
			project_mesh(visual,source,reduced)
		elif name in ["Fuselage","Wings","TailFin","Tailplane","Tailplane2","Engine","Engine2"]:
			project_mesh(visual,source)
	return true

func project_mesh(visual: MeshInstance3D, source: Node3D, replacement: Mesh = null) -> void:
	var mesh := replacement if replacement != null else visual.mesh
	var pose := source.global_transform.affine_inverse()*visual.global_transform
	var faces := mesh.get_faces()
	for i in range(0,faces.size(),3):
		var points := [pose*faces[i],pose*faces[i+1],pose*faces[i+2]]
		var normal: Vector3 = (points[2]-points[0]).cross(points[1]-points[0]).normalized()
		if normal.length_squared()<0.5: continue
		# Authored aircraft wings are double-sided, with some top faces wound downward.
		# Use the overhead capture for both sides, avoiding a transparent edge-on projection.
		if visual.name == &"Wings" and absf(normal.y)>0.5: normal=Vector3.UP
		var side := 0
		for j in NORMALS.size():
			if NORMALS[j].dot(normal)>NORMALS[side].dot(normal): side=j
		var view: Dictionary = views[side]
		for p: Vector3 in points:
			indices.append(vertices.size())
			vertices.append(p)
			normals.append(normal)
			var local := p-Vector3(view.centre)
			var uv := Vector2(0.5+local.dot(view.right)/view.span,0.5-local.dot(view.up)/view.span)
			uvs.append((uv+Vector2(side%3,side/3))/Vector2(3,2))
