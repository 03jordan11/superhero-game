class_name PlayerHostileGrab
extends Node

const LIBRARY=preload("res://assets/animations/authored-combo/hero_combo.glb")
const DAMAGE=preload("res://scripts/combat-scripts/damage_info.gd")
const THROWN=preload("res://scripts/npc-scripts/hostile_thrown_motion.gd")
enum Mode { NONE, GRAB, HOLD, CHARGE, THROW, SLAM, RECOVER }
@export var grab_range:=2.5
@export_range(1,90,1) var grab_half_angle:=65.0
@export var throw_charge_time:=1.2
@export var throw_min_hold_time:=.2
@export var throw_min_speed:=20.0
@export var throw_max_speed:=75.0
@export var throw_max_damage:=80.0
@export var slam_damage: Array[float]=[20.0,20.0,60.0]
var held: HostileBase
var mode:=Mode.NONE
var pair:=""
var phase_time:=0.0
var charge:=0.0
var slam_count:=0
var queued_slam:=false
var impact_done:=false
var _model: Node3D
var _skeleton: Skeleton3D
var _victim_animation: AnimationPlayer
var _model_transform: Transform3D
var _layer:=0
var _mask:=0
var _animation_mode: int
var _label_visible:=true
var _name_visible:=true
var _hint: Label
var _hint_timer:=0.0
var _clips: Dictionary={}
@onready var player: PlayerCharacter=get_parent()

func _ready() -> void:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animations/authored-combo/grab_manifest.json"))
	for clip in manifest.clips:
		if clip.role=="Hero": _clips[clip.pair]=clip
	var canvas:=CanvasLayer.new(); add_child(canvas)
	_hint=Label.new(); canvas.add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.position=Vector2(-310,-95); _hint.size=Vector2(620,50)
	_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_outline_color",Color.BLACK); _hint.add_theme_constant_override("outline_size",4)
	_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE

func has_hostile() -> bool: return is_instance_valid(held)
func owns_animation() -> bool: return mode!=Mode.NONE
func blocks_motion() -> bool: return mode in [Mode.GRAB,Mode.SLAM,Mode.RECOVER]

func _candidate() -> HostileBase:
	var best: HostileBase
	var nearest:=grab_range*grab_range
	for node in get_tree().get_nodes_in_group(&"hostile"):
		var person:=node as HostileBase
		if person==null or not person.can_grab or person.is_dead or person.is_grabbed or person.is_thrown: continue
		var offset:=person.global_position+Vector3.UP-player.global_position
		if offset.length_squared()>grab_range*grab_range: continue
		var forward:=player.superhero_character.global_basis.z.normalized()
		if forward.dot(offset.normalized())<cos(deg_to_rad(grab_half_angle)): continue
		var ray:=PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP*.4,person.global_position+Vector3.UP,1,[player.get_rid(),person.get_rid()])
		if not player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		if player.target_lock.has_target() and player.target_lock.target==person: return person
		if offset.length_squared()<nearest: best=person; nearest=offset.length_squared()
	return best

func try_grab() -> bool:
	if player.is_carrying() or owns_animation() or player.is_dead or player.is_knocked_out or player.is_ground_slamming or player.is_wall_running or player.is_charging_jump or player.is_charging_flight or player.combat_controller.is_action_locked(): return false
	var person:=_candidate()
	if person==null: return false
	person.frost.cancel()
	person.electrified.cancel()
	held=person
	_model=held.get_node("Superhero_Male_FullBody")
	_skeleton=_model.find_child("GeneralSkeleton",true,false)
	_victim_animation=held.animation_controller.animation_player
	_model_transform=_model.transform; _layer=held.collision_layer; _mask=held.collision_mask
	_animation_mode=_victim_animation.callback_mode_process
	_label_visible=held.health_label.visible; _name_visible=held.nameplate.visible
	held.health_label.hide(); held.nameplate.hide()
	held.is_grabbed=true; held._reset_combat_actions(); held.velocity=Vector3.ZERO
	held.set_physics_process(false); held.collision_layer=0; held.collision_mask=0
	held.died.connect(_on_held_died)
	if not _victim_animation.has_animation_library("GrabCombat"): _victim_animation.add_animation_library("GrabCombat",LIBRARY)
	_victim_animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_model.transform=Transform3D.IDENTITY
	player.combat_controller.cancel_punch(); player.laser_eyes.cancel_input()
	player.animation_controller.is_hit_reacting=false; player.animation_controller.is_playing_landing_animation=false
	if player.target_lock.has_target() and player.target_lock.target==held:
		player.target_lock.release(); player.target_lock.cycle_target()
	slam_count=0; queued_slam=false; mode=Mode.GRAB; _set_pair("Grab")
	pose_after_move()
	return true

func request_slam() -> void:
	if not has_hostile() or player.is_flying or not player.is_on_floor(): return
	if mode==Mode.HOLD: _start_slam()
	elif mode in [Mode.GRAB,Mode.SLAM] and slam_count<3: queued_slam=true

func _start_slam() -> void:
	if not player.is_on_floor() or player.is_flying: queued_slam=false; return
	slam_count+=1; queued_slam=false; impact_done=false; mode=Mode.SLAM
	_set_pair("Slam%d"%slam_count)

func update(delta: float, input: PlayerInputSnapshot) -> void:
	if player.is_dead or player.is_knocked_out:
		drop(); return
	if owns_animation() and not has_hostile() and mode!=Mode.RECOVER: _end()
	if not owns_animation(): return
	phase_time+=delta
	if mode==Mode.RECOVER:
		if phase_time>=_clips[pair].duration: _end()
		return
	if held.is_dead: drop(); return
	match mode:
		Mode.GRAB:
			if phase_time>=_clips[pair].duration:
				mode=Mode.HOLD
				if queued_slam: _start_slam()
		Mode.HOLD:
			if input.vehicle_interact_just_pressed:
				mode=Mode.CHARGE; charge=0; _set_pair("ThrowCharge")
		Mode.CHARGE:
			if input.vehicle_interact_pressed: charge=minf(charge+delta,throw_charge_time)
			if input.vehicle_interact_just_released:
				if charge<throw_min_hold_time: drop(); return
				mode=Mode.THROW; impact_done=false; _set_pair("ThrowRelease")
			elif not input.vehicle_interact_pressed:
				# Focus/menu reset is cancellation, never a throw.
				mode=Mode.HOLD; charge=0
			elif pair=="ThrowCharge" and phase_time>=_clips[pair].duration: _set_pair("ThrowHold")
		Mode.THROW:
			if phase_time>=float(_clips[pair].events.release) and not impact_done:
				impact_done=true; pose_after_move(); _throw(); mode=Mode.RECOVER
		Mode.SLAM:
			if not player.is_on_floor() or player.is_flying:
				mode=Mode.HOLD; queued_slam=false
				if not impact_done: slam_count-=1
				return
			if not impact_done and phase_time>=float(_clips[pair].events.impact):
				impact_done=true; pose_after_move()
				var info=DAMAGE.new(slam_damage[mini(slam_count-1,slam_damage.size()-1)],held.global_position,Vector3.DOWN,&"chest",player)
				info.damage_type=&"grab_slam"; held.apply_damage(info)
				if not has_hostile(): return
				if slam_count==3: _detach(true); mode=Mode.RECOVER; return
			if phase_time>=_clips[pair].duration:
				mode=Mode.HOLD
				if queued_slam: _start_slam()
	if has_hostile() and mode==Mode.HOLD:
		var next:="Hold"
		if player.is_flying:
			next="CarryFlightFast" if player.flying_state.is_boosting or player.flying_state.surge_remaining>0 else "CarryFlightMove" if player.velocity.length()>player.flight_hover_speed_threshold else "CarryFlightHover"
		elif Vector2(player.velocity.x,player.velocity.z).length()>.2:
			next="CarryRun" if input.sprint_pressed else "CarryWalk"
		if next!=pair: _set_pair(next)

func _set_pair(next: String) -> void:
	pair=next; phase_time=0
	# Pairs are sampled explicitly; a timed crossfade would never advance while paused.
	player.character_animation_player.play("AuthoredCombo/Hero_"+pair,0)
	if has_hostile(): _victim_animation.play("GrabCombat/Victim_"+pair,0)

func pose_after_move() -> void:
	if not owns_animation(): return
	var data: Dictionary=_clips[pair]
	var time:=fposmod(phase_time,float(data.duration)) if data.loop else minf(phase_time,float(data.duration))
	var hero_clip:="AuthoredCombo/Hero_"+pair
	if player.character_animation_player.assigned_animation!=hero_clip: player.character_animation_player.play(hero_clip,0)
	player.character_animation_player.seek(time,true); player.character_animation_player.pause()
	if has_hostile():
		held.global_transform=player.superhero_character.global_transform
		var victim_clip:="GrabCombat/Victim_"+pair
		if _victim_animation.assigned_animation!=victim_clip: _victim_animation.play(victim_clip,0)
		_victim_animation.seek(time,true); _victim_animation.pause()

func _throw() -> void:
	var person:=held
	var ratio:=clampf(charge/maxf(throw_charge_time,.001),0,1)
	var direction: Vector3=-player.camera.global_basis.z
	_detach(false)
	var speed:=lerpf(throw_min_speed,throw_max_speed,ratio)
	if player.target_lock.has_target():
		var target: HostileBase=player.target_lock.target
		# Aim slightly above the target's feet so capsule travel clears the floor.
		var offset:=target.global_position+Vector3.UP*.5-person.global_position
		var travel:=offset.length()/maxf(speed,.001)
		# Commit a leading, gravity-compensated aim at release; never home in flight.
		direction=(offset+target.velocity*travel-person.get_gravity()*.5*travel*travel).normalized()
	var projectile=THROWN.new(); person.add_child(projectile)
	projectile.start(person,player,direction*speed,throw_max_damage*ratio)
	charge=0

func _safe_release_position(desired: Vector3) -> Vector3:
	var shape: CollisionShape3D=held.get_node("CollisionShape3D")
	var space:=player.get_world_3d().direct_space_state
	var exclusions: Array[RID]=[held.get_rid(),player.get_rid()]
	# Try the posed position first, then nearby positions around the player's body.
	var options: Array[Vector3]=[desired,player.global_position-Vector3.UP]
	for side in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
		options.append(player.global_position-Vector3.UP+player.global_basis*side*1.5)
	for candidate in options:
		var ray:=PhysicsRayQueryParameters3D.create(candidate+Vector3.UP*1.1,candidate-Vector3.UP*1.1,1,exclusions)
		var floor_hit:=space.intersect_ray(ray)
		if not floor_hit.is_empty() and floor_hit.normal.y>.7: candidate.y=maxf(candidate.y,floor_hit.position.y+.03)
		var query:=PhysicsShapeQueryParameters3D.new(); query.shape=shape.shape; query.collision_mask=_mask
		query.transform=Transform3D(Basis.IDENTITY,candidate)*shape.transform; query.exclude=exclusions
		if space.intersect_shape(query,1).is_empty(): return candidate
	return player.global_position # Player's own cleared volume, never a long release teleport.

func _detach(knockdown: bool) -> void:
	if not has_hostile(): return
	_skeleton.force_update_all_bone_transforms()
	var hips:=_skeleton.to_global(_skeleton.get_bone_global_pose(_skeleton.find_bone("Hips")).origin)
	var release_position:=_safe_release_position(hips-Vector3.UP*.95)
	var person:=held; held=null
	if person.died.is_connected(_on_held_died): person.died.disconnect(_on_held_died)
	person.is_grabbed=false; _model.transform=_model_transform
	person.global_transform=Transform3D(Basis(Vector3.UP,player.global_rotation.y),release_position)
	_victim_animation.callback_mode_process=_animation_mode
	person.health_label.visible=_label_visible and not person.is_dead
	person.nameplate.visible=_name_visible and not person.is_dead
	person.collision_layer=0 if person.is_dead else _layer; person.collision_mask=0 if person.is_dead else _mask
	person.velocity=player.velocity
	if not person.is_dead:
		person.set_physics_process(true)
		if knockdown:
			person.is_hit_reacting=true; person.is_waiting_for_knockback_stun=true
			person.knockback_stun_remaining=person.chest_hit_stun_duration*2
			person.animation_controller.play_knockback()
		else: person.animation_controller.set_is_idle()
	else: person.animation_controller.play_death()
	# Avoid one frame of overlapping capsules when an interruption drops nearby.
	person.add_collision_exception_with(player)
	var person_ref: WeakRef=weakref(person)
	var player_ref: WeakRef=weakref(player)
	get_tree().create_timer(.3).timeout.connect(func():
		var released=person_ref.get_ref()
		var thrower=player_ref.get_ref()
		if released!=null and thrower!=null and not released.is_thrown: released.remove_collision_exception_with(thrower))

func drop() -> void:
	if has_hostile(): _detach(true)
	_end()

func _on_held_died(_person: NPCBase) -> void:
	_detach(false)
	if mode==Mode.SLAM: mode=Mode.RECOVER
	else: _end()

func _end() -> void:
	mode=Mode.NONE; queued_slam=false; charge=0; pair=""; phase_time=0

func _process(delta: float) -> void:
	_hint_timer-=delta
	if _hint_timer>0: return
	_hint_timer=.1
	var bindings: Node=get_node("/root/GameSettings").input_bindings
	if get_node("/root/DebugManager").developer_menu_open or player.get_node("PlayerPowerController").is_selector_open(): _hint.hide(); return
	var key: String=bindings.label_for("pick_up_vehicle",bindings.active_device)
	if has_hostile():
		_hint.text="%s: drop · Hold %s: throw · Attack: slam %d/3 (ground only)"%[key,key,slam_count]
		if mode in [Mode.CHARGE,Mode.THROW]: _hint.text="Throw charge: %d%% · Impact damage: %d / %d"%[roundi(100*charge/maxf(throw_charge_time,.001)),roundi(throw_max_damage*charge/maxf(throw_charge_time,.001)),roundi(throw_max_damage*.5*charge/maxf(throw_charge_time,.001))]
		_hint.show()
	elif not player.is_carrying() and not player.is_dead and not player.is_knocked_out and _candidate()!=null:
		_hint.text="%s: grab hostile"%key; _hint.show()
	else: _hint.hide()
