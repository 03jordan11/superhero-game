extends Node3D
## Inspection controls are isolated to this preview; the main game controls are untouched.
const BASE := "res://assets/waterfront/cargo_ship/"
const VARIANTS := ["ocean_blue", "oxide_red", "deep_teal", "graphite"]
var yaw := .65
var pitch := .46
var distance := 205.0
var target := Vector3(0,9,0)
var _elapsed := 0.0

func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_update_camera()
	_update_help(0)

func _process(delta: float) -> void:
	_elapsed += delta
	($Water.material_override as ShaderMaterial).set_shader_parameter("elapsed",_elapsed)

func set_variant(index: int) -> void:
	$Ship.palette = load(BASE + "materials/" + VARIANTS[index] + ".tres")
	_update_help(index)

func set_night(enabled: bool) -> void:
	$DayNightCycle.set_time(0.0 if enabled else 13.0)
	($Water.material_override as ShaderMaterial).set_shader_parameter("night_amount", 1.0 if enabled else 0.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4: set_variant(event.keycode - KEY_1)
			KEY_N: set_night($DayNightCycle.time_of_day != 0.0)
			KEY_A:
				$Ship.navigation_mode = ($Ship.navigation_mode + 1) % 3
				_update_help(-1)
			KEY_B:
				yaw = PI
				pitch = .12
				_update_camera()
			KEY_R:
				yaw = .65
				pitch = .46
				distance = 205
				target = Vector3(0,9,0)
				_update_camera()
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			yaw -= event.relative.x * .006
			pitch = clampf(pitch + event.relative.y * .004, -.15, 1.45)
			_update_camera()
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			target += ($Camera3D.global_basis.x * -event.relative.x + $Camera3D.global_basis.y * event.relative.y) * distance * .001
			_update_camera()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(8, distance * .9)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(600, distance * 1.1)
		_update_camera()

func _update_camera() -> void:
	$Camera3D.position = target + Vector3(sin(yaw)*cos(pitch),sin(pitch),-cos(yaw)*cos(pitch))*distance
	$Camera3D.look_at(target)

func _update_help(index: int) -> void:
	if index >= 0: $Help/Panel/Label.set_meta("variant", VARIANTS[index].capitalize())
	$Help/Panel/Label.text = "CARGO SHIP  /  %s\n1–4 Material variants   •   N Day / night   •   A Lighting mode: %s\nLeft drag Orbit   •   Right drag Pan   •   Wheel Zoom   •   B Stern   •   R Reset\n156 m length  /  Waterline Y = 0  /  Forward −Z" % [$Help/Panel/Label.get_meta("variant"), ["Underway","Anchored","Berthed"][$Ship.navigation_mode]]
