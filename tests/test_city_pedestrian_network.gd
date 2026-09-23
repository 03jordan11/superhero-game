extends SceneTree
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var network = load("res://scenes/npcs/city_pedestrian_routes.tscn").instantiate()
	root.add_child(network)
	await process_frame
	await process_frame
	if not network.valid or network.enabled_module_ids.size() != 8:
		fail("Default district selection failed")
		return
	var district = network.get_node("WestVillage")
	var checked := "routes/Block_01_01"
	if district.get(checked) != true:
		fail("Named checkbox not readable")
		return
	district.set(checked,false)
	await process_frame
	if network.enabled_module_ids.size() != 7:
		fail("Checkbox did not disable its module")
		return
	var packed := PackedScene.new()
	packed.pack(network)
	ResourceSaver.save(packed,"res://.godot/network_checkbox_roundtrip.tscn")
	var restored = load("res://.godot/network_checkbox_roundtrip.tscn").instantiate()
	if restored.get_node("WestVillage").enabled_routes.get("WestVillage_Block_01_01",true):
		fail("Checkbox settings did not serialize")
		return
	restored.free()
	for child in network.get_children():
		for key in network.inventory.modules:
			if network.inventory.modules[key].district == child.district_id:
				child.enabled_routes[key] = true
	network.schedule_rebuild()
	await process_frame
	if network.enabled_module_ids.size() != network.inventory.modules.size():
		fail("Full network selection failed")
		return
	if network.inventory.version != 2 or network.inventory.river_crossings != 3:
		fail("Expected authored pavement and three river bridges")
		return
	var visited: Dictionary = {}
	var bank_count := 0
	for id in network.astar.get_point_ids():
		if visited.has(id): continue
		bank_count += 1
		var pending: Array[int] = [id]
		visited[id] = true
		while not pending.is_empty():
			var current: int = pending.pop_back()
			for neighbor in network.astar.get_point_connections(current):
				if not visited.has(neighbor):
					visited[neighbor] = true
					pending.append(neighbor)
	if bank_count != network.inventory.component_sizes.size():
		fail("Actual enabled components differ from the authored inventory")
		return
	if not network.find_children("*","CharacterBody3D",true,false).is_empty():
		fail("The route graph should not spawn civilians")
		return
	print("PASS: district defaults, checkbox serialization, authored module/component counts, and no test spawning.")
	quit()

func fail(message: String) -> void:
	push_error(message)
	quit(1)
