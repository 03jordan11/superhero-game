extends Node3D
## The supplied car meshes face local +Z. Lamps follow the body through pickup,
## throwing and traffic turns; destroyed vehicles immediately lose their lights.

@export_range(0.0, 16.0, 0.1) var beam_energy := 7.0
@export_range(8.0, 70.0, 1.0) var beam_range := 38.0
@export_range(10.0, 50.0, 1.0) var beam_angle := 27.0
@export_range(0.0, 20.0, 0.5) var downward_angle := 6.0

var beams: Array[SpotLight3D] = []
var _front_material: StandardMaterial3D
var _rear_material: StandardMaterial3D
var _car: Node3D
var _night := 0.0
static var _mount_cache: Dictionary = {}

func _ready() -> void:
	_car = get_parent() as Node3D
	var visual := _car.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if visual == null or visual.mesh == null: return
	var bounds: AABB = visual.transform * visual.get_aabb()
	_front_material = _lens_material(Color(0.83, 0.91, 1.0))
	_rear_material = _lens_material(Color(1.0, 0.025, 0.008))
	var half_spacing := bounds.size.x * 0.28
	var height := bounds.position.y + bounds.size.y * 0.43
	var cache_key := visual.mesh.resource_path + str(visual.transform)
	if not _mount_cache.has(cache_key):
		var triangle_mesh := visual.mesh.generate_triangle_mesh()
		var mounts: Array[Vector3] = []
		for side in [-1, 1]:
			var x: float = bounds.get_center().x + side * half_spacing
			mounts.append(_fit_mount(visual, triangle_mesh, Vector3(x, height, bounds.end.z + 1.0), Vector3.FORWARD))
			mounts.append(_fit_mount(visual, triangle_mesh, Vector3(x, height + 0.08, bounds.position.z - 1.0), Vector3.BACK))
		_mount_cache[cache_key] = mounts
	var mounts: Array = _mount_cache[cache_key]
	var mount_index := 0
	for side in [-1, 1]:
		var nose: Vector3 = mounts[mount_index]
		_add_lens(nose, Vector3(bounds.size.x * 0.1, 0.12, 0.06), _front_material)
		_add_lens(mounts[mount_index + 1], Vector3(bounds.size.x * 0.09, 0.12, 0.06), _rear_material)
		mount_index += 2
		var light := SpotLight3D.new()
		light.name = "LeftBeam" if side < 0 else "RightBeam"
		light.position = nose + Vector3.BACK * 0.12
		light.rotation_degrees = Vector3(-downward_angle, 180, 0)
		light.light_color = Color(0.83, 0.91, 1.0)
		light.spot_range = beam_range
		light.spot_angle = beam_angle
		light.spot_attenuation = 0.7
		light.spot_angle_attenuation = 1.6
		light.shadow_enabled = true
		light.distance_fade_enabled = true
		light.distance_fade_begin = 90.0
		light.distance_fade_length = 60.0
		light.distance_fade_shadow = 45.0
		light.visible = false
		add_child(light)
		beams.append(light)
	_car.destroyed.connect(_on_destroyed)
	_bind_clock.call_deferred()

func _fit_mount(visual: MeshInstance3D, triangles: TriangleMesh, start: Vector3, direction: Vector3) -> Vector3:
	# Fit to the actual body, not the AABB's bumper/mirror extremes. Cached per model.
	var inverse := visual.transform.affine_inverse()
	var hit := triangles.intersect_ray(inverse * start, (inverse.basis * direction).normalized())
	if hit.is_empty(): return start + direction * 0.97
	return visual.transform * hit.position - direction * 0.035

func _lens_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color * 0.25
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.0
	return material

func _add_lens(point: Vector3, size: Vector3, material: Material) -> void:
	var lens := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	lens.mesh = box
	lens.position = point
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lens)

func _bind_clock() -> void:
	var cycle := get_tree().get_first_node_in_group(&"day_night_cycle")
	if cycle == null: return
	cycle.night_lighting_changed.connect(_set_night)
	_set_night(cycle.night_lighting)

func _set_night(amount: float) -> void:
	_night = amount if not _car.is_destroyed else 0.0
	for beam in beams:
		beam.light_energy = beam_energy * _night
		beam.visible = _night > 0.001
	if _front_material != null:
		_front_material.emission_energy_multiplier = 6.0 * _night
		_rear_material.emission_energy_multiplier = 3.0 * _night

func _on_destroyed(_impact_speed: float) -> void:
	_set_night(0.0)
