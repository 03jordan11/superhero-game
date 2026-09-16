@tool
extends Node
## Shared solar clock for outdoor lighting and the hideout's time-only clock.
signal time_changed(hours: float)

@export_group("Clock")
@export_range(0.0, 24.0, 0.01) var time_of_day := 17.0:
	set(value):
		if not is_finite(value): return
		time_of_day = fposmod(value, 24.0)
		if is_node_ready(): time_changed.emit(time_of_day)
@export var cycle_running := true
@export_range(0.5, 120.0, 0.5, "suffix:min") var day_length_minutes := 24.0
@export_range(0.0, 60.0, 0.5) var time_scale := 1.0

func _ready() -> void:
	add_to_group(&"game_clock")

func _process(delta: float) -> void:
	_advance_clock(delta)

func _advance_clock(delta: float) -> void:
	if not Engine.is_editor_hint() and cycle_running:
		advance_hours(delta * 24.0 / (maxf(day_length_minutes, 0.5) * 60.0) * maxf(time_scale, 0.0))

func set_time(hours: float) -> void:
	time_of_day = hours

func advance_hours(hours: float) -> void:
	set_time(time_of_day + hours)

func formatted_time() -> String:
	var minutes := floori(time_of_day * 60.0) % 1440
	return "%02d:%02d" % [minutes / 60, minutes % 60]

func copy_from(other: Node) -> void:
	set_time(other.time_of_day)
	cycle_running = other.cycle_running
	day_length_minutes = other.day_length_minutes
	time_scale = other.time_scale
