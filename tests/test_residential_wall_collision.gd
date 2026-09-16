extends SceneTree
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value: failures+=1; push_error(message)
func run() -> void:
	var world:=Node3D.new(); root.add_child(world)
	for i in range(1,21):
		var building: StaticBody3D=load("res://assets/generated-buildings/residential/residential_building_%02d.tscn"%i).instantiate()
		building.seeded_window_patterns=false; building.position.x=i*100
		world.add_child(building)
	var runner:=CharacterBody3D.new(); runner.collision_layer=2; runner.collision_mask=1
	var capsule:=CollisionShape3D.new(); capsule.shape=CapsuleShape3D.new()
	runner.add_child(capsule); world.add_child(runner)
	var motor: Node=load("res://scripts/player-scripts/player_movement_motor.gd").new()
	runner.add_child(motor)
	await physics_frame; await physics_frame
	var sweeps:=0; var volumes:=0
	for building in world.get_children():
		if building==runner: continue
		for node in building.get_children():
			if not node is CollisionShape3D: continue
			check(node.shape is BoxShape3D,"Unexpected mesh collision")
			if not str(node.name).begins_with("TierCollision") and node.name!=&"CollisionShape3D": continue
			volumes+=1
			var center: Vector3=node.global_position; var half: Vector3=node.shape.size/2
			# Hollow triangle shells do not report this interior overlap; boxes must.
			var query:=PhysicsShapeQueryParameters3D.new(); query.shape=SphereShape3D.new(); query.shape.radius=.1
			query.transform.origin=center; query.collision_mask=1
			check(not world.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"Building interior must be solid")
			for normal in [Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.RIGHT]:
				var distance: float=half.z if normal.z!=0 else half.x
				var plane: Vector3=center+normal*distance
				query.transform.origin=plane+normal*.55
				# A face between two joined wings is not an exterior wall.
				if not world.get_world_3d().direct_space_state.intersect_shape(query).is_empty(): continue
				for speed in [12.0,120.0]:
					runner.position=plane+normal*.501
					runner.position.y=center.y-half.y+1.2
					for step in 30:
						if runner.position.y>center.y+half.y-1.2: break
						runner.velocity=motor.get_wall_run_velocity(normal,Vector3.RIGHT,0,speed,1,8,1,1)
						runner.move_and_slide()
						if runner.position.y<center.y+half.y-1.0:
							check((runner.position-plane).dot(normal)>=.45,"Wall-run capsule crossed %s/%s %s at %s"%[building.name,node.name,normal,runner.position])
						sweeps+=1
				# Allow up to 5cm contact/recovery tolerance for the 0.5m-radius capsule.
				# High inward movement must still hit the wall rather than enter the volume.
				runner.position=plane+normal*2; runner.position.y=center.y
				var hit:=runner.move_and_collide(-normal*20)
				check(hit!=null and (runner.position-plane).dot(normal)>=.45,"Fast wall approach tunneled: %s/%s %s at %s"%[building.name,node.name,normal,runner.position])
	print("WALL_COLLISION_PASS: ",volumes," solid tier volumes, ",sweeps," upward capsule steps at 12/120 m/s, interior overlap and fast approach checks; failures=",failures)
	world.free(); quit(1 if failures else 0)
