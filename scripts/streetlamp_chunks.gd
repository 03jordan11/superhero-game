extends Node3D
## Spatial MultiMeshes: one surface per cell, with cheaper fixture meshes at distance.
@export var enabled := true:
	set(value):
		enabled = value
		if prepared: update_visibility()
@export_enum("Automatic", "Full fixtures", "Simple fixtures", "Heads only", "Hidden") var force_lod := 0
@export_range(100,500,50,"suffix:m") var chunk_size_m := 250.0
@export_range(25,300,25,"suffix:m") var full_detail_distance_m := 125.0
@export_range(150,600,25,"suffix:m") var heads_only_distance_m := 350.0
@export_range(400,2000,50,"suffix:m") var cutoff_distance_m := 750.0
@export_range(0,100,5,"suffix:m") var switching_margin_m := 25.0
var prepared := false
var prepared_chunks := 0
var total_chunks := 0
var entries: Array[Dictionary] = []
var meshes: Array[ArrayMesh] = []
var material: ShaderMaterial
var _originals: Node3D
var _original_visible := true
var _night := 0.0
var _elapsed := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"city_hlod_preparation")

func setup(fixtures: Array[Dictionary], original_post: Mesh, originals: Node3D, colors: Array) -> void:
	_originals = originals
	_original_visible = originals.visible
	material = ShaderMaterial.new()
	material.shader = load("res://assets/sky/streetlamp_chunks.gdshader")
	material.set_shader_parameter("night_amount",_night)
	material.set_shader_parameter("metal_color",Color(0.055,0.065,0.075))
	for i in colors.size():
		material.set_shader_parameter("bulb%d"%i,colors[i]*0.25)
		material.set_shader_parameter("emission%d"%i,colors[i])
	var lens := BoxMesh.new()
	lens.size = Vector3(0.5,0.07,0.98)
	for level in 3:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		if level==0: _append(tool,original_post,Transform3D.IDENTITY,false)
		elif level==1:
			for part in [[Vector3(0.2,9,0.2),Vector3(0,4.5,0)],
				[Vector3(0.13,0.14,1.8),Vector3(0,9,0.85)],
				[Vector3(0.6,0.22,1.1),Vector3(0,8.87,1.65)]]:
				var box := BoxMesh.new()
				box.size = part[0]
				_append(tool,box,Transform3D(Basis.IDENTITY,part[1]),false)
		_append(tool,lens,Transform3D(Basis.IDENTITY,Vector3(0,8.73,1.65)),true)
		tool.set_material(material)
		tool.index()
		meshes.append(tool.commit())
	var cells := {}
	for i in fixtures.size():
		var point: Vector3 = fixtures[i].transform.origin
		var key := Vector2i(floori(point.x/chunk_size_m),floori(point.z/chunk_size_m))
		if not cells.has(key): cells[key] = []
		cells[key].append(i)
	total_chunks = cells.size()
	for key: Vector2i in cells:
		var chunk := Node3D.new()
		chunk.name = "Cell_%d_%d"%[key.x,key.y]
		chunk.position = Vector3((key.x+0.5)*chunk_size_m,0,(key.y+0.5)*chunk_size_m)
		add_child(chunk)
		var bounds := AABB()
		var first := true
		for i: int in cells[key]:
			var pose: Transform3D = fixtures[i].transform
			pose.origin -= chunk.position
			var box := pose*meshes[0].get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		var batches: Array[MultiMeshInstance3D] = []
		for level in 3:
			var batch := MultiMeshInstance3D.new()
			batch.name = ["FullFixtures","SimpleFixtures","HeadsOnly"][level]
			batch.multimesh = MultiMesh.new()
			batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			batch.multimesh.use_custom_data = true
			batch.multimesh.mesh = meshes[level]
			batch.multimesh.instance_count = cells[key].size()
			batch.multimesh.custom_aabb = bounds
			for j in cells[key].size():
				var row: Dictionary = fixtures[cells[key][j]]
				var pose: Transform3D = row.transform
				pose.origin -= chunk.position
				batch.multimesh.set_instance_transform(j,pose)
				batch.multimesh.set_instance_custom_data(j,Color(float(row.style),0,0,0))
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			batch.visible = false
			chunk.add_child(batch)
			batches.append(batch)
		entries.append({"node":chunk,"batches":batches,"bounds":bounds,"indices":cells[key],"state":-1})
		prepared_chunks += 1
	prepared = true
	update_visibility()

func _append(tool: SurfaceTool, mesh: Mesh, pose: Transform3D, lens: bool) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for i in vertices.size(): indices.append(i)
	for i in indices:
		tool.set_normal(pose.basis*normals[i])
		tool.set_color(Color(1,0,0) if lens else Color(0,0,0))
		tool.add_vertex(pose*vertices[i])

func set_night(amount: float) -> void:
	_night = amount
	if material != null: material.set_shader_parameter("night_amount",amount)
	update_visibility()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed<0.1: return
	_elapsed = 0.0
	update_visibility()

func update_visibility() -> void:
	if not prepared: return
	_originals.visible = _original_visible and not enabled
	var camera := get_viewport().get_camera_3d()
	# Keep exported thresholds ordered even while tuning them in the Remote Inspector.
	var full_limit := full_detail_distance_m
	var head_limit := maxf(heads_only_distance_m,full_limit)
	var cut_limit := maxf(cutoff_distance_m,head_limit)
	for entry in entries:
		var state := 0
		if force_lod!=0:
			state = force_lod-1
		elif camera!=null:
			var box: AABB = entry.node.global_transform*entry.bounds
			var distance := camera.global_position.distance_to(camera.global_position.clamp(box.position,box.end))
			var margin := switching_margin_m
			if distance>cut_limit+(0.0 if entry.state>=3 else margin): state=3
			elif distance>head_limit+(0.0 if entry.state>=2 else margin): state=2
			elif distance>full_limit+(0.0 if entry.state>=1 else margin): state=1
		entry.state = state
		for level in 3:
			# Tiny unlit lenses add no useful daytime silhouette at this range.
			entry.batches[level].visible = enabled and state==level and (level!=2 or _night>0.001)

func _exit_tree() -> void:
	if is_instance_valid(_originals): _originals.visible = _original_visible
