extends MeshInstance3D
## One shared low-poly shell, one shader, no lights or particle simulation.
const WIND_SHADER = preload("res://effects/charge_punch_wind.gdshader")
static var _shell: ArrayMesh
var lifetime := 0.45
var elapsed := 0.0
var wind_material: ShaderMaterial

func configure(origin: Transform3D, reach: float, cone_degrees: float, duration: float, color: Color, power: float) -> void:
	name = "ChargePunchWind"
	add_to_group(&"charge_punch_wind")
	if _shell == null: _shell = _build_shell()
	mesh = _shell
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	lifetime = maxf(duration, 0.05)
	var length := maxf(reach, 0.1)
	var radius := length * tan(deg_to_rad(clampf(cone_degrees, 1.0, 150.0) * 0.5))
	global_transform = Transform3D(origin.basis.scaled_local(Vector3(radius, radius, length)), origin.origin)
	wind_material = ShaderMaterial.new()
	wind_material.shader = WIND_SHADER
	wind_material.set_shader_parameter("wind_color", color)
	wind_material.set_shader_parameter("power", clampf(power, 0.0, 1.0))
	material_override = wind_material

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime:
		queue_free()
		return
	wind_material.set_shader_parameter("progress", elapsed / lifetime)

static func _build_shell() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	const SIDES := 32
	const LENGTH_STEPS := 12
	for row in range(LENGTH_STEPS + 1):
		var t := float(row) / LENGTH_STEPS
		for side in range(SIDES + 1):
			var u := float(side) / SIDES
			var angle := u * TAU
			vertices.append(Vector3(cos(angle) * t, sin(angle) * t, -t))
			uvs.append(Vector2(u, t))
	for row in LENGTH_STEPS:
		for side in SIDES:
			var a := row * (SIDES + 1) + side
			var b := a + SIDES + 1
			indices.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
