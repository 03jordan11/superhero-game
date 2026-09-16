class_name PlayerFire
extends Node3D
## Fire attacks share aiming, cooling and overheat with PlayerLaserEyes.
signal charge_changed(active: bool, ratio: float)
const PROJECTILE = preload("res://effects/fireball.gd")
const BREATH = preload("res://effects/dragon_breath.gd")
@export_group("Fireball")
@export var damage := 40.0
@export var blast_radius := 3.0
@export var projectile_speed := 50.0
@export var projectile_lifetime := 6.0
@export var heat_per_shot := 20.0
@export var shot_interval := 0.35
@export_group("Charged Fireball")
@export var charge_duration := 1.5
@export var charged_damage_multiplier := 2.0
@export var charged_blast_radius := 6.0
@export var charge_heat_per_second := 20.0
@export_group("Dragon Breath")
@export var breath_damage_per_second := 20.0
@export var breath_heat_per_second := 20.0
@export var breath_range := 12.0
@export var breath_end_radius := 3.0
var shots_fired := 0
var charging := false
var charge_time := 0.0
var breathing := false
var _cooldown := 0.0
var _charge_orb: MeshInstance3D
var _breath: Node3D
@onready var player: PlayerCharacter = get_parent()

func _ready() -> void:
	_breath = BREATH.new()
	add_child(_breath)
	_charge_orb = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	sphere.radial_segments = 12
	sphere.rings = 6
	_charge_orb.mesh = sphere
	var material := ShaderMaterial.new()
	material.shader = preload("res://effects/fireball_core.gdshader")
	_charge_orb.material_override = material
	_charge_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_charge_orb.hide()
	add_child(_charge_orb)
	process_priority = 11

func _process(_delta: float) -> void:
	if player.is_dead or player.is_knocked_out:
		cancel()
		return
	if charging: _position_charge_orb()
	if breathing: _position_breath()

func tick(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)

func charge_ratio() -> float:
	return clampf(charge_time / maxf(charge_duration, 0.001), 0.0, 1.0)

func cancel() -> void:
	if charging:
		charging = false
		charge_time = 0.0
		charge_changed.emit(false, 0.0)
	if is_instance_valid(_charge_orb): _charge_orb.hide()
	breathing = false
	if is_instance_valid(_breath): _breath.stop()

func update_attack(delta: float, input: PlayerInputSnapshot, allowed: bool, heat_available: float) -> float:
	if not allowed:
		cancel()
		return 0.0
	# Breath takes priority if both attack buttons are held; cancel any stored ball.
	if input.secondary_power_pressed and player.abilities.is_unlocked(PlayerAbilities.DRAGON_BREATH):
		if charging: cancel()
		breathing = true
		_position_breath()
		var duration := minf(delta, heat_available / maxf(breath_heat_per_second, 0.001))
		_breath.deal_damage(breath_damage_per_second * duration, player)
		return breath_heat_per_second * duration
	breathing = false
	_breath.stop()
	if player.abilities.is_unlocked(PlayerAbilities.CHARGED_FIREBALL):
		if input.activate_power_just_pressed and _cooldown <= 0.0 and not charging:
			charging = true
			charge_time = 0.0
		if charging:
			if input.activate_power_pressed:
				var duration := minf(delta, heat_available / maxf(charge_heat_per_second, 0.001))
				charge_time = minf(charge_duration, charge_time + duration)
				charge_changed.emit(true, charge_ratio())
				_position_charge_orb()
				# Power caps, but Heat keeps accumulating until release or overheat.
				return charge_heat_per_second * duration
			var ratio := charge_ratio()
			cancel()
			if input.activate_power_just_released and launch(ratio): return heat_per_shot
	elif input.activate_power_just_pressed and launch():
		return heat_per_shot
	return 0.0

func _aim_target() -> Vector3:
	var camera := player.camera
	var center := camera.get_viewport().get_visible_rect().size * 0.5
	var origin := camera.project_ray_origin(center)
	var target := origin + camera.project_ray_normal(center) * 180.0
	var hit := player.laser_eyes._raycast(origin, target)
	return hit.position if not hit.is_empty() else target

func _torso() -> Vector3:
	var eyes := player.laser_eyes.eye_positions()
	return (eyes[0] + eyes[1]) * 0.5 - Vector3.UP * 0.3

func _position_charge_orb() -> void:
	_charge_orb.show()
	_charge_orb.global_position = _torso() + player.global_basis.x * 0.35
	_charge_orb.scale = Vector3.ONE * lerpf(0.65, 2.0, charge_ratio())

func _position_breath() -> void:
	var eyes := player.laser_eyes.eye_positions()
	var mouth := (eyes[0] + eyes[1]) * 0.5
	var head_basis := player.superhero_character.global_basis
	if is_instance_valid(player.laser_eyes._skeleton):
		head_basis = player.laser_eyes._skeleton.global_basis * player.laser_eyes._skeleton.get_bone_global_pose(player.laser_eyes._head_bone).basis
	mouth -= head_basis.y.normalized() * 0.045
	var direction := (_aim_target() - mouth).normalized()
	var endpoint := mouth + direction * breath_range
	var hit := player.laser_eyes._raycast(mouth, endpoint)
	if not hit.is_empty(): endpoint = hit.position
	_breath.set_stream(mouth, endpoint, breath_end_radius / maxf(breath_range, 0.01))

func launch(power := 0.0) -> bool:
	if _cooldown > 0.0: return false
	_cooldown = shot_interval
	power = clampf(power, 0.0, 1.0)
	var target := _aim_target()
	# Start beside the upper torso, then sweep to the hand so nearby walls block it.
	var torso := _torso()
	var hand := torso + player.global_basis.x * 0.35
	var projectile: Node3D = PROJECTILE.new()
	projectile.source = player
	projectile.damage = damage * lerpf(1.0, charged_damage_multiplier, power)
	projectile.edge_damage = damage if power > 0.0 else -1.0
	projectile.blast_radius = lerpf(blast_radius, charged_blast_radius, power)
	projectile.visual_scale = lerpf(1.0, 2.0, power)
	projectile.lifetime = projectile_lifetime
	projectile.velocity = (target - hand).normalized() * projectile_speed
	var world := get_tree().current_scene if get_tree().current_scene != null else player.get_parent()
	world.add_child(projectile)
	projectile.global_position = torso
	projectile.advance_to(hand)
	shots_fired += 1
	return true
