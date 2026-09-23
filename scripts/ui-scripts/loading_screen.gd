extends CanvasLayer
## Persists across scene swaps. Resource progress is measured; scene setup uses
## explicit milestones because Godot instantiates scenes on the main thread.
signal finished(succeeded: bool)

@export var background_texture: Texture2D = preload("res://assets/ui/loading/background.png")
@export_range(0.0, 5.0, 0.1) var error_display_seconds := 1.5

var active := false
var _previous_pause := false
var _previous_input_disabled := false
var _previous_mouse_mode: Input.MouseMode
@onready var progress_bar: ProgressBar = $Screen/Footer/Content/Progress
@onready var status_label: Label = $Screen/Footer/Content/StatusRow/Status
@onready var percent_label: Label = $Screen/Footer/Content/StatusRow/Percent

func _ready() -> void:
	$Screen/Background.texture = background_texture
	hide()

func begin(title: String) -> bool:
	if active: return false
	active = true
	_previous_pause = get_tree().paused
	_previous_input_disabled = get_viewport().is_input_disabled()
	_previous_mouse_mode = Input.mouse_mode
	get_tree().paused = true
	# Disable even always-processing menus and their keyboard/gamepad shortcuts.
	get_viewport().set_disable_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	$Screen/Footer/Content/Title.text = title
	progress_bar.value = 0
	set_progress(0, "Please wait…")
	show()
	return true

func set_progress(value: float, status: String) -> void:
	progress_bar.value = maxf(progress_bar.value, clampf(value, 0, 100))
	percent_label.text = "%d%%" % int(progress_bar.value)
	status_label.text = status

func present() -> void:
	# process_frame alone resumes before drawing. Wait for the loading screen to
	# actually reach the renderer before any main-thread instantiation/free work.
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	else:
		await get_tree().process_frame

func checkpoint(value: float, status: String) -> void:
	set_progress(value, status)
	await present()

func load_scene(path: String, from_percent: float, to_percent: float) -> PackedScene:
	await checkpoint(from_percent, "Loading resources…")
	if not ResourceLoader.exists(path, "PackedScene"): return null
	var error := ResourceLoader.load_threaded_request(path, "PackedScene")
	if error != OK: return null
	while true:
		var progress: Array = []
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			set_progress(to_percent, "Resources loaded")
			return ResourceLoader.load_threaded_get(path) as PackedScene
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS: return null
		if not progress.is_empty():
			set_progress(lerpf(from_percent, to_percent, float(progress[0])), "Loading resources…")
		await get_tree().process_frame
	return null

func finish(succeeded: bool) -> void:
	if succeeded:
		# City proxies use the final seed/materials and build a chunk per
		# frame. Keep that setup covered for Start, Load and returns to the city.
		for controller in get_tree().get_nodes_in_group(&"city_hlod_preparation"):
			while is_instance_valid(controller) and not controller.prepared:
				set_progress(94.0 + 5.0 * controller.prepared_chunks / maxf(controller.total_chunks, 1.0), "Preparing distant scenery…")
				await present()
		await checkpoint(100, "Ready")
	else:
		status_label.text = "Could not load this destination. Returning…"
		await present()
		await get_tree().create_timer(error_display_seconds).timeout
	# Keep the final scene covered through one full rendered frame, including its
	# deferred initialization. Never show 100% before arrival setup has finished.
	hide()
	get_tree().paused = _previous_pause
	get_viewport().set_disable_input(_previous_input_disabled)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if succeeded else _previous_mouse_mode
	active = false
	finished.emit(succeeded)
