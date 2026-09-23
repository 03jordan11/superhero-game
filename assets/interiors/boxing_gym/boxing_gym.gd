extends Node3D
## Directly playable interior; travel replaces the standalone player before ready.
@export var shoulder_offset := Vector3(.6, .75, 0)
@export_range(.5, 3, .05) var shoulder_distance := 1.5
@export_range(-30, 10, 1) var shoulder_pitch_degrees := -8.0
@export var indoor_walk_speed := 3.3
@export var indoor_sprint_speed := 6.0

func _ready() -> void:
	var player: PlayerCharacter = $Player
	player.global_transform = $PlayerSpawn.global_transform
	player.ground_facing_yaw = player.global_rotation.y
	player.minimum_run_speed = indoor_sprint_speed
	player.run_speed_per_attribute_point = 0
	player.walk_speed_ratio = clampf(indoor_walk_speed / maxf(indoor_sprint_speed,.1), .1, 1)
	player.floor_snap_length = .35
	player.spring_arm.spring_length = shoulder_distance
	player.spring_arm.position = shoulder_offset
	player.camera_effects.base_spring_arm_position = shoulder_offset
	player.spring_arm.rotation = Vector3(deg_to_rad(shoulder_pitch_degrees), 0, 0)
	player.spring_arm.margin = .25
	var clearance := SphereShape3D.new()
	clearance.radius = .3
	player.spring_arm.shape = clearance
	player.camera.make_current()
	player.reset_physics_interpolation()
