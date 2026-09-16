extends Node3D
## A pair of flickering ribbons and short decorative forks, in one mesh.
var _mesh := ImmediateMesh.new()
var _glow: StandardMaterial3D
var _core: StandardMaterial3D
var _spark: MeshInstance3D
var _light: OmniLight3D
var _time := 0.0

func _ready() -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = _mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	_glow = _material(Color(0.14, 0.35, 1.0), 2.0)
	_core = _material(Color(0.7, 0.95, 1.0), 4.0)
	_spark = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	sphere.radial_segments = 8
	sphere.rings = 4
	_spark.mesh = sphere
	_spark.material_override = _core
	_spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_spark)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.25, 0.55, 1.0)
	_light.light_energy = 2.0
	_light.omni_range = 3.0
	_light.shadow_enabled = false
	add_child(_light)
	hide()

func _material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material

func draw_arc(origin: Vector3, target: Vector3, camera: Vector3, contact: bool, delta: float) -> void:
	_time += delta
	global_transform = Transform3D(Basis.IDENTITY, origin)
	var end := target - origin
	if end.length_squared() < 0.0001:
		hide()
		return
	var direction := end.normalized()
	var reference := Vector3.RIGHT if absf(direction.y) > 0.95 else Vector3.UP
	var right := direction.cross(reference).normalized()
	var up := right.cross(direction).normalized()
	var lines: Array[PackedVector3Array] = []
	for strand in 2:
		var points := PackedVector3Array()
		for i in 17:
			var fraction := float(i) / 16.0
			var phase := floorf(_time * 30.0) * 1.73 + i * 4.31 + strand * 2.17
			var scatter := (right * sin(phase) + up * sin(phase * 1.37)) * sin(fraction * PI) * minf(0.3, end.length() * 0.025)
			points.append(end * fraction + scatter)
		lines.append(points)
		var fork := PackedVector3Array()
		var start := points[10]
		var tip := points[14] + right * (0.5 if strand == 0 else -0.5)
		fork.append(start)
		fork.append(start.lerp(tip, 0.4) + up * sin(_time * 35.0 + strand) * 0.15)
		fork.append(tip)
		lines.append(fork)
	_mesh.clear_surfaces()
	for layer in 2:
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _glow if layer == 0 else _core)
		for points in lines:
			_ribbon(points, 0.055 if layer == 0 else 0.018, camera - origin)
		_mesh.surface_end()
	_spark.visible = contact
	_spark.position = end
	_spark.scale = Vector3.ONE * (1.0 + sin(_time * 47.0) * 0.3)
	_light.visible = contact
	_light.position = end - direction * 0.15
	show()

func _ribbon(points: PackedVector3Array, width: float, camera: Vector3) -> void:
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var side := (b - a).cross(camera - (a + b) * 0.5).normalized() * width
		if side.is_zero_approx(): side = Vector3.RIGHT * width
		for vertex in [a - side, a + side, b + side, a - side, b + side, b - side]:
			_mesh.surface_add_vertex(vertex)
