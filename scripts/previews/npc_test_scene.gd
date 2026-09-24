extends Node3D
## Shared inspection room. Add model holders under Hostiles or Friendlies.
const REST_POSE := "Rest pose"
const PLAYBACK_SPEEDS := [0.1, 0.25, 0.5, 1.0, 2.0]

@export var overview_distance: float = 11.5
@export var character_distance: float = 3.4
@export var hand_distance: float = 0.65
@export var orbit_sensitivity: float = 0.006

var actors: Array[Node3D] = []
var selected_index: int = 0
var focus := Vector3(0, 1.0, 0)
var yaw: float = 0.0
var pitch: float = 0.08
var distance: float = 11.5
var animations: Array[AnimationPlayer] = []
var skeletons: Array[Skeleton3D] = []
var clips: Array[String] = [REST_POSE]
var selected_clip: String = REST_POSE
var playing: bool = true
var elapsed: float = 0.0
var playback_speed: float = 1.0
var hand_follow: Skeleton3D
@onready var camera: Camera3D = $Camera3D
@onready var picker: OptionButton = $CanvasLayer/Panel/Controls/ActorPicker
@onready var clip_picker: OptionButton = $CanvasLayer/Panel/Controls/ClipPicker
@onready var play_button: Button = $CanvasLayer/Panel/Controls/Playback/Play
@onready var speed_picker: OptionButton = $CanvasLayer/Panel/Controls/Playback/Speed
@onready var scrub: HSlider = $CanvasLayer/Panel/Controls/Scrub
@onready var playback_status: Label = $CanvasLayer/Panel/Controls/PlaybackStatus


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	picker.add_item("All characters")
	for group_name in ["Reference", "Hostiles", "Friendlies"]:
		for actor: Node3D in get_node(group_name).get_children():
			actors.append(actor)
			picker.add_item(str(actor.get_meta("display_name", actor.name)))
			setup_animation(actor)
	picker.item_selected.connect(select_actor)
	$CanvasLayer/Panel/Controls/Views/Front.pressed.connect(func(): set_view(0.0))
	$CanvasLayer/Panel/Controls/Views/Back.pressed.connect(func(): set_view(PI))
	$CanvasLayer/Panel/Controls/Views/Hands.pressed.connect(focus_hand)
	$CanvasLayer/Panel/Controls/Views/Reset.pressed.connect(func(): select_actor(0))
	$CanvasLayer/Panel/Controls/Lineups/Hostiles.pressed.connect(func(): show_lineup(false))
	$CanvasLayer/Panel/Controls/Lineups/Civilians.pressed.connect(func(): show_lineup(true))
	for animation_name in animations[0].get_animation_list() if not animations.is_empty() else []:
		if not str(animation_name).ends_with("A_TPose"):
			clips.append(str(animation_name))
	for clip in clips:
		clip_picker.add_item(clip.get_slice("/", 1).replace("_", " ") if clip.contains("/") else clip)
	clip_picker.item_selected.connect(func(index: int): select_clip(clips[index]))
	play_button.pressed.connect(toggle_playback)
	$CanvasLayer/Panel/Controls/Playback/Restart.pressed.connect(restart_clip)
	for speed in PLAYBACK_SPEEDS:
		speed_picker.add_item(str(speed) + "×")
	speed_picker.select(3)
	speed_picker.item_selected.connect(func(index: int): playback_speed = PLAYBACK_SPEEDS[index])
	scrub.value_changed.connect(scrub_to)
	select_actor(0)
	select_clip("UAL1/Idle" if clips.has("UAL1/Idle") else REST_POSE)


func setup_animation(actor: Node3D) -> void:
	var model := actor.get_node("Model")
	var skeleton := model.get_node_or_null("Armature/GeneralSkeleton") as Skeleton3D
	if skeleton == null:
		return
	skeletons.append(skeleton)
	var animation := AnimationPlayer.new()
	animation.name = "PreviewAnimationPlayer"
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	model.add_child(animation)
	if animations.is_empty():
		CharacterAnimationLibraryLoader.new().load_all_animations(animation, [
			CharacterAnimationLibraryLoader.UAL1_GROUP,
			CharacterAnimationLibraryLoader.UAL2_GROUP,
			CharacterAnimationLibraryLoader.FIGHTING_GROUP,
		])
	else:
		for library in animations[0].get_animation_library_list():
			animation.add_animation_library(library, animations[0].get_animation_library(library))
	animations.append(animation)


func select_clip(clip: String) -> void:
	if not clips.has(clip):
		return
	selected_clip = clip
	elapsed = 0.0
	clip_picker.select(clips.find(clip))
	for animation in animations:
		animation.stop()
	for skeleton in skeletons:
		skeleton.reset_bone_poses()
	if clip != REST_POSE:
		for animation in animations:
			animation.play(clip, 0)
	scrub.editable = clip != REST_POSE
	play_button.disabled = clip == REST_POSE
	apply_pose()


func clip_length() -> float:
	return animations[0].get_animation(selected_clip).length if selected_clip != REST_POSE else 0.0


func apply_pose() -> void:
	if selected_clip != REST_POSE:
		for animation in animations:
			animation.seek(elapsed, true)
			animation.advance(0)
	scrub.set_value_no_signal(elapsed / maxf(clip_length(), 0.001))
	play_button.text = "Pause" if playing else "Play"
	var state := "Rest pose" if selected_clip == REST_POSE else "%.2f / %.2f s · %s" % [elapsed, clip_length(), "Looping" if playing else "Paused"]
	playback_status.text = state + "\nHero, hostiles, and civilians share animation playback."
	if is_instance_valid(hand_follow):
		var bone := hand_follow.find_bone("LeftHand")
		if bone >= 0:
			hand_follow.force_update_all_bone_transforms()
			focus = hand_follow.to_global(hand_follow.get_bone_global_pose(bone).origin)
			update_camera()


func toggle_playback() -> void:
	if selected_clip == REST_POSE:
		return
	playing = not playing
	apply_pose()


func restart_clip() -> void:
	elapsed = 0.0
	apply_pose()


func scrub_to(fraction: float) -> void:
	playing = false
	elapsed = clampf(fraction, 0, 1) * clip_length()
	apply_pose()


func _process(delta: float) -> void:
	if playing and selected_clip != REST_POSE:
		elapsed = fmod(elapsed + delta * playback_speed, maxf(clip_length(), 0.001))
		apply_pose()


func _shortcut_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		toggle_playback()
		get_viewport().set_input_as_handled()


func select_actor(index: int) -> void:
	hand_follow = null
	selected_index = clampi(index, 0, actors.size())
	picker.select(selected_index)
	for actor in actors:
		actor.visible = true
		var label := actor.get_node_or_null("Label") as Label3D
		if label != null:
			label.visible = selected_index == 0
	$Studio/HeightGuides.visible = true
	if selected_index == 0:
		focus = Vector3.ZERO
		for actor in actors:
			focus += actor.global_position
		focus /= maxi(actors.size(), 1)
		distance = overview_distance
	else:
		focus = actors[selected_index - 1].global_position
		distance = character_distance
	focus.y += float(actors[selected_index - 1].get_meta("view_height", 0.95)) if selected_index > 0 else 0.95
	pitch = 0.08
	set_view(0.0)


func set_view(angle: float) -> void:
	yaw = angle
	update_camera()


func show_lineup(civilians: bool) -> void:
	select_actor(0)
	var lineup: Array[Node3D] = []
	for actor in actors:
		actor.visible = (actor.get_parent() == $Friendlies) == civilians
		if actor.visible:
			lineup.append(actor)
	if lineup.is_empty():
		return
	focus = Vector3.ZERO
	for actor in lineup:
		focus += actor.global_position
	focus /= lineup.size()
	focus.y += 0.95
	distance = 11.5
	update_camera()


func focus_hand() -> void:
	if selected_index == 0:
		select_actor(2 if actors.size() >= 2 else 1)
	if actors.is_empty():
		return
	var actor := actors[selected_index - 1]
	# Each holder can override this for a different pose or future character.
	focus = actor.to_global(actor.get_meta("hand_focus", Vector3(0.76, 1.43, 0)))
	hand_follow = actor.get_node_or_null("Model/Armature/GeneralSkeleton") as Skeleton3D
	$Studio/HeightGuides.visible = false
	distance = hand_distance
	pitch = 0.65
	set_view(0.0)
	apply_pose()


func update_camera() -> void:
	camera.global_position = focus + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(focus)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			yaw -= event.relative.x * orbit_sensitivity
			pitch = clampf(pitch + event.relative.y * orbit_sensitivity, -1.45, 1.45)
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			hand_follow = null
			focus += (-camera.global_basis.x * event.relative.x + camera.global_basis.y * event.relative.y) * distance * 0.0012
		else:
			return
		update_camera()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(0.18, distance * 0.88)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(30.0, distance / 0.88)
		else:
			return
		update_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			select_actor(0)
		elif event.keycode >= KEY_0 and event.keycode <= KEY_9:
			select_actor(mini(event.keycode - KEY_0, actors.size()))
