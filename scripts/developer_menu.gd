extends CanvasLayer

const PERFORMANCE_SAMPLE_WINDOW_SECONDS: float = 1.0
const PERFORMANCE_REFRESH_INTERVAL_SECONDS: float = 0.25
const CIVILIAN_SCENE: PackedScene = preload("res://scenes/civilian.tscn")
const HOSTILE_SCENE: PackedScene = preload("res://scenes/hostile.tscn")
const NPC_SPAWN_START_RADIUS: float = 6.0
const NPC_SPAWN_SPACING: float = 2.5
const GOLDEN_ANGLE_RADIANS: float = 2.399963

@onready var show_landing_check_box: CheckBox = $Panel/MarginContainer/Options/ShowLandingCheckBox
@onready var show_performance_hud_check_box: CheckBox = (
	$Panel/MarginContainer/Options/ShowPerformanceHudCheckBox
)
@onready var spawn_civilian_button: Button = $Panel/MarginContainer/Options/SpawnCivilianButton
@onready var spawn_hostile_button: Button = $Panel/MarginContainer/Options/SpawnHostileButton
@onready var strength_spin_box: SpinBox = (
	$Panel/MarginContainer/Options/AttributesGrid/StrengthSpinBox
)
@onready var speed_spin_box: SpinBox = (
	$Panel/MarginContainer/Options/AttributesGrid/SpeedSpinBox
)
@onready var resilience_spin_box: SpinBox = (
	$Panel/MarginContainer/Options/AttributesGrid/ResilienceSpinBox
)
@onready var performance_hud: CanvasLayer = $"../PerformanceHUD"
@onready var performance_label: Label = $"../PerformanceHUD/Panel/MarginContainer/PerformanceLabel"
@onready var player: CharacterBody3D = $"../Player"

var previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var frame_time_samples: Array[float] = []
var sampled_frame_time: float = 0.0
var performance_refresh_elapsed: float = 0.0
var spawned_npc_count: int = 0


func _ready() -> void:
	if not OS.is_debug_build():
		performance_hud.queue_free()
		queue_free()
		return

	visible = false
	performance_hud.visible = DebugManager.show_performance_hud
	show_landing_check_box.toggled.connect(_on_show_landing_check_box_toggled)
	show_performance_hud_check_box.toggled.connect(_on_show_performance_hud_check_box_toggled)
	spawn_civilian_button.pressed.connect(_on_spawn_civilian_button_pressed)
	spawn_hostile_button.pressed.connect(_on_spawn_hostile_button_pressed)
	strength_spin_box.value_changed.connect(_on_strength_spin_box_value_changed)
	speed_spin_box.value_changed.connect(_on_speed_spin_box_value_changed)
	resilience_spin_box.value_changed.connect(_on_resilience_spin_box_value_changed)


func _process(delta: float) -> void:
	if not DebugManager.show_performance_hud:
		return

	_add_frame_time_sample(delta)
	performance_refresh_elapsed += delta
	if performance_refresh_elapsed < PERFORMANCE_REFRESH_INTERVAL_SECONDS:
		return

	performance_refresh_elapsed = 0.0
	_update_performance_label()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_set_menu_open(not visible)
		get_viewport().set_input_as_handled()


func _set_menu_open(is_open: bool) -> void:
	visible = is_open
	DebugManager.developer_menu_open = is_open

	if is_open:
		previous_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		show_landing_check_box.set_pressed_no_signal(DebugManager.show_landing_target)
		show_performance_hud_check_box.set_pressed_no_signal(DebugManager.show_performance_hud)
		_refresh_attribute_controls()
	else:
		Input.mouse_mode = previous_mouse_mode


func _on_show_landing_check_box_toggled(is_enabled: bool) -> void:
	DebugManager.show_landing_target = is_enabled


func _on_show_performance_hud_check_box_toggled(is_enabled: bool) -> void:
	DebugManager.show_performance_hud = is_enabled
	performance_hud.visible = is_enabled
	if is_enabled:
		_reset_performance_samples()
		_update_performance_label()


func _on_spawn_civilian_button_pressed() -> void:
	_spawn_npc(CIVILIAN_SCENE, &"DevCivilian")


func _on_spawn_hostile_button_pressed() -> void:
	_spawn_npc(HOSTILE_SCENE, &"DevHostile")


func _spawn_npc(npc_scene: PackedScene, npc_name: StringName) -> void:
	var npc: CharacterBody3D = npc_scene.instantiate() as CharacterBody3D
	if npc == null:
		push_error("Failed to instantiate the %s scene." % npc_name)
		return

	var spawn_angle: float = spawned_npc_count * GOLDEN_ANGLE_RADIANS
	var spawn_radius: float = (
		NPC_SPAWN_START_RADIUS
		+ sqrt(float(spawned_npc_count)) * NPC_SPAWN_SPACING
	)
	var spawn_position: Vector3 = player.global_position + Vector3(
		cos(spawn_angle) * spawn_radius,
		0.0,
		sin(spawn_angle) * spawn_radius
	)
	spawn_position = _get_grounded_spawn_position(spawn_position)

	npc.name = npc_name
	get_parent().add_child(npc, true)
	npc.global_position = spawn_position
	spawned_npc_count += 1


func _refresh_attribute_controls() -> void:
	strength_spin_box.set_value_no_signal(float(player.get("strength")))
	speed_spin_box.set_value_no_signal(float(player.get("speed")))
	resilience_spin_box.set_value_no_signal(float(player.get("resilience")))


func _on_strength_spin_box_value_changed(value: float) -> void:
	player.set("strength", roundi(value))


func _on_speed_spin_box_value_changed(value: float) -> void:
	player.set("speed", roundi(value))


func _on_resilience_spin_box_value_changed(value: float) -> void:
	player.set("resilience", roundi(value))


func _get_grounded_spawn_position(horizontal_position: Vector3) -> Vector3:
	var ray_start := horizontal_position + Vector3.UP * 50.0
	var ray_end := horizontal_position + Vector3.DOWN * 200.0
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.exclude = [player.get_rid()]
	var result: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return horizontal_position
	return result["position"] + Vector3.UP * 0.05


func _add_frame_time_sample(delta: float) -> void:
	frame_time_samples.append(delta)
	sampled_frame_time += delta
	while (
		sampled_frame_time > PERFORMANCE_SAMPLE_WINDOW_SECONDS
		and frame_time_samples.size() > 1
	):
		sampled_frame_time -= frame_time_samples.pop_front()


func _reset_performance_samples() -> void:
	frame_time_samples.clear()
	sampled_frame_time = 0.0
	performance_refresh_elapsed = 0.0


func _update_performance_label() -> void:
	var average_frame_time_ms: float = 0.0
	var worst_frame_time_ms: float = 0.0
	if not frame_time_samples.is_empty():
		average_frame_time_ms = (
			sampled_frame_time / float(frame_time_samples.size())
		) * 1000.0
		for frame_time in frame_time_samples:
			worst_frame_time_ms = maxf(worst_frame_time_ms, frame_time * 1000.0)

	var civilian_count: int = 0
	var moving_civilian_count: int = 0
	for civilian in get_tree().get_nodes_in_group(&"civilian"):
		civilian_count += 1
		if civilian is CharacterBody3D:
			var civilian_body: CharacterBody3D = civilian as CharacterBody3D
			if Vector2(civilian_body.velocity.x, civilian_body.velocity.z).length() > 0.1:
				moving_civilian_count += 1

	var draw_calls: int = RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
	)
	performance_label.text = (
		"Performance\n"
		+ "FPS: %d | Frame: %.2f ms avg | %.2f ms worst\n" % [
			roundi(Engine.get_frames_per_second()),
			average_frame_time_ms,
			worst_frame_time_ms
		]
		+ "Draw calls: %d | Scene nodes: %d\n" % [
			draw_calls,
			get_tree().get_node_count()
		]
		+ "Civilians: %d (%d moving) | Vehicles: %d" % [
			civilian_count,
			moving_civilian_count,
			get_tree().get_nodes_in_group(&"explodable").size()
		]
	)
