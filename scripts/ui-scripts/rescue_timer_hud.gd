extends CanvasLayer
## Preview-only countdown. Picks the carried rescue first, otherwise the nearest.
var timer_label: Label
var detail_label: Label
@onready var player: PlayerCharacter = get_parent()

func _ready() -> void:
	layer = 5
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.offset_left = -240
	box.offset_right = 240
	box.offset_top = 28
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	timer_label = Label.new()
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 28)
	timer_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	timer_label.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(timer_label)
	detail_label = Label.new()
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.add_theme_font_size_override("font_size", 16)
	detail_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	detail_label.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(detail_label)
	hide()

func _process(_delta: float) -> void:
	var selected: RescueEncounter
	var distance := INF
	for node in get_tree().get_nodes_in_group(&"encounter"):
		var rescue := node as RescueEncounter
		if rescue == null or rescue.state != BaseEncounter.EncounterState.ACTIVE: continue
		if rescue.reward_player != player: continue
		var candidate := player.global_position.distance_squared_to(rescue.get_waypoint_position())
		if rescue.get_waypoint_priority() > 0:
			selected = rescue
			break
		if candidate < distance:
			selected = rescue
			distance = candidate
	visible = selected != null
	if selected == null: return
	var seconds := ceili(selected.remaining_time)
	timer_label.text = "RESCUE  %02d:%02d" % [seconds / 60, seconds % 60]
	timer_label.modulate = Color(1, 0.4, 0.2) if selected.penalty_flash > 0 else Color.WHITE
	detail_label.text = "Hard landing: −%s seconds" % String.num(selected.hard_landing_penalty, 1).trim_suffix(".0") if selected.penalty_flash > 0 else "Timer preview • no failure at 00:00"
