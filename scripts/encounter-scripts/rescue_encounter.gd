class_name RescueEncounter
extends BaseEncounter

const PATIENT_SCENE = preload("res://scenes/npcs/rescue_patient.tscn")
@export var timer_duration := 120.0
@export var hard_landing_penalty := 5.0
@export var random_location_min_radius := 60.0
@export var random_location_radius := 200.0
@export var ground_search_attempts := 40
var remaining_time := 120.0
var penalty_flash := 0.0
var patient: RescuePatient
var hospital: HospitalRescueZone
var random_number_generator := RandomNumberGenerator.new()

func _init() -> void:
	encounter_id = &"rescue"
	display_name = "Injured Civilian"
	xp_reward = 100
	money_reward = 100
	good_will_reward = 10
	cleanup_delay = 2.0
	random_number_generator.randomize()

func _prepare_encounter() -> bool:
	var distance := INF
	for node in get_tree().get_nodes_in_group(&"hospital_rescue_zone"):
		var zone := node as HospitalRescueZone
		if zone == null: continue
		var candidate := global_position.distance_squared_to(zone.global_position)
		if candidate < distance:
			hospital = zone
			distance = candidate
	if hospital == null:
		spawn_error = "No hospital rescue drop-off exists in this scene."
		return false
	var space := get_world_3d().direct_space_state
	for attempt in ground_search_attempts:
		var angle := random_number_generator.randf_range(0, TAU)
		var radius := random_number_generator.randf_range(random_location_min_radius, random_location_radius)
		var spot := global_position + Vector3(cos(angle), 0, sin(angle)) * radius
		var ray := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 150, spot + Vector3.DOWN * 350, 1)
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or not hit.collider is StaticBody3D or hit.normal.y < 0.9 or hit.position.y < -0.15: continue
		var shape := SphereShape3D.new()
		shape.radius = 1.0
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform.origin = hit.position + Vector3.UP * 1.05
		query.collision_mask = 1
		if not space.intersect_shape(query, 1).is_empty(): continue
		global_position = hit.position + Vector3.UP * 0.05
		return true
	spawn_error = "Could not find clear ground for the injured civilian. Try an open area."
	return false

func _activate_encounter() -> void:
	remaining_time = timer_duration
	patient = PATIENT_SCENE.instantiate() as RescuePatient
	patient.encounter = self
	add_child(patient)
	reward_player.landing_impact_controller.hard_landing_effect_spawned.connect(_on_hard_landing)

func _physics_process(delta: float) -> void:
	if state != EncounterState.ACTIVE: return
	remaining_time = maxf(remaining_time - delta, 0.0)
	penalty_flash = maxf(penalty_flash - delta, 0.0)
	# Preview timer: reaching zero neither fails the rescue nor changes rewards.
	if not is_instance_valid(patient) or not is_instance_valid(hospital):
		fail_encounter()
		return
	if hospital.contains_patient(patient): complete_encounter()

func _on_hard_landing() -> void:
	if state != EncounterState.ACTIVE or not is_instance_valid(patient) or patient.carrier != reward_player: return
	remaining_time = maxf(remaining_time - hard_landing_penalty, 0.0)
	penalty_flash = 1.0

func get_waypoint_position() -> Vector3:
	if not is_instance_valid(patient): return global_position
	if is_instance_valid(patient.carrier) and is_instance_valid(hospital): return hospital.global_position
	return patient.global_position

func get_waypoint_label() -> String:
	return "Hospital — set down civilian" if is_instance_valid(patient) and is_instance_valid(patient.carrier) else display_name

func get_waypoint_priority() -> int:
	return 1 if is_instance_valid(patient) and is_instance_valid(patient.carrier) else 0

func _exit_tree() -> void:
	# The patient may be parented to the hero when this encounter is removed.
	if is_instance_valid(patient) and patient.get_parent() != self: patient.queue_free()
