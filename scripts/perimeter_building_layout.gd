extends Node

const PERIMETER_BUILDINGS := [
	{"source": "Building_02", "position": Vector3(27, 0.625, -160)},
	{"source": "Building_05", "position": Vector3(27, 0.625, -100)},
	{"source": "Building_01", "position": Vector3(27, 0.625, -45)},
	{"source": "Building_07", "position": Vector3(27, 0.625, 10)},
	{"source": "Building_08", "position": Vector3(27, 0.375, 70)},
	{"source": "Building_02", "position": Vector3(27, 0.625, 130)},
	{"source": "Building_04", "position": Vector3(-459, 0.625, -160)},
	{"source": "Building_01", "position": Vector3(-459, 0.625, -105)},
	{"source": "Building_06", "position": Vector3(-459, 0.625, -50)},
	{"source": "Building_03", "position": Vector3(-459, 0.625, 5)},
	{"source": "Building_08", "position": Vector3(-459, 0.375, 65)},
	{"source": "Building_04", "position": Vector3(-459, 0.625, 125)},
	{"source": "Building_04", "position": Vector3(27, 0.625, -250)},
	{"source": "Building_02", "position": Vector3(-27, 0.625, -250)},
	{"source": "Building_01", "position": Vector3(-81, 0.625, -250)},
	{"source": "Building_06", "position": Vector3(-135, 0.625, -250)},
	{"source": "Building_08", "position": Vector3(-243, 0.375, -250)},
	{"source": "Building_03", "position": Vector3(-459, 0.625, -250)},
	{"source": "Building_05", "position": Vector3(27, 0.625, 250)},
	{"source": "Building_07", "position": Vector3(-27, 0.625, 250)},
	{"source": "Building_03", "position": Vector3(-81, 0.625, 250)},
	{"source": "Building_04", "position": Vector3(-135, 0.625, 250)},
	{"source": "Building_02", "position": Vector3(-243, 0.625, 250)},
	{"source": "Building_06", "position": Vector3(-459, 0.625, 250)},
]


func _ready() -> void:
	for layout_index in PERIMETER_BUILDINGS.size():
		var layout: Dictionary = PERIMETER_BUILDINGS[layout_index]
		var source_name: String = layout.source
		var source_building := get_node_or_null(NodePath(source_name)) as StaticBody3D
		if source_building == null:
			push_error("Missing perimeter building source: %s" % source_name)
			continue

		var building_copy := source_building.duplicate() as StaticBody3D
		building_copy.name = "Perimeter_Building_%02d" % (layout_index + 1)
		building_copy.position = layout.position
		add_child(building_copy)
