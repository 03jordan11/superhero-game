extends Node3D
## World-space button. The normal E / interact pipeline owns input consumption.
signal activated(enemy_id: StringName)
@export var enemy_id: StringName = &"melee_thug"
@export var display_name := "MELEE THUG"
@export_range(1.0, 5.0, 0.1) var interaction_distance := 2.8
@export_range(0.1, 3.0, 0.1) var cooldown_seconds := 0.6
var cooldown := 0.0
var prompt: Label3D
var button_mesh: MeshInstance3D

func _enter_tree() -> void:
	add_to_group(&"combat_arena_stations")

func _ready() -> void:
	var base := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.2, 1.05, 0.8)
	base.mesh = mesh
	base.position.y = 0.525
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.018, 0.035, 0.028)
	dark.metallic = 0.7
	base.material_override = dark
	add_child(base)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = mesh.size
	collision.shape = box
	collision.position = base.position
	body.add_child(collision)
	add_child(body)
	button_mesh = MeshInstance3D.new()
	var button := CylinderMesh.new()
	button.top_radius = 0.27
	button.bottom_radius = 0.27
	button.height = 0.1
	button_mesh.mesh = button
	button_mesh.position.y = 1.12
	var green := StandardMaterial3D.new()
	green.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	green.albedo_color = Color(0.08, 1.0, 0.4)
	green.emission_enabled = true
	green.emission = green.albedo_color
	button_mesh.material_override = green
	add_child(button_mesh)
	var label := Label3D.new()
	label.position.y = 2.0
	label.text = display_name
	label.font_size = 40
	label.pixel_size = 0.008
	label.modulate = Color(0.3, 1.0, 0.6)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	prompt = Label3D.new()
	prompt.position.y = 1.55
	prompt.font_size = 32
	prompt.pixel_size = 0.008
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(prompt)

func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	button_mesh.position.y = 1.07 if cooldown > 0.0 else 1.12
	var hero := get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	prompt.visible = hero != null and can_interact(hero)
	if prompt.visible:
		var bindings: Node = get_node("/root/GameSettings").input_bindings
		prompt.text = "[%s] %s" % [bindings.label_for("pick_up_vehicle", bindings.active_device), "RESET" if enemy_id == &"reset" else "SPAWN"]

func can_interact(hero: PlayerCharacter) -> bool:
	if get_tree().paused or DebugManager.developer_menu_open or cooldown > 0.0: return false
	if hero.is_dead or hero.is_knocked_out or hero.is_carrying() or hero.is_dodging: return false
	if hero.combat_controller.is_action_locked() or hero.ship_interaction.is_attached(): return false
	if hero.is_ground_slamming or hero.is_wall_running or hero.is_charging_jump or hero.is_charging_flight: return false
	if hero.get_node("PlayerPowerController").is_selector_open(): return false
	var toward := global_position + Vector3.UP - hero.camera.global_position
	return hero.global_position.distance_to(global_position) <= interaction_distance and -hero.camera.global_basis.z.dot(toward.normalized()) > 0.65

func try_interact(hero: PlayerCharacter) -> bool:
	if not can_interact(hero): return false
	cooldown = cooldown_seconds
	# Spawning/freeing collision objects must happen outside the physics callback.
	activated.emit.call_deferred(enemy_id)
	return true
