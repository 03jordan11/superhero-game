extends SceneTree

const THUG = preload("res://scenes/npcs/pistol_thug.tscn")
const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func spawn_thug(world: Node3D, at: Vector3) -> PistolHostile:
	var thug := THUG.instantiate() as PistolHostile
	thug.position = at
	world.add_child(thug)
	thug.set_physics_process(false)
	return thug

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	var player := load("res://scenes/player.tscn").instantiate() as PlayerCharacter
	world.add_child(player)
	player.position.y = 1.0
	player.set_physics_process(false)
	var thug := spawn_thug(world, Vector3(0, 0, 8))
	var ally := spawn_thug(world, Vector3(5, 0, 8))
	var stranger := spawn_thug(world, Vector3(-5, 0, 8))
	stranger.faction = &"test_other_faction"
	var far_ally := spawn_thug(world, Vector3(80, 0, 8))
	check(thug is HostileBase and thug is RangedHostile, "Pistol thug inherits shared enemy and ranged behavior")
	check(thug.faction == &"mafia" and thug.enemy_type == &"pistol_thug", "Scene defines Mafia pistol thug identity")
	check(thug.get_current_health() == 100 and thug.experience_gain == 10 and thug.ammo_count == 6, "Existing balance is preserved")
	check(thug.weapon.calculate_damage(5) == 5 and thug.weapon.calculate_damage(30) == 2, "Inspector weapon resource preserves damage falloff")
	await physics_frame
	await physics_frame
	# Walls block initial detection; alerts can still reach allies behind cover.
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(6, 5, 1)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	wall.position = Vector3(0, 2, 4)
	world.add_child(wall)
	await physics_frame
	thug._handle_guard()
	check(thug.current_state == HostileBase.State.GUARD, "Thug cannot detect the player through a wall")
	wall.free()
	await physics_frame
	thug.aggressive_to_player = false
	thug._handle_guard()
	check(thug.current_state == HostileBase.State.GUARD, "Aggression is independent of faction")
	thug.aggressive_to_player = true
	thug._handle_guard()
	check(thug.current_state == HostileBase.State.COMBAT and ally.current_state == HostileBase.State.COMBAT, "Visible player alerts nearby Mafia allies")
	check(stranger.current_state == HostileBase.State.GUARD and far_ally.current_state == HostileBase.State.GUARD, "Alerts exclude other factions and distant allies")
	thug.receive_alert(ally)
	check(thug.combat_target == player, "Alerts cannot target an ally")
	thug._handle_pistol_combat(0.01)
	check(thug.ammo_count == 5 and ally.ammo_count == 6, "Ammo is per instance")
	thug.current_state = HostileBase.State.GUARD
	thug.combat_target = null
	thug.apply_damage(DAMAGE.new(1.0, player.global_position, Vector3.ZERO, &"none", player))
	check(thug.combat_target == player and thug.current_state == HostileBase.State.COMBAT, "Damage acquires the attacker")
	check(thug.get_current_health() == 99 and ally.get_current_health() == 100, "Health is per instance")
	# Restart an interrupted empty-magazine reload and complete the real animation.
	var anim: AnimationPlayer = thug.animation_controller.animation_player
	anim.advance(5.0)
	thug._process_hit_reaction(5.0)
	thug.ammo_count = 0
	thug._handle_pistol_combat(0.01)
	check(thug.is_reloading, "Empty magazine starts reload")
	thug.apply_damage(DAMAGE.new(1.0, player.global_position, Vector3.ZERO, &"none", player))
	check(not thug.is_reloading and not thug.reload_completed, "Hit cancels in-progress reload without refilling")
	anim.advance(5.0)
	thug._process_hit_reaction(5.0)
	thug._handle_pistol_combat(0.01)
	anim.advance(anim.current_animation_length + 0.1)
	check(thug.reload_completed, "Real reload animation signals completion")
	thug._handle_pistol_combat(0.01)
	check(not thug.is_reloading and thug.ammo_count == 5, "Completed reload refills and fires next round")
	player.stats.level = 1
	player.stats.experience = 0
	var deaths := [0]
	thug.died.connect(func(_npc): deaths[0] += 1)
	thug.apply_damage(DAMAGE.new(1000.0, player.global_position, Vector3.ZERO, &"none", player))
	thug._die()
	thug.apply_damage(DAMAGE.new(1000.0))
	thug.receive_alert(player)
	check(deaths[0] == 1 and player.stats.experience == 10, "Death notification and XP happen exactly once")
	check(thug.current_state == HostileBase.State.DEAD and not thug.alert_indicator.visible, "Dead thug cannot re-enter combat")
	var legacy := load("res://scenes/npcs/hostile.tscn").instantiate() as PistolHostile
	check(legacy != null and legacy.faction == &"mafia", "Legacy scene resolves to the canonical Mafia thug")
	legacy.free()
	# The encounter now builds a level-scaled roster.
	var encounter := preload("res://scripts/encounter-scripts/gang-activity/gang_activity.gd").new()
	encounter.easy_rifle_chance = 1.0
	encounter.random_location_radius = 0.0
	player.stats.level = 1
	world.add_child(encounter)
	player.stats.experience = 0
	encounter.start_encounter()
	check(encounter.active_hostiles.size() == 4, "Easy encounter spawns its four-enemy roster")
	for enemy in encounter.active_hostiles.duplicate():
		enemy._die()
	check(encounter.state == BaseEncounter.EncounterState.COMPLETED, "Existing died signal completes encounter")
	check(player.stats.level == 2 and player.stats.experience == 40, "Enemy XP and completion XP are each awarded once")
	world.free()
	print("Pistol thug: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
