extends MeshInstance3D
const SHADER = preload("res://effects/frozen_ice.gdshader")

func _ready() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(1.15, 2.1, 1.0)
	mesh = box
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material_override = material
	position.y = 1.0
	hide()

func encase(enemy: Node3D) -> void:
	var collision := enemy.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null and collision.shape is CapsuleShape3D:
		var height: float = collision.shape.height
		mesh.size = Vector3(maxf(1.15, collision.shape.radius * 2.4), height + 0.35, maxf(1.0, collision.shape.radius * 2.2))
		position = collision.position
	show()

func hit(count: int) -> void:
	material_override.set_shader_parameter("cracks", float(count) / 3.0)

func shatter() -> void:
	# Briefly split/fade the shell visually; gameplay unfreezes immediately.
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", scale * 1.15, 0.15)
	tween.tween_property(self, "transparency", 1.0, 0.15)
	tween.chain().tween_callback(queue_free)
