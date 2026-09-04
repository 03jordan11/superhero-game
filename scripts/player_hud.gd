class_name PlayerHud
extends CanvasLayer

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


func set_health(current_health: float, max_health: float) -> void:
	var safe_max_health := maxf(max_health, 1.0)
	health_bar.max_value = safe_max_health
	health_bar.value = clampf(current_health, 0.0, safe_max_health)
	health_label.text = "Health: %d / %d" % [
		roundi(current_health),
		roundi(safe_max_health)
	]


func set_jump_charge(charge_percent: float) -> void:
	var clamped_percent := clampf(charge_percent, 0.0, 1.0)
	charge_bar.value = clamped_percent * 100.0
	charge_label.text = "Power Jump: %d%%" % roundi(clamped_percent * 100.0)


func show_landing_category(category: String) -> void:
	landing_label.text = "Landing: %s" % category


func set_flight_speed(speed_percent: float) -> void:
	var clamped_percent := clampf(speed_percent, 0.0, 1.0)
	flight_speed_bar.value = clamped_percent * 100.0
	flight_speed_label.text = "Flight Speed: %d%%" % roundi(clamped_percent * 100.0)


func set_sprint_speed(speed_percent: float) -> void:
	var clamped_percent := clampf(speed_percent, 0.0, 1.0)
	sprint_speed_bar.value = clamped_percent * 100.0
	sprint_speed_label.text = "Sprint Speed: %d%%" % roundi(clamped_percent * 100.0)


func set_vehicle_throw_charge(is_visible: bool, charge_percent: float) -> void:
	var clamped_percent := clampf(charge_percent, 0.0, 1.0)
	vehicle_throw_charge_label.visible = is_visible
	vehicle_throw_charge_bar.visible = is_visible
	vehicle_throw_charge_bar.value = clamped_percent * 100.0
	vehicle_throw_charge_label.text = "Vehicle Throw: %d%%" % roundi(clamped_percent * 100.0)
