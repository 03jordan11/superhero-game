extends Node3D
## Static sidewalk fixtures are batched; only a bounded pool casts nearby light.
## Layout comes from the same manifest as traffic, never from guessed street grids.

@export_file("*.json") var layout_path := "res://assets/super-city/layout.json"
@export_range(30.0, 150.0, 5.0) var spacing := 72.0
@export_range(16, 160, 8) var max_active_lights := 96
@export_range(80.0, 700.0, 10.0) var illumination_radius := 420.0
@export_range(0.0, 12.0, 0.1) var lamp_energy := 5.0
@export_range(10.0, 40.0, 1.0) var lamp_range := 25.0
@export_range(0.05, 1.0, 0.05) var selection_interval := 0.2
@export_group("Entrances and Storefronts")
@export_range(0, 48, 4) var max_frontage_lights := 24
@export_range(0.0, 8.0, 0.1) var frontage_energy := 2.4
@export_range(5.0, 25.0, 1.0) var frontage_range := 12.0
@export_range(30.0, 200.0, 5.0) var frontage_radius := 100.0

const COLORS := [Color(1.0, 0.63, 0.29), Color(0.72, 0.85, 1.0), Color(1.0, 0.82, 0.54)]
var fixtures: Array[Dictionary] = []
var _lights: Array[SpotLight3D] = []
var _lens_materials: Array[StandardMaterial3D] = []
var _selected: Array[Dictionary] = []
var frontages: Array[Dictionary] = []
var _frontage_lights: Array[SpotLight3D] = []
var _night := 0.0
var _elapsed := 0.0

func _ready() -> void:
	var layout = JSON.parse_string(FileAccess.get_file_as_string(layout_path))
	if not layout is Dictionary:
		push_error("CityNightLights: could not read city layout")
		return
	fixtures = build_fixture_layout(layout, spacing)
	frontages = build_frontage_layout(layout)
	_build_geometry()
	for index in max_active_lights:
		var light := SpotLight3D.new()
		light.name = "PavementLight%d" % index
		light.spot_range = lamp_range
		light.spot_angle = 66.0
		light.spot_attenuation = 0.65
		light.spot_angle_attenuation = 0.65
		light.shadow_enabled = false
		light.distance_fade_enabled = true
		light.distance_fade_begin = 550.0
		light.distance_fade_length = 250.0
		light.visible = false
		add_child(light)
		_lights.append(light)
	for index in max_frontage_lights:
		var light:=SpotLight3D.new(); light.name="FrontageLight%d"%index
		light.spot_range=frontage_range; light.spot_angle=70.0
		light.spot_attenuation=.8; light.spot_angle_attenuation=.6
		light.shadow_enabled=false; light.visible=false
		add_child(light); _frontage_lights.append(light)
	_bind_clock.call_deferred()

static func build_fixture_layout(layout: Dictionary, interval: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var sidewalks: Array[Rect2] = []
	for row in layout.get("sidewalks", []):
		sidewalks.append(Rect2(row[0], row[1], row[2], row[3]).grow(-0.25))
	for road in layout.get("roads", []):
		if road.kind != "street" and road.kind != "pier_access": continue
		var row: Array = road.rect
		var rect := Rect2(row[0], row[1], row[2], row[3])
		var horizontal := int(road.axis) == 0
		var length := rect.size.x if horizontal else rect.size.y
		if length < 20.0: continue
		var count := maxi(1, floori(length / maxf(interval, 30.0)))
		for i in count:
			for side in [-1, 1]:
				var along := (float(i) + 0.5) / count * length
				var point := Vector2(rect.position.x + along, rect.position.y - 1.1 if side < 0 else rect.end.y + 1.1) if horizontal else Vector2(rect.position.x - 1.1 if side < 0 else rect.end.x + 1.1, rect.position.y + along)
				var supported := false
				for sidewalk in sidewalks:
					if sidewalk.has_point(point):
						supported = true
						break
				if not supported: continue
				var heading := (0.0 if side < 0 else PI) if horizontal else (PI * 0.5 if side < 0 else -PI * 0.5)
				var style := 0 if point.x < -560 else (1 if point.x > 520 else 2)
				result.append({"transform": Transform3D(Basis(Vector3.UP, heading), Vector3(point.x, 0.065, point.y)), "style": style})
	# Supplemental corner lamps keep intersections connected to the mid-block pools.
	for road in layout.get("roads", []):
		if road.kind!="junction": continue
		var row: Array=road.rect
		var rect:=Rect2(row[0],row[1],row[2],row[3])
		for point in [rect.position-Vector2(1.1,1.1),rect.end+Vector2(1.1,1.1)]:
			var supported:=false
			for sidewalk in sidewalks:
				if sidewalk.has_point(point): supported=true; break
			if not supported: continue
			var blocked:=false
			for other in layout.get("roads", []):
				var r: Array=other.rect
				if Rect2(r[0],r[1],r[2],r[3]).has_point(point): blocked=true; break
			if blocked: continue
			var close:=false
			for fixture in result:
				var p: Vector3=fixture.transform.origin
				if point.distance_squared_to(Vector2(p.x,p.z))<144: close=true; break
			if close: continue
			var toward: Vector2=rect.get_center()-point
			var heading:=atan2(toward.x,toward.y)
			var style:=0 if point.x < -560 else (1 if point.x > 520 else 2)
			result.append({"transform":Transform3D(Basis(Vector3.UP,heading),Vector3(point.x,.065,point.y)),"style":style,"intersection":true})
	return result

static func build_frontage_layout(layout: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var catalog: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated-buildings/commercial/manifest.json"))
	var depths: Dictionary={}
	for row in catalog: depths[row.scene]=float(row.depth_m)
	for row in layout.get("buildings",[]):
		if not depths.has(str(row.asset).get_file()): continue
		var origin:=Vector3(row.position[0],row.position[1],row.position[2])
		var basis:=Basis(Vector3.UP,float(row.rotation_y))
		var depth: float=depths[str(row.asset).get_file()]
		for side in [-1,1]:
			var position:=origin+basis*Vector3(0,4.0,side*(depth*.5+.28))
			var target:=origin+basis*Vector3(0,.2,side*(depth*.5+3.8))
			var color:=Color("ffe3bb") if int(abs(origin.x+origin.z))%5!=0 else Color("f1f3ff")
			result.append({"position":position,"target":target,"color":color})
	return result

func _build_geometry() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.055, 0.065, 0.075)
	metal.metallic = 0.65
	metal.roughness = 0.42
	var post := SurfaceTool.new()
	post.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.07
	shaft.bottom_radius = 0.13
	shaft.height = 9.0
	shaft.radial_segments = 8
	post.append_from(shaft, 0, Transform3D(Basis.IDENTITY, Vector3(0, 4.5, 0)))
	var base := CylinderMesh.new()
	base.top_radius = 0.19
	base.bottom_radius = 0.25
	base.height = 0.45
	base.radial_segments = 8
	post.append_from(base, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0.225, 0)))
	for part in [[Vector3(0.13, 0.14, 1.8), Vector3(0, 9, 0.85)], [Vector3(0.6, 0.22, 1.1), Vector3(0, 8.87, 1.65)]]:
		var box := BoxMesh.new()
		box.size = part[0]
		post.append_from(box, 0, Transform3D(Basis.IDENTITY, part[1]))
	var mesh := post.commit()
	mesh.surface_set_material(0, metal)
	_add_batch("LampPosts", mesh, fixtures)
	for style in COLORS.size():
		var lens := StandardMaterial3D.new()
		lens.albedo_color = COLORS[style] * 0.25
		lens.emission_enabled = true
		lens.emission = COLORS[style]
		lens.emission_energy_multiplier = 0.0
		_lens_materials.append(lens)
		var bulb := BoxMesh.new()
		bulb.size = Vector3(0.5, 0.07, 0.98)
		bulb.material = lens
		var rows: Array[Dictionary] = []
		for fixture in fixtures:
			if fixture.style != style: continue
			var placement: Transform3D = fixture.transform
			placement.origin = placement * Vector3(0, 8.73, 1.65)
			rows.append({"transform": placement})
		_add_batch("LampLenses%d" % style, bulb, rows)

func _add_batch(label: String, mesh: Mesh, rows: Array[Dictionary]) -> void:
	var batch := MultiMeshInstance3D.new()
	batch.name = label
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh = mesh
	batch.multimesh.instance_count = rows.size()
	for i in rows.size(): batch.multimesh.set_instance_transform(i, rows[i].transform)
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)

func _bind_clock() -> void:
	var cycle := get_tree().get_first_node_in_group(&"day_night_cycle")
	if cycle == null: return
	cycle.night_lighting_changed.connect(_set_night)
	_set_night(cycle.night_lighting)

func _set_night(amount: float) -> void:
	_night = amount
	for material in _lens_materials: material.emission_energy_multiplier = 5.0 * _night
	_select_lights()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < selection_interval: return
	_elapsed = 0.0
	if _night > 0.001: _select_lights()

func _select_lights() -> void:
	for light in _lights: light.visible = false
	for light in _frontage_lights: light.visible = false
	_selected.clear()
	var camera := get_viewport().get_camera_3d()
	if camera == null or _night <= 0.001: return
	var focus := to_local(camera.global_position)
	_select_frontages(focus)
	var candidates: Array[Dictionary] = []
	for fixture in fixtures:
		var point: Vector3 = fixture.transform.origin
		var distance := Vector2(point.x - focus.x, point.z - focus.z).length_squared()
		if distance < illumination_radius * illumination_radius:
			candidates.append({"fixture": fixture, "distance": distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
	# Fade at the budget boundary as well as the radius, avoiding hard pool swaps.
	var edge := illumination_radius
	if candidates.size() > _lights.size(): edge = sqrt(candidates[_lights.size()].distance)
	for i in mini(candidates.size(), _lights.size()):
		var row: Dictionary = candidates[i]
		var fixture: Dictionary = row.fixture
		var placement: Transform3D = fixture.transform
		var light := _lights[i]
		light.position = placement * Vector3(0, 8.65, 1.65)
		light.rotation = Vector3(-PI * 0.5, 0, 0)
		light.light_color = COLORS[fixture.style]
		light.light_energy = lamp_energy * _night * (1.0 - smoothstep(edge * 0.72, edge, sqrt(row.distance)))
		light.visible = light.light_energy > 0.01
		_selected.append(fixture)

func _select_frontages(focus: Vector3) -> void:
	var candidates: Array[Dictionary]=[]
	for row in frontages:
		var distance: float=focus.distance_squared_to(row.position)
		if distance<frontage_radius*frontage_radius:
			candidates.append({"row":row,"distance":distance})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return a.distance<b.distance)
	var edge:=frontage_radius
	if candidates.size()>_frontage_lights.size(): edge=sqrt(candidates[_frontage_lights.size()].distance)
	for i in mini(candidates.size(),_frontage_lights.size()):
		var row: Dictionary=candidates[i].row
		var light:=_frontage_lights[i]
		light.position=row.position
		light.basis=Basis.looking_at(row.target-row.position,Vector3.UP)
		light.spot_range=frontage_range
		light.light_color=row.color
		light.light_energy=frontage_energy*_night*(1.0-smoothstep(edge*.65,edge,sqrt(candidates[i].distance)))
		light.visible=light.light_energy>.01
