extends StaticBody3D
## Solid cover from creation; launched victims can leave the rising wall safely.
const ICE_SHADER = preload("res://effects/frozen_ice.gdshader")
var dimensions := Vector3(8, 4, 2)
var lifetime := 6.0
var elapsed := 0.0
var launched: Array[CharacterBody3D] = []
var visual: MeshInstance3D

func _ready() -> void:
	add_to_group(&"frost_walls")
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = dimensions
	shape.position.y = dimensions.y * 0.5
	add_child(shape)
	visual = MeshInstance3D.new()
	visual.mesh = BoxMesh.new()
	visual.mesh.size = dimensions
	var material := ShaderMaterial.new()
	material.shader = ICE_SHADER
	visual.material_override = material
	add_child(visual)
	_update_visual()

func allow_launch(body: CharacterBody3D) -> void:
	launched.append(body)
	body.add_collision_exception_with(self)

func _physics_process(delta: float) -> void:
	elapsed += delta
	for index in range(launched.size() - 1, -1, -1):
		var body := launched[index]
		if not is_instance_valid(body):
			launched.remove_at(index)
			continue
		var local := to_local(body.global_position)
		# Padding includes the standing capsule so collision resumes after clearance.
		if absf(local.x) > dimensions.x * 0.5 + 0.8 or absf(local.z) > dimensions.z * 0.5 + 0.8 or local.y > dimensions.y + 0.2:
			body.remove_collision_exception_with(self)
			launched.remove_at(index)
	_update_visual()
	if elapsed >= lifetime:
		collision_layer = 0
		queue_free()

func _update_visual() -> void:
	var growth := smoothstep(0.0, 0.2, elapsed)
	visual.scale.y = maxf(0.02, growth)
	visual.position.y = dimensions.y * visual.scale.y * 0.5
	visual.material_override.set_shader_parameter("cracks", smoothstep(lifetime - 0.5, lifetime, elapsed))

func _exit_tree() -> void:
	for body in launched:
		if is_instance_valid(body): body.remove_collision_exception_with(self)
