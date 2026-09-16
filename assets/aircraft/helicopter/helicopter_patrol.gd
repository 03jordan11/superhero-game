extends Node3D
## One ambient helicopter. This node owns the route, not the flight response.
@export var patrol_enabled := true
@export_group("Orbit (relative to this node)")
@export_range(80.0, 3000.0, 10.0, "suffix:m") var orbit_radius := 550.0
@export_range(50.0, 1500.0, 5.0, "suffix:m") var altitude := 280.0
@export_range(5.0, 65.0, 1.0, "suffix:m/s") var cruise_speed := 38.0
@export var clockwise := true
@export_range(-180.0, 180.0, 1.0, "suffix:°") var starting_angle_degrees := 90.0
@export_range(0.1, 2.0, 0.05) var path_correction := 0.5
@export_enum("Forest / cream", "Rescue red", "Coastal blue", "Charcoal / orange") var livery := 1:
	set(value):
		livery = clampi(value,0,3)
		if is_node_ready(): $Aircraft/Helicopter.livery = livery

var phase := 0.0
var effective_speed := 0.0
var lap_seconds := 0.0
@onready var aircraft: Node3D = $Aircraft

func _ready() -> void:
	process_physics_priority = -10
	phase = deg_to_rad(starting_angle_degrees)
	aircraft.get_node("Helicopter").livery = livery
	var sample := sample_orbit(phase)
	aircraft.initialize_flight(sample.position,sample.velocity,sample.acceleration)
	_sync_enabled()

func _sync_enabled() -> void:
	visible = patrol_enabled
	aircraft.set_physics_process(patrol_enabled)
	aircraft.get_node("Helicopter").rotors_spinning = patrol_enabled

func sample_orbit(angle: float) -> Dictionary:
	var radius := maxf(orbit_radius,80.0)
	# Slow tighter orbits rather than demanding acceleration/bank beyond the limits.
	var limit := minf(aircraft.maximum_acceleration,9.81*tan(deg_to_rad(aircraft.maximum_bank_degrees)))
	effective_speed = minf(minf(maxf(cruise_speed,0.0),aircraft.maximum_speed),sqrt(maxf(limit,0.1)*radius)*0.9)
	lap_seconds = TAU*radius/maxf(effective_speed,0.1)
	var direction := 1.0 if clockwise else -1.0
	var radial := Vector3(cos(angle),0,sin(angle))
	var tangent := Vector3(-sin(angle),0,cos(angle))*direction
	# A horizontal world-space orbit: parent yaw affects placement, not altitude tilt.
	var yaw := Basis(Vector3.UP,global_rotation.y)
	return {
		"position":global_position+yaw*radial*radius+Vector3.UP*altitude,
		"velocity":yaw*tangent*effective_speed,
		"acceleration":-(yaw*radial)*effective_speed*effective_speed/radius,
	}

func _physics_process(delta: float) -> void:
	_sync_enabled()
	if not patrol_enabled: return
	advance_guidance(delta)

func advance_guidance(delta: float) -> void:
	var direction := 1.0 if clockwise else -1.0
	phase = wrapf(phase+direction*effective_speed/maxf(orbit_radius,80.0)*delta,-PI,PI)
	var sample := sample_orbit(phase)
	var correction: Vector3 = (sample.position-aircraft.global_position)*path_correction
	aircraft.set_flight_command(sample.velocity+correction,sample.acceleration)
