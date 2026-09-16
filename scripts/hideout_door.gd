extends Node3D
## A door consumes the existing E / pick-up action before nearby grab interactions.
@export var is_exit := false
@export_file("*.tscn") var interior_scene := "res://assets/buildings/gas_station_hideout/gas_station_interior.tscn"
@export_range(1.0, 4.0, 0.1) var interaction_distance := 2.4
@export_range(3.0, 30.0, 1.0) var marker_distance := 16.0
var _refresh := 0.0
@onready var label: Label3D = $Prompt

func _enter_tree() -> void:
	add_to_group(&"hideout_doors")

func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh > 0.0: return
	_refresh = 0.15
	var player := get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	label.visible = player != null and global_position.distance_to(player.global_position) < marker_distance
	if not label.visible: return
	var bindings: Node = get_node("/root/GameSettings").input_bindings
	var key: String = bindings.label_for("pick_up_vehicle", bindings.active_device)
	label.text = ("[%s] EXIT" if is_exit else "[%s] ENTER HIDEOUT") % key if can_interact(player) else ("EXIT" if is_exit else "HIDEOUT")

func can_interact(player: PlayerCharacter) -> bool:
	if player.is_dead or player.is_knocked_out or player.is_carrying(): return false
	if player.combat_controller.is_action_locked() or player.ship_interaction.is_attached(): return false
	if player.is_ground_slamming or player.is_wall_running or player.is_charging_jump: return false
	if global_position.distance_to(player.global_position) > interaction_distance: return false
	# Only the front side of this marker is usable (never through the exterior wall).
	return to_local(player.global_position).z > -0.15

func try_interact(player: PlayerCharacter) -> bool:
	if not can_interact(player): return false
	var travel := get_tree().get_first_node_in_group(&"hideout_travel")
	if travel == null:
		if is_exit: return false
		travel = preload("res://scripts/hideout_travel.gd").new()
		travel.name = "HideoutTravel"
		get_tree().root.add_child(travel)
	return travel.request_transition(self, player)
