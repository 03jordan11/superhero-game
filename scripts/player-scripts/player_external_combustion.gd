class_name PlayerExternalCombustion
extends Node3D
## Fire tier 3. Hold un-aimed Power Special to safely charge the shared heat.
const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
const EFFECT = preload("res://effects/vehicle_explosion_effect.tscn")
@export var charge_seconds := 2.0
@export var minimum_heat := 10.0
@export var minimum_radius := 1.0
@export var maximum_radius := 8.0
@export var minimum_damage := 10.0
@export var maximum_damage := 70.0
@export var cooldown_seconds := 300.0
@export var explosion_seconds := 1.4
@export_range(0.05, 1.0, 0.05) var explosion_time_scale := 0.5
var casting := false
var charging := false
var elapsed := 0.0
var _require_release := true
var _explosion_remaining := 0.0
var last_radius := 0.0
var last_damage := 0.0
var _glow: MeshInstance3D
@onready var player: PlayerCharacter = get_parent()
@onready var cooldowns: Node = get_node("/root/Weather")

func _ready() -> void:
	_glow = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.3
	mesh.height = 0.6
	_glow.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = preload("res://effects/fireball_core.gdshader")
	_glow.material_override = material
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow)
	_glow.hide()

func unlocked() -> bool:
	return player.get_node("PlayerPowerController").progression.level("fire") >= 3

func available() -> bool:
	return unlocked() and player.get_node("PlayerPowerController").active_power == &"fire" and cooldowns.external_combustion_cooldown_remaining <= 0.0 and not player.is_dead and not player.is_knocked_out

func eligible() -> bool:
	return available() and not (get_tree().paused or get_node("/root/DebugManager").developer_menu_open
		or get_node("/root/GameSettings").input_bindings.is_capturing or player.get_node("PlayerPowerController").is_selector_open()
		or player.is_dodging or player.anticipation.active() or player.is_ground_slamming or player.is_wall_running
		or player.is_charging_jump or player.is_charging_flight or player.is_carrying()
		or player.hostile_grab.owns_animation() or player.ship_interaction.is_attached()
		or player.combat_controller.is_action_locked() or player.laser_eyes.overheated)

func tick(delta: float, input: PlayerInputSnapshot) -> bool:
	if delta <= 0.0: return casting
	if not input.secondary_power_pressed: _require_release = false
	if casting and charging and not eligible(): cancel()
	if not casting and not _require_release and input.secondary_power_just_pressed:
		_require_release = true
		if not input.aim_power_pressed and eligible():
			player.thunderstorm.prepare_cast()
			casting = true
			charging = true
			elapsed = 0.0
			player.status_effects.hit_slowdown_remaining = 0.0
			player.character_animation_player.play("Thunderstorm/Spell_Simple_Enter", 0.08)
	if not casting: return false
	elapsed += delta
	if charging:
		if input.secondary_power_just_released:
			if not erupt():
				cancel()
				return false
			charging = false
			elapsed = 0.0
			_glow.hide()
			player.character_animation_player.play("Thunderstorm/Spell_Simple_Shoot", 0.08)
		elif not input.secondary_power_pressed:
			cancel()
			return false
		else:
			player.laser_eyes.heat = minf(100.0, player.laser_eyes.heat + delta * 100.0 / maxf(charge_seconds, 0.001))
			player.laser_eyes._cooldown = player.laser_eyes.cooling_delay
			player.laser_eyes.heat_changed.emit(player.laser_eyes.heat, false)
			if elapsed >= 0.533333 and player.character_animation_player.current_animation != "Thunderstorm/Spell_Simple_Idle":
				player.character_animation_player.play("Thunderstorm/Spell_Simple_Idle", 0.08)
			_glow.position = Vector3(0, 1.2, -0.4)
			_glow.scale = Vector3.ONE * lerpf(0.5, 2.0, player.laser_eyes.heat / 100.0)
			_glow.show()
	else:
		player.laser_eyes.update_power(delta, PlayerInputSnapshot.new())
		if elapsed >= 0.5:
			_finish_cast()
			return false
	# Freeze translation on the ground and hover during flight/airborne charging.
	player.velocity = Vector3.ZERO
	player.stamina.finish_tick(delta, Vector3.ZERO, player.is_on_floor())
	return true

func try_passive() -> bool:
	if charging or not available(): return false
	return erupt()

func erupt() -> bool:
	var heat := player.laser_eyes.heat
	if not available() or heat < minimum_heat: return false
	var fraction := clampf(inverse_lerp(minimum_heat, 100.0, heat), 0.0, 1.0)
	last_radius = lerpf(minimum_radius, maximum_radius, fraction)
	last_damage = lerpf(minimum_damage, maximum_damage, fraction)
	cooldowns.external_combustion_cooldown_remaining = cooldown_seconds
	player.get_node("PlayerFire").cancel()
	player.laser_eyes.heat = 0.0
	player.laser_eyes.overheated = false
	player.laser_eyes._require_release = true
	player.laser_eyes.heat_changed.emit(0.0, false)
	var center := player.global_position
	var enemies := get_tree().get_nodes_in_group(&"hostile") + get_tree().get_nodes_in_group(&"attack_helicopter")
	for enemy in enemies:
		if enemy.is_dead: continue
		if enemy.global_position.distance_to(center) > last_radius: continue
		var info = DAMAGE.new(last_damage, center, Vector3.ZERO, &"knockback" if enemy is HostileBase else &"none", player)
		info.damage_type = &"external_combustion"
		info.force_knockdown = enemy is HostileBase
		enemy.apply_damage(info)
	var effect: Node3D = EFFECT.instantiate()
	effect.explosion_lifetime = explosion_seconds
	# The reused pulse mesh expands to a four-meter radius at scale 1.
	effect.scale = Vector3.ONE * last_radius / 4.0
	var world := get_tree().current_scene if get_tree().current_scene != null else player.get_parent()
	world.add_child(effect)
	effect.global_position = center + Vector3.UP * 0.5
	get_node("/root/SlowMotion").start(self, explosion_time_scale)
	_explosion_remaining = explosion_seconds
	return true

func _process(delta: float) -> void:
	if _explosion_remaining <= 0.0: return
	_explosion_remaining = maxf(0.0, _explosion_remaining - delta)
	if _explosion_remaining <= 0.0: get_node("/root/SlowMotion").stop(self)

func _finish_cast() -> void:
	if casting and is_instance_valid(player.character_animation_player):
		if String(player.character_animation_player.current_animation).begins_with("Thunderstorm/"): player.character_animation_player.stop()
	casting = false
	charging = false
	_require_release = true
	if is_instance_valid(_glow): _glow.hide()

func cancel() -> void:
	_finish_cast()
	_explosion_remaining = 0.0
	get_node("/root/SlowMotion").stop(self)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]: cancel()

func _exit_tree() -> void:
	get_node("/root/SlowMotion").stop(self, true)
	cancel()
