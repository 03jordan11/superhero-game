extends "res://scripts/riverbank_chunks.gd"
## Harbor-specific bake inputs; distance, loading and restoration use the riverbank controller.
const HARBOR_INVENTORY := "res://assets/waterfront/harbor_chunks/inventory.json"

static func harbor_snapshot(region: Node3D) -> Dictionary:
	var rows := {}
	for node: Node3D in region.find_children("*","Node3D",true,false):
		var path := str(region.get_path_to(node))
		if path.begins_with("HarborChunks/"): continue
		if not node is MeshInstance3D and not node is Label3D: continue
		var row := {"visible":authored_visible(node,region)}
		if row.visible:
			row.transform = var_to_str(pose_in(node,region))
			if node is Label3D:
				row.text = node.text
			else:
				row.geometry = str(hash(node.mesh.get_faces()))
				var mat: Material = node.get_active_material(0)
				if mat is StandardMaterial3D:
					row.material = var_to_str([mat.albedo_color,mat.roughness,mat.metallic,mat.emission,
						mat.get_meta("night_glow",0.0),mat.albedo_texture,mat.transparency])
				elif mat is ShaderMaterial and mat.shader.resource_path.ends_with("modular-sidewalks/sidewalk.gdshader"):
					var texture: Texture2D = mat.get_shader_parameter("paving")
					row.material = var_to_str([mat.shader.resource_path,texture.resource_path,mat.get_shader_parameter("tile_size")])
				else: return {} # Unsupported edited geometry stays original.
		rows[path] = row
	return rows

func _prepare() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HARBOR_INVENTORY))
	var region := get_parent() as Node3D
	valid_bake = JSON.stringify(harbor_snapshot(region),"",true) == JSON.stringify(data.sources,"",true)
	for path: String in data.source_hashes:
		valid_bake = valid_bake and FileAccess.get_sha256(path)==data.source_hashes[path]
	total_chunks = data.chunks.size()
	for path: String in data.sources:
		if not data.sources[path].visible: continue
		var source := region.get_node_or_null(NodePath(path)) as MeshInstance3D
		if source != null:
			sources.append(source)
			flags.append(source.visible)
	for record: Dictionary in data.chunks:
		var chunk := get_node(NodePath(record.name)) as Node3D
		var near := chunk.get_node("FullDetail") as Node3D
		var far := chunk.get_node("DistantProxy") as MeshInstance3D
		if _material == null: _material = far.mesh.surface_get_material(0).duplicate()
		far.material_override = _material
		for mesh: MeshInstance3D in near.get_children(): mesh.material_override = _material
		var labels: Array[Node3D] = []
		var label_flags: Array[bool] = []
		for path: String in record.labels:
			var label := region.get_node_or_null(NodePath(path)) as Node3D
			if label == null: continue
			labels.append(label)
			label_flags.append(label.visible)
		entries.append({"node":chunk,"near":near,"far":far,"state":-1,"labels":labels,"label_flags":label_flags,
			"bounds":AABB(Vector3(record.position[0],record.position[1],record.position[2]),Vector3(record.size[0],record.size[1],record.size[2]))})
		prepared_chunks += 1
	prepared = true
	if not valid_bake: push_warning("Harbor bake is stale; originals retained. Run assets/waterfront/tools/build_harbor_chunks.gd")
	_apply_enabled()

func update_visibility() -> void:
	super.update_visibility()
	for entry in entries:
		for i in entry.labels.size():
			entry.labels[i].visible = entry.label_flags[i] and (not enabled or not valid_bake or (entry.state==0 and is_visible_in_tree()))

func _exit_tree() -> void:
	for entry in entries:
		for i in entry.labels.size():
			if is_instance_valid(entry.labels[i]): entry.labels[i].visible = entry.label_flags[i]
	super._exit_tree()
