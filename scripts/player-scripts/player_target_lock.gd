extends Node
## Tap on release to acquire/cycle; a hold never cycles before unlocking.
@export var acquisition_distance:=60.0
@export var break_distance:=80.0
@export var release_hold_seconds:=0.5
@export var obstruction_grace_seconds:=0.5
@export var visibility_check_interval:=0.1
@export var camera_follow_speed:=10.0
@export var target_height:=1.2
var target: HostileBase
var _target_died:=false
var _cycle: Array[HostileBase]=[]
var _press_pending:=false
var _held_seconds:=0.0
var _hold_consumed:=false
var _visibility_timer:=0.0
var _blocked_seconds:=0.0
var _visible:=true
var _marker: Label
var _hint: Label
@onready var player: PlayerCharacter=get_parent()

func _ready() -> void:
	var canvas:=CanvasLayer.new(); canvas.layer=5; add_child(canvas)
	_marker=Label.new(); _marker.text="◇"; _marker.add_theme_font_size_override("font_size",40)
	_marker.add_theme_color_override("font_color",Color(1,.8,.2))
	_marker.add_theme_color_override("font_outline_color",Color.BLACK)
	_marker.add_theme_constant_override("outline_size",5)
	_marker.mouse_filter=Control.MOUSE_FILTER_IGNORE; canvas.add_child(_marker); _marker.hide()
	_hint=Label.new(); canvas.add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top=-155; _hint.offset_bottom=-120
	_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_outline_color",Color.BLACK)
	_hint.add_theme_constant_override("outline_size",5)
	_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE; _hint.hide()

func has_target() -> bool:
	return is_instance_valid(target) and not target.is_dead

func cancel_press() -> void:
	_press_pending=false; _held_seconds=0; _hold_consumed=false

func release() -> void:
	_disconnect_target_death()
	_target_died=false
	target=null; _cycle.clear(); _blocked_seconds=0; _visibility_timer=0
	if is_instance_valid(_marker): _marker.hide(); _hint.hide()

func release_for_aim() -> void:
	release()
	cancel_press()

func update_lock(delta: float, input: PlayerInputSnapshot) -> void:
	if player.is_dead or player.is_knocked_out or player.is_ground_slamming or player.is_wall_running or player.ship_interaction.is_attached():
		release(); cancel_press(); return
	if DebugManager.developer_menu_open or player.get_node("PlayerPowerController").is_selector_open() or get_node("/root/GameSettings").input_bindings.is_capturing:
		cancel_press(); return
	# Aiming wins over pending taps and death retargeting. Releasing aim leaves
	# target empty, so only a fresh Tab press can enable lock-on again.
	if input.aim_power_pressed or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		release_for_aim(); return
	if input.lock_target_just_pressed and not _press_pending:
		_press_pending=true; _held_seconds=0; _hold_consumed=false
	if _press_pending:
		if input.lock_target_pressed:
			_held_seconds+=delta
			if _held_seconds>=release_hold_seconds and not _hold_consumed:
				release(); _hold_consumed=true
		elif input.lock_target_just_released:
			if not _hold_consumed: cycle_target()
			cancel_press()
		else: cancel_press() # Focus/menu interruption is not a tap.
	if _target_died or (is_instance_valid(target) and target.is_dead):
		release()
		cycle_target() # Nearest eligible visible enemy inside acquisition range.
	if not is_instance_valid(target) or not _eligible(target):
		release(); return
	if player.global_position.distance_to(target.global_position)>maxf(acquisition_distance,break_distance):
		release(); return
	_visibility_timer-=delta
	if _visibility_timer<=0:
		_visible=_line_of_sight(target); _visibility_timer=visibility_check_interval
	_blocked_seconds=0.0 if _visible else _blocked_seconds+delta
	if not _visible and _blocked_seconds>=obstruction_grace_seconds:
		release(); return
	_follow_camera(delta)

func _eligible(person: HostileBase) -> bool:
	return is_instance_valid(person) and person.is_inside_tree() and person.is_visible_in_tree() and not person.is_dead and not person.is_grabbed and not person.is_thrown and person.aggressive_to_player

func _aim_point(person: HostileBase) -> Vector3:
	return person.global_position+Vector3.UP*target_height

func _line_of_sight(person: HostileBase) -> bool:
	var space:=player.get_world_3d().direct_space_state
	for height in [target_height,target_height+.5]:
		var point: Vector3=person.global_position+Vector3.UP*height
		var ray:=PhysicsRayQueryParameters3D.create(player.camera.global_position,point,1,[player.get_rid()])
		var hit:=space.intersect_ray(ray)
		if hit.is_empty() or hit.collider==person or person.is_ancestor_of(hit.collider): return true
	return false

func _candidates() -> Array[HostileBase]:
	var candidates: Array[HostileBase]=[]
	for node in get_tree().get_nodes_in_group(&"hostile"):
		var person:=node as HostileBase
		if not _eligible(person): continue
		if player.global_position.distance_to(person.global_position)>acquisition_distance: continue
		if not player.camera.is_position_in_frustum(_aim_point(person)) and not player.camera.is_position_in_frustum(_aim_point(person)+Vector3.UP*.5): continue
		if _line_of_sight(person): candidates.append(person)
	candidates.sort_custom(func(a: HostileBase,b: HostileBase):
		var da:=player.global_position.distance_squared_to(a.global_position)
		var db:=player.global_position.distance_squared_to(b.global_position)
		return a.get_instance_id()<b.get_instance_id() if is_equal_approx(da,db) else da<db)
	return candidates

func cycle_target() -> void:
	var candidates:=_candidates()
	if candidates.is_empty(): return
	if not has_target():
		_cycle=candidates; _select(candidates[0]); return
	for index in range(_cycle.size()-1,-1,-1):
		if not is_instance_valid(_cycle[index]): _cycle.remove_at(index)
	# Keep the original order as people move, appending newly visible enemies.
	for person in candidates:
		if not _cycle.has(person): _cycle.append(person)
	var current:=_cycle.find(target)
	for offset in range(1,_cycle.size()+1):
		var person:=_cycle[(current+offset)%_cycle.size()]
		if is_instance_valid(person) and candidates.has(person): _select(person); return

func _select(person: HostileBase) -> void:
	_disconnect_target_death()
	_target_died=false
	target=person; _visible=true; _blocked_seconds=0; _visibility_timer=0
	target.died.connect(_on_target_died)

func _disconnect_target_death() -> void:
	if is_instance_valid(target) and target.died.is_connected(_on_target_died):
		target.died.disconnect(_on_target_died)

func _on_target_died(person: NPCBase) -> void:
	if person==target:
		# Resolve on the next physics tick, after death collision is disabled.
		# Remember the death even if encounter cleanup removes the body first.
		_target_died=true

func _follow_camera(delta: float) -> void:
	var offset:=_aim_point(target)-player.spring_arm.global_position
	var flat:=Vector2(offset.x,offset.z).length()
	var weight:=1.0-exp(-camera_follow_speed*delta)
	if flat>.05:
		player.rotation.y=lerp_angle(player.rotation.y,atan2(-offset.x,-offset.z),weight)
	var pitch:=clampf(atan2(offset.y,maxf(flat,.05)),deg_to_rad(player.min_camera_angle),deg_to_rad(player.max_camera_angle))
	player.spring_arm.rotation.x=lerp_angle(player.spring_arm.rotation.x,pitch,weight)

func _process(_delta: float) -> void:
	if not has_target(): _marker.hide(); _hint.hide(); return
	var point:=_aim_point(target)
	_marker.visible=_visible and not player.camera.is_position_behind(point)
	if _marker.visible: _marker.position=player.camera.unproject_position(point)-_marker.size*.5
	var bindings: Node=get_node("/root/GameSettings").input_bindings
	var key: String=bindings.label_for("lock_target",bindings.active_device)
	_hint.text="%s  •  %s: next enemy  •  Hold %.1fs: unlock"%[target.display_name,key,release_hold_seconds]
	_hint.show()
