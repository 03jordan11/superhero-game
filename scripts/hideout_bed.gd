extends Node3D
## Instant rest at the cot, using the same rebindable interaction as the door.
const COPY = preload("res://scripts/ui-scripts/powers_text.gd")
@export_range(1.0, 24.0, 0.5) var sleep_hours := 8.0
@export_range(0.5, 3.0, 0.1) var interaction_distance := 1.6
@export_range(2.0, 10.0, 0.5) var marker_distance := 4.0
var _refresh := 0.0
var _rested_until := 0
@onready var prompt: Label3D = $Prompt

func _enter_tree() -> void:
	add_to_group(&"hideout_beds")

func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh > 0.0: return
	_refresh = 0.15
	var player := get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	prompt.visible = player != null and global_position.distance_to(player.global_position) < marker_distance
	if not prompt.visible: return
	if Time.get_ticks_msec() < _rested_until:
		prompt.text = COPY.text("bed.rested")
		return
	var bindings: Node = get_node("/root/GameSettings").input_bindings
	var hours := String.num(sleep_hours, 1).trim_suffix(".0")
	prompt.text = COPY.text("bed.interact", {"key": bindings.label_for("pick_up_vehicle", bindings.active_device), "hours": hours}) if can_interact(player) else COPY.text("bed.name")

func can_interact(player: PlayerCharacter) -> bool:
	if get_tree().paused or DebugManager.developer_menu_open or Time.get_ticks_msec() < _rested_until: return false
	if player.is_dead or player.is_knocked_out or player.is_carrying(): return false
	if player.combat_controller.is_action_locked() or player.ship_interaction.is_attached(): return false
	if player.is_flying or player.is_jump_active or player.is_ground_slamming or player.is_wall_running: return false
	if player.is_charging_jump or player.is_charging_flight: return false
	if player.get_node("PlayerPowerController").is_selector_open(): return false
	if get_tree().get_first_node_in_group(&"game_clock") == null: return false
	if global_position.distance_to(player.global_position) > interaction_distance: return false
	# A wall between the hero's chest and the mattress blocks interaction.
	var query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.8, global_position, 1, [player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func try_interact(player: PlayerCharacter) -> bool:
	if not can_interact(player): return false
	var clock := get_tree().get_first_node_in_group(&"game_clock")
	clock.advance_hours(sleep_hours)
	player.damage_receiver.restore_full_health()
	player.velocity = Vector3.ZERO
	_rested_until = Time.get_ticks_msec() + 2000
	_refresh = 0.0
	_process(0.0)
	return true
