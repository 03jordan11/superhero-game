extends SceneTree
const OUT = "res://artifacts/river_mountains/"
const TREES = preload("res://assets/trees/tools/tree_instances.gd")
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	FileAccess.open(OUT+".gdignore",FileAccess.WRITE).store_string("")
	var result := {"meshes":{},"trees":{},"walls":[]}
	for file in ["city_life","coastal_region","waterfront"]:
		var scene: Node = load("res://scenes/"+file+".tscn").instantiate()
		var rows := []
		for tree in TREES.trees(scene):
			var t: Transform3D = tree.transform
			var p: Node = tree.get_parent()
			while p != scene:
				if p is Node3D: t = p.transform*t
				p = p.get_parent()
			rows.append({"path":str(scene.get_path_to(tree)),"position":[t.origin.x,t.origin.y,t.origin.z],"radius":tree.get_aabb().size.x*t.basis.get_scale().x*.5,"species":tree.scene_file_path.get_file().get_basename()})
		result.trees[file] = rows
		for node in scene.find_children("*","MeshInstance3D",true,false):
			if node.name in ["NorthernGround","PinePassMountains","CoastalTerrain"]:
				var surfaces := []
				for s in node.mesh.get_surface_count():
					var a: Array = node.mesh.surface_get_arrays(s)
					var vertices := []; var colors := []; var indices := []
					for v in a[Mesh.ARRAY_VERTEX]: vertices.append([v.x,v.y,v.z])
					if a[Mesh.ARRAY_COLOR] != null:
						for c in a[Mesh.ARRAY_COLOR]: colors.append([c.r,c.g,c.b,c.a])
					if a[Mesh.ARRAY_INDEX] != null:
						for idx in a[Mesh.ARRAY_INDEX]: indices.append(idx)
					surfaces.append({"vertices":vertices,"colors":colors,"indices":indices})
				result.meshes[str(node.name)] = {"path":str(scene.get_path_to(node)),"scene":file,"transform":var_to_str(node.transform),"material":node.material_override.resource_path,"surfaces":surfaces}
			if str(node.name).begins_with("QuayWall") and node.position.z < 799.9:
				var shapes := []
				for shape in node.find_children("*","CollisionShape3D",true,false): shapes.append(str(scene.get_path_to(shape)))
				result.walls.append({"path":str(scene.get_path_to(node)),"shapes":shapes})
		scene.free()
	FileAccess.open(OUT+"source.json",FileAccess.WRITE).store_string(JSON.stringify(result))
	print("Exported terrain, tree positions and river walls")
	quit()
