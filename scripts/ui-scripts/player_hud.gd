class_name PlayerHud
extends CanvasLayer

## Presentation-only subscriber for Player gameplay events. Gameplay objects
## publish raw values; the HUD owns percentages, clamping, and label formatting.

@onready var charge_bar: ProgressBar = $ChargeBar
@onready var charge_label: Label = $ChargeLabel
@onready var landing_label: Label = $LandingLabel
@onready var flight_speed_bar: ProgressBar = $FlightSpeedBar
@onready var flight_speed_label: Label = $FlightSpeedLabel
@onready var sprint_speed_bar: ProgressBar = $SprintSpeedBar
@onready var sprint_speed_label: Label = $SprintSpeedLabel
@onready var vehicle_throw_charge_bar: ProgressBar = $VehicleThrowChargeBar
@onready var vehicle_throw_charge_label: Label = $VehicleThrowChargeLabel
@onready var health_bar: ProgressBar = $HealthBar
@onready var health_label: Label = $HealthLabel
@onready var experience_bar: ProgressBar = $ExperienceBar
@onready var experience_label: Label = $ExperienceLabel

var player: PlayerCharacter
var damage_receiver: PlayerDamageReceiver
var vehicle_interactor: PlayerVehicleInteractor
var landing_impact_controller: PlayerLandingImpactController


func setup(
	target_player: PlayerCharacter,
	target_damage_receiver: PlayerDamageReceiver,
	target_vehicle_interactor: PlayerVehicleInteractor,
	target_landing_impact_controller: PlayerLandingImpactController
) -> void:
	player = target_player
	damage_receiver = target_damage_receiver
	vehicle_interactor = target_vehicle_interactor
	landing_impact_controller = target_landing_impact_controller

	player.jump_charge_changed.connect(_on_jump_charge_changed)
	player.ground_speed_changed.connect(_on_ground_speed_changed)
	player.flight_speed_changed.connect(_on_flight_speed_changed)
	player.stats.experience_changed.connect(_on_experience_changed)
	player.stats.level_changed.connect(_on_level_changed)
	damage_receiver.health_changed.connect(_on_health_changed)
	vehicle_interactor.throw_charge_changed.connect(_on_throw_charge_changed)
	landing_impact_controller.landing_classified.connect(_on_landing_classified)

	_on_health_changed(
		damage_receiver.get_current_health(),
		damage_receiver.get_max_health()
	)
	_on_jump_charge_changed(player.jump_charge, player.max_jump_charge_time)
	var walk_speed := player.stats.get_walk_speed(
		player.minimum_run_speed,
		player.run_speed_per_attribute_point,
		player.walk_speed_ratio
	)
	var run_speed := player.stats.get_run_speed(
		player.minimum_run_speed,
		player.run_speed_per_attribute_point
	)
	_on_ground_speed_changed(player.current_ground_speed, walk_speed, run_speed)
	_on_flight_speed_changed(
		player.velocity.length() if player.is_flying else 0.0,
		run_speed,
		player.is_flying
	)
	_on_throw_charge_changed(
		vehicle_interactor.is_charging_throw(),
		vehicle_interactor.vehicle_throw_hold_time,
		maxf(vehicle_interactor.vehicle_throw_charge_time, 0.001)
	)
	_refresh_experience_display()


func _on_health_changed(current_health: float, max_health: float) -> void:
	var safe_max_health := maxf(max_health, 1.0)
	health_bar.max_value = safe_max_health
	health_bar.value = clampf(current_health, 0.0, safe_max_health)
	health_label.text = "Health: %d / %d" % [
		roundi(current_health),
		roundi(safe_max_health)
	]


func _on_experience_changed(
	_current_experience: int,
	_experience_to_next_level: int
) -> void:
	_refresh_experience_display()


func _on_level_changed(_current_level: int) -> void:
	_refresh_experience_display()


func _refresh_experience_display() -> void:
	var experience_to_next_level := player.stats.get_experience_to_next_level()
	experience_bar.max_value = experience_to_next_level
	experience_bar.value = clampi(player.stats.experience, 0, experience_to_next_level)
	experience_label.text = "Level %d: %d / %d XP" % [
		player.stats.level,
		player.stats.experience,
		experience_to_next_level,
	]


func _on_jump_charge_changed(current_charge: float, max_charge: float) -> void:
	var clamped_percent := clampf(
		current_charge / maxf(max_charge, 0.001),
		0.0,
		1.0
	)
	charge_bar.value = clamped_percent * 100.0
	charge_label.text = "Power Jump: %d%%" % roundi(clamped_percent * 100.0)


func _on_landing_classified(category: String) -> void:
	landing_label.text = "Landing: %s" % category


func _on_flight_speed_changed(
	current_speed: float,
	max_speed: float,
	is_active: bool
) -> void:
	var speed_percent := current_speed / maxf(max_speed, 0.001) if is_active else 0.0
	var clamped_percent := clampf(speed_percent, 0.0, 1.0)
	flight_speed_bar.value = clamped_percent * 100.0
	flight_speed_label.text = "Flight Speed: %d%%" % roundi(clamped_percent * 100.0)


func _on_ground_speed_changed(
	current_speed: float,
	walk_speed: float,
	run_speed: float
) -> void:
	var speed_percent := 0.0
	if run_speed > walk_speed:
		speed_percent = inverse_lerp(walk_speed, run_speed, current_speed)
	var clamped_percent := clampf(speed_percent, 0.0, 1.0)
	sprint_speed_bar.value = clamped_percent * 100.0
	sprint_speed_label.text = "Sprint Speed: %d%%" % roundi(clamped_percent * 100.0)


func _on_throw_charge_changed(
	is_visible: bool,
	hold_time: float,
	max_charge_time: float
) -> void:
	var charge_percent := hold_time / maxf(max_charge_time, 0.001)
	var clamped_percent := clampf(charge_percent, 0.0, 1.0)
	vehicle_throw_charge_label.visible = is_visible
	vehicle_throw_charge_bar.visible = is_visible
	vehicle_throw_charge_bar.value = clamped_percent * 100.0
	vehicle_throw_charge_label.text = "Vehicle Throw: %d%%" % roundi(clamped_percent * 100.0)
