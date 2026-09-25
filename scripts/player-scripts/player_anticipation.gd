extends Node
## Opening-swing duck and targeted counter. Input windows use unscaled seconds.
const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
enum Phase { IDLE, DUCK, READY, COUNTER }
@export_range(0.1, 1.0, 0.01) var warning_window := 0.35
@export_range(0.1, 1.0, 0.01) var counter_window := 0.5
@export_range(0.01, 1.0, 0.01) var stamina_fraction := 0.1
@export var counter_damage_multiplier := 2.0
@export var counter_range := 3.5
@export var counter_hit_delay := 0.2
@export var counter_duration := 0.65
@export_range(0.1, 1.0, 0.05) var slow_motion_scale := 0.4
@export_range(0.0, 1.0, 0.01) var slow_motion_duration := 0.5
var phase := Phase.IDLE
var target: Node3D
var elapsed := 0.0
var buffered_attack := false
var hit_resolved := false
var dodge_held := false
var slow_until := 0
var warning: Label3D
@onready var player: PlayerCharacter = get_parent()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if player.is_node_ready(): _setup()
	else: player.ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup() -> void:
	warning = Label3D.new()
	warning.name = "AnticipationWarning"
	warning.position = Vector3(0, 1.7, 0)
	warning.text = "!"
	warning.font_size = 80
	warning.pixel_size = 0.008
	warning.modulate = Color(1, 0.05, 0.03)
	warning.outline_size = 12
	warning.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	warning.no_depth_test = true
	warning.hide()
	player.add_child.call_deferred(warning)
	var library := AnimationLibrary.new()
	var loader := CharacterAnimationLibraryLoader.new()
	loader.add_animation(library, &"UAL1", &"Crouch_Idle", &"Duck")
	loader.add_animation(library, &"UAL2", &"Melee_Hook", &"Hook")
	loader.add_animation(library, &"UAL2", &"Melee_Hook_Rec", &"Recovery")
	player.character_animation_player.add_animation_library(&"Anticipation", library)
	player.damage_receiver.damage_received.connect(_on_damage_received)

func enabled() -> bool:
	return player.get_node("PlayerPowerController").progression.level("mind") >= 1

func active() -> bool:
	return phase != Phase.IDLE

func eligible() -> bool:
	return enabled() and player.is_on_floor() and not (
		player.is_dead or player.is_knocked_out or player.is_dodging
		or player.thunderstorm.casting
		or player.lightning_strike.casting
		or player.is_flying or player.is_ground_slamming or player.is_wall_running
		or player.is_charging_jump or player.is_charging_flight or player.is_carrying()
		or player.hostile_grab.owns_animation() or player.ship_interaction.is_attached()
		or player.combat_controller.charge_phase != PlayerCombatController.ChargePhase.NONE
		or player.get_node("PlayerPowerController").is_selector_open())

func pending_attacker() -> Node3D:
	if not eligible(): return null
	var soonest := INF
	var result: Node3D
	for enemy in get_tree().get_nodes_in_group(&"melee_hostile"):
		var remaining: float = enemy.counter_warning_remaining(player)
		if remaining > 0.0 and remaining <= warning_window + 0.001 and remaining < soonest:
			soonest = remaining
			result = enemy
	return result

func handle_event(event: InputEvent) -> bool:
	var bindings: Node = get_node("/root/GameSettings").input_bindings
	if event.is_action_released("dodge_roll"): dodge_held = false
	if get_tree().paused or bindings.is_capturing or DebugManager.developer_menu_open: return false
	if bindings.is_action_press(event, "dodge_roll"):
		if event is InputEventKey and (event.physical_keycode == KEY_CTRL or event.keycode == KEY_CTRL) and event.location == KEY_LOCATION_RIGHT:
			return active()
		var fresh := not dodge_held
		dodge_held = true
		if fresh and not active():
			var attacker := pending_attacker()
			if attacker != null and begin_evade(attacker): return true
	if active() and bindings.is_action_press(event, "attack"):
		if phase in [Phase.DUCK, Phase.READY]: buffered_attack = true
	return active()

func begin_evade(attacker: Node3D) -> bool:
	if active() or not eligible() or attacker.counter_warning_remaining(player) <= 0.0: return false
	if not player.stamina.spend_fraction(stamina_fraction): return false
	target = attacker
	phase = Phase.DUCK
	elapsed = 0.0
	buffered_attack = false
	player.combat_controller.cancel_punch()
	player.laser_eyes.cancel_input()
	player.bounding_controller.reset()
	player.animation_controller.is_hit_reacting = false
	player.animation_controller.is_playing_landing_animation = false
	player.status_effects.hit_slowdown_remaining = 0.0
	player.velocity = Vector3.ZERO
	_face_target()
	player.character_animation_player.play("Anticipation/Duck", 0.05)
	warning.hide()
	return true

func evade_hit(attacker: Node3D) -> bool:
	if phase != Phase.DUCK or attacker != target or not eligible(): return false
	phase = Phase.READY
	elapsed = 0.0
	# Refresh an existing effect without multiplying its scale a second time.
	_restore_time()
	get_node("/root/SlowMotion").start(self, slow_motion_scale)
	slow_until = Time.get_ticks_usec() + int(slow_motion_duration * 1000000.0)
	return true

func tick(delta: float) -> bool:
	if not active(): return false
	if not eligible():
		cancel()
		return false
	if not is_instance_valid(target) or target.is_dead:
		cancel(false)
		return false
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	# Counter impact/recovery follows the animation's scaled clock. The input
	# opportunity still uses real time; hit protection lasts for the whole action.
	elapsed += delta if phase == Phase.COUNTER else real_delta
	if phase == Phase.DUCK:
		if target.punch_resolved or elapsed > warning_window + 0.2:
			cancel()
			return false
	elif phase == Phase.READY:
		if buffered_attack:
			phase = Phase.COUNTER
			elapsed = 0.0
			hit_resolved = false
			_face_target()
			player.character_animation_player.play("Anticipation/Hook", 0.05)
			player.combat_controller.combo_punch_started.emit(1)
		elif elapsed >= counter_window:
			cancel(false)
			return false
	elif phase == Phase.COUNTER:
		if not hit_resolved and elapsed >= counter_hit_delay:
			hit_resolved = true
			_counter_hit()
		if elapsed >= counter_duration:
			cancel(false)
			return false
		if elapsed >= 0.47 and player.character_animation_player.current_animation != "Anticipation/Recovery":
			player.character_animation_player.play("Anticipation/Recovery", 0.05, 3.0)
	player.velocity = Vector3(0, -0.1, 0)
	player.move_and_slide()
	player.stamina.finish_tick(delta, Vector3.ZERO, player.is_on_floor())
	return true

func _counter_hit() -> void:
	if not is_instance_valid(target) or target.is_dead: return
	if player.global_position.distance_to(target.global_position) > counter_range: return
	var ray := PhysicsRayQueryParameters3D.create(player.global_position, target.global_position + Vector3.UP, 1, [player.get_rid()])
	var obstruction := player.get_world_3d().direct_space_state.intersect_ray(ray)
	if not obstruction.is_empty() and obstruction.collider != target: return
	var amount: float = player.stats.get_effective_strength() * player.combat_controller.regular_hit_damage_multiplier * counter_damage_multiplier
	var info = DAMAGE.new(amount, player.global_position, -player.global_basis.z, &"knockback", player)
	info.damage_type = &"melee"
	target.apply_damage(info)

func _face_target() -> void:
	var offset := target.global_position - player.global_position
	player.ground_facing_yaw = atan2(-offset.x, -offset.z)
	player._apply_ground_facing_visual()

func _process(_delta: float) -> void:
	if warning == null: return
	if slow_until > 0 and (Time.get_ticks_usec() >= slow_until or get_tree().paused): _restore_time()
	if get_tree().paused or player.is_dead or not enabled():
		if get_tree().paused: dodge_held = false
		cancel()
		warning.hide()
		return
	warning.visible = not active() and pending_attacker() != null

func _restore_time() -> void:
	if slow_until == 0: return
	get_node("/root/SlowMotion").stop(self)
	slow_until = 0

func cancel(restore_time := true) -> void:
	# A finished counter or defeated target must not cut the visual effect short.
	# Interruptions release this request; the helper handles the recovery fade.
	if restore_time: _restore_time()
	if active():
		player.character_animation_player.stop()
	phase = Phase.IDLE
	target = null
	buffered_attack = false
	if is_instance_valid(warning): warning.hide()

func _on_damage_received(_info) -> void:
	if active() or slow_until > 0: cancel()

func _exit_tree() -> void:
	get_node("/root/SlowMotion").stop(self, true)
	cancel()
