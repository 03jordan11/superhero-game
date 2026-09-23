extends Node3D
## Independent moving replacements and nearest-AABB switching for large coastal POIs.
const DATA_PATH := "res://assets/super-city/regional_proxies/inventory.json"
@export var enabled := true:
	set(value):
		enabled = value
		if prepared: update_visibility()
@export_enum("Automatic", "Originals", "Distant proxies") var force_lod := 0
@export_range(25,1000,25,"suffix:m") var near_distance_m := 300.0
@export_range(0,150,5,"suffix:m") var switching_margin_m := 50.0
var entries: Array[Dictionary] = []
var prepared := false
var prepared_chunks := 0
var total_chunks := 0
var _settle_frames := 2

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"city_hlod_preparation")

func _prepare() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	total_chunks = data.landmarks.size()
	for record: Dictionary in data.landmarks:
		var source := get_parent().get_node_or_null(NodePath(record.path)) as Node3D
		if source == null: continue # Ship is placed in Main, not standalone SuperCity.
		var proxy := MeshInstance3D.new()
		proxy.name = source.name
		proxy.mesh = load(record.mesh)
		proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		proxy.material_override = proxy.mesh.surface_get_material(0).duplicate()
		proxy.visible = false
		add_child(proxy)
		var roots: Array[Node3D] = []
		# AirTraffic must stay visible independently of the static airport replacement.
		if source.name == &"Airport":
			for child in source.get_children():
				if child is Node3D and child.name != &"AirTraffic": roots.append(child)
		else: roots.append(source)
		var flags: Array[bool] = []
		for node in roots: flags.append(node.visible)
		entries.append({"source":source,"proxy":proxy,"roots":roots,"flags":flags,"far":false,
			"bounds":AABB(_vector(record.bounds_position),_vector(record.bounds_size))})
		prepared_chunks += 1
	prepared = true
	var cycle := get_tree().get_first_node_in_group(&"day_night_cycle")
	if cycle != null: cycle.night_lighting_changed.connect(_refresh_lighting)
	_refresh_lighting()
	update_visibility()

func _vector(row: Array) -> Vector3: return Vector3(row[0],row[1],row[2])

func _process(_delta: float) -> void:
	if not prepared:
		if _settle_frames>0:
			_settle_frames -= 1
			return
		_prepare()
	update_visibility()

func update_visibility() -> void:
	if not prepared: return
	var camera := get_viewport().get_camera_3d()
	for entry in entries:
		if not is_instance_valid(entry.source):
			entry.proxy.visible = false
			continue
		entry.proxy.global_transform = entry.source.global_transform
		var far := false
		if enabled and camera != null:
			var box: AABB = entry.source.global_transform*entry.bounds
			var distance := camera.global_position.distance_to(camera.global_position.clamp(box.position,box.end))
			far = distance>near_distance_m+(0.0 if entry.far else switching_margin_m)
			if force_lod != 0: far = force_lod == 2
		_set_far(entry,far)

func _set_far(entry: Dictionary, far: bool, refresh := false) -> void:
	if entry.far == far and not refresh: return
	entry.far = far
	for i in entry.roots.size():
		if is_instance_valid(entry.roots[i]): entry.roots[i].visible = entry.flags[i] and not far
	entry.proxy.visible = far and entry.flags.has(true)

func _refresh_lighting(_amount := 0.0) -> void:
	var cycle := get_tree().get_first_node_in_group(&"day_night_cycle")
	for entry in entries:
		# Airport's top-level lights are animated by CoastalRegion. Restore their
		# current clock-driven visibility, not the daylight flag captured at startup.
		for i in entry.roots.size():
			if entry.roots[i] is Light3D:
				entry.flags[i] = entry.roots[i].light_energy>0.001
		entry.proxy.material_override.set_shader_parameter("night_amount",cycle.night_lighting if cycle != null else 0.0)
		entry.proxy.material_override.set_shader_parameter("window_brightness",1.0)
		_set_far(entry,entry.far,true)

func _exit_tree() -> void:
	for entry in entries: _set_far(entry,false)
