extends Node3D
## Empty training floor; all opponents use their existing combat implementations.
const THUGS := {
	&"melee_thug": preload("res://scenes/npcs/melee_thug.tscn"),
	&"pistol_thug": preload("res://scenes/npcs/pistol_thug.tscn"),
	&"rifle_thug": preload("res://scenes/npcs/rifle_thug.tscn"),
	&"super_thug": preload("res://scenes/npcs/super_thug.tscn"),
}
const HELICOPTER = preload("res://scripts/encounter-scripts/helicopter-chase/attack_helicopter.gd")
@export_range(1, 40, 1) var maximum_opponents := 16
@export_range(3.0, 20.0, 0.5) var spawn_spacing := 5.0
@export_range(12.0, 60.0, 1.0) var helicopter_spawn_height := 18.0
@export var recovery_distance := 230.0
var spawn_serial := 0
var status_seconds := 0.0
var permanent_nodes: Array[Node] = []
@onready var player: PlayerCharacter = $Player
@onready var opponents: Node3D = $Opponents
@onready var status: Label = $ArenaHUD/Status

func _enter_tree() -> void:
	add_to_group(&"combat_arena")

func _ready() -> void:
	permanent_nodes = get_children()
	for station in $Stations.get_children(): station.activated.connect(activate_station)
	player.camera.make_current()
	player.spring_arm.rotation.x = -0.12
	_message("SIMULATION READY  /  Approach a station and press E")

func activate_station(enemy_id: StringName) -> void:
	if get_tree().paused or player.is_dead: return
	if enemy_id == &"reset":
		reset_arena()
		return
	spawn_enemy(enemy_id)

func spawn_enemy(enemy_id: StringName) -> Node3D:
	if not THUGS.has(enemy_id) and enemy_id != &"helicopter": return null
	if opponent_count() >= maximum_opponents:
		_message("OPPONENT LIMIT  /  Use RESET ARENA to clear the simulation")
		return null
	var helicopter := enemy_id == &"helicopter"
	var location := _find_spawn_position(helicopter)
	if location == Vector3.INF:
		_message("SPAWN AREA OCCUPIED  /  Clear space or reset the arena")
		return null
	var enemy: Node3D
	if helicopter:
		enemy = HELICOPTER.new()
		enemy.target = player
	else:
		enemy = THUGS[enemy_id].instantiate()
		enemy.experience_gain = 0
	# Position before ready so helicopter flight initializes in the correct place.
	enemy.position = opponents.to_local(location)
	opponents.add_child(enemy)
	if not helicopter: enemy.receive_alert(player)
	spawn_serial += 1
	_message("SPAWNED  /  " + ("ATTACK HELICOPTER" if helicopter else str(enemy_id).replace("_", " ").to_upper()))
	return enemy

func _find_spawn_position(helicopter: bool) -> Vector3:
	for attempt in 32:
		var slot := (spawn_serial + attempt) % 32
		var point: Vector3 = $EnemySpawn.global_position + Vector3((slot % 8 - 3.5) * spawn_spacing, helicopter_spawn_height if helicopter else 0.0, -floorf(slot / 8.0) * spawn_spacing)
		if player.global_position.distance_to(point) < (14.0 if helicopter else 4.0): continue
		var clear := true
		for enemy in opponents.get_children():
			if enemy is Node3D and enemy.global_position.distance_to(point) < (18.0 if helicopter else 3.0):
				clear = false
				break
		if clear: return point
	return Vector3.INF

func reset_arena() -> void:
	player.revive_for_respawn()
	for enemy in opponents.get_children(): enemy.free()
	# Powers place projectiles and impact effects under the current scene.
	for effect in get_children():
		if effect not in permanent_nodes: effect.free()
	player.global_transform = $PlayerSpawn.global_transform
	player.ground_facing_yaw = player.global_rotation.y
	player.spring_arm.rotation = Vector3(-0.12, 0, 0)
	player.reset_physics_interpolation()
	spawn_serial = 0
	_message("SIMULATION RESET  /  Health and stamina restored")

func _process(delta: float) -> void:
	status_seconds -= delta
	if status_seconds <= 0.0:
		status.text = "%02d / %02d OPPONENTS  •  ESC: RETURN FROM COMBAT ARENA" % [opponent_count(), maximum_opponents]
	if not player.is_dead and (player.global_position.y < -20.0 or Vector2(player.global_position.x, player.global_position.z).length() > recovery_distance):
		reset_arena()

func _message(text: String) -> void:
	status.text = text
	status_seconds = 4.0

func opponent_count() -> int:
	var count := 0
	for enemy in opponents.get_children():
		if enemy is HostileBase or enemy is HELICOPTER: count += 1
	return count
