extends CanvasLayer
## Stays with the player through travel; loading owns input during the scene swap.
const PALETTE = preload("res://assets/ui/default_palette.tres")
const TRAVEL = preload("res://scripts/hideout_travel.gd")
@export_range(0.0, 3.0, 0.1) var death_animation_seconds := 1.2
var respawning := false
var _owns_pause := false
@onready var player: PlayerCharacter = get_parent()
@onready var respawn_button: Button = $Screen/Center/Menu/Respawn
@onready var status: Label = $Screen/Center/Menu/Status

func _ready() -> void:
	PALETTE.apply_menu_colors($Screen)
	$Screen/Dimmer.color = Color(PALETTE.background, 0.78)
	player.get_node("PlayerStateMachine/DeadState").death_started.connect(_on_death_started)
	respawn_button.pressed.connect(_respawn)
	hide()

func _on_death_started() -> void:
	# Allow the death animation and sound to play before pausing the world.
	get_tree().create_timer(death_animation_seconds).timeout.connect(_show_death_screen, CONNECT_ONE_SHOT)

func _show_death_screen() -> void:
	if not player.is_dead or respawning: return
	var scene := get_tree().current_scene
	if scene != null:
		var pause_menu := scene.get_node_or_null("PauseMenu")
		if pause_menu != null and pause_menu.visible: pause_menu.resume_game()
		var developer_menu := scene.get_node_or_null("DeveloperMenu")
		if developer_menu != null and developer_menu.visible: developer_menu._set_menu_open(false)
	for menu in get_tree().get_nodes_in_group(&"gameplay_menu"): menu.close_menu()
	_owns_pause = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	status.text = "Return to your hideout with full health and stamina."
	respawn_button.disabled = false
	show()
	respawn_button.grab_focus()

func _process(_delta: float) -> void:
	# An explicit developer reset may also revive the player.
	if visible and not player.is_dead and not respawning: _dismiss()

func _respawn() -> void:
	if respawning or not player.is_dead: return
	respawning = true
	respawn_button.disabled = true
	var travel := get_tree().get_first_node_in_group(&"hideout_travel")
	if travel == null:
		travel = TRAVEL.new()
		travel.name = "HideoutTravel"
		get_tree().root.add_child(travel)
	var succeeded: bool = await travel.respawn_in_hideout(player)
	respawning = false
	if succeeded:
		_dismiss()
	else:
		status.text = "Could not reach the hideout. Please try again."
		respawn_button.disabled = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		respawn_button.grab_focus()

func _dismiss() -> void:
	hide()
	if _owns_pause:
		_owns_pause = false
		get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
