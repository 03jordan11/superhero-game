extends SceneTree

const COPY = preload("res://scripts/ui-scripts/powers_text.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var original_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/powers.json"))
	# Exercise JSON loading for both English and a partial regional fallback.
	# The temporary catalog never changes the real text or saved preferences.
	catalog["fr"] = {
		"powers.title": "POUVOIRS", "powers.back": "Retour",
		"power.ice.name": "Glace", "powers.category.elemental": "ÉLÉMENTAIRE",
		"powers.category.count": "{total} pouvoirs ; {owned} acquis",
		"powers.action.upgrade": "Amélioration {number}",
	}
	var test_path := OS.get_environment("TEMP").path_join("powers_locale_%d.json" % OS.get_process_id())
	var file := FileAccess.open(test_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(catalog))
	file.close()
	COPY._catalog_path = test_path
	for key in catalog.en:
		check(COPY.text(key) == catalog.en[key], "English catalog key did not resolve: " + key)
	var page = load("res://scenes/ui/powers_page.tscn").instantiate()
	root.add_child(page)
	page.open_page()
	page.progression.apply_save_data({"tokens": 5, "upgrades": {"super_leap": 0, "ice": 2}})
	page.select_power("ice")
	check(page.back_button.text == "Back", "Footer must use the short Back label")
	check(page.category_label.text == "ELEMENTAL", "Detail heading should show only the category")
	check(page.card_pips.ice.size() == 3, "Each power needs three pips")
	for i in 3:
		var pip: Panel = page.card_pips.ice[i]
		var style: StyleBoxFlat = pip.get_theme_stylebox("panel")
		check(pip.custom_minimum_size.x == pip.custom_minimum_size.y and style.corner_radius_top_left == 7, "Pips should be circles, not bars")
		check((style.bg_color.a > 0) == (i < 2), "Pip fill should match unlocked upgrades")
	check(not page.power_buttons.fire.disabled, "Locked powers must remain selectable")
	check(page.card_icons.ice.ink.v > page.card_icons.fire.ink.v, "Unlocked powers should have brighter icons")
	var labels: Array[Node] = page.find_children("*", "Label", true, false)
	for label in labels:
		for removed in ["SELECTED POWER", "CORE CONCEPT", "CORE UNLOCKED", "COST  /", "MENU TEST", "Choose a power", "token to unlock", "Super Leap opens", "Each power has its own"]:
			check(not String(label.text).contains(removed), "Removed copy must not remain: " + removed)
	TranslationServer.set_locale("fr_CA")
	await process_frame
	check(page.back_button.text == "Retour" and page.title_label.text == "Glace", "Changing locale must refresh the open page")
	check(page.category_label.text == "ÉLÉMENTAIRE", "Category should use the chosen language")
	check(page.category_counts.Elemental.text == "3 pouvoirs ; 1 acquis", "Named fields should allow translated word order")
	check(page.action_button.text == "Amélioration 3", "Formatted actions should refresh with the locale")
	check(page.description_label.text.begins_with("Encase your fists"), "Missing translations must fall back to English")
	TranslationServer.set_locale("de")
	await process_frame
	check(page.back_button.text == "Back", "Unsupported languages must fall back to English")
	page.free()
	DirAccess.remove_absolute(test_path)
	TranslationServer.set_locale(original_locale)
	if failures == 0: print("PASS: JSON catalog, circular upgrade pips, locked/owned appearance, regional locale lookup, live refresh and English fallback")
	quit(1 if failures else 0)
