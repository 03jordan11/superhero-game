@tool
extends StaticBody3D
## Authored road presets with dimensions in metres. No per-frame generation.
## Children are implementation details; resize the root using the Inspector.
const ROAD_SHADER = preload("res://assets/super-city/modular-roads/road.gdshader")
const ASPHALT = preload("res://assets/super-city/textures/junction_20_20_15.res")
const PAVEMENT = preload("res://assets/super-city/modular-sidewalks/sidewalk.tres")
const TOP := 0.03
const SIDEWALK_WIDTH := 4.0
const APPROACH := 8.0
const DIRECTIONS := ["North", "East", "South", "West"]
const NORMALS := [Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT]

@export_enum("Straight", "Junction", "Dead end") var piece_type: int = 0:
	set(value):
		piece_type = value
		_schedule_rebuild()
@export_enum("Alley 6 m:6", "Local 12 m:12", "Street 20 m:20", "Avenue 28 m:28") var width_m: int = 20:
	set(value):
		width_m = value
		_schedule_rebuild()
@export_range(0.1, 200.0, 0.1, "or_greater", "suffix:m") var length_m := 40.0:
	set(value):
		length_m = maxf(0.1, value)
		_schedule_rebuild()
@export_group("Junction")
@export_enum("Alley 6 m:6", "Local 12 m:12", "Street 20 m:20", "Avenue 28 m:28") var cross_width_m: int = 20:
	set(value):
		cross_width_m = value
		_schedule_rebuild()
@export_flags("North", "East", "South", "West") var active_arms: int = 15:
	set(value):
		active_arms = value
		_schedule_rebuild()
@export_flags("North", "East", "South", "West") var crosswalk_arms: int = 15:
	set(value):
		crosswalk_arms = value
		_schedule_rebuild()
@export_group("Straight markings")
@export var crosswalk_north := false:
	set(value):
		crosswalk_north = value
		_schedule_rebuild()
@export var crosswalk_south := false:
	set(value):
		crosswalk_south = value
		_schedule_rebuild()
@export_range(0.0, 8.0, 0.1, "suffix:m") var dash_offset_m := 0.0:
	set(value):
		dash_offset_m = value
		_schedule_rebuild()
@export_group("Sidewalks")
@export var include_sidewalks := true:
	set(value):
		include_sidewalks = value
		_schedule_rebuild()
## Local X/Z openings for alleys and fitted frontage. They move with the piece.
@export var sidewalk_cutouts: Array[Rect2] = []:
	set(value):
		sidewalk_cutouts = value
		_schedule_rebuild()
@export_group("Boundary fitting")
## Local X/Z clipping for modules split by an existing city's chunk boundary.
@export var trim_to_bounds := false:
	set(value):
		trim_to_bounds = value
		_schedule_rebuild()
@export var trim_bounds := Rect2(-100, -100, 200, 200):
	set(value):
		trim_bounds = value
		_schedule_rebuild()
@export_group("Performance")
## Editor connection markers can be omitted from the running city.
@export var keep_sockets_at_runtime := true

var _rebuild_pending := false
var _built_settings: Array = []

func _ready() -> void:
	rebuild()
	if not Engine.is_editor_hint() and not keep_sockets_at_runtime:
		for node_name in ["RoadSockets", "SidewalkSockets"]:
			var sockets := get_node_or_null(node_name)
			if sockets != null: sockets.free()

func _schedule_rebuild() -> void:
	if not is_inside_tree() or _rebuild_pending:
		return
	_rebuild_pending = true
	rebuild.call_deferred()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not scale.is_equal_approx(Vector3.ONE):
		warnings.append("Keep Scale at (1, 1, 1). Use Length M and the width presets to preserve physics and marking sizes.")
	if piece_type == 1 and active_arms == 0:
		warnings.append("Enable at least one junction arm.")
	return warnings

func road_rects() -> Array[Rect2]:
	var w := float(width_m)
	if piece_type != 1:
		return _trim_rects([Rect2(-w / 2.0, -length_m / 2.0, w, length_m)])
	var d := float(cross_width_m)
	var rects: Array[Rect2] = [Rect2(-w / 2.0, -d / 2.0, w, d)]
	if active_arms & 1: rects.append(Rect2(-w / 2.0, -d / 2.0 - APPROACH, w, APPROACH))
	if active_arms & 2: rects.append(Rect2(w / 2.0, -d / 2.0, APPROACH, d))
	if active_arms & 4: rects.append(Rect2(-w / 2.0, d / 2.0, w, APPROACH))
	if active_arms & 8: rects.append(Rect2(-w / 2.0 - APPROACH, -d / 2.0, APPROACH, d))
	return _trim_rects(rects)

func _trim_rects(rects: Array[Rect2]) -> Array[Rect2]:
	if not trim_to_bounds: return rects
	var result: Array[Rect2] = []
	for rect in rects:
		var clipped := rect.intersection(trim_bounds)
		if clipped.has_area(): result.append(clipped)
	return result

func sidewalk_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if not include_sidewalks:
		return _fit_sidewalks(rects)
	var w := float(width_m)
	var s := SIDEWALK_WIDTH
	if piece_type != 1:
		var extra := s if piece_type == 2 else 0.0
		rects.append(Rect2(-w / 2.0 - s, -length_m / 2.0, s, length_m + extra))
		rects.append(Rect2(w / 2.0, -length_m / 2.0, s, length_m + extra))
		if piece_type == 2: rects.append(Rect2(-w / 2.0, length_m / 2.0, w, s))
		return _fit_sidewalks(rects)
	var d := float(cross_width_m)
	# Four corner squares; approach shoulders and closed sides meet these exactly.
	for x in [-w / 2.0 - s, w / 2.0]:
		for z in [-d / 2.0 - s, d / 2.0]:
			rects.append(Rect2(x, z, s, s))
	for i in 4:
		if active_arms & (1 << i):
			if i == 0 or i == 2:
				var z := -d / 2.0 - APPROACH if i == 0 else d / 2.0 + s
				for x in [-w / 2.0 - s, w / 2.0]: rects.append(Rect2(x, z, s, APPROACH - s))
			else:
				var x := w / 2.0 + s if i == 1 else -w / 2.0 - APPROACH
				for z in [-d / 2.0 - s, d / 2.0]: rects.append(Rect2(x, z, APPROACH - s, s))
		else:
			match i:
				0: rects.append(Rect2(-w / 2.0, -d / 2.0 - s, w, s))
				1: rects.append(Rect2(w / 2.0, -d / 2.0, s, d))
				2: rects.append(Rect2(-w / 2.0, d / 2.0, w, s))
				3: rects.append(Rect2(-w / 2.0 - s, -d / 2.0, s, d))
	return _fit_sidewalks(rects)

func _fit_sidewalks(rects: Array[Rect2]) -> Array[Rect2]:
	var result := _trim_rects(rects)
	for cut in sidewalk_cutouts:
		var next: Array[Rect2] = []
		for rect in result:
			var overlap := rect.intersection(cut)
			if not overlap.has_area():
				next.append(rect)
				continue
			for part in [Rect2(rect.position.x, rect.position.y, rect.size.x, overlap.position.y - rect.position.y),
				Rect2(rect.position.x, overlap.end.y, rect.size.x, rect.end.y - overlap.end.y),
				Rect2(rect.position.x, overlap.position.y, overlap.position.x - rect.position.x, overlap.size.y),
				Rect2(overlap.end.x, overlap.position.y, rect.end.x - overlap.end.x, overlap.size.y)]:
				if part.has_area(): next.append(part)
		result = next
	return result

func rebuild() -> void:
	_rebuild_pending = false
	if not has_node("Mesh") or not has_node("Collision"):
		return
	var settings := [piece_type, width_m, length_m, cross_width_m, active_arms,
		crosswalk_arms, crosswalk_north, crosswalk_south, dash_offset_m, include_sidewalks, trim_to_bounds, trim_bounds, sidewalk_cutouts.duplicate()]
	if settings == _built_settings:
		return
	_built_settings = settings
	var road_material := ShaderMaterial.new()
	road_material.shader = ROAD_SHADER
	for key in ["width_m", "cross_width_m", "length_m", "dash_offset_m"]:
		road_material.set_shader_parameter(key, float(get(key)))
	road_material.set_shader_parameter("asphalt", ASPHALT)
	road_material.set_shader_parameter("junction", piece_type == 1)
	road_material.set_shader_parameter("arms", active_arms)
	road_material.set_shader_parameter("crosswalks", crosswalk_arms)
	road_material.set_shader_parameter("crossing_north", crosswalk_north)
	road_material.set_shader_parameter("crossing_south", crosswalk_south)
	var mesh := ArrayMesh.new()
	var faces := PackedVector3Array()
	_add_surface(mesh, faces, road_rects(), 0.12, road_material)
	_add_surface(mesh, faces, sidewalk_rects(), 0.03, PAVEMENT)
	$Mesh.mesh = mesh
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	$Collision.shape = shape
	$Collision.disabled = faces.is_empty()
	_update_sockets()
	if Engine.is_editor_hint(): update_configuration_warnings()

func _quad(vertices: PackedVector3Array, normals: PackedVector3Array, points: Array[Vector3], normal: Vector3) -> void:
	# Clockwise winding as seen from above, matching the existing city's slabs.
	for i in [0, 1, 2, 0, 2, 3]:
		vertices.append(points[i])
		normals.append(normal)

func _add_surface(mesh: ArrayMesh, faces: PackedVector3Array, rects: Array[Rect2], depth: float, material: Material) -> void:
	if rects.is_empty(): return
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for rect in rects:
		var first_vertex := vertices.size()
		var a := Vector3(rect.position.x, TOP, rect.position.y)
		var b := Vector3(rect.end.x, TOP, rect.position.y)
		var c := Vector3(rect.end.x, TOP, rect.end.y)
		var d := Vector3(rect.position.x, TOP, rect.end.y)
		var down := Vector3(0, -depth, 0)
		_quad(vertices, normals, [a, b, c, d], Vector3.UP)
		_quad(vertices, normals, [a + down, b + down, b, a], Vector3.FORWARD)
		_quad(vertices, normals, [b + down, c + down, c, b], Vector3.RIGHT)
		_quad(vertices, normals, [c + down, d + down, d, c], Vector3.BACK)
		_quad(vertices, normals, [d + down, a + down, a, d], Vector3.LEFT)
		# A 1 mm horizontal overlap avoids numerical ray/capsule cracks at city
		# coordinates. Rendered footprints and the walking height remain exact.
		for i in range(first_vertex, vertices.size()):
			var p := vertices[i]
			p.x += signf(p.x - rect.get_center().x) * 0.001
			p.z += signf(p.z - rect.get_center().y) * 0.001
			faces.append(p)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)

func _update_sockets() -> void:
	if not has_node("RoadSockets") or not has_node("SidewalkSockets"): return
	for i in 4:
		var active := bool(active_arms & (1 << i)) if piece_type == 1 else (i == 0 or (i == 2 and piece_type == 0))
		var distance := length_m / 2.0
		var road_width := float(width_m)
		if piece_type == 1:
			distance = (cross_width_m if i == 0 or i == 2 else width_m) / 2.0 + APPROACH
			road_width = float(width_m if i == 0 or i == 2 else cross_width_m)
		var direction: Vector3 = NORMALS[i]
		var tangent := direction.cross(Vector3.UP)
		_set_socket($RoadSockets.get_node(DIRECTIONS[i]), direction * distance, direction, active, road_width)
		for side in [-1, 1]:
			var suffix := "Left" if side == -1 else "Right"
			var point: Vector3 = direction * distance + tangent * side * (road_width / 2.0 + SIDEWALK_WIDTH / 2.0)
			_set_socket($SidewalkSockets.get_node(DIRECTIONS[i] + suffix), point, direction, active and include_sidewalks, SIDEWALK_WIDTH)

func _set_socket(socket: Marker3D, point: Vector3, direction: Vector3, active: bool, width: float) -> void:
	# A boundary fragment cannot advertise an intact connection outside its mesh.
	if trim_to_bounds:
		active = active and trim_bounds.grow(0.001).has_point(Vector2(point.x, point.z))
	if socket.get_parent().name == "SidewalkSockets":
		for cut in sidewalk_cutouts:
			if cut.has_point(Vector2(point.x, point.z)): active = false
	socket.position = point
	socket.basis = Basis.looking_at(direction)
	socket.visible = active
	socket.set_meta("active", active)
	socket.set_meta("width_m", width)
