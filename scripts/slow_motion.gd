extends Node
## Shared game/audio slowdown. Each caller owns one request; the strongest wins.
@export_range(0.0, 2.0, 0.01) var ease_in_seconds := 0.1
@export_range(0.0, 3.0, 0.01) var ease_out_seconds := 0.5
var _requests: Dictionary = {}
var _base_speed := 1.0
var _active := false
var _from := 1.0
var _target := 1.0
var _elapsed := 0.0
var _duration := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Speed is a multiplier of the game speed before the first active request.
## Repeated calls from the same source update its request instead of stacking.
func start(source: Node, speed: float = 0.5) -> bool:
	if not is_instance_valid(source) or not source.is_inside_tree() or get_tree().paused or not is_finite(speed): return false
	var id := source.get_instance_id()
	if not _active:
		_base_speed = Engine.time_scale
		_active = true
	if not _requests.has(id):
		var on_exit := _release.bind(id, true)
		source.tree_exiting.connect(on_exit, CONNECT_ONE_SHOT)
		_requests[id] = {"source": weakref(source), "on_exit": on_exit, "speed": 1.0}
	_requests[id].speed = clampf(speed, 0.01, 1.0)
	_apply()
	return true

func stop(source: Node, immediate := false) -> void:
	if is_instance_valid(source): _release(source.get_instance_id())
	# Teardown can follow an earlier input cancellation that already began a fade.
	if immediate and _requests.is_empty(): cancel_all()

func _release(id: int, exiting := false) -> void:
	if not _requests.has(id): return
	_disconnect(_requests[id])
	_requests.erase(id)
	_apply()
	# Scene teardown must not carry a slowed soundtrack into the next scene.
	if exiting and _requests.is_empty(): cancel_all()

func _disconnect(request: Dictionary) -> void:
	var source: Node = request.source.get_ref()
	if is_instance_valid(source) and source.tree_exiting.is_connected(request.on_exit):
		source.tree_exiting.disconnect(request.on_exit)

func _apply() -> void:
	var multiplier := 1.0
	for request in _requests.values(): multiplier = minf(multiplier, request.speed)
	var target := _base_speed * multiplier
	if is_equal_approx(target, _target) and _duration > 0.0: return
	_from = Engine.time_scale
	_target = target
	_elapsed = 0.0
	_duration = ease_in_seconds if target < _from else ease_out_seconds
	if _duration <= 0.0: _advance(0.0)

func _advance(real_delta: float) -> void:
	if not _active: return
	_elapsed += maxf(real_delta, 0.0)
	var weight := 1.0 if _duration <= 0.0 else clampf(_elapsed / _duration, 0.0, 1.0)
	_set_speed(lerpf(_from, _target, smoothstep(0.0, 1.0, weight)))
	if weight >= 1.0:
		_duration = 0.0
		if _requests.is_empty(): _active = false

func _set_speed(value: float) -> void:
	Engine.time_scale = value
	AudioServer.playback_speed_scale = value

func cancel_all() -> void:
	if not _active: return
	for request in _requests.values(): _disconnect(request)
	_requests.clear()
	_set_speed(_base_speed)
	_active = false
	_duration = 0.0

func _process(delta: float) -> void:
	if get_tree().paused:
		cancel_all()
		return
	_advance(delta / maxf(Engine.time_scale, 0.001))

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]: cancel_all()

func _exit_tree() -> void:
	cancel_all()
