extends SceneTree
## Offline snapshot of authored city roads, including saved Main overrides.
## Does not modify geometry, pedestrian data, props, or the legacy layout.
const DEST := "res://assets/super-city/traffic/"

func _initialize() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	var city := main.get_node("SuperCity") as Node3D
	var pieces := []
	var candidates := city.get_node("Roads").find_children("*", "StaticBody3D", true, false)
	candidates.append_array(city.get_node("SouthRiverBridge").find_children("*", "StaticBody3D", true, false))
	for node in candidates:
		if not node.has_method("road_rects") or node.width_m < 12 or not visible(node, city): continue
		var transform := relative_transform(node, city)
		# The road leaving the southeast city edge is part of the deferred outer area.
		if node.piece_type != 1 and transform.origin.z > 760.01: continue
		assert(absf(transform.basis.y.dot(Vector3.UP)-1.0)<0.001,"Road must remain level")
		var forward := transform.basis.z.normalized()
		assert(minf(absf(forward.x),absf(forward.z))<0.001,"Non-axis-aligned road needs a curved route: "+str(city.get_path_to(node)))
		var rects := []
		for rect: Rect2 in node.road_rects(): rects.append(world_rect(rect,transform))
		var core := []
		if node.piece_type == 1:
			core = world_rect(Rect2(-node.width_m/2.0,-node.cross_width_m/2.0,node.width_m,node.cross_width_m),transform)
		pieces.append({"node":str(city.get_path_to(node)),"type":node.piece_type,"rects":rects,"core":core,"axis":0 if absf(forward.x)>0.5 else 1,"height":transform.origin.y+0.03})
	var bridges := []
	for spec in [["SouthRiverBridge","south_suspension",20],["CityHallBridge","city_hall_arch",28],["NorthRiverBridge","north_arch",20]]:
		var node := city.get_node(spec[0]) as Node3D
		if not visible(node,city): continue
		var transform := relative_transform(node,city)
		var source: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/bridges/"+spec[1]+"/deck_profile.json"))
		var samples := []
		for row in source:
			var point := transform*Vector3(0,row[1],row[0])
			samples.append([point.x,point.y,point.z])
		bridges.append({"node":spec[0],"width":spec[2],"profile":samples})
	DirAccess.make_dir_recursive_absolute(DEST)
	var data := {"pieces":pieces,"bridges":bridges,"source_sha256":{"main":FileAccess.get_sha256("res://scenes/main.tscn"),"super_city":FileAccess.get_sha256("res://scenes/super_city.tscn")}}
	FileAccess.open(DEST+"road_snapshot.json",FileAccess.WRITE).store_string(JSON.stringify(data,"\t")+"\n")
	print("TRAFFIC_SNAPSHOT: %d authored road pieces, %d bridges; external roads excluded" % [pieces.size(),bridges.size()])
	main.free()
	quit()

func visible(node: Node, city: Node) -> bool:
	while node != city:
		if node is Node3D and not node.visible: return false
		node = node.get_parent()
	return true

func relative_transform(node: Node3D, city: Node) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent != city:
		if parent is Node3D: result = parent.transform*result
		parent = parent.get_parent()
	return result

func world_rect(rect: Rect2, transform: Transform3D) -> Array:
	var bounds := transform*AABB(Vector3(rect.position.x,0,rect.position.y),Vector3(rect.size.x,0,rect.size.y))
	return [snappedf(bounds.position.x,0.001),snappedf(bounds.position.z,0.001),snappedf(bounds.size.x,0.001),snappedf(bounds.size.z,0.001)]
