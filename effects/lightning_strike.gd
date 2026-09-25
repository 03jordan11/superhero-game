extends Node3D
## Cosmetic sky bolt and one-second surface discharge. Damage is owned by the power.
const GROUND_SHADER = preload("res://effects/lightning_ground.gdshader")
const THUNDER = preload("res://assets/audio/weather/thunder_1.wav")
const BOLT_HEIGHT := 80.0
@export_range(-40.0, 6.0, 0.5) var strike_volume_db := 0.0
@export_range(1.0, 100.0, 1.0) var strike_sound_unit_size := 25.0
var lifetime := 1.0
var elapsed := 0.0
var active := false
var ground_material: ShaderMaterial
var upright_material: ShaderMaterial
var _bolt: MeshInstance3D
var _ground: MeshInstance3D
var _sheets: Node3D
var _light: OmniLight3D
var _audio: AudioStreamPlayer3D

func _ready() -> void:
	ground_material = ShaderMaterial.new()
	ground_material.shader = GROUND_SHADER
	upright_material = ground_material.duplicate()
	upright_material.set_shader_parameter("upright", true)
	_ground = MeshInstance3D.new()
	_ground.mesh = PlaneMesh.new()
	_ground.material_override = ground_material
	_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ground)
	_sheets = Node3D.new()
	add_child(_sheets)
	for i in 3:
		var sheet := MeshInstance3D.new()
		sheet.mesh = QuadMesh.new()
		sheet.material_override = upright_material
		sheet.rotation.y = float(i) * PI / 3.0
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_sheets.add_child(sheet)
	_bolt = MeshInstance3D.new()
	_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bolt)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.55, 0.75, 1)
	_light.omni_range = 14
	_light.position.y = 2
	add_child(_light)
	_audio = AudioStreamPlayer3D.new()
	_audio.stream = THUNDER
	_audio.bus = &"SFX"
	_audio.volume_db = strike_volume_db
	# Keep the nearby bolt's crack strong across the power's combat range.
	_audio.unit_size = strike_sound_unit_size
	_audio.max_db = 0.0
	_audio.max_distance = 120
	add_child(_audio)
	hide()
	set_process(false)

static func surface_basis(normal: Vector3) -> Basis:
	var x := Vector3.RIGHT.slide(normal).normalized()
	if x.is_zero_approx(): x = Vector3.FORWARD.slide(normal).normalized()
	return Basis(x, normal, x.cross(normal)).orthonormalized()

func start(center: Vector3, normal: Vector3, radius: float, radial: bool, seconds: float) -> void:
	global_transform = Transform3D(Basis.IDENTITY, center + normal * 0.035)
	lifetime = maxf(seconds, 0.01)
	elapsed = 0.0
	active = true
	_ground.basis = surface_basis(normal)
	_ground.mesh.size = Vector2.ONE * radius * 2.0
	_sheets.basis = _ground.basis
	for sheet in _sheets.get_children():
		sheet.mesh.size = Vector2(radius * 2.0, 0.85)
		sheet.position.y = 0.42
	for material in [ground_material, upright_material]:
		material.set_shader_parameter("elapsed", 0.0)
		material.set_shader_parameter("lifetime", lifetime)
		material.set_shader_parameter("radial", radial)
	_bolt.mesh = _build_bolt()
	_bolt.show()
	_light.light_energy = 8
	_audio.play()
	show()
	set_process(true)

func _build_bolt() -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var points := PackedVector3Array([Vector3.ZERO])
	for i in range(1, 33):
		points.append(Vector3(randf_range(-1.0, 1.0), i * BOLT_HEIGHT / 32.0, randf_range(-1.0, 1.0)))
	for layer in 2:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = Color(0.2, 0.5, 1) if layer == 0 else Color(0.85, 0.95, 1)
		material.emission_enabled = true
		material.emission = material.albedo_color
		material.emission_energy_multiplier = 5.0
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
		var width := 0.22 if layer == 0 else 0.07
		for i in points.size() - 1:
			for side in [Vector3.RIGHT, Vector3.FORWARD]:
				var a := points[i]
				var b := points[i + 1]
				var edge: Vector3 = side * width
				for v in [a - edge, a + edge, b + edge, a - edge, b + edge, b - edge]: mesh.surface_add_vertex(v)
		mesh.surface_end()
	return mesh

func _process(delta: float) -> void:
	elapsed += delta
	ground_material.set_shader_parameter("elapsed", elapsed)
	upright_material.set_shader_parameter("elapsed", elapsed)
	_bolt.visible = elapsed < 0.22 and (elapsed < 0.10 or elapsed > 0.14)
	_light.light_energy = 8.0 * maxf(0.0, 1.0 - elapsed / 0.3)
	if elapsed >= lifetime:
		active = false
		hide()
		set_process(false)

func stop() -> void:
	active = false
	hide()
	set_process(false)
	if is_instance_valid(_audio): _audio.stop()
