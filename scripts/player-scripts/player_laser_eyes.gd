class_name PlayerLaserEyes
extends Node3D

signal heat_changed(percent: float, overheated: bool)
signal aim_changed(active: bool)

const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
const SCORCH = preload("res://effects/laser_scorch.gd")
@export_group("Beam")
@export var damage_per_second := 25.0
@export var beam_range := 180.0
@export var beam_radius := 0.018
@export var eye_offset := Vector3(0.035, 0.085, 0.095)
@export_group("Heat")
@export var heat_per_second := 20.0
@export var cooling_per_second := 25.0
@export var cooling_delay := 0.75
@export var overheat_radius := 6.0
@export var overheat_area_damage := 75.0
@export_group("Aim")
@export_range(0.3, 1.0, 0.05) var aim_fov_ratio := 0.8
@export var zoom_speed := 10.0
@export_group("Scorch Trails")
@export var scorch_lifetime := 15.0
@export var scorch_spacing := 0.35
@export_range(8, 256, 1) var maximum_scorches := 128

var heat := 0.0
var overheated := false
var firing := false
var aiming := false
var last_hit: Dictionary = {}
var _normal_fov := 75.0
var _cooldown := 0.0
var _require_release := false
var _skeleton: Skeleton3D
var _head_bone := -1
var _beams: Array[MeshInstance3D] = []
var _impact: MeshInstance3D
var _marks: Array[MeshInstance3D] = []
var _last_scorch := Vector3.INF
var _last_surface_id := 0
var _beam_target := Vector3.ZERO
@onready var player := get_parent() as PlayerCharacter

func _ready() -> void:
	player.ready.connect(_setup, CONNECT_ONE_SHOT)
	_build_beams()

func _setup() -> void:
	_normal_fov = player.camera.fov
	for skeleton in player.superhero_character.find_children("*", "Skeleton3D", true, false):
		var index: int = skeleton.find_bone("Head")
		if index >= 0:
			_skeleton = skeleton
			_head_bone = index
			break
	player.abilities.ability_changed.connect(_ability_changed)
	process_priority = 10 # Follow animation and movement when placing the eye beams.

func _process(_delta: float) -> void:
	if not firing: return
	if player.is_dead or player.is_knocked_out:
		cancel_input()
		return
	var eyes := eye_positions()
	for i in 2: _draw_beam(_beams[i], eyes[i], _beam_target)

func _ability_changed(id: StringName, unlocked: bool) -> void:
	if id in [PlayerAbilities.LASER_EYES, PlayerAbilities.ICE, PlayerAbilities.FIRE, PlayerAbilities.ELECTRICITY, PlayerAbilities.CHARGED_FIREBALL, PlayerAbilities.DRAGON_BREATH] and not unlocked: cancel_input()

func cancel_input() -> void:
	_require_release = true
	var wall := get_node_or_null("../PlayerFrostWall")
	if wall != null: wall.cancel()
	var thunderstorm := get_node_or_null("../PlayerThunderstorm")
	if thunderstorm != null: thunderstorm.cancel()
	var lightning := get_node_or_null("../PlayerLightningStrike")
	if lightning != null: lightning.cancel()
	var combustion := get_node_or_null("../PlayerExternalCombustion")
	if combustion != null: combustion.cancel()
	var fire := get_node_or_null("../PlayerFire")
	if fire != null: fire.cancel()
	var frost := get_node_or_null("../PlayerFrost")
	if frost != null: frost.cancel()
	var electricity := get_node_or_null("../PlayerElectricity")
	if electricity != null: electricity.cancel()
	_set_aim(false)
	_hide_beams()
	if player != null and is_instance_valid(player.camera): player.camera.fov = _normal_fov

func update_power(delta: float, input: PlayerInputSnapshot) -> void:
	if delta <= 0.0: return
	var previous_heat := heat
	var previous_overheated := overheated
	var fire: PlayerFire = player.get_node("PlayerFire")
	fire.tick(delta)
	var blocked: bool = get_tree().paused or get_node("/root/DebugManager").developer_menu_open or get_node("/root/GameSettings").input_bindings.is_capturing
	blocked = blocked or player.get_node("PlayerPowerController").is_selector_open()
	if not input.activate_power_pressed and not input.secondary_power_pressed and not blocked: _require_release = false
	var selected: StringName = player.get_node("PlayerPowerController").active_power
	var available: bool = selected in [PlayerAbilities.LASER_EYES, PlayerAbilities.ICE, PlayerAbilities.FIRE, PlayerAbilities.ELECTRICITY] and player.abilities.is_unlocked(selected) and not (
		blocked or player.is_dead or player.is_knocked_out or player.is_ground_slamming
		or player.is_charging_flight or player.is_charging_jump or player.combat_controller.is_action_locked())
	available=available and not player.hostile_grab.owns_animation()
	_set_aim(available and input.aim_power_pressed)
	player.camera.fov = lerpf(player.camera.fov, _normal_fov * aim_fov_ratio if aiming else _normal_fov, 1.0 - exp(-zoom_speed * delta))
	var fire_heat := fire.update_attack(delta, input,
		selected == PlayerAbilities.FIRE and aiming and not overheated and not _require_release,
		100.0 - heat)
	var electricity: PlayerElectricity = player.get_node("PlayerElectricity")
	var electric_heat := electricity.update_attack(delta, input,
		selected == PlayerAbilities.ELECTRICITY and aiming and not overheated and not _require_release,
		100.0 - heat)
	var frost: PlayerFrost = player.get_node("PlayerFrost")
	var frost_heat := frost.update_attack(delta, input,
		selected == PlayerAbilities.ICE and aiming and not overheated and not _require_release, 100.0 - heat)
	var other_power_active := fire_heat > 0.0 or fire.charging or fire.breathing or electricity.firing or frost.firing
	if other_power_active:
		heat = minf(100.0, heat + fire_heat + electric_heat + frost_heat)
		_cooldown = cooling_delay
		if heat >= 99.9999: _overheat()
	if selected == PlayerAbilities.LASER_EYES and aiming and input.activate_power_pressed and not overheated and not _require_release:
		firing = true
		# Clamp the final damage interval to the time remaining before overheat.
		var firing_time := minf(delta, (100.0 - heat) / maxf(heat_per_second, 0.001))
		_fire(firing_time)
		heat = minf(100.0, heat + heat_per_second * firing_time)
		_cooldown = cooling_delay
		if heat >= 99.9999: _overheat()
	else:
		_hide_beams()
		var cooling_time := 0.0 if other_power_active else maxf(delta - _cooldown, 0.0)
		if not other_power_active: _cooldown = maxf(_cooldown - delta, 0.0)
		heat = maxf(heat - cooling_per_second * cooling_time, 0.0)
		if heat <= 0.0: overheated = false
	if not is_equal_approx(previous_heat, heat) or previous_overheated != overheated:
		heat_changed.emit(heat, overheated)

func _set_aim(value: bool) -> void:
	if aiming == value: return
	aiming = value
	aim_changed.emit(aiming)

func eye_positions() -> Array[Vector3]:
	var head := player.superhero_character.global_transform
	if is_instance_valid(_skeleton) and _head_bone >= 0:
		head = _skeleton.global_transform * _skeleton.get_bone_global_pose(_head_bone)
	else:
		head.origin = player.global_position + Vector3.UP * 0.8
	return [head * Vector3(-eye_offset.x, eye_offset.y, eye_offset.z), head * eye_offset]

func _fire(delta: float) -> void:
	var camera := player.camera
	var screen_center := camera.get_viewport().get_visible_rect().size * 0.5
	var eyes := eye_positions()
	var origin := (eyes[0] + eyes[1]) * 0.5
	var camera_origin := camera.project_ray_origin(screen_center)
	var target := camera_origin + camera.project_ray_normal(screen_center) * beam_range
	var camera_hit := _raycast(camera_origin, target)
	if not camera_hit.is_empty(): target = camera_hit.position + (camera_hit.position - origin).normalized() * 0.05
	# Resolve from the eyes as well, so a third-person camera cannot shoot through cover.
	last_hit = _raycast(origin, target)
	if not last_hit.is_empty(): target = last_hit.position
	_beam_target = target
	for i in 2: _draw_beam(_beams[i], eyes[i], target)
	_impact.visible = not last_hit.is_empty()
	_impact.global_position = target
	if last_hit.is_empty():
		_last_scorch = Vector3.INF
		return
	var collider: Object = last_hit.collider
	if is_instance_valid(collider) and collider.has_method("apply_damage"):
		var info = DAMAGE.new(damage_per_second * delta, origin, (target - origin).normalized(), &"none", player)
		info.damage_type = &"laser"
		collider.call("apply_damage", info)
	if is_instance_valid(collider) and collider is StaticBody3D and last_hit.normal.y > 0.65:
		_stamp_trail(target, last_hit.normal, collider.get_instance_id())
	else:
		_last_scorch = Vector3.INF

func _raycast(from: Vector3, to: Vector3) -> Dictionary:
	if from.distance_squared_to(to) < 0.000001: return {}
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	query.hit_from_inside = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	var end: Vector3 = result.position if not result.is_empty() else to
	for lod in get_tree().get_nodes_in_group(&"civilian_capsule_lod"):
		var hit: Dictionary = lod.intersect_damage_ray(from, end)
		if not hit.is_empty():
			result = hit
			end = hit.position
	return result

func fill_heat_without_explosion() -> void:
	# Lightning Strike spends the full Heat bar without the normal overload blast.
	heat = 100.0
	overheated = true
	_require_release = true
	_cooldown = cooling_delay
	_hide_beams()
	heat_changed.emit(heat, overheated)

func _overheat() -> void:
	if player.external_combustion.try_passive(): return
	heat = 100.0
	overheated = true
	cancel_input()
	player.flying_state.cancel_charge()
	player.state_machine.transition_to(&"KnockedDownState", {"cause": &"overheat"})
	# Apply this exact cost separately; the area blast excludes the player.
	var info = DAMAGE.new(floorf(player.get_max_health() * 0.3), player.global_position, Vector3.ZERO, &"none", player)
	info.damage_type = &"overheat"
	player.apply_damage(info)
	var explosions := get_tree().get_first_node_in_group(&"explosion_controller") as ExplosionController
	if explosions == null:
		explosions = ExplosionController.new()
		var world := get_tree().current_scene if get_tree().current_scene != null else player.get_parent()
		world.add_child(explosions)
	explosions.explode_power(player.global_position, overheat_area_damage, overheat_radius, player)

func _build_beams() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.08, 0.025)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.025, 0.008)
	material.emission_energy_multiplier = 5.0
	for i in 2:
		var beam := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = beam_radius
		mesh.bottom_radius = beam_radius
		mesh.height = 1.0
		mesh.radial_segments = 8
		beam.mesh = mesh
		beam.material_override = material
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(beam)
		beam.top_level = true
		beam.hide()
		_beams.append(beam)
	_impact = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.18
	sphere.radial_segments = 8
	sphere.rings = 4
	_impact.mesh = sphere
	_impact.material_override = material
	_impact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_impact)
	_impact.top_level = true
	_impact.hide()

func _draw_beam(beam: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var direction := (to - from).normalized()
	if direction.is_zero_approx():
		beam.hide()
		return
	var reference := Vector3.FORWARD if absf(direction.y) > 0.98 else Vector3.UP
	var right := direction.cross(reference).normalized()
	beam.global_transform = Transform3D(Basis(right, direction * from.distance_to(to), right.cross(direction)), (from + to) * 0.5)
	beam.show()

func _hide_beams() -> void:
	firing = false
	_last_scorch = Vector3.INF
	for beam in _beams: beam.hide()
	if _impact != null: _impact.hide()

func _stamp_trail(point: Vector3, normal: Vector3, surface_id: int) -> void:
	_marks = _marks.filter(func(mark): return is_instance_valid(mark) and not mark.is_queued_for_deletion())
	var connected := _last_scorch.is_finite() and _last_surface_id == surface_id and point.distance_to(_last_scorch) < 8.0
	if connected and point.distance_to(_last_scorch) < scorch_spacing: return
	var count := mini(24, maxi(1, ceili(point.distance_to(_last_scorch) / scorch_spacing))) if connected else 1
	var start := _last_scorch if connected else point
	for i in count:
		var mark: MeshInstance3D = SCORCH.new()
		mark.lifetime = scorch_lifetime
		add_child(mark)
		mark.top_level = true
		var right := normal.cross(Vector3.FORWARD).normalized()
		mark.global_transform = Transform3D(Basis(right, normal, right.cross(normal)), start.lerp(point, float(i + 1) / count) + normal * 0.015)
		_marks.append(mark)
		if _marks.size() > maximum_scorches: _marks.pop_front().queue_free()
	_last_scorch = point
	_last_surface_id = surface_id

func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]: cancel_input()
