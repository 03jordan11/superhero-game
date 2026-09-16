extends BaseEncounter
const ENEMY=preload("res://scripts/encounter-scripts/helicopter-chase/attack_helicopter.gd")
@export_category("Helicopter Chase")
@export var helicopter_health:=100.0
@export_range(10,100,1,"suffix:m") var engagement_distance:=25.0
@export_range(5,50,1,"suffix:m") var height_offset:=10.0
@export var spawn_distance:=55.0
@export var wreck_lifetime:=30.0
@export_range(8,40,1,"suffix:m") var ground_clearance:=12.0
var helicopter: CharacterBody3D
var _spawn_position:=Vector3.ZERO
func _init() -> void:
	encounter_id=&"helicopter_chase"
	display_name="Helicopter Chase"
	xp_reward=1000
	cleanup_delay=31.0
func _prepare_encounter() -> bool:
	var space:=get_world_3d().direct_space_state
	var sphere:=SphereShape3D.new(); sphere.radius=8
	for height in [25.0,50.0,100.0,200.0,350.0]:
		for i in range(12):
			var angle:=float(i)*TAU/12.0
			var candidate:=reward_player.global_position+Vector3(sin(angle)*spawn_distance,height,cos(angle)*spawn_distance)
			var query:=PhysicsShapeQueryParameters3D.new(); query.shape=sphere
			query.transform.origin=candidate+Vector3.UP*2; query.collision_mask=1
			if space.intersect_shape(query,1).is_empty():
				_spawn_position=candidate
				return true
	spawn_error="No clear airspace for the helicopter. Move to an open area and try again."
	return false
func _activate_encounter() -> void:
	helicopter=ENEMY.new()
	helicopter.max_health=helicopter_health
	helicopter.engagement_distance=engagement_distance
	helicopter.height_offset=height_offset
	helicopter.wreck_lifetime=wreck_lifetime
	helicopter.ground_clearance=ground_clearance
	helicopter.target=reward_player
	helicopter.position=to_local(_spawn_position)
	add_child(helicopter)
	helicopter.defeated.connect(_on_defeated)
	helicopter.tree_exiting.connect(_on_removed)
func _physics_process(_delta: float) -> void:
	if state!=EncounterState.ACTIVE: return
	if not is_instance_valid(reward_player) or reward_player.is_dead:
		if is_instance_valid(helicopter): helicopter.queue_free()
		fail_encounter()
	elif is_instance_valid(helicopter):
		helicopter.engagement_distance=engagement_distance
		helicopter.height_offset=height_offset
		helicopter.ground_clearance=ground_clearance
func _on_defeated() -> void:
	cleanup_delay=maxf(wreck_lifetime+1.0,2.0)
	complete_encounter()
func _on_removed() -> void:
	if state==EncounterState.ACTIVE: fail_encounter()
func get_waypoint_position() -> Vector3:
	return helicopter.global_position if is_instance_valid(helicopter) else _spawn_position
