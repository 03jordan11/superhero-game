class_name PlayerLightningStrike
extends Node3D
## Grounded tier-3 strike. Cooldown state lives in Weather for later HUD binding.
const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
const EFFECT = preload("res://effects/lightning_strike.gd")
const ARC = preload("res://effects/electric_arc.gd")
@export var strike_radius := 4.5
@export var target_range := 50.0
@export var initial_damage := 25.0
@export_range(0.0, 300.0, 1.0, "suffix:s") var cooldown_seconds := 60.0
@export_range(0.05, 1.0, 0.01, "suffix:s") var tap_seconds := 0.25
@export_range(0.05, 1.0, 0.05) var aiming_time_scale := 0.5
@export_range(0.1, 5.0, 0.1, "suffix:s") var ground_effect_seconds := 1.0
var casting := false
var aiming := false
var impacted := false
var held_seconds := 0.0
var cast_seconds := 0.0
var release_seconds := 0.0
var target: Dictionary = {}
var radial := false
var _require_release := true
var _slow_owned := false
var _marker: MeshInstance3D
var _effect: Node3D
var _hand_arc: Node3D
@onready var player: PlayerCharacter = get_parent()
@onready var weather: Node = get_node("/root/Weather")

func _ready() -> void:
	_marker = MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE * strike_radius * 2.0
	_marker.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = EFFECT.GROUND_SHADER
	material.set_shader_parameter("preview", true)
	_marker.material_override = material
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)
	_marker.hide()
	_effect = EFFECT.new()
	add_child(_effect)
	_effect.top_level = true
	_hand_arc = ARC.new()
	add_child(_hand_arc)
	process_priority = 12

func unlocked() -> bool:
	return player.get_node("PlayerPowerController").progression.level("electricity") >= 3

func eligible() -> bool:
	return unlocked() and player.thunderstorm.eligible() and not player.thunderstorm.casting and player.is_on_floor() and not player.is_flying

func tick(delta: float, input: PlayerInputSnapshot) -> bool:
	if delta <= 0: return casting
	if not input.secondary_power_pressed: _require_release = false
	if casting and (not eligible() or not weather.is_thunderstorm()): cancel()
	if not casting and not _require_release and input.secondary_power_just_pressed:
		_require_release = true
		if eligible() and weather.is_thunderstorm() and weather.lightning_strike_cooldown_remaining <= 0.0 and not player.laser_eyes.overheated:
			_begin()
	if not casting: return false
	player.laser_eyes.update_power(delta, PlayerInputSnapshot.new())
	if aiming:
		held_seconds += delta / maxf(Engine.time_scale, 0.001)
		cast_seconds += delta
		if cast_seconds >= 0.533333 and player.character_animation_player.current_animation != "Thunderstorm/Spell_Simple_Idle":
			player.character_animation_player.play("Thunderstorm/Spell_Simple_Idle", 0.08)
		if held_seconds >= tap_seconds:
			_start_slow_motion()
			target = aimed_ground()
			_show_target()
		if input.secondary_power_just_released:
			radial = held_seconds < tap_seconds
			target = ground_below_player() if radial else aimed_ground()
			if target.is_empty():
				cancel()
				return false
			aiming = false
			release_seconds = 0.0
			_marker.hide()
			player.character_animation_player.play("Thunderstorm/Spell_Simple_Shoot", 0.08)
		elif not input.secondary_power_pressed:
			# A suppressed input snapshot is cancellation, never an implicit release.
			cancel()
			return false
	else:
		release_seconds += delta
		if not impacted and release_seconds >= 0.25:
			if not _strike():
				cancel()
				return false
			impacted = true
			_restore_time()
		if release_seconds >= 0.5 and player.character_animation_player.current_animation != "Thunderstorm/Spell_Simple_Exit":
			player.character_animation_player.play("Thunderstorm/Spell_Simple_Exit", 0.08)
		if release_seconds >= 0.933333:
			cancel()
			return false
	player.velocity = Vector3(0, -0.1, 0)
	player.move_and_slide()
	player.stamina.finish_tick(delta, Vector3.ZERO, player.is_on_floor())
	return true

func _begin() -> void:
	player.thunderstorm.prepare_cast()
	casting = true
	aiming = true
	impacted = false
	held_seconds = 0.0
	cast_seconds = 0.0
	release_seconds = 0.0
	target = {}
	player.status_effects.hit_slowdown_remaining = 0.0
	player.character_animation_player.play("Thunderstorm/Spell_Simple_Enter", 0.08)

func _start_slow_motion() -> void:
	if _slow_owned: return
	_slow_owned = get_node("/root/SlowMotion").start(self, aiming_time_scale)

func _restore_time() -> void:
	if not _slow_owned: return
	get_node("/root/SlowMotion").stop(self)
	_slow_owned = false

func _world_ray(from: Vector3, to: Vector3) -> Dictionary:
	var excluded: Array[RID] = [player.get_rid()]
	for group in [&"hostile", &"civilian", &"attack_helicopter"]:
		for node in get_tree().get_nodes_in_group(group):
			if node is CollisionObject3D: excluded.append(node.get_rid())
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, excluded)
	return get_world_3d().direct_space_state.intersect_ray(query)

func aimed_ground() -> Dictionary:
	var camera := player.camera
	var center := camera.get_viewport().get_visible_rect().size * 0.5
	var origin := camera.project_ray_origin(center)
	var direction := camera.project_ray_normal(center)
	var hit := _world_ray(origin, origin + direction * (target_range + origin.distance_to(player.global_position)))
	if hit.is_empty() or hit.normal.y < 0.6 or hit.position.distance_to(player.global_position) > target_range: return {}
	# The shoulder camera cannot aim through a wall beside/behind the hero.
	var obstruction := _world_ray(player.global_position + Vector3.UP * 0.4, hit.position + hit.normal * 0.08)
	if not obstruction.is_empty() and obstruction.position.distance_to(hit.position) > 0.2: return {}
	return hit

func ground_below_player() -> Dictionary:
	var hit := _world_ray(player.global_position + Vector3.UP * 0.2, player.global_position + Vector3.DOWN * 3.0)
	return hit if not hit.is_empty() and hit.normal.y >= 0.6 else {}

func _show_target() -> void:
	_marker.visible = not target.is_empty()
	if target.is_empty(): return
	_marker.mesh.size = Vector2.ONE * strike_radius * 2.0
	_marker.global_transform = Transform3D(EFFECT.surface_basis(target.normal), target.position + target.normal * 0.035)

func _strike() -> bool:
	if target.is_empty() or not weather.begin_lightning_strike_cooldown(cooldown_seconds): return false
	player.laser_eyes.fill_heat_without_explosion()
	_effect.start(target.position, target.normal, strike_radius, radial, ground_effect_seconds)
	apply_strike_damage(target.position)
	return true

func apply_strike_damage(center: Vector3) -> void:
	# The sky bolt can hit aircraft above its ground circle, without Electrified.
	for aircraft in get_tree().get_nodes_in_group(&"attack_helicopter"):
		if aircraft.is_dead: continue
		var offset: Vector3 = aircraft.global_position - center
		if Vector2(offset.x, offset.z).length() > strike_radius or offset.y < 0.0 or offset.y > EFFECT.BOLT_HEIGHT: continue
		if not _world_ray(aircraft.global_position + Vector3.UP * (EFFECT.BOLT_HEIGHT - offset.y), aircraft.global_position + Vector3.UP * 0.6).is_empty(): continue
		var hit = DAMAGE.new(initial_damage, center, Vector3.ZERO, &"none", player)
		hit.damage_type = &"lightning_strike"
		aircraft.apply_damage(hit)
	var electric: PlayerElectricity = player.get_node("PlayerElectricity")
	for candidate in get_tree().get_nodes_in_group(&"hostile"):
		var enemy := candidate as HostileBase
		if enemy == null or enemy.is_dead or enemy.is_grabbed or enemy.is_thrown: continue
		var offset := enemy.global_position - center
		if Vector2(offset.x, offset.z).length() > strike_radius or absf(offset.y) > 2.5: continue
		# A ground strike cannot cross walls or hit enemies through another floor.
		if not _world_ray(center + Vector3.UP * 0.35, enemy.global_position + Vector3.UP * 0.6).is_empty(): continue
		var info = DAMAGE.new(initial_damage, center, Vector3.ZERO, &"none", player)
		info.damage_type = &"lightning_strike"
		if enemy.electrified.active:
			# Preserve an existing status schedule instead of restarting or stacking it.
			enemy.health_component.apply_damage(info)
		else:
			enemy.apply_damage(info)
			if not enemy.is_dead:
				enemy.electrified.begin(enemy, player, electric.reactive_duration, electric.reactive_tick_damage, electric.reactive_end_damage)

func cancel() -> void:
	_restore_time()
	if casting and is_instance_valid(player.character_animation_player):
		if String(player.character_animation_player.current_animation).begins_with("Thunderstorm/"): player.character_animation_player.stop()
	casting = false
	aiming = false
	_require_release = true
	if is_instance_valid(_marker): _marker.hide()
	if is_instance_valid(_hand_arc): _hand_arc.hide()

func _process(delta: float) -> void:
	if not casting: return
	var skeleton: Skeleton3D = player.laser_eyes._skeleton
	if not is_instance_valid(skeleton): return
	var index := skeleton.find_bone("LeftHand")
	if index < 0: return
	var hand := skeleton.global_transform * skeleton.get_bone_global_pose(index)
	_hand_arc.draw_arc(hand.origin, hand.origin + Vector3.UP * 0.22, player.camera.global_position, true, delta)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]: cancel()

func _exit_tree() -> void:
	get_node("/root/SlowMotion").stop(self, true)
	cancel()
	if is_instance_valid(_effect): _effect.stop()
