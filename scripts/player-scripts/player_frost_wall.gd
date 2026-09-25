class_name PlayerFrostWall
extends Node3D
const WALL = preload("res://effects/frost_wall.gd")
const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
@export var wall_width := 8.0
@export var wall_depth := 2.0
@export var wall_height := 4.0
@export var wall_seconds := 6.0
@export var target_range := 50.0
@export var damage := 50.0
@export var launch_speed := 12.0
@export var launch_up_speed := 8.0
@export var heat_cost := 20.0
@export var cooldown_seconds := 300.0
@export_range(0.05, 1.0, 0.05) var aiming_time_scale := 0.5
var casting := false
var aiming := false
var elapsed := 0.0
var target: Dictionary = {}
var _require_release := true
var _marker: MeshInstance3D
@onready var player: PlayerCharacter = get_parent()
@onready var cooldowns: Node = get_node("/root/Weather")

func _ready() -> void:
	_marker = MeshInstance3D.new()
	_marker.mesh = PlaneMesh.new()
	_marker.mesh.size = Vector2(wall_width, wall_depth)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.65, 0.93, 1.0, 0.55)
	material.emission_enabled = true
	material.emission = Color(0.3, 0.7, 1.0)
	_marker.material_override = material
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)
	_marker.top_level = true
	_marker.hide()
	# Prepare the same box/ice material while the player loads, without collision.
	var preparation := MeshInstance3D.new()
	preparation.name = "WallPreparation"
	preparation.mesh = BoxMesh.new()
	preparation.mesh.size = Vector3(wall_width, wall_height, wall_depth)
	var ice := ShaderMaterial.new()
	ice.shader = WALL.ICE_SHADER
	preparation.material_override = ice
	add_child(preparation)
	preparation.hide()

func unlocked() -> bool:
	return player.get_node("PlayerPowerController").progression.level("ice") >= 2

func eligible() -> bool:
	return unlocked() and player.get_node("PlayerPowerController").active_power == &"ice" and not (
		get_tree().paused or get_node("/root/DebugManager").developer_menu_open
		or get_node("/root/GameSettings").input_bindings.is_capturing or player.get_node("PlayerPowerController").is_selector_open()
		or player.is_dead or player.is_knocked_out or player.is_dodging or player.anticipation.active()
		or player.is_ground_slamming or player.is_wall_running or player.is_charging_jump or player.is_charging_flight
		or player.is_carrying() or player.hostile_grab.owns_animation() or player.ship_interaction.is_attached()
		or player.combat_controller.is_action_locked() or player.laser_eyes.overheated)

func tick(delta: float, input: PlayerInputSnapshot) -> bool:
	if delta <= 0.0: return casting
	if not input.secondary_power_pressed: _require_release = false
	if casting and not eligible(): cancel()
	if not casting and not _require_release and input.secondary_power_just_pressed:
		_require_release = true
		if input.aim_power_pressed and eligible() and cooldowns.frost_wall_cooldown_remaining <= 0.0:
			player.thunderstorm.prepare_cast()
			casting = true
			aiming = true
			elapsed = 0.0
			player.status_effects.hit_slowdown_remaining = 0.0
			player.character_animation_player.play("Thunderstorm/Spell_Simple_Enter", 0.08)
			get_node("/root/SlowMotion").start(self, aiming_time_scale)
	if not casting: return false
	# Keep aim zoom/Heat cooling, but suppress all simultaneous breath input.
	var aim_input := PlayerInputSnapshot.new()
	aim_input.aim_power_pressed = aiming
	player.laser_eyes.update_power(delta, aim_input)
	elapsed += delta
	if aiming:
		if not input.aim_power_pressed:
			cancel()
			return false
		target = aimed_ground()
		_marker.visible = not target.is_empty()
		if not target.is_empty():
			_marker.mesh.size = Vector2(wall_width, wall_depth)
			_marker.global_transform = Transform3D(target.basis, target.position + Vector3.UP * 0.035)
		if input.secondary_power_just_released:
			if not erect_wall():
				cancel()
				return false
			if not casting: return false # Normal overheat/death may cancel the cast.
			aiming = false
			elapsed = 0.0
			_marker.hide()
			get_node("/root/SlowMotion").stop(self)
			player.character_animation_player.play("Thunderstorm/Spell_Simple_Shoot", 0.08)
		elif not input.secondary_power_pressed:
			cancel()
			return false
		elif elapsed >= 0.533333 and player.character_animation_player.current_animation != "Thunderstorm/Spell_Simple_Idle":
			player.character_animation_player.play("Thunderstorm/Spell_Simple_Idle", 0.08)
	elif elapsed >= 0.5:
		cancel()
		return false
	# Plant on the ground or hover while placing/releasing a wall.
	player.velocity = Vector3.ZERO
	player.stamina.finish_tick(delta, Vector3.ZERO, player.is_on_floor())
	return true

func _excluded_people(include_player := true) -> Array[RID]:
	var excluded: Array[RID] = []
	if include_player: excluded.append(player.get_rid())
	for group in [&"hostile", &"civilian", &"attack_helicopter"]:
		for body in get_tree().get_nodes_in_group(group):
			if body is CollisionObject3D: excluded.append(body.get_rid())
	return excluded

func _world_ray(from: Vector3, to: Vector3) -> Dictionary:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1, _excluded_people()))

func aimed_ground() -> Dictionary:
	var camera := player.camera
	var screen := camera.get_viewport().get_visible_rect().size * 0.5
	var origin := camera.project_ray_origin(screen)
	var hit := _world_ray(origin, origin + camera.project_ray_normal(screen) * (target_range + origin.distance_to(player.global_position)))
	if hit.is_empty() or hit.normal.y < 0.85 or hit.position.distance_to(player.global_position) > target_range: return {}
	var cover := _world_ray(player.global_position + Vector3.UP * 0.4, hit.position + Vector3.UP * 0.08)
	if not cover.is_empty() and cover.position.distance_to(hit.position) > 0.2: return {}
	var away: Vector3 = (hit.position - player.global_position) * Vector3(1, 0, 1)
	if away.length_squared() < 0.01: away = -camera.global_basis.z * Vector3(1, 0, 1)
	if away.is_zero_approx(): away = Vector3.FORWARD
	var basis := Basis.looking_at(away.normalized(), Vector3.UP)
	var position: Vector3 = hit.position
	# All four corners need support: don't bridge gaps or clip through steps.
	for x in [-0.5, 0.5]:
		for z in [-0.5, 0.5]:
			var corner: Vector3 = hit.position + basis * Vector3(x * wall_width, 0, z * wall_depth)
			var support := _world_ray(corner + Vector3.UP * 0.4, corner + Vector3.DOWN * 0.4)
			if support.is_empty() or support.normal.y < 0.85: return {}
			position.y = maxf(position.y, support.position.y)
	var query := _volume_query(position, basis, 0.08)
	query.exclude = _excluded_people(false)
	# Include the player here so a close placement cannot trap the caster.
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): return {}
	return {"position": position, "basis": basis}

func _volume_query(position: Vector3, basis: Basis, floor_margin := 0.0) -> PhysicsShapeQueryParameters3D:
	var query := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(wall_width, wall_height - floor_margin, wall_depth)
	query.shape = box
	query.transform = Transform3D(basis, position + Vector3.UP * (wall_height + floor_margin) * 0.5)
	query.collision_mask = 1
	return query

func erect_wall() -> bool:
	if target.is_empty() or cooldowns.frost_wall_cooldown_remaining > 0.0: return false
	var hits := get_world_3d().direct_space_state.intersect_shape(_volume_query(target.position, target.basis), 256)
	var wall := WALL.new()
	wall.dimensions = Vector3(wall_width, wall_height, wall_depth)
	wall.lifetime = wall_seconds
	var world := get_tree().current_scene if get_tree().current_scene != null else player.get_parent()
	world.add_child(wall)
	wall.global_transform = Transform3D(target.basis, target.position)
	var seen := {}
	var direction: Vector3 = -target.basis.z
	for hit in hits:
		var enemy = hit.collider
		if enemy == player or seen.has(enemy.get_instance_id()): continue
		seen[enemy.get_instance_id()] = true
		if not (enemy is NPCBase or enemy.is_in_group(&"attack_helicopter")) or enemy.is_dead: continue
		if enemy is HostileBase:
			if enemy.is_grabbed or enemy.is_thrown: continue
			enemy.frost.cancel()
			enemy.electrified.cancel()
		var info = DAMAGE.new(damage, player.global_position, direction, &"knockback" if enemy is NPCBase else &"none", player)
		info.damage_type = &"frost_wall"
		info.force_knockdown = enemy is NPCBase
		if not enemy.apply_damage(info): continue
		if enemy is NPCBase:
			wall.allow_launch(enemy)
			enemy.knockback_velocity = direction * launch_speed
			enemy.velocity = direction * launch_speed + Vector3.UP * launch_up_speed
	cooldowns.frost_wall_cooldown_remaining = cooldown_seconds
	player.laser_eyes.heat = minf(100.0, player.laser_eyes.heat + heat_cost)
	player.laser_eyes._cooldown = player.laser_eyes.cooling_delay
	player.laser_eyes.heat_changed.emit(player.laser_eyes.heat, player.laser_eyes.overheated)
	if player.laser_eyes.heat >= 99.9999: player.laser_eyes._overheat()
	return true

func cancel() -> void:
	get_node("/root/SlowMotion").stop(self)
	if casting and is_instance_valid(player.character_animation_player):
		if String(player.character_animation_player.current_animation).begins_with("Thunderstorm/"): player.character_animation_player.stop()
	casting = false
	aiming = false
	_require_release = true
	target = {}
	if is_instance_valid(_marker): _marker.hide()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]: cancel()

func _exit_tree() -> void:
	get_node("/root/SlowMotion").stop(self, true)
	cancel()
