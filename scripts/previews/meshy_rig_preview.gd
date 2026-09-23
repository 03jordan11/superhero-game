extends Node3D
## Uses the real player scene and its animation libraries for deformation review.
const PLAYER := preload("res://scenes/player.tscn")
const CLIPS := ["Idle", "Run", "Sprint", "Jump_Charge", "Jump_Start", "Jump_Fall", "Landing", "Flight_Hover", "Flight_Move", "Flight_Fast", "Punch_01", "AuthoredCombo/Hero_Hold", "AuthoredCombo/Hero_Cross", "Death"]
var player: PlayerCharacter
var animation: AnimationPlayer
var camera: Camera3D
var canvas: CanvasLayer
var selected := "Idle"
var elapsed := 0.0
var speed := 1.0
var playing := true
var yaw := 0.25
var pitch := 0.1
var distance := 4.5
var focus := Vector3(0, 0.95, 0)
var scrub: HSlider
var time_label: Label
var picker: OptionButton

func _ready() -> void:
	player = PLAYER.instantiate()
	player.position.y = 1.0
	player.rotation.y = PI
	add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.get_node("GameplayHUD").hide()
	player.get_node("EncounterIndicator").hide()
	player.camera.current = false
	animation = player.character_animation_player
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("303b49")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.86, 0.91, 1.0)
	environment.ambient_light_energy = 0.5
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	for settings in [Vector3(-35, -30, 0.9), Vector3(-25, 150, 0.35)]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(settings.x, settings.y, 0)
		light.light_energy = settings.z
		add_child(light)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("444e5b")
	material.roughness = 1.0
	ground.material_override = material
	ground.position.y = -0.015
	add_child(ground)
	camera = Camera3D.new()
	camera.fov = 35
	add_child(camera)
	camera.make_current()
	get_viewport().msaa_3d = Viewport.MSAA_4X
	get_viewport().mesh_lod_threshold = 0.0
	_make_ui()
	select_clip("Idle")
	update_camera()

func _make_ui() -> void:
	canvas = CanvasLayer.new()
	add_child(canvas)
	var panel := VBoxContainer.new()
	panel.position = Vector2(20, 20)
	canvas.add_child(panel)
	var label := Label.new()
	label.text = "PLAYER ANIMATION PREVIEW | Current costume | Existing 65-bone rig\nRight drag: orbit | Wheel: zoom | Space: pause | R: reset view"
	panel.add_child(label)
	picker = OptionButton.new()
	for clip in CLIPS: picker.add_item(clip)
	picker.item_selected.connect(func(index: int): select_clip(CLIPS[index]))
	panel.add_child(picker)
	var slow := CheckButton.new()
	slow.text = "Quarter speed"
	slow.toggled.connect(func(enabled: bool): speed = 0.25 if enabled else 1.0)
	panel.add_child(slow)
	scrub = HSlider.new()
	scrub.custom_minimum_size.x = 400
	scrub.max_value = 1.0
	scrub.step = 0.001
	scrub.value_changed.connect(func(value: float):
		playing = false
		elapsed = value * animation.get_animation(selected).length
		pose())
	panel.add_child(scrub)
	time_label = Label.new()
	panel.add_child(time_label)

func select_clip(clip: String) -> void:
	assert(animation.has_animation(clip), "Missing player animation: " + clip)
	selected = clip
	if picker != null: picker.select(CLIPS.find(clip))
	elapsed = 0.0
	animation.play(selected, 0)
	pose()

func pose() -> void:
	animation.seek(elapsed, true)
	animation.advance(0)
	var length := animation.get_animation(selected).length
	if scrub != null: scrub.set_value_no_signal(elapsed / maxf(length, 0.001))
	if time_label != null: time_label.text = "%s | %.2f / %.2f s" % [selected, elapsed, length]

func _process(delta: float) -> void:
	if playing:
		elapsed = fmod(elapsed + delta * speed, maxf(animation.get_animation(selected).length, 0.001))
		pose()

func update_camera() -> void:
	camera.position = focus + Vector3(sin(yaw)*cos(pitch), sin(pitch), cos(yaw)*cos(pitch))*distance
	camera.look_at(focus)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x * 0.008
		pitch = clampf(pitch + event.relative.y * 0.008, -0.7, 1.2)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(0.7, distance * 0.9)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(8.0, distance / 0.9)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_SPACE: playing = not playing
		if event.physical_keycode == KEY_R:
			yaw = 0.25; pitch = 0.1; distance = 4.5; focus = Vector3(0, 0.95, 0)
	update_camera()
