class_name PlayerSpeedFeedback
extends Node3D
## One movement envelope drives both wind audio and subtle speed visuals.

@export_group("Speed Thresholds")
## Actual ground speed or 3D flight speed; independent of unlocks and input.
@export_range(0.1, 200.0, 0.5, "suffix:m/s") var movement_start_speed := 15.0
## Downward speed while airborne without flight. Upward jumps do not count.
@export_range(0.1, 200.0, 0.5, "suffix:m/s") var falling_start_speed := 25.0
## Speed above the applicable threshold needed for full wind intensity.
@export_range(1.0, 200.0, 0.5, "suffix:m/s") var speed_ramp := 30.0
@export_range(0.05, 2.0, 0.05, "suffix:s") var fade_seconds := 0.4
@export_group("Visuals")
## Zero disables visual rendering while retaining wind audio.
@export_range(0.0, 1.0, 0.05) var visual_strength := 0.6

var intensity := 0.0
var _trails: MeshInstance3D
var _overlay: ColorRect
var _trail_material: ShaderMaterial
var _screen_material: ShaderMaterial
@onready var _player := get_parent() as PlayerCharacter

func _ready() -> void:
	process_priority = 5 # Before PlayerSoundManager consumes intensity.
	_trail_material = ShaderMaterial.new()
	_trail_material.shader = preload("res://effects/player_speed_trails.gdshader")
	_screen_material = ShaderMaterial.new()
	_screen_material.shader = preload("res://effects/player_speed_screen.gdshader")
	_trails = MeshInstance3D.new()
	_trails.name = "WindTrails"
	_trails.mesh = _build_trails()
	_trails.material_override = _trail_material
	_trails.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trails)
	_trails.top_level = true
	_trails.hide()
	var layer := CanvasLayer.new()
	layer.name = "SpeedScreen"
	layer.layer = 0 # Gameplay HUD and menus draw afterward, undistorted.
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.name = "EdgeDistortion"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.material = _screen_material
	layer.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.hide()

func _process(delta: float) -> void:
	update_feedback(delta, _player.get_real_velocity(), _player.is_on_floor(),
		_player.is_flying, not _player.is_dead and not _player.is_knocked_out)

func calculate_target(motion: Vector3, grounded: bool, flying: bool, active: bool = true) -> float:
	if not active:
		return 0.0
	var speed := Vector2(motion.x, motion.z).length() if grounded else maxf(-motion.y, 0.0)
	var threshold := movement_start_speed if grounded or flying else falling_start_speed
	if flying:
		speed = motion.length()
	if speed < maxf(threshold, 0.1):
		return 0.0
	return lerpf(0.2, 1.0, smoothstep(threshold, threshold + maxf(speed_ramp, 1.0), speed))

func update_feedback(delta: float, motion: Vector3, grounded: bool, flying: bool, active: bool = true) -> void:
	var target := calculate_target(motion, grounded, flying, active)
	intensity = move_toward(intensity, target, maxf(delta, 0.0) / maxf(fade_seconds, 0.05))
	var strength := intensity * clampf(visual_strength, 0.0, 1.0)
	var visible_now := strength > 0.001
	_trails.visible = visible_now
	_overlay.visible = visible_now # No full-screen copy or transparent draws while idle.
	if not visible_now:
		return
	_screen_material.set_shader_parameter("intensity", strength)
	_trail_material.set_shader_parameter("intensity", strength)
	_trails.global_position = _player.global_position + Vector3.UP * 1.05
	if motion.length_squared() > 0.01:
		var direction := motion.normalized()
		var up := Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.95 else Vector3.UP
		_trails.global_basis = Basis.looking_at(direction, up)
	_trails.scale = Vector3(1.0, 1.0, lerpf(0.65, 1.4, intensity))

func _build_trails() -> ArrayMesh:
	# Four narrow, curved ribbons. Built once; the shader handles their movement.
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for origin in [Vector2(-0.6, 0.35), Vector2(0.6, 0.35), Vector2(-0.36, -0.5), Vector2(0.36, -0.5)]:
		var start := vertices.size()
		for segment in range(13):
			var t := float(segment) / 12.0
			var center := Vector3(origin.x * (1.0 + t * 0.55), origin.y + sin(t * PI) * 0.1, t * 3.5)
			for side in range(2):
				vertices.append(center + Vector3.RIGHT * (float(side) - 0.5) * 0.09)
				uvs.append(Vector2(float(side), t))
			if segment < 12:
				var i := start + segment * 2
				indices.append_array(PackedInt32Array([i, i + 1, i + 2, i + 1, i + 3, i + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
