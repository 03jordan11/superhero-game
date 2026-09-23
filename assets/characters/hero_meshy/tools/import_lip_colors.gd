@tool
extends EditorScenePostImport
## These two costumes use a local lip tint in COLOR_0, preserving their atlases.
func _post_import(scene: Node) -> Object:
	for instance: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		for surface in instance.mesh.get_surface_count():
			var colors: PackedColorArray = instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
			var material := instance.mesh.surface_get_material(surface) as StandardMaterial3D
			if material != null and not colors.is_empty():
				material.vertex_color_use_as_albedo = true
	return scene
