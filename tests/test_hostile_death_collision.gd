extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(30, 1, 30)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	var probe := CharacterBody3D.new()
	probe.collision_mask = 2 # Check enemy collision independently of the floor.
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	probe.add_child(shape)
	world.add_child(probe)
	for kind in ["pistol", "rifle", "melee", "super"]:
		var enemy := load("res://scenes/npcs/%s_thug.tscn" % kind).instantiate() as HostileBase
		enemy.collision_layer = 2
		world.add_child(enemy)
		enemy.set_physics_process(false)
		await physics_frame
		await physics_frame
		var side := Transform3D(Basis.IDENTITY, Vector3(0, 1, 3))
		var above := Transform3D(Basis.IDENTITY, Vector3(0, 4, 0))
		check(probe.test_move(side, Vector3(0, 0, -5)), "Living %s blocks horizontal movement" % kind)
		check(probe.test_move(above, Vector3(0, -5, 0)), "Living %s has a standing collider" % kind)
		enemy._die()
		await process_frame
		await physics_frame
		await physics_frame
		check(enemy.get_node("CollisionShape3D").disabled, "%s death disables capsule" % kind)
		check(not probe.test_move(side, Vector3(0, 0, -5)), "Can walk through dead %s" % kind)
		check(not probe.test_move(above, Vector3(0, -5, 0)), "Cannot stand on dead %s" % kind)
		check(not enemy.is_physics_processing() and enemy.velocity == Vector3.ZERO, "Corpse cannot fall through ground after disabling collision")
		check(enemy.animation_controller.animation_player.current_animation == "Death01", "Death animation is preserved")
		enemy.free()
	var airborne := preload("res://scenes/npcs/melee_thug.tscn").instantiate()
	airborne.position = Vector3(5, 4, 0)
	world.add_child(airborne)
	airborne._die()
	for tick in 120:
		await physics_frame
	check(absf(airborne.position.y) < 0.05 and not airborne.is_physics_processing(), "Airborne corpse falls and settles on the floor without a capsule")
	world.free()
	print("Hostile death collision: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
