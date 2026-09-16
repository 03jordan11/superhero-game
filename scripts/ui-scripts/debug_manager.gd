extends Node

signal performance_hud_visibility_changed(is_visible: bool)
signal enemy_debug_visuals_changed

@export var show_enemy_names: bool = true:
	set(value):
		show_enemy_names = value
		enemy_debug_visuals_changed.emit()
@export var show_enemy_tints: bool = true:
	set(value):
		show_enemy_tints = value
		enemy_debug_visuals_changed.emit()

var show_landing_target: bool = false
var show_performance_hud: bool = false:
	set(value):
		if show_performance_hud == value: return
		show_performance_hud = value
		performance_hud_visibility_changed.emit(value)
var developer_menu_open: bool = false
