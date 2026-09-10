extends Resource
## Shared menu/HUD colors. Edit assets/ui/default_palette.tres in the Inspector.
@export_group("Accent and text")
@export var accent := Color("64e4ff")
@export var accent_soft := Color("acfbff")
@export var text_primary := Color("e5f3ff")
@export var text_secondary := Color("8aa5bb")
@export var text_on_accent := Color("031621")
@export_group("Surfaces")
@export var background := Color("040d17")
@export var surface := Color("091a29")
@export var surface_raised := Color("0c273a")
@export var surface_selected := Color("12394b")
@export var border := Color("234359")
@export_group("States")
@export var focus := Color("c1f6ff")
@export var owned_border := Color("439db8")
@export var locked_tint := Color("53b9de")
@export var shadow := Color(0.01, 0.04, 0.07, 0.75)

func apply_menu_colors(root: Control) -> void:
	var theme := Theme.new()
	for type in ["Label", "Button", "OptionButton", "CheckBox"]:
		theme.set_color("font_color", type, text_primary)
		theme.set_color("font_hover_color", type, accent_soft)
		theme.set_color("font_pressed_color", type, accent)
	for type in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = surface_raised if state == "hover" else surface
			if state == "focus": style.bg_color = Color(0, 0, 0, 0)
			style.border_color = border if state == "normal" else accent
			style.set_border_width_all(1)
			style.set_corner_radius_all(5)
			theme.set_stylebox(state, type, style)
	root.theme = theme
	for title in root.find_children("Title", "Label", true, false):
		title.add_theme_color_override("font_color", accent)
