extends SceneTree
## Offline read-only inspection. No game scenes are added to the running tree or saved.
const OUT := "res://asset-dashboard/"
var data := {"assets":[],"meshes":[],"materials":[],"textures":[],"files":[],"errors":[]}
var geometry_cache := {}
var mesh_cache := {}
var material_cache := {}
var texture_cache := {}
var files: Array[String] = []
var prop_signatures := {}

func _initialize() -> void: run.call_deferred()

func scan(folder: String) -> void:
	for name in DirAccess.get_files_at(folder):
		if name.get_extension().to_lower() in ["tscn","res","tres","glb","gltf","fbx","png","jpg","jpeg","webp","svg","wav","mp3","ogg","gdshader","gd","blend","ttf","otf"]:
			files.append(folder.path_join(name))
	for name in DirAccess.get_directories_at(folder):
		if name not in ["tools","blender","__pycache__"]: scan(folder.path_join(name))

func rgba(c: Color) -> Array: return [c.r,c.g,c.b,c.a]
func vec(v: Vector3) -> Array: return [v.x,v.y,v.z]
func matrix(t: Transform3D) -> Array:
	return [t.basis.x.x,t.basis.x.y,t.basis.x.z,0,t.basis.y.x,t.basis.y.y,t.basis.y.z,0,t.basis.z.x,t.basis.z.y,t.basis.z.z,0,t.origin.x,t.origin.y,t.origin.z,1]
func b64(value: Variant) -> String:
	if value == null: return ""
	var bytes: PackedByteArray = value.to_byte_array()
	return Marshalls.raw_to_base64(bytes) if not bytes.is_empty() else ""

func texture_id(texture: Texture2D) -> int:
	if texture == null: return -1
	var key := texture.get_instance_id()
	if texture_cache.has(key): return texture_cache[key]
	var id: int = data.textures.size()
	texture_cache[key] = id
	var row := {"source":texture.resource_path,"width":texture.get_width(),"height":texture.get_height(),"preview":"","preview_width":0,"preview_height":0,"mipmaps":false,"format":"unavailable"}
	var image := texture.get_image()
	if image != null and not image.is_empty():
		row.mipmaps = image.has_mipmaps()
		row.format = str(image.get_format())
		if image.is_compressed(): image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		if maxi(image.get_width(),image.get_height())>1024:
			var scale := 1024.0/maxi(image.get_width(),image.get_height())
			image.resize(maxi(1,roundi(image.get_width()*scale)),maxi(1,roundi(image.get_height()*scale)),Image.INTERPOLATE_LANCZOS)
		row.preview_width = image.get_width()
		row.preview_height = image.get_height()
		row.preview = "data:image/png;base64,"+Marshalls.raw_to_base64(image.save_png_to_buffer())
	data.textures.append(row)
	return id

func mat_id(mat: Material) -> int:
	var key := mat.get_instance_id() if mat != null else 0
	if material_cache.has(key): return material_cache[key]
	var id: int = data.materials.size()
	material_cache[key] = id
	var row := {"name":"Default","source":"","type":"Default","albedo":[.65,.68,.7,1],"emission":[0,0,0,1],"energy":0,"emission_enabled":false,"metallic":0,"roughness":.8,"alpha":0,"cutoff":.5,"cull":0,"vertex_color":false,"vertex_srgb":false,"maps":{},"shader":"","parameters":{},"notes":[]}
	if mat != null:
		row.name = mat.resource_name if not mat.resource_name.is_empty() else mat.get_class()
		row.type = mat.get_class()
		row.source = mat.resource_path
	if mat is BaseMaterial3D:
		row.albedo = rgba(mat.albedo_color)
		row.emission = rgba(mat.emission)
		row.energy = mat.emission_energy_multiplier
		row.emission_enabled = mat.emission_enabled
		row.metallic = mat.metallic
		row.roughness = mat.roughness
		row.alpha = mat.transparency
		row.cutoff = mat.alpha_scissor_threshold
		row.cull = mat.cull_mode
		row.vertex_color = mat.vertex_color_use_as_albedo
		row.vertex_srgb = mat.vertex_color_is_srgb
		row.emission_operator = mat.emission_operator
		for pair in [["albedo",BaseMaterial3D.TEXTURE_ALBEDO],["emission",BaseMaterial3D.TEXTURE_EMISSION],["normal",BaseMaterial3D.TEXTURE_NORMAL],["roughness",BaseMaterial3D.TEXTURE_ROUGHNESS],["metallic",BaseMaterial3D.TEXTURE_METALLIC],["ao",BaseMaterial3D.TEXTURE_AMBIENT_OCCLUSION]]:
			var tex: Texture2D = mat.get_texture(pair[1])
			if tex != null: row.maps[pair[0]] = texture_id(tex)
		if mat.has_meta("glow_energy"): row.energy = mat.get_meta("glow_energy")
	elif mat is ShaderMaterial:
		row.shader = mat.shader.resource_path if mat.shader != null else ""
		row.notes.append("Custom game shader is not executed by the web viewer; neutral material approximation.")
		if mat.shader != null:
			for uniform in mat.shader.get_shader_uniform_list():
				var value: Variant = mat.get_shader_parameter(uniform.name)
				if value is Texture2D: row.maps[str(uniform.name)] = texture_id(value)
				elif value is Color: row.parameters[str(uniform.name)] = rgba(value)
				elif value is float or value is int or value is bool or value is String: row.parameters[str(uniform.name)] = value
	data.materials.append(row)
	return id

func surface_ids(mesh: Mesh) -> Array:
	var key := mesh.get_instance_id()
	if mesh_cache.has(key): return mesh_cache[key]
	var result: Array = []
	for surface in mesh.get_surface_count():
		if mesh is ArrayMesh and mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES: continue
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if vertices.is_empty(): continue
		var raw := vertices.to_byte_array()
		for channel in [Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_COLOR,Mesh.ARRAY_INDEX]:
			if arrays[channel] != null: raw.append_array(arrays[channel].to_byte_array())
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(raw)
		var fingerprint := hash.finish().hex_encode()
		var id: int = geometry_cache.get(fingerprint,-1)
		if id<0:
			id = data.meshes.size()
			geometry_cache[fingerprint] = id
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var bounds := AABB(vertices[0],Vector3.ZERO)
			for vertex in vertices: bounds = bounds.expand(vertex)
			var lods := {}
			if mesh is ArrayMesh:
				var native_surface := RenderingServer.mesh_get_surface(mesh.get_rid(),surface)
				for lod in native_surface.get("lods",[]):
					lods[str(lod.get("edge_length",0))] = lod.get("index_data",PackedByteArray()).size()/(6 if vertices.size()<=65536 else 12)
			data.meshes.append({"positions":b64(vertices),"normals":b64(arrays[Mesh.ARRAY_NORMAL]),"uv":b64(arrays[Mesh.ARRAY_TEX_UV]),"colors":b64(arrays[Mesh.ARRAY_COLOR]),"indices":b64(indices),"triangles":(indices.size() if not indices.is_empty() else vertices.size())/3,"vertices":vertices.size(),"min":vec(bounds.position),"max":vec(bounds.end),"lods":lods})
		result.append({"geometry":id,"surface":surface,"material":mat_id(mesh.surface_get_material(surface)),"source":mesh.resource_path})
	mesh_cache[key] = result
	return result

func category(path: String) -> String:
	if "/buildings/" in path: return "Landmark buildings"
	if "/generated-buildings/" in path: return "City buildings"
	if "/trees/" in path: return "Trees"
	if "/vehicles/" in path or "/Vehcile/" in path: return "Vehicles"
	if "/characters/" in path or "/npcs/" in path or path.ends_with("player.tscn"): return "Characters"
	if "/audio/" in path or path.get_extension() in ["wav","mp3","ogg"]: return "Audio"
	if "/animations/" in path: return "Animations"
	if "/sky/" in path: return "Sky & effects"
	if "/ui/" in path: return "Interface"
	if "central_park" in path or "/central-park/" in path: return "Park & nature"
	if "city_life" in path or "/city-life/" in path: return "Street furniture"
	if "coastal" in path: return "Coast & airport"
	if "waterfront" in path: return "Waterfront"
	return "World & resources"

func walk(node: Node, root_node: Node, pose: Transform3D, visible: bool, asset: Dictionary, ancestors: Array) -> void:
	if node is Node3D:
		pose = pose*node.transform
		visible = visible and node.visible
	var path := str(root_node.get_path_to(node))
	if node is CollisionShape3D and node.shape != null and not node.disabled:
		var kind: String = node.shape.get_class()
		asset.collision[kind] = int(asset.collision.get(kind,0))+1
		if node.shape is ConcavePolygonShape3D: asset.collision_triangles += node.shape.get_faces().size()/3
	if node is MeshInstance3D and node.get_script() != null and node.get_script().resource_path == "res://assets/trees/tree.gd" and node.trunk_collision_enabled:
		asset.collision["Scripted trunk capsule"] = int(asset.collision.get("Scripted trunk capsule",0))+1
	if node is Light3D:
		asset.lights.append({"path":path,"type":node.get_class(),"energy":node.light_energy,"shadows":node.shadow_enabled})
	if node is Skeleton3D: asset.bones += node.get_bone_count()
	if node is AnimationPlayer:
		for animation in node.get_animation_list():
			asset.animations.append({"name":animation,"seconds":node.get_animation(animation).length})
	var mesh: Mesh
	var poses: Array[Transform3D] = []
	if node is MeshInstance3D:
		mesh = node.mesh
		poses.append(pose)
	elif node is MultiMeshInstance3D and node.multimesh != null:
		mesh = node.multimesh.mesh
		for i in node.multimesh.instance_count: poses.append(pose*node.multimesh.get_instance_transform(i))
	if mesh != null:
		for surface in surface_ids(mesh):
			var material: int = surface.material
			if node.material_override != null: material = mat_id(node.material_override)
			elif node is MeshInstance3D and node.get_surface_override_material(surface.surface) != null: material = mat_id(node.get_surface_override_material(surface.surface))
			for instance_pose in poses:
				asset.parts.append({"g":surface.geometry,"m":material,"t":matrix(instance_pose),"path":path,"visible":visible,"shadow":node.cast_shadow,"distance":node.visibility_range_end,"mesh_source":surface.source})
	var chain := ancestors.duplicate()
	chain.append(node)
	for child in node.get_children(): walk(child,root_node,pose,visible,asset,chain)

func scene_asset(node: Node, source: String, name: String, section: String, level := "asset") -> Dictionary:
	var asset := {"id":"asset-%05d"%data.assets.size(),"name":name,"source":source,"category":section,"kind":"model","level":level,"parts":[],"collision":{},"collision_triangles":0,"lights":[],"bones":0,"animations":[],"notes":[]}
	# Normalize a selected embedded object's root placement; child transforms remain intact.
	var pose: Transform3D = node.transform.affine_inverse() if node is Node3D else Transform3D.IDENTITY
	walk(node,node,pose,true,asset,[])
	if asset.bones>0: asset.notes.append("Static mesh/bind-pose inspection; skeletal animation and runtime customization are not played.")
	if node.get_script() != null: asset.script = node.get_script().resource_path
	return asset

func add_scene(scene: PackedScene, path: String) -> void:
	var node := scene.instantiate()
	var asset := scene_asset(node,path,path.get_file().get_basename(),category(path))
	if asset.parts.is_empty(): asset.kind = "scene"
	data.assets.append(asset)
	# Expose authored prop groups nested inside world scenes, not every repeated tree.
	if path in ["res://scenes/central_park.tscn","res://scenes/city_life.tscn","res://scenes/coastal_region.tscn","res://scenes/waterfront.tscn"]:
		var candidates: Array[Node] = []
		for parent in node.get_children():
			if parent.name in ["Woodland","TreeCollisions"] or str(parent.name).begins_with("CoastalForest"): continue
			for child in parent.get_children():
				if child is Node3D and not str(child.name).begins_with("NorthernForest"):
					candidates.append(child)
		for candidate in candidates:
			var sub := scene_asset(candidate,path+"#"+str(node.get_path_to(candidate)),str(candidate.name),category(path))
			if sub.parts.is_empty() or sub.parts.size()>180: continue
			var signature := ""
			for part in sub.parts: signature += str(part.g)+":"+str(part.m)+":"+str(part.t)+";"
			signature = signature.sha256_text()
			if prop_signatures.has(signature):
				data.assets[prop_signatures[signature]].get_or_add("also_used_at",[]).append(sub.source)
				continue
			prop_signatures[signature] = data.assets.size()
			sub.id = "asset-%05d"%data.assets.size()
			data.assets.append(sub)
	node.free()

func run() -> void:
	scan("res://assets")
	scan("res://scenes")
	scan("res://resources")
	scan("res://effects")
	files.sort()
	for path in files:
		var extension := path.get_extension().to_lower()
		var bytes := FileAccess.get_file_as_bytes(path).size()
		var entry := {"path":path,"bytes":bytes,"type":extension,"dependencies":[]}
		if extension in ["tscn","res","tres","glb","gltf","fbx"]:
			entry.dependencies = Array(ResourceLoader.get_dependencies(path))
		data.files.append(entry)
		if extension in ["gd","blend","ttf","otf"]: continue
		if "_preview.tscn" in path or "/tests/" in path or "gallery.tscn" in path: continue
		if extension == "gdshader":
			data.assets.append({"id":"asset-%05d"%data.assets.size(),"name":path.get_file(),"source":path,"category":category(path),"kind":"shader","level":"resource","code":FileAccess.get_file_as_string(path)})
			continue
		if not ResourceLoader.exists(path):
			data.errors.append({"source":path,"error":"Resource not imported/readable"})
			continue
		var resource := ResourceLoader.load(path)
		if resource == null:
			data.errors.append({"source":path,"error":"Resource load failed"})
			continue
		if resource is PackedScene:
			add_scene(resource,path)
		elif resource is Mesh:
			var node := MeshInstance3D.new()
			node.mesh = resource
			var asset := scene_asset(node,path,path.get_file().get_basename(),category(path),"resource")
			data.assets.append(asset)
			node.free()
		elif resource is Texture2D:
			data.assets.append({"id":"asset-%05d"%data.assets.size(),"name":path.get_file(),"source":path,"category":category(path),"kind":"image","level":"resource","texture":texture_id(resource)})
		elif resource is Material:
			data.assets.append({"id":"asset-%05d"%data.assets.size(),"name":path.get_file(),"source":path,"category":category(path),"kind":"material","level":"resource","material":mat_id(resource)})
		elif resource is AudioStream:
			data.assets.append({"id":"asset-%05d"%data.assets.size(),"name":path.get_file(),"source":path,"category":"Audio","kind":"audio","level":"asset","seconds":resource.get_length()})
		else:
			data.assets.append({"id":"asset-%05d"%data.assets.size(),"name":path.get_file(),"source":path,"category":category(path),"kind":"resource","level":"resource","resource_type":resource.get_class()})
		if data.files.size()%50==0: print("Inspected ",data.files.size()," / ",files.size())
	data["generated"] = Time.get_datetime_string_from_system()
	data["engine"] = Engine.get_version_info().string
	var output := FileAccess.open(OUT+"snapshot.json",FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify(data))
	print("Snapshot: %d assets, %d geometries, %d materials, %d textures, %d files, %d errors" % [data.assets.size(),data.meshes.size(),data.materials.size(),data.textures.size(),data.files.size(),data.errors.size()])
	quit()
