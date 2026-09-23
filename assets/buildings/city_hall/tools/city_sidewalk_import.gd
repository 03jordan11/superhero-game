@tool
extends EditorScenePostImport
## Use the exact shared city paving shader/texture on every civic walking surface.
func _post_import(scene: Node) -> Object:
	var paving := load("res://assets/super-city/modular-sidewalks/sidewalk.tres") as Material
	for instance: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		for surface in instance.mesh.get_surface_count():
			var material := instance.mesh.surface_get_material(surface)
			if material != null and material.resource_name == "Steps and paving":
				instance.mesh.surface_set_material(surface, paving)
	return scene
