extends SceneTree

const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func bullet(amount: float):
	var damage = DAMAGE.new(amount)
	damage.damage_type = &"bullet"
	return damage

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	preload("res://tests/player_test_support.gd").unlock_current_powers(player)
	player.set_physics_process(false)
	var manager = player.get_node("PlayerSoundManager")
	manager.set_process(false)
	var audio: AudioStreamPlayer = manager.get_node("BulletHit")
	check(not audio.playing, "No bullet sound at spawn")
	player.apply_damage(DAMAGE.new(1.0))
	check(not audio.playing, "Other damage does not trigger bullet audio")
	check(not player.apply_damage(bullet(0.0)) and not audio.playing, "Rejected damage is silent")
	player.apply_damage(bullet(1.0))
	check(audio.playing, "Accepted bullet damage triggers the connected audio node")
	check(audio.stream is AudioStreamWAV and audio.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Bullet impact is a one-shot WAV")
	check(is_equal_approx(audio.stream.get_length(), 0.42), "Generated impact imports at the intended duration")
	check(audio.volume_db == -6.0 and audio.pitch_scale >= 0.92 and audio.pitch_scale <= 1.08, "Volume and variation apply")
	check(audio.max_polyphony == 4, "Rapid hits can overlap")
	audio.stop()
	manager.sounds_enabled = false
	player.apply_damage(bullet(1.0))
	check(not audio.playing, "Player sound mute includes bullet hits")
	manager.sounds_enabled = true
	var stream: AudioStream = manager.bullet_hit_sound
	manager.bullet_hit_sound = null
	player.apply_damage(bullet(1.0))
	check(not audio.playing, "Missing sound is safe")
	manager.bullet_hit_sound = stream
	manager.bullet_hit_volume_db = -12.0
	manager.bullet_hit_pitch_variation = 0.0

	# Exercise the actual hostile shot and collision path, with guaranteed accuracy.
	var hostile = load("res://scenes/npcs/hostile.tscn").instantiate()
	world.add_child(hostile)
	hostile.set_physics_process(false)
	hostile.position = Vector3(0, 0, 5)
	hostile.combat_target = player
	hostile.pistol_shot_origin_height = 0.0
	hostile.pistol_target_height = 0.0
	hostile.pistol_weapon = hostile.pistol_weapon.duplicate()
	hostile.pistol_weapon.close_stationary_hit_chance = 1.0
	await physics_frame
	await physics_frame
	hostile._resolve_pistol_shot()
	check(audio.playing, "Actual hostile pistol hit is classified as a bullet and plays audio")
	check(audio.volume_db == -12.0 and audio.pitch_scale == 1.0, "Inspector tuning applies to the next shot")
	audio.stop()
	hostile.pistol_weapon.close_stationary_hit_chance = 0.0
	hostile._resolve_pistol_shot()
	check(not audio.playing, "Missed shot does not play impact audio")
	player.apply_damage(bullet(player.get_current_health()))
	check(player.is_dead and audio.playing, "Fatal bullet still plays its impact")
	audio.stop()
	check(not player.apply_damage(bullet(1.0)) and not audio.playing, "Hits after death are rejected and silent")
	world.free()
	print("Player bullet hit audio: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
