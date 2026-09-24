extends RefCounted
## Read the placed road modules, including Main overrides, instead of layout.json.
static func shown(node: Node, city: Node) -> bool:
	while node != city:
		if node is Node3D and not node.visible: return false
		node = node.get_parent()
	return true

static func relative(node: Node3D, city: Node) -> Transform3D:
	var transform := node.transform
	var parent := node.get_parent()
	while parent != city:
		if parent is Node3D: transform = parent.transform * transform
		parent = parent.get_parent()
	return transform

static func world_rect(rect: Rect2, transform: Transform3D) -> Rect2:
	var bounds := transform * AABB(Vector3(rect.position.x,0,rect.position.y),Vector3(rect.size.x,0,rect.size.y))
	return Rect2(bounds.position.x,bounds.position.z,bounds.size.x,bounds.size.z)

static func row(rect: Rect2) -> Array:
	return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]

static func collect(city: Node3D) -> Dictionary:
	var data := {"roads":[],"sidewalks":[],"sidewalk_heights":[],"blockers":[]}
	var root := city.get_node_or_null("Roads")
	if root == null: return data
	var runs := {}
	for node in root.find_children("*","StaticBody3D",true,false):
		if not node.has_method("road_rects") or not shown(node,city): continue
		var tr := relative(node,city)
		for rect: Rect2 in node.sidewalk_rects():
			data.sidewalks.append(row(world_rect(rect,tr)))
			data.sidewalk_heights.append(tr.origin.y+0.03)
		for rect: Rect2 in node.road_rects():
			var r := world_rect(rect,tr)
			# All road surfaces exclude lamp bases, including alleys and junction arms.
			data.roads.append({"kind":"mask","axis":0,"rect":row(r)})
			if node.width_m < 12 or node.piece_type == 1: continue
			var horizontal := absf(tr.basis.z.x) > 0.5
			var key := "%d/%.2f/%.2f/%.2f" % [int(horizontal),r.position.y if horizontal else r.position.x,r.size.y if horizontal else r.size.x,tr.origin.y]
			if not runs.has(key): runs[key] = {"horizontal":horizontal,"rects":[]}
			runs[key].rects.append(r)
		if node.piece_type == 1 and node.width_m >= 12:
			var core := world_rect(Rect2(-node.width_m/2.0,-node.cross_width_m/2.0,node.width_m,node.cross_width_m),tr)
			data.roads.append({"kind":"junction","axis":0,"rect":row(core)})
	for group: Dictionary in runs.values():
		var horizontal: bool = group.horizontal
		group.rects.sort_custom(func(a: Rect2,b: Rect2): return a.position.x < b.position.x if horizontal else a.position.y < b.position.y)
		var merged: Rect2 = group.rects[0]
		for i in range(1,group.rects.size()):
			var next: Rect2 = group.rects[i]
			var gap := next.position.x-merged.end.x if horizontal else next.position.y-merged.end.y
			if gap < 0.05: merged = merged.merge(next)
			else:
				data.roads.append({"kind":"street","axis":0 if horizontal else 1,"rect":row(merged)})
				merged = next
		data.roads.append({"kind":"street","axis":0 if horizontal else 1,"rect":row(merged)})
	# Fitted independent sidewalks are valid lamp support only beside a live road.
	var sidewalks := city.get_node_or_null("Sidewalks")
	if sidewalks != null:
		for mesh: MeshInstance3D in sidewalks.find_children("*","MeshInstance3D",true,false):
			if not mesh.get_parent().has_meta("sidewalk_module") or not shown(mesh,city) or mesh.mesh == null: continue
			var box := relative(mesh,city) * mesh.get_aabb()
			data.sidewalks.append([box.position.x,box.position.z,box.size.x,box.size.z])
			data.sidewalk_heights.append(box.end.y)
	# Keep posts out of placed buildings and solid props even if pavement runs under them.
	for shape: CollisionShape3D in city.find_children("*","CollisionShape3D",true,false):
		if shape.disabled or not shape.shape is BoxShape3D or not shown(shape,city): continue
		var path := str(city.get_path_to(shape))
		if path.begins_with("Roads/") or path.begins_with("Ground/") or path.contains("sidewalk"): continue
		var body := shape.get_parent() as CollisionObject3D
		if body == null or (body.collision_layer & 1) == 0: continue
		var box := relative(shape,city) * AABB(-shape.shape.size/2,shape.shape.size)
		if box.end.y < 0.3 or box.position.y > 9: continue
		data.blockers.append(row(Rect2(box.position.x,box.position.z,box.size.x,box.size.z).grow(0.3)))
	return data
