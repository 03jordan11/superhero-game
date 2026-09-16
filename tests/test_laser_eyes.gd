extends SceneTree

class Target extends StaticBody3D:
	var damage := 0.0
	func apply_damage(info) -> bool:
		damage += info.amount
		return true

class TestCrowd extends Node3D:
	var _active: Node3D

var failures := 0
var player: PlayerCharacter
var laser: PlayerLaserEyes
var world: Node3D

func _initialize() -> void: run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func input(fire := false, aim := false) -> PlayerInputSnapshot:
	var snapshot := PlayerInputSnapshot.new()
	snapshot.activate_power_pressed = fire
	snapshot.aim_power_pressed = aim
	return snapshot

func target_at(point: Vector3, size: Vector3) -> Target:
	var target := Target.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	target.add_child(collision)
	world.add_child(target)
	target.position = point
	return target

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	player = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	player.set_process_input(false)
	player.global_position = Vector3(0, 1, 0)
	laser = player.laser_eyes
	var hud := player.get_node("GameplayHUD")
	var powers := player.get_node("PlayerPowerController")
	laser.update_power(0.1, input(true, true))
	check(not laser.firing and laser.heat == 0.0 and not hud.get_node("LaserReticle").visible, "Locked core cannot fire or aim")
	powers.progression.apply_save_data({"schema_version": 2, "upgrades": {"laser_eyes": 0, "flight": 0}})
	check(player.abilities.is_unlocked(PlayerAbilities.LASER_EYES) and not powers.progression.is_implemented("laser_eyes", 1), "Only the core is implemented")
	laser.update_power(0.1, input())
	var base_fov := player.camera.fov
	laser.update_power(0.5, input(false, true))
	check(player.camera.fov < base_fov and hud.get_node("LaserReticle").visible and laser.heat == 0, "Aim zooms and shows reticle without firing")
	laser.update_power(1.0, input())
	check(is_equal_approx(player.camera.fov, base_fov) and not hud.get_node("LaserReticle").visible, "Releasing aim restores camera")
	check(laser._head_bone >= 0 and laser.eye_positions()[0].distance_to(laser.eye_positions()[1]) > 0.02, "Beam origins use the animated head bone")
	player.camera.global_position = Vector3(0, 2, 4)
	player.camera.look_at(Vector3(0, 1.5, -10))
	var target := target_at(Vector3(0, 1.5, -10), Vector3(3, 3, 2))
	await physics_frame
	laser.update_power(0.2, input(true, false))
	check(not laser.firing and laser.heat == 0.0 and target.damage == 0.0, "Attack without aiming never fires the laser")
	laser.update_power(1.0, input(true, true))
	check(laser.firing and laser.aiming and is_equal_approx(target.damage, 25.0), "Aimed attack deals 25 damage per second to a ray target")
	check(laser.heat == 20.0 and hud.heat_bar.value == 20.0, "Beam fills the Heat meter at 20 percent per second")
	player.global_position += Vector3.RIGHT
	laser._process(0.016)
	var beam := laser._beams[0]
	check((beam.global_position - beam.global_basis.y * 0.5).is_equal_approx(laser.eye_positions()[0]), "Rendered beam stays attached to the eyes after player movement")
	player.global_position -= Vector3.RIGHT
	# A blocker near the player must intercept even with a third-person camera.
	var wall := target_at(Vector3(0, 1.5, -3), Vector3(4, 4, 0.3))
	await physics_frame
	laser.update_power(0.5, input(true, true))
	check(is_equal_approx(target.damage, 25.0) and is_equal_approx(wall.damage, 12.5), "Beam stops on nearby cover")
	wall.free()
	laser.update_power(0.75, input(true, false))
	check(not laser.firing and not laser.aiming, "Releasing aim stops a held beam immediately")
	check(laser.heat == 30.0, "Passive cooling observes its release delay")
	laser.update_power(0.4, input())
	check(is_equal_approx(laser.heat, 20.0), "Passive cooling removes 25 percent per second")
	# Real static ground hits leave a bounded trail which self-expires.
	var ground := target_at(Vector3(0, -0.5, -12), Vector3(50, 1, 50))
	player.camera.look_at(Vector3(3, 0, -5))
	await physics_frame
	laser.update_power(0.1, input(true, true))
	check(not laser._marks.is_empty(), "Ground beam impact creates a black scorch stamp")
	laser.maximum_scorches = 8
	for i in 30: laser._stamp_trail(Vector3(i * 0.4, 0, -5), Vector3.UP, ground.get_instance_id())
	check(laser._marks.size() <= 8, "Scorch count is bounded during continuous trails")
	var mark: MeshInstance3D = laser._marks.back()
	mark.call("_process", 16.0)
	check(mark.is_queued_for_deletion(), "Scorch marks expire")
	# Distant civilians also intercept beams and receive the overheat blast.
	var crowd := TestCrowd.new()
	crowd._active = Node3D.new()
	crowd.add_child(crowd._active)
	var lod := preload("res://scripts/npc-scripts/civilian_capsule_lod.gd").new()
	crowd.add_child(lod)
	world.add_child(crowd)
	var civilian := lod.create_capsule(-1)
	crowd._active.add_child(civilian)
	civilian.position = Vector3(0, 0, -5)
	var hit := laser._raycast(Vector3(0, 0.9, -1), Vector3(0, 0.9, -15))
	check(not hit.is_empty() and hit.collider == civilian, "Lightweight civilians participate in beam targeting")
	check(laser._raycast(Vector3(0, 0.9, -1), Vector3(0, 0.9, -3)).is_empty(), "Civilian targeting respects maximum range and occlusion")
	# Overheat at exactly five seconds, using MAX health and flooring the cost.
	laser.heat = 0
	laser.update_power(1.0, input())
	player.damage_receiver.set_max_health(1003)
	player.damage_receiver.health_component.current_health = 800
	player.state_machine.transition_to(&"FlyingState")
	player.velocity = Vector3.UP * 50
	var nearby := target_at(Vector3(3, 1, 0), Vector3.ONE)
	var outside := target_at(Vector3(20, 1, 0), Vector3.ONE)
	player.camera.look_at(Vector3(0, 4, -100))
	await physics_frame
	for i in 49: laser.update_power(0.1, input(true, true))
	check(not laser.overheated, "Beam does not overheat before five seconds")
	laser.update_power(0.1, input(true, true))
	check(laser.overheated and laser.heat == 100 and not laser.firing, "Five seconds reaches overheat and stops the beam")
	check(player.get_current_health() == 500, "Overheat subtracts floor(1003 * .3) from current health")
	check(player.is_knocked_out and not player.is_flying and player.velocity.y <= 0, "Overheat cancels flight and upward momentum")
	check(nearby.damage == 75 and outside.damage == 0, "Overheat damages nearby objects and respects blast radius")
	check(not civilian.pending_damage.is_empty(), "Overheat damages lightweight civilians")
	check(is_instance_valid(player) and not player.is_queued_for_deletion(), "Explosion never deletes the player")
	check(get_nodes_in_group(&"debug_explosion_effects").size() == 1, "Overheat reuses the existing explosion effect")
	player.state_machine.physics_update(0.2, PlayerInputSnapshot.new())
	check(player.velocity.y < 0, "Knockdown applies gravity after overheat")
	for i in 6: laser.update_power(1.0, input(true, true))
	check(player.get_current_health() == 500 and laser.heat == 0 and not laser.overheated, "Overheat triggers once and cools while the fire button remains held")
	player.state_machine.transition_to(&"GroundedState")
	laser.update_power(0.1, input(true, true))
	check(not laser.firing, "After overheating, release is required before firing again")
	laser.update_power(0.1, input())
	laser.update_power(0.1, input(true, true))
	check(laser.firing, "Fully cooled beam can fire again after release")
	laser.cancel_input()
	laser.update_power(0.1, input(true, true))
	check(not laser.firing and laser.aiming, "Input reset cancels beam and requires release")
	var page = load("res://scenes/ui/powers_page.tscn").instantiate()
	# Route the first click using live aim input, before a physics snapshot exists.
	player.velocity = Vector3.DOWN
	player.move_and_slide()
	check(player.is_on_floor(), "Combat routing fixture has real floor contact")
	Input.action_press("aim_power")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	player._profiled_input(click)
	check(not player.combat_controller.is_action_locked(), "Aimed left click cannot punch")
	player.state_machine.transition_to(&"FlyingState")
	player._profiled_input(click)
	check(not player.is_ground_slamming and player.is_flying, "Aimed left click does not exit flight into a slam")
	player.state_machine.transition_to(&"GroundedState")
	Input.action_release("aim_power")
	player._profiled_input(click)
	check(player.combat_controller.is_action_locked(), "Left click without aim still punches")
	player.combat_controller.cancel_punch()
	page.progression = powers.progression
	world.add_child(page)
	page.select_power("laser_eyes")
	check(not page.implementation_label.text.contains("This branch") and page.upgrade_states[0].text.contains("PLANNED"), "Core UI is available while upgrades stay planned")
	world.free()
	print("Laser Eyes: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
