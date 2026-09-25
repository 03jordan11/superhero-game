extends Node3D
## Crossed lightning sheets surround the frozen pose without replacing its materials.
var elapsed := 0.0
var material: ShaderMaterial

func _ready() -> void:
	material = $Arcs.mesh.material.duplicate()
	for child in get_children():
		if child is MeshInstance3D: child.material_override = material
	hide()
	set_process(false)

func start() -> void:
	elapsed = 0.0
	material.set_shader_parameter("elapsed", elapsed)
	show()
	set_process(true)

func _process(delta: float) -> void:
	elapsed += delta
	material.set_shader_parameter("elapsed", elapsed)
	$Light.light_energy = 0.6 + 0.25 * sin(elapsed * 57.0)
