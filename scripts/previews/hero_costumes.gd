extends Node3D
## Synchronized costume preview using the current player's animation libraries.
const REST_POSE := "Rest pose"
const SPEEDS := [0.1, 0.25, 0.5, 1.0, 2.0]
@export var overview_distance := 7.5
@export var outfit_distance := 3.7
@export var focus_height := 1.0
var yaw := 0.0
var pitch := 0.12
var distance := 7.5
var focus := Vector3(0, 1, 0)
var animations: Array[AnimationPlayer] = []
var skeletons: Array[Skeleton3D] = []
var clips: Array[String] = [REST_POSE]
var selected := REST_POSE
var elapsed := 0.0
var speed := 1.0
var playing := true
@onready var camera: Camera3D = $Camera3D
@onready var costumes: Node3D = $Costumes
@onready var view_picker: OptionButton = $CanvasLayer/MarginContainer/Controls/ViewPicker
@onready var clip_picker: OptionButton = $CanvasLayer/MarginContainer/Controls/ClipPicker
@onready var play_button: Button = $CanvasLayer/MarginContainer/Controls/Playback/Play
@onready var speed_picker: OptionButton = $CanvasLayer/MarginContainer/Controls/Playback/Speed
@onready var scrub: HSlider = $CanvasLayer/MarginContainer/Controls/Scrub
@onready var time_label: Label = $CanvasLayer/MarginContainer/Controls/Time

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	view_picker.add_item("All outfits")
	for costume in costumes.get_children():
		view_picker.add_item(str(costume.get_meta("display_name", costume.name)))
		var model := costume.get_node("Model")
		var skeleton := model.get_node_or_null("Armature/GeneralSkeleton") as Skeleton3D
		if skeleton == null:
			continue
		skeletons.append(skeleton)
		var animation := AnimationPlayer.new()
		animation.name = "CostumeAnimationPlayer"
		animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		model.add_child(animation)
		if animations.is_empty():
			# Reuse gameplay's library setup without running movement or combat logic.
			var controller := PlayerAnimationController.new()
			controller.setup(animation, true)
			controller.free()
		else:
			for library in animations[0].get_animation_library_list():
				animation.add_animation_library(library, animations[0].get_animation_library(library))
		animations.append(animation)
	if not animations.is_empty():
		for clip in animations[0].get_animation_list():
			if clip != "RESET": clips.append(clip)
	for clip in clips: clip_picker.add_item(clip.replace("_", " "))
	clip_picker.item_selected.connect(func(index: int): select_clip(clips[index]))
	play_button.pressed.connect(toggle_playback)
	$CanvasLayer/MarginContainer/Controls/Playback/Restart.pressed.connect(restart)
	for rate in SPEEDS: speed_picker.add_item(str(rate) + "×")
	speed_picker.select(3)
	speed_picker.item_selected.connect(func(index: int): speed = SPEEDS[index])
	scrub.value_changed.connect(scrub_to)
	view_picker.item_selected.connect(select_view)
	select_view(0)
	select_clip("Idle" if clips.has("Idle") else REST_POSE)

func select_clip(clip: String) -> void:
	assert(clips.has(clip), "Unknown preview animation: " + clip)
	selected = clip
	elapsed = 0.0
	clip_picker.select(clips.find(clip))
	for animation in animations: animation.stop()
	# Clear unkeyed bones when switching between authored and full-body clips.
	for skeleton in skeletons: skeleton.reset_bone_poses()
	if selected != REST_POSE:
		for animation in animations: animation.play(selected, 0)
	scrub.editable = selected != REST_POSE
	play_button.disabled = selected == REST_POSE
	pose()

func clip_length() -> float:
	return animations[0].get_animation(selected).length if selected != REST_POSE else 0.0

func pose() -> void:
	if selected != REST_POSE:
		for animation in animations:
			animation.seek(elapsed, true)
			animation.advance(0)
	scrub.set_value_no_signal(elapsed / maxf(clip_length(), 0.001))
	play_button.text = "Pause" if playing else "Play"
	time_label.text = "Rest pose" if selected == REST_POSE else "%.2f / %.2f s  ·  %s" % [elapsed, clip_length(), "Looping" if playing else "Paused"]

func toggle_playback() -> void:
	if selected == REST_POSE: return
	playing = not playing
	pose()

func restart() -> void:
	elapsed = 0.0
	pose()

func scrub_to(fraction: float) -> void:
	playing = false
	elapsed = clampf(fraction, 0.0, 1.0) * clip_length()
	pose()

func _process(delta: float) -> void:
	if playing and selected != REST_POSE:
		elapsed = fmod(elapsed + delta * speed, maxf(clip_length(), 0.001))
		pose()

func _shortcut_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		toggle_playback()
		get_viewport().set_input_as_handled()

func select_view(index: int) -> void:
	if index == 0:
		focus = Vector3.ZERO
		for costume: Node3D in costumes.get_children(): focus += costume.global_position
		focus /= maxi(costumes.get_child_count(), 1)
		distance = overview_distance
	else:
		focus = (costumes.get_child(index - 1) as Node3D).global_position
		distance = outfit_distance
	view_picker.select(index)
	focus.y += focus_height
	yaw = 0.0
	pitch = 0.12
	update_camera()

func update_camera() -> void:
	camera.global_position = focus + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(focus)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x * 0.006
		pitch = clampf(pitch + event.relative.y * 0.005, -0.25, 1.1)
		update_camera()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(1.2, distance * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(30.0, distance / 0.9)
		else: return
		update_camera()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		select_view(0)
