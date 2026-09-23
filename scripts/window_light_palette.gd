extends Resource
## Reusable colors for every building's window shader.
@export var warm_amber := Color("e4b766"):
	set(value):
		warm_amber = value
		emit_changed()
@export var soft_yellow := Color("f2dba6"):
	set(value):
		soft_yellow = value
		emit_changed()
@export var cool_white := Color("9ac8dc"):
	set(value):
		cool_white = value
		emit_changed()

func apply_to(material: ShaderMaterial) -> void:
	material.set_shader_parameter("warm_amber", warm_amber)
	material.set_shader_parameter("soft_yellow", soft_yellow)
	material.set_shader_parameter("cool_white", cool_white)
