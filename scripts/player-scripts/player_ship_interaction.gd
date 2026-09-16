extends Node
var encounter: Node
@onready var player: PlayerCharacter=get_parent()
func is_attached() -> bool:
	return is_instance_valid(encounter) and encounter.active_end>=0
func handle_input(delta: float, input: PlayerInputSnapshot) -> bool:
	if is_attached():
		if player.is_dead or player.is_knocked_out or encounter.state!=BaseEncounter.EncounterState.ACTIVE:
			release(); return false
		if encounter.active_method==&"push" and not player.is_flying:
			release(); return false
		if input.vehicle_interact_just_pressed:
			release(); return true
		encounter.effort=input.movement.y<-.1 if encounter.active_method==&"push" else input.movement.y>.1
		player.velocity=Vector3.ZERO
		player.global_position=encounter.attachment_position()
		var direction: Vector3=encounter.attachment_direction()
		player.superhero_character.global_basis=Basis.looking_at(-direction,Vector3.UP)
		player.animation_controller._play_animation("Ship_Effort" if encounter.effort else "Flight_Hover" if encounter.active_method==&"push" else "Idle")
		player.laser_eyes.update_power(delta,PlayerInputSnapshot.new())
		return true
	if not input.vehicle_interact_just_pressed or player.is_dead or player.is_knocked_out or player.is_carrying() or player.combat_controller.is_action_locked(): return false
	if player.is_charging_jump or player.is_ground_slamming or player.is_wall_running: return false
	for candidate in get_tree().get_nodes_in_group(&"ship_docking"):
		var contact: Dictionary=candidate.nearest_interaction(player)
		if contact.is_empty(): continue
		encounter=candidate; encounter.attach(contact.end,contact.method)
		player.combat_controller.cancel_punch(); player.laser_eyes.cancel_input(); player.flying_state.cancel_charge()
		player.flying_state.surge_remaining=0.0; player.flying_state.is_boosting=false
		player.current_flight_speed=0.0
		player.velocity=Vector3.ZERO; player.global_position=encounter.attachment_position()
		return true
	return false
func release() -> void:
	if is_instance_valid(encounter): encounter.detach()
	encounter=null
	if is_instance_valid(player): player.velocity=Vector3.ZERO
