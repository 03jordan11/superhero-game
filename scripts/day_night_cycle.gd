@tool
extends "res://scripts/game_clock.gd"
signal night_lighting_changed(amount: float)
signal window_settings_changed(occupancy_scale: float, brightness_scale: float)
## One clock drives the sky, sunlight, moonlight and distance haze. Hours are artistic
## local solar time (sunrise 06:00 / sunset 18:00), not a calendar simulation.

const SKY_SHADER = preload("res://assets/sky/hero_sky.gdshader")
const MILKY_WAY = preload("res://assets/sky/custom_galaxy.res")
const STARS = preload("res://assets/sky/custom_stars.res")

@export_group("Celestial Sky")
@export_range(-180.0, 180.0, 1.0, "suffix:deg") var sun_heading := -65.0
@export_range(-75.0, 75.0, 1.0, "suffix:deg") var latitude := 35.0
@export_range(-180.0, 180.0, 1.0, "suffix:deg") var star_heading := 25.0
@export_range(0.0, 12.0, 0.01) var milky_way_intensity := 0.0
@export_range(0.0, 8.0, 0.01) var star_intensity := 0.18
@export_range(0.0, 1.0, 0.01) var star_density := 0.08
@export_range(0.0, 1.0, 0.01) var horizon_light_pollution := 0.12
@export_range(0.2, 3.0, 0.1, "suffix:deg") var moon_radius_degrees := 0.86
@export_group("Lighting")
@export_range(0.0, 4.0, 0.05) var sunlight_energy := 1.25
@export_range(0.0, 1.0, 0.01) var moonlight_energy := 0.22
@export_range(0.0, 1.0, 0.01) var night_ambient_energy := 0.28
@export_range(0.0, 0.01, 0.0001) var day_fog_density := 0.00025
@export_range(0.0, 0.01, 0.0001) var night_fog_density := 0.00055
@export_range(0.0, 1.0, 0.01) var bloom_intensity := 0.18
@export_range(1.0, 5.0, 0.05) var bloom_threshold := 1.8
@export_group("Building Windows")
@export_range(0.0, 2.0, 0.05) var window_occupancy_scale := 1.0
@export_range(0.0, 3.0, 0.05) var window_brightness_scale := 1.0
@export_group("Drifting Clouds")
@export_range(0.0, 1.0, 0.01) var cloud_coverage := 0.32
@export_range(0.0, 5.0, 0.1) var cloud_speed := 1.0
@export_group("Scene Links")
@export_node_path("WorldEnvironment") var environment_path := NodePath("../Daylight")
@export_node_path("DirectionalLight3D") var sun_path := NodePath("../Sun")
@export_node_path("DirectionalLight3D") var moon_path := NodePath("../Moon")

var _environment: Environment
var _material: ShaderMaterial
var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _cloud_offset := Vector2.ZERO
var _update_elapsed := 0.0
var night_lighting := 0.0
var _last_window_settings := Vector2(-1,-1)
var _bloom_allowed := true

func _ready() -> void:
	super._ready()
	time_changed.connect(_on_time_changed)
	var world := get_node_or_null(environment_path) as WorldEnvironment
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	_moon = get_node_or_null(moon_path) as DirectionalLight3D
	if world == null or _sun == null or _moon == null:
		push_error("DayNightCycle needs a WorldEnvironment, Sun and Moon; check Scene Links.")
		set_process(false)
		return
	# Private resources avoid changing the source scene or another preview viewport.
	_environment = Environment.new()
	_material = ShaderMaterial.new()
	_material.shader = SKY_SHADER
	_material.set_shader_parameter("milky_way", MILKY_WAY)
	_material.set_shader_parameter("bright_stars", STARS)
	var noise := FastNoiseLite.new()
	noise.seed = 8421
	noise.frequency = 0.008
	noise.fractal_octaves = 5
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.generate_mipmaps = true
	texture.noise = noise
	_material.set_shader_parameter("cloud_noise", texture)
	var sky := Sky.new()
	sky.sky_material = _material
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.glow_enabled = true
	_environment.glow_intensity = bloom_intensity
	_environment.glow_hdr_threshold = bloom_threshold
	_environment.fog_enabled = true
	_environment.fog_sky_affect = 0.0
	world.environment = _environment
	world.set_meta("day_night_environment", true)
	if not Engine.is_editor_hint():
		var settings := get_node_or_null("/root/GameSettings")
		if settings != null:
			settings.graphics_settings_changed.connect(_on_graphics_settings_changed)
			_bloom_allowed = settings.bloom_enabled
	_sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	_moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_to_group(&"day_night_cycle")
	_update_environment()

func _process(delta: float) -> void:
	_update_elapsed += delta
	if _update_elapsed < 1.0 / 30.0: return
	var elapsed := _update_elapsed
	_update_elapsed = 0.0
	if not Engine.is_editor_hint():
		if cycle_running:
			# Cloud wind follows pause, but is independent of accelerated solar time.
			_cloud_offset += Vector2(0.0013, 0.00045) * elapsed * cloud_speed
			_cloud_offset = Vector2(fposmod(_cloud_offset.x, 10.0), fposmod(_cloud_offset.y, 10.0))
			_advance_clock(elapsed)
			return
	# Editor changes preview instantly, and a stopped clock can still be tuned.
	_update_environment()

func _on_time_changed(_hours: float) -> void:
	_update_environment()

func _on_graphics_settings_changed() -> void:
	_bloom_allowed = get_node("/root/GameSettings").bloom_enabled
	_update_environment()

func _update_environment() -> void:
	if _environment == null: return
	var window_settings := Vector2(window_occupancy_scale,window_brightness_scale)
	if not window_settings.is_equal_approx(_last_window_settings):
		_last_window_settings=window_settings
		window_settings_changed.emit(window_occupancy_scale,window_brightness_scale)
	_environment.glow_enabled = _bloom_allowed and bloom_intensity > 0
	_environment.glow_intensity = bloom_intensity
	_environment.glow_hdr_threshold = bloom_threshold
	var orbit := (time_of_day - 6.0) / 24.0 * TAU
	var direction := Basis(Vector3.UP, deg_to_rad(sun_heading)) * Vector3(cos(orbit), sin(orbit) * 0.82, sin(orbit) * 0.57).normalized()
	var moon_direction := -direction
	# Local +Z points toward the light source; Godot shines along local -Z.
	_sun.global_basis = Basis.looking_at(-direction, Vector3.UP)
	_moon.global_basis = Basis.looking_at(-moon_direction, Vector3.UP)
	var daylight := smoothstep(-0.12, 0.22, direction.y)
	var sunlight := smoothstep(-0.035, 0.16, direction.y)
	var lamp_amount := 1.0 - smoothstep(-0.12, 0.1, direction.y)
	if not is_equal_approx(lamp_amount, night_lighting):
		night_lighting = lamp_amount
		night_lighting_changed.emit(night_lighting)
	_sun.light_energy = sunlight_energy * sunlight
	_sun.light_color = Color(1.0, 0.35, 0.12).lerp(Color(1.0, 0.94, 0.84), smoothstep(0.0, 0.4, direction.y))
	_sun.visible = sunlight > 0.001
	_moon.light_energy = moonlight_energy * smoothstep(0.0, 0.25, moon_direction.y)
	_moon.light_color = Color(0.52, 0.66, 1.0)
	_moon.visible = _moon.light_energy > 0.001
	_environment.ambient_light_color = Color(0.28, 0.4, 0.67).lerp(Color(0.76, 0.84, 1.0), daylight)
	_environment.ambient_light_energy = lerpf(night_ambient_energy, 0.65, daylight)
	_environment.fog_density = lerpf(night_fog_density, day_fog_density, daylight)
	var twilight := exp(-pow((direction.y + 0.015) / 0.17, 2.0))
	_environment.fog_light_color = Color(0.065, 0.075, 0.10).lerp(Color(0.55, 0.68, 0.84), daylight).lerp(Color(0.56, 0.25, 0.22), twilight * 0.55)
	_environment.fog_light_energy = lerpf(0.35, 0.7, daylight)
	_material.set_shader_parameter("sun_direction", direction)
	_material.set_shader_parameter("moon_direction", moon_direction)
	# Rotate the complete celestial sphere about a tilted pole, not flat UV scrolling.
	var pole_tilt := Basis(Vector3.RIGHT, deg_to_rad(90.0 - latitude))
	var spin := Basis(Vector3.UP, time_of_day / 24.0 * TAU)
	var heading := Basis(Vector3.UP, deg_to_rad(star_heading))
	_material.set_shader_parameter("star_rotation", spin * pole_tilt * heading)
	_material.set_shader_parameter("milky_way_intensity", milky_way_intensity)
	_material.set_shader_parameter("star_intensity", star_intensity)
	_material.set_shader_parameter("star_density", star_density)
	_material.set_shader_parameter("horizon_light_pollution", horizon_light_pollution)
	_material.set_shader_parameter("moon_size", deg_to_rad(moon_radius_degrees))
	_material.set_shader_parameter("cloud_coverage", cloud_coverage)
	_material.set_shader_parameter("cloud_offset", _cloud_offset)
