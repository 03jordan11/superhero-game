extends MeshInstance3D
## Small reusable ground stamps; bounded by the laser controller and self-expiring.
const SCORCH_SHADER = preload("res://effects/laser_scorch.gdshader")
var lifetime := 15.0
var age := 0.0

func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.6, 0.6)
	mesh = plane
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = SCORCH_SHADER
	material_override = material

func _process(delta: float) -> void:
	age += delta
	material_override.set_shader_parameter("fade", 1.0 - smoothstep(lifetime * 0.55, lifetime, age))
	if age >= lifetime: queue_free()
