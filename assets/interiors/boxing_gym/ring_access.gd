extends Node3D
## Uses the player's existing interact action (E by default), before grabs.
@export_node_path("Node3D") var stairs_path := NodePath("../RingSteps")
@export_node_path("Node3D") var ring_path := NodePath("../BoxingRing")
@export var corner_position := Vector3(-2.2, 2.05, 2.2)
@export var stair_return_position := Vector3(0, 1.05, 2.15)
var _cooldown_until := 0
var _refresh := 0.0
@onready var stairs: Node3D = get_node(stairs_path)
@onready var ring: Node3D = get_node(ring_path)
@onready var prompt: Label3D = $Prompt

func _enter_tree() -> void:
	add_to_group(&"boxing_ring_access")

func is_inside(player: PlayerCharacter) -> bool:
	var p := ring.to_local(player.global_position)
	return absf(p.x) < 3.05 and absf(p.z) < 3.05 and p.y > 1.6

func can_interact(player: PlayerCharacter) -> bool:
	if player.is_dead or player.is_knocked_out or player.is_carrying(): return false
	if player.combat_controller.is_action_locked() or player.ship_interaction.is_attached(): return false
	if player.is_flying or player.is_ground_slamming or player.is_wall_running or player.is_charging_jump: return false
	if not player.is_on_floor(): return false
	if is_inside(player):
		return ring.to_local(player.global_position).distance_to(corner_position) < 1.6
	var p := stairs.to_local(player.global_position)
	return absf(p.x) < 1.15 and p.z > -.25 and p.z < 2.8 and p.y > .7 and p.y < 2.5

func try_interact(player: PlayerCharacter) -> bool:
	if not can_interact(player): return false
	if Time.get_ticks_msec() < _cooldown_until: return true
	var leaving := is_inside(player)
	var destination := stairs.global_transform if leaving else ring.global_transform
	destination.origin = stairs.to_global(stair_return_position) if leaving else ring.to_global(corner_position)
	destination.basis *= Basis(Vector3.UP, PI if leaving else -PI/4)
	player.target_lock.release()
	player.input_controller.reset()
	player.bounding_controller.reset()
	player.velocity = Vector3.ZERO
	player.current_ground_speed = 0
	player.is_jump_active = false
	player.air_jump_used = false
	player.landing_impact_controller.reset_normal_landing_tracking()
	player.landing_impact_controller.max_effect_downward_speed = 0
	player.camera_effects.shake_time_remaining = 0
	player.camera_effects.impact_kick_offset = 0
	player.state_machine.transition_to(&"GroundedState")
	player.global_transform = destination
	player.ground_facing_yaw = player.global_rotation.y
	player.spring_arm.rotation.y = 0
	player.reset_physics_interpolation()
	_cooldown_until = Time.get_ticks_msec() + 450
	prompt.hide()
	return true

func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh > 0: return
	_refresh = .1
	var player := get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	prompt.visible = player != null and can_interact(player)
	if not prompt.visible: return
	var bindings: Node = get_node("/root/GameSettings").input_bindings
	var key: String = bindings.label_for("pick_up_vehicle", bindings.active_device)
	var inside := is_inside(player)
	prompt.text = ("[%s] LEAVE RING" if inside else "[%s] ENTER RING") % key
	prompt.global_position = ring.to_global(corner_position + Vector3(0,.9,0)) if inside else stairs.to_global(Vector3(0,2.3,.75))
