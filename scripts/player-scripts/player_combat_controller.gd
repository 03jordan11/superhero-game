class_name PlayerCombatController
extends Node

const PUNCH_ANIMATIONS := ["Punch_01", "Punch_02", "Punch_03"]
const UPPERCUT_PUNCH_INDEX := 2
const DAMAGE_INFO_SCRIPT = preload("res://scripts/combat-scripts/damage_info.gd")
const CHARGE_WIND_SCRIPT = preload("res://effects/charge_punch_wind.gd")

var animation_controller: PlayerAnimationController
signal combo_punch_started(punch_index: int)
signal charge_punch_impact
signal charge_punch_sound_started

@export_category("Charged Punch")
@export_range(0.05, 1.0, 0.01) var charge_start_delay := 0.25
## Total time holding attack, including the tap/hold threshold.
@export_range(0.3, 3.0, 0.05) var charge_full_time := 1.0
@export var charge_range := 10.0
@export_range(1.0, 180.0, 1.0) var charge_cone_degrees := 60.0
@export var charge_near_distance := 2.0
@export var charge_max_damage := 100.0
@export var charge_min_damage := 30.0
@export var charge_windup_duration := 0.4
@export var charge_impact_delay := 0.2
@export var charge_recovery_duration := 0.7
## Seconds into the release animation. Zero starts audio as the fist drives forward.
@export_range(0.0, 0.5, 0.01) var charge_sound_delay := 0.0
@export_group("Charged Punch Wind")
@export var charge_wind_enabled := true
@export_range(0.1, 1.0, 0.01) var charge_wind_duration := 0.45
@export var charge_wind_color := Color(0.82, 0.91, 1.0, 0.5)
enum ChargePhase { NONE, WINDUP, HOLD, RELEASE }
var charge_phase: ChargePhase = ChargePhase.NONE
var attack_pending := false
var attack_hold_time := 0.0
var charge_phase_time := 0.0
var released_charge := 0.0
var _charge_hit := false
var _charge_sound_played := false

@export_category("Regular Punches")
@export var punch_forward_speed: float = 8.0
@export var punch_forward_delay: float = 0.25
@export var punch_forward_duration: float = 0.08
@export var punch_hit_delay: float = 0.2
@export var punch_hit_distance: float = 2.0
@export var punch_hit_radius: float = 0.75
@export var regular_hit_damage_multiplier: int = 2
@export_range(0.0, 1.0, 0.01) var combo_input_window: float = 0.6
## Keep at most one follow-up click, even during early wind-up or dash travel.
@export var buffer_early_combo_input: bool = true
@export var uppercut_launch_velocity: float = 6.0
@export var uppercut_launch_delay: float = 0.25
@export var uppercut_forward_speed: float = 14.0
@export var uppercut_forward_duration: float = 0.15

@export_category("Opening Punch Dash")
@export var opening_dash_enabled:=true
@export var opening_dash_speed:=75.0
@export var opening_dash_max_distance:=60.0
@export var opening_dash_timeout:=1.1
@export var opening_dash_max_height_difference:=1.5
@export var opening_dash_floor_grace:=0.15
## Aim inside arrival range so a retreating enemy cannot keep the wind-up paused.
@export_range(0.05, 0.5, 0.05) var opening_dash_arrival_margin:=0.25
var is_opening_dash:=false
var _dash_target: HostileBase
var _dash_elapsed:=0.0
var _dash_airborne_time:=0.0

var punch_time: float = 0.0
var is_punch_active: bool = false
var combo_punch_index: int = 0
var is_next_punch_queued: bool = false
var has_uppercut_launched: bool = false
var has_punch_hit: bool = false

func setup(target_animation_controller: PlayerAnimationController) -> void:
	animation_controller = target_animation_controller


func request_punch() -> void:
	if charge_phase != ChargePhase.NONE: return
	if animation_controller == null:
		return
	var player := get_parent() as PlayerCharacter
	if player != null and player.hostile_grab != null and player.hostile_grab.owns_animation(): return
	if player != null and (player.is_charging_jump or player.is_charging_flight):
		return

	if not is_punch_active:
		_start_punch(0,true)
	elif is_opening_dash or buffer_early_combo_input or animation_controller.is_current_animation_in_final_window(combo_input_window):
		is_next_punch_queued = true


func is_action_locked() -> bool:
	return is_punch_active or charge_phase != ChargePhase.NONE


func cancel_punch(clear_charge_input: bool = true) -> void:
	if clear_charge_input: cancel_charge_input()
	if is_opening_dash:
		var body:=get_parent() as CharacterBody3D
		if body != null: body.velocity.x=0; body.velocity.z=0
	is_opening_dash=false; _dash_target=null; _dash_elapsed=0
	is_punch_active = false
	is_next_punch_queued = false
	has_uppercut_launched = false
	has_punch_hit = false
	punch_time = 0.0


func update_punch_momentum(
	body: CharacterBody3D,
	delta: float,
	strength: int,
	movement_speed_multiplier: float = 1.0
) -> void:
	_update_charge(body, delta)
	if charge_phase != ChargePhase.NONE: return
	if not is_punch_active:
		return
	if is_opening_dash:
		_update_opening_dash(body,delta,movement_speed_multiplier)
		return

	if animation_controller.has_current_animation_finished():
		if is_next_punch_queued:
			_start_punch((combo_punch_index + 1) % PUNCH_ANIMATIONS.size())
		else:
			# A fresh press near the combo's end still needs its tap/hold decision.
			cancel_punch(false)
		return

	punch_time += delta
	if not has_punch_hit and punch_time >= punch_hit_delay:
		has_punch_hit = _try_hit_target(body, strength)

	var push_end_time := punch_forward_delay + punch_forward_duration
	if punch_time >= punch_forward_delay and punch_time <= push_end_time:
		var forward := -body.transform.basis.z.normalized()
		body.velocity.x = forward.x * punch_forward_speed * movement_speed_multiplier
		body.velocity.z = forward.z * punch_forward_speed * movement_speed_multiplier

	_apply_uppercut_motion(body, movement_speed_multiplier)


func begin_attack() -> void:
	if attack_pending or charge_phase != ChargePhase.NONE: return
	var player := get_parent() as PlayerCharacter
	if player == null: return
	# Contexts without charging (including airborne combo follow-ups and car
	# carrying) keep their original immediate regular-punch behavior.
	if not _charge_allowed(player):
		request_punch()
		return
	attack_pending = true
	attack_hold_time = 0.0


func release_attack() -> void:
	if not attack_pending: return
	var player := get_parent() as PlayerCharacter
	if player == null or not _charge_allowed(player):
		cancel_charge_input()
		return
	attack_pending = false
	if charge_phase == ChargePhase.NONE:
		request_punch()
		return
	if charge_phase not in [ChargePhase.WINDUP, ChargePhase.HOLD]: return
	released_charge = clampf((attack_hold_time - charge_start_delay) / maxf(charge_full_time - charge_start_delay, 0.01), 0.0, 1.0)
	# Complete the rear-back motion even if released just after the threshold.
	if charge_phase == ChargePhase.HOLD: _release_charged_punch()


func cancel_charge_input() -> void:
	attack_pending = false
	attack_hold_time = 0.0
	charge_phase = ChargePhase.NONE
	charge_phase_time = 0.0
	released_charge = 0.0
	_charge_hit = false
	_charge_sound_played = false


func _charge_allowed(player: PlayerCharacter) -> bool:
	return (
		player.abilities.is_unlocked(PlayerAbilities.CHARGED_PUNCH)
		and not player.is_dead and not player.is_knocked_out
		and player.is_on_floor() and not player.is_flying
		and not player.is_charging_jump and not player.is_charging_flight
		and not player.is_ground_slamming and not player.is_wall_running
		and not player.is_carrying() and not player.hostile_grab.owns_animation()
		and not player.input_controller.is_power_aim_requested()
		and not player.ship_interaction.is_attached()
	)


func _update_charge(body: CharacterBody3D, delta: float) -> void:
	if not attack_pending and charge_phase == ChargePhase.NONE: return
	var player := body as PlayerCharacter
	if player == null or not _charge_allowed(player):
		cancel_charge_input()
		return
	if attack_pending:
		attack_hold_time += delta
		if charge_phase == ChargePhase.NONE and attack_hold_time >= charge_start_delay:
			# Replace a buffered combo only once the player deliberately holds.
			var held_time := attack_hold_time
			cancel_punch()
			attack_pending = true
			attack_hold_time = held_time
			charge_phase = ChargePhase.WINDUP
			if not animation_controller.play_combat_animation("AuthoredCombo/Hero_ChargePunchWindup"):
				cancel_charge_input()
			return
	if charge_phase == ChargePhase.NONE: return
	body.velocity.x = 0.0
	body.velocity.z = 0.0
	charge_phase_time += delta
	if charge_phase == ChargePhase.WINDUP and charge_phase_time >= charge_windup_duration:
		if not attack_pending:
			_release_charged_punch()
		else:
			charge_phase = ChargePhase.HOLD
			charge_phase_time = 0.0
			animation_controller.play_combat_animation("AuthoredCombo/Hero_ChargePunchHold")
	elif charge_phase == ChargePhase.RELEASE:
		_update_charge_sound()
		if not _charge_hit and charge_phase_time >= charge_impact_delay:
			_charge_hit = true
			_apply_charge_cone(body)
			_spawn_charge_wind(body)
			charge_punch_impact.emit()
		# Time-based recovery prevents an interrupted animation trapping combat.
		if charge_phase_time >= maxf(charge_recovery_duration, charge_impact_delay):
			cancel_charge_input()


func _release_charged_punch() -> void:
	charge_phase = ChargePhase.RELEASE
	charge_phase_time = 0.0
	_charge_hit = false
	if not animation_controller.play_combat_animation("AuthoredCombo/Hero_ChargePunchRelease"):
		cancel_charge_input()
		return
	_update_charge_sound()


func _update_charge_sound() -> void:
	if not _charge_sound_played and charge_phase_time >= charge_sound_delay:
		_charge_sound_played = true
		charge_punch_sound_started.emit()


func _spawn_charge_wind(body: CharacterBody3D) -> void:
	if not charge_wind_enabled: return
	var wind := CHARGE_WIND_SCRIPT.new()
	body.get_parent().add_child(wind)
	var origin := Transform3D(body.global_basis.orthonormalized(), body.global_position + Vector3.UP * 0.5)
	wind.configure(origin, charge_range, charge_cone_degrees, charge_wind_duration, charge_wind_color, released_charge)


func charge_damage_at_distance(distance: float, power: float) -> float:
	var falloff := clampf((distance - charge_near_distance) / maxf(charge_range - charge_near_distance, 0.01), 0.0, 1.0)
	var full_damage := lerpf(charge_max_damage, charge_min_damage, falloff)
	return lerpf(charge_min_damage, full_damage, clampf(power, 0.0, 1.0))


func _apply_charge_cone(body: CharacterBody3D) -> void:
	var origin := body.global_position + Vector3.UP * 0.5
	var forward := -body.global_basis.z.normalized()
	var minimum_dot := cos(deg_to_rad(charge_cone_degrees * 0.5))
	# One candidate pass at impact; no persistent areas or per-frame enemy scans.
	var candidates := get_tree().get_nodes_in_group(&"hostile")
	var excluded: Array[RID] = [body.get_rid()]
	for node in candidates:
		if node is CollisionObject3D: excluded.append(node.get_rid())
	for node in candidates:
		var enemy := node as HostileBase
		if enemy == null or enemy.is_dead or enemy.is_grabbed: continue
		var offset := enemy.global_position + Vector3.UP - origin
		var distance := offset.length()
		if distance > charge_range or (distance > 0.001 and forward.dot(offset / distance) < minimum_dot): continue
		# Other enemies don't shield a whole crowd from the cone, but walls do.
		if not _clear_to_body(body, enemy, excluded): continue
		var damage = DAMAGE_INFO_SCRIPT.new(charge_damage_at_distance(distance, released_charge), origin, forward, &"knockback", body)
		damage.damage_type = &"melee"
		# Respect NPC knockback_resistant, including supers; never force knockdown.
		enemy.apply_damage(damage)


func _apply_uppercut_motion(body: CharacterBody3D, movement_speed_multiplier: float) -> void:
	if combo_punch_index != UPPERCUT_PUNCH_INDEX:
		return
	if punch_time < uppercut_launch_delay:
		return

	if not has_uppercut_launched:
		body.velocity.y = maxf(body.velocity.y, uppercut_launch_velocity)
		has_uppercut_launched = true

	if punch_time > uppercut_launch_delay + uppercut_forward_duration:
		return

	var forward := -body.transform.basis.z.normalized()
	body.velocity.x = forward.x * uppercut_forward_speed * movement_speed_multiplier
	body.velocity.z = forward.z * uppercut_forward_speed * movement_speed_multiplier


func _start_punch(punch_index: int, allow_opening_dash: bool=false) -> void:
	var animation_name: String = PUNCH_ANIMATIONS[punch_index]
	if not animation_controller.play_combat_animation(animation_name):
		return

	combo_punch_index = punch_index
	is_next_punch_queued = false
	has_uppercut_launched = false
	has_punch_hit = false
	punch_time = 0.0
	is_punch_active = true
	if allow_opening_dash and _begin_opening_dash(): return
	combo_punch_started.emit(punch_index)

func _begin_opening_dash() -> bool:
	var player:=get_parent() as PlayerCharacter
	if not opening_dash_enabled or player==null or not player.is_on_floor() or player.is_flying or not player.target_lock.has_target(): return false
	var person: HostileBase=player.target_lock.target
	var offset:=person.global_position-player.global_position
	var distance:=Vector2(offset.x,offset.z).length()
	if distance<=punch_hit_distance or distance>opening_dash_max_distance: return false
	if absf(offset.y+1.0)>opening_dash_max_height_difference or not _clear_to_body(player,person): return false
	_dash_target=person; _dash_elapsed=0; _dash_airborne_time=0; is_opening_dash=true
	# Hold the opening wind-up until arrival; hit timing starts at striking distance.
	animation_controller.animation_player.seek(.05,true)
	animation_controller.animation_player.pause()
	return true

func _update_opening_dash(body: CharacterBody3D, delta: float, _speed_multiplier: float) -> void:
	var player:=body as PlayerCharacter
	_dash_elapsed+=delta
	if not is_instance_valid(_dash_target) or _dash_target.is_dead or player==null or not player.target_lock.has_target() or player.target_lock.target!=_dash_target:
		cancel_punch(); return
	_dash_airborne_time=0.0 if player.is_on_floor() else _dash_airborne_time+delta
	if player.is_flying or player.is_dead or player.is_knocked_out or _dash_airborne_time>opening_dash_floor_grace or _dash_elapsed>opening_dash_timeout:
		cancel_punch(); return
	var offset:=_dash_target.global_position-body.global_position
	if absf(offset.y+1.0)>opening_dash_max_height_difference or not _clear_to_body(body,_dash_target):
		cancel_punch(); return
	offset.y=0
	var distance:=offset.length()
	if distance<=punch_hit_distance+.05:
		is_opening_dash=false; _dash_target=null
		body.velocity.x=0; body.velocity.z=0
		var queued:=is_next_punch_queued
		_start_punch(0) # Later combo openers never trigger another dash.
		is_next_punch_queued=queued
		return
	# A hit just before the click must not halve travel speed and cause timeout.
	# Arrival is checked on the next physics tick, after the enemy has also
	# moved. Stopping exactly at the threshold can chase a retreating target
	# forever at its walking speed while the punch animation remains paused.
	var stopping_distance:=maxf(punch_hit_distance-opening_dash_arrival_margin,0.1)
	var step:=minf(maxf(opening_dash_speed,0.0)*delta,distance-stopping_distance)
	var motion:=offset.normalized()*step
	if delta<=0: return
	var collision:=KinematicCollision3D.new()
	if body.test_move(body.global_transform,motion,collision) and collision.get_normal().y<.7:
		cancel_punch(); return
	# Stay on traversable ground; don't dash blindly off a rooftop or across water.
	var next:=body.global_position+motion
	var ray:=PhysicsRayQueryParameters3D.create(next+Vector3.UP*.5,next-Vector3.UP*2.0,1,[body.get_rid(),_dash_target.get_rid()])
	var floor_hit:=body.get_world_3d().direct_space_state.intersect_ray(ray)
	if floor_hit.is_empty() or floor_hit.normal.y<.7 or absf(floor_hit.position.y-(body.global_position.y-1.0))>.6:
		cancel_punch(); return
	body.velocity.x=motion.x/delta; body.velocity.z=motion.z/delta

func _clear_to_body(body: CharacterBody3D, other: Node3D, excluded: Array[RID] = []) -> bool:
	var point:=other.global_position+(Vector3.UP if other is CharacterBody3D else Vector3.ZERO)
	var ray:=PhysicsRayQueryParameters3D.create(body.global_position+Vector3.UP*.5,point,1,[body.get_rid()])
	if not excluded.is_empty(): ray.exclude = excluded
	var hit:=body.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.collider==other or other.is_ancestor_of(hit.collider)


func _try_hit_target(body: CharacterBody3D, strength: int) -> bool:
	# Extend the old sphere forward while preserving its close-range coverage.
	var hit_shape := CapsuleShape3D.new()
	hit_shape.radius = punch_hit_radius
	var extension:=maxf(punch_hit_distance-1.6,0.0)
	hit_shape.height=2.0*punch_hit_radius+extension
	var forward := -body.global_transform.basis.z.normalized()
	var impact_origin := body.global_position + Vector3.UP + forward * (punch_hit_distance-extension*.5)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = hit_shape
	query.transform = Transform3D(
		body.global_basis*Basis(Vector3.RIGHT,PI/2.0),
		impact_origin
	)
	query.exclude = [body.get_rid()]
	var hit_results: Array[Dictionary] = body.get_world_3d().direct_space_state.intersect_shape(query)
	var player:=body as PlayerCharacter
	if player!=null and player.target_lock.has_target():
		var preferred: Node3D=player.target_lock.target
		hit_results.sort_custom(func(a: Dictionary,b: Dictionary): return a.collider==preferred and b.collider!=preferred)

	for hit in hit_results:
		var collider: Object = hit.get("collider")
		if collider == null or not collider.has_method("apply_damage"):
			continue
		if collider is Node3D and not _clear_to_body(body,collider): continue

		var hit_reaction: StringName = (
			&"knockback" if combo_punch_index == UPPERCUT_PUNCH_INDEX else &"chest"
		)
		var damage: float = regular_hit_damage_multiplier * strength
		var is_explodable: bool = (
			collider is Node and (collider as Node).is_in_group(&"explodable")
		)
		if combo_punch_index == UPPERCUT_PUNCH_INDEX and not is_explodable:
			damage *= 2.0
		var damage_info = DAMAGE_INFO_SCRIPT.new(
			damage,
			impact_origin,
			forward,
			hit_reaction,
			body
		)
		damage_info.damage_type = &"melee"
		collider.call("apply_damage", damage_info)
		return true

	# A just-approached capsule may still be waiting for a safe full-body handoff.
	for lod in body.get_tree().get_nodes_in_group(&"civilian_capsule_lod"):
		var uppercut := combo_punch_index == UPPERCUT_PUNCH_INDEX
		var info = DAMAGE_INFO_SCRIPT.new(regular_hit_damage_multiplier*strength*(2.0 if uppercut else 1.0),impact_origin,forward,&"knockback" if uppercut else &"chest",body)
		info.damage_type = &"melee"
		if lod.apply_melee_damage(impact_origin,punch_hit_radius,info): return true
	return false
