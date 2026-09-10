@tool
extends "res://scripts/npc-scripts/pedestrian_route_graph.gd"

const CITY_PERF = preload("res://scripts/ui-scripts/city_performance_monitor.gd")
## Shared topology and debug overlays. CivilianCrowd owns population.
signal rebuilt
@export_category("City Routes")
## Master visibility switch for route lines in the editor and game.
## Each district's Show Debug setting still applies when enabled.
@export var show_debug_routes := true:
	set(value):
		show_debug_routes = value
		_update_debug_visibility()
@export var network_enabled := true:
	set(value):
		network_enabled = value
		schedule_rebuild()
@export var show_disabled_routes := false:
	set(value):
		show_disabled_routes = value
		schedule_rebuild()
var inventory: Dictionary = {}
var enabled_module_ids: Array[String] = []
var _queued := false
var _surface_cells: Dictionary = {}

func _validate_property(property: Dictionary) -> void:
	# The city graph uses its generated network; these inherited pilot-only
	# controls would misleadingly suggest they configure district debug lines.
	if property.name in ["graph_file","debug_visible"]:
		property.usage = PROPERTY_USAGE_NONE

func _ready() -> void:
	inventory = JSON.parse_string(FileAccess.get_file_as_string("res://assets/super-city/pedestrians/network.json"))
	schedule_rebuild()

func schedule_rebuild() -> void:
	if not is_inside_tree() or _queued: return
	_queued = true
	_rebuild.call_deferred()

func _rebuild() -> void:
	var perf_started := CITY_PERF.begin(self)
	_profiled_rebuild()
	CITY_PERF.finish(&"network_rebuild", perf_started)


func _profiled_rebuild() -> void:
	_queued = false
	if inventory.is_empty(): return
	valid = false
	astar.clear()
	edge_types.clear()
	enabled_module_ids.clear()
	for district in get_children():
		if not district.get_script(): continue
		for module in district.get_children():
			for child in module.get_children():
				if child.name == "RouteLines": child.free()
		if network_enabled and district.district_enabled:
			for key in district.enabled_routes:
				if district.enabled_routes[key] and inventory.modules.has(key): enabled_module_ids.append(key)
	for i in range(inventory.points.size()):
		var p: Array = inventory.points[i]
		astar.add_point(i,Vector3(p[0],p[1],p[2]))
	var batches: Dictionary = {}
	for edge in inventory.edges:
		var key: String = edge[3]
		var enabled := key in enabled_module_ids
		if enabled:
			astar.connect_points(edge[0],edge[1])
			edge_types[Vector2i(edge[0],edge[1])] = edge[2]
			edge_types[Vector2i(edge[1],edge[0])] = edge[2]
		if enabled or show_disabled_routes:
			if not batches.has(key): batches[key] = []
			batches[key].append(edge)
	walkable_surfaces.clear()
	_surface_cells.clear()
	for row in inventory.surfaces:
		var rect := Rect2(row[0],row[1],row[2],row[3])
		walkable_surfaces.append(rect)
		for x in range(floori(rect.position.x/100),floori(rect.end.x/100)+1):
			for z in range(floori(rect.position.y/100),floori(rect.end.y/100)+1):
				var key := Vector2i(x,z)
				if not _surface_cells.has(key): _surface_cells[key] = []
				_surface_cells[key].append(rect)
	valid = true
	for key in batches:
		var district = get_node_or_null(NodePath(inventory.modules[key].district))
		if district == null: continue
		var module = district.get_node_or_null(NodePath(inventory.modules[key].label))
		if module == null: continue
		_draw_module(module,batches[key],show_debug_routes and district.show_debug,key in enabled_module_ids)
	notify_property_list_changed()
	update_configuration_warnings()
	rebuilt.emit()

func contains_body(world_point: Vector3, radius: float, a: int, b: int) -> bool:
	var perf_started := CITY_PERF.begin(self)
	var result: bool = _profiled_contains_body(world_point, radius, a, b)
	CITY_PERF.finish(&"walkable_area_check", perf_started, not result)
	return result


func _profiled_contains_body(world_point: Vector3, radius: float, a: int, b: int) -> bool:
	# Reuse the proven corridor check with only nearby surface rectangles.
	var p := to_local(world_point)
	var saved := walkable_surfaces
	var local_surfaces: Array[Rect2] = []
	for x in range(floori((p.x-radius)/100),floori((p.x+radius)/100)+1):
		for z in range(floori((p.z-radius)/100),floori((p.z+radius)/100)+1):
			local_surfaces.append_array(_surface_cells.get(Vector2i(x,z),[]))
	walkable_surfaces = local_surfaces
	var result := super.contains_body(world_point,radius,a,b)
	walkable_surfaces = saved
	return result

func _update_debug_visibility() -> void:
	for district in get_children():
		if not district.get_script(): continue
		for module in district.get_children():
			var lines := module.get_node_or_null("RouteLines") as MeshInstance3D
			if lines != null:
				lines.visible = show_debug_routes and district.show_debug

func _draw_module(parent: Node3D, rows: Array, shown: bool, enabled: bool) -> void:
	var mesh := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mesh.surface_begin(Mesh.PRIMITIVE_LINES,mat)
	for edge in rows:
		var color := Color("35eddf") if edge[2] == "sidewalk" else (Color("ffcd38") if edge[2] == "crossing" else Color("d18aff"))
		mesh.surface_set_color(color if enabled else Color("657077"))
		mesh.surface_add_vertex(astar.get_point_position(edge[0])+Vector3.UP*0.1)
		mesh.surface_add_vertex(astar.get_point_position(edge[1])+Vector3.UP*0.1)
	mesh.surface_end()
	var visual := MeshInstance3D.new()
	visual.name = "RouteLines"
	visual.mesh = mesh
	visual.visible = shown
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)

func _get_property_list() -> Array[Dictionary]:
	return [{"name":"Enabled Modules","type":TYPE_INT,"usage":PROPERTY_USAGE_EDITOR|PROPERTY_USAGE_READ_ONLY}]

func _get(property: StringName):
	if property == &"Enabled Modules": return enabled_module_ids.size()
	return null

func _get_configuration_warnings() -> PackedStringArray:
	var messages := PackedStringArray()
	if transform != Transform3D.IDENTITY: messages.append("Keep this node at identity within the city: graph data uses city-local coordinates.")
	return messages
