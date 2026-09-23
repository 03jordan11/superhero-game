extends Node3D
## Prepare single-surface city proxies after source initialization.
const BATCH := preload("res://scripts/city_chunk_hlod.gd")
const MATERIALS := preload("res://scripts/city_hlod_materials.gd")
@export var enabled := true:
	set(value):
		enabled = value
		if not value:
			for batch in batches: batch.set_far(false)
@export_range(100.0, 1000.0, 10.0, "suffix:m") var near_distance_m := 100.0
@export_range(0.0, 100.0, 5.0, "suffix:m") var switching_margin_m := 25.0
var prepared := false
var prepared_chunks := 0
var total_chunks := 0
var build_ms := 0.0
var batches: Array = []
var atlas: RefCounted
var _building := false
var _queued := false
var _settle_frames := 0
var _chunks: Array[Node] = []

func _ready() -> void:
	# Preparation must advance while the loading screen pauses gameplay. Source
	# buildings are elsewhere in the tree and keep their usual process modes.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"city_hlod_preparation")
	get_node("/root/CityWindows").settings_changed.connect(_refresh_materials, CONNECT_DEFERRED)
	for side in get_children():
		for chunk in side.get_children():
			for building in chunk.get_buildings():
				if building.has_signal("window_materials_changed"):
					building.window_materials_changed.connect(request_rebuild)
	request_rebuild()

func request_rebuild() -> void:
	prepared = false
	for batch in batches: batch.set_far(false)
	_queued = true
	_settle_frames = 2

func _begin_rebuild() -> void:
	_queued = false
	_building = true
	for batch in batches: batch.dispose()
	batches.clear()
	atlas = MATERIALS.new()
	prepared_chunks = 0
	build_ms = 0.0
	_chunks.clear()
	for side in get_children():
		_chunks.append_array(side.get_children())
	total_chunks = _chunks.size()

func _build_next_chunk() -> void:
	if prepared_chunks < _chunks.size():
		var start := Time.get_ticks_usec()
		var batch := BATCH.new()
		batch.build(_chunks[prepared_chunks], near_distance_m, atlas)
		batches.append(batch)
		build_ms += (Time.get_ticks_usec() - start) / 1000.0
		prepared_chunks += 1
		return
	var atlas_start := Time.get_ticks_usec()
	if not atlas.finish():
		for batch in batches: batch.dispose()
		batches.clear()
		enabled = false
	build_ms += (Time.get_ticks_usec() - atlas_start) / 1000.0
	var clock := get_tree().get_first_node_in_group(&"day_night_cycle")
	if clock != null and not clock.night_lighting_changed.is_connected(_refresh_materials):
		clock.night_lighting_changed.connect(_refresh_materials, CONNECT_DEFERRED)
	_building = false
	prepared = true
	update_visibility()

func _refresh_materials(_amount := 0.0) -> void:
	if prepared and atlas != null: atlas.refresh()

func _process(_delta: float) -> void:
	if _queued:
		if _settle_frames > 0:
			_settle_frames -= 1
			return
		_begin_rebuild()
	if _building:
		_build_next_chunk()
		return
	update_visibility()

func update_visibility() -> void:
	if not prepared or not enabled: return
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	for batch in batches:
		batch.update(camera.global_position, near_distance_m, switching_margin_m)

func _exit_tree() -> void:
	for batch in batches: batch.dispose()
	batches.clear()
