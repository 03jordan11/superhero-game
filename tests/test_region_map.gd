extends SceneTree
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var city := Node3D.new()
	root.add_child(city)
	city.position = Vector3(120, 40, -90)
	city.rotation.y = 0.6
	city.scale = Vector3(1.5, 1.5, 1.5)
	var player := Node3D.new()
	root.add_child(player)
	var page = preload("res://scripts/ui-scripts/region_map.gd").new()
	page.city = city
	page.player = player
	root.add_child(page)
	page.size = Vector2(1200, 700)
	check(page.world_to_uv(city.to_global(Vector3(-5000, 0, -3500))).is_equal_approx(Vector2.ZERO), "Northwest map corner must map to zero after city transform")
	check(page.world_to_uv(city.to_global(Vector3(2200, 0, 3000))).is_equal_approx(Vector2.ONE), "Southeast map corner must map to one")
	var prison := Vector3(300, 15, 2400)
	var uv: Vector2 = page.world_to_uv(city.to_global(prison))
	check(uv.is_equal_approx(Vector2(5300.0 / 7200.0, 5900.0 / 6500.0)), "Prison island uses exported world bounds")
	check(uv.is_equal_approx(page.world_to_uv(city.to_global(prison + Vector3.UP * 1000))), "Flight altitude must not shift map position")
	player.global_position = city.to_global(Vector3(-1400, 50, -250))
	for viewport_size in [Vector2(1200, 700), Vector2(700, 1000)]:
		page.size = viewport_size
		page.reset_view()
		var rect: Rect2 = page.map_rect()
		check(is_equal_approx(rect.size.x / rect.size.y, 7200.0 / 6500.0), "Map must retain geographic aspect ratio")
		check(page.marker_position().is_equal_approx(rect.get_center()), "World midpoint marker must align with letterboxed map midpoint")
		page.zoom = 3.0
		page.pan = Vector2(73, -29)
		check(page.marker_position().is_equal_approx(page.map_rect().get_center()), "Zoom and pan must affect map and marker together")
	page.free()
	player.free()
	city.free()
	print("REGION_MAP_TEST: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)
