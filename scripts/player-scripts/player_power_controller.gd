extends Node
## Applies purchased abilities and derived bonuses without changing base stats.
@export_range(0, 100, 1) var strength_core_bonus: int = 5
@export_range(0, 100, 1) var speed_core_bonus: int = 5
const PROGRESSION = preload("res://scripts/ui-scripts/power_menu_progression.gd")
const REQUIREMENTS := {
	PlayerAbilities.POWER_JUMP: ["super_leap", 0],
	PlayerAbilities.AIR_JUMP: ["super_leap", 2],
	PlayerAbilities.BOUNDING: ["super_leap", 3],
	PlayerAbilities.SUPER_SPEED: ["super_speed", 0],
	PlayerAbilities.WALL_RUN: ["super_speed", 3],
	PlayerAbilities.FLIGHT: ["flight", 0],
	PlayerAbilities.FLIGHT_BOOST: ["flight", 1],
	PlayerAbilities.GROUND_SLAM: ["flight", 2],
	PlayerAbilities.VEHICLE_LIFT: ["strength", 2],
	PlayerAbilities.TROUBLE_SENSE: ["mind", 0],
}
var progression = PROGRESSION.new()
var last_save_succeeded := false
@onready var player: PlayerCharacter = get_parent()

func _ready() -> void:
	progression.changed.connect(sync_abilities)
	progression.purchased.connect(_save_progression)
	sync_abilities()

func sync_abilities() -> void:
	player.charged_jump_output_multiplier = 2.0 if progression.level("super_leap") >= 1 else 1.0
	player.get_node("PlayerStamina").running_drain_multiplier = 0.5 if progression.level("super_speed") >= 1 else 1.0
	player.stats.set_power_bonuses(
		strength_core_bonus if progression.level("strength") >= 0 else 0,
		speed_core_bonus if progression.level("super_speed") >= 0 else 0)
	for ability in REQUIREMENTS:
		var requirement: Array = REQUIREMENTS[ability]
		player.abilities.set_unlocked(ability, progression.level(requirement[0]) >= requirement[1])
	# Loading a locked save must also end any already-active traversal/charge.
	if not player.is_node_ready(): return
	player.bounding_controller.reset()
	if (player.is_flying and not player.abilities.is_unlocked(PlayerAbilities.FLIGHT)) or (player.is_charging_jump and not player.abilities.is_unlocked(PlayerAbilities.POWER_JUMP)) or (player.is_wall_running and not player.abilities.is_unlocked(PlayerAbilities.WALL_RUN)) or (player.is_ground_slamming and not player.abilities.is_unlocked(PlayerAbilities.GROUND_SLAM)):
		player.state_machine.transition_to(&"GroundedState" if player.is_on_floor() else &"AirborneState")
	if not player.abilities.is_unlocked(PlayerAbilities.VEHICLE_LIFT): player.vehicle_interactor.drop_held_vehicle()
	player.input_controller.reset()

func _save_progression() -> void:
	last_save_succeeded = get_node("/root/SaveManager").save_game()

func attribute_bonus(attribute: String) -> int:
	return player.stats.get_power_bonus(StringName(attribute))
