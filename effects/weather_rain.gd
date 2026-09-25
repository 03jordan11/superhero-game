extends MultiMeshInstance3D
## Camera-local rain with a small static-world roof/ground height map.
const SHADER = preload("res://effects/weather_rain.gdshader")
const GRID := 9
const WIDTH := 36.0
const CELL := WIDTH / GRID
@export var drop_count := 2800
var material: ShaderMaterial
var heights: Image
var height_texture: ImageTexture
var elapsed := 0.0
var roof_updates := 0

func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = SHADER
	heights = Image.create(GRID, GRID, false, Image.FORMAT_RF)
	heights.fill(Color(-10000, 0, 0))
	height_texture = ImageTexture.create_from_image(heights)
	material.set_shader_parameter("roof_heights", height_texture)
	var strip := QuadMesh.new()
	strip.size = Vector2(0.026, 0.65)
	strip.material = material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = strip
	multimesh.instance_count = drop_count
	multimesh.custom_aabb = AABB(Vector3(-19, -14, -19), Vector3(38, 30, 38))
	var random := RandomNumberGenerator.new()
	random.seed = 1964
	for i in drop_count:
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(random.randf_range(-18, 18), 0, random.randf_range(-18, 18))))
		multimesh.set_instance_custom_data(i, Color(random.randf(), random.randf(), 0, 1))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hide()

func update_rain(delta: float, strength: float) -> void:
	elapsed += delta
	material.set_shader_parameter("elapsed", elapsed)
	material.set_shader_parameter("intensity", strength)
	visible = strength > 0.001

func sample_roofs(camera_position: Vector3, excluded: Array[RID]) -> void:
	global_position = Vector3(floorf(camera_position.x / CELL) * CELL, camera_position.y, floorf(camera_position.z / CELL) * CELL)
	var origin := Vector2(global_position.x - WIDTH * 0.5, global_position.z - WIDTH * 0.5)
	material.set_shader_parameter("grid_origin", origin)
	for z in GRID:
		for x in GRID:
			var point := Vector3(origin.x + (x + 0.5) * CELL, global_position.y, origin.y + (z + 0.5) * CELL)
			var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2048, point - Vector3.UP * 14, 1, excluded)
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			heights.set_pixel(x, z, Color(hit.position.y if not hit.is_empty() else point.y - 15, 0, 0))
	height_texture.update(heights)
	roof_updates += 1
