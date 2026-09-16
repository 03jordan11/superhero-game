extends GPUParticles3D
## Sparse, distance-limited GPU smoke; no collision or lights.
const MAX_ACTIVE := 12
static var active_emitters := 0
@export_range(30, 1000, 10) var activation_distance := 350.0
@export var smoke_enabled := true
var _holds_slot := false

func _ready() -> void:
	emitting=false
	var timer:=Timer.new(); timer.wait_time=.5; timer.autostart=true
	add_child(timer); timer.timeout.connect(update_emission)
	update_emission()

func update_emission() -> void:
	var camera:=get_viewport().get_camera_3d()
	var nearby:=smoke_enabled and camera!=null and camera.global_position.distance_squared_to(global_position)<activation_distance*activation_distance
	if nearby and not _holds_slot and active_emitters<MAX_ACTIVE:
		_holds_slot=true; active_emitters+=1
	elif not nearby and _holds_slot:
		_holds_slot=false; active_emitters-=1
	emitting=_holds_slot
	visible=nearby

func _exit_tree() -> void:
	if _holds_slot:
		active_emitters-=1; _holds_slot=false
