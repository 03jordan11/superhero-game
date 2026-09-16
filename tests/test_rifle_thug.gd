extends SceneTree

const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var target := CharacterBody3D.new()
	world.add_child(target)
	target.position = Vector3(0, 0, -20)
	var pistol := preload("res://scenes/npcs/pistol_thug.tscn").instantiate()
	var rifle := preload("res://scenes/npcs/rifle_thug.tscn").instantiate()
	world.add_child(pistol)
	world.add_child(rifle)
	for enemy in [pistol, rifle]:
		enemy.set_physics_process(false)
		enemy.combat_target = target
		enemy.base_relocation_chance = 0.0
		enemy.max_relocation_chance = 0.0
		enemy.animation_controller.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	check(rifle.enemy_type == &"rifle_thug" and rifle.faction == &"mafia" and rifle.magazine_size == 30 and rifle.ammo_count == 30, "Rifle scene initializes Mafia identity and 30 rounds")
	check(pistol.magazine_size == 6 and pistol.automatic_shot_interval == 0.0, "Pistol keeps its original magazine and timing")
	check(pistol.nameplate.text == "Pistol" and pistol.nameplate.modulate == Color("66e080"), "Pistol has requested green label")
	check(rifle.nameplate.text == "RIFLE" and rifle.nameplate.modulate == Color("c5b458"), "Rifle has requested dull yellow label")
	check(rifle.nameplate.font.font_weight == 700 and rifle.nameplate.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "Labels use bold font and face the camera")
	check(rifle.nameplate.position.y > rifle.health_label.position.y and rifle.alert_indicator.position.y > rifle.nameplate.position.y, "Name, health and alert have separate heights")
	check(HostileBase.NAMEPLATE_COLORS[HostileBase.NameplateKind.MELEE] == Color("e55d5d") and HostileBase.NAMEPLATE_COLORS[HostileBase.NameplateKind.SUPER] == Color("ef9a42") and HostileBase.NAMEPLATE_COLORS[HostileBase.NameplateKind.SNIPER] == Color("639df5"), "Red, orange and blue are reserved")
	for tick in 100:
		for enemy in [pistol, rifle]:
			enemy._handle_ranged_combat(0.01)
			enemy.animation_controller.animation_player.advance(0.01)
	var rifle_shots: int = 30 - rifle.ammo_count
	var pistol_shots: int = 6 - pistol.ammo_count
	check(rifle_shots >= 7 and rifle_shots > pistol_shots * 2, "Rifle fires substantially faster despite sharing the pistol animation")
	rifle._reset_combat_actions()
	rifle.ammo_count = 30
	rifle.shots_since_relocation = 0
	for tick in 500:
		rifle._handle_ranged_combat(0.01)
		if rifle.is_reloading:
			break
		rifle.animation_controller.animation_player.advance(0.01)
	check(rifle.ammo_count == 0 and rifle.shots_since_relocation == 30 and rifle.is_reloading, "Rifle fires all 30 rounds then reloads")
	var animation: AnimationPlayer = rifle.animation_controller.animation_player
	animation.advance(animation.current_animation_length + 0.1)
	check(rifle.reload_completed, "Existing reload animation completes rifle reload")
	rifle._handle_ranged_combat(0.01)
	check(rifle.ammo_count == 29 and not rifle.is_reloading, "Reload refills 30 and resumes fire")
	rifle.ammo_count = 0
	rifle._reset_combat_actions()
	rifle._handle_ranged_combat(0.01)
	rifle.apply_damage(DAMAGE.new(1, target.global_position, Vector3.ZERO, &"none", target))
	check(not rifle.is_reloading and not rifle.reload_completed and rifle.ammo_count == 0, "Hit interrupts reload without free ammunition")
	pistol.current_state = HostileBase.State.GUARD
	rifle._alert_nearby_hostiles(target)
	check(pistol.combat_target == target and pistol.current_state == HostileBase.State.COMBAT, "Rifle alerts Mafia pistol allies")
	rifle._die()
	check(not rifle.nameplate.visible, "Nameplate hides on defeat")
	world.free()
	print("Rifle thug: %s (%d rifle vs %d pistol rounds in 1s)" % ["PASS" if failures == 0 else "FAIL", rifle_shots, pistol_shots])
	quit(0 if failures == 0 else 1)
