extends Node3D
## Offline-baked, one-surface replacements. Source roots stay in place for physics.
const DATA_PATH := "res://assets/super-city/landmark_proxies/inventory.json"
@export var enabled := true:
	set(value):
		enabled = value
		if not value:
			for entry in entries: _set_far(entry, false)
@export_range(25.0, 1000.0, 25.0, "suffix:m") var near_distance_m := 100.0
@export_range(0.0, 100.0, 5.0, "suffix:m") var switching_margin_m := 25.0
var entries: Array[Dictionary] = []
var prepared := false
var prepared_chunks := 0
var total_chunks := 0
var _settle_frames := 2

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"city_hlod_preparation")
	get_node("/root/CityWindows").settings_changed.connect(_refresh_lighting)

func _prepare() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	total_chunks = data.landmarks.size()
	for record: Dictionary in data.landmarks:
		var source := get_parent().get_node_or_null(NodePath(record.path)) as Node3D
		var mesh := load(record.mesh) as ArrayMesh
		if source == null or mesh == null:
			push_error("Landmark proxy missing source or bake: " + str(record.path))
			continue
		var proxy := MeshInstance3D.new()
		proxy.name = source.name
		proxy.mesh = mesh
		proxy.material_override = mesh.surface_get_material(0).duplicate()
		proxy.visible = false
		add_child(proxy)
		proxy.global_transform = source.global_transform
		var box := source.global_transform * AABB(_vector(record.bounds_position), _vector(record.bounds_size))
		entries.append({"source": source, "proxy": proxy, "original_visible": source.visible,
			"centre": box.get_center(), "radius": box.size.length() * 0.5, "far_active": false})
		prepared_chunks += 1
	var clock := get_tree().get_first_node_in_group(&"day_night_cycle")
	if clock != null: clock.night_lighting_changed.connect(_refresh_lighting)
	prepared = true
	_refresh_lighting()
	update_visibility()

func _vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

func _process(_delta: float) -> void:
	if not prepared:
		if _settle_frames > 0:
			_settle_frames -= 1
			return
		_prepare()
	update_visibility()

func update_visibility() -> void:
	if not prepared or not enabled: return
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	for entry in entries:
		var distance: float = near_distance_m + entry.radius + (0.0 if entry.far_active else switching_margin_m)
		_set_far(entry, camera.global_position.distance_to(entry.centre) > distance)

func _set_far(entry: Dictionary, value: bool) -> void:
	if entry.far_active == value: return
	entry.far_active = value
	# Hiding the root also covers lights and children which animate their own Visible
	# property (park fireflies). Visibility never disables collision or door areas.
	if is_instance_valid(entry.source): entry.source.visible = entry.original_visible and not value
	if is_instance_valid(entry.proxy): entry.proxy.visible = entry.original_visible and value

func _refresh_lighting(_amount := 0.0) -> void:
	var clock := get_tree().get_first_node_in_group(&"day_night_cycle")
	var amount: float = clock.night_lighting if clock != null else 0.0
	var brightness: float = get_node("/root/CityWindows").brightness
	for entry in entries:
		entry.proxy.material_override.set_shader_parameter("night_amount", amount)
		entry.proxy.material_override.set_shader_parameter("window_brightness", brightness)

func _exit_tree() -> void:
	for entry in entries: _set_far(entry, false)
