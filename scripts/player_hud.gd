class_name PlayerHud
extends CanvasLayer

@onready var charge_bar: ProgressBar = $ChargeBar
@onready var charge_label: Label = $ChargeLabel
@onready var landing_label: Label = $LandingLabel
@onready var flight_speed_bar: ProgressBar = $FlightSpeedBar
@onready var flight_speed_label: Label = $FlightSpeedLabel


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
