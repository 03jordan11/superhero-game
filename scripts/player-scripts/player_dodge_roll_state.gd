extends PlayerState
## Ground-only roll. Physics moves the body; the library clip supplies the pose.
@export_range(0.2, 2.0, 0.05) var duration := 0.6
@export_range(1.0, 15.0, 0.25) var distance := 6.0
@export_range(0.01, 1.0, 0.01) var stamina_fraction := 0.10
@export var minimum_moving_speed := 0.1
var elapsed := 0.0
var direction := Vector3.ZERO


func can_enter(_previous: PlayerState, _context: Dictionary = {}) -> bool:
	return player.is_on_floor() and not (
		player.is_dodging or player.is_dead or player.is_knocked_out
		or player.is_flying or player.is_ground_slamming or player.is_wall_running
		or player.is_charging_jump or player.is_charging_flight or player.is_carrying()
		or player.hostile_grab.owns_animation() or player.ship_interaction.is_attached()
		or player.combat_controller.is_action_locked()
	) and Vector2(player.velocity.x, player.velocity.z).length() > minimum_moving_speed \
		and player.stamina.current >= player.stamina.maximum * stamina_fraction \
		and player.character_animation_player.has_animation("Dodge_Roll")


func enter(_previous: PlayerState, _context: Dictionary = {}) -> void:
	direction = Vector3(player.velocity.x, 0, player.velocity.z).normalized()
	elapsed = 0.0
	player.is_dodging = true
	player.stamina.spend_fraction(stamina_fraction)
	player.combat_controller.cancel_punch()
	player.laser_eyes.cancel_input()
	player.bounding_controller.reset()
	player.status_effects.hit_slowdown_remaining = 0.0
	player.animation_controller.is_hit_reacting = false
	player.animation_controller.is_playing_landing_animation = false
	_face_roll_direction()
	var animation := player.character_animation_player
	animation.play("Dodge_Roll", 0.05, animation.get_animation("Dodge_Roll").length / duration)
	animation.seek(0.0, true)


func physics_update(delta: float, _input: PlayerInputSnapshot) -> void:
	# Ease out from a quick burst. Integrate the curve over this step so the
	# configured distance stays the same at any physics rate, including the end.
	var start := clampf(elapsed / duration, 0.0, 1.0)
	var end := clampf((elapsed + delta) / duration, 0.0, 1.0)
	var travel := distance * ((1.0 - start) * (1.0 - start) - (1.0 - end) * (1.0 - end))
	var speed := travel / maxf(delta, 0.000001)
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	player.velocity.y = -0.1 if player.is_on_floor() else player.velocity.y - player.gravity * delta
	elapsed += delta
	_face_roll_direction()


func post_physics_update(_delta: float, _input: PlayerInputSnapshot) -> void:
	if elapsed >= duration or not player.is_on_floor():
		state_machine.transition_to(&"GroundedState" if player.is_on_floor() else &"AirborneState")


func _face_roll_direction() -> void:
	player.ground_facing_yaw = atan2(-direction.x, -direction.z)
	player._apply_ground_facing_visual()


func exit(_next: PlayerState) -> void:
	player.is_dodging = false
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	player.character_animation_player.stop()
	player.animation_controller.was_on_floor = player.is_on_floor()
