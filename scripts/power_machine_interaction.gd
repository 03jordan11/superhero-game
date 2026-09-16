extends Node3D
## Uses the player's existing interact action and authoritative Powers page.
const COPY = preload("res://scripts/ui-scripts/powers_text.gd")
const MENU = preload("res://scripts/ui-scripts/gameplay_menu.gd")
@export_range(0.5, 4.0, 0.1) var interaction_distance := 2.0
@export_range(2.0, 15.0, 0.5) var marker_distance := 6.0
@export var front_point := Vector3(0, 1.1, 0.85)
@export_range(0.1, 3.0, 0.05) var panel_half_width := 1.75
var _refresh := 0.0
@onready var prompt: Label3D = $Prompt

func _enter_tree() -> void:
	add_to_group(&"power_machines")

func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh > 0.0: return
	_refresh = 0.15
	var player := get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	prompt.visible = player != null and global_position.distance_to(player.global_position) < marker_distance
	if not prompt.visible: return
	var bindings: Node = get_node("/root/GameSettings").input_bindings
	prompt.text = COPY.text("machine.interact", {"key": bindings.label_for("pick_up_vehicle", bindings.active_device)}) if can_interact(player) else COPY.text("machine.name")

func can_interact(player: PlayerCharacter) -> bool:
	if get_tree().paused or DebugManager.developer_menu_open: return false
	if player.is_dead or player.is_knocked_out or player.is_carrying(): return false
	if player.combat_controller.is_action_locked() or player.ship_interaction.is_attached(): return false
	if player.is_ground_slamming or player.is_wall_running or player.is_charging_jump or player.is_charging_flight: return false
	if player.get_node("PlayerPowerController").is_selector_open(): return false
	var point := to_local(player.global_position)
	# Reach any part of the front panel, without using it through the back wall.
	if point.z < 0.25: return false
	var nearest := front_point
	nearest.x = clampf(point.x, -panel_half_width, panel_half_width)
	return player.global_position.distance_to(to_global(nearest)) <= interaction_distance

func try_interact(player: PlayerCharacter) -> bool:
	if not can_interact(player): return false
	var menu: Node = null
	for candidate in get_tree().get_nodes_in_group(&"gameplay_menu"):
		if candidate.player == player:
			menu = candidate
			break
	if menu == null:
		# Standalone F6 room previews do not inherit the city's menus.
		menu = MENU.new()
		menu.name = "GameplayMenu"
		player.get_parent().add_child(menu)
	menu.open_menu(0)
	return menu.visible
