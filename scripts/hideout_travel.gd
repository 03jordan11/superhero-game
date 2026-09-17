extends Node
const CLOCK = preload("res://scripts/game_clock.gd")
## Scene travel keeps only the Player alive; the city and its encounters reload.
@export_category("Hideout Camera")
@export var shoulder_offset := Vector3(0.6, 0.75, 0.0)
@export_range(0.5, 3.0, 0.05) var shoulder_distance := 1.5
@export_range(-30.0, 10.0, 1.0) var shoulder_pitch_degrees := -8.0
var player: PlayerCharacter
var _city_path := ""
var _player_path := NodePath("Player")
var _return_transform: Transform3D
var _spring_length := 5.0
var _spring_margin := 0.01
var _spring_shape: Shape3D
var _spring_rotation := Vector3.ZERO
var _spring_base_position := Vector3.ZERO
var _busy := false
var _cooldown_until := 0
var _inside := false

func _enter_tree() -> void:
	add_to_group(&"hideout_travel")

func request_transition(door: Node3D, target: PlayerCharacter) -> bool:
	if _busy or Time.get_ticks_msec() < _cooldown_until: return true
	if door.is_exit != _inside: return false
	if not door.is_exit and get_tree().current_scene.scene_file_path.is_empty():
		push_warning("Hideout entrance requires a saved city scene to return to.")
		return false
	_busy = true
	player = target
	if door.is_exit: _leave.call_deferred()
	else: _enter.call_deferred(door)
	return true

func start_in_hideout(target: PlayerCharacter) -> bool:
	# Loading bypasses interaction distance; the normal entrance still determines
	# the interior and the safe return position outside the station.
	for door in get_tree().get_nodes_in_group(&"hideout_doors"):
		if not door.is_exit and get_tree().current_scene.is_ancestor_of(door):
			player = target
			_busy = true
			return _enter(door)
	return false

func _enter(door: Node3D) -> bool:
	var packed := load(door.interior_scene) as PackedScene
	if packed == null:
		push_error("Could not load hideout interior: " + door.interior_scene)
		_busy = false
		return false
	var room := packed.instantiate() as Node3D
	if room == null or not room.has_node("PlayerSpawn"):
		if room != null: room.free()
		push_error("Hideout interior needs a PlayerSpawn marker.")
		_busy = false
		return false
	var city := get_tree().current_scene
	_copy_clock(city, room)
	_city_path = city.scene_file_path
	_player_path = city.get_path_to(player)
	_return_transform = Transform3D(door.global_basis.orthonormalized() * Basis(Vector3.UP, PI), door.to_global(Vector3(0, 0.4, 1.4)))
	_spring_length = player.spring_arm.spring_length
	_spring_margin = player.spring_arm.margin
	_spring_shape = player.spring_arm.shape
	_spring_rotation = player.spring_arm.rotation
	_spring_base_position = player.camera_effects.base_spring_arm_position
	_reset_player()
	player.reparent(self)
	# Keep working menus indoors; discard them when the city reloads.
	for child in city.get_children():
		if child is CanvasLayer: child.reparent(self)
	get_tree().current_scene = null
	city.free()
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	for child in get_children(): child.reparent(room)
	player.global_transform = room.get_node("PlayerSpawn").global_transform
	player.ground_facing_yaw = player.global_rotation.y
	player.spring_arm.spring_length = shoulder_distance
	player.camera_effects.base_spring_arm_position = shoulder_offset
	player.spring_arm.position = shoulder_offset
	# Door panels sit slightly in front of wall collision; keep the camera clear.
	player.spring_arm.margin = 0.25
	var camera_clearance := SphereShape3D.new()
	camera_clearance.radius = 0.3
	player.spring_arm.shape = camera_clearance
	player.spring_arm.rotation = Vector3(deg_to_rad(shoulder_pitch_degrees), 0, 0)
	_inside = true
	_finish()
	return true

func _leave() -> void:
	var packed := load(_city_path) as PackedScene
	if packed == null:
		push_error("Could not reload city: " + _city_path)
		_busy = false
		return
	var city := packed.instantiate()
	_copy_clock(get_tree().current_scene, city)
	var placeholder := city.get_node_or_null(_player_path)
	if placeholder == null:
		city.free()
		push_error("Reloaded city is missing its player spawn.")
		_busy = false
		return
	var destination_parent := placeholder.get_parent()
	var player_name := placeholder.name
	var player_index := placeholder.get_index()
	placeholder.free()
	_reset_player()
	player.reparent(self)
	var room := get_tree().current_scene
	get_tree().current_scene = null
	room.free()
	# Insert the existing hero before the new city's UI initializes.
	player.get_parent().remove_child(player)
	player.name = player_name
	destination_parent.add_child(player)
	destination_parent.move_child(player, player_index)
	# Set the arrival pose before city population scripts initialize around the hero.
	var parent_pose := Transform3D.IDENTITY
	var ancestor: Node = destination_parent
	while ancestor != null:
		if ancestor is Node3D: parent_pose = ancestor.transform * parent_pose
		ancestor = ancestor.get_parent()
	player.transform = parent_pose.affine_inverse() * _return_transform
	get_tree().root.add_child(city)
	get_tree().current_scene = city
	player.global_transform = _return_transform
	player.ground_facing_yaw = player.global_rotation.y
	player.spring_arm.spring_length = _spring_length
	player.spring_arm.margin = _spring_margin
	player.spring_arm.shape = _spring_shape
	player.spring_arm.rotation = _spring_rotation
	player.camera_effects.base_spring_arm_position = _spring_base_position
	player.spring_arm.position = _spring_base_position
	_inside = false
	_finish()

func _find_clock(scene: Node) -> Node:
	if scene is CLOCK: return scene
	for child in scene.get_children():
		var clock := _find_clock(child)
		if clock != null: return clock
	return null

func _copy_clock(source: Node, destination: Node) -> void:
	var from := _find_clock(source)
	var to := _find_clock(destination)
	if from != null and to != null: to.copy_from(from)

func _reset_player() -> void:
	player.target_lock.release()
	player.combat_controller.cancel_punch()
	player.input_controller.reset()
	player.bounding_controller.reset()
	player.flying_state.cancel_charge()
	player.flying_state.surge_remaining = 0.0
	player.flying_state.is_boosting = false
	player.state_machine.transition_to(&"GroundedState")
	player.velocity = Vector3.ZERO
	player.current_flight_speed = 0.0
	player.is_jump_active = false
	player.air_jump_used = false
	player.ground_slam_impact_pending = false
	player.landing_impact_controller.reset_normal_landing_tracking()
	player.landing_impact_controller.max_effect_downward_speed = 0.0
	player.camera_effects.shake_time_remaining = 0.0
	player.camera_effects.impact_kick_offset = 0.0
	player.animation_controller._play_animation("Idle")

func _finish() -> void:
	_busy = false
	_cooldown_until = Time.get_ticks_msec() + 650
	player.camera.make_current()
	player.reset_physics_interpolation()
	var hud := get_tree().current_scene.get_node_or_null("PerformanceHUD")
	if hud != null: hud._set_enabled(DebugManager.show_performance_hud)
	Input.action_release("pick_up_vehicle")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
