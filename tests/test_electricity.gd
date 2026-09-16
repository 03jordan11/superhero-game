extends SceneTree
class Target extends StaticBody3D:
	var damage := 0.0
	var electric_damage := 0.0
	func apply_damage(info) -> bool:
		damage += info.amount
		if info.damage_type == &"electricity": electric_damage += info.amount
		return true
class TestCrowd extends Node3D:
	var _active: Node3D
var failures := 0
var world: Node3D
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func input(held := false, aim := true) -> PlayerInputSnapshot:
	var value := PlayerInputSnapshot.new()
	value.activate_power_pressed = held
	value.aim_power_pressed = aim
	return value
func target(position: Vector3, size := Vector3(2, 3, 0.2)) -> Target:
	var body := Target.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	world.add_child(body)
	body.position = position
	return body
func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	var player: PlayerCharacter = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	player.position.y = 1.0
	player.set_physics_process(false)
	player.set_process_input(false)
	var powers := player.get_node("PlayerPowerController")
	var shared := player.laser_eyes
	var electric: PlayerElectricity = player.get_node("PlayerElectricity")
	var hud := player.get_node("GameplayHUD")
	powers.select_active_power(&"electricity")
	shared.update_power(0.1, input())
	shared.update_power(0.5, input(true))
	check(not electric.firing and not shared.aiming and shared.heat == 0, "Locked Electricity cannot aim, fire or heat")
	var progression = preload("res://scripts/ui-scripts/power_menu_progression.gd").new()
	progression.add_tokens(1)
	check(progression.purchase("electricity") and progression.tokens == 0, "Electric core is purchasable for one token")
	powers.progression.apply_save_data(progression.to_save_data())
	check(player.abilities.is_unlocked(PlayerAbilities.ELECTRICITY) and not player.abilities.is_unlocked(PlayerAbilities.LASER_EYES), "Purchased Electricity survives save restoration independently of Laser Eyes")
	for tier in [1, 2, 3]: check(not powers.progression.is_implemented("electricity", tier), "Electric upgrades remain planned")
	shared.update_power(0.1, input())
	check(shared.aiming and hud.get_node("Heat").visible and hud.get_node("LaserReticle").visible, "Electricity has aim and shared heat UI")
	check(not hud.get_node("ActivePower").text.contains("NOT IMPLEMENTED"), "Equipped Electricity no longer appears as a placeholder")
	player.camera.top_level = true
	player.camera.global_position = Vector3(0, 2, 4)
	player.camera.look_at(Vector3(0, 1.5, -10))
	var victim := target(Vector3(0, 1.5, -10))
	await physics_frame
	shared.update_power(0.5, input(true, false))
	check(not electric.firing and victim.damage == 0, "Attack without aim does not shock")
	shared.update_power(1.0, input(true))
	check(electric.firing and not shared.firing and victim.electric_damage == 30 and shared.heat == 20, "One second deals 30 Electric damage and adds 20 Heat without laser beams")
	check(electric._hand_bone >= 0 and electric._arc.visible, "Lightning originates from the animated hand")
	var old_origin := electric._arc.global_position
	player.position.x += 0.5
	electric._process(0.016)
	check(electric._arc.global_position.distance_to(old_origin) > 0.4, "Visual arc follows the player between physics ticks")
	player.position.x -= 0.5
	# Camera is beyond this wall, but the hand must still strike the wall.
	var wall := target(Vector3(0, 1.5, -3), Vector3(5, 5, 0.2))
	player.camera.global_position = Vector3(0, 2, -4)
	player.camera.look_at(Vector3(0, 1.5, -10))
	await physics_frame
	shared.update_power(0.5, input(true))
	check(victim.damage == 30 and wall.electric_damage == 15 and electric.last_hit.collider == wall, "Cover blocks the hand ray even if the camera sees beyond it")
	wall.free()
	shared.update_power(0.1, input())
	check(not electric.firing and not electric._arc.visible, "Release immediately hides the arc and stops damage")
	shared.update_power(0.65, input())
	check(shared.heat == 30, "Shared cooling waits 0.75 seconds after shock")
	shared.update_power(0.4, input())
	check(is_equal_approx(shared.heat, 20), "Shared cooling removes 25 Heat/sec")
	victim.free()
	player.camera.global_position = Vector3(0, 2, 4)
	player.camera.look_at(Vector3(0, 1.5, -45))
	var far := target(Vector3(0, 1.5, -45))
	await physics_frame
	shared.update_power(0.1, input(true))
	check(far.damage == 0 and electric.last_hit.is_empty() and electric._target.distance_to(electric.hand_position()) <= 30.001, "Shock misses beyond its hand-relative 30m range")
	check(shared.heat > 20, "Missed shocks still consume Heat")
	far.free()
	# Lightweight civilian targeting uses the same occlusion-aware ray lookup.
	var crowd := TestCrowd.new()
	crowd._active = Node3D.new()
	crowd.add_child(crowd._active)
	var lod := preload("res://scripts/npc-scripts/civilian_capsule_lod.gd").new()
	crowd.add_child(lod)
	world.add_child(crowd)
	var civilian := lod.create_capsule(-1)
	crowd._active.add_child(civilian)
	civilian.position = Vector3(0, 0, -8)
	player.camera.look_at(Vector3(0, 0.9, -8))
	await physics_frame
	shared.update_power(0.2, input(true))
	check(civilian.pending_damage.size() == 1 and civilian.pending_damage[0].damage_type == &"electricity" and is_equal_approx(civilian.pending_damage[0].amount, 6), "Distant civilian receives exactly one Electric damage tick")
	crowd.free()
	var heat_before := shared.heat
	powers.select_active_power(&"fire")
	check(not electric.firing and shared.heat == heat_before, "Switching powers cancels lightning and preserves Heat")
	shared.update_power(0.1, input(true))
	check(not electric.firing, "Another equipped power cannot leak an electric attack")
	powers.select_active_power(&"electricity")
	shared.update_power(0.1, input(true))
	check(not electric.firing, "Switching back requires release")
	shared.update_power(0.1, input())
	shared.update_power(0.1, input(true))
	player.get_node("PowerSelector/Wheel").open()
	check(not electric.firing and not electric._arc.visible, "Opening selector cancels the effect immediately")
	player.get_node("PowerSelector/Wheel").close(true)
	shared.update_power(0.1, input(true))
	check(not electric.firing, "Held attack cannot escape the selector")
	# Different tick sizes produce identical damage; then test final overheat interval.
	victim = target(Vector3(0, 1.5, -10))
	player.camera.look_at(victim.position)
	await physics_frame
	for step in [0.1, 0.05]:
		shared.heat = 0
		shared.update_power(0.1, input())
		victim.electric_damage = 0
		for i in roundi(1.0 / step): shared.update_power(step, input(true))
		check(is_equal_approx(victim.electric_damage, 30) and is_equal_approx(shared.heat, 20), "Electric damage and Heat are frame-rate independent")
	powers.progression.apply_save_data({"upgrades": {"electricity": 0, "flight": 0}})
	shared.update_power(0.1, input())
	shared.heat = 99
	victim.electric_damage = 0
	player.state_machine.transition_to(&"FlyingState")
	var health := player.get_current_health()
	shared.update_power(0.5, input(true))
	check(is_equal_approx(victim.electric_damage, 1.5), "Final damage tick clamps to time left before overheat")
	check(shared.overheated and player.is_knocked_out and not player.is_flying and not electric.firing and not electric._arc.visible, "Overheat cancels shock and flight")
	check(player.get_current_health() == health - floorf(player.get_max_health() * 0.3), "Electric overheat applies the exact shared health cost")
	shared.update_power(5.0, input(true))
	player.state_machine.transition_to(&"GroundedState")
	shared.update_power(0.1, input(true))
	check(not shared.overheated and not electric.firing, "Cooled Electricity still requires attack release")
	shared.update_power(0.1, input())
	shared.update_power(0.1, input(true))
	check(electric.firing, "Shock works again after full cooling and release")
	powers.progression.apply_save_data({"upgrades": {"electricity": -1}})
	check(not electric.firing and not player.abilities.is_unlocked(PlayerAbilities.ELECTRICITY), "Loading a locked save cancels the power")
	await process_frame
	world.free()
	print("ELECTRICITY_TESTS: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
