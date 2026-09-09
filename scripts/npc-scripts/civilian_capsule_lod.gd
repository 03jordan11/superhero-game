extends Node

const CROWD_PERF = preload("res://scripts/ui-scripts/civilian_crowd_performance_monitor.gd")
## Settings and representation handoff only. The parent owns one population.
const CAPSULE := preload("res://scripts/npc-scripts/capsule_civilian.gd")
const JOURNEY := preload("res://scripts/npc-scripts/pedestrian_journey.gd")

@export var enabled := true
@export_category("Distant Coverage")
@export_range(0,1000,1) var max_capsules := 120
@export_range(50.0,1000.0,10.0) var view_distance := 350.0
@export_range(30.0,360.0,5.0) var view_angle := 140.0
@export_range(10.0,300.0,5.0) var surrounding_radius := 100.0
@export_range(0.0,1.0,0.05) var high_altitude_population_fraction := 0.35
@export_category("Full Civilian Transition")
@export_range(10.0,400.0,5.0) var promote_distance := 90.0
@export_range(20.0,500.0,5.0) var demote_distance := 120.0
@export_range(5.0,100.0,1.0) var interaction_distance := 25.0
@export_range(0.0,3.0,0.1) var approach_lead_seconds := 1.0
@export_range(0.0,5.0,0.1) var demote_delay := 1.0
@export_range(0.05,1.0,0.05) var check_interval := 0.1
@export_range(1,16,1) var transitions_per_check := 4
@export_category("Capsule Appearance")
@export_range(0.1,0.6,0.05) var capsule_radius := 0.3
@export_range(1.0,2.5,0.05) var capsule_height := 1.75
@export var debug_tier_colors := false

var full_count := 0
var capsule_count := 0
var promotions := 0
var demotions := 0
var blocked_promotions := 0
var _crowd: Node3D
var _mesh := CapsuleMesh.new()
var _materials: Dictionary = {}
var _far_time: Dictionary = {}
var _timer := 0.0

func _ready() -> void:
	_crowd = get_parent()
	_mesh.radial_segments = 8
	_mesh.rings = 2
	add_to_group(&"civilian_capsule_lod")

func wants_full(point: Vector3) -> bool:
	if not enabled: return true
	var lead := 0.0
	if _crowd._player is CharacterBody3D:
		lead = _crowd._player.velocity.length()*approach_lead_seconds
	var distance := maxf(promote_distance,interaction_distance)+minf(lead,100.0)
	return point.distance_to(_crowd._player.global_position) <= distance

func in_distant_area(point: Vector3, retaining: bool) -> bool:
	if not enabled: return false
	var offset: Vector3 = point-_crowd._player.global_position
	offset.y = 0.0
	var margin: float = _crowd.despawn_margin if retaining else 0.0
	if offset.length() > maxf(view_distance,_crowd.current_radius)+margin: return false
	if offset.length() <= surrounding_radius+minf(margin,10.0): return true
	var angle := minf(360.0,view_angle+(_crowd.retention_angle_margin if retaining else 0.0))
	return offset.normalized().dot(_crowd._spawn_forward) >= cos(deg_to_rad(angle*0.5))

func create_capsule(tone: int) -> Node3D:
	var walker := CAPSULE.new()
	walker.skin_tone_index = tone
	_mesh.radius = capsule_radius
	_mesh.height = maxf(capsule_height,capsule_radius*2.0)
	if not _materials.has(tone):
		var material := StandardMaterial3D.new()
		material.albedo_color = _crowd.SKIN_TONES[tone] if tone >= 0 else Color("c89569")
		material.roughness = 1.0
		_materials[tone] = material
	walker.set_visual(_mesh,_materials[tone])
	return walker

func refresh_counts() -> void:
	full_count = 0
	capsule_count = 0
	for walker in _crowd._active.get_children():
		if walker.is_lightweight: capsule_count += 1
		else: full_count += 1

func update(delta: float) -> void:
	var perf_started := CROWD_PERF.begin(self)
	_profiled_update(delta)
	CROWD_PERF.finish(&"lod_update", perf_started)


func _profiled_update(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0: return
	_timer = maxf(check_interval,0.05)
	refresh_counts()
	if not is_instance_valid(_crowd._player): return
	_mesh.radius = capsule_radius
	_mesh.height = maxf(capsule_height,capsule_radius*2.0)
	for tone in _materials:
		_materials[tone].albedo_color = Color.MAGENTA if debug_tier_colors else (_crowd.SKIN_TONES[tone] if tone >= 0 else Color("c89569"))
	var work := 0
	var walkers: Array = _crowd._active.get_children()
	# Nearest candidates get the limited transition budget first.
	walkers.sort_custom(func(a,b): return a.global_position.distance_squared_to(_crowd._player.global_position) < b.global_position.distance_squared_to(_crowd._player.global_position))
	var excess := maxi(0,capsule_count-maxi(max_capsules,0))
	for i in range(walkers.size()-1,-1,-1):
		if excess == 0: break
		var walker = walkers[i]
		if walker.is_lightweight and walker.pending_damage.is_empty() and walker.global_position.distance_to(_crowd._player.global_position) > interaction_distance:
			_crowd._retiring[walker] = true
			excess -= 1
	for walker in walkers:
		var pending_hit: bool = walker.is_lightweight and not walker.pending_damage.is_empty()
		if not pending_hit and (_crowd._retiring.has(walker) or not walker.route_enabled): continue
		if walker.is_lightweight:
			walker.get_node("CapsuleVisual").position.y = _mesh.height*0.5
			if not wants_full(walker.global_position) and walker.pending_damage.is_empty():
				walker.promotion_blocked = false
				continue
			var urgent: bool = not walker.pending_damage.is_empty() or walker.global_position.distance_to(_crowd._player.global_position) <= interaction_distance
			if not urgent and full_count >= _crowd.population_target:
				if not enabled: _crowd._retiring[walker] = true
				continue
			promote(walker)
			work += 1
		else:
			if not enabled or not _can_demote(walker) or capsule_count >= max_capsules: continue
			var far: bool = walker.global_position.distance_to(_crowd._player.global_position) > maxf(demote_distance,promote_distance+10.0) and not wants_full(walker.global_position)
			if not far:
				_far_time.erase(walker)
				continue
			_far_time[walker] = float(_far_time.get(walker,0.0))+maxf(check_interval,0.05)
			if _far_time[walker] < demote_delay: continue
			demote(walker)
			work += 1
		if work >= maxi(transitions_per_check,1): break

func _can_demote(walker: Node3D) -> bool:
	return not walker.is_dead and not walker.is_hit_reacting and walker.current_state == walker.State.WALK_TO_DESTINATION and walker.get_current_health() >= walker.get_max_health() and walker.is_on_floor()

func promote(walker: Node3D) -> Node3D:
	var perf_started := CROWD_PERF.begin(self)
	var result: Node3D = _profiled_promote(walker)
	CROWD_PERF.finish(&"promote", perf_started, result == null)
	return result


func _profiled_promote(walker: Node3D) -> Node3D:
	# Keep the visual at its exact position if a full body cannot fit yet.
	if not _crowd._promotion_clear(walker):
		walker.promotion_blocked = true
		blocked_promotions += 1
		return null
	var state := JOURNEY.capture(walker)
	var full = _crowd.CIVILIAN.instantiate()
	full.route_graph_path = _crowd._graph.get_path()
	full.ambient_roaming = true
	full.start_point_id = state._current_id
	full._path = state._path
	full.show_route_status = _crowd.show_civilian_status
	full.skin_tone_index = state.skin_tone_index
	if full.skin_tone_index >= 0: _crowd._apply_skin(full,full.skin_tone_index)
	full.position = _crowd._active.to_local(walker.global_position)
	_crowd._active.add_child(full)
	JOURNEY.restore(full,state)
	full.animation_controller.set_is_walking(full._pause_remaining <= 0.0)
	var damage: Array = walker.pending_damage.duplicate()
	_replace_bookkeeping(walker,full)
	for info in damage:
		if not is_instance_valid(info.source): info.source = null
		full.apply_damage(info)
	full_count += 1
	capsule_count -= 1
	promotions += 1
	return full

func demote(walker: Node3D) -> Node3D:
	var perf_started := CROWD_PERF.begin(self)
	var result: Node3D = _profiled_demote(walker)
	CROWD_PERF.finish(&"demote", perf_started, result == null)
	return result


func _profiled_demote(walker: Node3D) -> Node3D:
	var state := JOURNEY.capture(walker)
	var capsule := create_capsule(walker.skin_tone_index)
	capsule.graph = _crowd._graph
	capsule.position = _crowd._active.to_local(walker.global_position)
	_crowd._active.add_child(capsule)
	JOURNEY.restore(capsule,state)
	_replace_bookkeeping(walker,capsule)
	full_count -= 1
	capsule_count += 1
	demotions += 1
	return capsule

func _replace_bookkeeping(old: Node3D, replacement: Node3D) -> void:
	for records: Dictionary in [_crowd._counted_cells,_crowd._outside_time,_crowd._retiring]:
		if records.has(old):
			records[replacement] = records[old]
			records.erase(old)
	_far_time.erase(old)
	old.free()

func forget(walker: Node3D) -> void:
	_far_time.erase(walker)
	if walker.is_lightweight: capsule_count = maxi(0,capsule_count-1)
	else: full_count = maxi(0,full_count-1)

func apply_radius_damage(origin: Vector3, radius: float, info) -> void:
	# Called after the normal body query, so newly promoted bodies cannot be hit twice.
	for walker in _crowd._active.get_children():
		if not walker.is_lightweight: continue
		var closest := Geometry3D.get_closest_point_to_segment(origin,walker.global_position+Vector3.UP*0.5,walker.global_position+Vector3.UP*1.25)
		if closest.distance_to(origin) <= radius+0.5:
			walker.apply_damage(info)
			_timer = 0.0 # Handoff in the next physics update, outside query callbacks.

func apply_melee_damage(origin: Vector3, radius: float, info) -> bool:
	for walker in _crowd._active.get_children():
		if not walker.is_lightweight: continue
		var closest := Geometry3D.get_closest_point_to_segment(origin,walker.global_position+Vector3.UP*0.5,walker.global_position+Vector3.UP*1.25)
		if closest.distance_to(origin) <= radius+0.5:
			walker.apply_damage(info)
			_timer = 0.0
			return true
	return false
