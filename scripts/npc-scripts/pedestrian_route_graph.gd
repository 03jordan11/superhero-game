@tool
extends Node3D
## Shared routing data. Physics and character movement remain separate.
@export_file("*.json") var graph_file := "res://assets/super-city/pedestrian_pilot.json"
## Room beside painted stripes for passing people, only on an active crossing.
@export_range(0.0, 1.0, 0.05) var crossing_passing_margin := 0.5
@export var debug_visible := true:
	set(value):
		debug_visible = value
		if is_instance_valid(_debug_mesh):
			_debug_mesh.visible = value

var astar := AStar3D.new()
var edge_types: Dictionary = {}
var valid := false
var _debug_mesh: MeshInstance3D
var walkable_surfaces: Array[Rect2] = []

func _ready() -> void:
	build_graph()

func build_graph() -> void:
	valid = false
	astar.clear()
	edge_types.clear()
	var data = JSON.parse_string(FileAccess.get_file_as_string(graph_file))
	if not data is Dictionary or not data.has_all(["points", "edges"]):
		push_error("Pedestrian graph data is missing or invalid: "+graph_file)
		return
	for i in range(data.points.size()):
		var p: Array = data.points[i]
		astar.add_point(i, Vector3(p[0], p[1], p[2]))
	for edge in data.edges:
		var a := int(edge[0])
		var b := int(edge[1])
		if not astar.has_point(a) or not astar.has_point(b) or a == b:
			push_error("Pedestrian graph has an invalid connection")
			return
		astar.connect_points(a, b)
		edge_types[Vector2i(a,b)] = str(edge[2])
		edge_types[Vector2i(b,a)] = str(edge[2])
	valid = true
	_load_walkable_surfaces()
	_draw_debug()

func _load_walkable_surfaces() -> void:
	walkable_surfaces.clear()
	var bounds := Rect2(Vector2(astar.get_point_position(0).x,astar.get_point_position(0).z),Vector2.ZERO)
	for id in astar.get_point_ids():
		var p := astar.get_point_position(id)
		bounds = bounds.expand(Vector2(p.x,p.z))
	bounds = bounds.grow(6.0)
	var layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/super-city/layout.json"))
	for row in layout.sidewalks:
		var rect := Rect2(row[0],row[1],row[2],row[3])
		if rect.intersects(bounds):
			walkable_surfaces.append(rect)
	for road in layout.roads:
		if road.kind == "alley":
			var row: Array = road.rect
			var rect := Rect2(row[0],row[1],row[2],row[3])
			if rect.intersects(bounds):
				walkable_surfaces.append(rect)

func contains_body(world_point: Vector3, radius: float, a: int, b: int) -> bool:
	var p := to_local(world_point)
	var crossing_rect := Rect2()
	if is_crossing(a,b):
		var half_width := 1.5+clampf(crossing_passing_margin,0.0,1.0)
		var start := astar.get_point_position(a)
		var end := astar.get_point_position(b)
		crossing_rect = Rect2(Vector2(start.x,start.z),Vector2.ZERO).expand(Vector2(end.x,end.z))
		if absf(start.x-end.x) < 0.01:
			crossing_rect = Rect2(crossing_rect.position-Vector2(half_width,0),crossing_rect.size+Vector2(half_width*2,0))
		else:
			crossing_rect = Rect2(crossing_rect.position-Vector2(0,half_width),crossing_rect.size+Vector2(0,half_width*2))
	# Check the whole footprint against the union: adjacent sidewalk patches
	# must not act as barriers, but ordinary road space must remain forbidden.
	for i in range(9):
		var sample := Vector2(p.x,p.z)
		if i < 8:
			sample += Vector2.from_angle(float(i)*TAU/8.0)*radius
		var inside := crossing_rect.has_area() and crossing_rect.has_point(sample)
		for rect in walkable_surfaces:
			if rect.has_point(sample):
				inside = true
				break
		if not inside and not _is_extra_walkable(sample):
			return false
	return true

func _is_extra_walkable(_sample: Vector2) -> bool:
	return false

func route(from_id: int, to_id: int, allow_crossings := true) -> PackedInt64Array:
	if not valid or not astar.has_point(from_id) or not astar.has_point(to_id):
		return PackedInt64Array()
	# This pilot has one shared read-only topology. Crossing permission is
	# checked on the result without mutating connections for other pedestrians.
	var ids := astar.get_id_path(from_id, to_id)
	if not allow_crossings:
		for i in range(1, ids.size()):
			if is_crossing(ids[i-1], ids[i]):
				return PackedInt64Array()
	return ids

func point_world(id: int) -> Vector3:
	return to_global(astar.get_point_position(id))

func is_crossing(a: int, b: int) -> bool:
	return str(edge_types.get(Vector2i(a,b), "")).begins_with("crossing")

func _draw_debug() -> void:
	if is_instance_valid(_debug_mesh):
		_debug_mesh.free()
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for key: Vector2i in edge_types:
		if key.x > key.y:
			continue
		var color := Color("35eddf")
		if is_crossing(key.x,key.y):
			color = Color("ffcd38")
		elif edge_types[key] == "alley":
			color = Color("d18aff")
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(astar.get_point_position(key.x)+Vector3.UP*0.08)
		mesh.surface_add_vertex(astar.get_point_position(key.y)+Vector3.UP*0.08)
	mesh.surface_end()
	_debug_mesh = MeshInstance3D.new()
	_debug_mesh.name = "RouteDebug"
	_debug_mesh.mesh = mesh
	_debug_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_debug_mesh.visible = debug_visible
	add_child(_debug_mesh)
